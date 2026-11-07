# Security and integrity

This document says what the game does about security, what it deliberately does **not**
do, and which claims have actually been verified. It exists because it is easy to write a
sentence like "saves are protected" and much harder to mean it.

**The one-sentence version: World Dominion is an offline single-player game with no
accounts, no network access and nothing worth stealing from a server, so its integrity
work is aimed at corrupted files and casual tampering, not at determined attackers. It is
not anti-cheat, and nobody should treat it as one.**

---

## 1. The attack surface, honestly stated

| Surface | Status |
| --- | --- |
| Network | **None.** The game makes no network calls of any kind at runtime. There is no account, no telemetry, no crash reporting, no ads, no analytics, no remote config. |
| Permissions | **None requested.** No storage, location, contacts, camera or notification permission is requested by the shipped game. |
| Files read | Only files inside the game's own `user://` directory (saves, settings, profile), plus the read-only content packed with the game. |
| Files written | Only inside `user://`. |
| External input | Touch, mouse and keyboard. Keyboard shortcuts are listed on the Shortcuts screen. |
| Third-party code | Godot Engine only (MIT). No plugins, no addons, no SDKs. See `THIRD_PARTY_LICENSES.md`. |
| Audio assets | **None.** The two interface tones are generated from a sine in `Audio._build_tone()`; no audio file is bundled, downloaded or licensed in. There is no microphone or playback permission to request. |

Because the game is offline and has no network stack in use, the classic threats — stolen
credentials, session hijacking, server-side injection, data exfiltration — do not exist
here. What remains is local: a file on the player's own device that someone has edited,
truncated or corrupted.

## 2. What the save system actually does

- **Validation on load.** A save is parsed into typed values with explicit checks; a field
  that is out of range, the wrong type, or missing its required companions is rejected
  rather than defaulted into something plausible. Numbers arriving as JSON floats are
  coerced once, and non-whole values are refused rather than rounded.
- **Versioned files with migrations.** Saves carry a schema version. Older files are
  migrated by a chain of explicit steps, and a version the build does not recognise is
  refused with a message instead of being guessed at. A frozen save fixture from an earlier
  milestone is loaded by the test suite on every run, so "old saves still load" is checked,
  not assumed.
- **Atomic writes.** A write goes to a temporary file and is moved into place, so an
  interrupted write leaves the previous save intact rather than a half-written one.
- **Recovery, not silent data loss.** An unreadable save is reported to the player and left
  on disk; the game never deletes a file it could not parse.
- **No hidden state.** A save contains what the game needs to continue and nothing about
  the device it came from.
- **An integrity signature over the body.** Saves, the player profile and backup files carry a
  keyed digest (`src/core/save/integrity_signature.gd`). It detects a damaged, mangled or
  casually edited file; it cannot stop a determined person, because the key ships in the binary
  and the source is published. A mismatch never destroys anything: the file is read, the player
  is told in plain words, and the choice is theirs — use the previous copy, continue with a
  warning, or cancel. Files written before signatures existed report themselves as unsigned,
  not as tampered with.

## 3. What this is not

There is **no anti-cheat** here, and this document will not pretend otherwise. A save file
lives on the player's device, in a format the player can read and edit. Any local check can
be bypassed by a person who is willing to edit a file or rebuild the game. That is true of
every offline single-player game, including the ones that spend a lot of money pretending
otherwise.

The project's position:

- **Single-player integrity is the player's business.** If someone edits their own save to
  give themselves a thousand gems, they have changed their own game and harmed nobody.
- **An integrity signature, when it lands, is a corruption detector and a speed bump** — it
  catches a file that was damaged in transit or mangled by a bad copy, and it makes casual
  editing obvious. It is not a lock, and the UI must never threaten the player with
  consequences for a file they own.
- **No punishment mechanics.** The game must never ban, brick or "shadow-punish" a save for
  failing a check. If a signature does not match, the honest behaviour is to say so, load
  the file with a visible "modified" note, or refuse it with an explanation — never to
  silently corrupt the player's own progress.
- **No anti-cheat that phones home.** Since there is no network, there is nowhere to phone.

## 4. Verification status

Claims in this document are tagged. **Verified** means a test or a check in this repository
demonstrates it on every CI run. **UNVERIFIED** means the code path exists or is planned but
has not been demonstrated in this environment (a headless Linux container with no Godot
binary on the development machine and no phone or tablet available).

| Claim | Status | Evidence |
| --- | --- | --- |
| The game makes no network calls | **UNVERIFIED on device** | The project has no networking code and the export template is Godot's; a build-time audit has not been run, and nobody has watched a real build's traffic. |
| The game requests no OS permissions | **UNVERIFIED on device** | No permission is requested in the project or in any export preset; the Android manifest produced by a real export has not been inspected, because no Android export has been produced yet. |
| Saves are validated on load and bad fields are rejected | **Verified** | `tests/suites/test_save_system.gd`, `test_data_recovery.gd` — including hostile and truncated inputs |
| Old saves still load after a schema change | **Verified** | frozen fixture loaded by the save suite |
| Writes are atomic | **Verified (unit level)** | the save writer is exercised in the suite; a real power-loss interruption has not been tested on a device |
| Unparseable saves are preserved, not deleted | **Verified** | recovery suite |
| No third-party SDK or plugin is bundled | **Verified** | repository audit: no addons, no plugins, engine only |
| Licence and attribution appear in the About screens | **Verified** | about-screen content tests |
| Saves, the profile and backups carry an integrity signature | **Verified** | `src/core/save/integrity_signature.gd`; the body is normalised before digesting, so a JSON round trip does not look like tampering |
| A failed signature is reported and never acted on by itself | **Verified** | `tests/suites/test_integrity.gd` — the file still loads where it can, the message names the edit, and the player is offered the previous copy, a warned continue, or cancel |
| The three choices are reachable from the store layer | **Verified (core only)** | `ProfileStore.load_backup()`, the save store's backup load, `BackupBundle.inspect` — the screens that present the choice are not built yet |

## 5. Release hardening — what must be true before a store build

These are the things a release build has to get right, recorded here so they are not
rediscovered at submission time. None of them is verified today.

| Item | Status |
| --- | --- |
| Debug builds excluded from release exports; no developer tools reachable in a release build | **PLANNED** — developer tools exist and are behind a setting; a release-preset check is not yet written |
| No debug symbols or source paths in release binaries | **UNVERIFIED** |
| Android: manifest inspected for permissions, exported `minSdk`/`targetSdk` recorded, debug keystore replaced by a release keystore held by the owner | **UNVERIFIED** — no APK has been built |
| Windows: signed installer or a documented unsigned-install warning | **UNVERIFIED** — no export has been produced |
| iOS: signing identities, provisioning profiles and an Apple Developer account | **UNVERIFIED** — cannot be built from this repository alone |
| Store privacy declarations (no data collected, none shared, no tracking) | **PLANNED** — the answers are simple because there is nothing to declare, but the forms are not filled in |
| Age rating and content questionnaire | **PLANNED** |
| A backup/restore path tested on a real device with a real file manager | **UNVERIFIED** |
| Accessibility checks on a real display (contrast, scale, large text) | **UNVERIFIED** — contrast is unit-tested; the room, the sunlight and the phone are not |
| Crash and error reporting | **Deliberately absent.** Nothing is uploaded. Player-facing errors are shown on screen. |

## 6. Reporting a problem

Please open an issue on the repository page. Say what you did, what happened, and — for a
data problem — which record and which file. Do not include personal information, and do not
send a save file you would not want to make public; describe it instead if you can.

Given the project's licence (`LICENSE`), there is no bug bounty programme, no security
e-mail address and no service-level promise. What there is: a defect list, and the intent
to fix real problems.
