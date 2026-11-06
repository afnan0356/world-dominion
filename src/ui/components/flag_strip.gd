class_name FlagStrip
extends ScrollContainer
## The bottom flag strip: one tile per record in the chosen group, in A–Z order.
##
## Swiping moves it a page at a time and it **snaps** to the page it lands nearest, so a
## thumb-flick never leaves the strip half-way between countries. With reduced motion the
## selection jumps instead of sliding, which is the same rule the rest of the interface uses.
##
## The selected tile is marked three ways — a tick, the word "Selected" in its tooltip and a
## heavier border — so the state is never carried by colour alone.

signal country_chosen(country_id: String)

const ITEM_WIDTH := 72
## A 390-pixel-tall phone cannot spare 88 pixels for a strip. The compact strip keeps the
## same rows and the same tap behaviour at the smallest comfortable touch size.
const ITEM_WIDTH_COMPACT := 48
const PAGE_ITEMS := 6

var _row: HBoxContainer
var _ids := PackedStringArray()
var _selected_id := ""
var _compact := false
var _item_width := ITEM_WIDTH


func _ready() -> void:
	if _row == null:
		_build()


func _build() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	custom_minimum_size = Vector2(0, _strip_height())
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	add_child(_row)


## Shortens the strip for a short window. Called by the screen whenever the layout changes,
## so the choice is made once, from the space available, and not from a device name.
func set_compact(compact: bool) -> void:
	if compact == _compact:
		return
	_compact = compact
	_item_width = ITEM_WIDTH_COMPACT if compact else ITEM_WIDTH
	custom_minimum_size = Vector2(0, _strip_height())
	if _row == null:
		return
	for child: Node in _row.get_children():
		var button := child as Button
		if button != null:
			button.custom_minimum_size = Vector2(_item_width, _item_width)


func is_compact() -> bool:
	return _compact


func item_width() -> int:
	return _item_width


func _strip_height() -> float:
	return float(_item_width) + (8.0 if _compact else 16.0)


## Fills the strip with the records of `group_id`, in A–Z order.
func show_group(registry: CountryRegistry, _group_id: String, group_records: Array) -> void:
	_ensure_row()
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_ids = PackedStringArray()
	for entry: Variant in group_records:
		var country_id: String = str(entry)
		var record: CountryRecord = registry.get_country(country_id)
		if record == null:
			continue
		_ids.append(country_id)
		_row.add_child(_item(record))
	scroll_horizontal = 0


func item_ids() -> PackedStringArray:
	return _ids


func item_count() -> int:
	return _ids.size()


func selected_id() -> String:
	return _selected_id


## Marks a record as chosen. Does nothing for a record the strip does not show.
func set_selected(country_id: String) -> bool:
	if not _ids.has(country_id):
		return false
	_selected_id = country_id
	for child: Node in _row.get_children():
		var button: Button = child as Button
		if button == null:
			continue
		var is_selected: bool = str(button.get_meta("country_id", "")) == country_id
		button.set_meta("selected", is_selected)
		var mark: Label = button.get_node_or_null("Mark") as Label
		if mark != null:
			mark.text = "✓" if is_selected else ""
		button.add_theme_constant_override("outline_size", 2 if is_selected else 0)
	snap_to_selection()
	return true


## Scrolls so the selected tile is the leftmost visible one, one page at a time.
func snap_to_selection() -> void:
	var index: int = _ids.find(_selected_id)
	if index < 0:
		return
	var page: int = int(index / PAGE_ITEMS) * PAGE_ITEMS
	var target: float = float(page * (ITEM_WIDTH + DesignTokens.SPACE_8))
	if Settings.get_motion_mode() == Settings.MOTION_REDUCED:
		scroll_horizontal = int(target)
		return
	var tween: Tween = create_tween()
	tween.tween_property(self, "scroll_horizontal", int(target), 0.18)


## Swipe handling: a drag moves the content with the finger, and letting go snaps to the
## nearest page. Mouse wheels and the scrollbar keep working through the parent class.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		scroll_horizontal = int(maxf(0.0, float(scroll_horizontal)
				- (event as InputEventScreenDrag).relative.x))
		return
	if event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		_snap_to_nearest_page()


func _snap_to_nearest_page() -> void:
	var page_width: float = float(PAGE_ITEMS * (_item_width + DesignTokens.SPACE_8))
	var page: float = round(float(scroll_horizontal) / page_width)
	scroll_horizontal = int(page * page_width)


func _ensure_row() -> void:
	if _row == null:
		_build()


func _item(record: CountryRecord) -> Button:
	var button := Button.new()
	button.name = "Flag_%s" % record.id
	button.set_meta("country_id", record.id)
	button.custom_minimum_size = Vector2(_item_width, _item_width)
	button.tooltip_text = record.name
	button.theme_type_variation = &"GhostButton"
	button.pressed.connect(func() -> void:
		set_selected(record.id)
		country_chosen.emit(record.id))
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	button.add_child(column)
	var tile := FlagTile.new()
	tile.name = "Flag"
	column.add_child(tile)
	tile.show_country(record.id, record.iso_a2)
	var code := Label.new()
	code.name = "Code"
	code.text = record.iso_a2 if not record.iso_a2.is_empty() else record.id
	code.theme_type_variation = &"Mono"
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(code)
	var mark := Label.new()
	mark.name = "Mark"
	mark.text = ""
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(mark)
	return button
