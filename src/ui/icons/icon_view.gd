class_name IconView
extends TextureRect
## One interface mark: a licensed icon when its file loads, a drawn shape when it does not.
##
## The fallback is deliberate, not decoration. Icons ship as files, and a file can be missing
## from an export, corrupt, or refused by a platform's SVG reader. When that happens the player
## should still see a mark that means the same thing — the drawn shapes this project used before
## it had licensed icons — rather than an empty space that makes a button look broken.

## The drawn shape used when the file is unavailable.
var fallback_shape: String = ""
## The meaning this view was asked for, for tests and debugging.
var meaning: String = ""

var _fallback: ShellIcon = null


func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Point the view at a meaning. `pixels` is the square size in interface pixels.
func setup(icon_meaning: String, pixels: int, colour: Color) -> void:
	meaning = icon_meaning
	custom_minimum_size = Vector2(pixels, pixels)
	var loaded := IconAtlas.texture_for(icon_meaning, pixels)
	if loaded != null:
		_clear_fallback()
		texture = loaded
		visible = true
		modulate = colour
		return
	_use_fallback(icon_meaning, pixels, colour)


## Tint without rebuilding: the texture is shared, the colour is not.
func set_tint(colour: Color) -> void:
	modulate = colour
	if _fallback != null:
		_fallback.modulate = colour


func using_fallback() -> bool:
	return _fallback != null


func fallback_node() -> ShellIcon:
	return _fallback


func _use_fallback(icon_meaning: String, pixels: int, colour: Color) -> void:
	texture = null
	var entry := IconAtlas.entry_for(icon_meaning)
	var shape := str(entry.get("shape", fallback_shape))
	if shape.is_empty():
		shape = "question"
	if _fallback == null:
		_fallback = ShellIcon.new()
		_fallback.shape = shape
		_fallback.custom_minimum_size = Vector2(pixels, pixels)
		_fallback.modulate = colour
		add_child(_fallback)
	else:
		_fallback.shape = shape
		_fallback.modulate = colour
		_fallback.custom_minimum_size = Vector2(pixels, pixels)
	_fallback.size = Vector2(pixels, pixels)


func _clear_fallback() -> void:
	if _fallback == null:
		return
	if _fallback.get_parent() == self:
		remove_child(_fallback)
	_fallback.queue_free()
	_fallback = null
