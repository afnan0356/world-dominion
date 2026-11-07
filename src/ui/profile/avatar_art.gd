class_name AvatarArt
extends RefCounted
## The twenty avatars, drawn by the game itself.
##
## No image files, no copied art, nothing downloaded: each avatar is a small composition of
## circles, polygons and arcs, chosen deterministically from its index, over a palette of
## two colours per avatar. Every one has a name so the choice is never carried by colour
## alone — the grid shows the name under the drawing and the chosen one carries a tick.
##
## The same drawing is used at 56 px in the grid and at 96 px in the profile header, so a
## player sees exactly the avatar they picked.

const COUNT := 20

## Names, in index order. Deliberately neutral and geographyless: a landmark, a weather, a
## plant. Nothing here claims anything about a country.
const NAMES: PackedStringArray = [
	"Sunrise", "Harbour", "Cedar", "Comet", "Lantern",
	"Mesa", "Willow", "Compass", "Ember", "Tide",
	"Prairie", "Beacon", "Owl", "Kite", "Delta",
	"Summit", "Anchor", "Reed", "Aurora", "Cairn",
]

## Two colours per avatar: the ground and the mark drawn on it. Chosen to stay readable
## against both themes, and never the only thing that identifies an avatar.
const COLORS: Array = [
	[Color("2f4858"), Color("f6ae2d")], [Color("33658a"), Color("f2f4cb")],
	[Color("386641"), Color("a3b18a")], [Color("3d348b"), Color("f7b801")],
	[Color("6b4e2e"), Color("f4e3b2")], [Color("8c5c3e"), Color("f0c987")],
	[Color("2a6041"), Color("d8f3dc")], [Color("1d3557"), Color("e9c46a")],
	[Color("7f2b2b"), Color("ffd166")], [Color("12556b"), Color("c9f2f0")],
	[Color("7a6a3e"), Color("f7f3c6")], [Color("403d39"), Color("f6bd60")],
	[Color("3a3a4a"), Color("d9d9e3")], [Color("264653"), Color("e76f51")],
	[Color("5f4b8b"), Color("f2e9e4")], [Color("4f5d75"), Color("eef0f2")],
	[Color("204b57"), Color("b8d8d8")], [Color("556b2f"), Color("efe7bc")],
	[Color("23395b"), Color("a8dadc")], [Color("57534e"), Color("e7e5e4")],
]


static func name_of(index: int) -> String:
	if index < 0 or index >= NAMES.size():
		return NAMES[0]
	return NAMES[index]


static func ground_of(index: int) -> Color:
	return _pair(index)[0]


static func mark_of(index: int) -> Color:
	return _pair(index)[1]


static func _pair(index: int) -> Array:
	var safe := clampi(index, 0, COUNT - 1)
	return COLORS[safe]


## Draws avatar `index` inside `rect` on `canvas`. Everything is proportional to the rect,
## so the same code draws the 40 px grid tile and the 96 px header.
static func draw_on(canvas: CanvasItem, index: int, rect: Rect2) -> void:
	var safe := clampi(index, 0, COUNT - 1)
	var ground := ground_of(safe)
	var mark := mark_of(safe)
	var centre := rect.position + rect.size * 0.5
	var radius: float = minf(rect.size.x, rect.size.y) * 0.5
	canvas.draw_circle(centre, radius, ground)
	canvas.draw_arc(centre, radius - 1.0, 0.0, TAU, 32, mark.darkened(0.35), 2.0, true)
	match safe % 5:
		0:  # a rising sun: half disc and rays
			canvas.draw_circle(centre + Vector2(0.0, radius * 0.28), radius * 0.42, mark)
			for ray in 5:
				var angle: float = PI + PI * (float(ray) / 4.0)
				var from: Vector2 = centre + Vector2(cos(angle), sin(angle)) * radius * 0.55
				var to: Vector2 = centre + Vector2(cos(angle), sin(angle)) * radius * 0.82
				canvas.draw_line(from, to, mark, 2.0, true)
		1:  # a harbour: a triangle sail over a horizontal waterline
			canvas.draw_colored_polygon(PackedVector2Array([
					centre + Vector2(0.0, -radius * 0.5),
					centre + Vector2(radius * 0.42, radius * 0.18),
					centre + Vector2(-radius * 0.12, radius * 0.18)]), mark)
			canvas.draw_line(centre + Vector2(-radius * 0.6, radius * 0.42),
					centre + Vector2(radius * 0.6, radius * 0.42), mark, 2.0, true)
		2:  # a cedar: a trunk and three stacked branches
			canvas.draw_line(centre + Vector2(0.0, radius * 0.55),
					centre + Vector2(0.0, -radius * 0.1), mark, 2.0, true)
			for step in 3:
				var width: float = radius * (0.55 - 0.14 * float(step))
				var y: float = -radius * 0.5 + radius * 0.28 * float(step)
				canvas.draw_colored_polygon(PackedVector2Array([
						centre + Vector2(-width, y + radius * 0.34),
						centre + Vector2(width, y + radius * 0.34),
						centre + Vector2(0.0, y)]), mark)
		3:  # a comet: a disc and a tail
			canvas.draw_circle(centre + Vector2(-radius * 0.2, -radius * 0.2), radius * 0.26, mark)
			canvas.draw_line(centre + Vector2(0.02 * radius, 0.0),
					centre + Vector2(radius * 0.62, radius * 0.42), mark, 2.0, true)
		4:  # a lantern: a diamond with a hanging line
			canvas.draw_colored_polygon(PackedVector2Array([
					centre + Vector2(0.0, -radius * 0.5),
					centre + Vector2(radius * 0.34, 0.0),
					centre + Vector2(0.0, radius * 0.46),
					centre + Vector2(-radius * 0.34, 0.0)]), mark)
			canvas.draw_line(centre + Vector2(0.0, -radius * 0.5),
					centre + Vector2(0.0, -radius * 0.8), mark, 2.0, true)
