# Siachen Glacier — `KAS`

This folder holds everything WORLD DOMINION knows about **Siachen Glacier** (Siachen Glacier). The folder name is the stable id the game uses everywhere, including in save files.

## What is in here

| File | What it holds |
| --- | --- |
| `identity.json` | Names, codes, region, the source's own `type` and status note |
| `geometry.json` | 1 polygon(s), 21 points, outline bbox and label anchor |
| `sources.json` | Where the data came from, which commit, licence, how it was processed |
| `README.md` | This page |

## What the source says about this unit

* Region: Asia — Southern Asia
* Source type: Indeterminate
* Sovereignty field: Kashmir
* Status note: Claimed by Pakistan and India
* Capital: not recorded in the source

## What is missing, and why

* capital city (the source has no capital for this unit)
* ISO alpha-2 code (the source value is not a plain two-letter code)
* ISO alpha-3 code (the source has none for this unit)
* Population, economy, government and military figures: **not collected at all** yet. They are planned systems, and this project does not invent numbers.

## Where it came from

* Dataset: Natural Earth 1:50m Cultural Vectors — Admin 0 Countries
* Repository: `nvkelso/natural-earth-vector` at commit `ca96624a56bd078437bca8184e78163e5039ad19`
* Licence: Public Domain (Natural Earth Terms of Use)
* Retrieved: 2026-11-05

## How this folder was made

1. `tools/fetch_world_atlas.py` downloads the pinned source files (not committed).
2. `tools/build_world_atlas.py` writes this folder from the source, then builds the runtime pack from all the folders.
3. `tools/validate_country_folders.py` checks the tree; CI fails on any drift.

The file is generated. Do not hand-edit it: CI rebuilds the tree and compares bytes.
