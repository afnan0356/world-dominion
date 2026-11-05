class_name RegionFilter
extends HFlowContainer
## Region chips for the atlas. One region at a time, plus "All regions".
##
## The list comes from the dataset's own classification (`CountryRegistry.regions()`),
## so the filters cannot drift from the country data. Selecting a chip emits the
## region id; the screen decides what to do with it.

signal region_changed(region: String)

const CHIP_HEIGHT := 40
const ALL_REGIONS := ""

var _registry: CountryRegistry
var _group := ButtonGroup.new()
var _buttons: Dictionary = {}
var _active := ""
var _built := false
var _compact := false


func _ready() -> void:
	_ensure_built()


func setup(registry: CountryRegistry) -> void:
	_registry = registry
	_ensure_built()
	_rebuild()


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	add_theme_constant_override("h_separation", DesignTokens.SPACE_8)
	add_theme_constant_override("v_separation", DesignTokens.SPACE_8)
	_group.allow_unpress = false


func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_buttons.clear()
	_add_chip(ALL_REGIONS, "All regions")
	if _registry != null:
		for region: String in _registry.regions():
			_add_chip(region, region)
	set_region(_active)


func _add_chip(region: String, label_text: String) -> void:
	var chip := Button.new()
	chip.text = label_text
	chip.toggle_mode = true
	chip.button_group = _group
	chip.theme_type_variation = &"Chip"
	chip.custom_minimum_size.y = 32.0 if _compact else float(CHIP_HEIGHT)
	chip.focus_mode = Control.FOCUS_ALL
	chip.tooltip_text = "Show only %s" % label_text.to_lower() \
			if not region.is_empty() else "Show every region"
	chip.pressed.connect(_on_chip_pressed.bind(region))
	add_child(chip)
	_buttons[region] = chip


func _on_chip_pressed(region: String) -> void:
	if region == _active:
		return
	_active = region
	region_changed.emit(region)


## Sets the active region without emitting, used when the screen resets state.
func set_region(region: String) -> void:
	var target := region if _buttons.has(region) else ALL_REGIONS
	_active = target
	var chip: Button = _buttons.get(target)
	if chip != null:
		chip.set_pressed_no_signal(true)


## Short layouts use a lower chip so the row does not eat the map.
func set_compact(compact: bool) -> void:
	_compact = compact
	for region: String in _buttons:
		var chip: Button = _buttons[region]
		chip.custom_minimum_size.y = 32.0 if compact else float(CHIP_HEIGHT)


func active_region() -> String:
	return _active


func chip_count() -> int:
	return _buttons.size()


func chip_for(region: String) -> Button:
	return _buttons.get(region) as Button
