extends ResponsiveScreen
## The keyboard cheat sheet.
##
## The rows come from `Shortcuts.ENTRIES`, the same table the input code and the
## tests use. It is a screen rather than a tooltip because a player who wants to know
## what the keys do should be able to read the whole list at once, focused, with the
## keyboard they are asking about.

signal back_requested()

@onready var _header: AppHeader = %Header
@onready var _content: VBoxContainer = %Content


func _ready() -> void:
	super()
	_header.back_pressed.connect(func() -> void: back_requested.emit())
	_build_content()


func on_layout_changed(_mode: int, is_short: bool, view_size: Vector2) -> void:
	_header.set_compact(is_short)
	var margin := DesignTokens.screen_margin(DesignTokens.layout_mode(view_size))
	var available := view_size.x - float(margin * 2) - DesignTokens.SPACE_24
	_content.custom_minimum_size.x = clampf(available, 240.0,
			DesignTokens.CONTENT_MEASURE)


## Number of rows the sheet is showing, so a test can compare it with the table.
func row_count() -> int:
	var grid := _content.get_node_or_null("Grid") as GridContainer
	if grid == null:
		return 0
	# Three heading cells sit at the top of the grid; they are not shortcuts.
	return maxi(0, (grid.get_child_count() - 3) / 3)


func _build_content() -> void:
	var intro := Label.new()
	intro.text = Shortcuts.INTRO
	intro.theme_type_variation = &"Body"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(intro)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", DesignTokens.SPACE_24)
	grid.add_theme_constant_override("v_separation", DesignTokens.SPACE_8)
	_content.add_child(grid)
	for heading: String in ["Key", "Action", "Where"]:
		var label := Label.new()
		label.text = heading
		label.theme_type_variation = &"Eyebrow"
		grid.add_child(label)
	for entry: Array in Shortcuts.ENTRIES:
		var keys := Label.new()
		keys.text = str(entry[0])
		keys.theme_type_variation = &"Mono"
		grid.add_child(keys)
		var action := Label.new()
		action.text = str(entry[1])
		action.theme_type_variation = &"BodySmall"
		action.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action.custom_minimum_size.x = 260.0
		grid.add_child(action)
		var where := Label.new()
		where.text = str(entry[2])
		where.theme_type_variation = &"Caption"
		grid.add_child(where)
