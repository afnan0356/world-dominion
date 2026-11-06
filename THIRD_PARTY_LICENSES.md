# Third-party licences

World Dominion's own code, text, artwork and audio are covered by `LICENSE` (all rights
reserved, source available). This file lists everything in the repository that is **not**
the project's own work, with the licence it comes under. It is the place to look before
reusing anything from this repository.

Two rules govern this file:

1. **Nothing enters the repository without a licence recorded here first.** A font, an icon
   set, a sound, a data file: if its licence is not written down here, it does not ship.
2. **The map data is public domain and stays public domain.** This project's licence cannot
   and does not restrict it; see the note under Natural Earth.

---

## Godot Engine

| | |
| --- | --- |
| What | The engine this game runs on |
| Used by | Every build. Pinned to `4.6.3.stable.custom_build` |
| Licence | MIT |
| Copyright | Copyright (c) 2007-2026 Juan Linietsky, Ariel Manzur and the Godot community |
| Text | https://godotengine.org/license |

Godot's MIT licence permits commercial use, modification and redistribution, provided the
copyright notice and permission notice travel with the software and its binaries. The
engine's own third-party components (FreeType, HarfBuzz, ICU, libpng, zlib, mbedTLS and
others) are listed in the engine's `COPYRIGHT.txt` and are satisfied by the attribution
that ships inside every Godot binary. **The project bundles no engine source of its own
modification**, so no extra notice is required beyond this entry and the About screen's
credit.

The engine's bundled default font is part of Godot and covered by that MIT licence. The
project ships **no additional fonts**: it draws its interface with the engine's default
font, which is why there is no font entry below.

## Fonts

| | |
| --- | --- |
| What | Spectral (300, 400), IBM Plex Sans (400, 500, 600) and IBM Plex Mono (400, 500), Latin subsets as `woff2` |
| Where | `assets/fonts/<family>/` with each family's `OFL.txt` beside it |
| Licence | **SIL Open Font License 1.1** |
| Copyright | Spectral — Copyright 2017 The Spectral Project Authors. IBM Plex — Copyright 2017 IBM Corp., with Reserved Font Name "Plex". |
| Text | `assets/fonts/spectral/OFL.txt`, `assets/fonts/ibm_plex_sans/OFL.txt`, `assets/fonts/ibm_plex_mono/OFL.txt` |

The OFL permits bundling and embedding in a game, including a commercial one, provided the
licence travels with the font, the fonts are not sold on their own, and any modified version
is not distributed under the reserved names. **The font files here are unmodified upstream
builds** (the `woff2` files as published), so the reserved names are not an issue; the
licence text ships in the same folder as each family, which is where a reviewer will look.
The game's own interface code references these files and does not alter them.

## Natural Earth — the map data

| | |
| --- | --- |
| What | Country outlines, capital-city points, region and subregion labels, ISO code fields, population and GDP estimates |
| Files | `data/world/geometry.json`, `data/world/coast.json`, `data/world/countries.json`, `data/world/countries/*/`, `data/world/statistics.json`, `data/world/iso_codes_crosswalk.json`, `data/world/picker_regions.json` — all **derived** from the pinned source below |
| Dataset | Natural Earth 1:50m Cultural Vectors — Admin 0 Countries (and Populated Places, simple, for capitals) |
| Repository | https://github.com/nvkelso/natural-earth-vector |
| Commit | `ca96624a56bd078437bca8184e78163e5039ad19` (version `5.2.0-pre`) |
| Retrieved | 2026-11-05 |
| Licence | **Public Domain** — Natural Earth Terms of Use |
| Attribution (given, not required) | "Made with Natural Earth. Free vector and raster map data." |

Natural Earth's terms state that all versions of its raster and vector map data are in the
public domain, that no permission is needed to use them, and that credit is requested but
not required. The project gives the credit anyway, in the About screens and in
`docs/DATA_SOURCES.md`, because a map that cannot be traced back to its bytes is a map
nobody can check.

**The derived files are ours; the data in them is not.** The simplification, rounding,
folder structure, crosswalks and reports in `data/world/` are produced by this project's
own tools and are covered by `LICENSE` as part of the software. The geographic facts and
the code fields inside them come from the public domain and remain public domain: nobody
can restrict your use of the Natural Earth data itself, including the subset embedded here.

`data/world/statistics.json` also carries population and GDP values that Natural Earth
itself copies from external estimates, with the year of each value recorded:
`POP_YEAR` and `GDP_YEAR` (2019 for the pinned release). The project reproduces them as
reference data and labels them as estimates; it does not present them as current figures or
as its own measurements. Area figures are **derived by this project** from the simplified
1:50m outline, so they are approximate and labelled "derived" wherever they are shown.

## What is not here

No third-party art, icon set, sound effect, music track, UI kit, map tile service or database
has been bundled, and no font beyond the three families above (which are unmodified upstream
builds). Every image in the game is drawn by code; the interface is built
from the engine's own controls; there is no network access of any kind at runtime. If that
ever changes, this file gains an entry **before** the asset is committed, and the pull
request that adds it must say what it is and where its licence was read.

## Reporting a licensing problem

If you believe something in this repository is used without the licence it needs, please
open an issue on the repository page and say which file, which licence you think applies,
and where you read that licence. It will be treated as a defect, not a discussion.
