class_name AvatarGallery
extends GridContainer
## The twenty avatars as a selectable grid.
##
## Each cell is a button carrying the drawing **and** the avatar's name, and the chosen one
## also shows a tick and a heavier border — so the choice never rests on colour alone.

signal avatar_chosen(index: int)

const CELL := 56

var _buttons: Array[Button] = []
var _selected := 0


func _ready() -> void:
	columns = 5
	add_theme_constant_override("h_separation", DesignTokens.SPACE_8)
	add_theme_constant_override("v_separation", DesignTokens.SPACE_8)
	if _buttons.is_empty():
		_build()


func _build() -> void:
	for index in AvatarArt.COUNT:
		var button := Button.new()
		button.name = "Avatar_%d" % (index + 1)
		# 80 × 88: the 56 px drawing, its name and the tick, with room for all three. Taller
		# than it is wide because the label and mark sit under the drawing.
		button.custom_minimum_size = Vector2(CELL + 24.0, CELL + 32.0)
		button.theme_type_variation = &"GhostButton"
		button.tooltip_text = AvatarArt.name_of(index)
		button.set_meta("avatar_index", index)
		button.pressed.connect(_choose.bind(index))
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		button.add_child(column)
		var glyph := AvatarGlyph.new()
		glyph.name = "Glyph"
		glyph.index = index
		glyph.custom_minimum_size = Vector2(CELL, CELL)
		glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(glyph)
		var label := Label.new()
		label.name = "Label"
		label.text = AvatarArt.name_of(index)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.theme_type_variation = &"Caption"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(label)
		var mark := Label.new()
		mark.name = "Mark"
		mark.text = ""
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.theme_type_variation = &"Mono"
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(mark)
		add_child(button)
		_buttons.append(button)
	set_selected(_selected)


func _choose(index: int) -> void:
	set_selected(index)
	avatar_chosen.emit(index)


func set_selected(index: int) -> void:
	_selected = clampi(index, 0, AvatarArt.COUNT - 1)
	for position in _buttons.size():
		var button: Button = _buttons[position]
		var chosen := position == _selected
		button.set_meta("selected", chosen)
		button.add_theme_constant_override("outline_size", 2 if chosen else 0)
		var mark: Label = button.find_child("Mark", true, false) as Label
		if mark != null:
			mark.text = "✓" if chosen else ""
		button.tooltip_text = AvatarArt.name_of(position) + (" — selected" if chosen else "")


func selected_index() -> int:
	return _selected


func button_count() -> int:
	return _buttons.size()


func button_at(position: int) -> Button:
	if position < 0 or position >= _buttons.size():
		return null
	return _buttons[position]
