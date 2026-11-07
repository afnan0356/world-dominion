class_name ResponsiveScreen
extends Control
## Base class for full-window views.
##
## Responsibilities kept here (and out of individual screens):
##   * fill the screen host;
##   * translate the current viewport size into a layout mode and apply the
##     screen margins from the design tokens;
##   * expose hooks that subclasses override for their own breakpoint rules.
##
## Screens never branch on device type — only on the space they were given, which
## is what makes the same scene work on a phone in landscape, a tablet and a
## desktop window that has been resized.

## Identifier used by `ScreenRouter`. Set per scene.
@export var screen_id: String = ""

@onready var safe_area: MarginContainer = get_node_or_null("%SafeArea") as MarginContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_apply_layout)
	_apply_layout()
	# A subclass calls `super()` first and builds its reading column after, so on the very first
	# pass `on_layout_changed` finds no column to measure and the scene's own 720 px minimum
	# wins. On a 640 px window that minimum is wider than the window and every label inside it
	# runs off the right edge — not until somebody resizes, which on a phone never happens.
	# Re-applying once on the next idle frame measures what the subclass just built; the pass
	# is idempotent, so the extra call costs nothing.
	_apply_layout.call_deferred()


## Called by `ScreenRouter` after the screen is shown. Keyboard and gamepad
## players should be able to act without reaching for Tab, so the first
## available control takes focus. Touch-first devices skip it: a focus ring
## nobody asked for reads as a defect. Screens can override to pick another.
func focus_initial() -> void:
	if PlatformInfo.has_touchscreen():
		return
	var target := _first_focusable(self)
	if target != null:
		target.grab_focus()


func _first_focusable(node: Node) -> Control:
	for child: Node in node.get_children():
		var item := child as Control
		if item == null or not item.is_visible_in_tree():
			continue
		if item.focus_mode != Control.FOCUS_NONE:
			if not (item is BaseButton) or not (item as BaseButton).disabled:
				return item
		var nested := _first_focusable(item)
		if nested != null:
			return nested
	return null


## Called by `ScreenRouter` when the screen appears; used for staggered entrances.
func play_entrance() -> void:
	pass


## Override to react to size changes. `mode` is a DesignTokens.LayoutMode,
## `is_short` flags scarce vertical space.
func on_layout_changed(_mode: int, _is_short: bool, _view_size: Vector2) -> void:
	pass


func _apply_layout() -> void:
	if safe_area == null:
		return
	var view_size := size
	var mode := DesignTokens.layout_mode(view_size)
	var short := DesignTokens.is_short(view_size)
	var horizontal := DesignTokens.screen_margin(mode)
	var vertical := DesignTokens.SPACE_12 if short else DesignTokens.screen_margin(mode)
	safe_area.add_theme_constant_override("margin_left", horizontal)
	safe_area.add_theme_constant_override("margin_right", horizontal)
	safe_area.add_theme_constant_override("margin_top", vertical)
	safe_area.add_theme_constant_override("margin_bottom", vertical)
	on_layout_changed(mode, short, view_size)
