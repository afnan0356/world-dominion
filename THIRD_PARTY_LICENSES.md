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

## Country flags — flag-icons

| | |
| --- | --- |
| What | The 4:3 country flag SVGs, one per ISO 3166-1 alpha-2 code, used by the country picker |
| Source | https://github.com/lipis/flag-icons |
| Version | **v7.6.0**, release commit `0d8909b00aa8418802a5abf2afa82356b129a7ef` |
| Retrieved | 2026-11-06, from `https://codeload.github.com/lipis/flag-icons/tar.gz/refs/tags/v7.6.0` |
| Licence | MIT |
| Copyright | Copyright (c) 2013 Panayiotis Lipiridis |
| Files kept | only `flags/4x3/*.svg` files named by `data/world/flag_crosswalk.json`, under `assets/flags/4x3/` |

Only the SVGs that the game actually maps to a record are copied in, and they are the
source's own files, unmodified. They are rasterised at run time at the size the interface
needs; no raster copies are committed. A record with no flag file, or with no code to look
one up by, shows a neutral badge with its code — the game never guesses a flag, and never
borrows a parent country's flag for a territory.

Licence text, as published by the source:

```
The MIT License (MIT)

Copyright (c) 2013 Panayiotis Lipiridis

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Currency data — Unicode CLDR

| | | |
| --- | --- | --- |
| What | Which currency each record uses, and its English name and symbol |
| Source | https://github.com/unicode-org/cldr |
| Packages | `cldr-core` **48.0.0** (`supplemental/currencyData.json`) and `cldr-numbers-full` **48.0.0** (`main/en/currencies.json`), via `https://registry.npmjs.org/` |
| Retrieved | 2026-11-07 |
| Licence | **Unicode License v3** |
| Copyright | Copyright © 2004–2025 Unicode, Inc. |
| Files kept | not committed; the download lives in `data/source/cldr-48.0.0/`, which is ignored, and only the derived `currency.json` files are committed |

Only two things are taken from the source: the currency CLDR records as current for a
region (the history entry with no end date that is not marked `tender: false`), and that
currency's English display name and symbol. No rate, price or forecast is copied, and
nothing is inferred for a record the source cannot answer for — those say "Not available"
and the reason is recorded in `data/world/currency_crosswalk.json`.

Licence, as published by the source (`UNICODE-LICENSE-V3.txt` in the download):

```
UNICODE LICENSE V3

COPYRIGHT AND PERMISSION NOTICE

Copyright © 2004-2025 Unicode, Inc.

NOTICE TO USER: Carefully read the following legal agreement. BY
DOWNLOADING, INSTALLING, COPYING OR OTHERWISE USING DATA FILES, AND/OR
SOFTWARE, YOU UNEQUIVOCALLY ACCEPT, AND AGREE TO BE BOUND BY, ALL OF THE
TERMS AND CONDITIONS OF THIS AGREEMENT. IF YOU DO NOT AGREE, DO NOT
DOWNLOAD, INSTALL, COPY, DISTRIBUTE OR USE THE DATA FILES OR SOFTWARE.

Permission is hereby granted, free of charge, to any person obtaining a
copy of data files and any associated documentation (the "Data Files") or
software and any associated documentation (the "Software") to deal in the
Data Files or Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, and/or sell
copies of the Data Files or Software, and to permit persons to whom the
Data Files or Software are furnished to do so, provided that either (a)
this copyright and permission notice appear with all copies of the Data
Files or Software, or (b) this copyright and permission notice appear in
associated Documentation.

THE DATA FILES AND SOFTWARE ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF
THIRD PARTY RIGHTS. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS
INCLUDED IN THIS NOTICE BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT
OR CONSEQUENTIAL DAMAGES, OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF
USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THE DATA FILES OR SOFTWARE.

Except as contained in this notice, the name of a copyright holder shall
not be used in advertising or otherwise to promote the sale, use or other
dealings in these Data Files or Software without prior written
authorization of the copyright holder.
```

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

## Icons — game-icons.net, CC BY 3.0 (added in Milestone 11)

| | |
| --- | --- |
| What | 61 interface icons (SVG) |
| Where | `assets/icons/game_icons/<author>/<name>.svg` |
| Source | `https://github.com/game-icons/icons`, the same set published on https://game-icons.net |
| Pinned commit | `82d948812bfe3f269ef8f731dcdb07b08160edc4` (2026-04-23) |
| Licence file | `license.txt` in that commit, reproduced in full below |
| Licence | CC BY 3.0 for every author except Zeromancer, whose licence file entry says CC0 |
| How it was verified | Downloaded here from `codeload.github.com` at the pinned commit on 2026-11-07; the licence file was read from that same download, not from memory or a mirror |
| Authors used | Delapouite, Guard13007, Lorc, Sbed, Skoll, Zeromancer |

### The licence file, reproduced in full

The text below is the complete `license.txt` of the pinned commit, copied without editing. It
is the authority for the two CC0 exceptions and for the credit wording.

```text
Icons provided under the Creative Commons 3.0 BY or CC0 if mentioned below.

Each sub-folders in this archive correspond to a different contributor :

- Lorc, http://lorcblog.blogspot.com
- Delapouite, http://delapouite.com
- John Colburn, http://ninmunanmu.com
- Felbrigg, http://blackdogofdoom.blogspot.co.uk
- John Redman, http://www.uniquedicetowers.com
- Carl Olsen, https://twitter.com/unstoppableCarl
- Sbed, http://opengameart.org/content/95-game-icons
- PriorBlue
- Willdabeast, http://wjbstories.blogspot.com
- Viscious Speed, http://viscious-speed.deviantart.com - CC0
- Lord Berandas, http://berandas.deviantart.com
- Irongamer, http://ecesisllc.wix.com/home
- HeavenlyDog, http://www.gnomosygoblins.blogspot.com
- Lucas
- Faithtoken, http://fungustoken.deviantart.com
- Skoll
- Andy Meneely, http://www.se.rit.edu/~andy/
- Cathelineau
- Kier Heyl
- Aussiesim
- Sparker, http://citizenparker.com
- Zeromancer - CC0
- Rihlsul
- Quoting
- Guard13007, https://guard13007.com
- DarkZaitzev, http://darkzaitzev.deviantart.com
- SpencerDub
- GeneralAce135
- Zajkonur
- Catsu
- Starseeker
- Pepijn Poolman
- Pierre Leducq
- Caro Asercion
- SeregaCthtuf

Please, include a mention "Icons made by {author}" in your derivative work.

If you use them in one of your project, don't hesitate to drop a message to delapouite@gmail.com or ping @GameIcons on twitter.

More info and icons available at https://game-icons.net
```

### Required credit, in the source's own wording

The licence file says: *"Please, include a mention "Icons made by {author}" in your derivative
work."* The credit used throughout this project is therefore:

> Icons made by {author}. Available on https://game-icons.net

### Authors of the icons in this repository

| Author | Link given by the licence file | Licence |
| --- | --- | --- |
| Delapouite | http://delapouite.com | CC BY 3.0 |
| Guard13007 | https://guard13007.com | CC BY 3.0 |
| Lorc | http://lorcblog.blogspot.com | CC BY 3.0 |
| Sbed | http://opengameart.org/content/95-game-icons | CC BY 3.0 |
| Skoll | — | CC BY 3.0 |
| Zeromancer | — | CC0 |

Each author above appears with this credit line in `THIRD_PARTY_LICENSES.md` and in the game's
About screen (`src/ui/screens/about_screen.gd`, reading `data/credits.json`). A test
(`tests/suites/test_icons_licensed.gd`) fails if a committed icon's author is missing from
either.

### What was changed, and what was not

One change per file: the full-bleed background rectangle (`<path d="M0 0h512v512H0z"/>`) is
removed, so each mark can take the theme's colour instead of being a white shape on a black
square. Nothing else is edited — path data, viewBox and the white foreground are the source's
own bytes, and `tools/build_icons.py --check` re-downloads the pinned commit in CI and compares
every file.

### The drawn marks stay

The project's own code-drawn shapes (`src/ui/hud/shell_icon.gd`) remain as the fallback shown
when an icon file cannot be loaded — a missing file leaves a button with a mark that means the
same thing, not a blank space. They are original work, not third-party artwork.

### Exclusions applied

No icon was taken from an author whose entry the licence file does not cover, and no icon whose
own file says anything other than what this section records. The set contains no real-world
flag, no religious symbol and no depiction of a real person: meanings were chosen for interface
functions (messages, filters, coins), never for nations or beliefs.

## Interface sounds — still generated, no pack downloaded (Milestone 10)

Milestone 09 shipped interfaces sounds generated in code (a click and a confirm tone, silent
until the player raises a volume). Milestone 10 allowed a CC0 Kenney pack **only if its licence
could be verified at download**.

It could not: `kenney.nl` is outside the reachable hosts listed above. The generated tones
therefore stay, and **no audio file was added**. This is reported as a blocked item rather than
quietly skipped: the alternative — shipping a pack whose licence nobody re-checked — is the
one thing the rule forbids.
