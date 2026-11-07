# WORLD DOMINION

An offline grand strategy sandbox: lead a nation through a living world of politics, economy,
diplomacy and conflict.

WORLD DOMINION is being built as **one cross-platform game** for Android, iOS, Windows, macOS and
Linux — not as a desktop game that gets ported later. The simulation is designed to run entirely on
the player's device: no accounts, no backend, no mandatory network access.

---

## Development status

**Milestone 11 — Icons, a feature inventory, per-country state and data reconnaissance** is
implemented on this branch and awaiting review: every interface mark is now a licensed
game-icons.net file pinned to one commit and credited, with the code-drawn shape kept as the
fallback when a file cannot be read; each of the 242 countries has a record of its own, saved as
schema 5 and rebuilt from the data pack rather than trusted from a save; `docs/FEATURE_INVENTORY.md`
and `docs/SCREEN_MAP.md` state what every feature and screen is, each row naming the file that
proves it; `docs/DATA_CANDIDATES.md` records where the next data can come from, with its licence,
its commit and its gaps — **and no new data was imported**; and a **What is new** page, reachable
from the Library group and the pause menu, says what changed, with each line naming the files
that make it true. A modal panel now caps itself to the window, so a 640×360 screen keeps its
Close button on screen. The simulation is still the calendar.

**Milestone 10 — The game screen's shell** is implemented on this branch and awaiting review:
a five-zone interface over the campaign (a top bar with your avatar, Gold Coins, Red Gems, XP,
level and flag above a strip of real country figures; Messages with an unread count; News; Menu
and the tutorial; the seven-category bar; the clock's speed and the in-game date), a typed event
log stored with the save, Messages and News screens printed from that log, a country panel that
reuses the existing dossier, and a panel and list component every new screen is built from. Six
of the seven categories have nothing behind them in this build and say so in one paragraph
instead of showing an empty mock-up. The simulation is still the calendar.

**Milestone 09 — Audio and polish** is implemented on this branch: an
offline audio service (silent until you raise a volume), a settings screen in eight named
groups with a real frame-rate cap, a regrouped main menu, a diagnostics screen whose export
never touches your profile, Help and Roadmap screens that describe what actually exists,
two-step world deletion with a one-session undo, sourced currency data for 229 of 242 records,
a generated documentation index, and two build paths — a reproducible bundle that always
exists, and an Android export attempt that reports its own failure rather than shipping a
file it did not build. The simulation itself is still the calendar — the screens say so
rather than implying more.

| Area | State |
| --- | --- |
| Application shell (title screen, settings, about & credits, navigation) | Implemented |
| Design system (palette, typography, components, motion, responsive rules) | Implemented |
| Two themes: `Midnight` (default, dark) and `Parchment` (light) | Implemented |
| Local settings persistence (theme, interface scale, reduced motion, map detail, developer tools) | Implemented |
| **Interactive world map** — real country polygons, pan/zoom/pinch, keyboard, labels | Implemented |
| **Readable map** — separated coastline and land borders, ocean depth, optional graticule and equator/tropics, colour-blind-safe region tints, patch-clean selection cues | Implemented |
| **Map display options** — label density, borders, capitals, grid, reference lines, reduced detail; touch-sized panel, persisted locally | Implemented |
| **Minimum markers for tiny countries** — a visible dot for a country too small to see, never a change to what a tap selects | Implemented |
| **Per-country data folders** — `data/world/countries/<ID>/`, with the runtime pack generated from them and proven unchanged | Implemented |
| **Country registry** — 242 nations and territories with sourced metadata | Implemented |
| **Country dossier** — Overview / Geography / Administration / Key figures / Data sources, gaps stated | Implemented |
| **Sourced key figures** — population and GDP from one pinned source, each with its as-of year, plus an area derived from the outline and labelled as derived; "Not available" where the source has nothing | Implemented (reference data only) |
| **Country comparison** — up to three countries side by side, read-only, dashes for missing values, keyboard and touch | Implemented |
| **Capital markers and coordinates** — sourced from the same place as the capital name | Implemented |
| **Country search and region filters** — keyboard-navigable, deterministic, counted | Implemented |
| **Data pipeline** — fetch, build, validate, quality report, schema | Implemented |
| **Campaign setup** — Modern World scenario, starting 1 January 2026 | Implemented |
| **Starting-nation rule** — one reviewable data file, enforced in validation | Implemented (default for owner review) |
| **Developer tools** — F3 performance overlay, 30-second map stress test, reduced map detail | Implemented |
| **Simulation core** — deterministic clock, one tick = one in-game day, pause + four tick rates, seeded named random streams, queued event bus, system registry | Implemented |
| **Calendar** — the clock: Gregorian months and leap years, day/month/year events; with one baseline-integrity check beside it and nothing else | Implemented |
| **Save system** — versioned JSON, three slots + autosave, atomic writes, one rolling backup, strict validation, schema migration, export/import | Implemented |
| **Playable campaign shell** — game screen, time controls, map with the player's nation marked, dossier panel, honest simulation status | Implemented |
| **Pause menu, load screen, autosave indicator, first-run guide** | Implemented |
| **Flags in the interface** — a flag on every search result and dossier header, a lazy code badge where the source has none | Implemented |
| **First-run flow** — real loading progress, versioned Terms & Privacy, a notification *preference* (no permission, nothing promised), profile creation; reachable again from Settings | Implemented |
| **Country picker** — committed region groups, A–Z index and list, search by name, alias, alpha-2 and alpha-3, and a snapping flag strip, all in step with the map | Implemented |
| **Profile screen and avatars** — name, username set once, player ID, level, XP bar with numbers, VIP, Gold Coins and Red Gems, and twenty avatars drawn in code | Implemented |
| **String table** — every new screen's player-facing text behind one lookup, checked by a test | Implemented |
| **Licensed interface icons** — 68 meanings from game-icons.net, pinned to one commit, credited, hashed per file, with the code-drawn shape as the fallback | Implemented |
| **Per-country state** — one record per country, save schema 5, baseline rebuilt from the data pack on load (nothing changes a country yet) | Implemented (foundation only) |
| **What is new** — a notes page in the Library group and the pause menu; each line names the files that make it true, and the page ends with what is missing | Implemented |
| **Feature inventory and screen map** — every feature and screen, with the file that proves each row | Implemented (documents) |
| **Tutorial** — six skippable steps over a campaign, a one-time reward paid through the profile, reopenable from the pause menu | Implemented |
| **Your worlds and backup/restore** — a plain-JSON one-file backup, a worlds list, and a three-answer recovery dialog for anything damaged | Implemented |
| Choosing backup files through the platform's own file dialog | **Not implemented (planned; UNVERIFIED on devices)** |
| Headless test suite (every screen, the data pipeline, the simulation, saves, flags, the first run, the picker and the profile) | Implemented and passing in CI |
| Economy, budgets, politics, elections, diplomacy, military, country AI, resources, events, goals | **Not implemented (planned)** |
| Export presets / store builds for any platform | **Not configured** |

Screens state what is implemented and what is planned. `Continue` is enabled only when a save actually
loads, the game-screen status panel names the systems that run (the calendar and a one-time baseline check) and
says plainly that economy, politics, diplomacy and military simulation do not exist yet, and no placeholder statistic is
ever displayed. See [ROADMAP.md](ROADMAP.md).

### The world atlas

The map is drawn from **Natural Earth 1:50m** country polygons (public domain) through a reproducible
offline pipeline: 242 countries and territories, 1 620 polygons, 99 567 vertices, an equirectangular
projection, and no network access at runtime. Regenerating from the pinned source commit reproduces the
committed files byte for byte, and every build is audited by a validator that writes a reviewable
quality report. Missing source values stay missing — the dossier says "Not recorded in source" instead
of inventing a capital; the future systems (economy, government, military, diplomacy, resources,
society) are listed as unimplemented rather than mocked up.

### The key figures

Population and GDP are copied from that same pinned Natural Earth file — its own **estimates**, each
with the year the source records it for (most rows are 2019). They are baseline reference data for
the 2026 scenario start, **not live**, and the game never changes them: no simulation reads them, and
no save contains them. A value the source does not give (a fractional population, a `-99` GDP
sentinel) stays missing and is shown as "Not available", never as zero. Area is not a source field at
all — it is calculated from the simplified outline, so it is marked "derived" everywhere it appears.
The source, the licence, the four code differences, and every rejected value are recorded in
[docs/STATISTICS_REPORT.md](docs/STATISTICS_REPORT.md); the boundary between "shown" and "simulated"
is in [docs/STATISTICS_DESIGN.md](docs/STATISTICS_DESIGN.md).

| Question | Answer |
| --- | --- |
| Where is the data schema? | [docs/DATA_SCHEMA.md](docs/DATA_SCHEMA.md) |
| Where does the data come from, and under what licence? | [docs/DATA_SOURCES.md](docs/DATA_SOURCES.md) |
| Where is the list of every document? | [docs/INDEX.md](docs/INDEX.md) |
| How do I update the data, cut a build or recover from a red CI run? | [docs/OWNER_GUIDE.md](docs/OWNER_GUIDE.md) |
| Which units does the dataset call disputed, dependent or indeterminate? | [docs/DISPUTED_TERRITORIES.md](docs/DISPUTED_TERRITORIES.md) (generated) |
| Which countries can I start a campaign as, and why? | [docs/START_NATIONS.md](docs/START_NATIONS.md) (generated) |
| What does a technical term in these docs mean? | [docs/GLOSSARY.md](docs/GLOSSARY.md) |
| What does the data actually contain, and what is missing? | [docs/DATA_QUALITY.md](docs/DATA_QUALITY.md) (generated) |
| How fast is it, and what was not measured? | [docs/PERFORMANCE.md](docs/PERFORMANCE.md) |
| How is the map drawn, in which colours, and at what cost? | [docs/ANIMATION.md](docs/ANIMATION.md) | Generated inventory of every animation, its duration, trigger and reduced-motion answer |
| [docs/PR_REVIEW_GUIDE.md](docs/PR_REVIEW_GUIDE.md) | How to review a pull request here: what to read, what CI proves and what it does not |
| [docs/MAP_RENDERING.md](docs/MAP_RENDERING.md) |
| How is a country's data laid out on disk? | [docs/COUNTRY_FOLDER_GUIDE.md](docs/COUNTRY_FOLDER_GUIDE.md) |
| What can be shown visually, given there is no GPU here? | [docs/evidence/](docs/evidence/) |
| How does the simulation work, and what is deterministic? | [docs/SIMULATION_CORE.md](docs/SIMULATION_CORE.md) |
| What exactly is in a save file, and how is it protected? | [docs/SAVE_FORMAT.md](docs/SAVE_FORMAT.md) |
| What should a person check by hand on a device? | [docs/MANUAL_TEST_CHECKLIST.md](docs/MANUAL_TEST_CHECKLIST.md) |
| Where is this going, and what is only design? | [docs/OPEN_ENDED_DESIGN.md](docs/OPEN_ENDED_DESIGN.md) |

### Reproducing the world data

```bash
python3 tools/fetch_world_atlas.py --source-dir data/source      # pinned source commit only
python3 tools/build_world_atlas.py --source-dir data/source --out data/world --retrieved 2026-11-05
python3 tools/validate_world_atlas.py --report docs/DATA_QUALITY.md
python3 tools/report_policies.py                                 # regenerate the policy documents
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
- **CI:** GitHub Actions workflow for lint, atlas data validation (including stale-report and stale
  policy-document checks), resource import and the full headless test suite (see
  [ARCHITECTURE.md](ARCHITECTURE.md)).
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
src/ui/map/            The interactive map view, its overlay controls and the display-options panel
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

Start with the licence if you are here to read the code: [`LICENSE`](LICENSE) (source-available, all
rights reserved) and [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md) (every component that is
not ours, with its licence). [`docs/SECURITY.md`](docs/SECURITY.md) states honestly what the game
does and does not protect, and what has actually been verified.

[`docs/PROGRESSION.md`](docs/PROGRESSION.md) is generated from the XP curve the game runs
(levels, VIP tiers, the one speed VIP unlocks, the tutorial reward). [`docs/GAME_VISION.md`](docs/GAME_VISION.md) is where the game is going, including the open
questions only the owner can answer; [`docs/WALKTHROUGH.md`](docs/WALKTHROUGH.md) is what you can do
in the build today; [`docs/COUNTRY_CODES_AND_REGIONS.md`](docs/COUNTRY_CODES_AND_REGIONS.md) explains
the country codes and the picker's regions, record by record.

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
| [docs/DISPUTED_TERRITORIES.md](docs/DISPUTED_TERRITORIES.md) | Generated list of disputed/indeterminate/dependent units and the dataset-follows policy |
| [docs/START_NATIONS.md](docs/START_NATIONS.md) | Generated list of eligible starting nations and the reviewable rule |
| [docs/GLOSSARY.md](docs/GLOSSARY.md) | Plain-language explanations of every technical term used in these docs |
| [docs/evidence/](docs/evidence/) | Data renders of the committed geometry, and why no screenshot exists |
| [docs/PERFORMANCE.md](docs/PERFORMANCE.md) | Atlas measurements, budgets, and how to measure frame times on a real device |
| [docs/ANIMATION.md](docs/ANIMATION.md) | Generated inventory of every animation, its duration, trigger and reduced-motion answer |
| [docs/PR_REVIEW_GUIDE.md](docs/PR_REVIEW_GUIDE.md) | How to review a pull request here: what to read, what CI proves and what it does not |
| [docs/MAP_RENDERING.md](docs/MAP_RENDERING.md) | What each map layer draws, the measured colour table, the display options and the cost model |
| [docs/COUNTRY_FOLDER_GUIDE.md](docs/COUNTRY_FOLDER_GUIDE.md) | The per-country folder convention, with worked examples |
| [docs/STATISTICS_REPORT.md](docs/STATISTICS_REPORT.md) | Generated: the statistics source, coverage, the join, and every rejected value |
| [docs/STATISTICS_DESIGN.md](docs/STATISTICS_DESIGN.md) | What the figures are, what they are not, and the boundary around using them (PLANNED) |
| [docs/CONTROL_SIZES.md](docs/CONTROL_SIZES.md) | Generated: the declared height of every control, and the sizes below the 48 px target with their reasons |
| [docs/ANDROID.md](docs/ANDROID.md) | Exactly how far the Android work goes, and why it is not a support claim |
| [docs/layout-diagrams/](docs/layout-diagrams/) | Geometry diagrams of the responsive layouts (not screenshots) |

## Platform support

| Platform | Status in this milestone |
| --- | --- |
| Windows, macOS, Linux | The shell is designed for these and runs on Linux during development. **No export preset or executable build exists yet.** |
| Android | Architecture and input handling account for it; a hand-written debug export preset and a manual, non-blocking APK workflow exist. **No APK has ever been produced, installed or tested.** See [docs/ANDROID.md](docs/ANDROID.md). |
| iOS | Same as Android, plus a documented constraint: building and distributing requires Apple tooling (Xcode, signing certificates, a paid Apple Developer account) that is outside this repository. |

No platform build has been produced or verified. Anything that claims otherwise would be wrong.

## Privacy

WORLD DOMINION is offline-first by design: local saves, no accounts, no registration, no analytics,
no advertising SDKs, no telemetry and no network requests in the current build. The game writes
only inside its own `user://` directory: settings and your saved games. It requests no operating-system
permission of any kind, in any build.

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

WORLD DOMINION is **source-available and all rights reserved** — not open source. The code is
published so that anyone can read it, check the claims it makes about its data, and build it for
their own personal use. Selling it, distributing modified copies, publishing builds, or using it to
train a model is not permitted. The full terms, in plain English, are in [`LICENSE`](LICENSE).

Bundled third-party components keep their own licences: Godot Engine (MIT), Spectral and IBM Plex
typefaces (SIL OFL 1.1), Natural Earth map data (public domain). Everything is listed, with its
licence and where the licence text lives, in [`THIRD_PARTY_LICENSES.md`](THIRD_PARTY_LICENSES.md).
Contributions are not being accepted for now; see [`CONTRIBUTING.md`](CONTRIBUTING.md).
