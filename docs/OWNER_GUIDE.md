# Owner guide — running a one-person project

This is a personal project with one maintainer and no team. That changes what needs
documenting: there is nobody to ask, and the person who has to understand a decision in six
months is the person who made it, with none of the context. This page is the runbook for
that situation. It is deliberately short and entirely practical.

Nothing here describes something the repository cannot do today. Where a step does not exist
yet it says so, and `ROADMAP.md` carries the plan.

## The rules that never change

1. **Nothing is claimed that does not exist.** A screen, a button or a sentence in a
   document must point at code a player can reach. Work that is planned is labelled PLANNED
   in the interface and in the roadmap, never built as a dead switch.
2. **A number comes from a file that was downloaded**, with its licence, URL, version and
   retrieval date recorded next to it. Never from memory, never from a secondary page.
3. **CI is green before the next change starts.** A red build is fixed in its own commit,
   immediately — not bundled with the next feature, where it becomes invisible.
4. **Every user-visible string lives in the string table** (`src/ui/strings.gd`), and every
   control is sized from `DesignTokens` and reported in `docs/CONTROL_SIZES.md`.
5. **No new dependencies, no network calls at runtime.** The game is offline-first; the only
   network use is in `tools/`, during development, to fetch pinned data.

## The working loop

1. `git switch main && git pull` — start from what passed CI last.
2. Branch for the change. One branch per task in `ROADMAP.md`.
3. Write the test first when the rule is new: the suite is the specification, and a test
   that fails on the old behaviour is proof the change does something.
4. Run the local checks before pushing:
   ```bash
   python3 -m gdtoolkit.linter src tests
   python3 tools/build_docs_index.py --check
   python3 tools/report_data_completeness.py --check
   python3 tools/control_size_report.py --check
   ```
5. Push, open one pull request, wait for the whole workflow — lint, data checks, the suite,
   the benchmark and the boot smoke test — and merge only when it is green.
6. Update `docs/WALKTHROUGH.md` and `docs/MANUAL_TEST_CHECKLIST.md` in the same pull
   request as the feature. A feature the walkthrough does not mention is not finished.

There is no Godot binary in this environment and no display server, so anything that only
a real device can prove is recorded in `docs/ANDROID.md` and `docs/evidence/README.md`
instead of being asserted.

## Updating the world data

The data pipeline is ordered, and the order matters because each step reads the output of
the one before it:

```bash
python3 tools/fetch_world_atlas.py        # download the pinned Natural Earth files (not committed)
python3 tools/build_world_atlas.py        # write data/world/countries/ and the geometry
python3 tools/build_statistics.py         # population, GDP and area per record
python3 tools/build_currency.py --source data/source/cldr-48.0.0   # currency per record
python3 tools/build_currency.py --readmes # regenerate the per-country READMEs
python3 tools/build_country_pack.py       # fold the folders into the runtime pack
python3 tools/build_world_atlas.py --report docs/DATA_QUALITY.md
python3 tools/report_data_completeness.py
python3 tools/build_currency.py --report
python3 tools/build_statistics.py --report docs/STATISTICS_REPORT.md
```

Then run every `--check` above and commit the derived files. **Never hand-edit a file under
`data/world/`:** CI rebuilds the tree and compares bytes, and a hand edit fails the build
with a diff to prove it.

To update the currency source, download the two pinned npm packages again, unpack them into
`data/source/`, and change `SOURCE` in `tools/build_currency.py` — version, URL and
retrieval date together. A source change without a version bump is a lie about provenance.

## Backups, and what is precious here

The repository is the project. Three things are worth protecting and are all committed:

* `data/world/` — the folders are the readable source of truth; the pack is derived.
* `docs/` — every decision and its reason.
* `tests/` — the rules, in executable form.

`data/source/` is **not** committed and does not need to be: every file in it can be
downloaded again from the pin recorded in `data/world/` and in the builders.

The owner's own copies of these, kept outside the repository, are the only backup that
matters: run `git bundle create world-dominion.bundle --all` monthly and keep it somewhere
else. A hosted remote is a convenience, not a backup.

## Preparing a build

A packaged Android export is **not produced yet** — see `ROADMAP.md`. What exists today is
the project itself, which runs in Godot 4.6.3 and can be checked with the suite:

```bash
godot --headless --path . res://tests/test_runner.tscn      # the suite
godot --headless --path . res://tests/boot_smoke.tscn       # boot smoke test
```

Before calling a build good, work through `docs/MANUAL_TEST_CHECKLIST.md` on the device the
build is for. The checklist is the only thing that catches what a headless suite cannot:
touch targets, real fonts, real frame pacing and the feel of the map.

## A hotfix

1. Branch from the commit that last passed CI, not from a half-finished branch.
2. Fix the defect and add a test that fails without the fix. A hotfix with no test is a
   bug that will come back.
3. If the defect is in data, fix the pipeline and rebuild — never the generated file.
4. Merge, then re-run the manual checklist for the screens the fix touched.

## When CI fails

The failure names a step, and each step means one thing:

| Step | What it means | What to do |
| --- | --- | --- |
| Lint | a GDScript style or size rule broke | read the message; the rule is the design, not an obstacle |
| A `--check` step | a generated file is stale or was edited by hand | run the tool the step names, commit its output |
| Parse-check | a file does not compile, often after a refactor | run the same import locally; check for a call to a function that does not exist |
| The suite | a rule was broken, or a test needs updating | read the assertion: it names the behaviour that changed |
| Benchmark | the simulation or save got slower than its budget | see `docs/PERFORMANCE.md`; do not raise the budget without a measurement |
| Boot smoke | the game cannot reach its first screen | reproduce locally with the same command the step prints |

Never disable a check to get green. If a check is wrong, fix the check in its own commit and
say why in the message — that is a change to the rules, and it deserves its own history.

## Coming back after a long gap

Read, in this order: `docs/INDEX.md` (what exists), `ROADMAP.md` (what is done and what is
next), `docs/WALKTHROUGH.md` (what the build does today), then the last few pull request
bodies. That is about fifteen minutes and it replaces the memory of what you were doing.
