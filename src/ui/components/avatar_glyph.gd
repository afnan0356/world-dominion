class_name AvatarGlyph
extends Control
## One avatar drawing, at whatever size its parent gives it. Drawing lives in `AvatarArt`,
## so the grid tile and the profile header are the same picture.

var index := 0:
	set(value):
		index = clampi(value, 0, AvatarArt.COUNT - 1)
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(48, 48)


func _draw() -> void:
	AvatarArt.draw_on(self, index, Rect2(Vector2.ZERO, size))
