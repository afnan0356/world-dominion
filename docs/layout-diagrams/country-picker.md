# Country picker — layout diagrams

These are **diagrams**, not screenshots: they show the rectangles the headless tests measure
at each reference size, in both themes. Colours change with the theme; structure does not.

The picker lives on the **campaign setup** screen: `src/ui/components/country_picker_panel.gd`
(right-hand side panel), `src/ui/components/flag_strip.gd` (bottom of the map column), wired
in `src/ui/screens/campaign_setup.gd` by `_build_picker()`.

## 1280×720 — the wide layout

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ Header: back · "Campaign setup"                          [scenario section]   │
├──────────────────────────────────────────────────────────────────────────────┤
│ Body (HBox)                                                                  │
│ ┌───────────────────────────────────────────┐ ┌──────────────────────────┐   │
│ │ MapColumn                                 │ │ SidePanel, 340 wide       │   │
│ │ ┌───────────────────────────────────────┐ │ │ ┌──────────────────────┐ │   │
│ │ │ Search + recent-strip (HFlow)         │ │ │ │ Picker               │ │   │
│ │ │ RegionFilter chips                    │ │ │ │ SectionHeading       │ │   │
│ │ ├───────────────────────────────────────┤ │ │ │  "Choose your nation"│ │   │
│ │ │ MapFrame                              │ │ │ ├──────────────────────┤ │   │
│ │ │   WorldMapView — pan, zoom, tap       │ │ │ │ OptionButton         │ │   │
│ │ │   (fully usable; the picker never     │ │ │ │  "17 committed       │ │   │
│ │ │    covers it)                         │ │ │ │   groups"  48 high   │ │   │
│ │ │                                       │ │ │ ├──────────────────────┤ │   │
│ │ │                                       │ │ │ │ LineEdit  search by  │ │   │
│ │ │                                       │ │ │ │  name, alias, ISO-2, │ │   │
│ │ │                                       │ │ │ │  ISO-3     48 high   │ │   │
│ │ │                                       │ │ │ ├──────────────────────┤ │   │
│ │ │                                       │ │ │ │ JumpIndex HFlow      │ } │   │
│ │ │                                       │ │ │ │  [A][B][C]…[Z]       │ } │   │
│ │ │                                       │ │ │ ├──────────────────────┤ │   │
│ │ │                                       │ │ │ │ ListScroll (220 min) │ │   │
│ │ │                                       │ │ │ │  one letter of one   │ │   │
│ │ │                                       │ │ │ │  group, one row per  │ │   │
│ │ │                                       │ │ │ │  record: flag/badge, │ │   │
│ │ │                                       │ │ │ │  name, code, group   │ │   │
│ │ │                                       │ │ │ └──────────────────────┘ │   │
│ │ ├───────────────────────────────────────┤ │ │ Dossier (CountryInfo)    │   │
│ │ │ FlagStrip — ScrollContainer, 6 items   │ │ └──────────────────────────┘   │
│ │ │  per page, tiles 72 × 56, snap        │ │                                │
│ │ │  [🇧🇩][🇦🇫][🇮🇳][🇱🇰][🇳🇵][🇵🇰] …            │ │                                │
│ │ └───────────────────────────────────────┘ │                                │
│ └───────────────────────────────────────────┘                                │
├──────────────────────────────────────────────────────────────────────────────┤
│ Footer: selection title · detail · [Details] [Confirm nation]                │
└──────────────────────────────────────────────────────────────────────────────┘
```

The three views share **one** selection. `select_country()` marks the map, the list and the
strip and flies the camera; a pick in the list or a tap in the strip goes through the same
path, so they cannot drift apart (`test_the_map_the_list_and_the_strip_stay_in_step`).

## 640×360 — the short window

```
┌──────────────────────────────────────┐
│ Header                               │
├──────────────────────────────────────┤
│ NarrowBody (vertical scroll)         │
│ ┌──────────────────────────────────┐ │
│ │ Search / recent strip / regions  │ │
│ │ MapFrame — 72–120 px minimum,    │ │
│ │ 24 or 48 px given up in a short  │ │
│ │ window so the footer stays       │ │
│ │ FlagStrip — compact: 48 × 40     │ │
│ │  tiles, 56 px row                │ │
│ │ SidePanel → Picker (below)       │ │
│ └──────────────────────────────────┘ │
│ Footer                               │
└──────────────────────────────────────┘
```

Below a view height of 380 px the strip switches to its compact form (`set_compact(true)`)
and the map's minimum height drops to 72 px, which is what keeps the footer on screen at
640×360 and at 844×390 (a phone held sideways). This coupling is deliberate; removing either
half makes the SafeArea overflow, which is how it was found.

## 1920×1080 and portrait

At 1920×1080 the same two columns with more map; the side panel keeps its 340 px width and
the list keeps a readable row height. In portrait (390×844, 360×800) the layout uses
`NarrowBody`: everything stacks and scrolls, the strip stays compact and 48 px tall per tile.

## What the tests assert

`tests/suites/test_country_picker.gd`:

- the seventeen groups come from `data/world/picker_regions.json`, exactly one per record,
  and every record appears in a group;
- the list shows one letter of one group at a time, and the A–Z index moves to that letter;
- search matches a name, an alias, an alpha-2 and an alpha-3 code;
- the five flagless records (`ATC`, `IOA`, `CYN`, `KAS`, `SOL`) show the neutral code badge,
  never a neighbour's flag;
- the map, the list and the strip are in step in both directions, and selection is marked
  without relying on colour (tick + weight, plus a name in the tile's tooltip);
- the setup screen fits 640×360, 1280×720, 1920×1080, 844×390, 390×844 and 360×800 in both
  themes;
- scrolling the list repeatedly leaves no accumulating nodes or textures.
