# First-run screen — layout diagrams

These are **diagrams**, not screenshots: they are drawn from the measured rectangles the
headless tests assert, at the three reference sizes the milestone requires, in both themes.
The theme changes colours and nothing about the structure, so one diagram per size is shown
with the palette noted.

## 1280×720 — Midnight and Parchment (identical structure)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ SafeArea (screen margin 32 at this size)                                     │
│ ┌──────────────────────────────────────────────────────────────────────────┐ │
│ │ Scroll (vertical)                                                        │ │
│ │  ┌───────────────────────────────────────────┬─────────────────────────┐ │ │
│ │  │ Content 560 wide                          │ Spacer (expands)        │ │ │
│ │  │ ┌───────────────────────────────────────┐ │                         │ │ │
│ │  │ │ ScreenTitle  "Terms and Privacy"      │ │                         │ │ │
│ │  │ ├───────────────────────────────────────┤ │                         │ │ │
│ │  │ │ Mono        "Version 1 — 2026-11-06"  │ │                         │ │ │
│ │  │ ├───────────────────────────────────────┤ │                         │ │ │
│ │  │ │ Body        intro sentence            │ │                         │ │ │
│ │  │ │ FieldLabel  "It works offline"        │ │                         │ │ │
│ │  │ │ Body        offline sentence          │ │                         │ │ │
│ │  │ │ … four more heading/body pairs …      │ │                         │ │ │
│ │  │ ├───────────────────────────────────────┤ │                         │ │ │
│ │  │ │ HBox  [Accept and continue] [Decline…]│ │                         │ │ │
│ │  │ └───────────────────────────────────────┘ │                         │ │ │
│ │  └───────────────────────────────────────────┴─────────────────────────┘ │ │
│ └──────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

Both buttons are `DesignTokens.CONTROL_HEIGHT` tall (48) and focusable with the keyboard.

## 640×360 — the short window

```
┌────────────────────────────────────────────┐
│ SafeArea margin 16                         │
│ ┌────────────────────────────────────────┐ │
│ │ Scroll — the content is taller than    │ │
│ │ the window, so it scrolls here         │ │
│ │ ┌────────────────────────────────────┐ │ │
│ │ │ Content 560 wide (min), scrolls    │ │ │
│ │ │ Title / version / sections /       │ │ │
│ │ │ [Accept] [Decline]                 │ │ │
│ │ └────────────────────────────────────┘ │ │
│ └────────────────────────────────────────┘ │
└────────────────────────────────────────────┘
```

At this size the content column is wider than the window on purpose: it keeps sentences at a
readable measure and lets the player scroll, rather than squeezing them into a 300 px column.
The test asserts the buttons stay at full height and that nothing is clipped *vertically*
without the scroll container offering a way to reach it.

## 1920×1080 — the desktop window

The same column, centred with a wider spacer; nothing stretches past 560 px of text measure,
so a large monitor does not produce 200-character lines.

## The other steps

| Step | Structure |
| --- | --- |
| Loading | Centred title, body, `ProgressBar` (0–1) and a mono line naming the real step |
| Notifications | Title, body, a line labelled PLANNED, and the two choice buttons |
| Profile | Title, body, two labelled `LineEdit`s, the one-time username warning, an avatar **placeholder** panel (replaced in Task 4), a problem line, and Create |

## What the tests assert at each size and theme

- the content column does not exceed the viewport width;
- every button is at least `DesignTokens.CONTROL_HEIGHT` tall
  (`test_the_flow_fits_every_size_in_both_themes`);
- the Accept button is reachable by keyboard focus and activating it advances the flow
  (`test_keyboard_only_can_complete_the_flow`);
- the flow reaches the profile step and saves a profile at every size.
