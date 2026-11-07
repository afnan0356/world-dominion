#!/usr/bin/env python3
"""Build per-country currency data from Unicode CLDR, and nothing else.

The source is CLDR 48.0.0, pinned:

    dataset    Unicode CLDR 48.0.0 — supplemental currency data, English names
    packages   cldr-core 48.0.0 (supplemental/currencyData.json)
               cldr-numbers-full 48.0.0 (main/en/currencies.json)
    licence    Unicode License v3 (see THIRD_PARTY_LICENSES.md)
    retrieved  2026-11-07

**Nothing here is typed from memory, taken from Wikipedia or borrowed from a
parent country.** A record gets a `currency.json` only when the pinned source
names a current currency for that record's own ISO 3166-1 alpha-2 region *and*
gives that currency an English name. Everything else is listed as unmatched
with the reason, and the dossier shows "Not available".

"A current currency" means the region's entry in CLDR's `currencyData` that has
no end date and is not marked as a non-tender unit. If a region has no such
entry, or more than one, the record is unmatched: ambiguity is a refusal, not a
vote.

Usage:

    python3 tools/build_currency.py --source data/source/cldr-48.0.0
    python3 tools/build_currency.py --check          # no source needed: checks the tree
    python3 tools/build_currency.py --report docs/CURRENCY_REPORT.md
    python3 tools/build_currency.py --self-test

The builder writes `data/world/currency_crosswalk.json`, `data/world/currency.json`
and one `currency.json` per matched folder. It never touches geometry, identity,
statistics or the pack's hashes for them; `tools/build_country_pack.py` folds the
currency block into the manifest afterwards.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import country_folders as folders  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, "data", "world")
FOLDERS_DIR = os.path.join(WORLD, "countries")
CROSSWALK = os.path.join(WORLD, "currency_crosswalk.json")
PACK = os.path.join(WORLD, "currency.json")
REPORT = os.path.join(ROOT, "docs", "CURRENCY_REPORT.md")

SCHEMA = 1

SOURCE = {
    "id": "unicode_cldr_currency",
    "dataset": "Unicode CLDR 48.0.0 — supplemental currency data, English display names",
    "repository": "unicode-org/cldr",
    "version": "48.0.0",
    "licence": "Unicode License v3",
    "url": "https://registry.npmjs.org/cldr-core/-/cldr-core-48.0.0.tgz",
    "names_url": "https://registry.npmjs.org/cldr-numbers-full/-/cldr-numbers-full-48.0.0.tgz",
    "upstream": "https://github.com/unicode-org/cldr",
    "retrieved": "2026-11-07",
    "files": [
        {"name": "supplemental/currencyData.json",
         "purpose": "which currency each region used, with start and end dates"},
        {"name": "main/en/currencies.json",
         "purpose": "English display name and symbol for each ISO 4217 code"},
    ],
}

NOTICE = ("The currency each record uses, as the pinned CLDR release states it for that "
          "record's own region. Not a forecast and not an exchange rate.")

PURPOSE = ("Joins registry records to the regions of the CLDR currency source. The join key "
           "is the record's own ISO 3166-1 alpha-2 code; no record ever inherits another "
           "record's currency, and a record with no code of its own is unmatched.")

TENDER_FALSE = "false"


# --- Reading the source ----------------------------------------------------


def sha256_file(path: str) -> str:
    with open(path, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()


def load_regions(source_dir: str) -> dict[str, list[dict]]:
    """`{region: [entry, ...]}` straight out of CLDR's `currencyData`."""
    path = os.path.join(source_dir, "supplemental", "currencyData.json")
    with open(path, encoding="utf-8") as handle:
        document = json.load(handle)
    regions = document["supplemental"]["currencyData"]["region"]
    if not isinstance(regions, dict) or not regions:
        raise ValueError(f"{path} carries no currencyData.region map")
    return regions


def load_names(source_dir: str) -> dict[str, dict]:
    """`{code: {"name": ..., "symbol": ...}}` from CLDR's English currency names."""
    path = os.path.join(source_dir, "main", "en", "currencies.json")
    with open(path, encoding="utf-8") as handle:
        document = json.load(handle)
    currencies = document["main"]["en"]["numbers"]["currencies"]
    names: dict[str, dict] = {}
    for code, entry in currencies.items():
        name = entry.get("displayName")
        if not name:
            continue
        names[code] = {"name": name, "symbol": entry.get("symbol") or ""}
    return names


def current_currency(entries: list[dict]) -> tuple[dict | None, str]:
    """The one entry that is current, or `(None, reason)`.

    CLDR lists a region's currency history newest-first; an entry is current when it
    has no `_to`. An entry with `_tender: "false"` is a fund or a unit of account,
    not the money people hold, so it never counts.
    """
    open_entries: list[dict] = []
    for entry in entries:
        for code, fields in entry.items():
            if fields.get("_to"):
                continue
            if str(fields.get("_tender", "")).lower() == TENDER_FALSE:
                continue
            open_entries.append({"code": code, "since": fields.get("_from"),
                                 "tender": fields.get("_tender")})
    if not open_entries:
        return None, "the source names no current currency for this region"
    if len(open_entries) > 1:
        codes = sorted(item["code"] for item in open_entries)
        return None, "the source leaves more than one currency open: " + ", ".join(codes)
    return open_entries[0], ""


# --- Building --------------------------------------------------------------


def record_reason(record: dict) -> str:
    """Why a record cannot be joined at all, before the source is consulted."""
    code = (record.get("iso_a2") or "").strip().upper()
    if len(code) != 2 or not code.isalpha() or not code.isascii():
        return "no ISO 3166-1 alpha-2 code of its own"
    return ""


def build(folders_dir: str, source_dir: str) -> dict:
    """Everything the builder writes, as text, without touching the disk."""
    regions = load_regions(source_dir)
    names = load_names(source_dir)
    tree = folders.read_folders(folders_dir)
    ids = tree["ids"]
    if not ids:
        raise ValueError("the folder tree is empty")

    entries: dict[str, dict] = {}
    documents: dict[str, dict] = {}
    unmatched: list[dict] = []
    for country_id in sorted(ids):
        record = tree["identity"][country_id]
        reason = record_reason(record)
        code = (record.get("iso_a2") or "").strip().upper()
        if not reason and code not in regions:
            reason = f"the source has no region entry for {code}"
        current = None
        if not reason:
            current, reason = current_currency(regions[code])
        if current is not None and current["code"] not in names:
            reason = f"the source gives {current['code']} no English name"
            current = None
        entry = {
            "iso_a2": code or None,
            "region": code if code in regions else None,
            "matched": current is not None,
            "reason": reason,
            "iso_4217": current["code"] if current else None,
        }
        entries[country_id] = entry
        if current is None:
            unmatched.append({"id": country_id, "reason": reason})
            continue
        name = names[current["code"]]
        documents[country_id] = {
            "schema": folders.FOLDER_SCHEMA,
            "kind": "currency",
            "id": country_id,
            "iso_4217": current["code"],
            "name": name["name"],
            "symbol": name["symbol"],
            "current_since": current["since"],
            "region": code,
            "source": {
                "id": SOURCE["id"],
                "dataset": SOURCE["dataset"],
                "repository": SOURCE["repository"],
                "version": SOURCE["version"],
                "licence": SOURCE["licence"],
                "url": SOURCE["url"],
                "upstream": SOURCE["upstream"],
                "retrieved": SOURCE["retrieved"],
                "fields": [
                    {"path": f"currencyData.region.{code}", "holds": "the currency history"},
                    {"path": f"numbers.currencies.{current['code']}",
                     "holds": "the English name and symbol"},
                ],
            },
            "note": ("The source states this for the region of this record's own ISO "
                     "alpha-2 code. No currency, rate or forecast is inferred by this "
                     "project."),
        }

    crosswalk = {
        "schema": SCHEMA,
        "purpose": PURPOSE,
        "key": {"registry": "iso_a2", "source": "CLDR region code"},
        "source": SOURCE,
        "matched_count": len(documents),
        "record_count": len(ids),
        "entries": entries,
    }
    pack = full_pack(documents, len(ids))
    return {"documents": documents, "crosswalk": crosswalk, "pack": pack,
            "unmatched": unmatched, "record_count": len(ids)}


def full_pack(documents: dict[str, dict], record_count: int) -> dict:
    """The runtime pack, in one place, from the per-country documents on disk.

    Same function for the builder, for `tools/build_country_pack.py` and for `--check`,
    so the pack cannot disagree with the folders it claims to be built from.
    """
    return {
        "schema": SCHEMA,
        "kind": "currency",
        "notice": NOTICE,
        "source": {key: SOURCE[key] for key in
                   ("id", "dataset", "repository", "version", "licence", "url", "upstream",
                    "retrieved")},
        "matched_count": len(documents),
        "record_count": record_count,
        "countries": {
            country_id: {
                "iso_4217": documents[country_id]["iso_4217"],
                "name": documents[country_id]["name"],
                "symbol": documents[country_id].get("symbol", ""),
                "current_since": documents[country_id].get("current_since"),
            } for country_id in sorted(documents)
        },
        "report": "docs/CURRENCY_REPORT.md",
        "builder": "tools/build_currency.py",
    }


def from_tree(folders_dir: str) -> dict:
    """The crosswalk, the per-folder documents and the gap list, read from the tree.

    The raw CLDR files are a download and are not committed, so the report can be
    regenerated (and is checked) from what the repository actually ships.
    """
    with open(CROSSWALK, encoding="utf-8") as handle:
        crosswalk = json.load(handle)
    tree = folders.read_folders(folders_dir)
    documents = {country_id: tree["currency"][country_id] for country_id in tree["ids"]
                 if tree["currency"].get(country_id)}
    unmatched = [{"id": country_id, "reason": crosswalk["entries"][country_id]["reason"]}
                 for country_id in sorted(crosswalk.get("entries", {}))
                 if not crosswalk["entries"][country_id].get("matched")]
    return {"crosswalk": crosswalk, "documents": documents,
            "record_count": len(tree["ids"]), "unmatched": unmatched}


# --- Writing and checking --------------------------------------------------

CURRENCY_KEYS = ("schema", "kind", "id", "iso_4217", "name", "symbol", "current_since",
                 "region", "source", "note")


def document_text(document: dict) -> str:
    """The one JSON style the tree uses, with this file's key order."""
    ordered = {key: document[key] for key in CURRENCY_KEYS}
    return folders.dump_json(ordered)


def write(folders_dir: str, built: dict) -> dict:
    """Write every file the builder owns, and remove files it says should not exist."""
    written = 0
    removed = 0
    for country_id in built["crosswalk"]["entries"]:
        path = os.path.join(folders_dir, country_id, "currency.json")
        document = built["documents"].get(country_id)
        if document is None:
            if os.path.exists(path):
                os.remove(path)
                removed += 1
            continue
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(document_text(document))
        written += 1
    folders.write_json(CROSSWALK, built["crosswalk"])
    folders.write_json(PACK, built["pack"])
    return {"written": written, "removed": removed}


def check(folders_dir: str) -> list[str]:
    """Problems with the committed currency data, using only what is in the tree.

    The raw CLDR files are not committed (they are a download, like the atlas
    source), so the check rebuilds the pack from the folders and verifies that the
    crosswalk, the folders and the pack agree. A rebuild from the source is the
    builder's job, not CI's.
    """
    problems: list[str] = []
    tree = folders.read_folders(folders_dir)
    for path in (CROSSWALK, PACK):
        if not os.path.exists(path):
            problems.append(f"missing {os.path.relpath(path, ROOT)}")
    if problems:
        return problems
    with open(CROSSWALK, encoding="utf-8") as handle:
        crosswalk = json.load(handle)
    with open(PACK, encoding="utf-8") as handle:
        pack = json.load(handle)

    committed_documents: dict[str, dict] = {}
    for country_id in tree["ids"]:
        document = tree["currency"].get(country_id)
        path = os.path.join(folders_dir, country_id, "currency.json")
        entry = crosswalk.get("entries", {}).get(country_id)
        if entry is None:
            problems.append(f"currency_crosswalk.json has no entry for {country_id}")
            continue
        if entry.get("matched"):
            if document is None:
                problems.append(f"{country_id}/currency.json is missing but the crosswalk "
                                "says it matched")
                continue
            if list(document) != list(CURRENCY_KEYS):
                problems.append(f"{country_id}/currency.json has the wrong key order or keys")
            if str(document.get("id")) != country_id:
                problems.append(f"{country_id}/currency.json names {document.get('id')}")
            code = str(document.get("iso_4217") or "")
            if len(code) != 3 or not code.isalpha() or not code.isascii() or code != code.upper():
                problems.append(f"{country_id}/currency.json has a malformed ISO 4217 code "
                                f"{code!r}")
            if not str(document.get("name") or "").strip():
                problems.append(f"{country_id}/currency.json has no currency name")
            with open(path, "rb") as handle:
                text = handle.read().decode("utf-8")
            if text != document_text(document):
                problems.append(f"{country_id}/currency.json is not in the canonical format")
            committed_documents[country_id] = document
        else:
            if document is not None:
                problems.append(f"{country_id}/currency.json exists but the crosswalk says "
                                "the record is unmatched")
            if not str(entry.get("reason") or "").strip():
                problems.append(f"{country_id} has no currency and no recorded reason")

    rebuilt_full = full_pack(committed_documents, len(tree["ids"]))
    if json.dumps(pack, ensure_ascii=False, sort_keys=True) != json.dumps(
            rebuilt_full, ensure_ascii=False, sort_keys=True):
        problems.append("currency.json disagrees with the folders and the crosswalk")
    if int(crosswalk.get("matched_count", -1)) != len(committed_documents):
        problems.append("currency_crosswalk.json's matched_count is stale")
    if int(crosswalk.get("record_count", -1)) != len(tree["ids"]):
        problems.append("currency_crosswalk.json's record_count is stale")

    # The report is generated, so it is checked like everything else that is generated.
    wanted = report_document(from_tree(folders_dir))
    if os.path.exists(REPORT):
        with open(REPORT, encoding="utf-8") as handle:
            committed_report = handle.read()
        if committed_report != wanted:
            problems.append("docs/CURRENCY_REPORT.md is stale (rerun with --report)")
    else:
        problems.append("docs/CURRENCY_REPORT.md is missing")
    return problems


# --- The report ------------------------------------------------------------


def report_document(built: dict) -> str:
    entries = built["crosswalk"]["entries"]
    documents = built["documents"]
    total = built["record_count"]
    matched = len(documents)
    codes: dict[str, int] = {}
    for document in documents.values():
        codes[document["iso_4217"]] = codes.get(document["iso_4217"], 0) + 1

    lines: list[str] = []
    add = lines.append
    add("# Currency report")
    add("")
    add("**Generated by `tools/build_currency.py --report`. Do not edit by hand: CI "
        "regenerates it and fails if the committed copy differs.**")
    add("")
    add("## The source")
    add("")
    add(f"* Dataset: {SOURCE['dataset']}")
    add(f"* Repository: `{SOURCE['repository']}` (upstream {SOURCE['upstream']})")
    add(f"* Version: {SOURCE['version']}")
    add(f"* Licence: {SOURCE['licence']} — the full text ships with the data source, and "
        "the notice is repeated in [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)")
    add(f"* Retrieved: {SOURCE['retrieved']}")
    add(f"* Files used: `{SOURCE['files'][0]['name']}` "
        f"({SOURCE['files'][0]['purpose']}), `{SOURCE['files'][1]['name']}` "
        f"({SOURCE['files'][1]['purpose']})")
    add("")
    add("Only two things are taken from the source: which currency CLDR records as current "
        f"for a region (the entry with no end date that is not marked `tender: false`), and "
        "that currency's English display name and symbol. Nothing is converted, averaged, "
        "predicted or dated by this project.")
    add("")
    add("## The matching")
    add("")
    add(f"* Records in the atlas: **{total}**")
    add(f"* Records with a sourced currency: **{matched}**")
    add(f"* Records without one: **{total - matched}**")
    add(f"* Distinct currencies: **{len(codes)}**")
    add("")
    add("A record is matched only through **its own** ISO 3166-1 alpha-2 code. A record "
        "without a code of its own is never given the currency of the country it belongs "
        "to: the dossier says \"Not available\" and the reason is in the table below.")
    add("")
    add("## Currencies, by how many records use them")
    add("")
    add("| ISO 4217 | Name | Records |")
    add("| --- | --- | --- |")
    by_code: dict[str, tuple[str, int]] = {}
    for document in documents.values():
        name = document["name"]
        count = codes[document["iso_4217"]]
        by_code[document["iso_4217"]] = (name, count)
    for code in sorted(by_code):
        name, count = by_code[code]
        add(f"| `{code}` | {name} | {count} |")
    add("")
    add("## Records without a currency, and why")
    add("")
    if not built["unmatched"]:
        add("* None: every record has a sourced currency.")
    else:
        add("| Record | Reason |")
        add("| --- | --- |")
        for row in built["unmatched"]:
            add(f"| `{row['id']}` | {row['reason']} |")
    add("")
    add("## What this data is not")
    add("")
    add("* It is **not** an exchange rate, a price, or a forecast. The game stores no rate.")
    add("* It is **not** loaded into the simulation or into a save file. It is a label the "
        "dossier shows, and a test enforces that `src/core/sim` and `src/core/save` never "
        "mention it.")
    add("* It is **not** inferred for a territory from its parent. Where CLDR has no region "
        "entry of the territory's own, the record is unmatched.")
    add("")
    return "\n".join(lines)


# --- Self-test -------------------------------------------------------------


def self_test() -> int:
    """Fixture checks on the rules, so a broken rule fails here and not in the tree."""
    failures: list[str] = []

    def check(condition: bool, message: str) -> None:
        if not condition:
            failures.append(message)

    open_entry, reason = current_currency([{"BDT": {"_from": "1972-01-01"}},
                                           {"PKR": {"_from": "1948-04-01",
                                                    "_to": "1972-01-01"}}])
    check(open_entry is not None and open_entry["code"] == "BDT",
          "the entry without an end date is the current one")
    check(reason == "", "a single open entry is not a reason")

    closed, reason = current_currency([{"X": {"_from": "1", "_to": "2"}}])
    check(closed is None and "no current currency" in reason,
          "a closed history has no current currency")

    fund, _ = current_currency([{"USD": {"_from": "1792-01-01"}},
                                {"USN": {"_tender": "false"}}])
    check(fund is not None and fund["code"] == "USD",
          "a non-tender unit of account never becomes the answer")

    ambiguous, reason = current_currency([{"AAA": {}}, {"BBB": {}}])
    check(ambiguous is None and "more than one currency open" in reason,
          "two open entries are refused, not chosen between")

    check(record_reason({"iso_a2": None}) != "", "a record with no code is unmatched")
    check(record_reason({"iso_a2": "-99"}) != "", "a record with a non-code is unmatched")
    check(record_reason({"iso_a2": "BD"}) == "", "a two-letter code is joinable")

    if failures:
        for failure in failures:
            print(f"self-test failure: {failure}")
        return 1
    print("self-test ok: 7 rules")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__ or "")
    parser.add_argument("--source", default=os.path.join(ROOT, "data", "source",
                                                         "cldr-48.0.0"),
                        help="the extracted CLDR packages")
    parser.add_argument("--folders", default=FOLDERS_DIR)
    parser.add_argument("--check", action="store_true", help="fail when the tree is stale")
    parser.add_argument("--report", nargs="?", const=REPORT,
                        help="write the report (default docs/CURRENCY_REPORT.md)")
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--readmes", action="store_true",
                        help="rewrite each folder's README.md from its own documents")
    args = parser.parse_args()

    if args.self_test:
        return self_test()
    if args.readmes:
        tree = folders.read_folders(args.folders)
        written = 0
        for country_id in tree["ids"]:
            text = folders.readme_document(tree["identity"][country_id],
                                           tree["geometry"][country_id],
                                           tree["capital"][country_id],
                                           tree["sources"][country_id],
                                           tree["statistics"][country_id],
                                           tree["currency"][country_id])
            path = os.path.join(args.folders, country_id, "README.md")
            with open(path, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(text)
            written += 1
        print(f"rewrote {written} README.md files")
        return 0
    if args.check:
        problems = check(args.folders)
        for problem in problems:
            print(f"currency: {problem}")
        if problems:
            print(f"currency data is stale: {len(problems)} problem(s)")
            return 1
        print("currency data matches the folders, the crosswalk and the pack")
        return 0
    if not os.path.isdir(args.source):
        if args.report:
            # No download here: regenerate the report from the committed tree instead, so
            # the document can be refreshed on a machine that has no source checkout.
            with open(args.report, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(report_document(from_tree(args.folders)))
            print(f"no CLDR extract at {args.source}; wrote the report from the tree")
            return 0
        print(f"no CLDR extract at {args.source}")
        print("download cldr-core and cldr-numbers-full 48.0.0 and unpack them there")
        return 1
    built = build(args.folders, args.source)
    counts = write(args.folders, built)
    print(f"matched {len(built['documents'])} of {built['record_count']} records, "
          f"{len(built['unmatched'])} unmatched; wrote {counts['written']} folder files, "
          f"removed {counts['removed']}")
    if args.report:
        with open(args.report, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(report_document(built))
        print(f"wrote {os.path.relpath(args.report, ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
