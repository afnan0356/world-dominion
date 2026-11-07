# Diagnostics — layout diagram

This is a **diagram**, not a screenshot: it shows the rectangles the headless layout test
measures at each reference size, in both themes. Colours change with the theme; structure does
not.

Screen: `src/ui/screens/diagnostics/diagnostics_screen.tscn` (script `…/diagnostics_screen.gd`).
Report and file writing: `src/core/diagnostics/diagnostics_report.gd`; the in-memory log:
`src/core/diagnostics/diagnostics_log.gd`.

## 1280×720 — the wide layout

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ SafeArea (margin 48 / 32 / 16 by layout mode)                               │
│ ┌──────────────────────────────────────────────────────────────────────────┐ │
│ │ Header — [Back] · Diagnostics 48 high                                    │ │
│ │          "What this build is, and the last warnings it reported."        │ │
│ │          MILESTONE 09                                                    │ │
│ ├──────────────────────────────────────────────────────────────────────────┤ │
│ │ Separator                                                                │ │
│ ├──────────────────────────────────────────────────────────────────────────┤ │
│ │ Scroll (one page, vertical)                                              │ │
│ │  Content — 720 px measure, 24 px apart                                   │ │
│ │  ┌────────────────────────────────────────────────────────────────────┐  │ │
│ │  │ intro (Body, wrapped)                                              │  │ │
│ │  │ BUILD (SectionHeading)                                             │  │ │
│ │  │ ┌ PanelCard ─────────────────────────────────────────────────────┐ │  │ │
│ │  │ │ BuildGrid, 2 columns:                                          │ │  │ │
│ │  │ │  Version            v0.x.x                                     │ │  │ │
│ │  │ │  Data version       5.2.0-pre (generated 2026-11-05)           │ │  │ │
│ │  │ │  Engine             Godot 4.6.3.stable.custom_build            │ │  │ │
│ │  │ │  Platform           Desktop · Linux                            │ │  │ │
│ │  │ │  Renderer           Vulkan                                     │ │  │ │
│ │  │ │  Screen             1280 × 720 px at 100% interface scale      │ │  │ │
│ │  │ │  Frame-rate cap     60 frames per second                       │ │  │ │
│ │  │ └────────────────────────────────────────────────────────────────┘ │  │ │
│ │  │ RECENT WARNINGS AND ERRORS (SectionHeading)                        │  │ │
│ │  │ ┌ PanelCard ─────────────────────────────────────────────────────┐ │  │ │
│ │  │ │ caption: "The last N of at most 50 lines…"                     │ │  │ │
│ │  │ │ LogView (RichTextLabel, selection on, grows with its text)     │ │  │ │
│ │  │ │   WARN  The settings file could not be written (error 31).     │ │  │ │
│ │  │ │   ERROR A backup file could not be written.                    │ │  │ │
│ │  │ │ select hint                                                    │ │  │ │
│ │  │ │ [ Export diagnostics ] 48  [ Copy to clipboard ] 48            │ │  │ │
│ │  │ │ Status (appears for 6 s after either action)                   │ │  │ │
│ │  │ └────────────────────────────────────────────────────────────────┘ │  │ │
│ │  │ privacy note (what the file contains and does not)                 │  │ │
│ │  │ folder note (no file dialog verified; PLANNED)                     │  │ │
│ │  └────────────────────────────────────────────────────────────────────┘  │ │
│ └──────────────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────────────┘
```

## 640×360 — the short window

```
┌──────────────────────────────────────┐
│ Header compact: [Back] Diagnostics   │  one 40 px row
├──────────────────────────────────────┤
│ Scroll ..............................│  everything below scrolls
│  intro                               │
│  BUILD                               │
│  ┌────────────────────────────────┐  │
│  │ Version / value … 14 labels    │  │
│  └────────────────────────────────┘  │
│  RECENT WARNINGS AND ERRORS          │
│  ┌────────────────────────────────┐  │
│  │ caption · LogView · buttons    │  │
│  │  (buttons stack at 48 px)      │  │
│  └────────────────────────────────┘  │
│  privacy · folder notes              │
└──────────────────────────────────────┘
```

Measured by `tests/suites/test_diagnostics.gd` at 640×360, 844×390, 1280×720 and 1920×1080 in
both themes: the screen fills the viewport, both action buttons are at least 40 px high (48 px
when the window is taller than 460 px), and no label ever shows a missing string key.

## What the export contains

```
Version / Data version / Engine / Platform / Renderer / Screen / Frame-rate cap
LOG — n of at most 50 lines, oldest first
```

and nothing else: no name, username, player ID, avatar, wallet, save contents or folder path
beyond the game's own folder name. `DiagnosticsReport.scrub()` reduces every token that looks
like a path to its last component, and the report is built without reading the profile at all.
