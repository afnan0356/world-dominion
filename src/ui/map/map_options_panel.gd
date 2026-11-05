class_name MapOptionsPanel
extends Control
## The map display panel: the options that change what the map *draws*.
##
## Everything in here is a display choice. None of it changes the atlas, a hit box,
## a campaign or a save; that is why the panel can live on both the campaign screen
## and the setup screen without either one learning a new rule.
##
## The panel is built from the same components as the settings screen — rows with a
## title, a plain-language description and a segmented control — so it inherits the
## theme, the touch-target sizes and the focus order instead of inventing its own.
## It is operable by mouse, touch and keyboard: Escape closes it, Tab walks the
## controls, and Space/Enter changes the focused one.

signal closed()

const SETTING_ROW := preload("res://src/ui/components/setting_row.tscn")
const SEGMENTED := preload("res://src/ui/components/segmented_control.tscn")

const ON := "on"
const OFF := "off"

var _map: Node
var _card: PanelContainer
var _labels_row: SegmentedControl
var _borders_row: SegmentedControl
var _graticule_row: SegmentedControl
var _capitals_row: SegmentedControl
var _reference_row: SegmentedControl
var _detail_row: SegmentedControl
var _return_focus: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_card = PanelContainer.new()
	_card.theme_type_variation = &"PanelCard"
	_card.custom_minimum_size = Vector2(380.0, 0.0)
	center.add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	_card.add_child(column)

	column.add_child(_label("MAP DISPLAY", "Eyebrow"))
	column.add_child(_wrapped("These choices change how the map is drawn. They never "
			+ "change where a country is or which country a tap selects."))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 280.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.name = "Body"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", DesignTokens.SPACE_16)
	scroll.add_child(body)

	_labels_row = _add_row(body, "Country labels", "All labels, or only the most "
			+ "important ones when the map feels crowded.")
	_borders_row = _add_row(body, "Borders", "The line between two countries. Turn "
			+ "them off for a softer map; the coastline stays.")
	_capitals_row = _add_row(body, "Capital markers", "The small ring that marks a "
			+ "capital city.")
	_graticule_row = _add_row(body, "Grid lines", "Fine lines of latitude and "
			+ "longitude, every 15 degrees.")
	_reference_row = _add_row(body, "Equator and tropics", "The equator and the two "
			+ "tropics, dashed.")
	_detail_row = _add_row(body, "Reduced detail", "For a slower device: fewer labels, "
			+ "thinner lines, no coastline shading. Taps still land on the same country.")

	_labels_row.setup(_labelled_options(), MapOptions.labels())
	_borders_row.setup(_on_off_options(), _id_of(MapOptions.borders()))
	_capitals_row.setup(_on_off_options(), _id_of(MapOptions.capitals()))
	_graticule_row.setup(_on_off_options(), _id_of(MapOptions.graticule()))
	_reference_row.setup(_on_off_options(), _id_of(MapOptions.reference_lines()))
	_detail_row.setup(_on_off_options(),
			_id_of(Settings.get_map_detail() == SettingsSchema.DETAIL_REDUCED))

	_labels_row.option_selected.connect(func(value: String) -> void:
		MapOptions.set_labels(value)
		_apply())
	_borders_row.option_selected.connect(func(value: String) -> void:
		MapOptions.set_borders(value == ON)
		_apply())
	_capitals_row.option_selected.connect(func(value: String) -> void:
		MapOptions.set_capitals(value == ON)
		_apply())
	_graticule_row.option_selected.connect(func(value: String) -> void:
		MapOptions.set_graticule(value == ON)
		_apply())
	_reference_row.option_selected.connect(func(value: String) -> void:
		MapOptions.set_reference_lines(value == ON)
		_apply())
	_detail_row.option_selected.connect(func(value: String) -> void:
		Settings.set_map_detail(SettingsSchema.DETAIL_REDUCED if value == ON
				else SettingsSchema.DETAIL_FULL)
		_apply())

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(actions)
	var done := Button.new()
	done.text = "Done"
	done.theme_type_variation = &"PrimaryButton"
	done.custom_minimum_size = Vector2(96.0, DesignTokens.TOUCH_TARGET_MIN)
	done.tooltip_text = "Close the map display panel. Escape does the same."
	done.pressed.connect(close)
	actions.add_child(done)


## Shows the panel and applies the stored options to `map_view` once, so opening
## the panel on a fresh map is not needed for the options to take effect.
func open(map_view: Node) -> void:
	_map = map_view
	_sync()
	_return_focus = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	visible = true
	move_to_front()
	if _labels_row != null:
		_labels_row.focus_first()


func close() -> void:
	visible = false
	if _return_focus != null and is_instance_valid(_return_focus):
		_return_focus.grab_focus()
	_return_focus = null
	closed.emit()


func is_open() -> bool:
	return visible


## Applies the stored options to the map that was handed to `open()`. Screens call
## this after a settings change rather than each of them remembering the wiring.
func apply_to_map(map_view: Node = null) -> void:
	var target: Node = map_view if map_view != null else _map
	MapOptions.apply_to(target)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			accept_event()
			close()


func _apply() -> void:
	apply_to_map()


## Re-reads the store so the panel always shows what the map is actually doing.
func _sync() -> void:
	if _labels_row == null:
		return
	_labels_row.set_selected(MapOptions.labels())
	_borders_row.set_selected(_id_of(MapOptions.borders()))
	_capitals_row.set_selected(_id_of(MapOptions.capitals()))
	_graticule_row.set_selected(_id_of(MapOptions.graticule()))
	_reference_row.set_selected(_id_of(MapOptions.reference_lines()))
	_detail_row.set_selected(_id_of(
			Settings.get_map_detail() == SettingsSchema.DETAIL_REDUCED))


func _add_row(body: VBoxContainer, title: String, description: String) -> SegmentedControl:
	var row: SettingRow = SETTING_ROW.instantiate()
	var control := SEGMENTED.instantiate() as SegmentedControl
	control.custom_minimum_size.y = DesignTokens.TOUCH_TARGET_MIN
	row.setup(title, description, control)
	body.add_child(row)
	return control


func _labelled_options() -> Array:
	var options: Array = []
	for value: String in SettingsSchema.LABEL_DENSITY_LABELS:
		options.append({"id": value, "label": SettingsSchema.LABEL_DENSITY_LABELS[value]})
	return options


func _on_off_options() -> Array:
	return [{"id": ON, "label": "On"}, {"id": OFF, "label": "Off"}]


func _id_of(value: bool) -> String:
	return ON if value else OFF


func _label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label


func _wrapped(text: String) -> Label:
	var label := _label(text, "Caption")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 340.0
	return label
