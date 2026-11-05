class_name MapInspector
extends PanelContainer
## The developer map inspector: what the map actually loaded for one record.
##
## Off by default and never enabled by a setting, so a player cannot stumble into it:
## the only ways in are the pause menu row and F4, and it starts hidden on every
## screen. It exists so a reviewer can answer "is this shape the dataset's, or did
## something invent it?" without reading logs — every number here is a count of what
## is in memory, not an estimate.
##
## Stable ID matters most: the same ID in a bug report, a save file and the atlas
## dataset is the same country, which is what makes a report reproducible.

var _rows: VBoxContainer


func _init() -> void:
	theme_type_variation = &"PanelCard"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", DesignTokens.SPACE_12)
	margin.add_theme_constant_override("margin_right", DesignTokens.SPACE_12)
	margin.add_theme_constant_override("margin_top", DesignTokens.SPACE_8)
	margin.add_theme_constant_override("margin_bottom", DesignTokens.SPACE_8)
	add_child(margin)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", DesignTokens.SPACE_4)
	margin.add_child(_rows)


## Fills the panel for `country_id`, or shows the reason it cannot. Values come from
## the loaded atlas, so an unloaded or empty record reads as a gap rather than zero.
func set_entry(atlas: WorldAtlas, country_id: String) -> void:
	_clear()
	_heading("Map inspector")
	if atlas == null or not atlas.is_ready():
		_row("No atlas loaded", "Caption")
		return
	var record := atlas.registry.get_country(country_id)
	if record == null:
		_row("Stable ID", "not selected")
		return
	_row("Stable ID", record.id)
	_row("Name", record.name)
	_row("Source type", record.type)
	var polygons := atlas.geometry.polygon_count_of(record.id)
	var vertices := atlas.geometry.vertex_count_of(record.id)
	_row("Polygons", str(polygons))
	_row("Vertices", str(vertices))
	_row("Shape present", "yes" if atlas.geometry.has_country(record.id) else "no")


## How many key/value rows are showing, for the tests.
func row_count() -> int:
	return _rows.get_child_count()


func _row(label: String, value: String) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	var key := Label.new()
	key.text = label
	key.theme_type_variation = &"FieldLabel"
	line.add_child(key)
	var val := Label.new()
	val.text = value
	val.theme_type_variation = &"Mono"
	line.add_child(val)
	_rows.add_child(line)


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Eyebrow"
	_rows.add_child(label)


func _clear() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
