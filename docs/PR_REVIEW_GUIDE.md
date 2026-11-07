# How to review a pull request here

This guide is written for someone reviewing their first pull request in WORLD DOMINION,
or coming back after a month away. It explains what is in the repository, which files
actually decide whether a change is good, what the automated checks can and cannot
prove, and what a reviewer has to look at with their own eyes.

You do not need to run the game to review a pull request. You do need to read the parts
that the automation does not read for you — the list is at the end.

---

## 1. How the project is organised

The repository is a Godot 4 project with a plain-Python toolchain beside it.

| Area | Where it lives | What it is for |
| --- | --- | --- |
| The app | `src/app/` | One scene, a screen router, and the root that owns transitions |
| Screens | `src/ui/screens/` | One folder-level screen each: main menu, atlas, campaign, load, settings, about |
| Components | `src/ui/components/` | Reusable pieces: header, nav row, map panel, search, segmented control |
| Map | `src/ui/map/` | The map view, its controls, the display-options panel |
| Theme | `src/ui/theme/` | Palette, design tokens, typography, the theme factory |
| Animation | `src/ui/animation/` | The animation table and the one service that runs it |
| Core | `src/core/` | Data models and services: world, save, settings, simulation, projection |
| Data | `data/` | The world atlas, one folder per country, and the generated pack |
| Tools | `tools/` | Python and GDScript scripts that build, validate and report |
| Tests | `tests/` | The headless suite, one file per subject, and a canary that must fail |
| Docs | `docs/` | Everything a contributor needs, including this file |
| Automation | `.github/workflows/ci.yml` | The only thing that runs the game in this project's history |

## 2. What each milestone added

Milestones are the project's unit of trust: each one is finished, documented and
reviewable before the next begins.

| Milestone | Subject | Where to look |
| --- | --- | --- |
| 01 | Shell, theme, design system, settings, accessibility | `src/ui/theme/`, `src/ui/components/`, `tests/suites/test_design_system.gd` |
| 02 | World atlas: data, geometry, map rendering, dossier | `src/core/world/`, `src/ui/map/`, `data/world/`, `docs/MAP_RENDERING.md` |
| 03 | Campaign start, calendar, save system, recovery | `src/core/save/`, `src/ui/screens/campaign_setup.gd`, `docs/SAVE_FORMAT.md` |
| 04 | Completion pass: animation, polish, accessibility, extras, docs | `src/ui/animation/`, `docs/ANIMATION.md`, `docs/DATA_QUALITY.md`, `docs/PR_REVIEW_GUIDE.md` |
| 05 (planned) | Country statistics — **not started** | `ROADMAP.md` |

### Milestone 08 — screens first

| Task | Where to look | What to check |
| --- | --- | --- |
| 1 — flags and the string table | `src/ui/components/flag_tile.gd`, `src/ui/strings.gd` | a flag appears in a result row and the dossier header; the five flagless records show a badge; every new screen's text comes from `Strings.t()` |
| 2 — first run | `src/core/profile/first_run_store.gd`, `src/ui/screens/first_run/` | the terms page says only true things; notifications are a preference and say PLANNED; declining writes nothing |
| 3 — country picker | `src/ui/components/country_picker_panel.gd`, `flag_strip.gd`, `src/ui/screens/campaign_setup.gd` | map, list and strip share one selection; search matches both ISO codes; groups come from committed data |
| 4 — profile and avatars | `src/ui/screens/profile/`, `src/ui/profile/avatar_art.gd`, `src/ui/components/avatar_gallery.gd` | every number comes from the profile file; the rename shows price and balance first; no image file and no URL path; 20 named drawings |
| 5 — tutorial | `src/ui/tutorial/tutorial_steps.gd`, `src/ui/components/tutorial_panel.gd`, `src/ui/screens/game_screen.gd` | each step teaches a control that exists; finishing pays once through the profile; skipping pays nothing; the pause menu reopens it |
| 6 — backup/worlds | `src/ui/screens/worlds/`, `src/ui/screens/backup/`, `src/ui/components/integrity_dialog.gd`, `src/core/profile/profile_store.gd` | three answers, each with a checkable effect on the files; nothing repaired or deleted silently; no OS file picker claimed |

## 3. The files that matter most

If you read ten files per pull request, read these:

| File | Why it decides the review |
| --- | --- |
| `docs/DESIGN_SYSTEM.md` | Every colour, size, spacing and duration rule. A change that breaks it is visible to a reviewer without running anything |
| `src/ui/theme/palette.gd` | The two palettes and the contrast requirements that are checked automatically |
| `src/ui/theme/design_tokens.gd` | Spacing, radius, control heights, type scale, motion durations |
| `data/world/manifest.json` | Provenance: dataset, commit, licence, counts, limitations. If this is wrong, the map is wrong |
| `src/core/save/save_store.gd` | The save contract. A change here can lose a player's campaign |
| `tests/run_tests.gd` | Which suites exist. A new suite that is not registered never runs |
| `.github/workflows/ci.yml` | What is actually checked, and how a pass is decided |
| `ARCHITECTURE.md` | How the pieces fit together and which layer may call which |
| `CONTRIBUTING.md` | The rules a contributor is held to, including map changes |
| `docs/ANIMATION.md` | Every animation, and the reduced-motion answer for it |

## 4. Generated files: never edit by hand

These files are produced by a script and checked for freshness in CI. Editing one
directly makes the check fail, and worse, makes the document disagree with the code.

| Generated file | Produced by | Freshness check |
| --- | --- | --- |
| `docs/DATA_QUALITY.md` | `python3 tools/validate_world_atlas.py --report docs/DATA_QUALITY.md` | `--check-report docs/DATA_QUALITY.md` |
| `docs/ANIMATION.md` | `python3 tools/report_animations.py` | `python3 tools/report_animations.py --check` |
| `docs/DATA_COMPLETENESS.md` | `python3 tools/report_data_completeness.py` | `python3 tools/report_data_completeness.py --check` |
| `docs/STATISTICS_REPORT.md` | `python3 tools/build_statistics.py --report docs/STATISTICS_REPORT.md` | `python3 tools/validate_statistics.py --check-report docs/STATISTICS_REPORT.md` |
| `docs/CONTROL_SIZES.md` | `python3 tools/control_size_report.py` | `python3 tools/control_size_report.py --check` |
| policy documents (see `tools/report_policies.py`) | `python3 tools/report_policies.py` | `python3 tools/report_policies.py --check` |
| `data/world/{countries,geometry,statistics,manifest,start_eligibility}.json` | `python3 tools/build_country_pack.py` | `python3 tools/build_country_pack.py --check` |
| `data/world/countries/<ID>/statistics.json` | `python3 tools/build_statistics.py` | `python3 tools/build_statistics.py --check` and `python3 tools/validate_statistics.py` |
| `data/world/coast.json` | `python3 tools/build_coast_data.py` | `python3 tools/build_coast_data.py --check` |
| `data/world/countries/<ID>/` | `python3 tools/build_country_pack.py` (folders) | `python3 tools/validate_country_folders.py` |

If a pull request changes one of these, the reviewer's question is always: **was the
generator run, and does its output match what changed in the source?**

### Reviewing the figures specifically

If a pull request touches a number a player can see, four questions decide it, and each has
a file that answers it:

1. **Where did the number come from?** `docs/STATISTICS_REPORT.md` names the dataset, the
   version, the commit, the retrieval date, the licence and the file's SHA-256. A number
   without that block is a number to reject.
2. **Does it have a year?** Every non-derived figure carries one, and the game shows it. An
   undated figure is not allowed, however plausible it looks.
3. **Is it an exact integer?** `tools/build_statistics.py` rejects fractions, negatives, text
   and overflow, and lists each rejection with the reason. Rounding is not a fix.
4. **Does it reach the simulation?** It must not. `tests/suites/test_statistics.gd` fails if
   `src/core/sim/` or `src/core/save/` mentions statistics, and no save contains a figure, so
   an old save cannot disagree with a new one.

## 5. What each automated step proves — and what it does not

The workflow is called *Validation* and lives in `.github/workflows/ci.yml`. Every step
below is listed with the rule that decides pass or fail, and the thing a green tick does
**not** mean.

| Step | Passes when | Does **not** prove |
| --- | --- | --- |
| Install gdtoolkit | `pip install gdtoolkit==4.5.0` succeeds | nothing about the project |
| Lint GDScript | `gdlint src tests tools` finds no problems | that the code is correct, or even that it compiles |
| Check atlas data integrity | `tools/check_atlas_data.py` exits 0: files parse and agree | that the shapes are right, or that the source was recorded honestly |
| Validate atlas data + report freshness | `validate_world_atlas.py --check-report` exits 0 and the report on disk is byte-identical to a fresh one | that the dataset itself is accurate. It proves the project's own claims match its own files |
| Verify the runtime pack matches the folders | `build_country_pack.py --check` exits 0 | that anyone read the per-country READMEs |
| Validate the per-country folder tree | `validate_country_folders.py` exits 0 | that the source notes are true, only that they exist and are well formed |
| Coastline hints are up to date | `build_coast_data.py --check` exits 0 | that the coastline classification is visually correct |
| Folder validator self-test | `validate_country_folders.py --self-test` exits 0: the validator rejects deliberately broken fixtures | that it rejects every possible breakage |
| Policy documents are fresh | `report_policies.py --check` exits 0 | that the policies are wise, only that the documents match the code |
| Animation inventory is fresh | `report_animations.py --check` exits 0; also fails when a name used in code is missing from the table | that an animation looks good, or that the durations feel right |
| Data completeness report is fresh | `report_data_completeness.py --check` exits 0 | that no gap was quietly filled in — that is what the report lets a human check |
| Import project resources | `godot --headless --path . --import` exits 0 | that any scene is usable |
| Parse-check every changed GDScript file | no `Parse Error` outside the known autoload false positives | that the *unchanged* scripts compile, or that the code runs |
| Run headless test suite | the run prints `RESULT: PASS` — the gate reads that line, not the exit code | that a player can see or use anything. It is a headless engine |
| Benchmark | the run prints `BENCHMARK OK` **and** the process exits 0 | that a real machine, or a phone, will see those timings |
| Boot smoke test | the title screen logs no script errors and exits 0 | that any other screen works |
| Publish logs as commit comments | the comment API call succeeds | anything about the code |
| **Prove the test gate rejects a failing suite** (manual only) | the canary suite makes the run print `RESULT: FAIL`, and the gate step is shown to reject it | that the other gates are honest. It checks one gate, deliberately |

Two things a reviewer should take from that table: the project trusts *printed
verdicts* over exit codes (because a Godot process can exit 0 with a script error), and
nothing automated can tell whether a screen looks right.

## 6. What the suite covers, and how to read its output

`tests/run_tests.gd` runs every suite and prints one line per suite:

```
PASS  test_dossier                9 tests · 29107 assertions
```

Read that as "nine named cases, containing 29,107 assertions". The counts are reported
separately on purpose: one case can contain thousands of assertions (every vertex of
every polygon), and averaging them would hide which one failed. A failing run prints the
case name and the assertion message, and CI copies those into annotations.

## 7. The owner's checklist

Use this before approving. It is deliberately short; each line is something a machine
cannot confirm.

- [ ] The pull request says what changed and what did **not** change.
- [ ] Every new screen looks right in **both themes** (Midnight and Parchment) and at
      the three layout sizes (desktop, tablet, phone). Screenshots or an honest statement
      that none were captured — never a data render presented as a screenshot.
- [ ] Everything works with **touch**, **mouse**, **keyboard** and **reduced motion**.
- [ ] No claim is made that a check did not verify. Gates that ran privately or could not
      be run are described as such.
- [ ] Generated files were regenerated, not hand-edited.
- [ ] No forbidden scope crept in: no economy, politics, diplomacy, military, AI,
      resources, UN, scenarios, editor, achievements, news feed or statistics. No change
      to the eligibility rule, the disputed-territory wording, the data pack or save
      semantics without saying so plainly.
- [ ] No network calls, accounts, analytics, ads or paid APIs were added.
- [ ] Everything added is original: no copied code, art, sound or interface from another
      game.
- [ ] Docs match the code: `README`, `ROADMAP`, `ARCHITECTURE`, `DESIGN_SYSTEM`,
      `PERFORMANCE`, `GLOSSARY`, `CONTRIBUTING` and the generated reports.
- [ ] The pull request's own description is still accurate after the last commit.

## 8. How to reproduce a review locally

```bash
# the fast checks, no engine needed
gdlint src tests tools
python3 tools/check_atlas_data.py
python3 tools/validate_world_atlas.py --check-report docs/DATA_QUALITY.md
python3 tools/report_animations.py --check
python3 tools/report_data_completeness.py --check
python3 tools/validate_country_folders.py --self-test

# the suite, if you have a Godot 4.6.3 binary
godot --headless --path . --import
godot --headless --path . res://tests/test_runner.tscn
```

Then look at the game the way a player would: main menu, atlas, a campaign, the map
options panel, the pause menu, and Load Game with one good save and one damaged one.
That is the part no workflow can do for you.
