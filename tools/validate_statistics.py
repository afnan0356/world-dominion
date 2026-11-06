#!/usr/bin/env python3
"""Validate the statistics data and its generated report.

`tools/build_statistics.py` writes the data; this script asks whether the result can be
trusted. It checks the things a reviewer would otherwise have to check by hand:

* every value is an exact integer with a source field and an as-of year (or is marked
  derived with the method that produced it);
* the runtime pack is exactly what the folders say it is (byte-identical);
* the manifest's statistics block matches the pack it describes, hash included;
* the crosswalk is a bijection against the source rows and every entry's name agrees;
* the report in `docs/` is the one the builder would write today.

    python3 tools/validate_statistics.py
    python3 tools/validate_statistics.py --check-report docs/STATISTICS_REPORT.md
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import build_statistics as stats  # noqa: E402  (same folder)

ROOT = pathlib.Path(__file__).resolve().parent.parent
WORLD = ROOT / "data" / "world"
FOLDERS = WORLD / "countries"


def load(path: pathlib.Path) -> dict | None:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except OSError:
        print(f"error: cannot read {path.relative_to(ROOT)}", file=sys.stderr)
        return None
    except json.JSONDecodeError as error:
        print(f"error: {path.relative_to(ROOT)} is not valid JSON: {error}", file=sys.stderr)
        return None


def validate() -> tuple[list[str], list[str], dict]:
    errors: list[str] = []
    warnings: list[str] = []

    registry = load(WORLD / "countries.json")
    manifest = load(WORLD / "manifest.json")
    crosswalk = load(WORLD / "statistics_crosswalk.json")
    pack = load(WORLD / "statistics.json")
    if registry is None or manifest is None or crosswalk is None or pack is None:
        return ["a required file is missing"], [], {}

    ids = {record["id"] for record in registry["countries"]}
    documents: dict[str, dict] = {}
    for country_id in sorted(ids):
        path = FOLDERS / country_id / "statistics.json"
        if path.exists():
            doc = load(path)
            if doc is None:
                errors.append(f"{country_id}/statistics.json is unreadable")
                continue
            documents[country_id] = doc

    # --- values are sourced and dated --------------------------------------
    for country_id, doc in documents.items():
        if doc.get("id") != country_id:
            errors.append(f"{country_id}: file says it is {doc.get('id')!r}")
        indicators = doc.get("indicators") or {}
        if not indicators:
            errors.append(f"{country_id}: a statistics.json with no indicators should not exist")
        for key, indicator in indicators.items():
            if key not in ("population", "gdp_usd", "area_km2"):
                errors.append(f"{country_id}: unexpected indicator {key!r}")
                continue
            value = indicator.get("value")
            if isinstance(value, bool) or not isinstance(value, int):
                errors.append(f"{country_id}.{key}: value {value!r} is not an exact integer")
            elif value < 0:
                errors.append(f"{country_id}.{key}: value is negative")
            elif key != "area_km2" and value == 0:
                warnings.append(f"{country_id}.{key}: a real zero, kept as the source states it")
            if indicator.get("derived"):
                if not str(indicator.get("method") or "").strip():
                    errors.append(f"{country_id}.{key}: derived value without a method")
            else:
                year = indicator.get("year")
                if not isinstance(year, int) or isinstance(year, bool):
                    errors.append(f"{country_id}.{key}: no as-of year")
                if not str(indicator.get("source_field") or "").strip():
                    errors.append(f"{country_id}.{key}: no source field")

    # --- the pack is the folders ------------------------------------------
    rebuilt_pack, rebuilt_counts = stats.pack_from_folder_documents(documents)
    expected = json.dumps(rebuilt_pack, ensure_ascii=False, indent=2) + "\n"
    committed = (WORLD / "statistics.json").read_text(encoding="utf-8")
    if committed != expected:
        errors.append("statistics.json is not byte-identical to the pack rebuilt from the folders")

    block = manifest.get("statistics") or {}
    digest = hashlib.sha256(committed.encode("utf-8")).hexdigest()
    if block.get("sha256") != digest:
        errors.append("the manifest's statistics sha256 does not match statistics.json")
    for key in ("records_with_data", "population", "gdp_usd", "area_km2"):
        if block.get(key) != rebuilt_counts[key]:
            errors.append(f"the manifest's {key} is {block.get(key)!r}, measured {rebuilt_counts[key]}")
    if block.get("schema") != rebuilt_pack["schema"]:
        errors.append("the manifest's statistics schema does not match the pack")

    # --- the crosswalk still describes the source -------------------------
    # The pinned source is git-ignored, so a checkout without `data/source/` (CI, a
    # fresh clone) cannot compare against the bytes. In that case the crosswalk is
    # checked for internal consistency and against the registry only, and the run says
    # so out loud rather than reporting a check it did not perform.
    registry_doc = registry
    if stats.DEFAULT_SOURCE.exists():
        source_rows, sha256 = stats.load_source(stats.DEFAULT_SOURCE)
        errors.extend(stats.verify_crosswalk(crosswalk, source_rows, registry_doc))
        if crosswalk.get("source", {}).get("sha256") not in (None, sha256):
            warnings.append("the crosswalk records a different source file hash than the file "
                            "on disk")
    else:
        print("note: data/source/ is not present, so the crosswalk was checked against the "
              "registry only; run tools/fetch_world_atlas.py to check it against the source bytes")
        errors.extend(stats.verify_crosswalk_without_source(crosswalk, registry_doc))

    # --- one indicator, one source ----------------------------------------
    sources = {doc["source"]["id"] for doc in documents.values()}
    if len(sources) > 1:
        errors.append(f"records cite more than one statistics source: {sorted(sources)}")

    summary = {"records": len(documents), **rebuilt_counts}
    return errors, warnings, summary


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-report", help="fail when this report is stale")
    args = parser.parse_args(argv[1:])

    errors, warnings, summary = validate()
    for message in errors:
        print(f"error: {message}", file=sys.stderr)
    for message in warnings[:10]:
        print(f"warning: {message}", file=sys.stderr)
    if len(warnings) > 10:
        print(f"warning: … and {len(warnings) - 10} more", file=sys.stderr)

    if args.check_report:
        if not errors and not stats.DEFAULT_SOURCE.exists():
            print("error: --check-report needs the pinned source file; run "
                  "tools/fetch_world_atlas.py first", file=sys.stderr)
            return 1
        if not errors:
            result = stats.build(stats.DEFAULT_SOURCE.parent)
            document = stats.build_report(result["built"], result["crosswalk"],
                                          result["source"], result["counts"])
            path = pathlib.Path(args.check_report)
            if not path.exists() or path.read_text(encoding="utf-8") != document:
                print(f"error: {path} is stale; run tools/build_statistics.py --report {path}",
                      file=sys.stderr)
                return 1
            print(f"{path} is up to date")

    if errors:
        return 1
    print(f"statistics valid: {summary.get('records')} records "
          f"({summary.get('population')} population, {summary.get('gdp_usd')} gdp, "
          f"{summary.get('area_km2')} area), {len(warnings)} warning(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
