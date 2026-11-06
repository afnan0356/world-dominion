extends ResponsiveScreen
## Country comparison: up to three countries side by side, read-only.
##
## Every number on this screen comes from `CountryStatistics`, which reads the
## generated `statistics.json`. The screen never computes, sorts by value, colours a
## winner or says "higher is better": the columns are the order the player chose and
## the rows are the indicator order in `CountryStatistics.INDICATORS`. A figure the
## source does not give is shown as an em dash with the word "Not available", never as
## zero — a zero would be a claim the source does not make.
##
## Reachable from the atlas dossier and from the in-game dossier (both host screens
## listen to `CountryInfoPanel.compare_requested`), so it is one screen and one
## implementation for keyboard, touch and gamepad alike.

signal back_requested()

## Three fits on a 640 px wide window without shrinking the type; a fourth would not.
const MAX_COUNTRIES := 3
const MISSING_TEXT := "—"

var _statistics: CountryStatistics
var _atlas: WorldAtlas
var _selected: PackedStringArray = []
## Cell text keyed "indicator|column", filled while the table is built. The tests read
## it instead of walking the scene tree, and it is the exact string a player sees.
var _table_cells: Dictionary = {}

@onready var _header: AppHeader = %Header
@onready var _content: VBoxContainer = %Content
@onready var _search: CountrySearch = %Search
@onready var _chips: HBoxContainer = %Chips
@onready var _table: GridContainer = %Table
@onready var _status: Label = %Status


func _ready() -> void:
	super()
	_header.back_pressed.connect(func() -> void: back_requested.emit())
	_atlas = WorldAtlas.load_default()
	_statistics = _atlas.statistics
	_search.setup(_atlas.registry)
	_search.country_chosen.connect(add_country)
	_rebuild()


func receive_params(params: Dictionary) -> void:
	var country_id := str(params.get("country_id", ""))
	if not country_id.is_empty():
		add_country(country_id)


func on_layout_changed(_mode: int, is_short: bool, view_size: Vector2) -> void:
	_header.set_compact(is_short)
	var margin := DesignTokens.screen_margin(DesignTokens.layout_mode(view_size))
	var available := view_size.x - float(margin * 2) - DesignTokens.SPACE_24
	_content.custom_minimum_size.x = clampf(available, 240.0, DesignTokens.CONTENT_MEASURE)


# --- what the tests ask -----------------------------------------------------

## The chosen ids, in the order the player added them.
func selected_ids() -> PackedStringArray:
	return _selected.duplicate()


func statistics() -> CountryStatistics:
	return _statistics


## The text in one cell: `cell_text("population", 0)` is the first column.
## An empty string means the cell was never built.
func cell_text(indicator_key: String, column: int) -> String:
	var key := "%s|%d" % [indicator_key, column]
	return str(_table_cells.get(key, ""))


## The as-of line under one cell: "2019", "map outline (derived)", or "" when missing.
func as_of_text(indicator_key: String, column: int) -> String:
	var key := "as_of|%s|%d" % [indicator_key, column]
	return str(_table_cells.get(key, ""))


func search_field() -> CountrySearch:
	return _search


func table() -> GridContainer:
	return _table


func status_text() -> String:
	return _status.text


# --- selection --------------------------------------------------------------

## Adds one country. Returns false when the country is unknown, already chosen, or
## the third column is full — the screen is read-only, so nothing else happens.
func add_country(country_id: String) -> bool:
	if country_id.is_empty() or _selected.has(country_id):
		return false
	if _selected.size() >= MAX_COUNTRIES:
		_status.text = "Three countries are already side by side. Remove one to add another."
		return false
	if _atlas == null or _atlas.registry == null or not _atlas.registry.has_country(country_id):
		_status.text = "That country is not in this build's world data."
		return false
	_selected.append(country_id)
	_search.clear()
	_rebuild()
	return true


func remove_country(country_id: String) -> bool:
	var index := _selected.find(country_id)
	if index < 0:
		return false
	_selected.remove_at(index)
	_rebuild()
	return true


func clear_countries() -> void:
	_selected.clear()
	_rebuild()


# --- building ---------------------------------------------------------------

func _rebuild() -> void:
	for child: Node in _chips.get_children():
		_chips.remove_child(child)
		child.queue_free()
	for child: Node in _table.get_children():
		_table.remove_child(child)
		child.queue_free()
	_table_cells.clear()
	_table.columns = _selected.size() + 1
	_build_chips()

	if _selected.is_empty():
		_status.text = ("Search for a country and add up to %d. Everything shown comes "
				% MAX_COUNTRIES) + "from the pinned source file, with the year it refers to."
		var empty := Label.new()
		empty.text = "No countries chosen yet."
		empty.theme_type_variation = "Caption"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_table.add_child(empty)
		return
	_status.text = "Read-only. Baseline reference data for the 2026 scenario start, not live."

	_table.add_child(_cell("Figure", "FieldLabel"))
	for country_id in _selected:
		var record: CountryRecord = _atlas.registry.get_country(country_id)
		_table.add_child(_cell(record.name if record != null else country_id, "FieldLabel"))
	for definition: Dictionary in _statistics.definitions():
		var key := str(definition["key"])
		var label := str(definition["label"])
		var unit := str(definition.get("unit", ""))
		_table.add_child(_cell("%s (%s)" % [label, unit], "BodySmall"))
		for column in _selected.size():
			_table.add_child(_figure_cell(str(_selected[column]), key))


func _build_chips() -> void:
	for country_id in _selected:
		var record: CountryRecord = _atlas.registry.get_country(country_id)
		var chip := Button.new()
		chip.text = "%s  ×" % (record.name if record != null else country_id)
		chip.tooltip_text = "Remove %s from the comparison" % country_id
		chip.custom_minimum_size = Vector2(0, DesignTokens.TOUCH_TARGET_MIN)
		chip.pressed.connect(func() -> void: remove_country(country_id))
		_chips.add_child(chip)


## One figure cell: the value, then the as-of line. A missing figure is an em dash
## with the words "Not available" — the same words the dossier uses.
func _figure_cell(country_id: String, key: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", DesignTokens.SPACE_4)
	box.custom_minimum_size.x = 132
	var column := _selected.find(country_id)
	var value: Variant = _statistics.value(country_id, key)
	if value == null:
		box.add_child(_cell(MISSING_TEXT, "BodySmall"))
		box.add_child(_cell("Not available", "Caption"))
		_table_cells["%s|%d" % [key, column]] = MISSING_TEXT
		_table_cells["as_of|%s|%d" % [key, column]] = ""
		return box
	var number := CountryStatistics.format_integer(int(value))
	box.add_child(_cell(number, "BodySmall"))
	var as_of := _statistics.as_of_label(country_id, key)
	var suffix := " (derived)" if _statistics.is_derived(country_id, key) else ""
	box.add_child(_cell(as_of + suffix, "Caption"))
	_table_cells["%s|%d" % [key, column]] = number
	_table_cells["as_of|%s|%d" % [key, column]] = as_of + suffix
	return box


func _cell(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
