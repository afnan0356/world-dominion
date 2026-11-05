class_name MapControls
extends HBoxContainer
## Overlay controls for the world map: zoom in, zoom out, and "fit the world".
##
## Buttons are real focusable buttons (mouse, touch, keyboard and gamepad all
## work) rather than gesture-only affordances, because a player must be able to
## operate the map without discovering a pinch. Every button has a tooltip that
## names the action in words.

signal zoom_in_requested()
signal zoom_out_requested()
signal reset_requested()
signal options_requested()

const BUTTON_SIZE := 40

var _zoom_in: Button
var _zoom_out: Button
var _fit: Button
var _options: Button


func _ready() -> void:
	add_theme_constant_override("separation", DesignTokens.SPACE_4)
	alignment = BoxContainer.ALIGNMENT_END
	_zoom_in = _make_button("+", "Zoom in")
	_zoom_out = _make_button("-", "Zoom out")
	_fit = _make_button("Fit", "Fit the whole world on screen")
	_fit.custom_minimum_size.x = 56
	_zoom_in.pressed.connect(func() -> void: zoom_in_requested.emit())
	_zoom_out.pressed.connect(func() -> void: zoom_out_requested.emit())
	_fit.pressed.connect(func() -> void: reset_requested.emit())
	_options = _make_button("Map", "Map display: labels, borders, grid lines and capital markers")
	_options.custom_minimum_size.x = 56
	_options.pressed.connect(func() -> void: options_requested.emit())


func _make_button(text_value: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.tooltip_text = tooltip
	button.theme_type_variation = &"MapButton"
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.focus_mode = Control.FOCUS_ALL
	PressFeedback.attach(button)
	add_child(button)
	return button


## Compact maps shrink the controls rather than covering the world with chrome.
func set_compact(compact: bool) -> void:
	var height := 32 if compact else BUTTON_SIZE
	for button: Button in [_zoom_in, _zoom_out, _fit, _options]:
		if button != null:
			button.custom_minimum_size.y = height


func button_count() -> int:
	return get_child_count()
