# WORLD DOMINION

An offline grand strategy sandbox: lead a nation through a living world of politics, economy,
diplomacy and conflict.

WORLD DOMINION is being built as **one cross-platform game** for Android, iOS, Windows, macOS and
Linux — not as a desktop game that gets ported later. The simulation is designed to run entirely on
the player's device: no accounts, no backend, no mandatory network access.

---

## Development status

**Milestone 02 — World atlas & country selection** is implemented on this branch and awaiting review.

| Area | State |
| --- | --- |
| Application shell (title screen, settings, about & credits, navigation) | Implemented |
| Design system (palette, typography, components, motion, responsive rules) | Implemented |
| Two themes: `Midnight` (default, dark) and `Parchment` (light) | Implemented |
| Local settings persistence (theme, interface scale, reduced motion) | Implemented |
| **Interactive world map** — real country polygons, pan/zoom/pinch, keyboard, labels | Implemented |
| **Country registry** — 242 nations and territories with sourced metadata | Implemented |
| **Country dossier** — Overview / Geography / Administration / Data sources, gaps stated | Implemented |
| **Country search and region filters** — keyboard-navigable, deterministic, counted | Implemented |
| **Data pipeline** — fetch, build, validate, quality report, schema | Implemented |
| **Campaign setup** — Modern World scenario, starting 1 January 2026 | Implemented |
| Headless test suite (design, storage, wallet, content, layout, navigation, atlas, campaign) | Implemented and passing locally |
| Simulation, economy, politics, diplomacy, military, saving | **Not implemented** |
| Export presets / store builds for any platform | **Not configured** |

Screens state what is implemented and what is planned; entries that belong to later milestones are
disabled and labelled **PLANNED** rather than faked, and the campaign brief says in words that no
simulation runs and nothing is saved yet. See [ROADMAP.md](ROADMAP.md).

### The world atlas

The map is drawn from **Natural Earth 1:50m** country polygons (public domain) through a reproducible
offline pipeline: 242 countries and territories, 1 620 polygons, 99 568 vertices, an equirectangular
projection, and no network access at runtime. Regenerating from the pinned source commit reproduces the
committed files byte for byte, and every build is audited by a validator that writes a reviewable
quality report. Missing source values stay missing — the dossier says "Not recorded in source" instead
of inventing a capital or a statistic, and the future systems (population, economy, government,
military, diplomacy, resources, society) are listed as unimplemented rather than mocked up.

| Question | Answer |
| --- | --- |
| Where is the data schema? | [docs/DATA_SCHEMA.md](docs/DATA_SCHEMA.md) |
| Where does the data come from, and under what licence? | [docs/DATA_SOURCES.md](docs/DATA_SOURCES.md) |
| What does the data actually contain, and what is missing? | [docs/DATA_QUALITY.md](docs/DATA_QUALITY.md) (generated) |
| How fast is it, and what was not measured? | [docs/PERFORMANCE.md](docs/PERFORMANCE.md) |
| What can be shown visually, given there is no GPU here? | [docs/evidence/](docs/evidence/) |

### Reproducing the world data

```bash
python3 tools/fetch_world_atlas.py --source-dir data/source      # pinned source commit only
python3 tools/build_world_atlas.py --source-dir data/source --out data/world --retrieved 2026-11-05
python3 tools/validate_world_atlas.py --report docs/DATA_QUALITY.md
```

`data/source/` is ignored by Git; the generated files under `data/world/` are committed so the game
needs no build step and no network.

## Technical stack

- **Engine:** Godot 4.6 (stable) — scenes and nodes, `Control`-based interface.
- **Language:** GDScript only. No other runtime languages, frameworks or services.
- **Renderer:** GL Compatibility, the broadest mobile/desktop compatibility profile for a 2D
  interface-driven game.
- **Data:** JSON under `data/` for content that changes (build status, credits, scenarios, the world
  atlas); `ConfigFile` for local player settings. Geographic data is fetched at a pinned commit,
  generated offline by `tools/build_world_atlas.py`, validated by `tools/validate_world_atlas.py` and
  committed, so the game has no build step and no runtime fetch.
- **Artwork:** original SVG icons plus a procedurally drawn backdrop; no imported third-party art.
- **CI:** GitHub Actions workflow for lint, atlas data validation (including a stale-report check),
  resource import and the full headless test suite (see [ARCHITECTURE.md](ARCHITECTURE.md)).
- **Cost:** no paid APIs, no generative-AI services, no recurring services of any kind.

## Getting started

1. Install **Godot 4.6.x** (standard build, not .NET).
2. Open `project.godot` from the Godot project manager and let it import resources.
3. Press **F5** to run the shell.

Headless validation (the same commands CI runs):

```bash
# Static analysis of GDScript
pip install gdtoolkit==4.5.0
gdlint src tests tools

# Import resources, then run the test suite (exit code 0 = pass)
godot --headless --path . --import
godot --headless --path . res://tests/test_runner.tscn
```

## Repository layout

```
project.godot          Engine configuration and autoload registration
src/app/               Application root, screen router, transition handling
src/autoload/          Singletons: Settings (persistence), ThemeManager (themes)
src/core/              Engine-agnostic logic: settings schema/store, JSON data loading, the
                       game-wallet primitive, the world atlas (records, geometry, lookup,
                       projection, camera, filter) and campaign configuration
src/platform/          The only place that asks what platform the game runs on
src/ui/theme/          Design tokens, palettes, typography and the runtime theme builder
src/ui/components/     Reusable interface parts (nav row, segmented control, setting row, header)
src/ui/map/            The interactive map view and its overlay controls
src/ui/screens/        Full-window views (main menu, campaign setup, settings, about & credits)
src/ui/backdrop/       Procedural chart backdrop
assets/                Fonts (with licences), SVG icons, shaders, project icon
data/                  JSON content: build status, credits, scenarios, and the generated world atlas
tools/                 Offline atlas pipeline (Python) and the headless atlas benchmark
tests/                 Headless test runner and suites
docs/                  Data-source manifest, performance notes, layout diagrams
```

Architectural boundaries for future gameplay (`simulation/`, `economy/`, `politics/`, `diplomacy/`,
`military/`) are described in [ARCHITECTURE.md](ARCHITECTURE.md). They are *not* created as empty
folders: boundaries are documented first and materialise when the first real code arrives. The
`world/` and `campaign/` boundaries did materialise in Milestone 02, which is why they exist now.

## Documentation

| Document | Contents |
| --- | --- |
| [GAME_DESIGN.md](GAME_DESIGN.md) | Vision, pillars, systems, permanent currency rules |
| [ROADMAP.md](ROADMAP.md) | Milestones and their status (planned / in progress / implemented / tested / deferred) |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Project structure, technical decisions, cross-platform strategy, testing |
| [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) | Colours, typography, spacing, components, motion, responsiveness |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Conventions, geographic-content rules, review checklist, crediting |
| [docs/DATA_SCHEMA.md](docs/DATA_SCHEMA.md) | The three atlas files, field by field, with the rules for changing them |
| [docs/DATA_SOURCES.md](docs/DATA_SOURCES.md) | World-atlas provenance, licence, pipeline, naming policy, disputed-territory treatment |
| [docs/DATA_QUALITY.md](docs/DATA_QUALITY.md) | Generated audit: coverage, geometry checks, per-unit source gaps |
| [docs/evidence/](docs/evidence/) | Data renders of the committed geometry, and why no screenshot exists |
| [docs/PERFORMANCE.md](docs/PERFORMANCE.md) | Atlas measurements and what could not be measured |
| [docs/layout-diagrams/](docs/layout-diagrams/) | Geometry diagrams of the responsive layouts (not screenshots) |

## Platform support

| Platform | Status in this milestone |
| --- | --- |
| Windows, macOS, Linux | The shell is designed for these and runs on Linux during development. **No export preset or executable build exists yet.** |
| Android | Architecture and input handling account for it. **Not built or tested.** |
| iOS | Same as Android, plus a documented constraint: building and distributing requires Apple tooling (Xcode, signing certificates, a paid Apple Developer account) that is outside this repository. |

No platform build has been produced or verified. Anything that claims otherwise would be wrong.

## Privacy

WORLD DOMINION is offline-first by design: local saves, no accounts, no registration, no analytics,
no advertising SDKs, no telemetry and no network requests in the current build. The only file the
game writes is `user://settings.cfg`.

## Credits

- **Md. Afnan** — Project Creator
- **ChatGPT** — AI-assisted planning and design specification
- **Arena** — AI-assisted development

Human and AI-assisted contributions are listed separately in the game (About & Credits) and in
[`data/credits.json`](data/credits.json). Third-party components: Godot Engine (MIT) and the
typefaces Spectral, IBM Plex Sans and IBM Plex Mono (SIL OFL 1.1, licences in `assets/fonts`), and
the **Natural Earth** map dataset (public domain) described in
[docs/DATA_SOURCES.md](docs/DATA_SOURCES.md).

## Licensing

The project owner has not chosen a source licence yet. Until one is selected, treat the source as
all rights reserved. Bundled third-party components keep their own licences.
