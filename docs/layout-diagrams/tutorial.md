# Tutorial (the in-game guide) — layout diagrams

A **diagram**, not a screenshot: the rectangles below are what
`tests/suites/test_tutorial.gd` measures on the real scene at each size, in both themes.

The tutorial is a modal over the running campaign: `src/ui/components/tutorial_panel.gd`,
built by `_build_guide()` in `src/ui/screens/game_screen.gd`, opened on the first campaign
and again from the pause menu (**Show the guide again**). It is `PanelCard` at 360 px
minimum width, centred inside the dimmed overlay, so the campaign stays visible behind it and
the clock stays stopped while it is open.

## 1280×720 — one step (identical structure at every size)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ dimmed campaign (ColorRect 45% black, full rect)                             │
│                        ┌───────────────────────────────────┐                 │
│                        │ PanelCard, 360 wide               │                 │
│                        │ ┌───────────────────────────────┐ │                 │
│                        │ │ Eyebrow  "GETTING STARTED"    │ │                 │
│                        │ │ Caption  "Step 3 of 6"        │ │                 │
│                        │ │ Subheading "The map"          │ │                 │
│                        │ │ BodySmall  the step's words,  │ │                 │
│                        │ │   word-wrapped, five or six   │ │                 │
│                        │ │   lines                       │ │                 │
│                        │ ├───────────────────────────────┤ │                 │
│                        │ │ [Skip]              [Next]    │ │  both 48 high   │
│                        │ └───────────────────────────────┘ │                 │
│                        └───────────────────────────────────┘                 │
└──────────────────────────────────────────────────────────────────────────────┘
```

The last press on **Next** shows the closing card instead of a seventh step: the title
becomes **Tutorial complete**, the body the reward sentence (`You earned 100 XP, 100 Gold
Coins and 25 Red Gems.`), the counter the word *Finish*, **Skip** disappears and **Next**
becomes **Close**. A profile that already claimed the reward gets the "already paid" sentence
and no second payment.

## 640×360 and portrait (390×844)

The same centred panel; the body word-wraps to more lines, the panel grows downwards and stays
inside the window at both sizes — `test_the_tutorial_fits_every_size_in_both_themes` asserts
the panel's rect is inside the viewport and both buttons stay at `DesignTokens.CONTROL_HEIGHT`.

## What the tests assert

- every step names a feature that exists, and that feature's control is on the mounted game
  screen (`test_every_step_teaches_a_feature_that_exists`,
  `test_every_anchor_is_really_on_the_game_screen`) — a step about a screen that does not
  exist cannot pass;
- no sentence mentions a system the project has not built unless the same sentence says it is
  absent (`test_no_step_mentions_a_feature_that_does_not_exist`);
- the words come from the string table, not from the step file
  (`test_every_step_comes_from_the_string_table`);
- finishing pays 100 XP, 100 Gold Coins and 25 Red Gems exactly once per profile, and the
  claim is on disk (`test_finishing_pays_the_reward_once_per_profile`);
- skipping pays nothing and records the skip (`test_skipping_pays_nothing_and_still_marks_the_profile`);
- the pause menu reopens it (`test_the_pause_menu_opens_the_tutorial_again`).
