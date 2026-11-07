#!/usr/bin/env python3
"""Validate the per-country folder tree and its relationship to the runtime pack.

Run in CI before the engine is installed, so a broken data commit fails fast.

Checks, all against what is actually on disk:

* every folder name is a stable id that is safe as a file name on Windows, macOS,
  Linux and Android (no reserved names, no case collisions, no spaces or dots);
* every folder has the required files and nothing unexpected;
* every JSON has the folder schema version and the right `kind`;
* `identity.json`'s id matches its folder;
* `sources.json` records dataset, repository, commit, version, licence,
  attribution and retrieval date, and the commit matches the manifest;
* `capital.json` is either absent or complete (never an empty placeholder);
* every `README.md` is exactly what the generator produces today;
* folders and the pack describe the same records (no orphan folder, no record
  without a folder);
* the manifest's counts and recorded pack hashes match reality;
* `filter_region` is the honest derivation of `region`, not a hand-set flag.

`--self-test` builds a tiny synthetic tree, then breaks it in six documented
ways and asserts that each break is caught. That keeps the validator itself
tested instead of trusted.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import build_country_pack  # noqa: E402
import country_folders as folders  # noqa: E402


def _load_json(path: str, problems: list[str]) -> dict | None:
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except OSError as error:
        problems.append(f"{path}: cannot read ({error})")
    except json.JSONDecodeError as error:
        problems.append(f"{path}: not valid JSON ({error})")
    return None


STATISTICS_INDICATORS = ("population", "gdp_usd", "area_km2")


CURRENCY_KEYS = ("schema", "kind", "id", "iso_4217", "name", "symbol", "current_since",
                 "region", "source", "note")


def _check_currency(name: str, currency: dict, problems: list[str]) -> None:
    """A currency file must be a sourced ISO 4217 code with an English name."""
    _check_schema(currency, "currency", f"{name}/currency.json", problems)
    if list(currency) != list(CURRENCY_KEYS):
        problems.append(f"{name}/currency.json: unexpected key order or keys")
    if currency.get("id") != name:
        problems.append(f"{name}/currency.json: id is {currency.get('id')!r}")
    code = str(currency.get("iso_4217") or "")
    if len(code) != 3 or not code.isalpha() or code != code.upper():
        problems.append(f"{name}/currency.json: {code!r} is not an ISO 4217 code")
    if not str(currency.get("name") or "").strip():
        problems.append(f"{name}/currency.json: no currency name")
    source = currency.get("source") or {}
    for field in ("id", "dataset", "version", "licence", "retrieved"):
        if not str(source.get(field) or "").strip():
            problems.append(f"{name}/currency.json: the source block has no {field}")


def _check_statistics(name: str, doc: dict, problems: list[str]) -> None:
    """A statistics file must be a sourced, integral, dated record — or absent."""
    where = f"{name}/statistics.json"
    _check_schema(doc, "statistics", where, problems)
    if doc.get("id") != name:
        problems.append(f"{where}: id is {doc.get('id')!r}, which does not match its folder")
    source = doc.get("source") or {}
    for key in ("id", "dataset", "version", "licence", "url", "retrieved", "sha256"):
        if not str(source.get(key) or "").strip():
            problems.append(f"{where}: source.{key} is empty")
    indicators = doc.get("indicators")
    if not isinstance(indicators, dict) or not indicators:
        problems.append(f"{where}: no indicators (a file with no value must not exist)")
        return
    for key, indicator in indicators.items():
        if key not in STATISTICS_INDICATORS:
            problems.append(f"{where}: unknown indicator {key!r}")
            continue
        if not isinstance(indicator, dict):
            problems.append(f"{where}: {key} is not an object")
            continue
        value = indicator.get("value")
        if isinstance(value, bool) or not isinstance(value, int):
            problems.append(f"{where}: {key}.value is not an exact integer ({value!r})")
        elif value < 0:
            problems.append(f"{where}: {key}.value is negative ({value})")
        if indicator.get("derived"):
            if not str(indicator.get("method") or "").strip():
                problems.append(f"{where}: {key} is derived but records no method")
        else:
            year = indicator.get("year")
            if isinstance(year, bool) or not isinstance(year, int) or not (1900 <= year <= 2100):
                problems.append(f"{where}: {key}.year is missing or implausible ({year!r})")
            if not str(indicator.get("source_field") or "").strip():
                problems.append(f"{where}: {key} records no source field")


def _check_schema(doc: dict, kind: str, where: str, problems: list[str]) -> None:
    if int(doc.get("schema", -1)) != folders.FOLDER_SCHEMA:
        problems.append(f"{where}: schema is {doc.get('schema')!r}, expected "
                        f"{folders.FOLDER_SCHEMA}")
    if doc.get("kind") != kind:
        problems.append(f"{where}: kind is {doc.get('kind')!r}, expected {kind!r}")


def _crosswalks(pack_dir: str, problems: list[str]) -> tuple[dict, dict]:
    """The two committed crosswalks that decide a record's codes and its picker group."""
    out: list[dict] = []
    for name in ("iso_codes_crosswalk.json", "picker_regions.json"):
        path = os.path.join(pack_dir, name)
        try:
            with open(path, encoding="utf-8") as handle:
                out.append(json.load(handle).get("records") or {})
        except OSError:
            problems.append(f"{name}: missing (run tools/build_country_codes.py)")
            out.append({})
        except (ValueError, KeyError):
            problems.append(f"{name}: unreadable")
            out.append({})
    return out[0], out[1]


def validate(folders_dir: str, pack_dir: str) -> list[str]:
    """Every problem found, in a stable order. Empty list means the tree is good."""
    problems: list[str] = []
    codes, regions = _crosswalks(pack_dir, problems)
    if not os.path.isdir(folders_dir):
        return [f"{folders_dir}: no country folder tree"]

    names = sorted(entry for entry in os.listdir(folders_dir)
                   if os.path.isdir(os.path.join(folders_dir, entry)))
    if not names:
        return [f"{folders_dir}: the tree has no country folders"]

    # --- names are portable and unique ignoring case ----------------------
    seen_lower: dict[str, str] = {}
    for name in names:
        if not folders.is_safe_id(name):
            problems.append(f"{name}/: not a portable folder name")
        if name.lower() in seen_lower:
            problems.append(f"{name}/: collides with {seen_lower[name].lower()}/ on a "
                            "case-insensitive filesystem")
        seen_lower[name.lower()] = name

    ids: list[str] = []
    for name in names:
        path = os.path.join(folders_dir, name)
        present = set(os.listdir(path))
        missing = [item for item in folders.REQUIRED_FILES if item not in present]
        for item in missing:
            problems.append(f"{name}/: missing {item}")
        allowed = set(folders.REQUIRED_FILES) | set(folders.OPTIONAL_FILES)
        for extra in sorted(present - allowed):
            problems.append(f"{name}/: unexpected file {extra}")
        if missing:
            continue

        identity = _load_json(os.path.join(path, "identity.json"), problems)
        geometry = _load_json(os.path.join(path, "geometry.json"), problems)
        sources = _load_json(os.path.join(path, "sources.json"), problems)
        capital = None
        if "capital.json" in present:
            capital = _load_json(os.path.join(path, "capital.json"), problems)
        statistics = None
        if "statistics.json" in present:
            statistics = _load_json(os.path.join(path, "statistics.json"), problems)
            if statistics:
                _check_statistics(name, statistics, problems)
        currency = None
        if "currency.json" in present:
            currency = _load_json(os.path.join(path, "currency.json"), problems)
            if currency:
                _check_currency(name, currency, problems)
        if not identity or not geometry or not sources:
            continue

        _check_schema(identity, "identity", f"{name}/identity.json", problems)
        _check_schema(geometry, "geometry", f"{name}/geometry.json", problems)
        _check_schema(sources, "sources", f"{name}/sources.json", problems)

        if identity.get("id") != name:
            problems.append(f"{name}/identity.json: id is {identity.get('id')!r}, "
                            f"which does not match its folder")
        ids.append(name)

        for key in ("name", "name_long", "type", "sovereignty"):
            if not str(identity.get(key) or "").strip():
                problems.append(f"{name}/identity.json: {key} is empty")
        # --- the codes and the picker group, checked against the crosswalks ----
        status = identity.get("code_status")
        if status not in ("iso-official", "user-assigned", "none"):
            problems.append(f"{name}/identity.json: code_status is {status!r}")
        entry = codes.get(name)
        if entry is None:
            problems.append(f"{name}/identity.json: no entry in iso_codes_crosswalk.json")
        else:
            for key in ("iso_a2", "iso_a3"):
                expected = entry.get(key) or ""
                actual = identity.get(key) or ""
                if actual != expected:
                    problems.append(f"{name}/identity.json: {key} is {actual!r}, the "
                                    f"crosswalk says {expected!r}")
            if status != entry.get("code_status"):
                problems.append(f"{name}/identity.json: code_status is {status!r}, the "
                                f"crosswalk says {entry.get('code_status')!r}")
        mapped = regions.get(name)
        if mapped is None:
            problems.append(f"{name}/identity.json: no entry in picker_regions.json")
        elif identity.get("picker_group") != mapped.get("group"):
            problems.append(f"{name}/identity.json: picker_group is "
                            f"{identity.get('picker_group')!r}, the map says "
                            f"{mapped.get('group')!r}")
        region = identity.get("region")
        expected_filter = region in build_country_pack.FILTER_REGIONS
        if bool(identity.get("filter_region")) != expected_filter:
            problems.append(f"{name}/identity.json: filter_region should be "
                            f"{expected_filter} for region {region!r}")

        for key in ("dataset", "repository", "commit", "version", "licence",
                    "attribution", "retrieved", "url"):
            if not str(sources.get(key) or "").strip():
                problems.append(f"{name}/sources.json: {key} is empty")
        if "Public Domain" not in str(sources.get("licence", "")):
            problems.append(f"{name}/sources.json: the licence is not recorded as public domain")

        if "capital.json" in present:
            if capital is None:
                continue
            _check_schema(capital, "capital", f"{name}/capital.json", problems)
            point = capital.get("point")
            if not str(capital.get("name") or "").strip():
                problems.append(f"{name}/capital.json: capital.json exists but has no name")
            if not (isinstance(point, list) and len(point) == 2
                    and all(isinstance(value, (int, float)) for value in point)):
                problems.append(f"{name}/capital.json: point is not a [lon, lat] pair")

        polygons = geometry.get("polygons")
        if not isinstance(polygons, list) or not polygons:
            problems.append(f"{name}/geometry.json: no polygons")
        else:
            for index, polygon in enumerate(polygons):
                for ring_index, ring in enumerate(polygon):
                    if len(ring) < 8 or len(ring) % 2:
                        problems.append(f"{name}/geometry.json: polygon {index} ring "
                                        f"{ring_index} is not a closed flat ring")
        if int(geometry.get("scale", 0)) != build_country_pack.SCALE:
            problems.append(f"{name}/geometry.json: scale is {geometry.get('scale')!r}")

        # --- README freshness -------------------------------------------
        wanted = folders.readme_document(identity, geometry, capital, sources, statistics,
                                         currency)
        readme_path = os.path.join(path, "README.md")
        try:
            with open(readme_path, encoding="utf-8") as handle:
                committed = handle.read()
        except OSError as error:
            problems.append(f"{name}/README.md: cannot read ({error})")
            continue
        if committed != wanted:
            problems.append(f"{name}/README.md: stale (regenerate with "
                            "tools/build_world_atlas.py)")

    # --- folders versus the pack -----------------------------------------
    countries_path = os.path.join(pack_dir, "countries.json")
    pack = _load_json(countries_path, problems)
    if pack is None:
        return problems
    pack_ids = [record.get("id") for record in pack.get("countries", [])]
    if len(set(pack_ids)) != len(pack_ids):
        problems.append("countries.json: duplicate ids")
    for orphan in sorted(set(ids) - set(pack_ids)):
        problems.append(f"{orphan}/: folder has no record in the pack")
    for missing_record in sorted(set(pack_ids) - set(ids)):
        problems.append(f"{missing_record}: record has no folder")

    manifest_path = os.path.join(pack_dir, "manifest.json")
    manifest = _load_json(manifest_path, problems)
    if manifest is None:
        return problems
    folder_block = manifest.get("folders") or {}
    if int(folder_block.get("count", -1)) != len(names):
        problems.append(f"manifest.json: folders.count is {folder_block.get('count')!r}, "
                        f"but {len(names)} folders exist")
    if int(manifest.get("counts", {}).get("countries", -1)) != len(pack_ids):
        problems.append("manifest.json: counts.countries disagrees with countries.json")

    commit = str((manifest.get("source") or {}).get("commit", ""))
    for name in ids:
        sources = _load_json(os.path.join(folders_dir, name, "sources.json"), problems)
        if sources and str(sources.get("commit", "")) != commit:
            problems.append(f"{name}/sources.json: commit disagrees with the manifest")

    # --- the pack really is the folder tree ------------------------------
    pack_block = manifest.get("pack") or {}
    for key, file_name in (("countries_sha256", "countries.json"),
                           ("geometry_sha256", "geometry.json")):
        path = os.path.join(pack_dir, file_name)
        if not os.path.exists(path):
            problems.append(f"{file_name}: missing from the pack directory")
            continue
        actual = folders.sha256_file(path)
        recorded = str(pack_block.get(key, ""))
        if recorded != actual:
            problems.append(f"{file_name}: manifest records {recorded[:16] or '(nothing)'}, "
                            f"file is {actual[:16]}")
    return problems


# --- Self-test fixtures ----------------------------------------------------


def _fixture_entry(country_id: str, name: str, with_capital: bool, index: int) -> dict:
    record = {
        "id": country_id, "name": name, "name_long": f"{name} (long)",
        "iso_a2": "ZZ", "iso_a3": country_id, "region": "Asia", "subregion": "Test",
        "code_status": "iso-official", "picker_group": "europe",
        "capital": "Testville" if with_capital else None,
        "capital_point": [10.0, 20.0] if with_capital else None,
        "type": "Sovereign country", "sovereignty": name, "note": None,
        "label": [10.0, 20.0], "label_rank": 3, "tiny": False,
        "bbox": [9.0, 19.0, 11.0, 21.0], "filter_region": True, "search": name.lower(),
    }
    geometry = {"bbox": record["bbox"], "polygons": [[[1800, 3800, 2200, 3800, 2200, 4200,
                                                       1800, 4200, 1800, 3800]]]}
    return {"record": record, "geometry": geometry, "adm0": country_id,
            "formal_name": None, "scale": 200, "source_index": index, "repairs": [],
            "dropped_rings": 0, "repaired_rings": 0, "repaired_vertices": 0}


def _rewrite_identity(tree: str, country_id: str, key: str, value: str) -> None:
    """Change one identity field, as a hand edit or a stale build would."""
    path = os.path.join(tree, "countries", country_id, "identity.json")
    with open(path, encoding="utf-8") as handle:
        document = json.load(handle)
    document[key] = value
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(document, handle, indent=2)
        handle.write("\n")


def _write_fixture(root: str) -> tuple[str, str]:
    folders_dir = os.path.join(root, "countries")
    pack_dir = os.path.join(root, "world")
    source = {
        "dataset": "Test data", "repository": "example/test", "commit": "0" * 40,
        "version": "1", "licence": "Public Domain (test)",
        "url": "https://example.invalid", "capital_url": "https://example.invalid",
        "retrieved": "2026-01-01",
    }
    entries = [_fixture_entry("AAA", "Alpha", True, 0),
               _fixture_entry("BBB", "Beta", False, 1),
               _fixture_entry("CON-2", "Gamma", False, 2)]
    folders.write_folders(folders_dir, entries, source, "2026-01-01")
    # The two crosswalks are part of the pack, and the validator checks every record
    # against them, so a fixture without them is already broken.
    codes = {"schema": 1, "records": {}}
    regions = {"schema": 1, "records": {}}
    for entry in entries:
        record = entry["record"]
        codes["records"][record["id"]] = {"iso_a2": record.get("iso_a2", ""),
                                          "iso_a3": record.get("iso_a3", ""),
                                          "code_status": record.get("code_status", "none")}
        regions["records"][record["id"]] = {"group": record.get("picker_group", "europe"),
                                            "continent": "Test",
                                            "subregion": "Test",
                                            "rule": "CONTINENT='Test'"}
    documents = build_country_pack.build_documents(folders_dir)
    build_country_pack.write_pack(documents, pack_dir)
    for name, document in (("iso_codes_crosswalk.json", codes),
                           ("picker_regions.json", regions)):
        path = os.path.join(pack_dir, name)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(document, handle, indent=2)
            handle.write("\n")
    return folders_dir, pack_dir


def self_test() -> int:
    """Break a good fixture in documented ways and require the validator to notice."""
    failures = 0
    with tempfile.TemporaryDirectory() as root:
        folders_dir, pack_dir = _write_fixture(root)
        problems = validate(folders_dir, pack_dir)
        if problems:
            print(f"self-test: the good fixture should pass, got {problems[:3]}")
            failures += 1
        else:
            print("self-test: a well-formed tree passes")

    cases = [
        ("missing required file",
         lambda tree: os.remove(os.path.join(tree, "countries/AAA/sources.json")),
         "missing sources.json"),
        ("orphan folder",
         lambda tree: shutil.copytree(os.path.join(tree, "countries/AAA"),
                                      os.path.join(tree, "countries/ZZZ")),
         "ZZZ/"),
        ("case-collision folder",
         lambda tree: shutil.copytree(os.path.join(tree, "countries/AAA"),
                                      os.path.join(tree, "countries/aaa")),
         "case-insensitive"),
        ("stale README",
         lambda tree: _append(os.path.join(tree, "countries/BBB/README.md"), "\nedited\n"),
         "stale"),
        ("code that disagrees with the crosswalk",
         lambda tree: _rewrite_identity(tree, "AAA", "iso_a2", "YY"),
         "the crosswalk says"),
        ("group that disagrees with the map",
         lambda tree: _rewrite_identity(tree, "AAA", "picker_group", "nowhere"),
         "the map says"),
        ("empty capital placeholder",
         lambda tree: _write(os.path.join(tree, "countries/BBB/capital.json"),
                             '{"schema": 1, "kind": "capital", "id": "BBB"}'),
         "capital.json"),
        ("wrong schema version",
         lambda tree: _rewrite_json(os.path.join(tree, "countries/AAA/identity.json"),
                                    {"schema": 99}),
         "schema is 99"),
        ("reserved Windows folder name",
         lambda tree: os.makedirs(os.path.join(tree, "countries/CON")),
         "CON"),
        ("hand-set filter_region",
         lambda tree: _rewrite_json(os.path.join(tree, "countries/AAA/identity.json"),
                                    {"filter_region": False}),
         "filter_region"),
        ("unexpected file",
         lambda tree: _write(os.path.join(tree, "countries/AAA/notes.txt"), "hello\n"),
         "unexpected file"),
    ]
    for label, breaker, expected in cases:
        with tempfile.TemporaryDirectory() as root:
            folders_dir, pack_dir = _write_fixture(root)
            breaker(root)
            problems = validate(folders_dir, pack_dir)
            joined = " ".join(problems)
            if expected in joined:
                print(f"self-test: caught {label}")
            else:
                print(f"self-test: MISSED {label} (looked for {expected!r}, got {problems[:3]})")
                failures += 1
    print("self-test: all validator checks responded as documented"
          if failures == 0 else f"self-test: {failures} check(s) failed")
    return 0 if failures == 0 else 1


def _write(path: str, text: str) -> None:
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text)


def _append(path: str, text: str) -> None:
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(text)


def _rewrite_json(path: str, patch: dict) -> None:
    with open(path, encoding="utf-8") as handle:
        doc = json.load(handle)
    doc.update(patch)
    _write(path, json.dumps(doc, indent=2) + "\n")


def main(argv: list[str]) -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--folders", default=os.path.join(root, "data/world/countries"))
    parser.add_argument("--pack-dir", default=os.path.join(root, "data/world"))
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()

    problems = validate(args.folders, args.pack_dir)
    if problems:
        print(f"country folders invalid: {len(problems)} problem(s)")
        for problem in problems[:40]:
            print(f"  - {problem}")
        if len(problems) > 40:
            print(f"  ... and {len(problems) - 40} more")
        return 1
    count = len([entry for entry in os.listdir(args.folders)
                 if os.path.isdir(os.path.join(args.folders, entry))])
    print(f"country folders ok: {count} records, required files, sources, READMEs, "
          "pack match")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
