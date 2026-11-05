#!/usr/bin/env python3
"""Fetch the pinned Natural Earth source files for the world atlas.

The atlas is generated from two Natural Earth 1:50m GeoJSON files at a pinned commit.
This script downloads exactly that commit's bytes, verifies nothing about them beyond
their checksums, writes them to `data/source/` (not committed) and prints the
checksums so a build can be reproduced and compared.

Only the GitHub REST API is used, because the build environment that produced the
atlas can reach `api.github.com` but not `raw.githubusercontent.com` or
`naturalearthdata.com`. Files are fetched through the Git blobs API, which serves
base64 for large objects where the contents API would refuse them.

Usage:

    python3 tools/fetch_world_atlas.py                       # fetch into data/source
    python3 tools/fetch_world_atlas.py --source-dir /tmp/ne
    python3 tools/build_world_atlas.py --source-dir data/source
"""

from __future__ import annotations

import argparse
import base64
import json
import pathlib
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
API = "https://api.github.com"

# Pinned in data/world/manifest.json. Update both together, then rebuild and
# re-run the validator, or the atlas and its provenance disagree.
REPOSITORY = "nvkelso/natural-earth-vector"
COMMIT = "ca96624a56bd078437bca8184e78163e5039ad19"
FILES = (
    "geojson/ne_50m_admin_0_countries.geojson",
    "geojson/ne_50m_populated_places_simple.geojson",
)


def get(url: str) -> dict:
    request = urllib.request.Request(url, headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "world-dominion-atlas-fetch",
    })
    with urllib.request.urlopen(request, timeout=120) as response:
        return json.loads(response.read().decode("utf-8"))


def tree_entries() -> dict[str, dict]:
    tree = get(f"{API}/repos/{REPOSITORY}/git/trees/{COMMIT}?recursive=1")
    if tree.get("truncated"):
        print("warning: GitHub truncated the tree listing; still looking up known paths",
              file=sys.stderr)
    return {entry["path"]: entry for entry in tree.get("tree", [])
            if entry.get("type") == "blob"}


def fetch(path: str, entry: dict) -> bytes:
    blob = get(f"{API}/repos/{REPOSITORY}/git/blobs/{entry['sha']}")
    if blob.get("encoding") != "base64":
        raise SystemExit(f"{path}: unexpected blob encoding {blob.get('encoding')!r}")
    data = base64.b64decode(blob["content"])
    if entry.get("size") and len(data) != entry["size"]:
        raise SystemExit(f"{path}: expected {entry['size']} bytes, got {len(data)}")
    return data


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", default="data/source",
                        help="where to write the source GeoJSON (not committed)")
    args = parser.parse_args(argv[1:])

    target = pathlib.Path(args.source_dir)
    if not target.is_absolute():
        target = ROOT / target
    target.mkdir(parents=True, exist_ok=True)

    entries = tree_entries()
    checksums = []
    for path in FILES:
        entry = entries.get(path)
        if entry is None:
            print(f"error: {path} is missing from commit {COMMIT[:10]}", file=sys.stderr)
            return 1
        data = fetch(path, entry)
        destination = target / pathlib.Path(path).name
        destination.write_bytes(data)
        import hashlib
        digest = hashlib.sha256(data).hexdigest()
        checksums.append((destination.name, len(data), digest))
        print(f"fetched {destination.name} ({len(data) // 1024} KiB) sha256 {digest}")

    lock = target / "CHECKSUMS.txt"
    lock.write_text("\n".join(f"{name}  {size}  {digest}"
                              for name, size, digest in checksums) + "\n", encoding="utf-8")
    print(f"wrote {lock.relative_to(ROOT) if lock.is_relative_to(ROOT) else lock}")
    print(f"source commit {COMMIT}")
    print("next: python3 tools/build_world_atlas.py --source-dir "
          f"{args.source_dir} --out data/world --retrieved YYYY-MM-DD")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
