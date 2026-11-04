class_name ThemeFactory
extends RefCounted
## Builds the runtime `Theme` for a palette.
##
## The theme is generated from `DesignTokens` + `Palette` rather than hand-edited
## in a .tres file, for three reasons:
##   1. tokens have a single source of truth, so spacing and type cannot drift
##      between screens;
##   2. switching between the Midnight and Parchment palettes is a rebuild of
##      one object instead of maintaining two near-identical theme resources;
##   3. the test suite can assert properties of the generated theme (contrast,
##      required type variations, font sizes) in a headless run.
##
## Components address styles through *type variations* (e.g. a Button with
## `theme_type_variation = "NavRow"`), never through per-instance overrides.

# Content paddings for the stylebox variants (left, top, right, bottom).
const _PAD_CONTROL := Vector4(DesignTokens.SPACE_16, DesignTokens.SPACE_8,
		DesignTokens.SPACE_16, DesignTokens.SPACE_8)
const _PAD_GHOST := Vector4(DesignTokens.SPACE_8, DesignTokens.SPACE_4,
		DesignTokens.SPACE_12, DesignTokens.SPACE_4)
const _PAD_NAV := Vector4(DesignTokens.SPACE_24, DesignTokens.SPACE_12,
		DesignTokens.SPACE_16, DesignTokens.SPACE_12)
const _PAD_PANEL := Vector4(DesignTokens.PANEL_PADDING, DesignTokens.PANEL_PADDING,
		DesignTokens.PANEL_PADDING, DesignTokens.PANEL_PADDING)
const _PAD_BADGE := Vector4(DesignTokens.SPACE_8, DesignTokens.SPACE_2,
		DesignTokens.SPACE_8, DesignTokens.SPACE_2)
const _PAD_TOOLTIP := Vector4(DesignTokens.SPACE_12, DesignTokens.SPACE_8,
		DesignTokens.SPACE_12, DesignTokens.SPACE_8)


# --- Public API ------------------------------------------------------------

static func build(colors: Dictionary) -> Theme:
	var theme := Theme.new()
	theme.default_font = Typography.sans_regular()
	theme.default_font_size = DesignTokens.FS_BODY
	_build_labels(theme, colors)
	_build_buttons(theme, colors)
	_build_panels(theme, colors)
	_build_separators(theme, colors)
	_build_scrollbars(theme, colors)
	_build_container_defaults(theme)
	_build_tooltip(theme, colors)
	return theme


## Style variations the interface relies on; the test suite asserts that every
## one of these exists in the generated theme.
static func required_variations() -> Dictionary:
	return {
		"Label": [
			"DisplayTitle", "DisplayTitleCompact", "ScreenTitle", "SectionHeading",
			"FieldLabel", "Caption", "Body", "BodySmall", "Eyebrow", "Mono", "BadgeText",
			"Value", "Tagline",
		],
		"Button": ["NavRow", "GhostButton", "SegmentButton", "DangerButton"],
		"PanelContainer": ["PanelCard", "Badge"],
	}


# --- Labels ----------------------------------------------------------------

static func _build_labels(theme: Theme, colors: Dictionary) -> void:
	var primary: Color = colors[Palette.KEY_TEXT_PRIMARY]
	var secondary: Color = colors[Palette.KEY_TEXT_SECONDARY]
	var tertiary: Color = colors[Palette.KEY_TEXT_TERTIARY]
	var accent: Color = colors[Palette.KEY_ACCENT]

	# Default label: interface body text.
	theme.set_font("font", "Label", Typography.sans_regular())
	theme.set_font_size("font_size", "Label", DesignTokens.FS_BODY)
	theme.set_color("font_color", "Label", primary)
	theme.set_constant("line_spacing", "Label", DesignTokens.SPACE_4)

	_label_style(theme, "DisplayTitle", Typography.serif_light(), DesignTokens.FS_DISPLAY,
			primary, DesignTokens.TRACK_DISPLAY, -DesignTokens.SPACE_24)
	_label_style(theme, "DisplayTitleCompact", Typography.serif_light(),
			DesignTokens.FS_DISPLAY_COMPACT, primary, DesignTokens.TRACK_CAPTION + 1,
			-DesignTokens.SPACE_12)
	_label_style(theme, "ScreenTitle", Typography.serif_regular(), DesignTokens.FS_TITLE,
			primary, 0, -DesignTokens.SPACE_4)
	_label_style(theme, "ScreenTitleCompact", Typography.serif_regular(),
			DesignTokens.FS_TITLE_COMPACT, primary, 0, -DesignTokens.SPACE_2)
	_label_style(theme, "Tagline", Typography.serif_light(), DesignTokens.FS_SUBHEADING + 2,
			secondary, 0, DesignTokens.SPACE_4)
	_label_style(theme, "SectionHeading", Typography.sans_semibold(), DesignTokens.FS_SMALL - 1,
			tertiary, DesignTokens.TRACK_CAPTION, DesignTokens.SPACE_2)
	_label_style(theme, "FieldLabel", Typography.sans_medium(), DesignTokens.FS_BODY,
			primary, 0, DesignTokens.SPACE_2)
	_label_style(theme, "Caption", Typography.sans_regular(), DesignTokens.FS_SMALL - 1,
			tertiary, 0, DesignTokens.SPACE_2)
	_label_style(theme, "Body", Typography.sans_regular(), DesignTokens.FS_BODY,
			secondary, 0, DesignTokens.SPACE_4)
	_label_style(theme, "BodySmall", Typography.sans_regular(), DesignTokens.FS_SMALL,
			secondary, 0, DesignTokens.SPACE_2)
	_label_style(theme, "Eyebrow", Typography.sans_semibold(), DesignTokens.FS_CAPTION,
			accent, DesignTokens.TRACK_EYEBROW, 0)
	_label_style(theme, "Mono", Typography.mono_regular(), DesignTokens.FS_MONO,
			tertiary, 0, 0)
	_label_style(theme, "Value", Typography.mono_medium(), DesignTokens.FS_SMALL,
			secondary, 0, 0)
	_label_style(theme, "BadgeText", Typography.sans_semibold(), DesignTokens.FS_CAPTION - 1,
			secondary, DesignTokens.TRACK_CAPTION, 0)


static func _label_style(theme: Theme, type_name: String, font: Font, size: int,
		color: Color, tracking: int, line_spacing: int) -> void:
	theme.set_type_variation(type_name, "Label")
	theme.set_font("font", type_name, Typography.tracked(font, tracking) if tracking > 0 else font)
	theme.set_font_size("font_size", type_name, size)
	theme.set_color("font_color", type_name, color)
	theme.set_constant("line_spacing", type_name, line_spacing)


# --- Buttons ---------------------------------------------------------------

static func _build_buttons(theme: Theme, colors: Dictionary) -> void:
	var primary: Color = colors[Palette.KEY_TEXT_PRIMARY]
	var surface: Color = colors[Palette.KEY_BG_SURFACE]
	var base: Color = colors[Palette.KEY_BG_BASE]
	var hover: Color = colors[Palette.KEY_BG_HOVER]
	var selected: Color = colors[Palette.KEY_BG_SELECTED]
	var border: Color = colors[Palette.KEY_BORDER]
	var accent: Color = colors[Palette.KEY_ACCENT]
	var negative: Color = colors[Palette.KEY_NEGATIVE]

	theme.set_font("font", "Button", Typography.sans_medium())
	theme.set_font_size("font_size", "Button", DesignTokens.FS_BODY)
	theme.set_color("font_color", "Button", primary)
	theme.set_color("font_hover_color", "Button", primary)
	theme.set_color("font_pressed_color", "Button", primary)
	theme.set_color("font_focus_color", "Button", primary)
	theme.set_color("font_disabled_color", "Button", colors[Palette.KEY_TEXT_DISABLED])
	theme.set_constant("h_separation", "Button", DesignTokens.SPACE_8)
	# Button icons are 48px vector sources; the theme caps them at the design size
	# so every icon in the interface matches without per-instance tuning.
	theme.set_constant("icon_max_width", "Button", DesignTokens.ICON_SIZE_SMALL)

	# Base button: a quiet, secondary surface. Nothing in Milestone 01 uses the
	# bare Button type, but any future one inherits a coherent look.
	theme.set_stylebox("normal", "Button", _box(surface, border, DesignTokens.RADIUS_SMALL,
			_PAD_CONTROL))
	theme.set_stylebox("hover", "Button", _box(hover, border, DesignTokens.RADIUS_SMALL,
			_PAD_CONTROL))
	theme.set_stylebox("pressed", "Button", _box(selected, border, DesignTokens.RADIUS_SMALL,
			_PAD_CONTROL))
	theme.set_stylebox("disabled", "Button", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0),
			DesignTokens.RADIUS_SMALL, _PAD_CONTROL))
	theme.set_stylebox("focus", "Button", _focus_box(accent))

	# NavRow — a full-width navigation entry on the main menu.
	var nav_margins := _PAD_NAV
	_set_stylebox_variation(theme, "Button", "NavRow", {
		"normal": _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), DesignTokens.RADIUS_SMALL, nav_margins),
		"hover": _box(hover, Color(0, 0, 0, 0), DesignTokens.RADIUS_SMALL, nav_margins),
		"pressed": _box(selected, Color(0, 0, 0, 0), DesignTokens.RADIUS_SMALL, nav_margins),
		"disabled": _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), DesignTokens.RADIUS_SMALL, nav_margins),
		"focus": _focus_box(accent),
	})
	theme.set_color("font_hover_color", "NavRow", primary)
	theme.set_color("font_pressed_color", "NavRow", primary)

	# GhostButton — low-emphasis actions such as "Back".
	_set_stylebox_variation(theme, "Button", "GhostButton", {
		"normal": _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), DesignTokens.RADIUS_SMALL,
				_PAD_GHOST),
		"hover": _box(hover, Color(0, 0, 0, 0), DesignTokens.RADIUS_SMALL,
				_PAD_GHOST),
		"pressed": _box(selected, Color(0, 0, 0, 0), DesignTokens.RADIUS_SMALL,
				_PAD_GHOST),
		"disabled": _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), DesignTokens.RADIUS_SMALL,
				_PAD_GHOST),
		"focus": _focus_box(accent),
	})
	theme.set_color("font_color", "GhostButton", colors[Palette.KEY_TEXT_SECONDARY])
	theme.set_color("font_hover_color", "GhostButton", primary)
	theme.set_color("icon_normal_color", "GhostButton", colors[Palette.KEY_TEXT_SECONDARY])
	theme.set_color("icon_hover_color", "GhostButton", primary)
	theme.set_color("icon_pressed_color", "GhostButton", primary)
	theme.set_color("icon_focus_color", "GhostButton", primary)

	# SegmentButton — one option inside a segmented control (toggle button).
	var seg_margins := _PAD_CONTROL
	_set_stylebox_variation(theme, "Button", "SegmentButton", {
		"normal": _box(base, border, DesignTokens.RADIUS_SMALL, seg_margins),
		"hover": _box(hover, border, DesignTokens.RADIUS_SMALL, seg_margins),
		"pressed": _box(selected, accent, DesignTokens.RADIUS_SMALL, seg_margins),
		"hover_pressed": _box(selected, accent, DesignTokens.RADIUS_SMALL, seg_margins),
		"disabled": _box(base, border, DesignTokens.RADIUS_SMALL, seg_margins),
		"focus": _focus_box(accent),
	})
	theme.set_color("font_color", "SegmentButton", colors[Palette.KEY_TEXT_SECONDARY])
	theme.set_color("font_hover_color", "SegmentButton", primary)
	theme.set_color("font_pressed_color", "SegmentButton", accent)
	theme.set_color("font_hover_pressed_color", "SegmentButton", accent)
	theme.set_font("font", "SegmentButton", Typography.sans_medium())
	theme.set_font_size("font_size", "SegmentButton", DesignTokens.FS_SMALL)

	# DangerButton — destructive, reversible-with-warning actions.
	_set_stylebox_variation(theme, "Button", "DangerButton", {
		"normal": _box(Color(0, 0, 0, 0), negative, DesignTokens.RADIUS_SMALL,
				_PAD_CONTROL),
		"hover": _box(Color(negative, 0.12), negative, DesignTokens.RADIUS_SMALL,
				_PAD_CONTROL),
		"pressed": _box(Color(negative, 0.2), negative, DesignTokens.RADIUS_SMALL,
				_PAD_CONTROL),
		"disabled": _box(Color(0, 0, 0, 0), border, DesignTokens.RADIUS_SMALL,
				_PAD_CONTROL),
		"focus": _focus_box(negative),
	})
	theme.set_color("font_color", "DangerButton", negative)
	theme.set_color("font_hover_color", "DangerButton", negative)
	theme.set_color("font_pressed_color", "DangerButton", negative)


static func _set_stylebox_variation(theme: Theme, base_type: String, type_name: String,
		boxes: Dictionary) -> void:
	theme.set_type_variation(type_name, base_type)
	for state: String in boxes:
		theme.set_stylebox(state, type_name, boxes[state])


# --- Panels, separators, scrollbars ---------------------------------------

static func _build_panels(theme: Theme, colors: Dictionary) -> void:
	var border: Color = colors[Palette.KEY_BORDER]
	theme.set_type_variation("PanelCard", "PanelContainer")
	theme.set_stylebox("panel", "PanelCard", _box(colors[Palette.KEY_BG_PANEL], border,
			DesignTokens.RADIUS_MEDIUM, _PAD_PANEL))

	# Badge — a small status chip ("PLANNED", "IMPLEMENTED").
	theme.set_type_variation("Badge", "PanelContainer")
	theme.set_stylebox("panel", "Badge", _box(Color(0, 0, 0, 0), border, DesignTokens.RADIUS_SMALL,
			_PAD_BADGE))


static func _build_separators(theme: Theme, colors: Dictionary) -> void:
	var line := StyleBoxLine.new()
	line.color = colors[Palette.KEY_BORDER]
	line.thickness = DesignTokens.BORDER_HAIRLINE
	theme.set_stylebox("separator", "HSeparator", line)
	var vline := StyleBoxLine.new()
	vline.color = colors[Palette.KEY_BORDER]
	vline.thickness = DesignTokens.BORDER_HAIRLINE
	vline.vertical = true
	theme.set_stylebox("separator", "VSeparator", vline)
	theme.set_constant("separation", "HSeparator", DesignTokens.BORDER_HAIRLINE)
	theme.set_constant("separation", "VSeparator", DesignTokens.BORDER_HAIRLINE)


static func _build_scrollbars(theme: Theme, colors: Dictionary) -> void:
	var track := StyleBoxEmpty.new()
	track.content_margin_left = DesignTokens.SPACE_4
	track.content_margin_right = DesignTokens.SPACE_4
	track.content_margin_top = DesignTokens.SPACE_4
	track.content_margin_bottom = DesignTokens.SPACE_4
	var grabber := _box(colors[Palette.KEY_BORDER_STRONG], Color(0, 0, 0, 0),
			DesignTokens.RADIUS_MEDIUM)
	var grabber_active := _box(colors[Palette.KEY_TEXT_TERTIARY], Color(0, 0, 0, 0),
			DesignTokens.RADIUS_MEDIUM)
	var grabber_pressed := _box(colors[Palette.KEY_ACCENT], Color(0, 0, 0, 0),
			DesignTokens.RADIUS_MEDIUM)
	for bar: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, track)
		theme.set_stylebox("scroll_focus", bar, track)
		theme.set_stylebox("grabber", bar, grabber)
		theme.set_stylebox("grabber_highlight", bar, grabber_active)
		theme.set_stylebox("grabber_pressed", bar, grabber_pressed)


static func _build_container_defaults(theme: Theme) -> void:
	for type_name: String in ["VBoxContainer", "HBoxContainer", "GridContainer"]:
		theme.set_constant("separation", type_name, DesignTokens.SPACE_8)
	theme.set_constant("h_separation", "GridContainer", DesignTokens.SPACE_16)
	theme.set_constant("v_separation", "GridContainer", DesignTokens.SPACE_12)


static func _build_tooltip(theme: Theme, colors: Dictionary) -> void:
	theme.set_type_variation("TooltipPanel", "PopupPanel")
	theme.set_stylebox("panel", "TooltipPanel", _box(colors[Palette.KEY_BG_PANEL],
			colors[Palette.KEY_BORDER_STRONG], DesignTokens.RADIUS_SMALL,
			_PAD_TOOLTIP))
	theme.set_type_variation("TooltipLabel", "Label")
	theme.set_font_size("font_size", "TooltipLabel", DesignTokens.FS_SMALL)
	theme.set_color("font_color", "TooltipLabel", colors[Palette.KEY_TEXT_SECONDARY])


# --- Stylebox helpers ------------------------------------------------------

static func _box(fill: Color, border: Color, radius: int, margins := Vector4.ZERO,
		border_width := -1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	if border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(DesignTokens.BORDER_HAIRLINE if border_width < 0 else border_width)
	box.content_margin_left = margins.x
	box.content_margin_top = margins.y
	box.content_margin_right = margins.z
	box.content_margin_bottom = margins.w
	return box


static func _focus_box(color: Color) -> StyleBoxFlat:
	var box := _box(Color(0, 0, 0, 0), color, DesignTokens.RADIUS_SMALL, Vector4.ZERO)
	box.draw_center = false
	return box
