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
    theme_manager.gd          Autoload `ThemeManager` — builds/applies the active theme
  core/
    config/
      settings_schema.gd      Allowed keys, defaults, validation, labels
      settings_store.gd       ConfigFile read/write with recovery
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
      atlas_filter.gd         Query + region filter state
      world_atlas.gd          Loads registry + geometry + index + manifest together
    campaign/
      scenario.gd             One scenario definition (id, name, start date, implemented)
      scenario_catalog.gd     Directory-backed catalogue of scenarios
      campaign_config.gd      Versioned campaign configuration + validation
  platform/
    platform_info.gd          The only place that asks "what am I running on?"
  ui/
    map/
      world_map_view.gd       Interactive map: cached meshes, borders, labels, input
      map_controls.gd         Zoom in / out / fit overlay buttons
    theme/
      design_tokens.gd        Spacing, type ramp, radii, motion, breakpoints
      palette.gd              Midnight + Parchment palettes and contrast requirements
      typography.gd           Font loading and tracking
      theme_factory.gd        Builds a Theme from tokens + palette (named variations)
      motion.gd               Durations/easing, reduced-motion aware
    components/
      nav_row.tscn/.gd        Navigation entry (title, caption, badge, states)
      segmented_control.tscn/.gd  Mutually exclusive option row
      setting_row.tscn/.gd    Label + description + control, stacks when narrow
      app_header.tscn/.gd     Back button, context line, title block
    screens/
      responsive_screen.gd    Base class: margins per breakpoint, layout hooks
      main_menu.tscn/.gd
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
before**: `src/simulation/`, `src/world/`, `src/economy/`, `src/politics/`, `src/diplomacy/`,
`src/military/`, `src/save/`, `assets/audio/`. Empty folders and placeholder scripts add noise and
rot; the README of each future area is the pull request that introduces it.

## 3. Dependency rules

```
        ui/screens ──▶ ui/components ──▶ ui/theme ──▶ assets/
             │                │              │
             ├────────────────┴──────────────┴──▶ autoload (Settings, ThemeManager)
             ▼
          core/*        (no dependency on ui/ or scenes)
             ▲
        platform/platform_info  (no dependency on ui/)

  future: simulation/* ◀── core/* ；ui/* reads simulation state through plain data,
          never through node references.
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
  `quit_requested`); they never reach into the router or each other.

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
   when they would overlap a label already placed. At most 26 labels are drawn.

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

## 10. Selection state and campaign configuration

Selection is deliberately not a property of the map widget. `CampaignSetup` holds the chosen country
id and the scenario, pushes the id into the map for highlighting and into the dossier for display,
and owns the validation gate. That keeps three concerns apart:

* **`AtlasFilter`** — query text + region, with a `changed` signal; asks the registry for results.
* **Selection** — a stable country id in the screen, mirrored into `WorldMapView.selected_id()`.
* **`CampaignConfig`** — a versioned value object (`schema_version`, `scenario_id`, `country_id`,
  `start_date`, display `metadata`) that can be created, serialised and validated with no scene
  involved.

`CampaignConfig.validate(catalog, registry)` returns *every* reason a choice cannot be played:
unknown or unimplemented scenario, unknown country, invalid or mismatched start date, unsupported
format version. The confirm button is disabled unless that list is empty, so a hand-edited config
and a screen-built one are gated by the same rule. `to_dict()` exists so that a future save system
has a stable format to build on; **it is not a save system**, and nothing in this milestone writes
a campaign to disk.

## 11. Testing

`tests/test_runner.tscn` runs as a real scene, so autoloads and the theme are available:

```bash
godot --headless --path . --import
godot --headless --path . res://tests/test_runner.tscn   # exit code 0 = all assertions pass
```

Suites:

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
| `test_campaign_ui` | Campaign screen mounted at seven reference sizes in both orientations, nothing overflows, arrangements (side/stack/drawer) apply, result list does not reflow the map, both themes, reduced motion, accessibility of map/search/filters |
| `test_navigation` | The real router instantiates the real screens: start screen, forward navigation to settings and the campaign screen, back history, overlay clean-up |

Static analysis: `gdlint src tests tools` (gdtoolkit 4.5.0), also part of CI.

A separate, non-CI benchmark (`tools/atlas_benchmark.tscn`) measures atlas load, mesh construction and
query throughput on the CPU; its results live in [PERFORMANCE.md](PERFORMANCE.md). It cannot measure
frame time, because the headless renderer has no GPU.

The layout suite is the substitute for visual inspection in a headless environment: it verifies
geometry, not appearance. Rendered appearance still needs a human on a display.

## 12. Continuous integration

`.github/workflows/ci.yml` runs on pushes and pull requests:

1. `gdlint src tests`
2. install Godot 4.6.3 via `chickensoft-games/setup-godot`
3. `godot --headless --path . --import`
4. `godot --headless --path . res://tests/test_runner.tscn`

The workflow is committed but **has not been executed** in this environment (no GitHub Actions runner
was available). It should be treated as unverified until the first pull request run completes.

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

## 14. What is intentionally absent

No simulation loop, no economy or political systems, no AI, no save files, no audio, no network code,
no analytics, no accounts, no monetisation, no export presets. The world map, country registry,
selection and campaign setup **do** exist as of Milestone 02, and are described in sections 9 and 10. See [ROADMAP.md](ROADMAP.md).
