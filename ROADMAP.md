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
- `godot --headless --path . res://tests/test_runner.tscn` — 6 suites, 3744 assertions, 0 failures.
- Application smoke run: `godot --headless --path . --quit-after 180 res://src/app/main.tscn` — the
  shell boots, builds its theme and shows the main menu without errors.
- Layout geometry inspected node by node at 1920×1080, 1280×720, 1024×768, 844×390, 640×360 and
  390×844.

### Not tested here

- **Nothing was rendered.** The validation environment has no display server or GPU, so the shell was
  verified through layout/geometry assertions and code review rather than by looking at pixels. The
  project owner should open the project in the Godot editor to confirm final visual judgement.
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

## Milestone 02 — Campaign creation & world data

Status: **Planned**

- Scenario selection: a small number of hand-authored starting situations.
- Country selection from world data; difficulty framing without hidden rule changes.
- World data format (JSON) with a schema and a validation test, plus a documented content pipeline.
- First pass of the in-game shell: persistent top bar, date/time controls, notification area.
- Save slot creation (a new campaign writes a local save immediately).

## Milestone 03 — Save management & campaign continuity

Status: **Planned**

- Versioned save format with migration support, atomic writes and a corruption-safe fallback.
- Autosave/rolling saves, manual slots, and delete/duplicate.
- The `Continue` and `Load` flows on the main menu become functional.

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

- No rendered verification was possible in the development environment (headless only).
- The light theme is complete and contrast-tested, but its final look has not been reviewed on a
  real display.
- iOS cannot be built from this repository alone: it requires Xcode, signing identities, provisioning
  profiles and an Apple Developer account held by the project owner.
- The interface scale setting from 130 % on a small phone in landscape will require scrolling on the
  settings screen; that is intended behaviour, not a defect, but it deserves a device check.
