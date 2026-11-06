class_name CountryPickerPanel
extends VBoxContainer
## The country picker's list half: a group chooser drawn from the committed region groups, an
## A–Z index, and the records of the chosen group for the chosen letter.
##
## **Virtualisation, honestly described:** only one letter's records are built at a time — at
## most a few dozen rows — so scrolling a group of ninety countries never creates ninety
## controls. The A–Z index is the way from one letter to another, which is also how the player
## expects to browse a long list.
##
## Search is the registry's own: it already matches names, aliases, alpha-2 and alpha-3 codes,
## so the picker does not re-invent matching rules.

signal country_previewed(country_id: String)
signal country_chosen(country_id: String)

const GROUPS_PATH := "res://data/world/picker_regions.json"
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

var _registry: CountryRegistry
var _groups: Array = []
var _group_of: Dictionary = {}
var _group_id := ""
var _letter := "A"
var _query := ""
var _selected_id := ""

var _group_select: OptionButton
var _search: LineEdit
var _letter_row: HFlowContainer
var _list: VBoxContainer
var _count_label: Label


func _ready() -> void:
	_build()
	_load_groups()


func setup(registry: CountryRegistry) -> void:
	_registry = registry
	_refresh()


# --- Testable state -------------------------------------------------------

func group_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for group: Variant in _groups:
		out.append(str((group as Dictionary).get("id", "")))
	return out


func group_label(group_id: String) -> String:
	for group: Variant in _groups:
		if str((group as Dictionary).get("id", "")) == group_id:
			return str((group as Dictionary).get("label", group_id))
	return group_id


## The committed group a record belongs to, or "" when it has none.
func group_of(country_id: String) -> String:
	return str(_group_of.get(country_id, ""))


func current_group() -> String:
	return _group_id


func current_letter() -> String:
	return _letter


func visible_ids() -> PackedStringArray:
	var out := PackedStringArray()
	if _list == null:
		return out
	for child: Node in _list.get_children():
		var id := str(child.get_meta("country_id", ""))
		if not id.is_empty():
			out.append(id)
	return out


func available_letters() -> PackedStringArray:
	var letters := PackedStringArray()
	for country_id: String in _group_members(_group_id):
		var record: CountryRecord = _registry.get_country(country_id) if _registry else null
		if record == null:
			continue
		var first := record.name.substr(0, 1).to_upper()
		if not letters.has(first):
			letters.append(first)
	letters.sort()
	return letters


func selected_id() -> String:
	return _selected_id


# --- Behaviour ------------------------------------------------------------

func select_group(group_id: String) -> void:
	if group_id.is_empty() or not group_ids().has(group_id):
		return
	_group_id = group_id
	_query = ""
	if _search != null:
		_search.text = ""
	var letters := available_letters()
	_letter = letters[0] if not letters.is_empty() else "A"
	if _group_select != null:
		for index in _group_select.item_count:
			if str(_group_select.get_item_metadata(index)) == group_id:
				_group_select.select(index)
				break
	_refresh()


func select_letter(letter: String) -> void:
	if letter.is_empty():
		return
	_letter = letter.substr(0, 1).to_upper()
	_refresh()


func set_query(text: String) -> void:
	_query = text.strip_edges()
	if _search != null and _search.text != text:
		_search.text = text
	_refresh()


func set_selected(country_id: String) -> void:
	_selected_id = country_id
	_refresh()


func choose(country_id: String) -> void:
	if _registry == null or _registry.get_country(country_id) == null:
		return
	country_chosen.emit(country_id)


# --- Construction ---------------------------------------------------------

func _build() -> void:
	add_theme_constant_override("separation", DesignTokens.SPACE_8)
	var title := Label.new()
	title.name = "Title"
	title.text = Strings.t("picker.title")
	title.theme_type_variation = &"SectionHeading"
	add_child(title)

	_group_select = OptionButton.new()
	_group_select.name = "GroupSelect"
	_group_select.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	_group_select.item_selected.connect(func(index: int) -> void:
		select_group(str(_group_select.get_item_metadata(index))))
	add_child(_group_select)

	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = Strings.t("picker.search")
	_search.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	_search.text_changed.connect(set_query)
	add_child(_search)

	_letter_row = HFlowContainer.new()
	_letter_row.name = "JumpIndex"
	_letter_row.tooltip_text = Strings.t("picker.jump")
	add_child(_letter_row)

	_count_label = Label.new()
	_count_label.name = "Count"
	_count_label.theme_type_variation = &"Caption"
	add_child(_count_label)

	var scroll := ScrollContainer.new()
	scroll.name = "ListScroll"
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func _load_groups() -> void:
	var text := FileAccess.get_file_as_string(GROUPS_PATH)
	if text.is_empty():
		push_warning("CountryPickerPanel: %s is missing." % GROUPS_PATH)
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	_groups = data.get("groups", [])
	var records: Variant = data.get("records", {})
	if records is Dictionary:
		for country_id: Variant in (records as Dictionary):
			_group_of[str(country_id)] = str(((records as Dictionary)[country_id]
					as Dictionary).get("group", ""))
	if _group_select != null:
		_group_select.clear()
		for group: Variant in _groups:
			_group_select.add_item(str((group as Dictionary).get("label", "")))
			_group_select.set_item_metadata(_group_select.item_count - 1,
					str((group as Dictionary).get("id", "")))
	if not _groups.is_empty():
		_group_id = str((_groups[0] as Dictionary).get("id", ""))
	var letters := available_letters()
	_letter = letters[0] if not letters.is_empty() else "A"


func _group_members(group_id: String) -> PackedStringArray:
	var out := PackedStringArray()
	if group_id.is_empty():
		return out
	for country_id: String in _group_of:
		if str(_group_of[country_id]) == group_id:
			out.append(country_id)
	out.sort()
	return out


func _refresh() -> void:
	if _list == null or _registry == null:
		return
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var ids := PackedStringArray()
	if not _query.is_empty():
		for record: CountryRecord in _registry.search(_query):
			ids.append(record.id)
	else:
		for country_id: String in _group_members(_group_id):
			var record: CountryRecord = _registry.get_country(country_id)
			if record != null and record.name.substr(0, 1).to_upper() == _letter:
				ids.append(record.id)
	ids.sort()
	_rebuild_letters()
	for country_id: String in ids:
		_list.add_child(_row(country_id))
	_count_label.text = ""
	if not _selected_id.is_empty():
		var chosen: CountryRecord = _registry.get_country(_selected_id)
		if chosen != null:
			_count_label.text = Strings.t("picker.selected", [chosen.name])
	if ids.is_empty():
		var empty := Label.new()
		empty.name = "Empty"
		empty.text = Strings.t("picker.no_results")
		empty.theme_type_variation = &"Caption"
		_list.add_child(empty)


func _rebuild_letters() -> void:
	if _letter_row == null:
		return
	for child: Node in _letter_row.get_children():
		_letter_row.remove_child(child)
		child.queue_free()
	var available := available_letters()
	for letter: String in LETTERS:
		var button := Button.new()
		button.name = "Letter_%s" % letter
		button.text = letter
		button.custom_minimum_size = Vector2(DesignTokens.CONTROL_HEIGHT,
				DesignTokens.CONTROL_HEIGHT)
		button.focus_mode = Control.FOCUS_ALL
		button.disabled = not available.has(letter)
		button.theme_type_variation = &"PrimaryButton" if letter == _letter else &"GhostButton"
		button.pressed.connect(select_letter.bind(letter))
		_letter_row.add_child(button)


func _row(country_id: String) -> Button:
	var record: CountryRecord = _registry.get_country(country_id)
	var button := Button.new()
	button.name = "Row_%s" % country_id
	button.set_meta("country_id", country_id)
	button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	button.theme_type_variation = &"SearchResult"
	button.tooltip_text = record.name if record != null else country_id
	button.pressed.connect(func() -> void:
		country_previewed.emit(country_id)
		choose(country_id))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = DesignTokens.SPACE_8
	row.offset_right = -DesignTokens.SPACE_8
	row.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	button.add_child(row)
	var tile := FlagTile.new()
	tile.name = "Flag"
	if record != null:
		tile.show_country(record.id, record.iso_a2)
	row.add_child(tile)
	var label := Label.new()
	label.text = record.name if record != null else country_id
	label.theme_type_variation = &"BodySmall"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	var code := Label.new()
	code.text = ("✓ " if country_id == _selected_id else "") + (
			record.iso_a3 if record != null and record.has_iso_a3() else "")
	code.theme_type_variation = &"Mono"
	code.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	code.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(code)
	return button
