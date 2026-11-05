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
| `data/world/manifest.json` | 2 KiB | Provenance, processing steps, counts, repairs, known limitations. |
| `data/world/start_eligibility.json` | 1 KiB | Which source classifications may start a campaign. Hand-maintained, see below. |

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
      "capital_point": [90.4, 23.7],     // capital (lon, lat) from the same source feature, or null
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
4. **Missing is `null`, never zero and never a guess.** `capital`, `capital_point`, `iso_a2`, `iso_a3`,
   `note` and `subregion` are the fields that can be absent. The registry turns `null` into an empty
   string (and `capital_point` into an empty value pair) and the UI states the gap. 46 of 242 units have
   no capital in the source; that is reported, not filled.
4a. **The capital name and the capital point come from the same feature.** Both are read from one row of
   `ne_50m_populated_places_simple.geojson` — the populated place whose `adm0_a3` matches the unit and
   whose `FEATURECLA` marks it as a national capital. They are never joined from different sources, so a
   marker cannot appear on the wrong city, and a unit with no sourced capital has neither a name nor a
   point (196 of 242 units have both; 46 have neither). The validator fails if a point exists without a
   name, if either is outside its range, or if the two disagree on which units have a capital.
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
5. **Self-intersections are repaired, and the repair is recorded.** A handful of Natural Earth rings
   double back on themselves (a "hairpin" where the coastline crosses itself between two consecutive
   vertices). Such a ring cannot be triangulated, so the builder finds the proper crossings exactly on
   the quantised integers and removes the single spike vertex responsible. A repair is applied only when
   it provably removes at least one crossing **and** changes the ring's area by less than 0.5%; otherwise
   the ring is left alone and the problem is reported. The manifest lists every repair. In this build
   exactly one is needed — Taiwan's main island, one vertex removed, area 3.171229 → 3.170037 deg²
   (−0.04%). This is a repair of a drawing defect, not a change to any boundary or claim.
5a. **A hull fallback exists but is not used.** If a ring still cannot be triangulated, the renderer fills
   it with its convex hull rather than deleting a landmass. The benchmark reports how often that happens;
   after the repair above it is **0 rings**, so no visible geometry depends on it.
5b. **Small rings are dropped, and the drop is counted.** Rings smaller than
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
| `counts` | Countries, polygons, rings, dropped rings, repaired rings, repaired vertices, capital points, vertices. The validator fails when these are stale. |
| `repairs` | Every ring the builder repaired, with `id`, `ring` index, `removed_vertices` and `area_before` / `area_after` in square degrees. Empty is the normal state; one entry is expected in this build (Taiwan's main island). |
| `known_limitations` | Source and pipeline limitations, including the neutrality statement. |

## `start_eligibility.json`

```jsonc
{
  "schema": 1,
  "eligible_types": ["Sovereign country", "Country", "Sovereignty"],
  "reason": "Not available as a starting nation in this version.",
  "note": "This is a default rule for the project owner to review, not a final decision. …"
}
```

The only file that decides which records a player may start a campaign as. It is a list of the dataset's
own `type` values — it never names a place, so there is no per-country code anywhere in the game. Every
record stays searchable, selectable and fully documented; only confirmation of a new campaign is gated,
and the gate is enforced in `CampaignConfig.validate()`, not in the interface. `reason` is shown to the
player verbatim; `note` is owner-facing and explains that the rule is a reviewable default. Edit the list
and restart: the interface, the validation gate and `docs/START_NATIONS.md` all follow it. The generated
table of who is and is not eligible lives in [`START_NATIONS.md`](START_NATIONS.md).

## Quality gates

```bash
python3 tools/check_atlas_data.py                     # fast CI smoke alarm
python3 tools/validate_world_atlas.py                 # full audit, exit 1 on errors
python3 tools/validate_world_atlas.py --report docs/DATA_QUALITY.md
python3 tools/validate_world_atlas.py --check-report docs/DATA_QUALITY.md   # fails if stale
python3 tools/report_policies.py                                            # regenerate the policy docs
python3 tools/report_policies.py --check                                    # fails if either is stale
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
countries.json 7709854e02228f01f2d50c6761e2987ffd9133fd10910d7ddfe56526d93a1524
geometry.json  24064c36ec9f9ef7ce60305999ec6dc876dbad2763f651e5c2a2f7a087aee87b
manifest.json  c3e2be983c3a1a4374530740ea07e6b370479f35f400a704ed337c7d48ecad7a
```

Verified on 2026-11-05 by rebuilding into a scratch directory and comparing: all three hashes match.
`start_eligibility.json` is hand-maintained policy, not a build output, so it has no rebuild hash.

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
