#!/usr/bin/env python3
"""Classify every geometry ring as coastline, land border or a mix of both.

The map wants a visible hierarchy: a country's sea edge should read heavier than
the seam it shares with its neighbour. Nothing in the source says which is which —
the rings are just outlines — so this tool derives it from the geometry itself:
a segment that appears in **two** records is a shared (land) border, and a
segment that appears in only one is coastline.

Output `data/world/coast.json` is deliberately tiny: one code per ring per
record (`1` = coastline, `0` = shared land border, `2` = mixed), so the whole
file is a few kilobytes and the renderer can choose a stroke without any runtime
analysis. It is a *derived visual aid*: it never changes geometry, hit testing or
any saved value.

Usage:

    python3 tools/build_coast_data.py
    python3 tools/build_coast_data.py --check
"""

from __future__ import annotations

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import country_folders as folders  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDERS_DIR = os.path.join(ROOT, "data/world/countries")
OUT = os.path.join(ROOT, "data/world/coast.json")

METHOD = ("a segment shared by two records is a land border; a segment used by one "
          "record is coastline; quantisation makes shared borders identical, and "
          "segments that do not match exactly are counted as coastline")


def build() -> dict:
    tree = folders.read_folders(FOLDERS_DIR)
    usage: dict[tuple[int, int, int, int], int] = {}
    per_country: dict[str, list[list[tuple[int, int]]]] = {}
    for country_id in tree["ids"]:
        polygons = tree["geometry"][country_id]["polygons"]
        rings: list[list[tuple[int, int]]] = []
        for polygon in polygons:
            for ring in polygon:
                coords = [(ring[index], ring[index + 1]) for index in range(0, len(ring), 2)]
                rings.append(coords)
                for index in range(len(coords) - 1):
                    a, b = coords[index], coords[index + 1]
                    key = (a[0], a[1], b[0], b[1]) if a <= b else (b[0], b[1], a[0], a[1])
                    usage[key] = usage.get(key, 0) + 1
        per_country[country_id] = rings

    codes: dict[str, str] = {}
    summary = {"rings": 0, "fully_coastal": 0, "fully_shared": 0, "mixed": 0,
               "segments": len(usage), "shared_segments": 0}
    for country_id, rings in per_country.items():
        code = []
        for coords in rings:
            coastal = 0
            total = 0
            for index in range(len(coords) - 1):
                a, b = coords[index], coords[index + 1]
                key = (a[0], a[1], b[0], b[1]) if a <= b else (b[0], b[1], a[0], a[1])
                total += 1
                if usage[key] == 1:
                    coastal += 1
            if total == 0:
                code.append("0")
                continue
            if coastal == total:
                code.append("1")
                summary["fully_coastal"] += 1
            elif coastal == 0:
                code.append("0")
                summary["fully_shared"] += 1
            else:
                code.append("2")
                summary["mixed"] += 1
            summary["rings"] += 1
        codes[country_id] = "".join(code)
    summary["shared_segments"] = sum(1 for count in usage.values() if count > 1)
    return {
        "schema": 1,
        "scale": 200,
        "method": METHOD,
        "summary": summary,
        "countries": codes,
    }


def document() -> str:
    return json.dumps(build(), ensure_ascii=False, indent=1) + "\n"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    text = document()
    data = json.loads(text)
    summary = data["summary"]
    if args.check:
        try:
            with open(OUT, encoding="utf-8") as handle:
                committed = handle.read()
        except OSError:
            print("data/world/coast.json is missing; run python3 tools/build_coast_data.py")
            return 1
        if committed != text:
            print("coast.json is stale; run python3 tools/build_coast_data.py")
            return 1
        print(f"coast data is up to date ({summary['rings']} rings, "
              f"{summary['shared_segments']} shared segments)")
        return 0
    with open(OUT, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)
    print(f"wrote data/world/coast.json ({os.path.getsize(OUT) / 1024:.0f} KiB)")
    print(f"  rings {summary['rings']}: {summary['fully_coastal']} fully coastline, "
          f"{summary['fully_shared']} fully land border, {summary['mixed']} mixed")
    print(f"  segments {summary['segments']}, of which {summary['shared_segments']} are shared")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
