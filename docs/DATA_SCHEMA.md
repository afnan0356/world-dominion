# World atlas data schema

This document describes the three committed data files under `data/world/`, how they are produced, and
how to change them safely. It is the contract between the data pipeline (`tools/`) and the game
(`src/core/world/`). Nothing in the game infers data that is not in these files.

Related documents: [`DATA_SOURCES.md`](DATA_SOURCES.md) (source, licence, limitations),
[`DATA_QUALITY.md`](DATA_QUALITY.md) (generated audit), [`ARCHITECTURE.md`](../ARCHITECTURE.md)
(runtime boundaries), [`CONTRIBUTING.md`](../CONTRIBUTING.md) (rules for contributors).

## Files

| File | Size | Role |
| --- | --- | --- |
| `data/world/countries.json` | 93 KiB | The registry: one record per selectable unit. No geometry. |
| `data/world/geometry.json` | 1 144 KiB | Quantised polygons keyed by the same stable IDs. |
| `data/world/manifest.json` | 2 KiB | Provenance, processing steps, counts, known limitations. |

They are separate on purpose:

* the **simulation-side systems of the future** (population, government, economy) will join against
  `countries.json` by stable ID and must never need to load polygons;
* the **renderer** needs polygons and must not need metadata;
* **search and filtering** need neither polygons nor UI;
* a reviewer can audit provenance without reading a megabyte of coordinates.

All three carry `"schema": 1`. Bump this integer when a field is removed or changes meaning; adding a
field is backward compatible because loaders read by name and tolerate absence.

## `countries.json`

```jsonc
{
  "schema": 1,
  "countries": [
    {
      "id": "BGD",                       // stable identifier, see below
      "name": "Bangladesh",              // display name
      "name_long": "People's Republic of Bangladesh",
      "iso_a2": "BD",                    // null when the source has no valid code
      "iso_a3": "BGD",                   // null when the source has no valid code
      "region": "Asia",                  // dataset classification, used by the region filter
      "subregion": "Southern Asia",      // dataset classification, informational
      "capital": "Dhaka",                // null when the source records no capital
      "type": "Sovereign country",       // source's own TYPE, verbatim
      "sovereignty": "Bangladesh",       // source's own SOVEREIGNT, verbatim
      "note": null,                      // source's own NOTE, verbatim, often null
      "label": [90.4, 23.7],             // label anchor (lon, lat) from the source
      "label_rank": 3,                   // source LABELRANK: 1 = must be labelled
      "tiny": false,                     // source's "tiny" flag for micro-states
      "bbox": [88.0, 20.7, 92.7, 26.6],  // [min_lon, min_lat, max_lon, max_lat]
      "filter_region": true,             // participate in the region filter
      "search": "bangladesh bangladesh bd bgd bgd people's republic of bangla"
    }
  ]
}
```

### Rules

1. **Stable identifiers.** `id` is ISO alpha-3 when the source provides one, otherwise Natural Earth's
   `ADM0_A3` unit code. It never comes from a display name, is never re-derived, and matches
   `^[A-Z]{3}(-[0-9]+)?$`. The suffix form exists because the source uses codes such as `CYN` for
   Northern Cyprus; those are kept as the source writes them.
2. **Names come from the source.** `name` is `NAME`, `name_long` is `NAME_LONG` (falling back to `name`
   when the source leaves it blank). There is no editorial renaming and no translation layer yet. If a
   display-name policy is added, it must record where each name came from.
3. **ISO codes are accepted, not repaired.** A code is copied only when the source value is a plain
   uppercase code of the right length. Natural Earth's `-99` placeholder and Taiwan's `CN-TW` are stored
   as `null`; the dossier then says the source does not record one.
4. **Missing is `null`, never zero and never a guess.** `capital`, `iso_a2`, `iso_a3`, `note` and
   `subregion` are the fields that can be absent. The registry turns `null` into an empty string and the
   UI states the gap. 46 of 242 units have no capital in the source; that is reported, not filled.
5. **Text is source text.** `type`, `sovereignty` and `note` are copied verbatim and are what the UI
   shows. This project does not arbitrate sovereignty: Israel/Palestine in particular keeps the source's
   geometry and classification, and no editorial position is encoded anywhere in the data.
6. **Search keys are generated.** `search` is the folded, lowercase concatenation of the display name,
   long name, ISO alpha-2, ISO alpha-3 and the source's `FORMAL_EN`/`NAME_SORT` variants. It is
   generated, so it must never be hand-edited; the validator proves it contains the name and both ISO
   codes.
7. **`filter_region`** marks whether the unit appears in the player-facing region filter. Antarctica,
   "Seven seas (open ocean)" and similar source oddities are real records in the registry (the map can
   select them if the player taps them) but do not pollute the six player-facing regions.
8. **Sorting is deterministic.** Records are ordered by ID in the file; the registry sorts by name for
   presentation, so file order does not matter to the UI.

## `geometry.json`

```jsonc
{
  "schema": 1,
  "scale": 200,                    // coordinates are quantised to 1/200 degree
  "countries": {
    "BGD": {
      "bbox": [88.0, 20.7, 92.7, 26.6],
      "polygons": [                // one entry per disconnected landmass
        [                          // one polygon = list of rings
          [8881, 2432, 8885, 2429] // ring 0 is the outline, flat [lon, lat, lon, lat…]
          ,[9001, 2500, 9004, 2503] // further rings are holes, same flat encoding
        ]
      ]
    }
  }
}
```

### Rules

1. **Quantised integers.** Each coordinate is `round(degrees * 200)`, so 0.005° ≈ 550 m at the equator.
   This halves the file and makes the data exactly comparable across platforms. Dequantise by dividing
   by `scale`.
2. **Closed rings.** The first point is repeated as the last. The validator fails on an unclosed ring.
3. **Ring order carries meaning.** Index 0 is the outer boundary; every later ring is a hole. The renderer
   draws holes as a second mesh in the sea colour instead of running polygon booleans at runtime.
4. **Antimeridian.** Rings are split at ±180° in the pipeline, so no ring jumps more than 180° of
   longitude between consecutive vertices. The validator enforces this. Countries on both sides of the
   line are therefore multiple polygons and their bboxes legitimately span the full width (Russia,
   Fiji, the United States).
5. **Small rings are dropped, and the drop is counted.** Rings smaller than
   `MIN_RING_AREA_DEG2 = 0.0025` (about 30 km² at the equator) are removed, and `counts.dropped_rings`
   in the manifest records how many. At 1:50m this affects one sliver in this build.
6. **No per-polygon metadata, deliberately.** Polygons are anonymous; country identity lives in the
   registry. That is what lets the renderer be replaced without touching data, and lets data be extended
   without touching the renderer.

## `manifest.json`

| Field | Meaning |
| --- | --- |
| `schema` | Schema version, must match the other files. |
| `generated` | Date the build ran, ISO 8601. |
| `source.dataset` / `repository` / `commit` / `version` / `licence` / `url` / `retrieved` | Provenance. The commit pins the exact bytes; `tools/fetch_world_atlas.py` downloads that commit only. |
| `source.capital_url` | Second source file used for capital names. |
| `processing.scale`, `processing.min_ring_area_deg2`, `processing.steps` | Exactly what the build did, in order. |
| `counts` | Countries, polygons, rings, dropped rings, vertices. The validator fails when these are stale. |
| `known_limitations` | Source and pipeline limitations, including the neutrality statement. |

## Quality gates

```bash
python3 tools/check_atlas_data.py                     # fast CI smoke alarm
python3 tools/validate_world_atlas.py                 # full audit, exit 1 on errors
python3 tools/validate_world_atlas.py --report docs/DATA_QUALITY.md
python3 tools/validate_world_atlas.py --check-report docs/DATA_QUALITY.md   # fails if stale
```

The validator checks: schema presence, ID format and uniqueness, ISO format and uniqueness, duplicate
display names, required fields, bbox sanity against the geometry (drift tolerance 0.02°), ring closure,
non-zero area, antimeridian splits, coordinate range, registry/geometry key equality, manifest counts,
provenance completeness, licence record and the presence of processing steps and limitations. Source gaps
(missing capital, missing ISO) are reported as coverage, not as failures — inventing them is forbidden.

`docs/DATA_QUALITY.md` is generated by that command and committed, so the current coverage numbers are
reviewable in the diff rather than buried in a build log. CI regenerates it and fails when it is stale.

## Reproducing the data

```bash
python3 tools/fetch_world_atlas.py --source-dir data/source     # pinned commit only
python3 tools/build_world_atlas.py --source-dir data/source --out data/world --retrieved 2026-11-05
python3 tools/validate_world_atlas.py --report docs/DATA_QUALITY.md
```

`data/source/` is ignored by Git (see `.gitignore`): the raw 3.8 MiB of GeoJSON is reproducible from the
pinned commit and must not be duplicated in the repository.

Regenerating from the pinned commit with the committed build script reproduces the committed files
**byte for byte**, so any diff after a rebuild is a real data change:

```
countries.json  bac91c8a4723fc6ec429ac512a67b14c744a4d1a4f3d6fdbb846be74efc00193
geometry.json   5089f39a53a3f515b37d6ee12ea1d8e5f3922ac0d2766d1aa2caed1f90b2e327
manifest.json   958771ebec3545a318e91dc5c4e4681d091b13def3747e80e525db77d2d37dd7
```

## Adding metadata for future systems

The registry is designed to grow *beside* the map, not inside it. To add population data later:

1. Do **not** add fields to `geometry.json`; it must stay geometry-only.
2. Add a new file, e.g. `data/world/population.json`, keyed by the same stable `id`, with its own
   `source` block and `retrieved` date — one file per source, so licences stay separable.
3. Add a loader in `src/core/world/` (or a new `src/core/society/` module) that joins by ID and exposes
   `has_population()` / `population()`; never let the map or the UI parse the file directly.
4. Extend the dossier through `CountryDossier` sections rather than by hand-building labels in the panel,
   so a missing value renders as "not recorded" instead of a fake number.
5. Update `docs/DATA_QUALITY.md` by extending the validator for the new file, and register the source in
   `docs/DATA_SOURCES.md`.
