#!/usr/bin/env python3
"""Integrity gate for the committed world atlas.

Cheap, dependency-free checks that run in CI before the engine is installed, so a
broken or partial data commit fails fast. The GDScript suites test the same data
far more thoroughly through the game's own loaders; this is the smoke alarm.
"""

import hashlib
import json
import os
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

    # The folders are the human-readable source of truth and the pack is generated
    # from them, so the pack must carry the hashes it was built with and the folder
    # count must agree with the record count.
    folders_dir = "data/world/countries"
    if not os.path.isdir(folders_dir):
        fail("data/world/countries/ is missing: the per-country tree is the source of truth")
    folder_ids = sorted(name for name in os.listdir(folders_dir)
                        if os.path.isdir(os.path.join(folders_dir, name)))
    if sorted(ids) != folder_ids:
        fail("the folders and the pack disagree about which countries exist")
    if int(manifest.get("folders", {}).get("count", -1)) != len(folder_ids):
        fail("the manifest's folder count is stale")
    for key, name in (("countries_sha256", "countries.json"),
                      ("geometry_sha256", "geometry.json")):
        with open(os.path.join("data/world", name), "rb") as handle:
            actual = hashlib.sha256(handle.read()).hexdigest()
        if manifest.get("pack", {}).get(key) != actual:
            fail(f"{name} does not match the hash the manifest records")

    # The renderer's coastline hints are derived from the geometry, so a country's
    # code string must be exactly as long as its ring count, one character per ring.
    coast_path = "data/world/coast.json"
    try:
        with open(coast_path, encoding="utf-8") as handle:
            coast = json.load(handle)
    except OSError as error:
        fail(f"cannot read {coast_path}: {error}")
    except json.JSONDecodeError as error:
        fail(f"{coast_path} is not valid JSON: {error}")
    codes = coast.get("countries")
    if not isinstance(codes, dict):
        fail("coast.json has no 'countries' object")
    if set(codes) - set(ids):
        fail("coast.json names countries the pack does not have")
    for country_id, code_string in codes.items():
        rings = sum(len(polygon) for polygon in geometry[country_id]["polygons"])
        if len(code_string) != rings:
            fail(f"coast.json has {len(code_string)} codes for {country_id}, "
                 f"which has {rings} rings")
        if set(code_string) - {"0", "1", "2"}:
            fail(f"coast.json uses an unknown code for {country_id}")
    if coast.get("summary", {}).get("rings") != sum(
            sum(len(polygon) for polygon in geometry[i]["polygons"]) for i in codes):
        fail("coast.json's ring count is stale")

    print(f"atlas ok: {len(ids)} countries, {len(folder_ids)} folders, "
          f"{manifest['counts']['polygons']} polygons, "
          f"{manifest['counts']['vertices']} vertices")
    return 0


if __name__ == "__main__":
    sys.exit(main())
