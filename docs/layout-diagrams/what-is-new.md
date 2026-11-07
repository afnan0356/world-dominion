# What is new — layout diagram

A **diagram**, not a screenshot: it shows the rectangles the layout code produces, in the
design system's own terms. Colours change with the theme; structure does not.

Screens: `src/ui/screens/whats_new/whats_new_screen.tscn`. Content table:
`src/ui/screens/whats_new/whats_new_items.gd`. The screen is a `ResponsiveScreen`, like Help and
the Roadmap, so it is the same shape: a compact-capable header, one scrolling reading column at
most 720 px wide, and cards.

## 1280×720

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ SafeArea — margins from DesignTokens.screen_margin(EXPANDED)                  │
│ ┌──────────────────────────────────────────────────────────────────────────┐ │
│ │ Header — [Back] · What is new 48 high                                    │ │
│ │          "What changed in this build, and what did not." · VERSION 0.2.0  │ │
│ ├──────────────────────────────────────────────────────────────────────────┤ │
│ │ Scroll (vertical; the page scrolls, cards never do)                       │ │
│ │  Content — 720 px measure, 24 px apart                                    │ │
│ │  ┌────────────────────────────────────────────────────────────────────┐  │ │
│ │  │ intro (Body, wrapped): "every line names the file that makes it     │  │ │
│ │  │ true …"                                                            │  │ │
│ │  │                                                                    │  │ │
│ │  │ Milestone 11 — the foundation pass          (SectionHeading)        │  │ │
│ │  │ ┌ PanelCard ─────────────────────────────────────────────────────┐ │  │ │
│ │  │ │ Real icons, in the player's palette         (FieldLabel)       │ │  │ │
│ │  │ │ body text (wrapped)                                            │ │  │ │
│ │  │ │ data/ui/icon_sources.json · src/ui/icons/…      (Caption)      │ │  │ │
│ │  │ └────────────────────────────────────────────────────────────────┘ │  │ │
│ │  │ ┌ PanelCard ─────────────────────────────────────────────────────┐ │  │ │
│ │  │ │ A list of every feature …   body …   docs/FEATURE_INVENTORY.md │ │  │ │
│ │  │ └────────────────────────────────────────────────────────────────┘ │  │ │
│ │  │ … one card per entry in WhatsNewItems.RELEASES …                  │  │ │
│ │  │                                                                    │  │ │
│ │  │ Not in this build                           (SectionHeading)        │  │ │
│ │  │ ┌ PanelCard ─────────────────────────────────────────────────────┐ │  │ │
│ │  │ │ no economy, no politics, no diplomacy …                        │ │  │ │
│ │  │ │ docs/DATA_CANDIDATES.md · docs/FEATURE_INVENTORY.md            │ │  │ │
│ │  │ └────────────────────────────────────────────────────────────────┘ │  │ │
│ │  └────────────────────────────────────────────────────────────────────┘  │ │
│ └──────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

## 640×360

```
┌────────────────────────────────────────┐
│ SafeArea — 12 px vertical margins      │
│ ┌────────────────────────────────────┐ │
│ │ [Back] What is new   ← compact     │ │
│ │ VERSION 0.2.0                      │ │
│ ├────────────────────────────────────┤ │
│ │ Scroll ↓                           │ │
│ │  Content — 584 px measure, wraps   │ │
│ │  ┌──────────────────────────────┐  │ │
│ │  │ title (wrapped to 2 lines)    │  │ │
│ │  │ body (wrapped, 4–6 lines)     │  │ │
│ │  │ data/ui/icon_sources.json ·   │  │ │
│ │  │ src/ui/icons/icon_atlas.gd    │  │ │
│ │  └──────────────────────────────┘  │ │
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

The reading column narrows to the window instead of overflowing it: `ResponsiveScreen` applies
its layout once on `_ready` and again on the next idle frame, because a subclass builds its
column *after* `super()`. Without the second pass the scene's own 720 px minimum wins and every
label runs about 40 px off the right edge. `tests/suites/test_whats_new.gd` mounts the screen at
this size and checks that no label's rectangle ends past the window.

The same suite opens a `ModalPanel` with a body taller than the window and checks that the panel
caps itself to the viewport and that its **Close** button is still on screen — the panel is
content-sized and centred, which is right on a desktop and wrong here.
