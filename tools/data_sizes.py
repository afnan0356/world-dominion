#!/usr/bin/env python3
"""Keep the data-size table in `docs/PERFORMANCE.md` true.

Documented sizes rot faster than any other number: a data file grows by a few kilobytes
and the page quietly keeps claiming the old figure. This tool owns the table between two
markers and CI compares it on every push, so the sizes on that page are the sizes of the
committed files and nothing else.

It reports two groups, because the distinction matters: the files the game **loads** at
startup, and the crosswalks that only the build reads.

Usage:

    python3 tools/data_sizes.py            # rewrite the block in docs/PERFORMANCE.md
    python3 tools/data_sizes.py --check    # fail when the block is stale
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORLD = ROOT / "data" / "world"
DOC = ROOT / "docs" / "PERFORMANCE.md"

START = "<!-- data-sizes:start -->"
END = "<!-- data-sizes:end -->"

# What the game reads. The atlas loads exactly these, once, when the world starts.
RUNTIME = ("countries.json", "geometry.json", "coast.json", "manifest.json",
           "statistics.json", "currency.json")
# What only the build reads.
BUILD_ONLY = ("currency_crosswalk.json", "flag_crosswalk.json", "iso_codes_crosswalk.json",
              "picker_regions.json", "start_eligibility.json", "statistics_crosswalk.json")


def size_of(name: str) -> int:
    path = WORLD / name
    if not path.is_file():
        raise SystemExit(f"missing data file: {path}")
    return path.stat().st_size


def kib(count: int) -> str:
    """Kilobytes, rounded, with a thin-space thousands separator as the rest of the docs use.

    Anything under a kilobyte is reported in bytes: rounding 419 bytes to "0 KiB" would be
    a figure that says nothing.
    """
    if count < 1024:
        return f"{count} B"
    value = f"{int(round(count / 1024.0)):,}".replace(",", " ")
    return f"{value} KiB"


def block() -> str:
    runtime = {name: size_of(name) for name in RUNTIME}
    build_only = {name: size_of(name) for name in BUILD_ONLY}
    runtime_total = sum(runtime.values())
    build_total = sum(build_only.values())
    lines = [START, "| File | Bytes | Size | Loaded at startup |", "| --- | --- | --- | --- |"]
    for name in RUNTIME:
        lines.append(f"| `data/world/{name}` | {runtime[name]:,} | {kib(runtime[name])} | yes |")
    lines.append(f"| **Runtime pack total** | **{runtime_total:,}** | **{kib(runtime_total)}** "
                 f"(≈{runtime_total / 1048576.0:.2f} MiB) | — |")
    for name in BUILD_ONLY:
        lines.append(f"| `data/world/{name}` | {build_only[name]:,} | {kib(build_only[name])} "
                     f"| no |")
    lines.append(f"| **Build-time crosswalks total** | **{build_total:,}** | "
                 f"**{kib(build_total)}** | — |")
    lines.append(END)
    return "\n".join(lines)


def replace_block(text: str) -> str:
    start = text.find(START)
    end = text.find(END)
    if start < 0 or end < start:
        raise SystemExit(f"{DOC.relative_to(ROOT)} has no data-sizes markers")
    return text[:start] + block() + text[end + len(END):]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__ or "")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    text = DOC.read_text(encoding="utf-8")
    wanted = replace_block(text)
    if args.check:
        if wanted != text:
            print("docs/PERFORMANCE.md: the data-size table is stale "
                  "(run python3 tools/data_sizes.py)")
            return 1
        print(f"data sizes ok: {len(RUNTIME)} runtime files, {len(BUILD_ONLY)} build-only")
        return 0
    DOC.write_text(wanted, encoding="utf-8", newline="\n")
    print(f"wrote the data-size table into {DOC.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
