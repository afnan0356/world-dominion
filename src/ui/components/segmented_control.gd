class_name SegmentedControl
extends HBoxContainer
## A row of mutually exclusive options ("Midnight / Parchment").
##
## Chosen over a dropdown because every option stays visible with one tap and
## the current value reads at a glance. Options are toggled buttons in one
## ButtonGroup, so keyboard and d-pad navigation work without extra code.

signal option_selected(option_id: String)

const _MIN_TOUCH_HEIGHT := DesignTokens.TOUCH_TARGET_MIN
const _DESKTOP_HEIGHT := DesignTokens.CONTROL_HEIGHT

var _buttons: Array[Button] = []
var _selected_id: String = ""


func _ready() -> void:
	add_theme_constant_override("separation", DesignTokens.SPACE_4)
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_equalise_segment_widths.call_deferred()


## Uneven segment widths read as sloppy, and the widest label is the only thing
## that should set the size. Widths are measured once the control is inside the
## tree, so the active theme's fonts and paddings are already applied.
func _equalise_segment_widths() -> void:
	if _buttons.size() < 2:
		return
	var widest := 0.0
	for button: Button in _buttons:
		widest = maxf(widest, button.get_combined_minimum_size().x)
	for button: Button in _buttons:
		button.custom_minimum_size.x = widest


## Builds the segments. `options` is an array of {id, label} dictionaries.
func setup(options: Array, selected_id: String) -> void:
	_clear()
	var group := ButtonGroup.new()
	var height := _MIN_TOUCH_HEIGHT if PlatformInfo.has_touchscreen() else _DESKTOP_HEIGHT
	for option: Variant in options:
		if not option is Dictionary:
			push_error("SegmentedControl: options must be dictionaries.")
			continue
		var entry: Dictionary = option
		var button := Button.new()
		button.text = str(entry.get("label", ""))
		button.theme_type_variation = &"SegmentButton"
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_ALL
		button.custom_minimum_size = Vector2(0, height)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("option_id", str(entry.get("id", "")))
		button.tooltip_text = str(entry.get("tooltip", ""))
		button.toggled.connect(_on_button_toggled.bind(button))
		add_child(button)
		_buttons.append(button)
	set_selected(selected_id, false)
	if is_node_ready():
		_equalise_segment_widths.call_deferred()


func set_selected(option_id: String, notify: bool = false) -> void:
	_selected_id = option_id
	for button: Button in _buttons:
		button.set_pressed_no_signal(str(button.get_meta("option_id")) == option_id)
	if notify:
		option_selected.emit(option_id)


func get_selected_id() -> String:
	return _selected_id


func button_count() -> int:
	return _buttons.size()


## Puts keyboard focus on the first segment, so a panel that opens on this control
## can be operated with Tab and Space without a pointer.
func focus_first() -> void:
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _on_button_toggled(is_pressed: bool, button: Button) -> void:
	if not is_pressed:
		return
	var option_id := str(button.get_meta("option_id"))
	if option_id == _selected_id:
		return
	_selected_id = option_id
	option_selected.emit(option_id)


func _clear() -> void:
	for button: Button in _buttons:
		button.queue_free()
	_buttons.clear()
