extends ResponsiveScreen
## About & Credits.
##
## Content is loaded from `res://data/` so contributors can be added, and the
## build status kept current, without touching interface code. Human and
## AI-assisted contributions are listed in separate groups: a reader should
## never have to guess who or what produced a piece of the project.

signal back_requested()
signal navigate_requested(screen_id: String)


var _meta: Dictionary = {}
var _credits: Dictionary = {}

@onready var _header: AppHeader = %Header
@onready var _content: VBoxContainer = %Content


func _ready() -> void:
	super()
	_header.back_pressed.connect(func() -> void: back_requested.emit())
	_meta = DataLoader.load_dictionary("app_meta.json")
	_credits = DataLoader.load_dictionary("credits.json")
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_build_content()
	var data_link := Button.new()
	data_link.text = "About the data"
	data_link.theme_type_variation = &"GhostButton"
	data_link.tooltip_text = "Where the map comes from, and its licence"
	data_link.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	data_link.pressed.connect(func() -> void: navigate_requested.emit("about_data"))
	PressFeedback.attach(data_link)
	_content.add_child(data_link)


func _on_theme_changed(_palette_id: String) -> void:
	# Bullet markers are drawn from palette colours; rebuild the content rather
	# than caching references to every custom-coloured node.
	for child: Node in _content.get_children():
		child.queue_free()
	_build_content()


func on_layout_changed(_mode: int, is_short: bool, view_size: Vector2) -> void:
	_header.set_compact(is_short)
	var margin := DesignTokens.screen_margin(DesignTokens.layout_mode(view_size))
	var available := view_size.x - float(margin * 2) - DesignTokens.SPACE_24
	_content.custom_minimum_size.x = clampf(available, 240.0,
			float(DesignTokens.CONTENT_MEASURE_NARROW))


# --- Content ---------------------------------------------------------------

func _build_content() -> void:
	_build_project_section()
	_build_status_section()
	_build_credits_section()
	_build_built_with_section()
	_build_license_section()


func _build_project_section() -> void:
	var body := _add_section("THE PROJECT", "")
	for paragraph: Variant in DataLoader.get_typed(_meta, "about_paragraphs", TYPE_ARRAY, []):
		body.add_child(_paragraph(str(paragraph)))


func _build_status_section() -> void:
	var body := _add_section("DEVELOPMENT STATUS", "")
	body.add_child(_key_value_grid(DataLoader.get_typed(_meta, "status", TYPE_ARRAY, [])))
	body.add_child(HSeparator.new())
	body.add_child(_subheading("Implemented"))
	_add_bullet_list(body, DataLoader.get_typed(_meta, "implemented", TYPE_ARRAY, []), true)
	body.add_child(_subheading("Planned"))
	_add_bullet_list(body, DataLoader.get_typed(_meta, "planned_next", TYPE_ARRAY, []), false)
	var note := str(_meta.get("status_note", ""))
	if not note.is_empty():
		body.add_child(HSeparator.new())
		body.add_child(_paragraph(note))


func _build_credits_section() -> void:
	var body := _add_section("CREDITS", "")
	body.add_child(_subheading("Human contributors"))
	var human_rows: Array = []
	var creator: Variant = _credits.get("creator")
	if creator is Dictionary:
		human_rows.append({
			"name": str((creator as Dictionary).get("name", "")),
			"role": str((creator as Dictionary).get("role", "")),
		})
	for entry: Variant in DataLoader.get_typed(_credits, "human_contributors", TYPE_ARRAY, []):
		if entry is Dictionary:
			human_rows.append(entry)
	body.add_child(_key_value_grid(human_rows, "No other human contributors yet."))
	body.add_child(HSeparator.new())
	body.add_child(_subheading("AI-assisted contributions"))
	body.add_child(_key_value_grid(
			DataLoader.get_typed(_credits, "ai_assisted", TYPE_ARRAY, []),
			"No AI-assisted contributions recorded."))
	var asset_note := str(_credits.get("assets_note", ""))
	if not asset_note.is_empty():
		body.add_child(HSeparator.new())
		body.add_child(_paragraph(asset_note))


func _build_built_with_section() -> void:
	var body := _add_section("BUILT WITH", "")
	body.add_child(_key_value_grid(
			DataLoader.get_typed(_credits, "built_with", TYPE_ARRAY, []),
			"No third-party components recorded."))


func _build_license_section() -> void:
	var body := _add_section("LICENSING", "")
	body.add_child(_paragraph(str(_credits.get("license_note", ""))))


# --- Builders --------------------------------------------------------------

func _add_section(heading: String, description: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	section.add_child(_label(heading.to_upper(), "SectionHeading"))
	if not description.is_empty():
		section.add_child(_paragraph(description))
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelCard"
	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	panel.add_child(body)
	section.add_child(panel)
	_content.add_child(section)
	return body


func _key_value_grid(entries: Array, empty_text: String = "") -> Control:
	if entries.is_empty():
		return _paragraph(empty_text)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", DesignTokens.SPACE_24)
	grid.add_theme_constant_override("v_separation", DesignTokens.SPACE_8)
	for entry: Variant in entries:
		if not entry is Dictionary:
			continue
		var row: Dictionary = entry
		var name_label: Label
		if row.has("key"):
			name_label = _label(str(row.get("key", "")), "Caption")
		else:
			name_label = _label(str(row.get("name", "")), "FieldLabel")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(name_label)
		var detail: String = str(row.get("role", row.get("detail", row.get("value", ""))))
		var value_label := _label(detail, "Caption")
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value_label.custom_minimum_size.x = 160
		grid.add_child(value_label)
	return grid


func _add_bullet_list(parent: Node, entries: Array, implemented: bool) -> void:
	for entry: Variant in entries:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", DesignTokens.SPACE_8)
		var marker := ColorRect.new()
		marker.custom_minimum_size = Vector2(DesignTokens.BORDER_ACCENT, DesignTokens.SPACE_12)
		marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		marker.color = ThemeManager.color(Palette.KEY_ACCENT) if implemented \
				else ThemeManager.color(Palette.KEY_BORDER_STRONG)
		row.add_child(marker)
		var label := _label(str(entry), "BodySmall")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		parent.add_child(row)


func _subheading(text: String) -> Label:
	return _label(text.to_upper(), "Caption")


func _paragraph(text: String) -> Label:
	var label := _label(text, "Body")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label
