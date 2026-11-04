class_name AtlasBackdrop
extends Control
## Procedural background for the application shell.
##
## Original artwork, drawn with vector primitives rather than imported textures:
## a set of concentric chart rings with meridians emerging from the right edge —
## a hint of a world map without depicting one, since no map exists yet. The
## rings are drawn at a very low contrast so interface text always wins, and a
## shader adds a soft vignette plus dithering to keep large gradients clean.
##
## Everything here reacts to the active palette, so both themes share one
## implementation instead of two near-identical images.

## Ring radii as a fraction of the smaller viewport dimension.
const RING_SCALES: Array[float] = [0.58, 0.72, 0.86, 1.0]
## Meridian half-widths as a fraction Of the outermost ring radius.
const MERIDIAN_SCALES: Array[float] = [0.22, 0.45, 0.68, 0.88]
## Segments per full ellipse. Enough to look smooth, cheap enough to redraw.
const SEGMENTS := 128
const GRID_ALPHA_DARK := 0.5
const GRID_ALPHA_LIGHT := 0.75

@onready var _vignette: ColorRect = %Vignette


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ThemeManager.theme_changed.connect(_on_theme_changed)
	resized.connect(_refresh)
	_refresh()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ThemeManager.color(Palette.KEY_BG_BASE))
	var rings := ThemeManager.color(Palette.KEY_BACKDROP_GRID)
	rings.a = GRID_ALPHA_DARK if ThemeManager.is_dark() else GRID_ALPHA_LIGHT

	var centre := Vector2(size.x * 1.06, size.y * 0.52)
	var base_radius := minf(size.x, size.y) * 0.82

	for ring_scale: float in RING_SCALES:
		var radius := base_radius * ring_scale
		_draw_ellipse(centre, radius, radius, rings)
	for meridian_scale: float in MERIDIAN_SCALES:
		var width := base_radius * meridian_scale
		_draw_ellipse(centre, width, base_radius, rings)


func _draw_ellipse(centre: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	var points := PackedVector2Array()
	points.resize(SEGMENTS + 1)
	for index in SEGMENTS + 1:
		var angle := TAU * float(index) / float(SEGMENTS)
		points[index] = centre + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
	draw_polyline(points, color, 1.0, true)


func _refresh() -> void:
	queue_redraw()
	if _vignette == null:
		return
	var tint := ThemeManager.color(Palette.KEY_BACKDROP_GLOW)
	var material := _vignette.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("edge_tint", tint)
	material.set_shader_parameter("strength", ThemeManager.vignette_strength())
	material.set_shader_parameter("inner_radius", 0.2)
	material.set_shader_parameter("outer_radius", 0.82)
	_vignette.color = Color.WHITE


func _on_theme_changed(_palette_id: String) -> void:
	_refresh()
