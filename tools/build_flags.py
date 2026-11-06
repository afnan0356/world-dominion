#!/usr/bin/env python3
"""Build the committed flag crosswalk, and copy only the flags it maps.

The source is lipis/flag-icons, pinned:
    version  v7.6.0
    commit   0d8909b00aa8418802a5abf2afa82356b129a7ef
    licence  MIT (see THIRD_PARTY_LICENSES.md)
    retrieved 2026-11-06

The crosswalk is the single place that says "this record, this code, this file". A record
gets a flag only when it has an ISO 3166-1 alpha-2 code **and** the source ships a file for
that code. Everything else is reported as flagless, and the interface shows a neutral code
badge for it — no parent country's flag, no guessed one.

Usage:
    tools/build_flags.py --source /path/to/flag-icons-7.6.0 [--check]
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COUNTRIES = ROOT / "data" / "world" / "countries.json"
CROSSWALK = ROOT / "data" / "world" / "flag_crosswalk.json"
ASSET_DIR = ROOT / "assets" / "flags" / "4x3"

SOURCE_VERSION = "v7.6.0"
SOURCE_COMMIT = "0d8909b00aa8418802a5abf2afa82356b129a7ef"
SOURCE_URL = "https://github.com/lipis/flag-icons"
RETRIEVED = "2026-11-06"
RATIO = 4.0 / 3.0


def is_four_by_three(text: str) -> bool:
    """True when the SVG declares a viewBox whose width is four thirds of its height."""
    match = re.search(r'viewBox\s*=\s*"([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)"',
                      text)
    if not match:
        return False
    width, height = float(match.group(3)), float(match.group(4))
    if height <= 0:
        return False
    return abs(width / height - RATIO) < 1e-6


def build(source: Path) -> tuple[dict, list[dict], list[str]]:
    flags = source / "flags" / "4x3"
    if not flags.is_dir():
        raise SystemExit(f"no flags/4x3 folder in {source}")
    document = json.loads(COUNTRIES.read_text(encoding="utf-8"))
    records = document["countries"]
    mapping: dict[str, dict] = {}
    flagless: list[dict] = []
    for record in records:
        code = (record.get("iso_a2") or "").upper()
        if not code:
            flagless.append({"id": record["id"], "reason": "no alpha-2 code"})
            continue
        candidate = flags / f"{code.lower()}.svg"
        if not candidate.is_file():
            flagless.append({"id": record["id"], "reason": f"the source has no {code}.svg"})
            continue
        text = candidate.read_text(encoding="utf-8", errors="replace")
        if not is_four_by_three(text):
            flagless.append({"id": record["id"],
                             "reason": f"{code}.svg does not declare a 4:3 viewBox"})
            continue
        mapping[record["id"]] = {
            "iso_a2": code,
            "file": f"4x3/{code.lower()}.svg",
            "source": SOURCE_VERSION,
        }
    document = {
        "format": "world-dominion-flag-crosswalk",
        "schema_version": 1,
        "source": {
            "name": "lipis/flag-icons",
            "url": SOURCE_URL,
            "version": SOURCE_VERSION,
            "commit": SOURCE_COMMIT,
            "licence": "MIT",
            "retrieved": RETRIEVED,
            "aspect": "4:3 viewBox, as published",
            "files_used": "flags/4x3/*.svg, unmodified",
        },
        "matched_count": len(mapping),
        "record_count": len(records),
        "flags": mapping,
        "flagless": flagless,
    }
    return document, flagless, sorted({entry["file"].split("/")[1] for entry in mapping.values()})


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, help="unpacked flag-icons release")
    parser.add_argument("--check", action="store_true",
                        help="fail if the committed crosswalk is out of date")
    args = parser.parse_args()

    document, flagless, filenames = build(Path(args.source))
    text = json.dumps(document, indent=2, ensure_ascii=False) + "\n"
    if args.check:
        if not CROSSWALK.is_file():
            print("flag crosswalk is missing", file=sys.stderr)
            return 1
        if CROSSWALK.read_text(encoding="utf-8") != text:
            print("flag crosswalk is out of date; run tools/build_flags.py", file=sys.stderr)
            return 1
        print(f"flag crosswalk is up to date ({document['matched_count']} flags, "
              f"{len(flagless)} flagless records)")
        return 0

    CROSSWALK.write_text(text, encoding="utf-8")
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    for existing in ASSET_DIR.glob("*.svg"):
        if existing.name not in filenames:
            existing.unlink()
    for filename in filenames:
        shutil.copyfile(Path(args.source) / "flags" / "4x3" / filename,
                        ASSET_DIR / filename)
    print(f"wrote {CROSSWALK.relative_to(ROOT)} and {len(filenames)} SVGs to "
          f"{ASSET_DIR.relative_to(ROOT)}")
    print(f"{len(flagless)} records have no flag and will show a code badge")
    return 0


if __name__ == "__main__":
    sys.exit(main())
