#!/usr/bin/env python3
"""Generate the two policy documents the project promises to keep honest.

* `docs/DISPUTED_TERRITORIES.md` — every record whose source `type` is Disputed,
  Indeterminate, Sovereignty or Dependency, listed from the committed data.
* `docs/START_NATIONS.md` — which records a player may start a campaign as, read
  from `data/world/start_eligibility.json`.

Both are generated from the registry and the rule file, never hand-written, so the
lists cannot drift from the data. CI runs `--check` and fails when either document
is stale.

Usage:

    python3 tools/report_policies.py
    python3 tools/report_policies.py --check
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
COUNTRIES = ROOT / "data/world/countries.json"
ELIGIBILITY = ROOT / "data/world/start_eligibility.json"
TERRITORIES_DOC = ROOT / "docs/DISPUTED_TERRITORIES.md"
START_NATIONS_DOC = ROOT / "docs/START_NATIONS.md"

# Types whose status the dataset itself leaves open or subordinate. This is the
# documented list the policy document is built from.
UNCERTAIN_TYPES = ["Disputed", "Indeterminate", "Sovereignty", "Dependency"]


def load() -> tuple[list[dict], dict]:
    countries = json.loads(COUNTRIES.read_text(encoding="utf-8"))["countries"]
    eligibility = json.loads(ELIGIBILITY.read_text(encoding="utf-8"))
    return countries, eligibility


def escape(text: str) -> str:
    return text.replace("|", "\\|")


def territories_document(countries: list[dict]) -> str:
    by_type: dict[str, list[dict]] = {}
    for record in countries:
        by_type.setdefault(str(record.get("type")), []).append(record)

    lines: list[str] = []
    add = lines.append
    add("# Disputed, uncertain and dependent territories")
    add("")
    add("## What this page is for")
    add("")
    add("WORLD DOMINION shows the world exactly as its map data describes it. The map data is a "
        "public-domain dataset called **Natural Earth** (1:50m scale, pinned to one commit — see "
        "[DATA_SOURCES.md](DATA_SOURCES.md)). That dataset labels every unit with a `type`, such as "
        "`Sovereign country`, `Dependency`, `Disputed` or `Indeterminate`.")
    add("")
    add("This project copies those labels and that geometry **without editing them**. It does not "
        "decide where a border should be, and it does not take a side in any sovereignty dispute.")
    add("")
    add("Two plain-English consequences:")
    add("")
    add("1. **This is one dataset's convention.** Another atlas, another government or another "
        "organisation would draw some of these lines and label some of these units differently. "
        "Nothing here is an official position of the project, its owner or its contributors on any "
        "border or sovereignty question.")
    add("2. **Changing it is a data decision, not a code decision.** If the owner later adopts a "
        "different policy, the change belongs in the data pipeline and in this document — not in "
        "`if country == …` code. There is no special-case code for any individual place.")
    add("")
    add("The game also uses these labels for one practical rule: which records a player may start a "
        "campaign as. That rule is separate, explicit and data-driven — see "
        "[START_NATIONS.md](START_NATIONS.md). It is a default for review, not a judgement.")
    add("")
    add("## Every record the source marks as uncertain or dependent")
    add("")
    add("`type` is copied verbatim from the dataset. `id` is the stable identifier used everywhere "
        "in the game.")
    add("")
    for type_name in UNCERTAIN_TYPES:
        records = sorted(by_type.get(type_name, []), key=lambda item: item["name"])
        add(f"### `{type_name}` — {len(records)} record(s)")
        add("")
        if not records:
            add("_None in this dataset._")
            add("")
            continue
        add("| Stable ID | Name | Source type (verbatim) | Region |")
        add("| --- | --- | --- | --- |")
        for record in records:
            add(f"| `{record['id']}` | {escape(record['name'])} | `{escape(record['type'])}` | "
                f"{escape(str(record.get('region')))} |")
        add("")
    add("## How these records are drawn and handled")
    add("")
    add("* Their geometry is drawn exactly as the dataset provides it. No record is merged into a "
        "neighbour, split, renamed, hidden or silently reclassified.")
    add("* The dossier shows the source's `type`, and for records the source marks `Disputed` or "
        "`Indeterminate` it adds one neutral sentence: *Status and boundaries follow the pinned "
        "Natural Earth dataset. That is this dataset's convention, not an official position of this "
        "project on any sovereignty or boundary question.*")
    add("* They can be selected on the map, searched, filtered and read in the dossier.")
    add("* Starting a campaign as one of them is governed by the same data-driven rule as everything "
        "else ([START_NATIONS.md](START_NATIONS.md)). That rule lists `type` values, not places.")
    add("")
    add("## All classification values in this dataset")
    add("")
    add("| Source `type` | Records |")
    add("| --- | --- |")
    for type_name in sorted(by_type, key=lambda name: (-len(by_type[name]), name)):
        add(f"| `{escape(str(type_name))}` | {len(by_type[type_name])} |")
    add("")
    add("## Keeping this page honest")
    add("")
    add("```bash")
    add("python3 tools/report_policies.py          # regenerate this file and START_NATIONS.md")
    add("python3 tools/report_policies.py --check  # CI: fail when either file is stale")
    add("```")
    add("")
    return "\n".join(lines)


def start_nations_document(countries: list[dict], eligibility: dict) -> str:
    eligible_types = [str(item) for item in eligibility.get("eligible_types", [])]
    reason = str(eligibility.get("reason", "Not available as a starting nation in this version."))
    note = str(eligibility.get("note", ""))
    eligible = [record for record in countries if record.get("type") in eligible_types]
    ineligible = [record for record in countries if record.get("type") not in eligible_types]

    lines: list[str] = []
    add = lines.append
    add("# Which countries you can start a campaign as")
    add("")
    add("## The short version")
    add("")
    add(f"Of the **{len(countries)}** records in the world atlas, **{len(eligible)}** can be chosen "
        f"as a starting nation and **{len(ineligible)}** cannot, in this version of the game.")
    add("")
    add("Every record can still be searched, tapped on the map and read in the country dossier. The "
        "rule only decides who you can *play as* when you start a new campaign.")
    add("")
    add("## The rule")
    add("")
    add("A record can be a starting nation when its **source classification** (the `type` field "
        "from the Natural Earth dataset) is one of:")
    add("")
    for type_name in eligible_types:
        add(f"* `{type_name}`")
    add("")
    add(f"Everything else shows this message when selected: *\"{reason}\"*")
    add("")
    add("This is written in the dataset's own classification values. It does not name any individual "
        "place, and it says nothing about whether a place is real, recognised or important — only "
        "that this version does not let you play as it.")
    add("")
    add("**This rule is a default for the owner to review, not a final decision.** It is stored in "
        "one file, `data/world/start_eligibility.json`. To allow more records, add their `type` "
        "value to `eligible_types` in that file; to allow fewer, remove one. No code changes are "
        "needed, and validation will follow immediately.")
    if note:
        add("")
        add(f"> {note}")
    add("")
    add("## Eligible starting nations")
    add("")
    add(f"| Stable ID | Name | Source type | Region |")
    add("| --- | --- | --- | --- |")
    for record in sorted(eligible, key=lambda item: item["name"]):
        add(f"| `{record['id']}` | {escape(record['name'])} | `{escape(str(record.get('type')))}` | "
            f"{escape(str(record.get('region')))} |")
    add("")
    add("## Not eligible in this version")
    add("")
    add("| Stable ID | Name | Source type | Region |")
    add("| --- | --- | --- | --- |")
    for record in sorted(ineligible, key=lambda item: item["name"]):
        add(f"| `{record['id']}` | {escape(record['name'])} | `{escape(str(record.get('type')))}` | "
            f"{escape(str(record.get('region')))} |")
    add("")
    add("## Keeping this page honest")
    add("")
    add("```bash")
    add("python3 tools/report_policies.py          # regenerate this file and DISPUTED_TERRITORIES.md")
    add("python3 tools/report_policies.py --check  # CI: fail when either file is stale")
    add("```")
    add("")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="do not write; fail when a committed document is stale")
    args = parser.parse_args(argv[1:])

    countries, eligibility = load()
    documents = {
        TERRITORIES_DOC: territories_document(countries),
        START_NATIONS_DOC: start_nations_document(countries, eligibility),
    }

    if args.check:
        stale = [path for path, text in documents.items()
                 if not path.exists() or path.read_text(encoding="utf-8") != text]
        for path in stale:
            print(f"stale: {path.relative_to(ROOT)} — run python3 tools/report_policies.py",
                  file=sys.stderr)
        if stale:
            return 1
        print("policy documents are up to date")
        return 0

    for path, text in documents.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        print(f"wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
