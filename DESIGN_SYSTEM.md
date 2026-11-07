# WORLD DOMINION — Design System

This document describes the visual language established in Milestone 01. Every future milestone is
expected to extend it rather than invent a parallel one.

The system is defined in four files and one test suite:

| File | Owns |
| --- | --- |
| `src/ui/theme/design_tokens.gd` | Spacing, type ramp, radii, borders, motion, component metrics, breakpoints |
| `src/ui/theme/palette.gd` | `Midnight` and `Parchment` palettes + the contrast pairs that must hold |
| `src/ui/theme/typography.gd` | Font files, weights, letter-spacing |
| `src/ui/theme/theme_factory.gd` | Turns tokens + palette into the runtime `Theme` with named variations |
| `tests/suites/test_design_system.gd` | Fails the build if contrast, ordering or variation completeness regress |

## 1. Character

**Editorial cartography, not a dashboard.** The reference points are printed atlases, diplomatic
dossiers and modern institutional typography: strong serif headlines, quiet sans interface text,
hairline rules, generous margins, a single brass accent, and a hint of a world that is not drawn yet.

Deliberately avoided: gradients as decoration, glass/blur panels, purple-blue “tech” palettes, large
corner radii, drop shadows on every surface, icon soup, fake data widgets, and anything that reads as
a generic admin template.

## 2. Colour

Two palettes. **Midnight (dark) is the default**: long sessions, dark rooms, and a future map that
must dominate the screen. **Parchment (light)** is a warm paper surface for daylight play.

### Midnight

| Token | Hex | Used for |
| --- | --- | --- |
| `bg_base` | `#0C1216` | Window background, transition overlay |
| `bg_surface` | `#131C22` | Secondary surfaces, quiet panels |
| `bg_panel` | `#16212A` | Cards and content panels |
| `bg_hover` | `#1B2833` | Hover state of rows and buttons |
| `bg_selected` | `#21303B` | Pressed/selected state |
| `border` | `#253239` | Hairlines |
| `border_strong` | `#33454F` | Emphasised separators, scrollbar grabber |
| `text_primary` | `#E9EEF2` | Titles and primary text |
| `text_secondary` | `#A3B2BD` | Body copy |
| `text_tertiary` | `#84939D` | Captions, metadata |
| `text_disabled` | `#5A6B75` | Disabled entries (not contrast-guaranteed by design) |
| `accent` | `#D8A54A` | Brass: eyebrows, accent bar, focus ring, selection |
| `accent_strong` | `#E8B961` | Accent hover |
| `on_accent` | `#12181C` | Text on an accent fill |
| `positive` / `negative` / `info` | `#84AE8F` / `#D08A73` / `#88A9C9` | Semantic states |
| `backdrop_grid` | `#2E3F49` | Procedural chart rings |
| `backdrop_glow` | `#070B0E` | Vignette tint |
| `map_water` | `#070D11` | Sea on the atlas |
| `map_land` | `#2C3A44` | Unselected land |
| `map_land_hover` | `#35474F` | Land under the pointer |
| `map_selected` | `#6B5427` | Selected nation fill |
| `map_border` | `#465C68` | Country outlines |
| `map_border_selected` | `#D8A54A` | Outline of the selected nation |
| `map_label` | `#A3B2BD` | Country name labels |
| `map_graticule` | `#17242C` | 15° graticule lines |
| `map_water_deep` | `#040A0D` | The poles of the sea gradient |
| `map_coast` | `#5B7482` | Coastline stroke (heavier than a land border) |
| `map_region_0…5` | `#2A3741` `#303F49` `#364650` `#2C3943` `#33424C` `#394A54` | Region tints, ordered by lightness |
| `map_ineligible` | `#7C8B95` | The dash on a record a campaign cannot start as |

### Parchment

| Token | Hex | Used for |
| --- | --- | --- |
| `bg_base` | `#F2EFE8` | Window background (warm paper) |
| `bg_surface` | `#FAF8F3` | Secondary surfaces |
| `bg_panel` | `#FFFDF8` | Cards and content panels |
| `bg_hover` | `#E9E3D6` | Hover state |
| `bg_selected` | `#DFD6C3` | Pressed/selected state |
| `border` | `#DCD4C4` | Hairlines |
| `border_strong` | `#BFB49E` | Emphasised separators |
| `text_primary` | `#1B2226` | Titles and primary text |
| `text_secondary` | `#414E57` | Body copy |
| `text_tertiary` | `#556068` | Captions, metadata |
| `text_disabled` | `#9AA2A6` | Disabled entries |
| `accent` | `#7E5C13` | Brass, darkened for contrast on paper |
| `accent_strong` | `#6B4D10` | Accent hover |
| `on_accent` | `#FBF7EE` | Text on an accent fill |
| `positive` / `negative` / `info` | `#3F6B4E` / `#96432C` / `#2F5A7E` | Semantic states |

Map colours for the Parchment palette follow the same roles: `map_water` `#A0BCC8`, `map_water_deep`
`#8AA9B6`, `map_land` `#F1EADA`, `map_land_hover` `#E1D5BC`, `map_selected` `#C89A4E`,
`map_border` `#A89C85`, `map_border_selected` `#7E5C13`, `map_coast` `#8E8268`,
`map_label` `#414E57`, `map_graticule` `#C6D3D6`, `map_ineligible` `#6B767C`, and the region tints
`#F4EDDD` `#EDE5D2` `#E7DECA` `#F6F0E2` `#EFE8D6` `#E9E1CF`. The sea is a
deeper blue-grey than a paper palette might suggest on purpose: land and water must stay
distinguishable (1.67:1 here) and a pale sea cannot clear that bar against pale land.

Map colours are checked as **non-text pairs** (`Palette.MAP_CONTRAST_REQUIREMENTS`): land must read
against water (≥ 1.6) and against the deep end of the sea gradient, a selection against ordinary land
(≥ 1.6), labels against land (≥ 4.5, a text pair), the selected outline against its fill (≥ 2.0), the
coastline against land (≥ 1.3), the land border against land (≥ 1.2), the ineligible dash against land
(≥ 2.4), and the grid against the sea (≥ 1.2). The design-system test enforces them for both palettes,
so a future retheme cannot ship an unreadable map.

### Region tints make a smaller promise, on purpose

Six tones, one per source region, ordered by lightness so two neighbours from different regions never
share a value. Their pairwise contrast is necessarily small — a tint separated enough to reach 1.5:1
would stop being a tint and start competing with the selection colour. So the tested promise is
narrower, and the docs say so: **no two tints share a luminance**
(`MAP_REGION_MIN_LUMINANCE_STEP`), **every tint separates from the sea**
(`MAP_REGION_MIN_WATER_CONTRAST`), and nothing a player must read depends on telling two tints apart —
names, coastlines, borders and the shape cues carry that. Printing a 1.03:1 pair and calling it an
accessible distinction would be a claim the design does not make.

### Shape before colour

Every map state has a cue beyond hue, so the map survives colour blindness, greyscale and a printed
screenshot: coastlines are heavier than land borders; the player's country has a **dashed** outline; a
selection gets **corner ticks**; records a campaign cannot start as get a **dash**; countries too small
to see get a **minimum marker**. Colour reinforces those cues; it never carries the meaning alone.

### Contrast guarantees (tested)

| Pair | Midnight | Parchment | Required |
| --- | --- | --- | --- |
| `text_primary` on `bg_panel` | 13.99:1 | 15.85:1 | ≥ 7:1 |
| `text_secondary` on `bg_base` | 8.67:1 | 7.46:1 | ≥ 4.5:1 |
| `text_tertiary` on `bg_panel` | 5.17:1 | 6.34:1 | ≥ 4.5:1 |
| `text_tertiary` on `bg_hover` | 4.75:1 | 5.04:1 | ≥ 4.5:1 |
| `accent` on `bg_panel` | 7.32:1 | 6.03:1 | ≥ 4.5:1 |
| `on_accent` on `accent` | 8.01:1 | 5.73:1 | ≥ 4.5:1 |
| `accent` (focus ring) on every surface | ≥ 6.7:1 | ≥ 4.8:1 | ≥ 3:1 (non-text) |

Colour is never the only signal: disabled entries are also labelled and non-interactive, status is
stated in words, and selection is carried by border + text colour + fill, not hue alone.

## 3. Typography

Three families, all SIL OFL 1.1. Only the latin subsets of the weights in use are shipped (~200 KB).

| Family | Role | Weights |
| --- | --- | --- |
| **Spectral** | Display and editorial headings — gives the interface a documentary tone | 300, 400 |
| **IBM Plex Sans** | Interface text: labels, body, buttons | 400, 500, 600 |
| **IBM Plex Mono** | Figures, version strings, technical values (tabular alignment) | 400, 500 |

Type ramp (`DesignTokens`):

| Variation | Face | Size | Notes |
| --- | --- | --- | --- |
| `DisplayTitle` | Spectral Light | 56 | Letterspaced +3 px; used only for the wordmark |
| `DisplayTitleCompact` | Spectral Light | 40 | Compact/short layouts |
| `ScreenTitle` | Spectral Regular | 30 | Secondary screen titles |
| `ScreenTitleCompact` | Spectral Regular | 24 | Secondary screen titles on short layouts |
| `Tagline` | Spectral Light | 18 | Single editorial line under the wordmark |
| `SectionHeading` | Plex Sans SemiBold | 12 | Uppercase, +1 px tracking, tertiary colour |
| `Eyebrow` | Plex Sans SemiBold | 11 | Uppercase, +2 px tracking, accent colour |
| `FieldLabel` | Plex Sans Medium | 15 | Row titles, setting names |
| `Body` | Plex Sans Regular | 15 | Prose, +4 px line spacing |
| `BodySmall` | Plex Sans Regular | 13 | List items |
| `Caption` | Plex Sans Regular | 12 | Descriptions, metadata |
| `Mono` | Plex Mono Regular | 12 | Version/engine strings, status bar |
| `Value` | Plex Mono Medium | 13 | Right-aligned technical values |
| `BadgeText` | Plex Sans SemiBold | 11 | Uppercase chip labels |

Rules: three sizes in a view at most, one accent-coloured text element per grouping, no italic (no
italic face is shipped), no text below 11 px, and no faux-bold (weights are real font files).

## 4. Spacing, radii, borders

- Spacing scale: **2, 4, 8, 12, 16, 24, 32, 48, 64**. Default container separation 8; panel padding 20;
  screen margins 16 (compact) / 32 (medium) / 48 (expanded).
- Main menu vertical rhythm: 12 (eyebrow → title), 16 (title → rule), 16 (rule → tagline),
  32 (tagline → menu). On short layouts these tighten to 6 / 8 / 8 / 16.
- Interactive row heights: 56 px (desktop), 52 px (short / touch), never below the 48 px touch target
  including padding.
- Radii: **2 px** (controls) and **3 px** (panels). Nothing is pill-shaped; corners should read as
  engineered, not soft.
- Borders are hairlines (1 px). A 2 px brass rule is reserved for the wordmark underline and the nav
  accent bar.
- Elevation is expressed by surface colour and hairlines, not shadows. Panels never stack shadows.
- One idea per band of vertical space: a heading, its rule, its content. Gaps between bands come from
  the scale, never from arbitrary numbers.

## 4a. Motion

Durations and easings live in `AnimationTokens`, not in screens: camera flight 440 ms,
selection pulse 1200 ms per leg, panel slide 180 ms, panel fade 140 ms, button press 90 ms,
speed change 160 ms, pause change 180 ms, campaign start 320 ms, ambient sea 500 ms linear.
Every entry declares what happens under reduced motion, and none flashes more than three
times per second. Press feedback is a 3 % dip over 90 ms; a press is never a bounce.
The generated table, with triggers and reduced-motion behaviour, is `docs/ANIMATION.md`.

## 5. Components

### Navigation row (`NavRow`)
Full-width `Button` with title, optional description, optional status badge and a chevron.
Height 56 px (48 px on short layouts). States: idle (transparent), hover (`bg_hover`), pressed
(`bg_selected`), focus (brass outline + accent bar), disabled (muted text, no chevron, no hover).
The 2 px accent bar fades in on hover/focus — motion without colour-filling.

### Segmented control (`SegmentedControl`)
Mutually exclusive options as toggled buttons in one `ButtonGroup`. Idle: `bg_base` with hairline;
hover: `bg_hover`; selected: `bg_selected` fill + brass border + brass label; focus: brass outline.
Height 40 px on desktop, 48 px on touch devices. Used for theme, interface scale and motion.

### Badge

A small status chip: a transparent panel with a hairline border and semibold caption text.
Used for Load Game slot states (Ready / Damaged / Empty) and campaign requirements. It is
never the only cue — the sentence beside it says the same thing in words.

### Keyboard cheat sheet

A three-column grid (keys, action, where it works) rendered from `Shortcuts.ENTRIES`, the
same table the input code and the tests read. Monospace for the keys, body text for the
action, caption for the scope.

### Buttons
- `GhostButton` — low-emphasis actions ("Back").
- `SegmentButton` — inside a segmented control.
- `DangerButton` — destructive action (reset settings), outlined in `negative`, never filled.
- Base `Button` — quiet secondary surface, kept coherent for future use.
Every button has a visible focus state; no button relies on colour alone to convey state.

- `PrimaryButton` — the single confirming action on a screen ("Review campaign"). Brass fill with
  `on_accent` text, brass-tinted focus ring, outlined and muted when disabled.
- `Chip` — a filter toggle (region filters). Transparent with a hairline when off, `bg_selected`
  with a brass border and brass label when on, so the active filter is legible without colour alone.
- `MapButton` — square 40×40 map overlay control (`+`, `-`, `Fit`), 32 px tall on short layouts.
- `SearchResult` — one row of the country search list: body text, right-aligned mono ISO code.

### Text fields
`LineEdit` has a themed surface, hairline border, brass caret and a brass focus border. `SearchField`
is the atlas search field: same shape, a stronger border so it reads as the primary control above the
map, and a 44 px minimum height (40 px on short layouts).

### Panels
`PanelCard` (1 px border, 20 px padding, radius 3) groups related controls; `Badge` is a small
outlined chip used for status words such as **PLANNED** or **IMPLEMENTED**; `MapFrame` wraps the
atlas in a sea-coloured panel with a hairline border and no padding, so the map is flush with its
frame.

### Flag tile and flag strip

`FlagTile` is a 40 × 30 flag that rasterises lazily and shows a neutral **code badge** while it
loads, or for good when the source has no flag for that record. `FlagStrip` is a
`ScrollContainer` of tiles, six to a page, snapping page by page; tiles are 72 px square in the
normal layout and 48 px in a short window. Selection is a tick, a heavier outline *and* the
country's name in the tooltip — never colour alone.

### Country picker panel

A `VBoxContainer`: a section heading, a group `OptionButton`, a search `LineEdit`, a `HFlowContainer`
A–Z index of 48 × 48 buttons, a count line, and a scrolling list of one letter of one group.
Every control is `CONTROL_HEIGHT`; the list has a 220 px minimum and virtualises by showing one
letter at a time rather than by recycling nodes.

### Avatars

`AvatarArt` draws twenty avatars from an index — a coloured disc, an outline and one of five
motifs (sun and rays, sail and waterline, cedar, comet, lantern) — so the grid tile and the
96 px profile header are the same picture. Each avatar carries a name ("Sunrise", "Harbour",
"Cedar" …) under it, and the chosen cell adds a tick and a 2 px outline. The gallery is
5 columns × 4 rows of 80 × 80 buttons; nothing there is an image file.

### Header (`AppHeader`)
Back control, a mono context line on the right ("Milestone 01"), then the title block. Separated from
content by an `HSeparator`.

### Icons
Original 48×48 grid SVGs with 3 px strokes, displayed at 16 px — the source resolution is 3× the
display size, so icons stay sharp on high-density screens. Their size is set once by the theme's
`icon_max_width` constant, never per instance, and they are tinted with palette colours
(`chevron_right`, `arrow_left`, `reset`). No icon library, no icon font, no copied glyphs. Icons are optional decoration next to a text label, never the only label.

### Backdrop
Procedurally drawn concentric chart rings with meridians emerging from the right edge, plus a shader
vignette with subtle dithering to avoid banding. Contrast is intentionally near the threshold of
visibility: it adds atmosphere without competing with text. It is a chart ornament, not a map — the
interactive atlas is the only place geography is drawn.

### The map itself
The atlas is drawn, not composed from nodes, so its "components" are its visual rules: flat fills
(no gradient), one-pixel country outlines, a 30° graticule at low contrast, tracked uppercase labels
in `Eyebrow` type at `map_label` colour, a brass 2 px outline and `map_selected` fill for the chosen
nation, and `map_land_hover` for the country under the pointer. Selection is always shown twice —
fill *and* outline — so it survives colour-vision differences and the Parchment palette.

Three additions keep the map usable rather than decorative:

* **Tiny-shape markers.** A country whose whole shape is under 6 px on screen gets a hollow 3.5 px
  ring at its label anchor (5 px, doubled, when selected), drawn in `map_label` or `map_accent`. Without
  it, Singapore and the Pacific atolls are invisible at world zoom and the assist radius is invisible
  too — and an affordance nobody can see is not an affordance.
* **Ocean names** at world zoom only, in `map_label` at 75 % alpha, smaller than country labels and
  never on top of them. They are orientation words, not features.
* **Scale bar.** A 1.5 px rule with end ticks in `map_label`, bottom right, with its distance label in
  `Eyebrow` type. It states kilometres, computed at the view centre, and it never implies that the
  equirectangular map has one uniform scale.

## 6. Motion

| Token | Duration | Used for |
| --- | --- | --- |
| `DURATION_FAST` | 120 ms | Hover/accent feedback |
| `DURATION_BASE` | 180 ms | Entrance fades |
| `DURATION_SCREEN` | 220 ms | Screen transitions (fade out ≈55 %, fade in ≈75 %) |
| `STAGGER_STEP` | 35 ms | Sequential entrance of menu rows |

Single easing family: cubic ease-out. Entrances fade with a small delay cascade; nothing bounces,
nothing spins, nothing animates for longer than 260 ms. The **Reduced motion** setting collapses every
duration to zero through `Motion.duration()`, so the interface becomes instant rather than merely
slower.

## 7. Layout and responsiveness

Breakpoints from `DesignTokens`:

| Mode | Available width | Behaviour |
| --- | --- | --- |
| `COMPACT` | < 620 px | Single column, 16 px margins, compact display type, menu rows full width |
| `MEDIUM` | 620–1023 px | 32 px margins, 340 px menu measure, tagline shown |
| `EXPANDED` | ≥ 1024 px | 48 px margins, 420 px menu measure, build-status dossier column appears |

Additional rules:
- `is_short()` (height < 460 px, e.g. a phone in landscape) tightens vertical rhythm, uses a
  single-line wordmark and hides the tagline. Since Milestone 09 it no longer hides menu entries:
  the main menu's column scrolls instead, so every row stays reachable with its 48–56 px height.
- Settings rows stack from two columns to one below 480 px of row width.
- Content columns are capped by a reading measure (720 px settings, 640 px about) and never stretch
  to a widescreen edge.
- Below 400 px of height the main menu's version bar is dropped: on a phone in landscape it would
  cost the menu 50 px, and the same information is on the About screen.
- On short layouts secondary screens use a compact header: the title drops to 24 px and the subtitle
  is hidden, because a full header block would take a third of a phone in landscape.
- The main menu is grouped **Play** (New Campaign, Continue, Worlds), **You** (Profile, Settings)
  and **Library** (Help, Roadmap, About the data, Keyboard shortcuts, Diagnostics, About & Credits),
  with 28 px headings that are text rather than controls. The rows live in a `ScrollContainer`
  whose height is the smaller of what the rows need and what the window can spare after the
  wordmark and status bar, so a short window scrolls rather than compressing a row below 48 px.
- In `COMPACT` the version line shortens ("Milestone 01 — Foundation" becomes "Milestone 01") and owns
  the full bar width with ellipsis trimming, so it can never push the bar past the screen margin.
- Disabled text keeps ≥ 3:1 contrast in both palettes (Midnight 3.41:1, Parchment 3.28:1) so a
  "Planned" entry stays readable while still reading as unavailable.
- The campaign screen has three arrangements of the **same two widgets**, chosen by space rather
  than by device: `SIDE` (map left, dossier right) for every non-compact width, `STACK` (map on top,
  dossier below at 30 % of the height) for a tall narrow screen, and `DRAWER` (map only, dossier
  opening over it from a footer toggle) when the window is both narrow and short — the case where
  stacking would leave the world 40 px tall. The map is never hidden behind chrome in any of them.
- On short layouts the atlas tightens: search field 40 px, filter chips 32 px, map minimum 96 px,
  map controls 32 px, and the dossier becomes the drawer.
- The country search list is an overlay above the map, not a block in the flow, so opening it never
  reflows the world underneath.
- All screens are verified at 1920×1080, 1280×720, 1024×768, 844×390, 640×360, 390×844 and 360×800
  by `tests/suites/test_layout.gd` and `tests/suites/test_campaign_ui.gd`: no overflow, no collapsed
  labels, on either palette and with reduced motion.

## 8. Voice and micro-copy

Short, declarative, no exclamation marks, no marketing filler. Availability is stated plainly:
unfinished entries carry a **PLANNED** badge and are disabled; finished ones lose both. Nothing is
described as working before it does — the campaign brief says "no simulation runs, no turn is taken
and nothing is saved yet" in those words. Missing data is stated, not smoothed over: the country
dossier writes "Not recorded in source" rather than inventing a capital. Captions explain *what a
control does*, not what it “unlocks”.

## 8a. The settings screen (Milestone 09)

Eight groups, in this order, each a heading plus a card of `SettingRow`s: **Display** (theme,
interface scale, reduced motion), **Performance** (frame-rate cap, quality), **Audio** (four
buses with a slider and a mute each, plus the interface-sounds switch), **Controls** (the
keyboard cheat sheet, read from `Shortcuts.ENTRIES`), **Backup** (links to the worlds and
backup screens), **Privacy and terms**, **Advanced / Developer** (performance overlay, developer
tools, the F4 inspector hint, the stress test) and **About this build**.

Two rules hold the group together:

* **A control changes something that exists.** There is no switch for a feature that is not
  built. "Realism" is the one setting the roadmap wants and the build does not have, so it
  appears as a caption marked PLANNED rather than as a control that would do nothing.
* **One source per fact.** The cheat sheet is `Shortcuts.ENTRIES` — the same table the shortcut
  screen renders — and the quality preset is `SettingsSchema.quality_preset()`, the table below.

### Quality presets

Quality is not a new renderer; it writes the five map display options that already exist, in
`SettingsSchema.quality_preset()`:

| Option | High | Medium | Low |
| --- | --- | --- | --- |
| Map detail | Full | Reduced (thinner borders, no ocean names, no capital markers on the map, lower label cap) | Reduced |
| Labels | All labels | All labels | Fewer labels |
| Capital markers | Shown | Shown (the reduced detail pass may still hide them) | Hidden |
| Graticule | Shown | Hidden | Hidden |
| Reference lines | Shown | Shown | Hidden |
| Ambient sea | Allowed (and still off under reduced motion) | Stopped by reduced detail | Stopped by reduced detail |

`Custom` means "whatever the map options already say": it changes no option, and choosing a
preset overwrites all five. Changing any map option by hand — on this screen or in the
campaign's Map options panel — stores `Custom`, so the label never claims a preset the options
no longer match. No preset changes geography, hit boxes, selection or a save.

### Frame-rate cap

30, 60 or Unlimited, stored as a string and turned into the engine's own value by
`SettingsSchema.fps_cap()` (30, 60 and 0). `SettingsService._apply_runtime()` writes it to
`Engine.max_fps` on load and on every settings change, so there is no restart and no second
code path. It is a ceiling: a busy device can draw fewer frames, and nothing in the UI claims
otherwise.

## 8b. Help and Roadmap

Both are "library" screens: a header, one scrolling reading column capped at the 720 px measure,
and cards. They share no widget beyond the existing ones — a `SectionHeading`, a `PanelCard`, a
`Caption` for provenance, and (on Help) `GhostButton` links at 48 px.

The Roadmap is deliberately the least animated screen in the game: **no** tween, no
`AnimationPlayer`, nothing that moves when the page appears. "Calm" is a design requirement here,
and the cheapest way to guarantee it under reduced motion is to have no motion to reduce.

Status pills use the existing `Badge` panel and `BadgeText` label variations, so a roadmap status
looks like the PLANNED badge the navigation rows used to carry rather than a new language.

## 9. Adding to the system

1. Add a token to `DesignTokens` (never a magic number in a scene).
2. Add colours to **both** palettes and, if text sits on them, add the pair to
   `Palette.CONTRAST_REQUIREMENTS`.
3. Add a type variation in `ThemeFactory` and register it in `required_variations()`.
4. Build the component from existing variations; only create a new variation when a genuinely new
   role appears.
5. Extend `tests/suites/test_layout.gd` with the new screen or component and at least the
   phone-landscape size.
6. Update this document in the same pull request.
7. If the change adds a map colour, add it to **both** palettes and to
   `Palette.MAP_CONTRAST_REQUIREMENTS`.
