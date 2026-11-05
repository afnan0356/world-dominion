# Save format

This document describes exactly what WORLD DOMINION writes to disk when you save, why
each field exists, and what the game does when something is wrong with a file. It is
written for two readers: a player who wants to know whether their campaign is safe, and a
developer who needs to change the format without breaking anyone's save.

Everything here describes **Milestone 03** (save schema 2). Anything that is planned rather
than implemented is labelled *planned*.

---

## 1. Where saves live

| Platform | Location |
| --- | --- |
| Windows | `%APPDATA%\Godot\app_userdata\WORLD DOMINION\saves\` |
| macOS | `~/Library/Application Support/Godot/app_userdata/WORLD DOMINION/saves/` |
| Linux | `~/.local/share/godot/app_userdata/WORLD DOMINION/saves/` |
| Android | the app's private storage area (`user://saves`) |
| iOS | the app's sandbox (`user://saves`) |

`user://` is Godot's per-application data directory. The game **never** writes anywhere
else unless you explicitly export a save with a file dialog.

Files in that folder:

| File | Meaning |
| --- | --- |
| `1.json`, `2.json`, `3.json` | The three manual slots |
| `autosave.json` | The autosave slot |
| `<slot>.bak.json` | The previous good content of that slot (one generation) |
| `<slot>.tmp.json` | Only present for a moment during a save |
| `<slot>.old.json` | Only present for a moment during a save |
| `<slot>.damaged.json` | A copy kept by *Restore backup*, so nothing is thrown away |

The save folder contains nothing that identifies you. A save records the nation you chose,
the in-game date, your playtime and the game version. It contains no device identifiers, no
account name and no personal data beyond what you typed into the game (currently: nothing).

---

## 2. The file itself

A save is a UTF-8 JSON object written by a canonical serialiser (keys sorted, integers and
floats written distinctly). It is small — typically 2–6 KB — because **it never contains map
geometry**. It refers to countries by their stable ids and records which world data it
expects (see §5).

```json
{
  "format": "world-dominion-save",
  "schema_version": 2,
  "game_version": "0.2.0",
  "created_at": "2026-11-05T09:14:02Z",
  "last_saved_at": "2026-11-05T10:41:55Z",
  "slot": "1",
  "playtime_seconds": 312.5,
  "scenario_id": "modern_world_2026",
  "player_country_id": "BGD",
  "player_country_name": "Bangladesh",
  "data_stamp": { "...": "see §5" },
  "state_hash": "…64 hex characters…",
  "checksum": "…64 hex characters…",
  "world": { "…": "see §3" }
}
```

| Field | Why it exists |
| --- | --- |
| `format` | Lets the game reject a JSON file that is not a save (for example a data file), with a plain explanation. |
| `schema_version` | The **shape** of the file. Only this number decides how a file is read. |
| `game_version` | The build that wrote it, from `ProjectSettings`. Shown in the load list; used for support, never for deciding whether a file can be read. |
| `created_at`, `last_saved_at` | UTC ISO-8601. Sortable as text, which is how *Continue* picks the most recent valid save. |
| `slot` | Where it was written. Informational: copying a file to another slot does not change how it loads. |
| `playtime_seconds` | Real seconds spent in the campaign. Also in `world`; the top-level copy is what the load list reads. |
| `scenario_id` | Which scenario definition to check the state against. |
| `player_country_id` | The nation you lead, by stable id — not by name and not by position in a list. |
| `player_country_name` | Cached for the load list so a slot can be described without rebuilding the world. Informational only. |
| `data_stamp` | Which world data the save expects (§5). |
| `state_hash` | SHA-256 of the canonical world state. Detects a save that is internally inconsistent even when the checksum matches. Also the determinism test's comparison value. |
| `checksum` | SHA-256 over every other field, including `world` and `state_hash`. Detects any change after writing. |
| `world` | The campaign state (§3). |

### The checksum

The checksum is computed over the canonical JSON of the payload **with the `checksum` field
removed**, then written next to it. Reading it back:

1. the file must parse as a JSON object with the right `format`;
2. `schema_version` must be an integer this build understands;
3. the checksum must exist and match a freshly computed one;
4. the state hash must match a hash recomputed from `world`;
5. only then is the world rebuilt and validated against the shipped country registry.

A failure at any step stops the load. The file is **never** rewritten as a side effect of
reading it, so a refused save is left exactly as it was found.

### Why the checksum is not a signature

It detects damage and accidental edits, not a determined attacker. A local single-player
game has no secret to sign with, and pretending otherwise would be misleading. Cheating with
a save file only affects the cheater's own campaign.

---

## 3. The `world` section

```json
{
  "schema_version": 1,
  "scenario_id": "modern_world_2026",
  "scenario_name": "Modern World",
  "scenario_version": 1,
  "player_country_id": "BGD",
  "player_country_name": "Bangladesh",
  "seed": 3321883427,
  "game_version": "0.2.0",
  "data_stamp": { "...": "§5" },
  "clock": { "day_index": 739617, "speed": 2 },
  "streams": { "calendar": { "state": 1234567890 } },
  "wallet": { "gold_coins": 0, "diamonds": 0 },
  "playtime_seconds": 312.5,
  "countries": {
    "BGD": {
      "sections": {
        "core": { "version": 1, "source": "campaign_setup", "values": { "...": "..." } }
      }
    }
  }
}
```

* **`clock.day_index`** — days since `0001-01-01`. One tick is one in-game day, so this
  number *is* the date. Stored as an exact integer; a fractional value is rejected rather
  than rounded. The sub-tick accumulator is deliberately **not** saved: it depends on frame
  timing, and a reload must resume on an exact date.
* **`clock.speed`** — 0 paused, 1–4 for the four speeds. Saving a paused game is normal.
* **`seed`** — the campaign seed. The same seed and the same actions reproduce the same
  world; see `docs/SIMULATION_CORE.md`.
* **`streams`** — the position of each named random stream that has been used. Adding a new
  system introduces a new stream name and cannot shift the numbers another stream produces.
* **`wallet`** — integer balances. Values round-trip exactly and are not affected by any
  future national economics; the wallet is a player-level currency, not a national budget.
* **`countries`** — extensible per-country state, keyed by stable id. **Only the player's
  country has an entry in this milestone**, and the entry is created empty: it proves the
  extension point works without inventing a statistic. Each section carries its own
  `version` and optional `source`, so a later milestone can add a section without touching
  the sections already there.
* **`playtime_seconds`** is excluded from the state hash. It is real time, not game state —
  two identical campaigns played for different lengths must still hash the same.

### Extension points and their versions

Three independent version numbers exist and must not be confused:

| Version | Meaning | Where it lives |
| --- | --- | --- |
| Save **schema** | The shape of the whole file | `schema_version` (top level) |
| World state **schema** | The shape of `world` | `world.schema_version` |
| Section **version** | The shape of one per-country section | `world.countries.<id>.sections.<name>.version` |
| **Data** version | Which world data the ids refer to | `data_stamp` |

A new section is added by writing it with `version: 1`. A changed section is written with
`version: 2` and a migration step; readers refuse to interpret a section version they do not
know rather than guessing. Adding a *new* save schema means: bump `SaveFile.SCHEMA_VERSION`,
add one step to `SaveMigrations`, and keep the previous schema readable.

**Loading never rewrites a file.** An older save is upgraded **in memory**, the player is told that it
came from an older version, and the newer shape is written the next time they save. Rewriting on load
would mean that merely *looking* at a slot changes it — bad if the upgrade turns out to be wrong, and
worse if the player only wanted to check what was in the slot.

---

## 4. Autosave, backups and atomic writes

**Atomic write.** A save is written to `<slot>.tmp.json`, read back and verified, copied over
`<slot>.bak.json` if a previous save exists, and only then swapped in with a directory rename.
If anything fails before the rename, the old file is still the save. If the rename itself
fails, the old file is put back. The verification step reads the bytes that actually reached
the disk, not the ones in memory.

**Autosave.** Once per in-game month (on the first tick that lands on the 1st), plus when you
leave the campaign. It writes the `autosave` slot and never blocks a system update: the tick
requests it, the game screen performs it after the frame's ticks are finished. While a menu
is open the clock is stopped, so an autosave never fires while you are reading the pause menu.

**Backups.** One generation is kept per slot. `Load Game` reports a slot whose main file is
damaged *and* offers *Restore backup*; the load itself tries the backup automatically and says
so — never silently. *Restore backup* keeps the damaged file as `<slot>.damaged.json`.

**Recovery, in plain language:**

1. If a slot says "damaged", choose *Restore backup*. You lose at most the time between the
   previous save and this one.
2. If the backup is also damaged, choose another slot, or start a new campaign. The game will
   not invent a campaign for you.
3. If `Continue` is disabled, no slot could be validated. `Load Game` explains why for each one.

---

## 5. Why a save references the world data instead of containing it

Map geometry is ~1.3 MB of data that never changes between saves. Copying it into every save
would make saves large, slow and subtly divergent from the shipped map. Instead a save stores
a **stamp**:

```json
{
  "source_commit": "ca96624a56bd078437bca8184e78163e5039ad19",
  "short_commit": "ca96624",
  "countries": 242,
  "vertices": 99567,
  "ids_fingerprint": "8f2c1d0a",
  "label": "ca96624/242/99567/8f2c1d0a"
}
```

The fingerprint is a hash of the sorted list of country ids — the part a save actually depends
on. On load, the id set must match: a corrected map with the same ids loads fine (geometry can
be fixed without invalidating saves), while a data set where a country id disappeared refuses
the save with an explanation instead of loading a campaign that refers to a country that no
longer exists.

---

## 6. Errors: what you see and what the developer log says

| Situation | What the player sees | Developer log |
| --- | --- | --- |
| File changed after writing | "This save file has been changed or damaged since it was written… A backup may still work." | `checksum mismatch (stored ab12cd34…, computed ef56ab78…)` |
| Truncated or empty file | "This save file is empty, so there is nothing to load." | `the file is empty` / `the file is not a JSON object` |
| Newer schema | "This save was made by a newer version of the game (format 3; this build understands up to 2). It has been left untouched. Update the game to load it." | `save schema 3 is newer than this build's 2` |
| Fractional or out-of-range value | "This save contains values the game will not accept. It has not been loaded." | the exact field and reason, e.g. `clock day_index is missing or out of range` |
| Country id not in this build | "This save was made against a different version of the world data…" | `this save was made against a different country list (…)` |
| Disk write failed | "The game could not write to storage. Your previous save is safe." | `writing the temporary file failed` |

No stack traces are shown in the interface. The detailed reason goes to the Godot output log
for a bug report.

---

## 7. Export and import

* **Export** copies a slot's verified bytes to a file you choose. It is a copy; the slot stays.
* **Import** reads the file, runs the full validation (format, schema, checksum, state hash,
  country ids), and only then offers a slot. The chosen slot is written atomically and keeps a
  backup of what was there.
* Godot's file dialogs are used, with the native dialog where the platform provides one.

**Status, honestly:** the import/export *logic* is covered by the headless test suite. The
**file dialogs themselves are unverified on Android and iOS** — nobody has run this build on a
phone yet. On desktop the dialog is expected to work but has not been verified in this
milestone either, because no graphical session was available. In a headless environment the
buttons say so instead of failing silently.

---

## 8. Measured behaviour (schema 2, desktop-class headless CPU)

| Measurement | Value | Note |
| --- | --- | --- |
| Save file size | ~2–6 KB for a one-country campaign | grows with per-country sections, not with the map |
| Save time | a few milliseconds | reported by `SaveStore.last_save_milliseconds` per write |
| Load time | tens of milliseconds including validation | reported by `SaveStore.last_load_milliseconds` |

Device performance on a phone is **UNVERIFIED**. The numbers are printed by the
instrumentation, not estimated, and are meant to be quoted from a real run — see
`docs/PERFORMANCE.md`.

---

## 9. What this format does not do yet (planned)

* No price, budget, population or military field exists, because no such system exists.
* No per-country diplomacy or relations sections exist. They will be added as versioned
  sections, not as new top-level fields.
* Only one backup generation is kept. A rolling history is *planned*.
* Cloud sync, accounts and cross-device transfer are **not planned**: the game is offline-first
  by design.
