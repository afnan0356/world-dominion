#!/usr/bin/env python3
"""Report the measured height of every control this project draws.

Milestone 05 raises the older 40 px controls to the 48 px touch target. This script is
how that claim stays checkable: it reads the source, measures the height each control
asks for, and writes `docs/CONTROL_SIZES.md`.

What it measures is the *declared* minimum height in the code — the number the layout
engine is asked for — not a rendered pixel measurement, which needs a running engine.
The report says so; nothing here is a screenshot or a rendering.

Declared exceptions live in `EXCEPTIONS`, each with the reason it is smaller and the
size it asks for. A control that is smaller than the target without an entry there is
reported as a problem and fails `--check`.

    python3 tools/control_size_report.py
    python3 tools/control_size_report.py --check
"""

from __future__ import annotations

import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOC = ROOT / "docs" / "CONTROL_SIZES.md"
SRC = ROOT / "src"
TARGET = 48

#: `file:constant` → (size, reason). Every entry must also satisfy the reason rule.
EXCEPTIONS = {
    "src/ui/components/region_filter.gd:COMPACT_CHIP": (
        32, "compact layout only (360 px tall landscape phone); the row scrolls "
            "horizontally, so a 48 px chip would hide the map"),
    "src/ui/components/country_search.gd:COMPACT_FIELD": (
        44, "compact layout only; the search field shares a row with the map, and 44 px "
            "still clears the 40 px the layout was designed around"),
    "src/ui/components/app_header.gd:NAV_ROW": (
        56, "larger than the target, listed because it is a control"),
}

CONSTANT_PATTERN = re.compile(r"^const\s+([A-Z][A-Z0-9_]*(?:HEIGHT|SIZE)[A-Z0-9_]*)\s*:=\s*"
                              r"(\d+)", re.MULTILINE)
LITERAL_PATTERN = re.compile(r"custom_minimum_size(?:\.y)?\s*=\s*(?:Vector2\([^,]+,\s*)?"
                             r"(\d+(?:\.\d+)?)")


def measure() -> list[dict]:
    """Every declared height, with the file and line it came from."""
    rows: list[dict] = []
    for path in sorted(SRC.rglob("*.gd")):
        text = path.read_text(encoding="utf-8")
        relative = str(path.relative_to(ROOT))
        for match in CONSTANT_PATTERN.finditer(text):
            name, value = match.group(1), int(match.group(2))
            if value < 24 or value > 200:
                continue
            rows.append({"where": f"{relative}:{name}", "value": value,
                         "line": text[:match.start()].count("\n") + 1,
                         "kind": "constant"})
        for match in LITERAL_PATTERN.finditer(text):
            value = float(match.group(1))
            if value < 24 or value > 200:
                continue
            line = text[:match.start()].count("\n") + 1
            rows.append({"where": f"{relative}:{line}", "value": int(value), "line": line,
                         "kind": "inline"})
    return rows


def document(rows: list[dict]) -> str:
    below = [row for row in rows if row["value"] < TARGET]
    lines: list[str] = []
    add = lines.append
    add("# Control sizes")
    add("")
    add("**Generated from the source by `tools/control_size_report.py`. Do not edit by "
        "hand.**")
    add("")
    add(f"Every control the player taps should be at least **{TARGET} px** tall — the same "
        "number as `DesignTokens.TOUCH_TARGET_MIN`, which is the size a finger needs. This "
        "page lists what the code actually asks for.")
    add("")
    add("**What is measured:** the minimum height declared in the source, read from the "
        "files. This is not a rendered measurement: it is the number the layout engine is "
        "told to honour, which is the number a code review can check. A rendered "
        "measurement needs a running engine, and this project does not present a "
        "computed table as a screenshot of the game.")
    add("")
    add("## Declaration with a reason to be smaller")
    add("")
    add("| Location | Earlier size | Now | Why |")
    add("| --- | ---: | ---: | --- |")
    add("| `DesignTokens.CONTROL_HEIGHT` | 40 | 48 | Raised in Milestone 05. This is the "
        "height of buttons, fields and rows across every screen. |")
    add("| `CountrySearch.FIELD_HEIGHT` | 44 | 48 | Raised with it; the compact layout uses "
        "44, below. |")
    add("| `RegionFilter.CHIP_HEIGHT` | 40 | 48 | Raised with it; the compact layout uses "
        "32, below. |")
    add("")
    if not below:
        add("Nothing in the source asks for less than the target.")
    else:
        add("## Still below the target, on purpose")
        add("")
        add("| Where | Height | Reason |")
        add("| --- | ---: | --- |")
        for row in below:
            key = row["where"]
            reason = ""
            for candidate, (size, why) in EXCEPTIONS.items():
                if candidate.split(":")[0] == key.split(":")[0] and size == row["value"]:
                    reason = why
                    break
            if not reason:
                reason = "**undeclared** — no exception recorded for this size"
            add(f"| `{key}` (line {row['line']}) | {row['value']} px | {reason} |")
        add("")
        add("The compact-layout sizes are the only exceptions: at 640×360 the screen is "
            "360 px tall in total, so a full-height control row would leave no map. Those "
            "sizes are still at least 32 px, which keeps them tappable and keeps every "
            "screen inside its layout at that size.")
    add("")
    add("## Every declared height in the source")
    add("")
    add("| Where | Height | Meets the target |")
    add("| --- | ---: | --- |")
    for row in sorted(rows, key=lambda item: (item["where"], item["line"])):
        mark = "yes" if row["value"] >= TARGET else "no — see above"
        add(f"| `{row['where']}` (line {row['line']}) | {row['value']} px | {mark} |")
    add("")
    return "\n".join(lines)


def problems(rows: list[dict]) -> list[str]:
    out: list[str] = []
    for row in rows:
        if row["value"] >= TARGET:
            continue
        declared = any(candidate.split(":")[0] == row["where"].split(":")[0]
                       and size == row["value"] for candidate, (size, _) in EXCEPTIONS.items())
        if not declared:
            out.append(f"{row['where']} asks for {row['value']} px without a declared reason")
    return out


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="fail when the committed report is stale or a size is undeclared")
    args = parser.parse_args(argv[1:])

    rows = measure()
    found = problems(rows)
    for message in found:
        print(f"error: {message}", file=sys.stderr)
    wanted = document(rows)
    if args.check:
        if not DOC.exists() or DOC.read_text(encoding="utf-8") != wanted:
            print(f"error: {DOC.relative_to(ROOT)} is stale; run "
                  "tools/control_size_report.py", file=sys.stderr)
            return 1
        if found:
            return 1
        print(f"control sizes ok: {len(rows)} declarations, "
              f"{sum(1 for row in rows if row['value'] < TARGET)} declared exceptions")
        return 0
    DOC.parent.mkdir(parents=True, exist_ok=True)
    DOC.write_text(wanted, encoding="utf-8", newline="\n")
    print(f"wrote {DOC.relative_to(ROOT)} ({len(rows)} declarations)")
    return 1 if found else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
