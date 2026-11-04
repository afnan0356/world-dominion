# WORLD DOMINION

An offline grand strategy sandbox: lead a nation through a living world of politics, economy,
diplomacy and conflict.

WORLD DOMINION is being built as **one cross-platform game** for Android, iOS, Windows, macOS and
Linux — not as a desktop game that gets ported later. The simulation is designed to run entirely on
the player's device: no accounts, no backend, no mandatory network access.

---

## Development status

**Milestone 01 — Project foundation & visual design system** is implemented on this branch and is
awaiting review. Nothing beyond the application shell exists yet.

| Area | State |
| --- | --- |
| Application shell (title screen, settings, about & credits, navigation) | Implemented |
| Design system (palette, typography, components, motion, responsive rules) | Implemented |
| Two themes: `Midnight` (default, dark) and `Parchment` (light) | Implemented |
| Local settings persistence (theme, interface scale, reduced motion) | Implemented |
| Headless test suite (design, storage, wallet, content, layout, navigation) | Implemented and passing locally |
| World map, countries, economy, politics, diplomacy, military, saves | **Not implemented** |
| Export presets / store builds for any platform | **Not configured** |

Screens state what is implemented and what is planned; entries that belong to later milestones are
disabled and labelled **PLANNED** rather than faked. See [ROADMAP.md](ROADMAP.md).

## Technical stack

- **Engine:** Godot 4.6 (stable) — scenes and nodes, `Control`-based interface.
- **Language:** GDScript only. No other runtime languages, frameworks or services.
- **Renderer:** GL Compatibility, the broadest mobile/desktop compatibility profile for a 2D
  interface-driven game.
- **Data:** JSON under `data/` for content that changes (build status, credits); `ConfigFile` for
  local player settings.
- **Artwork:** original SVG icons plus a procedurally drawn backdrop; no imported third-party art.
- **CI:** GitHub Actions workflow for lint + headless tests (see [ARCHITECTURE.md](ARCHITECTURE.md)).
- **Cost:** no paid APIs, no generative-AI services, no recurring services of any kind.

## Getting started

1. Install **Godot 4.6.x** (standard build, not .NET).
2. Open `project.godot` from the Godot project manager and let it import resources.
3. Press **F5** to run the shell.

Headless validation (the same commands CI runs):

```bash
# Static analysis of GDScript
pip install gdtoolkit==4.5.0
gdlint src tests

# Import resources, then run the test suite (exit code 0 = pass)
godot --headless --path . --import
godot --headless --path . res://tests/test_runner.tscn
```

## Repository layout

```
project.godot          Engine configuration and autoload registration
src/app/               Application root, screen router, transition handling
src/autoload/          Singletons: Settings (persistence), ThemeManager (themes)
src/core/              Engine-agnostic logic: settings schema/store, data loading of JSON,
                       and the game-wallet currency primitive
src/platform/          The only place that asks what platform the game runs on
src/ui/theme/          Design tokens, palettes, typography and the runtime theme builder
src/ui/components/     Reusable interface parts (nav row, segmented control, setting row, header)
src/ui/screens/        Full-window views (main menu, settings, about & credits)
src/ui/backdrop/       Procedural chart backdrop
assets/                Fonts (with licences), SVG icons, shaders, project icon
data/                  JSON content: build status and credits
tests/                 Headless test runner and suites
```

Architectural boundaries for future gameplay (`simulation/`, `world/`, `economy/`, `politics/`,
`diplomacy/`, `military/`) are described in [ARCHITECTURE.md](ARCHITECTURE.md). They are *not*
created as empty folders in this milestone: boundaries are documented first and materialise when
the first real code arrives.

## Documentation

| Document | Contents |
| --- | --- |
| [GAME_DESIGN.md](GAME_DESIGN.md) | Vision, pillars, systems, permanent currency rules |
| [ROADMAP.md](ROADMAP.md) | Milestones and their status (planned / in progress / implemented / tested / deferred) |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Project structure, technical decisions, cross-platform strategy, testing |
| [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) | Colours, typography, spacing, components, motion, responsiveness |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Conventions, review checklist, crediting policy |

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
typefaces Spectral, IBM Plex Sans and IBM Plex Mono (SIL OFL 1.1, licences in `assets/fonts`).

## Licensing

The project owner has not chosen a source licence yet. Until one is selected, treat the source as
all rights reserved. Bundled third-party components keep their own licences.
