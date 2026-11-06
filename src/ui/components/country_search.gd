class_name CountrySearch
extends VBoxContainer
## Search field for the atlas.
##
## Queries the registry (never the map) and lists at most six matches. Each result
## is a focusable button, so the search works with keyboard only; Enter picks the
## first match, Escape clears. Choosing a result emits the country id — what
## happens next (selecting + focusing the map) belongs to the screen.

signal country_chosen(country_id: String)
signal query_changed(query: String)
## Emitted when the result list opens or closes, so a host screen can position
## the list as an overlay above the map instead of letting it push the layout.
signal results_visibility_changed(visible: bool)

const MAX_RESULTS := 6
## 48 is the touch target (Milestone 05); the compact layout keeps 44 because a
## landscape phone loses that row from the map, and the field still clears the 40 px
## the layout was designed around.
const FIELD_HEIGHT := 48

var _registry: CountryRegistry
var _field: LineEdit
var _panel: PanelContainer
var _list: VBoxContainer
var _empty: Label
var _built := false
var _result_ids: PackedStringArray = []
var _active_result := -1
var _panel_attached := true


func _ready() -> void:
	_ensure_built()


func setup(registry: CountryRegistry) -> void:
	_registry = registry
	_ensure_built()
	_refresh()


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	add_theme_constant_override("separation", DesignTokens.SPACE_4)
	_field = LineEdit.new()
	_field.theme_type_variation = &"SearchField"
	_field.placeholder_text = "Search nations or ISO codes"
	_field.clear_button_enabled = true
	_field.custom_minimum_size.y = FIELD_HEIGHT
	_field.text_changed.connect(_on_text_changed)
	_field.text_submitted.connect(_on_text_submitted)
	_field.gui_input.connect(_on_field_input)
	_field.tooltip_text = ("Search by country name or ISO code. Up/Down moves through "
			+ "results, Enter selects, Escape clears.")
	add_child(_field)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", DesignTokens.SPACE_4)
	margin.add_theme_constant_override("margin_right", DesignTokens.SPACE_4)
	margin.add_theme_constant_override("margin_top", DesignTokens.SPACE_4)
	margin.add_theme_constant_override("margin_bottom", DesignTokens.SPACE_4)
	_panel.add_child(margin)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 0)
	margin.add_child(_list)
	_empty = _make_label("", "Caption")
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.add_theme_constant_override("line_spacing", DesignTokens.SPACE_4)
	margin.add_child(_empty)
	ThemeManager.theme_changed.connect(_on_theme_changed)


func _panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = ThemeManager.color(Palette.KEY_BG_PANEL)
	box.border_color = ThemeManager.color(Palette.KEY_BORDER_STRONG)
	box.set_border_width_all(DesignTokens.BORDER_HAIRLINE)
	box.set_corner_radius_all(DesignTokens.RADIUS_SMALL)
	box.border_width_top = DesignTokens.BORDER_ACCENT
	return box


# --- Public API ------------------------------------------------------------

func set_query(text: String, notify: bool = true) -> void:
	_ensure_built()
	if _field.text == text:
		return
	_field.text = text
	if notify:
		_on_text_changed(text)
	else:
		_refresh()


func current_query() -> String:
	return "" if _field == null else _field.text.strip_edges()


func clear() -> void:
	set_query("")


## Short layouts shrink the field rather than losing it.
func set_compact(compact: bool) -> void:
	_ensure_built()
	_field.custom_minimum_size.y = 44.0 if compact else float(FIELD_HEIGHT)


func focus_field() -> void:
	if _field != null:
		_field.grab_focus()
		_field.caret_column = _field.text.length()


func is_list_visible() -> bool:
	return _panel != null and _panel.visible


func visible_result_ids() -> PackedStringArray:
	return _result_ids


## Detaches the result list so a screen can parent it above the map. Returns null
## when the list was already taken (or never built).
func take_results_panel() -> PanelContainer:
	_ensure_built()
	if _panel == null or not _panel_attached:
		return _panel
	if _panel.get_parent() == self:
		remove_child(_panel)
	_panel_attached = false
	return _panel


## True when the "no nation matches" message is showing.
func empty_state_visible() -> bool:
	return _empty != null and _empty.visible


## The n-th result button, or null. Used by the keyboard path and by tests.
func result_button(index: int) -> Button:
	if index < 0 or index >= _list.get_child_count():
		return null
	return _list.get_child(index) as Button


## Records currently listed, for tests and status lines.
func result_titles() -> PackedStringArray:
	var out := PackedStringArray()
	for child: Node in _list.get_children():
		var label := child.get_node_or_null("Row/Name") as Label
		if label != null:
			out.append(label.text)
	return out


# --- Internals -------------------------------------------------------------

func _on_text_changed(text: String) -> void:
	_refresh()
	query_changed.emit(text.strip_edges())


func _refresh() -> void:
	if _list == null:
		return
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_result_ids = PackedStringArray()
	var query := current_query()
	if query.is_empty() or _registry == null:
		_set_panel_visible(false)
		return
	var matches := _registry.search(query)
	for index in mini(matches.size(), MAX_RESULTS):
		var record: CountryRecord = matches[index]
		_result_ids.append(record.id)
		_list.add_child(_make_result_button(record))
	_empty.visible = matches.is_empty()
	_empty.text = "No nation matches \"%s\". Try a different spelling or an ISO code." % query
	_set_panel_visible(true)


func _make_result_button(record: CountryRecord) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"SearchResult"
	button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	button.tooltip_text = "%s — %s" % [record.name, record.region]
	button.pressed.connect(_on_result_pressed.bind(record.id))
	button.gui_input.connect(_on_result_input.bind(_result_ids.size() - 1))
	button.focus_entered.connect(_on_result_focused.bind(_result_ids.size() - 1))
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = DesignTokens.SPACE_8
	row.offset_right = -DesignTokens.SPACE_8
	row.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	button.add_child(row)
	var name_label := _make_label(record.name, "BodySmall")
	name_label.name = "Name"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	var code := record.iso_a3 if record.has_iso_a3() else record.region
	var code_label := _make_label(code, "Mono")
	code_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	code_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	code_label.add_theme_color_override("font_color", ThemeManager.color(Palette.KEY_TEXT_TERTIARY))
	row.add_child(code_label)
	return button


func _on_result_pressed(country_id: String) -> void:
	_set_panel_visible(false)
	country_chosen.emit(country_id)


func _set_panel_visible(visible: bool) -> void:
	if _panel == null or _panel.visible == visible:
		return
	_panel.visible = visible
	results_visibility_changed.emit(visible)


func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	if not _result_ids.is_empty():
		_on_result_pressed(_result_ids[0])


## Keyboard path: Down from the field walks into the results, Up walks back out.
## Without this the result list is only reachable with a mouse, which would make
## search unusable for keyboard and controller players.
func _on_field_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		clear()
		_set_panel_visible(false)
		_field.release_focus()
		_field.accept_event()
	elif event.is_action_pressed("ui_down") and not _result_ids.is_empty():
		_focus_result(0)
		_field.accept_event()


func _on_result_input(event: InputEvent, index: int) -> void:
	if event.is_action_pressed("ui_down"):
		_focus_result(index + 1)
		_focus_result_accept()
	elif event.is_action_pressed("ui_up"):
		if index <= 0:
			focus_field()
		else:
			_focus_result(index - 1)
		_focus_result_accept()
	elif event.is_action_pressed("ui_cancel"):
		clear()
		_set_panel_visible(false)
		focus_field()


func _focus_result_accept() -> void:
	var owner_button := get_viewport().gui_get_focus_owner()
	if owner_button is Control:
		(owner_button as Control).accept_event()


## Focuses the index-th result, clamped to the list. Public for the keyboard path
## and for tests.
func _focus_result(index: int) -> void:
	if _result_ids.is_empty():
		return
	var clamped := clampi(index, 0, _result_ids.size() - 1)
	var button := result_button(clamped)
	if button == null:
		return
	_active_result = clamped
	button.grab_focus()


func active_result_index() -> int:
	return _active_result


func _on_result_focused(index: int) -> void:
	_active_result = index


func _on_theme_changed(_palette_id: String) -> void:
	if _panel != null:
		_panel.add_theme_stylebox_override("panel", _panel_style())


func _make_label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
