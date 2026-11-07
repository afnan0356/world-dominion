#!/usr/bin/env python3
"""Fetch the pinned game-icons commit, commit the icons the interface uses, and keep the
crosswalk honest.

Why a tool rather than a hand copy:

* **Attribution is not optional.** Every icon is CC BY 3.0 (or CC0 where the source's own
  licence file says so), and the credit has to name the author of *that* icon. A hand-built
  crosswalk drifts the first time somebody adds an icon and forgets the author, so the file is
  generated from the source manifest and a test checks it.
* **The licence is re-read at download time.** The pinned commit's `license.txt` is fetched
  with the icons and its per-author CC0 exceptions are applied to the recorded licence. If the
  file ever says something else, the tool refuses to write with that assumption unexamined:
  every author the manifest names must appear in the licence file, and the file must still
  describe CC BY / CC0.
* **The bytes are reproducible.** Icons are copied with exactly one change: the full-bleed
  background rectangle is removed so the mark tints with the theme. `--check` re-fetches the
  pinned commit and compares the committed file with the recomputed one, so a hand-edited or
  stale icon fails CI.

Usage:

    python3 tools/build_icons.py           # write assets/ and the crosswalk
    python3 tools/build_icons.py --check   # fail when either is stale
    python3 tools/build_icons.py --self-test
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import re
import sys
import tarfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "data" / "ui" / "icon_sources.json"
CROSSWALK = ROOT / "data" / "ui" / "icon_crosswalk.json"
ASSET_ROOT = ROOT / "assets" / "icons" / "game_icons"
TARBALL = "https://codeload.github.com/game-icons/icons/tar.gz/{commit}"
LICENCE_TEXT = "https://raw.githubusercontent.com/game-icons/icons/{commit}/license.txt"
# The fetch the tool makes when it needs the licence file from a place raw.githubusercontent is
# unreachable; the tarball above carries the same file, so the tarball is the only network call
# in practice.
MAX_ICON_BYTES = 12_000
MAX_TOTAL_BYTES = 400_000
BACKGROUND = re.compile(r'<path d="M0 0h512v512H0z"\s*/>')


class IconsError(RuntimeError):
    """A problem the tool refuses to paper over."""


def load_manifest() -> dict:
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    for key in ("pinned_commit", "authors", "icons", "attribution_format"):
        if key not in data:
            raise IconsError(f"icon manifest has no {key}")
    if len(data["icons"]) < 1:
        raise IconsError("icon manifest lists no icons")
    return data


def fetch_tree(commit: str) -> dict[str, bytes]:
    """Every file of the pinned commit, keyed by `author/name.svg`."""
    url = TARBALL.format(commit=commit)
    with urllib.request.urlopen(url, timeout=120) as response:  # noqa: S310 - fixed host
        blob = response.read()
    out: dict[str, bytes] = {}
    with tarfile.open(fileobj=io.BytesIO(blob), mode="r:gz") as archive:
        for member in archive.getmembers():
            if not member.isfile():
                continue
            parts = member.name.split("/", 1)
            if len(parts) != 2:
                continue
            out[parts[1]] = archive.extractfile(member).read()
    if "license.txt" not in out:
        raise IconsError("the pinned commit has no license.txt")
    return out


def licence_facts(licence_text: str, authors: dict) -> dict:
    """The licence file's own words: who is listed, and who is marked CC0."""
    text = licence_text.decode("utf-8", "replace")
    lowered = text.lower()
    if "creative commons 3.0 by" not in lowered:
        raise IconsError("license.txt does not describe Creative Commons 3.0 BY")
    cc0: set[str] = set()
    listed: dict[str, str] = {}
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped.startswith("- "):
            continue
        body = stripped[2:]
        name = body.split(",", 1)[0].strip()
        if name.lower().endswith(" - cc0"):
            name = name[: -len(" - cc0")].strip()
            cc0.add(name.lower())
        listed[name.lower()] = body
    missing = [entry["name"] for entry in authors.values()
               if entry["name"].lower() not in listed]
    if missing:
        raise IconsError("license.txt does not list these authors: " + ", ".join(missing))
    return {"cc0": cc0, "listed": listed}


def strip_background(svg: bytes) -> bytes:
    """The one permitted edit: remove the 512x512 background rectangle."""
    text = svg.decode("utf-8")
    if BACKGROUND.search(text) is None:
        raise IconsError("icon has no full-bleed background path to remove")
    stripped = BACKGROUND.sub("", text, count=1)
    return stripped.encode("utf-8")


def build_asset(author: str, name: str, tree: dict[str, bytes]) -> bytes:
    key = f"{author}/{name}"
    if key not in tree:
        raise IconsError(f"{key} is not in the pinned commit")
    return strip_background(tree[key])


def crosswalk_for(manifest: dict, tree: dict[str, bytes], facts: dict) -> dict:
    entries: dict[str, dict] = {}
    total = 0
    for item in manifest["icons"]:
        meaning = item["meaning"]
        if meaning in entries:
            raise IconsError(f"meaning '{meaning}' is listed twice")
        source = item["source"]
        if "/" not in source:
            raise IconsError(f"{meaning}: source must be 'author/name.svg'")
        author_key, name = source.split("/", 1)
        if author_key not in manifest["authors"]:
            raise IconsError(f"{meaning}: author '{author_key}' is not declared")
        asset = build_asset(author_key, name, tree)
        if len(asset) > MAX_ICON_BYTES:
            raise IconsError(f"{meaning}: {len(asset)} bytes exceeds the {MAX_ICON_BYTES} budget")
        total += len(asset)
        author = manifest["authors"][author_key]
        licence = author["licence"]
        if author["name"].lower() in facts["cc0"]:
            licence = "CC0"
        elif licence != "CC BY 3.0":
            raise IconsError(f"{meaning}: {author['name']} is CC BY 3.0 in the licence file "
                             f"but the manifest says {licence}")
        entries[meaning] = {
            "source": source,
            "author": author["name"],
            "author_url": author["url"],
            "licence": licence,
            "file": f"res://assets/icons/game_icons/{author_key}/{name}",
            "sha256": hashlib.sha256(asset).hexdigest(),
            "bytes": len(asset),
            "shape": item["shape"],
        }
    if total > MAX_TOTAL_BYTES:
        raise IconsError(f"the icon set is {total} bytes, over the {MAX_TOTAL_BYTES} budget")
    authors = sorted({entry["author"] for entry in entries.values()})
    return {
        "schema": 2,
        "note": ("Generated by tools/build_icons.py from data/ui/icon_sources.json. Do not "
                 "edit by hand: run the tool."),
        "repository": manifest["repository"],
        "pinned_commit": manifest["pinned_commit"],
        "attribution_format": manifest["attribution_format"],
        "authors": {name: manifest["authors"][key]["url"]
                    for key, name in ((k, v["name"]) for k, v in manifest["authors"].items())
                    if name in authors},
        "total_bytes": total,
        "icons": entries,
    }


def write_outputs(manifest: dict, tree: dict[str, bytes], facts: dict) -> dict:
    crosswalk = crosswalk_for(manifest, tree, facts)
    for item in manifest["icons"]:
        author_key, name = item["source"].split("/", 1)
        asset = build_asset(author_key, name, tree)
        target = ASSET_ROOT / author_key / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(asset)
    CROSSWALK.write_text(json.dumps(crosswalk, indent=2, sort_keys=True) + "\n",
                         encoding="utf-8")
    return crosswalk


def check_outputs(manifest: dict, tree: dict[str, bytes], facts: dict) -> list[str]:
    problems: list[str] = []
    fresh = crosswalk_for(manifest, tree, facts)
    committed_raw = CROSSWALK.read_text(encoding="utf-8") if CROSSWALK.exists() else ""
    if committed_raw != json.dumps(fresh, indent=2, sort_keys=True) + "\n":
        problems.append("data/ui/icon_crosswalk.json is stale: run tools/build_icons.py")
    for item in manifest["icons"]:
        author_key, name = item["source"].split("/", 1)
        asset = build_asset(author_key, name, tree)
        target = ASSET_ROOT / author_key / name
        if not target.exists():
            problems.append(f"missing icon file {target.relative_to(ROOT)}")
        elif target.read_bytes() != asset:
            problems.append(f"{target.relative_to(ROOT)} differs from the pinned commit")
    return problems


def self_test() -> int:
    """The rules that keep the set honest, checked without a network call."""
    try:
        strip_background(b'<svg><path d="M0 0h512v512H0z"/><path fill="#fff" d="M1 1"/></svg>')
    except IconsError:
        print("self-test FAILED: a normal icon was refused")
        return 1
    try:
        strip_background(b'<svg><path d="M1 1"/></svg>')
    except IconsError:
        pass
    else:
        print("self-test FAILED: an icon without a background path was accepted")
        return 1
    facts = licence_facts(b"Icons provided under the Creative Commons 3.0 BY or CC0 if "
                          b"mentioned below.\n\n- Lorc, http://x\n- Zeromancer - CC0\n",
                          {"a": {"name": "Lorc"}, "b": {"name": "Zeromancer"}})
    if facts["cc0"] != {"zeromancer"}:
        print("self-test FAILED: the CC0 exception was not read")
        return 1
    try:
        licence_facts(b"- Lorc, http://x\n", {"a": {"name": "Nobody"}})
    except IconsError:
        pass
    else:
        print("self-test FAILED: an unlisted author was accepted")
        return 1
    manifest = load_manifest()
    meanings = [item["meaning"] for item in manifest["icons"]]
    if len(meanings) != len(set(meanings)):
        print("self-test FAILED: the manifest lists a meaning twice")
        return 1
    print(f"self-test ok: {len(meanings)} meanings, background stripping, CC0 exceptions")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="fail when the committed icons or crosswalk are stale")
    parser.add_argument("--self-test", action="store_true",
                        help="check the tool's own rules without a network call")
    parser.add_argument("--report", action="store_true",
                        help="print the set's size and authorship")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    try:
        manifest = load_manifest()
        tree = fetch_tree(manifest["pinned_commit"])
        facts = licence_facts(tree["license.txt"], manifest["authors"])
        if args.report:
            crosswalk = crosswalk_for(manifest, tree, facts)
            print(f"{len(crosswalk['icons'])} icons from {len(crosswalk['authors'])} authors, "
                  f"{crosswalk['total_bytes']} bytes total, commit "
                  f"{manifest['pinned_commit'][:7]}")
            for name, url in sorted(crosswalk["authors"].items()):
                print(f"  {name}{' — ' + url if url else ''}")
            return 0
        if args.check:
            problems = check_outputs(manifest, tree, facts)
            if problems:
                for problem in problems:
                    print(f"icon check: {problem}", file=sys.stderr)
                return 1
            print(f"icons ok: {len(manifest['icons'])} icons match the pinned commit "
                  f"{manifest['pinned_commit'][:7]}")
            return 0
        crosswalk = write_outputs(manifest, tree, facts)
        print(f"wrote {len(crosswalk['icons'])} icons and the crosswalk "
              f"({crosswalk['total_bytes']} bytes)")
        return 0
    except IconsError as error:
        print(f"icon build failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
