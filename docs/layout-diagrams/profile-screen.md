# Profile screen — layout diagrams

These are **diagrams**, not screenshots: each box is a rectangle the headless tests measure
and assert at that size, in both themes. The theme changes colours only, so one diagram per
size is drawn and the palette is noted beside it.

The screen is `src/ui/screens/profile/profile_screen.tscn` with
`src/ui/screens/profile/profile_screen.gd`. It is reachable from the main menu (**Profile**)
and from the pause menu (**Profile**).

## 1280×720 — Midnight and Parchment (identical structure)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ SafeArea (screen margin 32 at this size)                                     │
│ ┌──────────────────────────────────────────────────────────────────────────┐ │
│ │ Scroll (vertical — the column scrolls on a short window)                 │ │
│ │  ┌───────────────────────────────────────────┬─────────────────────────┐ │ │
│ │  │ Content 560 wide                          │ Spacer (expands)        │ │ │
│ │  │ ┌───────────────────────────────────────┐ │                         │ │ │
│ │  │ │ HBox "Identity"                       │ │                         │ │ │
│ │  │ │  ┌──────┐  ScreenTitleCompact "Nadia" │ │                         │ │ │
│ │  │ │  │avatar│  Mono "@nadia_7"            │ │                         │ │ │
│ │  │ │  │ 96px │  Caption "Player ID: …"     │ │                         │ │ │
│ │  │ │  └──────┘                             │ │                         │ │ │
│ │  │ ├───────────────────────────────────────┤ │                         │ │ │
│ │  │ │ FieldLabel "Level 4"                  │ │                         │ │ │
│ │  │ │ ProgressBar "XPBar"  ── the fill is   │ │                         │ │ │
│ │  │ │ the XP earned inside this level       │ │                         │ │ │
│ │  │ │ Caption "150 / 250 XP to level 5"     │ │                         │ │ │
│ │  │ │ Mono    "VIP 0"                       │ │                         │ │ │
│ │  │ │ BodySmall "Gold Coins: 1200"          │ │                         │ │ │
│ │  │ │ BodySmall "Red Gems: 150"             │ │                         │ │ │
│ │  │ ├───────────────────────────────────────┤ │                         │ │ │
│ │  │ │ FieldLabel "Choose an avatar"         │ │                         │ │ │
│ │  │ │ Grid 5 × 4, each cell 80 × 80:        │ │                         │ │ │
│ │  │ │ ┌────┬────┬────┬────┬────┐            │ │                         │ │ │
│ │  │ │ │ 1  │ 2  │ 3  │ 4  │ 5  │  drawing   │ │                         │ │ │
│ │  │ │ │Sun │Har │Ced │Com │Lan │  + name    │ │                         │ │ │
│ │  │ │ ├────┼────┼────┼────┼────┤            │ │                         │ │ │
│ │  │ │ │ …  │    │    │    │    │  selected: │ │                         │ │ │
│ │  │ │ │    │    │    │    │    │  tick "✓"  │ │                         │ │ │
│ │  │ │ └────┴────┴────┴────┴────┘  + 2px     │ │                         │ │ │
│ │  │ │ Body  help: drawn in code, no link,   │ │                         │ │ │
│ │  │ │       no upload                       │ │                         │ │ │
│ │  │ ├───────────────────────────────────────┤ │                         │ │ │
│ │  │ │ [Change display name]                 │ │                         │ │ │
│ │  │ │ Body "This change costs 100 Red Gems. │ │                         │ │ │
│ │  │ │       You have 150."                  │ │                         │ │ │
│ │  │ ├───────────────────────────────────────┤ │                         │ │ │
│ │  │ │ FieldLabel "Username" (+ warning, or  │ │                         │ │ │
│ │  │ │ the "set once" paragraph when locked) │ │                         │ │ │
│ │  │ │ [LineEdit] [Set username]             │ │                         │ │ │
│ │  │ ├───────────────────────────────────────┤ │                         │ │ │
│ │  │ │ Body  "Importing your own picture is  │ │                         │ │ │
│ │  │ │        PLANNED. …"                    │ │                         │ │ │
│ │  │ │ Body  "Achievements are PLANNED."     │ │                         │ │ │
│ │  │ ├───────────────────────────────────────┤ │                         │ │ │
│ │  │ │ [Back to the menu]                    │ │                         │ │ │
│ │  │ │ Caption status line (last action)     │ │                         │ │ │
│ │  │ └───────────────────────────────────────┘ │                         │ │ │
│ │  └───────────────────────────────────────────┴─────────────────────────┘ │ │
│ └──────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

Both the rename dialog and every button are `DesignTokens.CONTROL_HEIGHT` (48) tall. The
rename dialog is a `PanelCard` added to the same content column while it is open; it shows
the price and the balance, then **Confirm** and **Cancel**. Confirm is disabled when the
balance cannot meet the price — the test presses a forced rename anyway and proves nothing
is spent.

## 640×360 — the short window

```
┌────────────────────────────────────────────┐
│ SafeArea margin 16                         │
│ ┌────────────────────────────────────────┐ │
│ │ Scroll — the whole column scrolls here │ │
│ │ ┌────────────────────────────────────┐ │ │
│ │ │ Content 560 wide (min):            │ │ │
│ │ │ identity, XP, 20 avatars in a      │ │ │
│ │ │ 5 × 4 grid, rename, username,      │ │ │
│ │ │ the PLANNED lines, Back            │ │ │
│ │ └────────────────────────────────────┘ │ │
│ └────────────────────────────────────────┘ │
└────────────────────────────────────────────┘
```

As on the first-run screen, the column keeps a readable measure and scrolls rather than
squeezing sentences into 300 px. Nothing is clipped without the scroll container offering a
way to reach it; the tests assert the header avatar and every avatar cell stay at least 48 px
in both directions at this size.

## 1920×1080 — the desktop window

The same 560 px column, left-aligned against a wider spacer. The avatar grid does not stretch
to the window; a large monitor does not produce 200-character lines or 200 px avatars.

## Portrait (390×844, 360×800)

The same column, vertically scrolled. The grid stays 5 columns because its minimum width
(5 × 80 + 4 × 8 = 432) is inside the 560 px column, and the column scrolls horizontally
inside the disabled-horizontal `ScrollContainer` exactly as the first-run screen does. These
sizes are asserted for the same properties: 48 px targets, a finger-sized header avatar, a
full-height Back button.

## What the tests assert at each size and theme

`tests/suites/test_profile_screen.gd`:

- the screen fills the view exactly (`test_the_screen_fits_every_reference_size_in_both_themes`,
  both `midnight` and `parchment`, five sizes);
- every avatar cell is at least 48 × 48 and carries its name; the header drawing is at least
  48 px (`test_every_gallery_cell_carries_a_drawing_and_its_name`);
- every number on the screen equals the profile file's number — level, XP into the level,
  XP span, wallet balances and VIP (`test_the_screen_shows_the_players_own_numbers`,
  `test_a_different_profile_gives_different_numbers`);
- every button takes keyboard focus and activating a cell chooses that avatar
  (`test_every_action_is_reachable_from_a_keyboard`);
- choosing an avatar marks the cell with a tick as well as a border, updates the header and
  survives a reload from disk (`test_choosing_avatars_saves_the_choice_and_marks_the_cell`).

Real-device rendering and real-device speed at these sizes are **UNVERIFIED**: there is no
Godot binary and no device in the build environment. The owner's manual pass is in
`docs/MANUAL_TEST_CHECKLIST.md`.
