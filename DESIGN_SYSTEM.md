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

### Buttons
- `GhostButton` — low-emphasis actions ("Back").
- `SegmentButton` — inside a segmented control.
- `DangerButton` — destructive action (reset settings), outlined in `negative`, never filled.
- Base `Button` — quiet secondary surface, kept coherent for future use.
Every button has a visible focus state; no button relies on colour alone to convey state.

### Panels
`PanelCard` (1 px border, 20 px padding, radius 3) groups related controls; `Badge` is a small
outlined chip used for status words such as **PLANNED**.

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
visibility: it adds atmosphere without competing with text. No map is drawn, because no map exists yet.

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
  single-line wordmark, hides the tagline and the unavailable "Continue" entry, and shortens rows.
- Settings rows stack from two columns to one below 480 px of row width.
- Content columns are capped by a reading measure (720 px settings, 640 px about) and never stretch
  to a widescreen edge.
- Below 400 px of height the main menu's version bar is dropped: on a phone in landscape it would
  cost the menu 50 px, and the same information is on the About screen.
- All screens are verified at 1920×1080, 1280×720, 1024×768, 844×390, 640×360 and 390×844 by
  `tests/suites/test_layout.gd`: no overflow, no collapsed labels.

## 8. Voice and micro-copy

Short, declarative, no exclamation marks, no marketing filler. Availability is stated plainly:
"World map and country selection · Milestone 02" with a **PLANNED** badge. Nothing is described as
working before it does. Captions explain *what a setting does*, not what it “unlocks”.

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
