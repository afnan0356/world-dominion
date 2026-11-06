# WORLD DOMINION — Roadmap

Status vocabulary used in this document:

- **Implemented** — code exists on the branch.
- **Tested** — verified by an automated check or a documented manual check in this environment.
- **In progress** — actively being worked on.
- **Planned** — agreed intent, no code yet.
- **Deferred** — deliberately postponed; no commitment to a milestone.

A milestone is only "done" when it is implemented, tested and has passed the UI/UX refinement
checklist in [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Milestone 01 — Project foundation & visual design system

Status: **Implemented**, **Tested** (headless suite; no rendered-platform verification — see below).

### Implemented

- Godot 4.6 project with a cross-platform layout/input baseline (GL Compatibility renderer,
  `canvas_items` stretch mode with `expand` aspect, landscape orientation).
- Application shell: title screen with primary navigation, settings screen, about & credits screen,
  with a fade-based screen router and back navigation.
- Design system: tokens (`src/ui/theme/design_tokens.gd`), two palettes, a runtime theme builder with
  named style variations, and reusable components (nav row, segmented control, setting row, header).
- Two themes: `Midnight` (default) and `Parchment`, switchable at runtime and persisted.
- Settings: theme, interface scale (90–130 %), reduced motion; stored locally in `user://settings.cfg`
  with validation and graceful recovery from a corrupt file.
- Procedurally drawn backdrop (chart rings + shader vignette) and original SVG icons.
- Data-driven build status and credits (`data/app_meta.json`, `data/credits.json`).
- Game-wallet currency primitive with integer-only invariants (no economy system).
- Headless test suite: design tokens/contrast, theme completeness, settings storage, wallet
  invariants, content files, responsive layout at six viewport sizes.
- GitHub Actions workflow for lint + headless tests.

### Tested here

Validation used a Linux **headless** build of Godot 4.6.3 (compiled from the official source tag with
`vulkan=no opengl3=no`), so scripts, scenes, resources, autoloads and layout were exercised, but
nothing was rendered.

- `gdlint src tests` (gdtoolkit 4.5.0) — clean.
- `godot --headless --path . --import` — resources imported, no script errors.
- `godot --headless --path . res://tests/test_runner.tscn` — 6 suites, 3802 assertions, 0 failures.
- Application smoke run: `godot --headless --path . --quit-after 240 res://src/app/main.tscn` — the
  shell boots, builds its theme and shows the main menu without errors.
- Layout geometry inspected node by node at 1920×1080, 1280×720, 1024×768, 844×390, 640×360, 390×844
  and 360×800; six of those inspections are drawn up in `docs/layout-diagrams/` (geometry diagrams
  built from resolved widget rects and theme data, **not** engine renders).

### Not tested here

- **Nothing was rendered by the engine.** The validation environment has no display server, no
  OpenGL/EGL/Vulkan implementation and no GPU, and cannot install one (non-root, package mirrors and
  release-asset hosts unreachable), so the shell was verified through layout/geometry assertions,
  geometry diagrams and code review rather than by looking at engine pixels. The project owner should
  open the project in the Godot editor to confirm final visual judgement.
- No export build for any platform was produced or run.

### Deferred from this milestone

- Following the operating system's light/dark preference. Godot's `DisplayServer.is_dark_mode()` is
  not supported on all target platforms; the two explicit themes ship now, and automatic following
  is deferred until it can be verified per platform.
- Audio. No sound is generated or loaded yet, and the settings screen deliberately has no audio
  section until audio exists.
- Safe-area insets for notched displays. The layout is inset-aware in structure (a single
  `MarginContainer` per screen) but no inset values are read yet, because they can only be verified
  on a device.

---

## Milestone 02 — World atlas, country data & campaign selection

Status: **Implemented**, **Tested** (headless suite and layout assertions; no rendered-platform
verification — see below).

### Implemented

- **World atlas.** Real country polygons from Natural Earth 1:50m (public domain), processed offline
  by `tools/build_world_atlas.py` into a compact runtime format: 242 countries and territories,
  1 620 polygons, 1 631 rings, 99 567 vertices, 1.3 MB of JSON. Coastlines and borders are real
  geography, not hand-drawn shapes.
- **Documented projection.** Equirectangular (plate carrée), isolated in `MapProjection`; shapes are
  stored as quantised lon/lat (1/200°) so the projection is a runtime decision.
- **Rendering designed for 200+ countries.** One cached `ArrayMesh` per country, drawn through a
  camera transform (panning and zooming do no vertex work), culled by bounding box, holes as
  sea-coloured meshes, 1-px borders via world-space polylines, label level-of-detail by zoom.
- **Interaction.** Drag pan (mouse/touch), wheel and trackpad zoom, two-finger pinch, pointer-anchored
  zoom, keyboard pan/zoom, visible zoom-in / zoom-out / fit controls, hard clamping so the world can
  never be lost, whole-shape highlight, safe re-tap, empty-space tap clears the selection.
- **Country registry.** 242 records with a stable id (ISO alpha-3, else Natural Earth admin-0 code),
  display name, long name, ISO alpha-2/alpha-3 where the source has them, region, subregion, capital
  where sourced, the source's type/sovereignty/note, label anchor, bbox and search key. Missing
  values are empty and reported, never invented. The registry has no UI or map dependency.
- **Geography policy.** Source, repository commit, version, retrieval date, licence, processing steps
  and known limitations recorded in `data/world/manifest.json` and
  [docs/DATA_SOURCES.md](docs/DATA_SOURCES.md). Disputed, dependent and indeterminate units keep
  their own geometry and the dataset's classification verbatim; the neutral treatment of
  Israel/Palestine is documented and asserted by tests. Statistics were deliberately not imported in
  this milestone; Milestone 05 adds population and GDP from the same pinned file, with their vintage
  and provenance, as read-only reference data.
- **Country selection screen.** Search by name/common name/ISO code (case- and accent-insensitive),
  region filters from the dataset's own classification with an active-filter indicator and a clear
  action, results as an overlay so the map never reflows, dossier that shows only sourced data, and
  a proper empty state.
- **Campaign foundation.** Data-driven scenario catalogue (`data/scenarios/*.json`), one implemented
  scenario — **Modern World, 1 January 2026** — a versioned `CampaignConfig` value object, and
  validation that refuses unknown/unimplemented scenarios, unknown countries and bad dates. Confirm
  shows a campaign brief that states plainly that no simulation runs and nothing is saved.
- **Interface.** Reuses the existing design system: Midnight/Parchment palettes (with new map
  tokens), the type ramp, spacing, focus rings, reduced-motion handling and breakpoints. Three
  arrangements of the same map + dossier widgets (side / stack / drawer) cover desktop, tablet,
  portrait and a 640×360 window without hiding the map.
- **Country data pipeline.** `tools/fetch_world_atlas.py` (pinned-commit source retrieval),
  `tools/build_world_atlas.py` (deterministic build: regenerating from the pinned commit reproduces
  the committed files byte for byte), `tools/validate_world_atlas.py` (schema, identifier, ISO,
  geometry and provenance audit that writes [docs/DATA_QUALITY.md](docs/DATA_QUALITY.md)), and
  `tools/check_atlas_data.py` (fast CI gate). Schema and reproduction steps are documented in
  [docs/DATA_SCHEMA.md](docs/DATA_SCHEMA.md).
- **Country dossier.** `CountryDossier` builds Overview / Geography / Administration / Data sources
  from the record plus atlas context. Every gap is stated ("Not recorded in source"); the seven
  future systems (population, economy, government, military, diplomacy, resources, society) are listed
  as unimplemented and carry no numbers.
- **Small-country selection assist.** Countries whose whole shape is under 11 px on screen can be
  selected from up to 18 px away, and get a visible marker ring. Polygons never move or grow, and the
  assist can only ever reach tiny shapes, so a large neighbour cannot absorb a nearby tap.
- **Geographic orientation.** Zoom-dependent ocean labels at world zoom, a scale bar that reports
  kilometres per pixel at the view centre (equirectangular distortion is stated, not hidden), and the
  existing `LABELRANK`-driven country labels with overlap rejection.
- **Search and exploration depth.** Keyboard-only search (arrow keys through results, Enter selects,
  Escape clears), deterministic duplicate-free ranking, documented alias source (the dataset's formal
  and sort names), region counts read from the registry, and combined search + region filtering.
- **Campaign staging.** A derived three-stage line (Scenario → Nation → Review) that spells the stage
  out in words, keeps a valid selection when stepping back from the review, and validates scenario,
  country and date before confirmation.
- **Failure handling.** Missing, malformed or inconsistent data yields an explained empty state rather
  than a crash or a substitution: registry, geometry, map and campaign validation each report what they
  dropped and why.
- **Capital markers and coordinates.** The capital name and its coordinates are read from the same
  source feature, so a marker can never disagree with the name. Markers appear from zoom 2.4, labels
  from 3.6, always below country labels in priority; 196 of 242 units have a sourced capital, the other
  46 show the gap in the dossier and nothing on the map.
- **Starting-nation rule (default for owner review).** One hand-maintained data file,
  `data/world/start_eligibility.json`, lists the dataset's own `type` values that may start a campaign
  (`Sovereign country`, `Country`, `Sovereignty` → 206 of 242 records). It is enforced in
  `CampaignConfig.validate()`, so the interface cannot bypass it. Every record stays searchable,
  selectable and fully documented; only confirmation is gated, and an ineligible record says
  *"Not available as a starting nation in this version."* The generated list and the review note are in
  [docs/START_NATIONS.md](docs/START_NATIONS.md).
- **Neutral-status wording.** Every record shows its source classification verbatim; records the dataset
  files as `Disputed` or `Indeterminate` additionally carry one neutral sentence naming the dataset and
  disclaiming an official position. The full generated inventory of disputed, indeterminate, sovereignty
  and dependency units is [docs/DISPUTED_TERRITORIES.md](docs/DISPUTED_TERRITORIES.md).
- **Geometry repair, recorded.** The builder now detects self-intersecting rings exactly on the quantised
  integers and removes only the one spike vertex responsible, and only when that provably removes a
  crossing and moves the area by under 0.5%. One repair is performed (Taiwan's main island, −0.04% area)
  and written to `manifest.json`; the convex-hull fallback is now used **0** times.
- **Developer tools.** A persisted performance overlay (F3) showing FPS, average/p95/worst frame time,
  draw calls and map counts; a **reduced map detail** setting that keeps geography and tap targets
  identical while drawing less; and a deterministic 30-second map stress test with documented budgets
  and verdicts, so the owner can replace the unverified frame-time rows with measurements.
- **Beginner-facing documentation.** [docs/GLOSSARY.md](docs/GLOSSARY.md) explains every technical term
  in plain language, and the two generated policy documents state their rules without naming a place.
- **Tests.** Fifteen suites, including two added in the hardening pass: starting-nation eligibility and
  the source-status note, and the developer tools (settings, overlay, stress-path determinism, verdict
  thresholds, reduced detail, gate enforcement).

### Tested here

Headless Linux build of Godot 4.6.3 (compiled from the official source tag, `vulkan=no opengl3=no`):

- `gdlint src tests tools` — clean.
- `godot --headless --path . --import` — resources imported, no script errors.
- `godot --headless --path . res://tests/test_runner.tscn` — 15 suites, 246 481 assertions, 0 failures.
- `python3 tools/check_atlas_data.py`, `python3 tools/validate_world_atlas.py
  --check-report docs/DATA_QUALITY.md` and `python3 tools/report_policies.py --check` — atlas data
  valid, quality report and both policy documents fresh.
- A rebuild from the pinned commit into a scratch directory reproduces all three atlas files
  **byte for byte** (SHA-256 recorded in `docs/DATA_SCHEMA.md`).
- Application smoke run boots the shell without errors.
- Atlas benchmark (`tools/atlas_benchmark.tscn`) — load, mesh-build and query timings recorded in
  [docs/PERFORMANCE.md](docs/PERFORMANCE.md), with the frame-time caveat stated there.
- Layout geometry inspected node by node at 1920×1080, 1280×720, 1024×768, 844×390, 640×360,
  390×844 and 360×800, both orientations.
- Data renders of the committed geometry in both palettes (`docs/evidence/`) — labelled inside the
  image as data renders, **not** screenshots.

### Not tested here

- **Nothing was rendered by the engine.** The environment has no display server, no GPU and no
  OpenGL/EGL/Vulkan implementation, so the map's painted appearance — colours, label collisions at
  extreme zoom, border antialiasing — was verified by geometry assertions, colour-contrast tests and
  code review, not by looking at pixels. The owner should open the project in the Godot editor for
  final visual judgement.
- Frame time on desktop and on low-end mobile hardware is **unverified** (no GPU, no device).
- Touch gestures (pinch, drag) were exercised only through the input handlers' logic, not on a
  device.
- No export build for any platform was produced or run.

### Deferred from this milestone

- Save files and the Continue flow (Milestone 03).
- Any simulation, economy, politics, diplomacy or military system.
- Historical or alternate scenarios — none are implemented, so none are offered.
- Maps at 1:10m detail, more projections, country flags, and a per-country "zoom to fit" animation.
- Full localisation of country names (the dataset has translations; the interface is English).
- **Named sub-national regions and continents as first-class map entities.** The dataset's classification
  is used for filters; drawing labelled sub-regions needs a different dataset and is deferred.
- **Strided border simplification at low zoom** (noted in `docs/PERFORMANCE.md`): only worth doing if a
  device measures a problem, and no device has been measured.
- **A tested Android build.** An export preset and a manual, non-blocking debug-APK workflow exist, but
  no APK has been produced or run — the workflow has never completed a successful export here. The
  honest status, the known risks and the acceptance criteria for calling Android "supported" are in
  [docs/ANDROID.md](docs/ANDROID.md). This remains non-blocking and out of scope for Milestone 03.

## Milestone 03 — Simulation core, save system & playable campaign shell

Status: **Implemented** (details: `docs/SIMULATION_CORE.md`, `docs/SAVE_FORMAT.md`)

### Implemented

- **Simulation core, no UI dependency.** `GameClock` with a fixed documented start (1 January 2026),
  one tick = one in-game day, pause plus four speeds defined as *ticks per second* (2, 8, 32, 128
  days/second), correct Gregorian month lengths and leap years, and a per-frame tick cap (64) that
  carries its remainder so a slow frame delays ticks instead of skipping or repeating them.
- **Deterministic randomness.** SplitMix32 with a campaign seed and named per-system streams, so
  adding a system can never shift another system's numbers. 1,000 ticks from the same seed produce
  the same state hash in the test suite.
- **Event bus.** Queued, non-recursive delivery; priority then subscription order; subscriptions
  changed during delivery take effect on the next one; payloads documented read-only.
- **System framework.** Registration with id, order band, frequency (daily/monthly/yearly) and
  version. The **only registered system is the calendar** — there are no placeholder systems.
- **WorldState.** Scenario id and version, player country by stable id, clock, seed, game-version
  stamp, data stamp, extensible versioned per-country sections, validation with precise messages and
  a canonical state hash. Static (registry and geometry, read-only) and dynamic (saved) state are
  separated; **saves never contain map geometry**.
- **Save/load.** Versioned JSON (schema 2) in `user://` only: atomic temp-write → verify → backup →
  swap, one rolling backup per slot, three slots plus an autosave, autosave on each in-game month and
  on leaving the campaign, checksum plus state hash, strict validation (fractional or infinite
  numbers, wrong types, unknown country ids, oversized files), migration from schema 1, and a
  refusal of newer schemas that leaves the file untouched. Export and import through file dialogs.
- **Playable campaign shell.** Confirming a campaign starts the game screen after a short skippable,
  reduced-motion-aware transition: top bar (in-game date, pause and speed controls, player country,
  pause-menu button), the existing interactive map with the player's nation marked by a ring and the
  words "YOUR NATION" (not by colour alone), and the existing country dossier for the selected
  country — selecting another country never changes who you lead. A status panel states honestly
  that only the calendar runs.
- **Pause menu** (Resume, Save, Save as…, Load, Settings, guide, Quit to main menu with an unsaved
  confirmation, and an "early foundation" version line), **Load screen** listing all four slots with
  country, date, playtime and save time, including damaged slots and backup recovery.
- **Main menu** `Continue` enabled only when a save actually loads, plus a `Load Game` entry.
- **First-run guide** (four short steps, skippable, re-openable from the pause menu) stored in the
  existing settings store.
- Keyboard: Space pauses, 1–4 choose the speed, Escape opens the pause menu; documented in Settings.

### Tested here

- Headless suites `test_simulation_core.gd`, `test_save_system.gd` and `test_game_shell.gd` — calendar
  arithmetic, tick cap and slow frames, pause, 1,000-tick determinism, stream isolation, bus ordering
  and re-entrancy, save round-trip, tampering, truncation, invalid numbers, unknown ids, newer-schema
  refusal, schema-1 migration, backup recovery, injected write failures, slot listing, export/import,
  the game screen at six reference sizes, keyboard shortcuts, dossier selection, first-run guide,
  repeated enter/leave, Load screen and Continue.
- CI (`.github/workflows/ci.yml`) is green with every step gating: lint, atlas hashes, atlas audit and
  report freshness, policy-document freshness, import, a parse check that fails on real compile errors,
  the full suite (**18 suites, 249 862 assertions, 0 failures**), the simulation/save benchmark and a
  headless boot smoke test that fails on any script error. The logs are published as commit comments,
  which is where the numbers above were read.
- Measurements from `tools/sim_benchmark.tscn` (see `docs/PERFORMANCE.md`): 17.9–18.5 µs per simulated
  day, 1.34 ms per atomic save, 0.71–0.77 ms to load with the atlas warm, a 1 247-byte save file.

### Not tested here

- **No build has run on a phone.** Touch layout, save/load timing on mobile storage and the file
  dialogs on Android/iOS are **UNVERIFIED**.
- No export build for any platform was produced.

### Deferred from this milestone

- Every subsystem that would produce statistics: economy, budgets, politics, elections, diplomacy,
  military, country AI, resources, real-world statistics, UN mechanics, world editor, achievements and
  news feed.
- A full tutorial (the first-run guide is a handful of steps, deliberately).
- Rolling multi-generation save history (one backup per slot today).
- Simulation-generated events and player-defined goals — design only, in
  [docs/OPEN_ENDED_DESIGN.md](docs/OPEN_ENDED_DESIGN.md).

## Milestone 04 — Presentation foundation: readable map, print-clean interface

Status: **In progress** — Tasks 1–6 implemented and tested; the documentation and
gate audit (Tasks 7–9) is in progress and is listed honestly at the end of this section.

This milestone is *presentation only*. It adds no economy, no politics, no
diplomacy, no military, no AI, no resources, no scenarios, no editor, no
achievements, no news, and **no statistics**: the roadmap's statistics milestone
moved to number 05 so this one could take its place without pretending the work
was something else.

### Task 1 — Per-country data folders (implemented, tested)

`data/world/countries/<STABLE_ID>/` is now the source of truth: `identity.json`,
`geometry.json`, `sources.json`, a generated `README.md`, and `capital.json`
where a capital is recorded (196 of 242 records). The runtime pack
(`countries.json`, `geometry.json`, `manifest.json`) is generated *from* those
folders by `tools/build_country_pack.py`, which also proves the bytes it writes
match the committed pack. `tools/validate_country_folders.py` audits the tree and
tests itself against deliberately broken fixtures; `tools/report_data_completeness.py`
writes `docs/DATA_COMPLETENESS.md`. The convention for future files, with Bangladesh
and the United States worked through by hand, is in `docs/COUNTRY_FOLDER_GUIDE.md`.
Gameplay-visible data did not change: `countries.json` and `geometry.json` are
byte-identical to the previous pack.

### Task 2 — Map polish (implemented, tested)

- **Coastline hints.** `data/world/coast.json`, generated by
  `tools/build_coast_data.py` from segment reuse in the geometry, tells the
  renderer which rings are coastline (`1`), shared land border (`0`) or mixed
  (`2`). 1,631 rings: 1,421 coast, 64 land, 146 mixed. A missing hint file means
  plain borders, never an invented coastline.
- **Hierarchy.** Coastline > land border > selected border, in zoom-adaptive
  widths, with the player's country keeping a dashed outline.
- **Depth and reference.** A two-tone ocean gradient, an optional 15° graticule
  and optional equator/tropics dashes, readable in both Midnight and Parchment.
- **Region tints.** Six tones ordered by lightness, so two neighbours in different
  regions do not read as one shape; the tints are a secondary cue and the docs say
  so rather than over-claiming a contrast ratio they cannot reach.
- **Selection cues that do not depend on colour.** Corner ticks around the
  selection, a dash over records a campaign cannot start as, a dashed outline for
  the player, and minimum markers for countries too small to see. Hit boxes are
  geometry, so none of this changes what a tap selects.
- **Labels.** Haloed, zoom-faded, density-capped (26 / 14), with the existing
  collision rules unchanged.
- **Display options.** Label density, borders, capitals, grid, reference lines and
  reduced detail, in a touch-sized keyboard-operable panel, persisted in the
  settings store (`MapOptions`), shared by the campaign screen and the game screen.
- **Legend and scale bar.** An unobtrusive three-sample key plus the existing
  scale indicator.
- **Cost.** The new layers cost five draw commands in the model computed by
  `tools/map_render_cost.py` (2,381 vs 2,376) with no change in vertices, because
  the grid, dashes, ticks, legend samples and scale ticks are batched into single
  `draw_multiline` calls. Frame timings are **unverified**: there is no GPU here
  and the headless renderer does not draw.
- **Docs.** `docs/MAP_RENDERING.md` covers every layer, the measured colour
  table, the option table and the cost model.

### Task 3 — Animation foundation (implemented, tested)

- **One table, one runner.** `src/ui/animation/animation_tokens.gd` names every
  animation with its duration, easing, trigger, reduced-motion answer and flash count;
  `src/ui/animation/animation_service.gd` is the only thing that starts a tween.
- **The four rules**, each with a test: nothing blocks input (the runner never touches
  it, and the camera flight is cancelled by the first gesture), nothing animates when
  nothing changes (asking for the value a target already has starts no tween), every
  animation has a reduced-motion answer (values applied at once, no tween, loops never
  start), and nothing flashes more than three times per second (the generator refuses
  to write a document that would).
- **Camera fly-to** on selecting from search, the recent list or the dossier: clamped by
  `MapCamera.set_view()` on every step, so it cannot leave the world, and cancelled by any
  pan, zoom or key press. Reduced motion jumps.
- **Selection pulse** on the outline only, **panel slide/fade** for the map display panel
  and the pause menu, **press feedback** on rows and map controls, smooth speed and pause
  labels, a **campaign-start fade** that any input skips, and an **ambient sea** whose
  cadence comes from the table and which does no work when paused, in reduced detail, or
  under reduced motion.
- **`docs/ANIMATION.md`** is generated by `tools/report_animations.py`, which also fails
  when an animation used in code is missing from the table.
- **Limitation:** the durations are chosen values, not measured on a display. Timings
  were not verified on a device.

### Task 4 — Game-screen polish (implemented, tested)

Dossier regrouped into Identity, Geography, Administrative, Data sources and a new Data
completeness group that lists the record's own gaps and states that it is not a score.
Load Game cards carry a Ready/Damaged/Empty badge, the country marker, the in-game date,
playtime and last-saved time, and damaged slots state the reason and the backup
consequence in plain words. The pause menu and guide fade in through the animation
service; the campaign-start transition is skippable and never covers the top bar.

### Task 5 — Accessibility sweep (partly implemented, partly tested)

New colour pairs are declared in `Palette.CONTRAST_REQUIREMENTS` and checked in both
themes; the completion suite walks the keyboard focus chain of six screens in three
layouts and checks that every focusable control is reachable; Load Game controls are
measured against the 48 px touch minimum; repeated enter/leave loops are checked for node
growth. **Not done:** a written focus-order report for the map options panel, legend,
dossier, pause menu and game top bar, and the theme-switch leak loops on those panels.

### Task 6 — Extras (implemented, tested)

Recently viewed countries appear as chips under the atlas search (settings only, never in
a save); a keyboard cheat sheet exists as a screen and as an in-campaign panel, driven by
the same table the tests read; a developer map inspector reports a record's stable ID,
source type, polygon and vertex counts and starts hidden, reachable only from the pause
menu or F4; "About the data" reads `data/world/manifest.json` and prints source, version,
retrieval date, commit, licence, counts, limitations and one neutral sentence about status
that names no country.

### Tasks 7–9 — in progress

The gate audit has started: the benchmark step now requires `BENCHMARK OK` instead of
trusting a piped exit code, and a manual-only `workflow_dispatch` job runs a canary suite
that must make the gate fail. `docs/DATA_QUALITY.md` gained a generated coastline-hints
section. `docs/PR_REVIEW_GUIDE.md` is written. **Open:** the rendered-screenshot
investigation (Task 9) has not produced a capture, so no screenshot is claimed.

## Milestone 05 — Country statistics foundation (& Milestone 04 closeout)

Status: **Implemented, in part** — reference figures are in the game; nothing simulates them yet.

Done in this milestone:

- **Sourced, citable key figures** for all 242 records: population and GDP from the pinned Natural
  Earth file (its own estimates, each with the year the source records it for), plus an area
  derived from the committed outline and labelled as derived. One source, one pin, one crosswalk;
  no value typed from memory. Source, licence, retrieval date and every rejected value are in
  [`docs/STATISTICS_REPORT.md`](docs/STATISTICS_REPORT.md).
- **A dossier "Key figures" group** with the as-of year and the source beside every value, and
  "Not available" — never `0` — where the source has nothing.
- **A read-only Country Comparison screen**: up to three countries side by side, dashes for missing
  values, keyboard and touch, all three layout sizes, both themes. Reachable from the atlas and
  from a campaign, with no ranking or score language anywhere on it.
- **"About the data"** lists the statistics dataset, version, retrieval date, licence, attribution
  and per-figure coverage.
- Milestone 04 closeout: controls raised to the 48 px touch target with the remaining sizes
  recorded in [`docs/CONTROL_SIZES.md`](docs/CONTROL_SIZES.md); antimeridian framing fixed for the
  three records whose outline spans both map edges, with tests.

Deliberately **not** done, and not started:

- No simulation reads a figure: no growth, no economy tick, no trends, no projections.
- Not in `WorldState`, not in a save, no migration needed.
- `docs/STATISTICS_DESIGN.md` describes that boundary and is marked PLANNED wherever it discusses
  using the numbers.

**Milestone 04 closeout, item by item:**

| Item | State |
| --- | --- |
| A1 focus-order report | **Partial.** Not regenerated: producing it needs a running engine to walk focus, and the environment that prepared this milestone has no Godot binary (see below). The Milestone 04 documentation is unchanged and nothing new is claimed. |
| A2 theme-leak node counts | **Partial**, for the same reason. The new comparison screen is covered instead by a test that builds it in both themes and proves the figures and the missing-value dash do not change (`tests/suites/test_statistics.gd`). |
| A3 48 px controls | **Done.** Raised, with the short-window exception at 40 px recorded with its reason and its measurement in [`docs/CONTROL_SIZES.md`](docs/CONTROL_SIZES.md); the game-shell layout test measures the map's height at six reference sizes, including 640×360, and refused the first attempt. |
| A4 antimeridian framing | **Done.** `WorldGeometry.focus_bbox_of()` frames the mainland; Russia, the United States and Fiji no longer fly out to the whole world, and a negative-width rectangle can no longer move the camera nowhere. Six cases in `tests/suites/test_camera_framing.gd`. |
| A5 exact Milestone 04 Task 7 leftovers | **Not done as a separate audit.** The leftovers listed at the end of Milestone 04 were the A1/A2 reports; there is no other item, and this table is the honest answer rather than a completed checklist that was not run. |
| A6 Godot + software GL in CI | **Re-checked once.** Godot runs headless in CI (import, parse check, full suite, benchmark, boot smoke — all green), so engine-level checks do run there. *Rendered* output with software GL is still not available: the CI job has no display, and the local environment could not install an engine at all. The existing documentation is unchanged. |

## Milestone 06 — Politics & economy

Status: **Planned**

- Government, parties, elections, approval, stability, corruption.
- Budget, taxation, spending, trade, inflation, unemployment, debt and (rarely) sovereign default.
- Explicit non-interference with the player's game wallet, enforced by tests.

## Milestone 07 — Diplomacy & military

Status: **Planned**

- Relations, treaties, alliances, sanctions, negotiations; AI attitudes per country.
- Force structure, readiness, logistics, conflict resolution, occupation and peace terms.

## Milestone 08 — Platform builds & accessibility pass

Status: **Planned**

- Export presets for Windows, macOS, Linux and Android; iOS build instructions documented for a
  machine with Apple tooling.
- Safe-area support, controller navigation, text scale review, colour-vision check on semantic
  colours.
- Performance budget verification on low-end mobile hardware.

## Milestone 09 — Audio & polish

Status: **Planned** — ambient score, interface sounds, mixing settings, final visual polish pass.

---

## Milestone 06 — real codes, licence, and the picker's ground truth

Delivered in this milestone, each with the check that proves it:

| Item | Status |
| --- | --- |
| Country codes from the source's own corrected fields, with `code_status` (`iso-official` / `user-assigned` / `none`) | **Done** — `tools/build_country_codes.py`, `data/world/iso_codes_crosswalk.json`, `docs/COUNTRY_CODES_AND_REGIONS.md` |
| Both codes shown in the dossier and searchable; a record with no code says so | **Done** — dossier identity group, `test_country_codes.gd` |
| Stable ids unchanged, geography byte-identical, folders/pack/manifest/READMEs regenerated | **Done** — `geometry.json` and `coast.json` unchanged; ids identical |
| Picker region mapping: 17 groups, exactly one per record, published rules, review list | **Done (data only)** — `data/world/picker_regions.json`; the picker UI itself is not built |
| Licence, third-party licences, README/About/CONTRIBUTING, `docs/SECURITY.md` | **Done** |
| `docs/GAME_VISION.md` (with open questions), `docs/WALKTHROUGH.md` | **Done** |
| First-run flow (loading, terms, consent), picker UI, flags, tutorial, XP/VIP, profile, backup, integrity signature, store exports | **Not started** — planned |


## Deferred (no milestone assigned)

- Real-time multiplayer or any online service.
- Cloud saves or accounts.
- Localisation. Text is authored in English; no string-extraction pipeline exists yet.
- Automatic system-theme following.
- Procedural generation of world history or scenarios.
- Any monetisation of any kind.

## Known limitations recorded in Milestone 01

- No rendered verification was possible in the development environment (headless only); the committed
  layout diagrams are geometry drawings, not screenshots.
- The light theme is complete and contrast-tested, but its final look has not been reviewed on a
  real display.
- iOS cannot be built from this repository alone: it requires Xcode, signing identities, provisioning
  profiles and an Apple Developer account held by the project owner.
- The interface scale setting from 130 % on a small phone in landscape will require scrolling on the
  settings screen; that is intended behaviour, not a defect, but it deserves a device check.
