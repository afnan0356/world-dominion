# Builds — two paths, and what each one promises

There are exactly two ways this project turns into something a person can run. One always
works. The other depends on tooling that this environment cannot guarantee, and says so
out loud rather than shipping a file it did not build.

Both are produced by `.github/workflows/export.yml`, which runs **only when asked**
(`workflow_dispatch`) or when a `v*` tag is pushed. Nothing here runs on an ordinary push:
the validation workflow is the gate on the code, and an artifact build must never slow that
down or block it.

## Path 1 — the project bundle (always produced)

```bash
python3 tools/build_project_bundle.py --self-test
python3 tools/build_project_bundle.py --out dist/world-dominion-<version>.zip
python3 tools/build_project_bundle.py --verify dist/world-dominion-<version>.zip
```

The bundle is a zip of the project — `project.godot`, `src/`, `data/world/`, `assets/`,
`scenes/`, `tests/`, the tools and the docs — plus a `BUNDLE.json` inside it that lists
every file with its size and SHA-256. Unzip it, open the folder in **Godot 4.6.3**, and
press play. It is the build path that needs no Android SDK, no export template and no
network.

Three properties are deliberate:

* **Deterministic.** Entries are sorted, timestamps are fixed at 1980-01-01 and modes are
  normalised, so the same tree produces byte-identical archives. `--self-test` proves it by
  building twice and comparing; the workflow runs that before it builds anything.
* **Self-describing.** `--verify` re-reads the archive and checks every file against the
  manifest it carries, so a truncated download or a corrupted copy is detected by the
  artifact itself, not by trusting the log that produced it.
* **Not a redistribution of third-party data.** `data/source/` (the downloaded Natural
  Earth and CLDR files) is excluded. The pins that regenerate it are committed, and the
  licences are in [THIRD_PARTY_LICENSES.md](../THIRD_PARTY_LICENSES.md).

## Path 2 — the Android APK (attempted, never faked)

The `android` job installs Godot 4.6.3 **with its export templates**, sets up an Android
SDK with platform 34 and build-tools 34.0.0, imports the project and runs:

```bash
godot --headless --path . --export-debug "Android Debug" build/world-dominion.apk
```

Two outcomes, and both are honest:

* **An APK exists** → it is uploaded with `sha256sum` and its size, and the run summary says
  so.
* **No APK** → the job writes `build/EXPORT_REPORT.md` containing the last 40 lines of the
  engine's own export log and of the SDK install log, uploads that instead, and the summary
  says "no APK — see build/EXPORT_REPORT.md". The rule is simple: this workflow never
  uploads a file it did not build, and never calls a failed export a success.

The known failure modes, so they are not a surprise:

| Symptom in `build/export.log` | What it means |
| --- | --- |
| `No export template found` / `Export template not found` | the templates for this exact engine build are not installed; the engine version and the template version must match |
| `Android SDK path is not configured` | `ANDROID_HOME` is unset or the SDK layout is not the one the engine expects |
| `Unable to find Android build-tools` / `platform` | platform 34 / build-tools 34.0.0 are not installed |
| `Keystore not found` | a release export needs a signing key; the debug preset does not, so this means the wrong preset was used |

None of those are fixed by editing the workflow to ignore them. They are fixed by making the
tooling available, and until then the bundle remains a working build.

## Checking a build by hand

Before calling either artifact good, work through
[MANUAL_TEST_CHECKLIST.md](MANUAL_TEST_CHECKLIST.md) on the device it is for. A headless
suite can prove behaviour, saves and layout arithmetic; it cannot prove touch targets, real
frame pacing or how the map feels under a thumb.

## What is deliberately not here

* **No signed release build.** Signing needs a key that must never live in this
  repository, and there is no release to sign yet. `ROADMAP.md` records it as planned.
* **No store upload.** No store listing exists, and nothing here claims one does.
* **No desktop export.** The same template problem applies, and the bundle already runs on
  a desktop through the editor.
