# Android status

**Short version: this project does not support Android yet.** No Android build has ever been produced,
installed or tested. Nothing in this repository should be read as a claim that it runs on a phone.

This page records exactly how far the work goes, what is missing, and what the next honest step is.

## What exists

| Piece | State |
| --- | --- |
| Cross-platform design | Done: one interface, responsive breakpoints, touch-sized targets (`TOUCH_TARGET_MIN = 48`), mouse *and* touch input handlers, pinch-to-zoom, no keyboard-only paths. |
| Renderer choice | GL Compatibility, the broadest mobile/desktop profile, chosen for Android feasibility. |
| Export preset | `export_presets.cfg` contains one preset, **Android Debug**, hand-written for this repository. |
| CI workflow | `.github/workflows/android-debug.yml` — **manual only** (`workflow_dispatch`), marked non-blocking, uploads a debug APK artifact. |
| Produced APK | **None.** The workflow has never been run successfully, because the development environment has no JDK, no Android SDK and no access to the export-template download. |
| Device testing | **None.** No APK has been installed on any phone. |

## Why the workflow is not proof

Every step in `.github/workflows/android-debug.yml` is standard Godot Android CI practice: JDK 17, the
Android SDK, the official export templates, an ephemeral debug keystore, an editor settings file that
points Godot at the SDK and keystore, then `--export-debug`. That is a reasonable recipe — but it was
written from documentation, not from a successful local run, and a recipe that has never been executed
is a hypothesis.

The known risks, in order of likelihood:

1. **Editor settings file format.** Godot writes `editor_settings-4.tres` itself; the workflow composes
   it by hand. If the resource type or a key name is wrong, the export fails with a keystore or SDK
   error.
2. **Export template download.** `include-templates: true` fetches ~1 GB of templates. If the runner or
   the action's cache misbehaves, the export fails before anything is produced.
3. **Android SDK components.** Godot's exporter needs specific `build-tools` and `platform` packages.
   `setup-android` installs the SDK, but not necessarily the versions Godot expects.
4. **Preset validity.** The preset is hand-written; Godot tolerates missing option keys by filling
   defaults, but an option with the wrong type would be rejected.

If a run fails, the fix belongs in one place: record the failing step here with its log excerpt, then
adjust the workflow. Do not describe a partially working workflow as Android support.

## What "done" would have to look like

Android support becomes a real claim only when all of the following are true:

1. The workflow (or a local export) produces an APK from a clean checkout, twice in a row.
2. The APK installs on a real device and launches to the title screen.
3. The map can be panned, zoomed and tapped, and a country can be opened, selected and confirmed as a
   campaign, on that device.
4. The 30-second map stress test (Settings → Advanced / Developer) has been run at full and reduced
   detail, and its numbers are recorded in [`PERFORMANCE.md`](PERFORMANCE.md).
5. The layout has been inspected on a portrait phone screen and a landscape phone screen, and the
   results are written down — with the sizes and the device named.

Until then, README's platform table keeps Android marked **not built or tested**, and the frame-time
rows in `PERFORMANCE.md` keep their **UNVERIFIED** label.

## Target device

The owner's phone — **Realme 9i, Snapdragon 680, Android 13, 6 GB RAM** — is the reference low-end
device for that measurement. It is named here so the eventual numbers have a stated context, not
because anything has been measured on it.

## Installing a build, when one exists

```bash
adb install -r world-dominion-debug.apk     # debug builds are not signed for distribution
```

A debug APK is for testing only. It uses a throwaway key, is not Play-Store-ready, and must never be
presented as a release.
