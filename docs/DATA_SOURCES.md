# Data sources and geographic content

This document records **where the world atlas comes from**, under what licence, exactly how it was
transformed, and what the project does *not* claim about the places it draws. The machine-readable
copy of the same facts ships with the game in `data/world/manifest.json`, and `tests/suites/`
asserts that the manifest and the shipped data agree.

## Source dataset

| Field | Value |
| --- | --- |
| Dataset | Natural Earth 1:50m Cultural Vectors — Admin 0 Countries |
| Also used | Natural Earth 1:50m Populated Places (simple) — capital-city names only |
| Repository | [`nvkelso/natural-earth-vector`](https://github.com/nvkelso/natural-earth-vector) |
| Commit used | `ca96624a56bd078437bca8184e78163e5039ad19` (2022-06-02) |
| Version label in the repository | `5.2.0-pre` (the `VERSION` file at that commit) |
| Files | `geojson/ne_50m_admin_0_countries.geojson`, `geojson/ne_50m_populated_places_simple.geojson` |
| Retrieved | 2026-11-05 |
| Licence | **Public Domain** — Natural Earth Terms of Use: "All versions of Natural Earth raster + vector map data found on this website are in the public domain." No attribution is legally required; it is given here and in the About screen because it is the right thing to do and because the provenance must be reviewable. |

Natural Earth is a public-domain map dataset produced by the Natural Earth project with the North
American Cartographic Information Society. The vector repository above is the canonical mirror of
the released shapefiles and GeoJSON.

### Why 1:50m and not 1:10m

The 1:10m release is roughly four times larger (≈13 MB for the countries file alone). At the zoom
levels a strategy interface actually uses — the whole world in ~1000 px — 1:50m is already finer
than one pixel per 0.36°, and the difference is invisible until a country is zoomed far past the
range this milestone supports. 1:50m keeps the committed runtime data at ~1.2 MB and keeps the mesh
build measurable. 1:10m remains a drop-in option: the pipeline takes the file path as an argument.

## What the pipeline does

Script: [`tools/build_world_atlas.py`](../tools/build_world_atlas.py). It runs **offline only**; the
game never runs Python, never contacts a server and never needs the source files.

```bash
# 1. fetch the two GeoJSON files from the repository at the pinned commit
#    (any copy of the same commit's files works — they are public domain)
python3 tools/build_world_atlas.py --source-dir <geojson-dir> --out data/world \
    --retrieved 2026-11-05
```

Steps, in order:

1. Read both GeoJSON files with Python's `json` module.
2. For every feature, take Natural Earth's `ADMIN` name, its ISO codes, `CONTINENT` (region),
   `SUBREGION`, `TYPE`, `SOVEREIGNT`, `NOTE_BRK`/`NOTE_ADM0`, `LABEL_X`/`LABEL_Y`, `LABELRANK` and
   `TINY` — and **only** those. Population, GDP, income group and every other statistical column are
   discarded on purpose (see "Deliberately excluded" below).
3. Derive a **stable id**: the ISO alpha-3 code where the source has one (`ISO_A3`), otherwise
   Natural Earth's admin-0 code (`ADM0_A3`, e.g. `KOS` for Kosovo). No id is derived from a display
   name, so renaming a country cannot break a saved campaign. Duplicate ids would be suffixed
   `-2`, `-3` and reported; the current dataset produces none.
4. **Quantise** every coordinate to 1/200° (0.005°, ≈550 m at the equator) and store it as an
   integer. Rings stay **closed** (first point repeated) so borders can be stroked without special
   cases.
5. Drop consecutive duplicate vertices, drop rings with fewer than three distinct points, and drop
   *holes* smaller than 0.0025°² (≈30 km²). No outline is dropped: island nations keep every island.
6. Join **capital names** from the populated-places file on `adm0_a3` where `adm0cap = 1`, taking
   the lowest `scalerank` when a country has more than one capital entry. If the source has no
   capital row for a unit, the capital is left **empty** — 46 of 242 units have no capital in this
   dataset, and the interface says "Not recorded in source" for them.
7. Fold names to a lowercase ASCII search key (`Côte d'Ivoire` → `cote d'ivoire civ …`) so runtime
   search does not have to normalise Unicode.
8. Write three files: `data/world/countries.json` (metadata, 92 KiB), `data/world/geometry.json`
   (shapes, 1.14 MiB) and `data/world/manifest.json` (provenance, 2 KiB).

### Current output

| Measurement | Value |
| --- | --- |
| Countries and territories | 242 |
| Polygons (disconnected parts) | 1 620 |
| Rings (outlines + holes) | 1 631 |
| Vertices | 99 568 |
| Quantisation | 1/200° (0.005°) |
| Metadata file | 92 KiB |
| Geometry file | 1 144 KiB |

## Naming policy

Display names are the dataset's `NAME` (the short common name), with `NAME_LONG` shown beneath when
it differs. **Nothing is renamed.** Where the project needed a different word for UI reasons it is
in the interface, not in the data: the atlas calls every unit a "nation" and shows the dataset's own
`TYPE` alongside, so a dependency is never silently promoted to a sovereign state or the reverse.
Identifiers are ISO alpha-3 / Natural Earth codes, never display names.

## Deliberately excluded

The source file contains `POP_EST`, `GDP_MD`, `INCOME_GRP` and related columns. None of them are
imported, and no screen displays them. Two reasons:

* they are estimates for a dataset dated to 2022 and would be presented as if they were 2026 facts;
* this project's rule is that any statistic shown to the player comes from a system that actually
  models it. The simulation does not exist yet, so the atlas stays a *geographic* catalogue.

The interface therefore shows names, ISO codes, region/subregion, capital (when sourced) and the
source's political classification — nothing else.

## Disputed areas, dependencies and sovereignty

This project **does not take a position** on contested sovereignty, and that is a deliberate,
documented policy rather than an omission.

* Every unit keeps the geometry the dataset gives it, in its own record with its own id. Nothing is
  merged into a neighbour, and nothing is deleted.
* `TYPE`, `SOVEREIGNT`, `NOTE_ADM0` and `NOTE_BRK` are stored and displayed **verbatim**. The
  dossier shows a "Dataset classification" line for anything that is not a plain
  `Sovereign country`, so a player can see that the source filed it as a dependency, a disputed
  unit or an indeterminate one.
* **Israel and Palestine** are the case the milestone brief names explicitly. The dataset files
  Israel as `TYPE: "Disputed"` and Palestine as `TYPE: "Indeterminate"`,
  `SOVEREIGNT: "Israel"`, `NOTE_BRK: "Partial self-admin."`. Both keep their own geometry,
  their own records and their own ids (`ISR`, `PSE`); Palestine has no capital in the source and
  therefore none in the game. The source's wording is preserved, no position is implied by the
  interface, and the neutral treatment is asserted by
  `tests/suites/test_world_geometry.gd::test_disputed_and_dependent_units_keep_the_source_classification`.
  Resolving representation is an **owner decision**, not a developer one; when a policy is set, it
  will be implemented as an explicit, documented overlay in the data pipeline, never as a silent
  edit.
* Antarctica is included as the dataset's `Indeterminate` map unit with its treaty note. It is
  selectable, like every other unit, because pretending it is not on the map would be a different
  kind of inaccuracy.

## Known limitations

* **Generalisation.** 1:50m coastlines and borders are simplified for world-scale display. Small
  islands, reefs and meanders that exist on the ground do not exist in this data.
* **Quantisation.** Detail below 0.005° is intentionally lost. At the maximum zoom (96 px per
  degree) that is about half a pixel.
* **No projection transform is stored.** Coordinates are lon/lat; the renderer applies an
  equirectangular projection at draw time (see [ARCHITECTURE.md](ARCHITECTURE.md)).
* **Antimeridian.** Shapes are stored with coordinates in [-180°, 180°]; the dataset already splits
  Russia and Fiji at the meridian, so nothing wraps. The map does not scroll horizontally past
  ±180° — it clamps instead.
* **Enclaves smaller than the generalisation** (Vatican City, Monaco, Singapore's city boundary) may
  not carve a hole out of their neighbour. Where the dataset provides a hole (Lesotho in South
  Africa, San Marino in Italy) it is preserved and rendered, and a hit test inside it resolves to
  the enclave.
* **No capital for 46 units**, no ISO code for 8, and no `NOTE_BRK` for most: the interface reports
  those gaps instead of filling them.
* **Dependency and disputed counts** (28 dependencies, 4 disputed, 4 indeterminate, 2 sovereignty
  units at the pinned commit) change with Natural Earth releases. Re-running the pipeline with a new
  commit changes the atlas; the manifest records which commit is in the build.

## Reproducing and updating

1. Fetch the two files for the commit you want from `nvkelso/natural-earth-vector`.
2. Run the pipeline with `--source-dir` pointing at them, `--retrieved` set to the fetch date.
3. Run `gdlint src tests tools` and the headless test suite. The data tests assert counts, id
   format, geometry/metadata agreement and manifest consistency, so a broken or partial fetch fails
   the build rather than shipping.
4. Update the table at the top of this file and the `known_limitations` list in the pipeline's
   manifest if the new release changes anything described here.

## Attribution in the game

The campaign screen states the dataset, version, retrieval date, country/polygon/vertex counts and
licence in its dossier footer, and the About & Credits screen lists Natural Earth under third-party
components. Both read from `data/world/manifest.json`, so an update cannot leave stale credit text
behind.
