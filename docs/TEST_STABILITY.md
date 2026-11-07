# Test stability

**What this page is.** Why the headless suite is run three times in CI, what the shared setup and
teardown does, and what the Milestone 11 red run actually turned out to be. It is written for
whoever runs the suite next and sees a difference between two orders.

## 1. The run that started this

Milestone 11 had one red run (`42383304025`) whose two migration assertions passed in the next run
(`42383668885`) with **no production code changed** between them. Only the test file changed. That
is the description of a flake, and it was treated as one — but the artefact says something more
specific, and less comfortable:

* the failing assertion was `restored.baseline_matches(_baseline)`;
* the rewritten assertion was `recorded == _baseline.digest()`;
* `baseline_matches()` requires the recorded digest to be **non-empty** *and* equal;
* a comparison of two strings is satisfied when **both are empty**.

So the rewrite could turn red to green in a run where the save carried no digest at all, without
touching the code that writes it. The commit that made the change also added the diagnostics that
would have shown which case it was — after the run that would have shown it. Run logs from that
period are no longer retrievable (the log receiver returns EOF), so **this cannot be proved from
the artefact**; what can be done is to make both possibilities impossible to pass:

* the strict predicate is back in `test_country_state.gd`, diagnostics and all;
* `test_isolation.gd` asserts that a reference is never empty, whichever way it is asked;
* every suite starts from a clean state, so a run cannot inherit a save, a session or a cache.

The honest summary: **not explained from the artefact, and no longer able to pass silently.**

## 2. What one suite can leave behind

| Kind of state | Where it lived | What clears it now |
| --- | --- | --- |
| The process-wide baseline | `CountryState._shared` | `CountryState.reset_shared()` |
| Diagnostics entries and their sequence number | `DiagnosticsLog._entries` | `DiagnosticsLog.clear()` |
| "This process deleted slot X" | `WorldDeletion._session_slots` | `WorldDeletion.reset_session()` |
| Parsed crosswalks | `ShellIcon`, `IconAtlas`, `FlagImage` | each `clear_cache()` |
| Start rules | `StartEligibility._cached` | `StartEligibility.reload()` |
| Open modal panels | `ModalPanel.stack` | `ModalPanel.clear_stack()` |
| Settings, theme, audio volumes | `Settings`, `ThemeManager`, `Audio` | snapshot and restore per suite |
| The player's save store and an open session | `Game.store`, `Game.session` | snapshot, `Game.close()`, restore |
| Files | anything under `user://` | ten suite-owned directories deleted per suite |

`tests/support/suite_isolation.gd` is the one place that does all of it. The runner calls it
around every suite; a suite no longer has to remember, and a suite that fails halfway no longer
leaves anything behind. Its teardown prints a `LEAK` line when a suite writes a file at the root of
`user://` that the game does not own (`settings.cfg`, `profile.json`, `first_run.json`,
`diagnostics.log` are the only ones it may).

## 3. The three runs

| Run | Order | Gate |
| --- | --- | --- |
| 1 | declaration order (the normal gate) | `RESULT: PASS` |
| 2 | shuffled, seed `20261201` | `RESULT: PASS` **and** identical to run 1 |
| 3 | shuffled, seed `771113` | `RESULT: PASS` **and** identical to run 1 |

Shuffling covers both the suite order and the order of the `test_*` methods inside a suite. It is
reproducible: Godot's `RandomNumberGenerator` is a fixed PCG32, seeded explicitly, and each suite's
method permutation mixes in the seed with its own name, so two suites do not start from the same
permutation. The runner prints `ORDER <normal|shuffle> seed=<n> suites=<n>` and the shuffled suite
order, so any failure can be reproduced locally with:

```bash
GD_TEST_ORDER=shuffle GD_TEST_SEED=20261201 godot --headless --path . res://tests/test_runner.tscn
```

`tools/check_suite_stability.py` compares the runs. It compares **verdict, test count and
assertion count** per suite, because a suite that quietly asserts less — an empty loop, a fixture
that failed to load — still prints PASS. Its `--self-test` proves it catches a flipped verdict, a
changed count and a missing suite, and that it accepts a reordering with identical results.

## 4. Adding a suite

Nothing to remember, but two rules:

1. Write files under one of the directories in `SuiteIsolation.TEST_DIRECTORIES`, or at the root
   only if the game itself owns the file name. Otherwise the teardown reports a `LEAK`.
2. If a suite needs something built once (a world atlas, a store), build it in `before_suite()`
   rather than in the first test that needs it, so the shuffled runs cannot arrive in another
   order.

If the game gains a new `static var` cache, give it a `clear_cache()`/`reset_*()` **and** add it to
`SuiteIsolation._reset_module_state()`. `test_isolation.gd` fails when a cache it fills does not
empty.
