#!/usr/bin/env python3
"""ISO country codes and the picker's region groups, both derived from the pinned source.

Two products, one pass, because they answer the same kind of question — "what does the
source actually say about this record?" — and both must be checkable against the source
bytes rather than against memory.

**Codes.** Natural Earth stores `-99` in `ISO_A2`/`ISO_A3` for a handful of records and
`CN-TW` for Taiwan. The same file carries corrected fields (`ISO_A2_EH`, `ISO_A3_EH`) for
some of them, and this tool adopts those, records why, and marks every record:

* `iso-official` — the code the source gives is the record's own ISO 3166-1 code;
* `user-assigned` — the code is widely used but not officially assigned (Kosovo's `XK`);
* `none` — the source has no code of this record's own.

Two records are deliberately **not** fixed: for the Indian Ocean Territories and Ashmore
and Cartier Islands the corrected field carries their administering state's code
(`AU`/`AUS`). Copying that onto a separate record would give three records the same code
and would read as a sovereignty claim. They keep no code, and the report says so.

**Groups.** The picker shows a finer taxonomy than the source's `CONTINENT`. Every record
is assigned to exactly one group by a published rule over `CONTINENT` + `SUBREGION`;
nothing is hand-coded per record. Where the source's labels cannot settle a case without a
political judgement, the rule applies a documented default and the case is listed under
"needs owner review" instead of being quietly decided.

    python3 tools/build_country_codes.py            # write both files + the report
    python3 tools/build_country_codes.py --check    # fail when anything is stale
    python3 tools/build_country_codes.py --self-test
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "data" / "source" / "ne_50m_admin_0_countries.geojson"
WORLD = ROOT / "data" / "world"
CODES = WORLD / "iso_codes_crosswalk.json"
REGIONS = WORLD / "picker_regions.json"
REPORT = ROOT / "docs" / "COUNTRY_CODES_AND_REGIONS.md"
REGISTRY = WORLD / "countries.json"

CODES_SCHEMA = 1
REGIONS_SCHEMA = 1

#: `CONTINENT` → the picker groups it can produce, by `SUBREGION`. The first rule that
#: matches wins, and `None` means "any subregion of that continent".
GROUP_RULES: list[tuple[str, str | None, str]] = [
    # A subregion of "Seven seas (open ocean)" wins over the continent: one record
    # (the Indian Ocean Territories) is filed under Asia but is an island dependency
    # with no continental mainland, and putting it in a continent list would be wrong.
    ("*", "Seven seas (open ocean)", "oceans"),
    ("North America", "Northern America", "north_america"),
    ("North America", "Central America", "central_america_caribbean"),
    ("North America", "Caribbean", "central_america_caribbean"),
    ("South America", None, "south_america"),
    ("Europe", None, "europe"),
    ("Africa", "Northern Africa", "africa_north"),
    ("Africa", "Western Africa", "africa_west"),
    ("Africa", "Middle Africa", "africa_central"),
    ("Africa", "Eastern Africa", "africa_east"),
    ("Africa", "Southern Africa", "africa_south"),
    ("Asia", "Western Asia", "middle_east"),
    ("Asia", "Central Asia", "central_asia"),
    ("Asia", "Southern Asia", "south_asia"),
    ("Asia", "Eastern Asia", "east_asia"),
    ("Asia", "South-Eastern Asia", "southeast_asia"),
    ("Oceania", None, "oceania"),
    ("Antarctica", None, "antarctica"),
    ("Seven seas (open ocean)", None, "oceans"),
]

GROUPS: list[tuple[str, str]] = [
    ("north_america", "North America"),
    ("central_america_caribbean", "Central America & Caribbean"),
    ("south_america", "South America"),
    ("europe", "Europe"),
    ("africa_north", "Africa — North"),
    ("africa_west", "Africa — West"),
    ("africa_central", "Africa — Central"),
    ("africa_east", "Africa — East"),
    ("africa_south", "Africa — South"),
    ("middle_east", "Middle East"),
    ("central_asia", "Central Asia"),
    ("south_asia", "South Asia"),
    ("east_asia", "East Asia"),
    ("southeast_asia", "Southeast Asia"),
    ("oceania", "Oceania"),
    ("antarctica", "Antarctica"),
    ("oceans", "Islands of the open ocean"),
]

#: Records whose `SUBREGION` is Western Asia but which are not usually meant by "Middle
#: East". The rule still places them there (that is the source's own geography); they are
#: listed so the owner can move them with a rule change rather than a hand edit.
REVIEW_NOTE = {
    "middle_east": "Western Asia is the source's own label. Cyprus, Georgia, Armenia and "
                   "Azerbaijan are placed here by that label; move them with a rule, not by "
                   "editing a record.",
    "oceans": "The source labels these 'Seven seas (open ocean)': they are small islands "
              "and atolls with no continental assignment. Kept in their own group so the "
              "continent lists stay honest.",
    "antarctica": "One record, the Antarctic Treaty area. It is not a country and cannot "
                  "start a campaign; the eligibility rule is unchanged.",
}

A2_PATTERN = re.compile(r"^[A-Z]{2}$")
A3_PATTERN = re.compile(r"^[A-Z]{3}$")


def fail(message: str) -> "SystemExit":
    print(f"error: {message}", file=sys.stderr)
    return SystemExit(1)


def load_source() -> tuple[list[dict], str]:
    if not SOURCE.exists():
        raise fail(f"no source file at {SOURCE}; run tools/fetch_world_atlas.py first "
                   "(this tool never invents a code)")
    raw = SOURCE.read_bytes()
    rows = [feature.get("properties") or {}
            for feature in json.loads(raw.decode("utf-8")).get("features", [])]
    if not rows:
        raise fail(f"{SOURCE.name} has no features")
    return rows, hashlib.sha256(raw).hexdigest()


def clean_code(value: object) -> str | None:
    """The source's code, or None when it is a placeholder, empty or malformed."""
    text = str(value or "").strip()
    if not text or text == "-99":
        return None
    return text


def code_owners(rows: list[dict]) -> dict[tuple[str, str], str]:
    """Which record each plain code belongs to, so a parent's code is never copied.

    Natural Earth fills the corrected field for a dependency with its administering
    state's code. Adopting that would give three records the same code, so a code that
    already belongs to another record is never adopted.
    """
    owners: dict[tuple[str, str], str] = {}
    for row in rows:
        adm0 = str(row.get("ADM0_A3") or "")
        for kind, field_name in (("a2", "ISO_A2"), ("a3", "ISO_A3")):
            code = clean_code(row.get(field_name))
            if code:
                owners.setdefault((kind, code), adm0)
    return owners


def code_entry(row: dict, owners: dict[tuple[str, str], str]) -> dict:
    """One record's codes, with the rule that produced them."""
    plain_a2, plain_a3 = clean_code(row.get("ISO_A2")), clean_code(row.get("ISO_A3"))
    fixed_a2, fixed_a3 = clean_code(row.get("ISO_A2_EH")), clean_code(row.get("ISO_A3_EH"))
    adm0 = str(row.get("ADM0_A3") or "")
    name = str(row.get("NAME") or "")
    fclass = str(row.get("FCLASS_ISO") or "")

    entry: dict = {
        "adm0_a3": adm0,
        "iso_a2": None,
        "iso_a3": None,
        "code_status": "none",
        "source_fields": [],
        "note": "",
    }

    # A code is only this record's own when no *other* record already claims it.
    def is_own(code: str | None, kind: str) -> bool:
        if code is None:
            return False
        owner = owners.get((kind, code))
        return owner is None or owner == adm0

    if plain_a2 is not None and A2_PATTERN.match(plain_a2):
        entry["iso_a2"], _ = plain_a2, entry["source_fields"].append("ISO_A2")
    if plain_a3 is not None and A3_PATTERN.match(plain_a3):
        entry["iso_a3"] = plain_a3
        entry["source_fields"].append("ISO_A3")

    changed: list[str] = []
    if entry["iso_a2"] is None and is_own(fixed_a2, "a2") and A2_PATTERN.match(fixed_a2 or ""):
        entry["iso_a2"] = fixed_a2
        changed.append("ISO_A2_EH")
    if entry["iso_a3"] is None and is_own(fixed_a3, "a3") and A3_PATTERN.match(fixed_a3 or ""):
        entry["iso_a3"] = fixed_a3
        changed.append("ISO_A3_EH")
    for field_name in changed:
        if field_name not in entry["source_fields"]:
            entry["source_fields"].append(field_name)

    if entry["iso_a2"] is None and entry["iso_a3"] is None:
        note = ""
        if fixed_a2 or fixed_a3:
            note = (f"the corrected field names the administering state ({fixed_a2}/{fixed_a3}), "
                    "not this record; adopting it would duplicate that state's code, so this "
                    "record keeps no code")
        elif fclass == "Unrecognized":
            note = "the source marks it 'Unrecognized' and has no code of its own"
        entry["code_status"] = "none"
        entry["note"] = note
        return entry

    # Kosovo: XK is widely used but not an officially assigned ISO 3166-1 code.
    if adm0 == "KOS" or (entry["iso_a2"] == "XK"):
        entry["code_status"] = "user-assigned"
        entry["note"] = ("XK is commonly used for Kosovo but is not officially assigned in "
                         "ISO 3166-1; recorded as user-assigned, never as official. The "
                         "source gives no three-letter code for Kosovo at all, so none is "
                         "shown — a gap, not an invention")
        return entry

    entry["code_status"] = "iso-official"
    if changed:
        entry["note"] = ("taken from the source's corrected " + "/".join(changed) +
                         " field, where the plain field holds the -99 placeholder")
    elif plain_a2 is None and entry["iso_a2"] is not None:
        entry["note"] = "two-letter code read from the corrected field"
    return entry


def group_for(continent: str, subregion: str) -> tuple[str, str]:
    """(group, rule text) for one record. Every input matches exactly one rule."""
    for rule_continent, rule_subregion, group in GROUP_RULES:
        if rule_continent != "*" and continent != rule_continent:
            continue
        if rule_subregion is not None and subregion != rule_subregion:
            continue
        rule = f"CONTINENT={continent!r}"
        if rule_subregion:
            rule += f" and SUBREGION={subregion!r}"
        return group, rule
    raise fail(f"no rule covers CONTINENT={continent!r} SUBREGION={subregion!r}")


def build(source_dir: pathlib.Path = SOURCE.parent) -> dict:
    rows, sha256 = load_source()
    registry = json.loads(REGISTRY.read_text(encoding="utf-8"))
    owners = code_owners(rows)
    by_adm0 = {}
    for row in rows:
        code = str(row.get("ADM0_A3") or "")
        if code:
            by_adm0.setdefault(code, row)

    # The registry's id is not always the source's code; the statistics crosswalk is the
    # committed map between them, so it is reused rather than re-derived by name.
    statistics_crosswalk = json.loads((WORLD / "statistics_crosswalk.json")
                                      .read_text(encoding="utf-8"))
    codes = {
        "schema": CODES_SCHEMA,
        "purpose": ("The ISO 3166-1 codes this project shows, the field each came from and "
                    "whether it is official. Generated from the pinned source by "
                    "tools/build_country_codes.py; never edited by hand."),
        "source": {
            "dataset": "Natural Earth 1:50m Cultural Vectors — Admin 0 Countries",
            "repository": "nvkelso/natural-earth-vector",
            "commit": "ca96624a56bd078437bca8184e78163e5039ad19",
            "version": "5.2.0-pre",
            "licence": "Public Domain (Natural Earth Terms of Use)",
            "retrieved": "2026-11-05",
            "file": SOURCE.name,
            "sha256": sha256,
        },
        "fields": {
            "ISO_A2": "natural earth's two-letter field",
            "ISO_A3": "natural earth's three-letter field",
            "ISO_A2_EH": "the corrected two-letter field (EH = the publisher's fix)",
            "ISO_A3_EH": "the corrected three-letter field",
        },
        "statuses": {
            "iso-official": "the record's own officially assigned ISO 3166-1 code",
            "user-assigned": "a widely used code that is not officially assigned",
            "none": "the source has no code of this record's own; nothing is invented",
        },
        "records": {},
    }
    regions = {
        "schema": REGIONS_SCHEMA,
        "purpose": ("The country picker's groups, derived from the source's own CONTINENT "
                    "and SUBREGION fields by the published rules below. Each record is in "
                    "exactly one group."),
        "rules": [{"continent": c, "subregion": s, "group": g}
                  for c, s, g in GROUP_RULES],
        "groups": [{"id": gid, "label": label} for gid, label in GROUPS],
        "records": {},
    }
    review: list[dict] = []
    unmatched: list[str] = []
    for record in registry.get("countries", []):
        country_id = record["id"]
        adm0 = statistics_crosswalk["entries"].get(country_id)
        row = by_adm0.get(adm0 or "")
        if row is None:
            unmatched.append(country_id)
            continue
        codes["records"][country_id] = code_entry(row, owners)
        continent = str(row.get("CONTINENT") or "")
        subregion = str(row.get("SUBREGION") or "")
        group, rule = group_for(continent, subregion)
        regions["records"][country_id] = {
            "group": group, "continent": continent, "subregion": subregion, "rule": rule,
        }
        if group in REVIEW_NOTE:
            review.append({"id": country_id, "group": group, "continent": continent,
                           "subregion": subregion})
    if unmatched:
        raise fail(f"{len(unmatched)} registry records have no source row: "
                   f"{', '.join(unmatched[:8])}")
    return {"codes": codes, "regions": regions, "review": review, "sha256": sha256}


def dump(document: dict) -> str:
    return json.dumps(document, ensure_ascii=False, indent=2) + "\n"


def document(report: dict) -> str:
    codes, regions = report["codes"], report["regions"]
    counts: dict[str, int] = {}
    for entry in codes["records"].values():
        counts[entry["code_status"]] = counts.get(entry["code_status"], 0) + 1
    group_counts: dict[str, int] = {}
    for entry in regions["records"].values():
        group_counts[entry["group"]] = group_counts.get(entry["group"], 0) + 1

    lines: list[str] = []
    add = lines.append
    add("# Country codes and picker regions")
    add("")
    add("Generated by `python3 tools/build_country_codes.py`. Do not edit by hand: CI runs")
    add("it with `--check` and fails when this file is stale.")
    add("")
    add("Both tables come from the **same pinned Natural Earth file** the map is drawn")
    add("from. No code and no group was typed from memory, and neither was chosen by")
    add("hand for a single record.")
    add("")
    add("## Country codes")
    add("")
    add("| Status | Records | Meaning |")
    add("| --- | ---: | --- |")
    for status in ("iso-official", "user-assigned", "none"):
        add(f"| `{status}` | {counts.get(status, 0)} | {codes['statuses'][status]} |")
    add("")
    add("### What was wrong, and what the source itself fixed")
    add("")
    add("Natural Earth writes `-99` where it has no code, and Taiwan's two-letter field")
    add("holds `CN-TW`, which is not a two-letter code. The same file carries corrected")
    add("fields (`ISO_A2_EH` / `ISO_A3_EH`), and those are the values adopted here:")
    add("")
    add("| Record | Name | Before | After | From | Status |")
    add("| --- | --- | --- | --- | --- | --- |")
    for country_id, entry in sorted(codes["records"].items()):
        if not entry["note"]:
            continue
        after = f"{entry['iso_a2'] or '—'} / {entry['iso_a3'] or '—'}"
        fields = ", ".join(f"`{name}`" for name in entry["source_fields"]) or "—"
        add(f"| `{country_id}` | {entry['adm0_a3']} | — | {after} | {fields} | "
            f"`{entry['code_status']}` |")
    add("")
    add("The two records that the corrected field would have given their **administering")
    add("state's** code (the Indian Ocean Territories and Ashmore and Cartier Islands) are")
    add("left without one: three records answering to `AU` would be wrong, and copying a")
    add("parent's code onto a territory is a sovereignty claim this project does not make.")
    add("")
    add("### Every record")
    add("")
    add("| ID | Source ADM0_A3 | ISO alpha-2 | ISO alpha-3 | Status | Group |")
    add("| --- | --- | --- | --- | --- | --- |")
    for country_id in sorted(codes["records"]):
        entry = codes["records"][country_id]
        group = regions["records"].get(country_id, {}).get("group", "—")
        add(f"| `{country_id}` | {entry['adm0_a3']} | {entry['iso_a2'] or '—'} | "
            f"{entry['iso_a3'] or '—'} | `{entry['code_status']}` | `{group}` |")
    add("")
    add("## Picker regions")
    add("")
    add("| Group | Records |")
    add("| --- | ---: |")
    for group_id, label in GROUPS:
        add(f"| {label} (`{group_id}`) | {group_counts.get(group_id, 0)} |")
    add(f"| **Total** | **{sum(group_counts.values())}** |")
    add("")
    add("### The rules")
    add("")
    add("Applied in order; the first match wins, and a record that matches none is a build")
    add("error rather than a silent default.")
    add("")
    add("| CONTINENT | SUBREGION | Group |")
    add("| --- | --- | --- |")
    for rule in regions["rules"]:
        continent = "any" if rule["continent"] == "*" else rule["continent"]
        add(f"| {continent} | {rule['subregion'] or '(any)'} | `{rule['group']}` |")
    add("")
    add("### Needs owner review")
    add("")
    add("These are the cases where the source's labels do not settle the question, so the")
    add("rule above applies a **documented default** and the case is listed here instead of")
    add("being decided quietly. Changing one is a change to `GROUP_RULES`, not to a record.")
    add("")
    for group_id, note in REVIEW_NOTE.items():
        members = [item["id"] for item in report["review"] if item["group"] == group_id]
        if not members:
            continue
        add(f"* **{group_id}** — {note}")
        add(f"  Records: {', '.join('`' + member + '`' for member in sorted(members))}")
    add("")
    return "\n".join(lines)


def check(report: dict) -> list[str]:
    problems: list[str] = []
    for path, document_value in ((CODES, report["codes"]), (REGIONS, report["regions"])):
        try:
            committed = json.loads(path.read_text(encoding="utf-8"))
        except OSError:
            problems.append(f"{path.name} is missing")
            continue
        if committed != document_value:
            problems.append(f"{path.name} is stale")
    try:
        committed_report = REPORT.read_text(encoding="utf-8")
    except OSError:
        problems.append(f"{REPORT.relative_to(ROOT)} is missing")
        committed_report = None
    if committed_report is not None and committed_report != document(report):
        problems.append(f"{REPORT.relative_to(ROOT)} is stale")
    return problems


def self_test() -> int:
    failures: list[str] = []

    def expect(condition: bool, message: str) -> None:
        if not condition:
            failures.append(message)

    def row(**overrides: object) -> dict:
        base = {"ADM0_A3": "TST", "NAME": "Test", "ISO_A2": "-99", "ISO_A3": "-99",
                "ISO_A2_EH": "-99", "ISO_A3_EH": "-99", "FCLASS_ISO": "Admin-0 country"}
        base.update(overrides)
        return base

    expect(code_entry(row(ISO_A2="BD", ISO_A3="BGD"), {})["code_status"] == "iso-official",
           "a plain pair should be official")
    fixed = code_entry(row(ISO_A2_EH="FR", ISO_A3_EH="FRA"), {})
    expect((fixed["iso_a2"], fixed["iso_a3"]) == ("FR", "FRA"),
           "the corrected fields should be adopted when the plain ones are placeholders")
    expect("ISO_A2_EH" in fixed["source_fields"], "the source field used should be recorded")
    kosovo = code_entry(row(ADM0_A3="KOS", ISO_A2_EH="XK"), {})
    expect(kosovo["code_status"] == "user-assigned", "XK is user-assigned, not official")
    expect(kosovo["iso_a3"] is None, "Kosovo has no three-letter code in the source")
    parent = code_entry(row(ADM0_A3="ATC", ISO_A2_EH="AU", ISO_A3_EH="AUS",
                            FCLASS_ISO="Unrecognized"),
                            {("a2", "AU"): "AUS", ("a3", "AUS"): "AUS"})
    expect(parent["code_status"] == "none", "a parent's code must not be adopted")
    expect(code_entry(row(ISO_A2="CN-TW", ISO_A3="TWN"), {})["iso_a2"] is None,
           "CN-TW is not a two-letter code")
    expect(group_for("Africa", "Western Africa")[0] == "africa_west", "Africa splits")
    expect(group_for("Asia", "Western Asia")[0] == "middle_east", "Western Asia is the Middle East rule")
    expect(group_for("Oceania", "Polynesia")[0] == "oceania", "Oceania is one group")
    try:
        group_for("Atlantis", "Nowhere")
        failures.append("an unknown continent should be an error, not a default")
    except SystemExit:
        pass
    if failures:
        for message in failures:
            print(f"FAIL {message}")
        print(f"self-test: {len(failures)} failures")
        return 1
    print("self-test: ok")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail when output is stale")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv[1:])
    if args.self_test:
        return self_test()

    report = build()
    problems = check(report) if args.check else []
    if problems:
        for problem in problems:
            print(f"error: {problem}", file=sys.stderr)
        return 1
    if not args.check:
        CODES.write_text(dump(report["codes"]), encoding="utf-8", newline="\n")
        REGIONS.write_text(dump(report["regions"]), encoding="utf-8", newline="\n")
        REPORT.write_text(document(report), encoding="utf-8", newline="\n")
        print(f"wrote {CODES.name}, {REGIONS.name} and {REPORT.relative_to(ROOT)}")

    counts: dict[str, int] = {}
    for entry in report["codes"]["records"].values():
        counts[entry["code_status"]] = counts.get(entry["code_status"], 0) + 1
    groups: dict[str, int] = {}
    for entry in report["regions"]["records"].values():
        groups[entry["group"]] = groups.get(entry["group"], 0) + 1
    print(f"codes: {counts}  groups: {len(groups)}  review: {len(report['review'])}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
