class_name RecordList
extends VBoxContainer
## A list of records with a search box, optional filter chips and a real empty state.
##
## The list owns no content of its own: `set_items()` hands it records and a renderer, and it
## draws them. What it does own is the four things every list in this game must get right:
##
## * **Search.** Typing narrows the list by whatever `search_text` the caller gives each
##   record. Clearing the box restores everything; the box never hides itself, so the player
##   can always see why the list looks short.
## * **Filters.** A row of chips, one per filter the caller offers. Choosing one narrows
##   along a field the caller names; "All" always exists.
## * **Keyboard.** Up and Down move between rows and Enter activates the focused one, because
##   the rows are ordinary focusable buttons rather than labels.
## * **Empty and no-match states.** Those are different facts and they read differently:
##   nothing here yet, versus nothing matches what you typed.

signal row_activated(key: String)
signal filter_changed(filter_id: String)
signal query_changed(query: String)

const NO_FILTER := "all"

var search_text_key := "text"
var filter_field := "category"

var _search: LineEdit
var _chips: HBoxContainer
var _count: Label
var _rows: VBoxContainer
var _empty: Label
var _current_filter := NO_FILTER
var _items: Array = []
var _renderer: Callable = Callable()
var _searchable: Callable = Callable()


func _ready() -> void:
	if _rows != null:
		return
	add_theme_constant_override("separation", DesignTokens.SPACE_8)
	var tools := HBoxContainer.new()
	tools.name = "Tools"
	tools.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	add_child(tools)
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = Strings.t("list.search_placeholder")
	_search.tooltip_text = Strings.t("list.search")
	_search.clear_button_enabled = true
	_search.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(_on_query_changed)
	tools.add_child(_search)
	_count = Label.new()
	_count.name = "Count"
	_count.theme_type_variation = &"Caption"
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tools.add_child(_count)

	_chips = HBoxContainer.new()
	_chips.name = "Filters"
	_chips.add_theme_constant_override("separation", DesignTokens.SPACE_4)
	add_child(_chips)

	_empty = Label.new()
	_empty.name = "Empty"
	_empty.theme_type_variation = &"BodySmall"
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.visible = false
	add_child(_empty)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", DesignTokens.SPACE_4)
	scroll.add_child(_rows)


## Replaces the filter row. The "All" chip always exists and always comes first, so a list
## can never be left with a filter the player cannot undo.
func set_filters(filters: Array) -> void:
	_ready()
	for child: Node in _chips.get_children():
		child.queue_free()
	add_filter(NO_FILTER, Strings.t("list.filter_all"))
	var known := {NO_FILTER: true}
	for entry: Variant in filters:
		var filter_id := str((entry as Dictionary).get("id", ""))
		if filter_id.is_empty() or known.has(filter_id):
			continue
		known[filter_id] = true
		add_filter(filter_id, str((entry as Dictionary).get("label", filter_id)))
	_highlight_filters()


## The search box, so a panel can put the caret in it when it opens.
func query_field() -> LineEdit:
	_ready()
	return _search


## Adds one filter chip. `NO_FILTER` ("all") is added automatically by `setup()`.
func add_filter(filter_id: String, label: String) -> void:
	_ready()
	var button := Button.new()
	button.name = "Filter_%s" % filter_id
	button.text = label
	button.toggle_mode = true
	button.theme_type_variation = &"GhostButton"
	button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	button.set_meta("filter_id", filter_id)
	button.pressed.connect(func() -> void: set_filter(filter_id))
	PressFeedback.attach(button)
	_chips.add_child(button)
	_highlight_filters()


func setup(items: Array, renderer: Callable, searchable: Callable = Callable(),
		empty_text: String = "") -> void:
	_ready()
	_items = items
	_renderer = renderer
	_searchable = searchable
	_empty.text = empty_text if not empty_text.is_empty() else Strings.t("list.empty")
	if _chips.get_child_count() == 0:
		add_filter(NO_FILTER, Strings.t("list.filter_all"))
	refresh()


func set_items(items: Array) -> void:
	_items = items
	refresh()


func set_filter(filter_id: String) -> void:
	_current_filter = filter_id
	_highlight_filters()
	refresh()
	filter_changed.emit(filter_id)


func current_filter() -> String:
	return _current_filter


func query() -> String:
	_ready()
	return _search.text


func set_query(text: String) -> void:
	_ready()
	_search.text = text
	refresh()


## The records that survive the current filter and query. Public so a test can assert on the
## numbers the player sees rather than peeking at labels.
func visible_items() -> Array:
	var out: Array = []
	var needle := query().strip_edges().to_lower()
	for item: Variant in _items:
		if _current_filter != NO_FILTER:
			var value := str(_field(item, filter_field))
			if value != _current_filter:
				continue
		if not needle.is_empty():
			var haystack := str(_searchable.call(item)).to_lower() if _searchable.is_valid() \
					else str(_field(item, search_text_key)).to_lower()
			if not haystack.contains(needle):
				continue
		out.append(item)
	return out


func refresh() -> void:
	_ready()
	for child: Node in _rows.get_children():
		child.queue_free()
	var visible := visible_items()
	for index in visible.size():
		var row := _build_row(visible[index], index)
		_rows.add_child(row)
	_count.text = Strings.t("list.count", [visible.size(), _items.size()])
	# Two different facts, two different sentences: "nothing here yet" is not the same as
	# "nothing matches what you typed", and telling them apart is how a player knows whether
	# the list is empty or their search is.
	if _items.is_empty():
		_empty.text = Strings.t("list.empty")
		_empty.visible = true
	elif visible.is_empty():
		_empty.text = Strings.t("list.no_results", [query()])
		_empty.visible = true
	else:
		_empty.visible = false


func row_count() -> int:
	_ready()
	return _rows.get_child_count()


func _build_row(item: Variant, index: int) -> Control:
	var key := str(_field(item, "id"))
	var button := Button.new()
	button.name = "Row%03d" % index
	button.focus_mode = Control.FOCUS_ALL
	button.theme_type_variation = &"GhostButton"
	button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	button.set_meta("key", key)
	button.pressed.connect(func() -> void: row_activated.emit(key))
	PressFeedback.attach(button)
	var rendered: Variant = _renderer.call(item) if _renderer.is_valid() else null
	if rendered is Control:
		var control := rendered as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.set_anchors_preset(Control.PRESET_FULL_RECT)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_child(control)
	else:
		button.text = str(_field(item, search_text_key))
	return button


func _field(item: Variant, field: String) -> Variant:
	if item is Dictionary:
		return (item as Dictionary).get(field, "")
	return item.get(field) if item != null else ""


func _on_query_changed(text: String) -> void:
	refresh()
	query_changed.emit(text)


func _highlight_filters() -> void:
	for button: Node in _chips.get_children():
		var is_current := str(button.get_meta("filter_id", "")) == _current_filter
		(button as Button).set_pressed_no_signal(is_current)
		(button as Button).theme_type_variation = &"PrimaryButton" if is_current else &"GhostButton"
