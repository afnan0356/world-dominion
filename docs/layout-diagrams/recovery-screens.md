# Worlds, backup and the recovery dialog — layout diagrams

**Diagrams**, not screenshots: the boxes are the rectangles
`tests/suites/test_recovery_screens.gd` measures at each size, in both themes.

Two screens, both built on `ResponsiveScreen` with the same scrolling column as the profile
screen: `src/ui/screens/worlds/worlds_screen.tscn` (**Your worlds**) and
`src/ui/screens/backup/backup_screen.tscn` (**Backup and restore**). Both are reached from
**Load game** (`WorldsEntry`, `BackupEntry`), which is where a player looking for their saves
already goes.

## Your worlds — 1280×720 (the 640×360 and portrait layouts scroll the same column)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ SafeArea                                                                     │
│  ┌───────────────────────────────────────────┬───────────────────────────┐   │
│  │ Content 560 wide                          │ Spacer (expands)          │   │
│  │ ScreenTitleCompact "Your worlds"          │                           │   │
│  │ Body "Every world saved on this device…"  │                           │   │
│  │ Row 1: [Slot 1 — Bangladesh, 1 Jan 2026]  │ 48 high, expands          │   │
│  │        …and beside it [Delete]            │ 96 × 48                   │   │
│  │   ┌ Confirmation (only after Delete) ───┐ │                           │   │
│  │   │ FieldLabel "Delete Slot 1?"         │ │                           │   │
│  │   │ Body "Bangladesh · 1 January 2026 ·  │ │                           │   │
│  │   │   played 1 h 02 min"                │ │                           │   │
│  │   │ Caption "A recovery copy is made    │ │                           │   │
│  │   │   first, so you can undo this…"     │ │                           │   │
│  │   │ [Delete this world] 48 [Keep it] 48 │ │                           │   │
│  │   └─────────────────────────────────────┘ │                           │   │
│  │ Row 2: [Slot 2 — this file cannot be read]│ 48 high                   │   │
│  │ Row 3: [Autosave — empty] (disabled)      │ 48 high                   │   │
│  │ HBox: Caption status ……… [Undo] 48        │                           │   │
│  │ [Back]                                    │ 48 high                   │   │
│  │ ┌ IntegrityDialog (only when damaged) ──┐ │                           │   │
│  │ │ Subheading "A saved file cannot be    │ │                           │   │
│  │ │   read"                               │ │                           │   │
│  │ │ BodySmall — the engine's own reasons  │ │                           │   │
│  │ │ [Use the backup]           48 high    │ │                           │   │
│  │ │ [Continue with a warning]  48 high    │ │                           │   │
│  │ │ [Cancel]                   48 high    │ │                           │   │
│  │ └───────────────────────────────────────┘ │                           │   │
│  └───────────────────────────────────────────┴───────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────┘
```

**Use the backup** is disabled — with the reason in its tooltip — when no previous copy
exists, so the dialog never offers an answer it cannot carry out.

**Delete** opens the confirmation shown above, never a bare "are you sure?". It names the slot,
the country, the in-game date and the playtime read from the save, and it states whether a
recovery copy can be made *before* the player agrees. Confirming copies the slot's files into
`user://saves/deleted/`, then deletes that slot only; **Undo** appears in the status row and
works until the game closes. Where no copy can be made the confirmation says the deletion is
permanent, and the status afterwards says the same. The profile is a different file in a
different store and is never touched.

The same dialog appears on the **profile screen** when the profile file cannot be read (it
loads with the backup *not* taken automatically), and on **Backup and restore** when a restore
would replace a world or when the chosen file's seal has failed.

## Backup and restore — 1280×720

```
┌──────────────────────────────────────────────────────────────────────────────┐
│  Content 560 wide                                                            │
│  ScreenTitleCompact "Backup and restore"                                     │
│  Body "A backup is one plain file holding your profile and every world…"     │
│  [Create a backup now]                                 48 high               │
│  Caption "Backups are kept in the game's own backup folder… PLANNED …"       │
│  Backups                                                                     │
│   [2026-11-07 10-00-00 · Keeper · level 3 · 2 world(s)]  48 high             │
│   [backup-2026-11-06.json — cannot be read]              48 high             │
│  Caption status ("Restored: 1. Reasons: …")                                  │
│  [Back]                                                                      │
└──────────────────────────────────────────────────────────────────────────────┘
```

## What the tests assert

- the dialog offers exactly three answers, each a full-height control, and a disabled backup
  answer cannot be chosen (`test_the_dialog_offers_exactly_three_choices`);
- **profile path**: backup / continue / cancel each do exactly what they say, and the damaged
  file is byte-identical afterwards (`test_a_damaged_profile_asks_before_using_the_backup`,
  `test_continuing_with_a_damaged_profile_changes_no_file`,
  `test_cancelling_a_damaged_profile_leaves_the_screen`);
- **world path**: the same three, plus a readable world opening with no question at all;
- **restore path**: a restore that would replace a world asks first; "use the backup" keeps
  the device's copies; "continue" writes the bundle's text byte for byte; "cancel" writes
  nothing;
- a backup made by the screen inspects as a sound bundle and holds the profile and its worlds;
- both screens fill the view at 640×360, 1280×720, 1920×1080 and 390×844 in both themes.

## What is UNVERIFIED about platform file dialogs

The game's backup folder (`user://backups`) is used deliberately: it is reachable with any
file manager on every platform, and it needs no OS integration. Choosing an arbitrary folder
or opening a specific file through each platform's own file dialog is **PLANNED and
UNVERIFIED**:

- Godot 4.6's `FileDialog` was **not** run on Android, iOS, Windows, macOS or Linux here, and
  no device was available to try it on;
- the `Android` scoped-storage behaviour and iOS document picker have not been tested by this
  project at all;
- therefore nothing in the interface offers a file picker, and the screen says so in words
  rather than implying one exists.

Importing a save file already uses a text path typed by the player (see the load screen);
that is the only file-choice mechanism in this build, and it is likewise untested on a device.
