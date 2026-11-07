# WORLD DOMINION — Architecture

> Scope: Milestone 01 (application foundation). Gameplay systems are described as intended
> boundaries, not as existing code.

## 1. Goals driving the structure

1. **One project for every platform.** No Android-only or desktop-only assumptions in shared code.
2. **Simulation separated from presentation.** Game logic must be testable headlessly and must not
   depend on scene nodes.
3. **Predictable boundaries.** A developer (or an AI agent) should know where a change belongs
   without reading the whole repository.
4. **Local-first.** Saves and settings are files on the device; no service is required to play.
5. **Small dependency surface.** Engine + GDScript + JSON. Nothing else at runtime.

## 2. Directory layout

```
project.godot                 Engine config, autoload registration, window/stretch settings
icon.svg

src/
  app/
    main.tscn / main.gd       Application root: backdrop, screen host, transition overlay
    screen_router.gd          Screen lifetime, history, fade transitions
  autoload/
    settings_service.gd       Autoload `Settings` — player preferences + persistence
    game_session_service.gd   Autoload `Game` — the running campaign + the shared save store
    theme_manager.gd          Autoload `ThemeManager` — builds/applies the active theme
  core/
    config/
      settings_schema.gd      Allowed keys, defaults, validation, labels
      settings_store.gd       ConfigFile read/write with recovery
      map_options.gd          Typed view over the map display settings
    data/
      data_loader.gd          Defensive JSON loading from res://data/
    economy/
      game_wallet.gd          Game-wallet currencies (Gold Coins, Diamonds), integer-only
    world/
      country_record.gd       One country: metadata + validation, no map/UI knowledge
      country_registry.gd     Catalogue, id index, region filter, search
      world_geometry.gd       Polygon geometry in lon/lat, parsed from data/world/
      country_lookup.gd       Spatial grid + point-in-country hit testing
      map_projection.gd       The equirectangular projection, in one place
      map_camera.gd           Centre/zoom, clamping, focus, screen<->world transforms
      atlas_history.gd        "Recently viewed" ids, local to the settings store
      atlas_filter.gd         Query + region filter state
      world_atlas.gd          Loads registry + geometry + index + manifest together
    profile/
      player_profile.gd       Display name, username, player ID, XP, VIP, wallet, avatar index
      profile_store.gd        Atomic profile writes, rolling backup, checksum + signature
      progression.gd          XP curve, level and VIP derivation (one formula, documented)
      first_run_store.gd      Terms version + acceptance, notification preference, completion
    campaign/
      scenario.gd             One scenario definition (id, name, start date, implemented)
      scenario_catalog.gd     Directory-backed catalogue of scenarios
      campaign_config.gd      Versioned campaign configuration + validation
    sim/
      game_date.gd            The calendar: day index, months, leap years, formatting
      deterministic_rng.gd    SplitMix32 — integer-only, platform independent
      random_streams.gd       Named per-system streams derived from the campaign seed
      event_bus.gd            Queued publish/subscribe with fixed delivery order
      simulation_system.gd    Base system: id, order band, frequency, version
      systems/calendar_system.gd  The only shipped system: day/month/year events
      game_clock.gd           Tick rates, pause, per-frame cap with carried remainder
      canonical_json.gd       Deterministic JSON + SHA-256 for hashes and checksums
      world_state.gd          Dynamic campaign state, validation, state hash
      simulation.gd           Runs the clock and the registered systems
    save/
      save_file.gd            The file format: build, checksum, parse, summary
      save_migrations.gd      One step per schema version, never downward
      save_store.gd           Slots, atomic writes, backups, listing, export/import
      game_session.gd         One running campaign: world + simulation + playtime + autosave
  platform/
    platform_info.gd          The only place that asks "what am I running on?"
  ui/
    map/
      world_map_view.gd       Interactive map: cached meshes, coastlines, labels, input
      map_controls.gd         Zoom in / out / fit / display-options overlay buttons
      map_options_panel.gd    The map display panel (labels, borders, grid, detail)
    theme/
      design_tokens.gd        Spacing, type ramp, radii, motion, breakpoints
      palette.gd              Midnight + Parchment palettes and contrast requirements
                              (including the map tokens and their measured minimums)
      typography.gd           Font loading and tracking
      theme_factory.gd        Builds a Theme from tokens + palette (named variations)
      motion.gd               Durations/easing, reduced-motion aware
    profile/
      avatar_art.gd           The twenty avatars, drawn in code: names, colours, five motifs
    strings.gd                The string table: every new screen's player-facing text, by key
    components/
      nav_row.tscn/.gd        Navigation entry (title, caption, badge, states)
      segmented_control.tscn/.gd  Mutually exclusive option row
      setting_row.tscn/.gd    Label + description + control, stacks when narrow
      app_header.tscn/.gd     Back button, context line, title block
      flag_tile.gd            One flag at 40×30, rasterised lazily; code badge when absent
      flag_strip.gd           Swipeable, snapping row of flag tiles for one group
      country_picker_panel.gd Region groups, A–Z index, A–Z list, search, one selection
      avatar_glyph.gd         One avatar drawing at whatever size its parent gives it
      avatar_gallery.gd       The 5 × 4 selectable avatar grid, each cell named
    screens/
      responsive_screen.gd    Base class: margins per breakpoint, layout hooks
      first_run/              Loading, terms, notifications, profile creation (once per version)
      profile/                The profile screen: identity, XP, wallet, avatars, rename, username
      main_menu.tscn/.gd
      campaign_setup.tscn/.gd
      game_screen.tscn/.gd    The campaign: top bar, map, dossier, pause menu, guide
      load_game_screen.tscn/.gd  Slot list, damaged-slot handling, export/import
      settings_screen.tscn/.gd
      about_screen.tscn/.gd
    backdrop/
      atlas_backdrop.tscn/.gd Procedural chart backdrop
assets/
  fonts/{spectral,ibm_plex_sans,ibm_plex_mono}/  woff2 subsets + OFL licences
  icons/{chevron_right,arrow_left,reset}.svg  Original 48×48 grid icons, tinted by the theme
  shaders/vignette.gdshader   Vignette + dither over the backdrop
data/
  app_meta.json               Build status, about copy
  credits.json                Creator, contributors, AI assistance, third-party licences
tests/
  test_case.gd                Assertions + discovery
  run_tests.gd / test_runner.tscn
  suites/test_*.gd
```

Boundaries that exist as documentation only — **create them when the first real code arrives, not
before**: `src/politics/`, `src/diplomacy/`, `src/military/`, `assets/audio/`. Empty folders and
placeholder scripts add noise and rot; the README of each future area is the pull request that
introduces it. `core/sim` and `core/save` arrived with Milestone 03, exactly when they were needed.

## 3. Dependency rules

```
        ui/screens ──▶ ui/components ──▶ ui/theme ──▶ assets/
             │                │              │
             ├────────────────┴──────────────┴──▶ autoload (Settings, ThemeManager)
             ▼
          core/*        (no dependency on ui/ or scenes)
             ▲
        platform/platform_info  (no dependency on ui/)

          core/sim ◀── core/world     (systems read registry data, never scenes)
          core/save ◀── core/sim      (a save serialises WorldState; it never imports UI)
          ui/* ──▶ core/sim, core/save (the game screen reads state; it owns none of it)
```

Hard rules:

- `src/core/**` must not import UI scripts, scenes or `ThemeManager`. It is the part that can run in a
  headless test or (later) in a fast simulation loop.
- `src/ui/**` may read core types and autoloads; core never reads UI.
- Only `src/platform/platform_info.gd` may branch on the operating system. If a screen needs to know
  something platform-specific, it asks this file.
- Currency code (`src/core/economy`) must never reference national economy types; the test suite
  enforces this for `game_wallet.gd`.
- Screens communicate upwards through signals (`navigate_requested`, `back_requested`,
  `quit_requested`, `home_requested`); they never reach into the router or each other.
- `src/core/sim/**` and `src/core/save/**` must not create nodes, read the scene tree, load a texture
  or touch `ThemeManager`. The simulation can be advanced 1,000 times inside a test with no window.
- Only `SaveStore` writes under `user://`. A screen that wants to save asks the store; nothing else
  opens `FileAccess` on the save folder.

## 4. Application flow

`src/app/main.tscn` is the only scene the engine starts.

1. `Main._ready()` creates a `ScreenRouter` with the screen registry (`PackedScene` per id) plus the
   screen host and the transition overlay.
2. `ScreenRouter.start("main_menu")` instantiates the menu, sets full-rect anchors, then calls
   `play_entrance()` if the screen defines it.
3. Navigation: a screen emits `navigate_requested(screen_id)`; `Main` asks the router to `go_to()`.
   The router fades the overlay to the backdrop colour, swaps the screen at full coverage, calls the
   new screen's `play_entrance()`, then fades out. Durations come from `Motion`, which returns 0 when
   the player enabled reduced motion, so the whole transition collapses to an instant swap.
4. Back: `ui_cancel` (Escape / Android back) or the header's back button pops the router history.
5. Every screen derives from `ResponsiveScreen`, which applies design-token margins for the current
   viewport size and calls `on_layout_changed()` so each screen can adapt its own rhythm.
6. **A campaign is an object, not a screen.** `Game` (autoload) holds the running `GameSession` and one
   `SaveStore`. The campaign setup screen calls `Game.start(config)`, the load screen calls
   `Game.resume(slot)`, and both then ask the router for `game`. Leaving to the title calls
   `Game.close()`, which is the single place a campaign ends — that is what makes repeated
   enter/leave cycles leak-free and what lets Settings open on top of a paused campaign without
   destroying it.

## 4a. The screens-first milestone

Milestone 08 is screens: it builds the interface a new player meets before any of the planned
simulation exists, and it says so in each screen rather than implying more.

- **First run** (`src/ui/screens/first_run/`): a loading screen that reports the real steps it
  performs, the versioned terms page, a notification *preference* that requests no permission
  and promises nothing (`PLANNED` is on the screen), and profile creation through the same
  `PlayerProfile` validation the rest of the game uses. `FirstRunStore` decides what happens on
  launch: first run, terms version changed, or straight to the menu.
- **Country picker** (`country_picker_panel.gd`, `flag_strip.gd`): the setup screen's right
  panel and bottom strip share one selection with the map and the dossier, through
  `select_country()` — the single place a country is chosen on that screen.
- **Profile** (`src/ui/screens/profile/`): reads the profile file and nothing else. Price and
  balance are shown before a rename; the charge itself goes through `PlayerProfile`, so a
  screen cannot skip it. Avatars are code-drawn from an index, because a profile file that
  could hold a path or a URL would be a door this project does not want.
- **Tutorial** (`src/ui/tutorial/tutorial_steps.gd`, `src/ui/components/tutorial_panel.gd`):
  six steps over the running campaign, data-driven, each naming a feature whose control a test
  resolves on the mounted game screen. The panel emits `finished` or `skipped`; only the
  screen's `_award_tutorial()` pays, and it pays through `PlayerProfile.complete_tutorial()`,
  so skipping cannot award and a second finish cannot pay twice.
- **Worlds and backup** (`src/ui/screens/worlds/`, `src/ui/screens/backup/`): a face on the
  existing `SaveStore` and `BackupBundle` engines. `IntegrityDialog` is the only recovery UI:
  three answers, no fourth, and it writes nothing — each screen maps an answer onto its own
  files, which is what lets a profile, a world and a restore share one question honestly.
  `ProfileStore.load_or_create()` gained `allow_backup` so the profile screen can ask instead
  of taking the rolling copy silently.
- **Deliberately absent**: any platform file dialog. Backups live in `user://backups`, which
  needs no OS integration; a picker is PLANNED and UNVERIFIED on real devices.

## 5. Theming pipeline

There is no hand-edited `.tres` theme. The theme is generated:

```
DesignTokens (spacing/type/motion)  ─┐
Palette.colors(palette_id)          ─┼─▶ ThemeFactory.build() ──▶ Theme ──▶ Window.theme (root)
Typography (fonts, tracking)        ─┘                                   │
                                                                         ▼
                                                     every Control inherits it
```

- Components select appearance through **type variations** (`theme_type_variation = &"NavRow"`), never
  through per-instance `theme_override_*` styling. The few overrides that exist are responsive
  typography, state-driven label colours and responsive component sizes, all commented at the call
  site. Widget metrics that the engine exposes as theme constants (button `icon_max_width`,
  container separations with no token equivalent) are set once in `ThemeFactory`.
- `ThemeManager` rebuilds and reapplies the theme when the palette setting changes and emits
  `theme_changed`, which custom-drawn widgets (backdrop, accent markers) listen to.
- Changing a colour means changing `Palette`; changing spacing means changing `DesignTokens`. Both
  are covered by tests, so drift is caught.

## 5a. Animation

Animation is a small, single-purpose layer, not a framework. `AnimationTokens` is a table
of named animations — duration, easing, trigger, reduced-motion answer, flash count — and
`AnimationService` is one object per screen that starts tweens and cancels them when the
screen leaves the tree. Screens never call `create_tween()` for presentation; the service
applies a final value instantly under reduced motion and refuses to start a tween when the
target already holds the requested value, which is what keeps an idle screen free of work.
The camera flight is the one case that is not a property tween: it drives `MapCamera` step
by step so the camera's own clamping applies on every frame, which is why it can never
leave the world and why any gesture can cancel it. `docs/ANIMATION.md` is generated from
the table, so the document and the code cannot drift.

## 6. Settings and persistence

- `SettingsSchema` owns keys, defaults, allowed values and display labels.
- `SettingsStore` reads/writes `user://settings.cfg` through `ConfigFile`; every value passes through
  `SettingsSchema.sanitize()` on load, so unknown, outdated or hand-edited values degrade to defaults.
- `Settings` (autoload) exposes typed accessors, emits `changed(key, value)`, applies the interface
  scale to `Window.content_scale_factor`, and records the last save error so the settings screen can
  warn the player instead of silently losing choices.
- Saves for campaigns do not exist yet. The intended design (Milestone 03) is a versioned, chunked
  JSON save per slot under `user://saves/`, written to a temporary file and renamed, with a migration
  path per version bump.

## 7. Cross-platform strategy

- **Resolution independence.** `display/window/stretch/mode = canvas_items` with
  `aspect = expand`. The interface is laid out in logical pixels and adapts to the real window size
  rather than letterboxing.
- **Breakpoints, not devices.** `DesignTokens.layout_mode()` classifies the available space
  (`COMPACT < 620 ≤ MEDIUM < 1024 ≤ EXPANDED`) plus `is_short()` for scarce height. No screen asks
  what platform it is on.
- **Input parity.** All interactive elements are `Button`s or containers of `Button`s, so touch, mouse
  and keyboard/Tab navigation behave identically. Touch targets are at least 44–48 px; hover is never
  the only way to reveal an action.
- **Landscape target.** `display/window/handheld/orientation = 0` (landscape) for handhelds, with
  layouts that still behave in portrait and can reflow if that decision changes.
- **Platform isolation.** `platform_info.gd` centralises desktop/mobile questions, touchscreen
  detection and renderer naming. Quit is offered only where programmatic quitting is appropriate
  (desktop, not iOS).
- **Known gaps** — safe-area insets (notches), iOS signing/distribution (requires Apple tooling and an
  Apple Developer account), export presets and per-platform verification. None of it is claimed.

## 8. Content data

`res://data/*.json` holds content that changes independently of code: build status and credits. The
about screen and the main menu's dossier render from it, falling back to visible empty states if a
file is missing or malformed. `DataLoader` reports failures with `push_error` and returns empty
values rather than crashing the shell.

Future world/country content will use the same approach with a versioned schema and a validation test,
so content errors surface in CI instead of in a player's session.

## 9. World atlas: data, geometry and rendering

The atlas is the first part of the project with real content, so the boundaries are explicit:

```
data/world/*.json  --(CountryRegistry / WorldGeometry)-->  core world objects
                                                              |
                              WorldAtlas  -------------------+
                                    |                         |
                        CountryLookup (hit tests)      CampaignSetup screen
                                                              |
                                                     WorldMapView (draws, input)
```

* **`CountryRecord` / `CountryRegistry`** know nothing about geometry, cameras or the map. They parse
  metadata, index it by stable id, and answer *search* and *region* questions. A UI-free test suite
  exercises them directly.
* **`WorldGeometry`** owns the polygon wire format: flat integer arrays in 1/200° stored in
  `data/world/geometry.json`, parsed into `Vector2` rings in degrees. Malformed rings are dropped
  individually and reported; nothing throws.
* **`CountryLookup`** builds a 10°×10° grid of bounding boxes once and answers "which country is
  under this lon/lat?" with an even-odd point-in-ring test against the surviving candidates. The
  smallest bbox wins when they overlap, which is what makes enclaves selectable.
* **`MapProjection`** is the single place that defines the projection (equirectangular / plate
  carrée). Swapping to Miller or Robinson later means changing two functions, not the data.
* **`MapCamera`** is a plain `RefCounted` holding centre and zoom (pixels per degree). Every mutation
  re-clamps, which is why the map cannot be dragged or zoomed out of view. It has no Node dependency,
  so camera behaviour is unit-tested without a scene.
* **`WorldAtlas`** assembles the four above plus the manifest and records how long the load took.
* **`CountryDossier`** turns a record (plus atlas facts such as polygon counts and the dataset
  version) into sections of label/value pairs, marking every field the source does not provide. It is
  data, not UI: the panel walks it, and a future screen can read the same object.

### Rendering approach

`WorldMapView` draws the map in `_draw()` with three techniques chosen for cost:

1. **Cached triangle meshes.** Each country's outline rings are triangulated once with
   `Geometry2D.triangulate_polygon` and committed to an `ArrayMesh` in world (lon/lat) space. Panning
   and zooming only change the canvas transform, so they cost no vertex work at all. Holes are a
   second cached mesh drawn in the sea colour, which is how Lesotho reads as a hole inside South
   Africa without polygon booleans.
2. **Culled border polylines.** Borders are stroked in world space with a width of `1 / zoom`, so
   they stay one pixel at every zoom level. Countries smaller than 7 px on screen keep their fill but
   lose their stroke.
3. **Level of detail for labels.** Country labels come from the dataset's own label anchor and
   `LABELRANK`, are limited to a rank threshold that relaxes as the player zooms in, and are skipped
   when they would overlap a label already placed. At most 26 labels are drawn. Ocean names are
   project-authored anchors drawn only at world zoom, under the country labels and above nothing else.
4. **Tiny-shape markers and scale bar.** Countries whose whole shape is under 6 px get a marker ring
   so they are visible at all; the scale bar is drawn in screen space from
   `KILOMETRES_PER_DEGREE × cos(latitude) / zoom`, so the distance it claims is the distance at the
   centre of the view. The bar states kilometres, not a projection guarantee.
5. **Triangulation fallback.** One Natural Earth ring (Taiwan's main island) is not a simple polygon
   and `Geometry2D.triangulate_polygon` refuses it. That ring is filled with its convex hull — an
   over-filled bay instead of a missing island — and holes are skipped rather than hulled. The
   benchmark prints how many rings needed the fallback so the compromise stays visible.

The map is drawn from palette colours (`map_water`, `map_land`, `map_selected`, …), never from
hardcoded hex values, so both themes work without touching the renderer.

### Interaction

Mouse drag, wheel zoom, trackpad pan/magnify, touch drag, two-finger pinch and keyboard (arrows,
`+`/`-`) all drive the same `MapCamera`. Zoom is anchored at the pointer where the platform reports
one. A press that moves less than 6 px counts as a tap; `tap()` maps the point to a country id and
emits it, with `""` for open water. The screen — not the map — decides what a tap *means*, which is
why re-tapping the selected country is a no-op instead of a toggle, and tapping empty space clears
the selection.

Rendering is verified only by mesh/polygon counts and geometry assertions in this environment; see
[PERFORMANCE.md](PERFORMANCE.md) for what could and could not be measured.

### Selection assistance for small countries

A polygon smaller than a fingertip cannot be hit reliably, so `country_at_point(point, assist)` has a
second step: **after** the polygon test misses, it looks for the nearest country whose *whole* bbox is
under 11 px on screen and whose label anchor or centre is within 18 px of the tap. Two properties
matter and both are tested: the assist never mutates geometry, and it can only reach tiny shapes, so
a large neighbour can never absorb a tap. Hover deliberately passes `assist = false` so the highlight
does not jump to archipelagos under the pointer.

## 9a. Country data pipeline

The runtime never sees GeoJSON. The pipeline is three small, separately runnable tools:

```text
tools/fetch_world_atlas.py     pinned natural-earth-vector commit -> data/source/ (git-ignored)
tools/build_world_atlas.py     data/source/ -> data/world/{countries,geometry,manifest}.json
tools/build_statistics.py      the same source -> per-record statistics.json + the runtime pack
tools/build_country_pack.py    data/world/countries/ -> {countries,geometry,statistics,manifest}.json
tools/validate_world_atlas.py  audits the committed files, writes docs/DATA_QUALITY.md
tools/validate_statistics.py   audits the figures, their years, their source and the report
tools/check_atlas_data.py      fast integrity gate used before the engine is installed in CI
```

Order matters and is documented in [CONTRIBUTING.md](CONTRIBUTING.md): atlas, then statistics,
then the pack. The statistics step is separate because it is a *different* claim about the same
bytes — "these are the source's own numbers, with their vintage" — and a reviewer should be able to
run it, read its report and reject it without rebuilding the map.

Design rules that keep this maintainable:

* **Source bytes are pinned by commit**, not by "latest": provenance lives in
  `data/world/manifest.json` and the fetch script refuses to look anywhere else.
* **The build is deterministic.** Re-running it from the pinned commit reproduces the committed files
  byte for byte (hashes are recorded in [DATA_SCHEMA.md](docs/DATA_SCHEMA.md)), so any diff after a
  rebuild is a real data change rather than noise.
* **Validation is a first-class artefact.** `--report` writes a reviewable Markdown audit and
  `--check-report` fails CI when the committed report is stale, so coverage numbers cannot rot.
* **Source gaps are coverage, not errors.** A missing capital or ISO code is reported and rendered as
  a gap; the build never substitutes a value.
* **Adding metadata later does not touch the renderer.** New datasets get their own file keyed by the
  same stable id, their own loader in `src/core/…`, and a dossier section. The map reads geometry
  only, and geometry carries no metadata.

## 9b. Country statistics: read-only by construction

`CountryStatistics` (`src/core/world/country_statistics.gd`) loads `data/world/statistics.json`
once, through `WorldAtlas`, and answers questions. It has **no write path** and takes no part in the
simulation:

* nothing in `src/core/sim/` or `src/core/save/` mentions statistics, and a test fails the build if
  that changes (`tests/suites/test_statistics.gd`);
* no save contains a figure, so there is nothing to migrate;
* the dossier asks it for three values, the comparison screen asks for the same three, and
  "About the data" reads the manifest's `statistics` block. Those are the only callers.

The screen is deliberately dumb: `CountryStatistics.format_integer()` does the only arithmetic in
the UI, and the comparison never sorts, ranks or colours a column by value.

## 10. Selection state and campaign configuration

Selection is deliberately not a property of the map widget. `CampaignSetup` holds the chosen country
id and the scenario, pushes the id into the map for highlighting and into the dossier for display,
and owns the validation gate. That keeps three concerns apart:

* **`AtlasFilter`** — query text + region, with a `changed` signal; asks the registry for results.
* **Selection** — a stable country id in the screen, mirrored into `WorldMapView.selected_id()`.
* **`CampaignConfig`** — a versioned value object (`schema_version`, `scenario_id`, `country_id`,
  `start_date`, display `metadata`) that can be created, serialised and validated with no scene
  involved.

`CampaignConfig.validate(catalog, registry, eligibility)` returns *every* reason a choice cannot be
played:
unknown or unimplemented scenario, unknown country, invalid or mismatched start date, unsupported
format version. The confirm button is disabled unless that list is empty, so a hand-edited config
and a screen-built one are gated by the same rule.

**Starting-nation eligibility** is the one rule that is *not* a preference: `StartEligibility` reads
`data/world/start_eligibility.json`, which lists the dataset's own `type` values that may start a
campaign. The rule names types, never places, so no per-country branch exists anywhere, and widening or
narrowing it is a one-line data edit. `validate()` consults it, so the interface cannot bypass it: every
record stays browsable, searchable and readable in the dossier, but only eligible records confirm. The
generated list of who is and is not eligible is [`docs/START_NATIONS.md`](docs/START_NATIONS.md), and the
project states there that the rule is a **default for owner review, not a final decision**.

`to_dict()` exists so that a future save system
has a stable format to build on; **it is not a save system**, and nothing in this milestone writes
a campaign to disk.

## 11. Testing

`tests/test_runner.tscn` runs as a real scene, so autoloads and the theme are available:

```bash
godot --headless --path . --import
godot --headless --path . res://tests/test_runner.tscn   # exit code 0 = all assertions pass
```

Suites (15 at the time of writing; `docs/` and the PR description quote the current counts):

| Suite | What it protects |
| --- | --- |
| `test_design_system` | Token ordering, palette completeness, WCAG AA contrast for every foreground/surface pair, focus-ring visibility, theme variation completeness, schema validation, motion helpers |
| `test_settings_storage` | Defaults, round-trips, repair of invalid values, corrupt-file recovery, no secrets in the file |
| `test_game_wallet` | Integer-only balances, no negative values, clamping, strict restoration (fractional, negative, string and malformed saved values are rejected rather than rounded), JSON round trips, architectural separation from national economies |
| `test_data_files` | JSON parses, required content exists, creator credited, human vs AI contributions separated, third-party licences stated |
| `test_layout` | Every screen mounted in a `SubViewport` at six reference sizes: nothing overflows, no label collapses, breakpoint rules apply, planned entries are not clickable |
| `test_country_data` | Registry parses the shipped dataset, ids unique and stable, ISO codes well formed, required fields present, missing optionals explicit, geometry references resolve, search case/accent folding, region classification, combined filters, malformed records rejected, manifest matches the data, data-source document shipped |
| `test_world_geometry` | Coordinate sweep over every ring, closed outlines, multi-polygon countries keep their parts, holes preserved (Lesotho, San Marino), known-place hit tests, malformed geometry reported instead of fatal, disputed units keep the source's classification and their own geometry |
| `test_atlas_interaction` | Camera fit/clamp/anchor/focus behaviour, filter state signals, selection change/clear/idempotence, tap-to-country and empty-space taps, mesh caching, map survives a missing atlas |
| `test_campaign` | Scenario catalogue and date validation, malformed definitions rejected, configuration validation (unknown/missing country, unknown or unimplemented scenario, bad date, future schema), screen flow from empty state to confirmable campaign and the honest brief |
| `test_campaign_ui` | Campaign screen mounted at seven reference sizes in both orientations, nothing overflows, arrangements (side/stack/drawer) apply, result list does not reflow the map, both themes, reduced motion, accessibility of map/search/filters, keyboard-only search, stage line, region counts |
| `test_dossier` | Every record produces the four recorded sections in order, sourced values verbatim, missing values become explicit gaps, no field resembles an invented statistic, planned sections carry no values, geometry context and source attribution appear |
| `test_data_recovery` | Missing files, garbage registries, malformed geometry, broken geometry references, empty registry in the search field, map with no data, invalid campaigns — each reports and never crashes or substitutes |
| `test_start_nations` | The eligibility rule is one data file; it names types, not places; widening it widens eligibility without code changes; the campaign gate rejects ineligible records with the neutral message; ineligible records keep full dossiers; the source-status note is exact and neutral; a capital's name and coordinates come from the same feature and show a gap when absent |
| `test_developer_tools` | Developer settings default to off, round-trip and sanitise; the overlay samples frames, ignores the mouse and follows its setting; the stress path is deterministic and stays inside the world; verdicts match the documented thresholds; reduced detail never draws more labels or markers and never hides a country; the stress test cannot start with developer tools off |
| `test_navigation` | The real router instantiates the real screens: start screen, forward navigation to settings and the campaign screen, back history, overlay clean-up |

Static analysis: `gdlint src tests tools` (gdtoolkit 4.5.0), also part of CI.

A separate, non-CI benchmark (`tools/atlas_benchmark.tscn`) measures atlas load, mesh construction and
query throughput on the CPU; its results live in [PERFORMANCE.md](PERFORMANCE.md). It cannot measure
frame time, because the headless renderer has no GPU.

The layout suite is the substitute for visual inspection in a headless environment: it verifies
geometry, not appearance. Rendered appearance still needs a human on a display.

## 11a. Simulation and save layers

```
CampaignConfig ──▶ WorldState.new_campaign() ──▶ WorldState (dynamic state)
                        │                          │
                        ▼                          ▼
                   GameClock ◀── Simulation ──▶ EventBus ──▶ systems (calendar today)
                        │                          │
                        └────────── GameSession ───┘
                                       │
                                       ▼
                       SaveFile (payload) ──▶ SaveStore (atomic write, backup)
```

* A **tick** steps the clock one in-game day and then runs every registered system whose frequency
  matches the new date, in order. Systems publish events; the bus delivers them after the handler
  returns.
* The **clock** converts real seconds into due ticks (rate from the chosen speed), caps a frame at 64
  ticks and carries the remainder — a slow frame delays time, it never skips or repeats it.
* `WorldState` holds only dynamic state. Geometry, names and ids live in the read-only atlas, so saves
  stay small and a corrected map does not invalidate a campaign.
* `SaveFile` builds the payload, computes the checksum and the state hash and parses/verifies on the
  way back in. `SaveStore` owns the filesystem: temp file → verify → backup → swap, plus the failure
  injection seam the tests use to prove the old save survives.

## 12. Continuous integration

`.github/workflows/ci.yml` runs on pushes and pull requests. Every step is **gating** — the run is
green only when all of them pass:

1. `gdlint src tests tools`
2. `tools/check_atlas_data.py` — hashes of the committed world data
3. `tools/validate_world_atlas.py --check-report docs/DATA_QUALITY.md` — audit + report freshness
4. `tools/report_policies.py --check` — generated policy documents are current
5. install Godot 4.6.3 via `chickensoft-games/setup-godot`, then `--headless --import`
6. `--check-only --script` on every changed `.gd` file, with the three autoload false positives
   (`Settings`, `ThemeManager`, `Game`) filtered out and every other compile error fatal
7. `--headless res://tests/test_runner.tscn` — the whole suite
8. `--headless res://tools/sim_benchmark.tscn` — the benchmark must succeed and prints the timings
9. boot smoke: `--headless --quit-after 240 res://src/app/main.tscn`, failing on any `SCRIPT ERROR`

A final step publishes the parse, suite and boot logs as **commit comments** (`if: always()`), so a run
can be read without the Actions log viewer and the evidence stays attached to the commit. It was added
while this branch was developed in an environment that could not fetch job logs; it also makes a failed
run diagnosable from the commit page.

Status: **executed and green** on the current commit of this branch (249 862 assertions, 0 failures).
The workflow was *not* verified from the Actions log viewer here: the numbers quoted come from the
published comment. A phone build has never been produced, so every device claim stays **UNVERIFIED**.

## 12a. Developer tools

Three measuring facilities ship in the build, all off by default and all silent when off:

* **Performance overlay** (`src/ui/dev/performance_overlay.gd`) — a persisted setting, toggled by **F3**
  or in Settings. It reads engine counters and its own rolling frame samples and draws a corner panel
  that ignores the mouse. It never writes a metric to disk.
* **Map detail** (`SettingsSchema.KEY_MAP_DETAIL`) — `full` or `reduced`. Reduced keeps geography,
  shapes and tap targets identical and reduces only drawing: fewer labels, no ocean names, no capital
  markers, a thicker border culling floor.
* **Map stress test** (`src/core/dev/map_stress_test.gd`) — a 30-second, deterministic camera path with
  recorded frame samples, stall filtering and a verdict against budgets in
  [`docs/PERFORMANCE.md`](docs/PERFORMANCE.md). It is started from Settings, which asks
  `ScreenRouter.go_to(screen_id, remember, params)` to open the campaign screen with
  `{"stress_test": true}`; the campaign screen receives that through its optional `receive_params()`
  method and ignores it unless developer tools are on.

The label and capital placement rules are exposed as pure functions (`label_layout()`,
`capital_layout()`) returning the rectangles that *would* be drawn. That is what lets the tests assert
culling, label collisions and reduced-detail behaviour in a headless build with no GPU, and it keeps
one definition of "what is on screen".

## 13. Decisions and trade-offs

| Decision | Reason | Cost |
| --- | --- | --- |
| Theme generated in code instead of a `.tres` | One source of truth for tokens; palette switching is a rebuild; testable properties | Theme structure lives in GDScript rather than being editable in the inspector |
| Type variations instead of many custom components | Fewer scenes, consistent styling, discoverable in one file | A variation's name has to be spelled correctly; the test suite checks the required list |
| Custom test runner instead of a third-party framework | No extra dependency for a small suite | Fewer features (no mocks, no parameterisation) |
| GL Compatibility renderer | Widest mobile/desktop support for a 2D interface game | No 3D/Vulkan-specific features (not needed; the future map is 2D) |
| Data in JSON, loaded defensively | Content changes without code changes; failures do not crash | Schema validation must be maintained per file |
| No empty gameplay folders yet | Avoid placeholder rot; boundaries are documented instead | A new contributor must read this file before creating them |
| Quantised lon/lat instead of projected coordinates in the data file | The projection stays a runtime decision; hit-testing uses the same numbers the renderer draws | The file is tied to a 0.005° grid |
| Equirectangular projection | Undistorted reading of the inhabited world, trivial hit tests, no re-projection at load | High latitudes are stretched horizontally |
| `ArrayMesh` per country instead of per-frame polygon calls | `draw_colored_polygon` re-triangulates every frame; a cached mesh is one draw call | ~100 k extra vertices held in memory while the map is open |
| Holes drawn as sea-coloured meshes | No polygon booleans, no geometry preprocessing beyond the export | Only correct because the sea is a flat colour |
| No horizontal wrap at ±180° | Simpler camera clamping and no duplicate-shape logic | You cannot spin the world continuously; you drag back instead |
| Scenario definitions as JSON | Content, not code; a new scenario needs no screen change | Scenario *behaviour* still needs code when simulation arrives |

## 13a. Honesty rules (enforced where a test can)

- A system's status panel is built from the **registry**, so it cannot list a system that is not
  registered. Today that is one line: the calendar.
- No statistic is displayed unless a system computes it from saved state. Where a number would go and
  there is none, the interface says so in words.
- `Continue` is enabled only when a save actually loads.
- A damaged or newer save is refused with a reason and left byte-for-byte untouched.
- Measurements in the docs come from `tools/` benchmarks; anything not measured is labelled
  **UNVERIFIED**, including every phone number.

## 14. What is intentionally absent

No economy, political, diplomatic or military simulation, no AI, no audio, no network code, no
analytics, no accounts, no monetisation and no export presets.

The world map, country registry, selection and campaign setup exist as of Milestone 02, and the
simulation loop (calendar only), the save system and the campaign shell exist as of Milestone 03 —
described in sections 9, 10, 11 and 11a. Nothing else in this document describes a system that does not
run. See [ROADMAP.md](ROADMAP.md).

### Why new settings groups get their own class

`SettingsService` is deliberately at its size limit — 20 public methods, enforced
by the linter. Anything that needs a new group of settings therefore gets a small
typed class over `Settings.get_value` / `set_value` (`MapOptions`, `AtlasHistory`)
instead of adding another accessor pair to the service. That keeps one honest rule:
the service owns *storage*, the group class owns *meaning*.

## The map layer, in four parts

1. **Data.** `data/world/countries/` (folders, the source of truth) → the pack
   (`countries.json`, `geometry.json`, `manifest.json`) plus one derived hint file,
   `data/world/coast.json`, which classifies each ring as coastline, shared land
   border or mixed. The hint is generated from the geometry by
   `tools/build_coast_data.py`; when it is missing the renderer falls back to plain
   borders and never invents a coastline.
2. **Geometry and camera.** `WorldGeometry` parses rings and answers
   `rings_of()` / `ring_coast_codes()`; `MapCamera` owns centre, zoom, clamping and
   the screen↔world transforms; `MapProjection` is the only place that knows the
   projection. None of them draw.
3. **The view.** `WorldMapView` is one `CanvasItem` that paints the frame: ocean,
   optional grid and reference lines, cached fills, borders, cues, labels, legend
   and scale bar. It keeps no game state — it is told what to draw and reports
   `draw_stats()` for the developer overlay, the tests and the cost model.
4. **Display options.** `MapOptions` reads and writes the settings store and
   applies a snapshot to any view with one call; `MapOptionsPanel` is the UI. The
   options are display-only by construction: the hit test uses geometry, so no
   option can change which country a tap selects.

Details, colour tables and the cost model: `docs/MAP_RENDERING.md`.

