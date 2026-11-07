class_name CountryInfoPanel
extends VBoxContainer
## The country dossier panel: what the atlas knows about the selected country, and
## nothing it does not.
##
## The panel is a renderer, not a source of truth. `CountryDossier` decides which
## sections and fields exist and which values are gaps; this file only walks them
## and applies the design system. Sections the project has not implemented yet are
## listed by name and marked as unimplemented, so a player can see the shape of the
## game without being shown a single invented number.
##
## The panel keeps the source's political classification verbatim (type,
## sovereignty, note) instead of interpreting it: disputed and dependent units are
## labelled as the dataset labels them, and this project takes no position.

## Emitted when the player asks to put this country beside others. The panel does not
## own navigation: the screen that hosts it decides where the comparison lives, so the
## atlas and the game can both reuse the same panel.
signal compare_requested(country_id: String)

var _record: CountryRecord
var _dossier: CountryDossier
var _compare_button: Button
var _context: Dictionary = {}
var _content: VBoxContainer
var _built := false


func _ready() -> void:
	_ensure_built()
	# A caller may have chosen a country before this panel entered the tree (the country
	# panel builds its dossier while it is still being prepared). Entering the tree must not
	# wipe that choice.
	if _record == null:
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


func dossier() -> CountryDossier:
	return _dossier


## Atlas facts the record does not own (polygon counts, dataset version, …). The
## panel stores them so re-selecting a country does not need a second call.
func set_context(context: Dictionary) -> void:
	_context = context.duplicate()
	if _record != null:
		show_country(_record)


## Shows a country, or the empty state when `record` is null.
func show_country(record: CountryRecord, context: Dictionary = {}) -> void:
	_ensure_built()
	_clear()
	_record = record
	if not context.is_empty():
		_context = context.duplicate()
	if record == null:
		show_empty()
		return
	_dossier = CountryDossier.build(record, _context)
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	var tile := FlagTile.new()
	tile.name = "Flag"
	tile.show_country(record.id, record.iso_a2)
	header.add_child(tile)
	var name_label := _label(_dossier.title, "ScreenTitleCompact")
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	_content.add_child(header)
	if not _dossier.subtitle.is_empty():
		var long_label := _label(_dossier.subtitle, "Caption")
		long_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(long_label)
	for section: CountryDossier.Section in _dossier.sections:
		_content.add_child(_section_block(section))
	_content.add_child(_planned_block())
	_content.add_child(_compare_row())


func show_empty() -> void:
	_ensure_built()
	_clear()
	_compare_button = null
	_record = null
	_dossier = null
	_content.add_child(_label("No nation selected", "FieldLabel"))
	var hint := _label(
		"Tap a country on the map or search for one. The dossier shows only "
		+ "what the atlas actually records.", "Caption")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(hint)


func show_unavailable(reason: String) -> void:
	_ensure_built()
	_clear()
	_compare_button = null
	_record = null
	_dossier = null
	_content.add_child(_label("Atlas unavailable", "FieldLabel"))
	var message := _label(reason, "Caption")
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(message)


## Number of children the panel has built; the tests use it to prove the dossier
## is actually populated and to prove the empty state is not.
## The "Compare" button, or null on the empty state. Tests press it with a synthetic
## key event to prove the path works without a mouse.
func compare_button() -> Button:
	return _compare_button


func row_count() -> int:
	return 0 if _content == null else _content.get_child_count()


## True when a planned (unimplemented) section is on screen. Serves the honesty
## requirement: the panel must say what the game does not have yet.
func shows_planned_sections() -> bool:
	return _dossier != null


func _section_block(section: CountryDossier.Section) -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", DesignTokens.SPACE_4)
	var heading := _label(section.title.to_upper(), "SectionHeading")
	block.add_child(heading)
	if not section.fields.is_empty():
		block.add_child(_field_grid(section.fields))
	if not section.note.is_empty():
		var note := _label(section.note, "Caption")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		block.add_child(note)
	return block


## Planned systems are named, never simulated: a player who reads this panel must
## not believe the game tracks population or military strength.
func _planned_block() -> VBoxContainer:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", DesignTokens.SPACE_4)
	block.add_child(_label("PLANNED", "SectionHeading"))
	var names: PackedStringArray = []
	for planned: CountryDossier.Section in CountryDossier.planned_sections():
		names.append(planned.title)
	var summary := _label(
		"Not implemented in this build: %s. " % " · ".join(names)
		+ "These systems are not simulated and hold no state. Where the source gives a "
		+ "reference figure, the Key figures group shows it as a baseline; the game never "
		+ "changes it.", "Caption")
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	block.add_child(summary)
	return block


func _field_grid(fields: Array[CountryDossier.Field]) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", DesignTokens.SPACE_16)
	grid.add_theme_constant_override("v_separation", DesignTokens.SPACE_4)
	for field: CountryDossier.Field in fields:
		_add_row(grid, field)
	return grid


func _add_row(grid: GridContainer, field: CountryDossier.Field) -> void:
	var key_label := _label(field.label.to_upper(), "SectionHeading")
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	grid.add_child(key_label)
	var value_label := _label(field.value, "BodySmall")
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.custom_minimum_size.x = 120
	if not field.recorded:
		value_label.add_theme_color_override("font_color",
				ThemeManager.color(Palette.KEY_TEXT_TERTIARY))
	grid.add_child(value_label)


## One keyboard-reachable button, sized for a finger, that asks the host screen for a
## comparison. It is the only control this panel owns.
func _compare_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	_compare_button = Button.new()
	_compare_button.text = "Compare this country"
	_compare_button.tooltip_text = "Put this country beside up to two others"
	_compare_button.custom_minimum_size = Vector2(0, DesignTokens.TOUCH_TARGET_MIN)
	_compare_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compare_button.pressed.connect(_on_compare_pressed)
	row.add_child(_compare_button)
	return row


func _on_compare_pressed() -> void:
	if _record != null:
		compare_requested.emit(_record.id)


func _clear() -> void:
	_compare_button = null
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
