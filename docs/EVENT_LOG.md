# The event log, Messages and News

**Status: implemented in Milestone 10.** This page documents what is stored, what is shown,
what is deliberately absent, and the one schema migration the feature needed.

## 1. What an event is

One thing that **actually happened** in a campaign, recorded at the moment it happened. Not a
notification, not a headline, not a reminder. An event is written by the system that did the
thing, with the values it used:

| Field | Type | Why it is stored this way |
| --- | --- | --- |
| `id` | `evt-000123` | Monotonic and never reused, so read state stays attached to the right entry even after the oldest are trimmed |
| `day_index` | integer | The in-game day, as `GameClock` counts it. Sorting and history do not depend on a formatted string |
| `date_label` | text | The date as the clock worded it *then*, so an entry read a year later still reads correctly |
| `category` | closed list | `campaign`, `economy`, `government`, `diplomacy`, `military`, `research`, `world`, `system` — the same words as the shell's category bar |
| `severity` | `info`, `notice`, `warning` | How loudly it reads |
| `key` | string-table key | The sentence lives in `src/ui/strings.gd`, never in the save. Wording can improve without touching saved games |
| `params` | named values | Strings and whole numbers only; anything else is refused at load |
| `origin` | dotted name | Which system raised it (`save.autosave`, `campaign.start`), which is the answer to *why am I seeing this?* |
| `read` | boolean | Whether the player has confirmed it in the Messages panel |

An entry whose string key no longer exists is **kept**, shown as "this entry cannot be read in
this version" with the missing key named, and reported in the load issues. History is not
silently deleted because a sentence was renamed.

## 2. What is recorded today

| Event | Raised by | Key |
| --- | --- | --- |
| A campaign began | `GameSession.start_new` | `events.campaign.started` |
| A campaign was resumed from a save | `GameSession.resume` | `events.campaign.loaded` |
| The month-boundary autosave was written | `GameSession.autosave` | `events.save.autosave` |
| The player saved to a slot | `GameSession.save_to` | `events.save.manual` |
| The baseline data a save recorded is not the data this build ships | `GameSession._verify_baseline` via `BaselineIntegritySystem` | `events.world.baseline_changed` |

That is the whole list, and it is short **on purpose**. The build's simulation is the calendar,
the save system and one integrity check; there is nothing else that could honestly raise an
event. The last entry is the only one that describes something going *wrong* rather than
something happening: it is raised at most once per load, and only when the shipped dataset has
changed since the campaign was saved. No
sample data, no "welcome" entry and no seeded history exists: a brand-new campaign has exactly
one entry, the one that says it began.

Adding an event later means calling `GameSession.record_event()` from the system that did the
thing. There is no second path into the log.

## 3. Limits

* **`EventLog.MAX_EVENTS = 200`.** The log keeps the newest 200 and drops the oldest first, so
  the recent past is what survives.
* **`LOAD_CEILING = 2000`.** A file claiming more entries than that is refused rather than
  trusted; it is not a log this build wrote.
* The worst case is roughly 60 kB of save data at the cap; a save is still kilobytes.
* Trimming happens when an event is added, never on load, so loading a save cannot change it.

The ids come from a stored counter. On load the counter is pushed past the highest id actually
present, so a file with a damaged counter cannot make the next event collide with an old one.

## 4. Read state

`unread_count()` is **derived** by counting unread entries; it is never stored on its own. A
stale badge would be one more thing to go wrong, and a count that disagrees with the list is
the kind of defect players report as "the number is lying".

Opening the Messages panel does **not** mark anything read — a glance is not a read.
Confirming a row, or pressing *Mark all read*, does. The badge on the shell's left rail
updates immediately, because it reads the same derived count.

## 5. The schema migration (3 → 4)

The log lives inside the world state, under `world.events`:

```json
"events": {
  "next_sequence": 3,
  "entries": [ { "id": "evt-000001", "day_index": 1, "…": "…" } ]
}
```

* The **save file** schema moved from 3 to 4 (`SaveFile.SCHEMA_VERSION`).
* `SaveMigrations._v3_to_v4()` adds `"events": {"next_sequence": 1, "entries": []}` to a
  schema 3 world and then **recomputes the state hash**, so the migrated file is verifiable
  from scratch — a migration cannot launder a damaged file.
* The old-save fixture is `tests/fixtures/save_schema1_frozen.json`, which predates the log
  entirely. It is loaded, migrated 1 → 2 → 3 → 4 and asserted to produce an **empty** log.
  Reconstructing history would mean inventing it; an empty list is the truthful result.
* **The state hash deliberately excludes the log.** The log is a record of actions the hash
  already covers, and read state is a view preference, not campaign state. The file's own
  checksum still covers the log, so an edited log is still detected as damage.

## 6. What the interface shows

**Messages** (`src/ui/hud/messages_panel.gd`) — newest first, with a search box, category
chips that only offer categories that actually occur, an unread-only toggle, *Mark all read*,
and two different empty states: *nothing has happened yet* is not the same sentence as
*nothing matches what you typed*. Confirming a row prints the event's own origin line under it.

**News** (`src/ui/hud/news_panel.gd`) — a quiet newspaper page: masthead, one column, hairline
rules, one article per event, newest first, each credited to the system that recorded it. It
generates no prose, predicts nothing and has no "analyst expects" sentence anywhere in it. With
an empty log it prints a page that says the edition has nothing to report.

**The shell's rails** — Messages shows the derived unread count, News shows the newest entry's
date (or "No news yet").

## 7. What is deliberately not here

* No notifications, no banners, no sounds of their own. The settings screen's notification
  preference governs in-game banners only; no operating-system notification is ever requested.
* No filtering by severity in the interface yet (the data supports it; the panel does not offer
  a control it cannot justify).
* No summarising, no auto-generated sentences, no "you may also be interested in" — every
  line in both screens is an event that was recorded.
