# Help and Roadmap — layout diagrams

These are **diagrams**, not screenshots: they show the rectangles the headless layout test
measures at each reference size, in both themes. Colours change with the theme; structure does
not.

Screens: `src/ui/screens/help/help_screen.tscn` and `src/ui/screens/roadmap/roadmap_screen.tscn`.
Content tables: `src/ui/screens/help/help_sections.gd` and
`src/ui/screens/roadmap/roadmap_items.gd`.

Both are the same shape — a compact-capable header, one scrolling reading column at most 720 px
wide, and cards — so one diagram covers both.

## 1280×720

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ SafeArea                                                                     │
│ ┌──────────────────────────────────────────────────────────────────────────┐ │
│ │ Header — [Back] · Help / Roadmap 48 high                                 │ │
│ │          subtitle · MILESTONE 09                                         │ │
│ ├──────────────────────────────────────────────────────────────────────────┤ │
│ │ Scroll (vertical, page scrolls — cards never scroll on their own)         │ │
│ │  Content — 720 px measure, 24 px apart                                    │ │
│ │  ┌────────────────────────────────────────────────────────────────────┐  │ │
│ │  │ intro (Body, wrapped)                                              │  │ │
│ │  │                                                                    │  │ │
│ │  │ SECTION HEADING (SectionHeading)                                    │  │ │
│ │  │ ┌ PanelCard ─────────────────────────────────────────────────────┐ │  │ │
│ │  │ │ body text (wrapped)                                            │ │  │ │
│ │  │ │ [Your worlds] 48  [Backup and restore] 48   ← Help only        │ │  │ │
│ │  │ └────────────────────────────────────────────────────────────────┘ │  │ │
│ │  │ SECTION HEADING                                                    │  │ │
│ │  │ ┌ PanelCard ─────────────────────────────────────────────────────┐ │  │ │
│ │  │ │ Roadmap item: title ………………………………………… [ PLANNED ]        │ │  │ │
│ │  │ │ body text (wrapped)                                            │ │  │ │
│ │  │ │ docs/GAME_VISION.md · "the sentence the item comes from"       │ │  │ │
│ │  │ └────────────────────────────────────────────────────────────────┘ │  │ │
│ │  └────────────────────────────────────────────────────────────────────┘  │ │
│ └──────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

Help has six sections (what this is, what you can do, saving and backups, why there is no
account, the notification choice, if something goes wrong). Roadmap has an intro, an "In this
build" card, then eight item cards.

## 640×360 — the short window

```
┌──────────────────────────────────────┐
│ Header compact: [Back] Help          │  one 40 px row
├──────────────────────────────────────┤
│ Scroll ..............................│  the whole page scrolls
│  intro                               │
│  SECTION HEADING                     │
│  ┌────────────────────────────────┐  │
│  │ body                           │  │
│  │ [Your worlds] 48               │  │   buttons wrap onto their own rows
│  │ [Backup and restore] 48        │  │
│  └────────────────────────────────┘  │
│  …                                   │
└──────────────────────────────────────┘
```

Measured by `tests/suites/test_help_roadmap.gd` at 640×360, 844×390, 1280×720, 1920×1080 and
390×844 in both themes: the screen fills the viewport, every link button keeps at least 40 px
(48 px above 460 px of height), and no label shows a missing string key.

## Motion

There is none. Roadmap builds no tween and adds no `AnimationPlayer`, so the reduced-motion
setting changes nothing there — asserted by counting processed tweens before and after mounting
the screen, and by comparing the page's item titles with motion set to Full and to Reduced.
