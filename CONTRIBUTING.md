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
- Hand-authored content (build status, credits, scenarios) is committed. **Generated** content
  (`data/world/countries.json`, `data/world/geometry.json`, `data/world/manifest.json`) is produced
  by `tools/build_world_atlas.py` and committed as well, because the game must ship with no build
  step: never edit those three files by hand, and never hand-tune a border.

### Geographic content rules

These exist because geography is the easiest place in this project to accidentally publish a claim.

1. **Never invent a place, a border, a capital, a code or a statistic.** If the source does not
   record a value, the value is empty and the interface says "Not recorded in source". No
   placeholders, no "N/A", no best guesses, no data from memory.
2. **Sovereignty is reported, never decided.** `TYPE`, `SOVEREIGNT`, `NOTE_ADM0` and `NOTE_BRK` are
   copied verbatim from the dataset. Do not merge a disputed or dependent unit into its neighbour, do
   not drop one, and do not rename one to make a screen read better. Representation questions
   (including Israel/Palestine) are **owner decisions**; until an owner policy exists, the source's
   geometry and classification stay untouched and the neutrality policy in
   [DATA_SOURCES.md](DATA_SOURCES.md) applies.
3. **Every geographic change goes through the pipeline**, with the source repository, commit,
   retrieval date, licence, processing steps and known limitations recorded in the manifest and in
   [DATA_SOURCES.md](DATA_SOURCES.md) in the same pull request.
4. **Keep the data honest to its source.** If you must transform (quantise, simplify, drop tiny
   holes), document it in `manifest.json`'s `processing` block and in the docs.
5. **Ids are stable.** `ISO alpha-3` where the source provides one, otherwise the Natural Earth
   admin-0 code. Never derive an id from a display name, and never renumber ids to "tidy" the file.
6. **No runtime fetching.** The game may not download, geocode or call an API for geography. All
   data ships in the repository.
7. **Don't commit duplicate raw sources.** Keep the downloaded GeoJSON out of the repository (it is
   reproducible from the pinned commit); commit only the pipeline, the generated runtime files and
   the manifest.

### Data validation checklist

Before opening a pull request that touches `data/world/`:

```bash
gdlint src tests tools
godot --headless --path . --import
godot --headless --path . res://tests/test_runner.tscn        # country + geometry + campaign suites
godot --headless --path . res://tools/atlas_benchmark.tscn    # refresh docs/PERFORMANCE.md numbers
```

The suites assert: 200+ countries, unique and well-formed ids, ISO shape, required fields, explicit
missing values, every country has geometry and vice versa, coordinates inside the world, closed
rings, holes preserved, known-place hit tests, disputed units preserved, manifest counts equal to
the loaded data, and that this document set exists.

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
- Never claim a platform build or a rendering check that was not actually performed. A geometry
  diagram is not a screenshot: label it as a diagram.
- Never present a measured number you did not measure. If a figure is unverified, say so — for
  example frame time for the map is unverified in this environment because it has no GPU.
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
