class_name CountryInfoPanel
extends VBoxContainer
## What the atlas knows about the selected country — and nothing it does not.
##
## Every row is either a value taken from the dataset or an explicit "not recorded
## in source". There are no placeholder statistics: no population, GDP, military
## or approval figures exist in this build, so none are shown. Adding a sourced
## field later means adding one row here and one column in the data pipeline.
##
## The panel keeps the source's political classification verbatim (type,
## sovereignty, note) instead of interpreting it: disputed and dependent units are
## labelled as the dataset labels them, and this project takes no position.

var _record: CountryRecord
var _content: VBoxContainer
var _built := false


func _ready() -> void:
	_ensure_built()
	show_empty()


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	add_theme_constant_override("separation", DesignTokens.SPACE_8)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_content)


func selected_id() -> String:
	return "" if _record == null else _record.id


## Shows a country, or the empty state when `record` is null.
func show_country(record: CountryRecord) -> void:
	_ensure_built()
	_clear()
	_record = record
	if record == null:
		show_empty()
		return
	var name_label := _label(record.name, "ScreenTitleCompact")
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(name_label)

	if record.name_long != record.name:
		var long_label := _label(record.name_long, "Caption")
		long_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(long_label)

	_content.add_child(HSeparator.new())
	_content.add_child(_details_grid(record))

	if record.is_political_edge_case():
		var political := record.political_label()
		if not political.is_empty():
			var political_label := _label("Dataset classification: %s." % political, "Caption")
			political_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_content.add_child(political_label)

	_content.add_child(HSeparator.new())
	var source := _label(
		"Names, codes and classification come from Natural Earth 1:50m. "
		+ "Fields the dataset does not record are left empty on purpose.", "Caption")
	source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(source)


func show_empty() -> void:
	_ensure_built()
	_clear()
	_record = null
	_content.add_child(_label("No nation selected", "FieldLabel"))
	var hint := _label(
		"Tap a country on the map or search for one. The panel will show only "
		+ "what the atlas actually records.", "Caption")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(hint)


func show_unavailable(reason: String) -> void:
	_ensure_built()
	_clear()
	_record = null
	_content.add_child(_label("Atlas unavailable", "FieldLabel"))
	var message := _label(reason, "Caption")
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(message)


func row_count() -> int:
	return 0 if _content == null else _content.get_child_count()


func _details_grid(record: CountryRecord) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", DesignTokens.SPACE_16)
	grid.add_theme_constant_override("v_separation", DesignTokens.SPACE_8)
	_add_row(grid, "Region", _or_missing(record.region))
	_add_row(grid, "Subregion", _or_missing(record.subregion))
	_add_row(grid, "ISO", record.iso_label())
	_add_row(grid, "Capital", _or_missing(record.capital))
	_add_row(grid, "Classification", _or_missing(record.type))
	if record.sovereignty != record.name:
		_add_row(grid, "Source sovereignty", _or_missing(record.sovereignty))
	if not record.note.is_empty():
		_add_row(grid, "Source note", record.note)
	return grid


func _add_row(grid: GridContainer, key: String, value: String) -> void:
	var key_label := _label(key.to_upper(), "SectionHeading")
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	grid.add_child(key_label)
	var value_label := _label(value, "BodySmall")
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.custom_minimum_size.x = 120
	if value.begins_with("Not recorded"):
		value_label.add_theme_color_override("font_color",
				ThemeManager.color(Palette.KEY_TEXT_TERTIARY))
	grid.add_child(value_label)


func _or_missing(value: String) -> String:
	return value if not value.is_empty() else "Not recorded in source"


func _clear() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
