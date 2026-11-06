# Montserrat — `MSR`

This folder holds everything WORLD DOMINION knows about **Montserrat** (Montserrat). The folder name is the stable id the game uses everywhere, including in save files.

## What is in here

| File | What it holds |
| --- | --- |
| `identity.json` | Names, codes, region, the source's own `type` and status note |
| `geometry.json` | 1 polygon(s), 7 points, outline bbox and label anchor |
| `statistics.json` | Sourced population and GDP, plus the area derived from the outline |
| `sources.json` | Where the data came from, which commit, licence, how it was processed |
| `README.md` | This page |

## What the source says about this unit

* Region: North America — Caribbean
* Source type: Dependency
* Sovereignty field: United Kingdom
* Status note: U.K.
* Capital: not recorded in the source
* Country codes: MS (two letters) / MSR (three letters) — officially assigned ISO 3166-1 codes

## What is missing, and why

* capital city (the source has no capital for this unit)
* Economy, government, military and society figures: **not collected at all** yet. They are planned systems, and this project does not invent numbers.
* The two sourced figures below are Natural Earth's own estimates, each with the year the source records them for; they are not live and not updated by the game.

## Key figures (baseline reference data, not live)

| Figure | Value | As of |
| --- | --- | --- |
| Population | 4,649 people | 2019 |
| GDP | 44,000,000 US dollars | 2006 |
| Area | 79 km² (derived, approximate) | map outline |

Population and GDP come from the source file named below. The area is **derived** from this record's simplified outline, so it is approximate and is not an official land-area figure; it is labelled as derived wherever the game shows it.

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
