class_name Palette
extends RefCounted
## The two official WORLD DOMINION palettes.
##
## Both palettes are intentionally narrow: one ink colour, three surface steps,
## a single brass accent and a small set of semantic colours. Text/surface
## combinations are verified against WCAG AA contrast by the test suite
## (tests/suites/test_design_system.gd), so a palette change that hurts
## legibility fails CI instead of shipping.

const MIDNIGHT := "midnight"
const PARCHMENT := "parchment"
const DEFAULT_ID := MIDNIGHT

# Keys expected by the theme builder and by any custom-drawn widget.
const KEY_BG_BASE := "bg_base"
const KEY_BG_SURFACE := "bg_surface"
const KEY_BG_PANEL := "bg_panel"
const KEY_BG_HOVER := "bg_hover"
const KEY_BG_SELECTED := "bg_selected"
const KEY_BORDER := "border"
const KEY_BORDER_STRONG := "border_strong"
const KEY_TEXT_PRIMARY := "text_primary"
const KEY_TEXT_SECONDARY := "text_secondary"
const KEY_TEXT_TERTIARY := "text_tertiary"
const KEY_TEXT_DISABLED := "text_disabled"
const KEY_ACCENT := "accent"
const KEY_ACCENT_STRONG := "accent_strong"
const KEY_ON_ACCENT := "on_accent"
const KEY_POSITIVE := "positive"
const KEY_WARNING := "warning"
const KEY_NEGATIVE := "negative"
const KEY_INFO := "info"
const KEY_BACKDROP_GRID := "backdrop_grid"
const KEY_BACKDROP_GLOW := "backdrop_glow"

# Map colours. The world map is drawn, not themed through nodes, so its colours
# live in the palette with the rest of the visual language. Land/water/selection
# pairs are contrast-checked by the design-system test as non-text pairs.
const KEY_MAP_WATER := "map_water"
const KEY_MAP_LAND := "map_land"
const KEY_MAP_LAND_HOVER := "map_land_hover"
const KEY_MAP_SELECTED := "map_selected"
const KEY_MAP_BORDER := "map_border"
const KEY_MAP_BORDER_SELECTED := "map_border_selected"
const KEY_MAP_LABEL := "map_label"
const KEY_MAP_GRATICULE := "map_graticule"

# The dark theme is the default: a strategy interface is used for long
# sessions, often at night, and dark surfaces keep the (future) map legible.
const _MIDNIGHT := {
	KEY_BG_BASE: "#0C1216",
	KEY_BG_SURFACE: "#131C22",
	KEY_BG_PANEL: "#16212A",
	KEY_BG_HOVER: "#1B2833",
	KEY_BG_SELECTED: "#21303B",
	KEY_BORDER: "#253239",
	KEY_BORDER_STRONG: "#33454F",
	KEY_TEXT_PRIMARY: "#E9EEF2",
	KEY_TEXT_SECONDARY: "#A3B2BD",
	KEY_TEXT_TERTIARY: "#84939D",
	KEY_TEXT_DISABLED: "#5A6B75",
	KEY_ACCENT: "#D8A54A",
	KEY_ACCENT_STRONG: "#E8B961",
	KEY_ON_ACCENT: "#12181C",
	KEY_POSITIVE: "#84AE8F",
	KEY_WARNING: "#D8A54A",
	KEY_NEGATIVE: "#D08A73",
	KEY_INFO: "#88A9C9",
	KEY_BACKDROP_GRID: "#2E3F49",
	KEY_BACKDROP_GLOW: "#070B0E",
	KEY_MAP_WATER: "#070D11",
	KEY_MAP_LAND: "#2C3A44",
	KEY_MAP_LAND_HOVER: "#35474F",
	KEY_MAP_SELECTED: "#6B5427",
	KEY_MAP_BORDER: "#465C68",
	KEY_MAP_BORDER_SELECTED: "#D8A54A",
	KEY_MAP_LABEL: "#A3B2BD",
	KEY_MAP_GRATICULE: "#17242C",
}

const _PARCHMENT := {
	KEY_BG_BASE: "#F2EFE8",
	KEY_BG_SURFACE: "#FAF8F3",
	KEY_BG_PANEL: "#FFFDF8",
	KEY_BG_HOVER: "#E9E3D6",
	KEY_BG_SELECTED: "#DFD6C3",
	KEY_BORDER: "#DCD4C4",
	KEY_BORDER_STRONG: "#BFB49E",
	KEY_TEXT_PRIMARY: "#1B2226",
	KEY_TEXT_SECONDARY: "#414E57",
	KEY_TEXT_TERTIARY: "#556068",
	KEY_TEXT_DISABLED: "#7C858A",
	KEY_ACCENT: "#7E5C13",
	KEY_ACCENT_STRONG: "#6B4D10",
	KEY_ON_ACCENT: "#FBF7EE",
	KEY_POSITIVE: "#3F6B4E",
	KEY_WARNING: "#7E5C13",
	KEY_NEGATIVE: "#96432C",
	KEY_INFO: "#2F5A7E",
	KEY_BACKDROP_GRID: "#D8CDB9",
	KEY_BACKDROP_GLOW: "#E3DCCB",
	KEY_MAP_WATER: "#A0BCC8",
	KEY_MAP_LAND: "#F1EADA",
	KEY_MAP_LAND_HOVER: "#E1D5BC",
	KEY_MAP_SELECTED: "#C89A4E",
	KEY_MAP_BORDER: "#A89C85",
	KEY_MAP_BORDER_SELECTED: "#7E5C13",
	KEY_MAP_LABEL: "#414E57",
	KEY_MAP_GRATICULE: "#C6D3D6",
}

const _DISPLAY_NAMES := {
	MIDNIGHT: "Midnight",
	PARCHMENT: "Parchment",
}

const _DESCRIPTIONS := {
	MIDNIGHT: "Deep ink surfaces with a brass accent. The default.",
	PARCHMENT: "Warm paper surfaces for daylight and long reading.",
}

## Contrast pairs that the design system guarantees (foreground, background)
## and the minimum ratio required. Non-text decorative colours are excluded.
## Non-text pairs that must stay distinguishable on the map: land against water,
## a selected country against ordinary land, and country labels against land.
const MAP_CONTRAST_REQUIREMENTS := [
	[KEY_MAP_LAND, KEY_MAP_WATER, 1.6],
	[KEY_MAP_SELECTED, KEY_MAP_LAND, 1.6],
	[KEY_MAP_LAND_HOVER, KEY_MAP_LAND, 1.15],
	[KEY_MAP_LABEL, KEY_MAP_LAND, 4.5],
	[KEY_MAP_BORDER_SELECTED, KEY_MAP_SELECTED, 2.0],
	[KEY_MAP_BORDER, KEY_MAP_LAND, 1.2],
]

const CONTRAST_REQUIREMENTS := [
	[KEY_TEXT_PRIMARY, KEY_BG_BASE, 7.0],
	[KEY_TEXT_PRIMARY, KEY_BG_PANEL, 7.0],
	[KEY_TEXT_SECONDARY, KEY_BG_BASE, 4.5],
	[KEY_TEXT_SECONDARY, KEY_BG_SURFACE, 4.5],
	[KEY_TEXT_TERTIARY, KEY_BG_BASE, 4.5],
	[KEY_TEXT_TERTIARY, KEY_BG_PANEL, 4.5],
	[KEY_TEXT_TERTIARY, KEY_BG_HOVER, 4.5],
	[KEY_ACCENT, KEY_BG_BASE, 4.5],
	[KEY_ACCENT, KEY_BG_PANEL, 4.5],
	[KEY_ON_ACCENT, KEY_ACCENT, 4.5],
	[KEY_NEGATIVE, KEY_BG_PANEL, 4.5],
	[KEY_POSITIVE, KEY_BG_PANEL, 4.5],
	[KEY_INFO, KEY_BG_PANEL, 4.5],
]


static func ids() -> PackedStringArray:
	return PackedStringArray([MIDNIGHT, PARCHMENT])


static func is_valid(palette_id: String) -> bool:
	return _DISPLAY_NAMES.has(palette_id)


static func display_name(palette_id: String) -> String:
	return _DISPLAY_NAMES.get(palette_id, _DISPLAY_NAMES[DEFAULT_ID])


static func description(palette_id: String) -> String:
	return _DESCRIPTIONS.get(palette_id, _DESCRIPTIONS[DEFAULT_ID])


## True for palettes built on dark surfaces. Used for a handful of decisions
## that are not expressible in the token set (e.g. vignette strength).
static func is_dark(palette_id: String) -> bool:
	return palette_id != PARCHMENT


## Resolved colours for a palette id, as {String: Color}. Unknown ids fall back
## to the default palette instead of failing, so bad saved data cannot break
## the interface.
static func colors(palette_id: String) -> Dictionary:
	var source: Dictionary = _PARCHMENT if palette_id == PARCHMENT else _MIDNIGHT
	var resolved := {}
	for key: String in source:
		resolved[key] = Color(source[key])
	return resolved
