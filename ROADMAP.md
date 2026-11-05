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
  1 620 polygons, 1 631 rings, 99 568 vertices, 1.2 MB of JSON. Coastlines and borders are real
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
  Israel/Palestine is documented and asserted by tests. Statistics (population, GDP, income group)
  are deliberately not imported.
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
- **Tests.** Five new suites: country data and manifest, geometry and hit-testing, camera and
  interaction, campaign configuration and flow, and campaign UI at seven reference sizes in both
  themes.

### Tested here

Headless Linux build of Godot 4.6.3 (compiled from the official source tag, `vulkan=no opengl3=no`):

- `gdlint src tests tools` — clean.
- `godot --headless --path . --import` — resources imported, no script errors.
- `godot --headless --path . res://tests/test_runner.tscn` — 11 suites, 0 failures (assertion count
  in the milestone report).
- Application smoke run boots the shell without errors.
- Atlas benchmark (`tools/atlas_benchmark.tscn`) — load, mesh-build and query timings recorded in
  [docs/PERFORMANCE.md](docs/PERFORMANCE.md), with the frame-time caveat stated there.
- Layout geometry inspected node by node at 1920×1080, 1280×720, 1024×768, 844×390, 640×360,
  390×844 and 360×800.

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

## Milestone 03 — Save management & campaign continuity

Status: **Planned**

- Versioned save format built on the `CampaignConfig` schema introduced in Milestone 02, with
  migration support, atomic writes and a corruption-safe fallback.
- Autosave/rolling saves, manual slots, and delete/duplicate.
- The `Continue` and `Load` flows on the main menu become functional (they stay disabled and
  labelled **PLANNED** until then).

## Milestone 04 — Simulation core

Status: **Planned**

- Deterministic tick-based simulation (fixed step, seeded RNG, no floats for money).
- Time advance (pause / play / speed), event scheduling, and a pure-logic test harness for
  long-run invariants (no money created from nothing, no state explosion).
- Country statistics and trends surfaced in the interface.

## Milestone 05 — Politics & economy

Status: **Planned**

- Government, parties, elections, approval, stability, corruption.
- Budget, taxation, spending, trade, inflation, unemployment, debt and (rarely) sovereign default.
- Explicit non-interference with the player's game wallet, enforced by tests.

## Milestone 06 — Diplomacy & military

Status: **Planned**

- Relations, treaties, alliances, sanctions, negotiations; AI attitudes per country.
- Force structure, readiness, logistics, conflict resolution, occupation and peace terms.

## Milestone 07 — Platform builds & accessibility pass

Status: **Planned**

- Export presets for Windows, macOS, Linux and Android; iOS build instructions documented for a
  machine with Apple tooling.
- Safe-area support, controller navigation, text scale review, colour-vision check on semantic
  colours.
- Performance budget verification on low-end mobile hardware.

## Milestone 08 — Audio & polish

Status: **Planned** — ambient score, interface sounds, mixing settings, final visual polish pass.

---

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
