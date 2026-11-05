#!/usr/bin/env python3
"""Integrity gate for the committed world atlas.

Cheap, dependency-free checks that run in CI before the engine is installed, so a
broken or partial data commit fails fast. The GDScript suites test the same data
far more thoroughly through the game's own loaders; this is the smoke alarm.
"""

import json
import sys

ATLAS_FILES = {
    "countries": "data/world/countries.json",
    "geometry": "data/world/geometry.json",
    "manifest": "data/world/manifest.json",
}


def fail(message: str) -> None:
    print(f"atlas check failed: {message}")
    sys.exit(1)


def main() -> int:
    data = {}
    for key, path in ATLAS_FILES.items():
        try:
            with open(path, encoding="utf-8") as handle:
                data[key] = json.load(handle)
        except OSError as error:
            fail(f"cannot read {path}: {error}")
        except json.JSONDecodeError as error:
            fail(f"{path} is not valid JSON: {error}")

    countries = data["countries"]["countries"]
    geometry = data["geometry"]["countries"]
    manifest = data["manifest"]

    ids = [entry["id"] for entry in countries]
    if len(ids) < 200:
        fail(f"only {len(ids)} countries")
    if len(set(ids)) != len(ids):
        fail("duplicate country ids")
    if set(ids) != set(geometry):
        fail("the registry and the geometry disagree about which countries exist")
    if manifest["counts"]["countries"] != len(ids):
        fail("the manifest's country count is stale")
    if manifest["counts"]["vertices"] < 50000:
        fail("the geometry looks truncated")
    source = manifest["source"]
    for key in ("dataset", "repository", "commit", "version", "licence", "url", "retrieved"):
        if not str(source.get(key, "")).strip():
            fail(f"the manifest is missing '{key}'")
    if "Public Domain" not in source["licence"]:
        fail("the licence is not recorded as public domain")
    if not manifest.get("known_limitations"):
        fail("the manifest must record the dataset's known limitations")

    print(f"atlas ok: {len(ids)} countries, "
          f"{manifest['counts']['polygons']} polygons, "
          f"{manifest['counts']['vertices']} vertices")
    return 0


if __name__ == "__main__":
    sys.exit(main())
