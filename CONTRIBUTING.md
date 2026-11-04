# Contributing to WORLD DOMINION

WORLD DOMINION is a long-term project with human and AI-assisted contributors. These conventions keep
the codebase coherent as it grows.

## Before you start

- Read [ARCHITECTURE.md](ARCHITECTURE.md) for boundaries and [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) for
  the visual language.
- Check [ROADMAP.md](ROADMAP.md) — do not implement a later milestone early, and do not mark planned
  work as done.
- Use Godot **4.6.x** (standard build). Do not upgrade the engine version as a side effect of another
  change; that is its own pull request.

## Running the project

```bash
godot --headless --path . --import                       # import resources
godot --editor --path .                                  # open in the editor
godot --headless --path . res://tests/test_runner.tscn   # tests (exit 0 = pass)
pip install gdtoolkit==4.5.0 && gdlint src tests         # static analysis
```

## Code conventions

- GDScript only. Tabs for indentation, 100-column limit, `snake_case` functions/variables,
  `PascalCase` classes, `SCREAMING_SNAKE_CASE` constants.
- Every script starts with a `##` doc comment stating what it owns and, when useful, what it must not
  do. Comments explain *why*; do not narrate obvious code.
- Keep scripts single-purpose. If a file needs "and" to describe it, split it.
- Interface styling goes through `ThemeFactory` type variations. Per-instance `theme_override_*` is
  allowed only for responsive typography or state-dependent label colours, and must say so in a
  comment.
- No magic numbers in scenes for spacing, radii or durations: use `DesignTokens`.
- Screens communicate upwards with signals; they do not reference the router or each other.
- `src/core/**` must remain free of UI and scene dependencies so it can be tested headlessly.
- Only `src/platform/platform_info.gd` may branch on the operating system.
- No new dependency, plugin, addon or service without discussing it first. No paid APIs, no
  generative-AI services, no analytics, no advertising SDKs, no accounts, no backend.

## Data and content

- Runtime content lives in `data/*.json` and is loaded through `DataLoader` (which reports failures
  instead of crashing).
- Add or update a validation test in `tests/suites/test_data_files.gd` when a content file changes
  shape.

## Tests

- Every behavioural change needs a test. Design changes need a design-system or layout assertion.
- A UI change is not complete until `tests/suites/test_layout.gd` covers the screen at the
  phone-landscape size (844×390) as well as a desktop size.
- Never commit a change that leaves `gdlint` or the test suite failing.

## Mandatory polish pass (every milestone)

Before a milestone is considered complete:

1. Inspect every screen that changed (in the editor or on a device — say which).
2. Fix inconsistent spacing, alignment and typography.
3. Re-check colours, contrast, borders and hover/focus/disabled states.
4. Improve transitions where they help; remove any that do not.
5. Check phone landscape, tablet and desktop dimensions.
6. Remove temporary or placeholder-looking elements.
7. Confirm the screen still reads as part of one coherent game.

If visual inspection was not possible, say so explicitly in the pull request instead of implying it
happened.

## Honesty rules

- Never mark planned functionality as implemented, in code, docs or a pull request summary.
- Never claim a platform build or a rendering check that was not actually performed.
- Unfinished navigation entries stay disabled and labelled **PLANNED**.

## Crediting

- Human contributors are added to `data/credits.json` under `human_contributors` with their name and
  the work they did.
- AI-assisted work is listed separately under `ai_assisted`. If an AI tool materially produced code,
  documentation or assets, disclose it — including the tool and the scope.
- Never invent contributors, permissions, endorsements or affiliations. The project creator is
  credited as **Md. Afnan — Project Creator**.

## Secrets

Do not commit API keys, tokens, keystores, provisioning profiles or signing certificates. Nothing in
this project requires a secret to build or run.

## Pull requests

Include: what changed, why, how it was validated (commands and actual results), what could not be
validated, and any decision the project owner needs to make. Do not merge your own changes into the
protected branch without review.
