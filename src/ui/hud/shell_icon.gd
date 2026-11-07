class_name ShellIcon
extends Control
## A small mark drawn in code: the fallback for the licensed icons, and the mark used where no
## icon file fits.
##
## Milestone 11 added the game-icons.net set (`assets/icons/game_icons/`, CC BY 3.0 — see
## `THIRD_PARTY_LICENSES.md`), drawn through `IconView`. This file stays because a file can be
## missing, corrupt or refused by a platform's SVG reader, and a button must still show a mark:
## `IconView` draws the shape named here when the file does not load. Every shape is a handful
## of polygons and lines in the theme's own colours, so it is sharp on any display.
##
## Each mark is named in `data/ui/icon_crosswalk.json`, beside the icon file for the same
## meaning. A screen asks for a *meaning* ("messages"), never for a picture.

const CROSSWALK_PATH := "res://data/ui/icon_crosswalk.json"
## Parsed once per run, like the flag crosswalk next door.
static var _crosswalk: Dictionary = {}
static var _loaded := false

@export var icon_name := "avatar":
	set(value):
		icon_name = value
		queue_redraw()

## When set, this shape is drawn instead of the one the crosswalk names. `IconView` uses it to
## draw a fallback for a meaning the crosswalk does not know, and tests use it to prove a mark
## exists when its file does not.
var shape := "":
	set(value):
		shape = value
		queue_redraw()

var _shape := "bust"


func _init() -> void:
	custom_minimum_size = Vector2(20, 20)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


## The crosswalk, as committed. Empty when the file is missing — a missing file then draws
## nothing rather than a wrong picture.
static func crosswalk() -> Dictionary:
	if _loaded:
		return _crosswalk
	_loaded = true
	var text := FileAccess.get_file_as_string(CROSSWALK_PATH)
	if text.is_empty():
		return _crosswalk
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var icons: Variant = (parsed as Dictionary).get("icons")
		if icons is Dictionary:
			_crosswalk = icons
	return _crosswalk


## Every meaning the crosswalk knows, sorted, for the test that keeps it in step with the
## screens.
static func names() -> PackedStringArray:
	var out := PackedStringArray()
	for key: Variant in crosswalk().keys():
		out.append(str(key))
	out.sort()
	return out


## Every shape this file knows how to draw. The crosswalk may only name these, which is the
## freshness check: adding a meaning without adding a drawing fails the suite.
static func shapes() -> PackedStringArray:
	return PackedStringArray(["bust", "envelope", "page", "bars", "question", "globe",
			"pillar", "link", "shield", "spark"])


static func shape_for(meaning: String) -> String:
	var entry: Variant = crosswalk().get(meaning)
	if entry is Dictionary:
		return str((entry as Dictionary).get("shape", ""))
	return ""


func _draw() -> void:
	_shape = shape if not shape.is_empty() else shape_for(icon_name)
	var colour := get_theme_color("font_color", "Label")
	var box := Vector2(minf(size.x, size.y), minf(size.x, size.y))
	var origin := (size - box) * 0.5
	var thin := maxf(1.0, box.x * 0.09)
	var rect := Rect2(origin + box * 0.12, box * 0.76)
	match _shape:
		"bust":
			_draw_bust(origin, box, colour, thin)
		"envelope":
			draw_rect(rect, colour, false, thin)
			draw_line(rect.position, rect.position + Vector2(rect.size.x * 0.5,
					rect.size.y * 0.45), colour, thin)
			draw_line(rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.45),
					rect.position + Vector2(rect.size.x, 0.0), colour, thin)
		"page":
			draw_rect(rect, colour, false, thin)
			for index in 3:
				var y := rect.position.y + rect.size.y * (0.28 + 0.2 * index)
				draw_line(Vector2(rect.position.x + thin * 2.0, y),
						Vector2(rect.end.x - thin * 2.0, y), colour, thin)
		"bars":
			for index in 3:
				var y := rect.position.y + rect.size.y * (0.18 + 0.32 * index)
				draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), colour, thin)
		"question":
			draw_arc(Vector2(origin.x + box.x * 0.5, origin.y + box.y * 0.38),
					box.x * 0.22, PI, TAU * 0.92, 16, colour, thin)
			draw_line(Vector2(origin.x + box.x * 0.5, origin.y + box.y * 0.6),
					Vector2(origin.x + box.x * 0.5, origin.y + box.y * 0.72), colour, thin)
			draw_circle(Vector2(origin.x + box.x * 0.5, origin.y + box.y * 0.86), thin, colour)
		"globe":
			draw_arc(origin + box * 0.5, box.x * 0.36, 0.0, TAU, 32, colour, thin)
			draw_line(Vector2(origin.x + box.x * 0.14, origin.y + box.y * 0.5),
					Vector2(origin.x + box.x * 0.86, origin.y + box.y * 0.5), colour, thin)
			draw_arc(origin + box * 0.5, box.x * 0.36, PI * 1.5, PI * 2.5, 12, colour, thin)
		"pillar":
			draw_rect(rect, colour, false, thin)
			draw_line(Vector2(rect.position.x + rect.size.x * 0.33, rect.position.y),
					Vector2(rect.position.x + rect.size.x * 0.33, rect.end.y), colour, thin)
			draw_line(Vector2(rect.position.x + rect.size.x * 0.66, rect.position.y),
					Vector2(rect.position.x + rect.size.x * 0.66, rect.end.y), colour, thin)
		"link":
			draw_arc(Vector2(origin.x + box.x * 0.38, origin.y + box.y * 0.5), box.x * 0.2,
					0.0, TAU, 20, colour, thin)
			draw_arc(Vector2(origin.x + box.x * 0.62, origin.y + box.y * 0.5), box.x * 0.2,
					0.0, TAU, 20, colour, thin)
		"shield":
			var points := PackedVector2Array([
				Vector2(origin.x + box.x * 0.22, origin.y + box.y * 0.2),
				Vector2(origin.x + box.x * 0.78, origin.y + box.y * 0.2),
				Vector2(origin.x + box.x * 0.5, origin.y + box.y * 0.86)])
			draw_polyline(points, colour, thin)
			draw_line(points[0], points[2], colour, thin)
			draw_line(points[1], points[2], colour, thin)
		"spark":
			var centre := origin + box * 0.5
			for index in 4:
				var angle := TAU * float(index) / 4.0
				draw_line(centre, centre + Vector2(cos(angle), sin(angle)) * box.x * 0.38,
						colour, thin)
		_:
			# An unknown meaning draws a small neutral dot: visible, obviously not an icon,
			# and never a guess at the picture somebody meant.
			draw_circle(origin + box * 0.5, thin, colour)


func _draw_bust(origin: Vector2, box: Vector2, colour: Color, thin: float) -> void:
	draw_circle(Vector2(origin.x + box.x * 0.5, origin.y + box.y * 0.34), box.x * 0.17,
			colour, false, thin)
	draw_arc(Vector2(origin.x + box.x * 0.5, origin.y + box.y * 0.9), box.x * 0.3,
			PI, TAU, 20, colour, thin)
