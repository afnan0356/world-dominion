class_name DesignTokens
extends RefCounted
## Single source of truth for WORLD DOMINION's visual language: spacing, type
## ramp, radii, motion and layout breakpoints.
##
## Nothing in this file depends on a specific screen. Every theme resource,
## component and screen composes these tokens instead of hardcoding values, so
## the interface stays consistent as the project grows. Sizes are expressed in
## logical pixels at 100% interface scale; the player's interface-scale setting
## is applied by the window (`content_scale_factor`), not by changing tokens.

enum LayoutMode { COMPACT, MEDIUM, EXPANDED }

# --- Spacing ---------------------------------------------------------------
# An 8pt rhythm with 2/4 steps for optical alignment of hairlines and labels.
const SPACE_2 := 2
const SPACE_4 := 4
const SPACE_8 := 8
const SPACE_12 := 12
const SPACE_16 := 16
const SPACE_24 := 24
const SPACE_32 := 32
const SPACE_48 := 48
const SPACE_64 := 64

# --- Type ramp (px) --------------------------------------------------------
const FS_DISPLAY := 56
const FS_DISPLAY_COMPACT := 40
const FS_TITLE := 30
## Screen titles shrink on short screens so the header cannot eat a phone in
## landscape; the display title has its own compact size for the same reason.
const FS_TITLE_COMPACT := 24
const FS_HEADING := 20
const FS_SUBHEADING := 16
const FS_BODY := 15
const FS_SMALL := 13
const FS_CAPTION := 11
const FS_MONO := 12

# Positive letter-spacing (px between glyphs) for tracked, capitalised text.
const TRACK_DISPLAY := 3
const TRACK_EYEBROW := 2
const TRACK_CAPTION := 1

# --- Radii & borders -------------------------------------------------------
# Deliberately restrained: a 2–3px radius reads as engineered, not playful.
const RADIUS_SMALL := 2
const RADIUS_MEDIUM := 3
const BORDER_HAIRLINE := 1
const BORDER_ACCENT := 2

# --- Motion (seconds) ------------------------------------------------------
# Durations are short on purpose; the interface should feel immediate.
const DURATION_FAST := 0.12
const DURATION_BASE := 0.18
const DURATION_SLOW := 0.26
const DURATION_SCREEN := 0.22
const STAGGER_STEP := 0.035

# --- Component metrics -----------------------------------------------------
const NAV_ROW_HEIGHT := 56
const NAV_ROW_HEIGHT_COMPACT := 52
## Every button, field and row the player taps is at least this tall. It matches
## `TOUCH_TARGET_MIN` on purpose: a control that is comfortable for a finger is also
## comfortable for a mouse, and one number is easier to keep honest than two.
const CONTROL_HEIGHT := 48
const TOUCH_TARGET_MIN := 48
const PANEL_PADDING := 20
const CONTENT_MEASURE := 720
const CONTENT_MEASURE_NARROW := 640
const DOSSIER_WIDTH := 300
const ICON_SIZE_SMALL := 16

# --- Responsive breakpoints ------------------------------------------------
## Below this width the interface is compact (phones in landscape).
const BREAKPOINT_MEDIUM := 620
## From this width the interface is expanded (desktops, tablets in landscape).
const BREAKPOINT_EXPANDED := 1024
## Below this height vertical rhythm tightens (phone landscape).
const HEIGHT_SHORT := 460


## Layout mode for a viewport size. Landscape is the design target, but every
## rule here is expressed in terms of the available box, not of a device.
static func layout_mode(size: Vector2) -> LayoutMode:
	if size.x >= BREAKPOINT_EXPANDED:
		return LayoutMode.EXPANDED
	if size.x >= BREAKPOINT_MEDIUM:
		return LayoutMode.MEDIUM
	return LayoutMode.COMPACT


## True when vertical space is scarce and the interface should tighten up.
static func is_short(size: Vector2) -> bool:
	return size.y < HEIGHT_SHORT


## Outer margin between the screen edge and content.
static func screen_margin(mode: LayoutMode) -> int:
	match mode:
		LayoutMode.EXPANDED:
			return SPACE_48
		LayoutMode.MEDIUM:
			return SPACE_32
		_:
			return SPACE_16


## Minimum height of an interactive row, never below the touch target minimum.
static func nav_row_height(is_short: bool) -> int:
	return NAV_ROW_HEIGHT_COMPACT if is_short else NAV_ROW_HEIGHT
