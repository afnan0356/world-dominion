class_name WorldMapView
extends Control
## The interactive world map.
##
## Responsibilities are narrow on purpose: this control draws the atlas and turns
## pointer/keyboard input into camera moves and country activation. It does not
## own the selection, the search, the filters or the campaign — the screen above
## it does — and it contains no country-specific code. Every country is just an
## id with geometry and a colour role.
##
## Rendering: one cached `ArrayMesh` per country (its outline rings triangulated
## once) is drawn through the camera transform, so panning and zooming cost no
## vertex work at all. Holes are a second cached mesh drawn in the sea colour,
## which is what makes Lesotho read as a hole inside South Africa without any
## polygon boolean operations. Borders are polylines in world space with a width
## of `1 / zoom`, so they stay one pixel at every zoom level.
##
## Touch, mouse, trackpad and keyboard share the same `MapCamera`; there is no
## device-specific branch outside the input handlers below.

signal country_activated(country_id: String)
signal hover_changed(country_id: String)
signal view_changed()

const TAP_SLOP := 6.0
const HOVER_INTERVAL_MS := 70
const LABEL_LIMIT := 26
## Countries smaller than this on screen keep their fill but lose their outline:
## at that size a stroke is noise, and skipping it keeps a world view cheap.
const BORDER_MIN_PIXELS := 7.0

var atlas: WorldAtlas
var camera := MapCamera.new()

var _selected_id := ""
var _hovered_id := ""
var _show_labels := true
var _meshes: Dictionary = {}
var _hole_meshes: Dictionary = {}
var _dragging := false
var _drag_distance := 0.0
var _pointer := Vector2.ZERO
var _touches: Dictionary = {}
var _pinch_distance := 0.0
var _last_hover_ms := 0
var _visible_ids: PackedStringArray = []
var _label_font: Font
var _label_size := 11


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	camera.set_view_size(size)
	camera.changed.connect(_on_camera_changed)
	resized.connect(_on_resized)
	mouse_exited.connect(_on_mouse_exited)
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_refresh_fonts()


# --- Public API ------------------------------------------------------------

func set_atlas(value: WorldAtlas) -> void:
	atlas = value
	_meshes.clear()
	_hole_meshes.clear()
	camera.set_view_size(size)
	camera.reset()
	queue_redraw()


func selected_id() -> String:
	return _selected_id


func hovered_id() -> String:
	return _hovered_id


## Sets the highlighted country. Passing an unknown id clears the highlight,
## which keeps the "deselect with an empty tap" path free of special cases.
func set_selected(country_id: String) -> void:
	var resolved := country_id
	if not resolved.is_empty() and (atlas == null or not atlas.registry.has_country(resolved)):
		resolved = ""
	if resolved == _selected_id:
		return
	_selected_id = resolved
	queue_redraw()


func set_labels_visible(visible: bool) -> void:
	if visible == _show_labels:
		return
	_show_labels = visible
	queue_redraw()


func labels_visible() -> bool:
	return _show_labels


## Moves and zooms the camera so `country_id` fills the view. Returns false when
## the country is unknown or has no shape, so callers can report it honestly.
func focus_country(country_id: String, padding: float = 56.0) -> bool:
	if atlas == null or not atlas.registry.has_country(country_id):
		return false
	if not atlas.geometry.has_country(country_id):
		return false
	camera.focus_rect(atlas.geometry.bbox_of(country_id), padding)
	return true


## The country under a point in this control's local coordinates ("" for none).
func country_at_point(point: Vector2) -> String:
	if atlas == null or atlas.lookup == null:
		return ""
	var country_id := atlas.lookup.country_at_screen(point, camera)
	if not country_id.is_empty() and not atlas.registry.has_country(country_id):
		return ""
	return country_id


## Reports the country under a point as an activation. Tap release, touch release
## and tests all go through here, so "what a tap means" has one definition: the
## country id, or "" for empty water and empty space.
func tap(point: Vector2) -> String:
	var country_id := country_at_point(point)
	country_activated.emit(country_id)
	return country_id


func visible_country_ids() -> PackedStringArray:
	if _visible_ids.is_empty() and atlas != null and atlas.is_ready():
		return _collect_visible(camera.visible_rect(24.0))
	return _visible_ids


## Builds and caches the triangle meshes for `country_ids` and returns the cached
## vertex total. `_draw()` calls this lazily for what is on screen; the benchmark
## and the tests call it directly so mesh construction can be measured without a
## GPU.
func build_meshes_for(country_ids: PackedStringArray) -> int:
	for country_id: String in country_ids:
		_meshes_for(country_id, false)
		_meshes_for(country_id, true)
	return cached_vertex_count()


## Vertices in the cached meshes; used by the performance notes and tests.
func cached_vertex_count() -> int:
	var total := 0
	for key: Variant in _meshes:
		var mesh: ArrayMesh = _meshes[key]
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var arrays := mesh.surface_get_arrays(0)
		var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
		if vertices is PackedVector3Array:
			total += (vertices as PackedVector3Array).size()
	return total


# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	var water := _color(Palette.KEY_MAP_WATER)
	draw_rect(Rect2(Vector2.ZERO, size), water)
	_draw_graticule()
	if atlas == null or not atlas.is_ready():
		_draw_missing_data()
		return
	var world_transform := camera.transform()
	# 24 px of margin keeps shapes that straddle the edge from popping in.
	var visible := camera.visible_rect(24.0)
	_visible_ids = _collect_visible(visible)

	draw_set_transform_matrix(world_transform)
	var land := _color(Palette.KEY_MAP_LAND)
	for country_id: String in _visible_ids:
		_draw_fill(country_id, land, false)
	for country_id: String in _visible_ids:
		_draw_fill(country_id, water, true)

	if not _hovered_id.is_empty() and _visible_ids.has(_hovered_id) \
			and _hovered_id != _selected_id:
		_draw_fill(_hovered_id, _color(Palette.KEY_MAP_LAND_HOVER), false)
		_draw_fill(_hovered_id, water, true)

	if not _selected_id.is_empty() and _visible_ids.has(_selected_id):
		_draw_fill(_selected_id, _color(Palette.KEY_MAP_SELECTED), false)
		_draw_fill(_selected_id, water, true)

	_draw_borders(_visible_ids)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if _show_labels:
		_draw_labels()
	if has_focus():
		draw_rect(Rect2(Vector2.ZERO, size), _color(Palette.KEY_ACCENT), false,
				DesignTokens.BORDER_ACCENT)


func _draw_graticule() -> void:
	var colour := _color(Palette.KEY_MAP_GRATICULE)
	var step := MapProjection.GRATICULE_STEP
	var longitude := MapProjection.MIN_LON
	while longitude <= MapProjection.MAX_LON:
		var x := camera.world_to_screen(Vector2(longitude, 0.0)).x
		if x >= 0.0 and x <= size.x:
			draw_line(Vector2(x, 0.0), Vector2(x, size.y), colour, 1.0)
		longitude += step
	var latitude := MapProjection.MIN_LAT
	while latitude <= MapProjection.MAX_LAT:
		var y := camera.world_to_screen(Vector2(0.0, latitude)).y
		if y >= 0.0 and y <= size.y:
			draw_line(Vector2(0.0, y), Vector2(size.x, y), colour, 1.0)
		latitude += step


func _draw_missing_data() -> void:
	var font := get_theme_font(&"font", &"Body")
	var font_size := get_theme_font_size(&"font_size", &"Body")
	var message := "World data unavailable"
	var width := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - width) * 0.5, size.y * 0.5), message,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _color(Palette.KEY_TEXT_TERTIARY))


func _draw_borders(country_ids: PackedStringArray) -> void:
	var border := _color(Palette.KEY_MAP_BORDER)
	var selected_border := _color(Palette.KEY_MAP_BORDER_SELECTED)
	var hairline := 1.0 / camera.zoom
	for country_id: String in country_ids:
		var bbox := atlas.geometry.bbox_of(country_id)
		var screen_size := bbox.size * camera.zoom
		if maxf(screen_size.x, screen_size.y) < BORDER_MIN_PIXELS:
			continue
		var is_selected := country_id == _selected_id
		var colour := selected_border if is_selected else border
		var width := hairline * (DesignTokens.BORDER_ACCENT if is_selected else 1.0)
		for ring: PackedVector2Array in atlas.geometry.rings_of(country_id):
			if ring.size() < 2:
				continue
			draw_polyline(ring, colour, width)


## Fills a country (or its holes) with one colour.
##
## The cached mesh is the fast path: one draw call, no triangulation at draw
## time. A ring that could not be triangulated — a self-intersecting outline in
## some future dataset — falls back to `draw_colored_polygon` for that shape, so a
## single bad polygon degrades its own country instead of leaving a hole in the
## world.
func _draw_fill(country_id: String, colour: Color, holes: bool) -> void:
	var mesh := _meshes_for(country_id, holes)
	if mesh != null and mesh.get_surface_count() > 0:
		draw_mesh(mesh, null, Transform2D.IDENTITY, colour)
		return
	for rings: Array in atlas.geometry.polygons_of(country_id):
		for index in rings.size():
			if (index == 0) == holes:
				draw_colored_polygon(rings[index], colour)


func _draw_labels() -> void:
	var font := _label_font
	if font == null:
		return
	var colour := _color(Palette.KEY_MAP_LABEL)
	var placed: Array[Rect2] = []
	var max_rank := 2
	var ratio := camera.zoom_ratio()
	if ratio > 6.0:
		max_rank = 10
	elif ratio > 2.2:
		max_rank = 4
	for country_id: String in _visible_ids:
		if placed.size() >= LABEL_LIMIT:
			break
		var record := atlas.registry.get_country(country_id)
		if record == null or not record.has_label or record.label_rank > max_rank:
			continue
		var anchor := camera.world_to_screen(record.label)
		if anchor.x < 0.0 or anchor.y < 0.0 or anchor.x > size.x or anchor.y > size.y:
			continue
		var text := record.name.to_upper()
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _label_size)
		var rect := Rect2(anchor - Vector2(text_size.x * 0.5, text_size.y * 0.5), text_size)
		if rect.position.x < 2.0 or rect.end.x > size.x - 2.0:
			continue
		var overlaps := false
		for other: Rect2 in placed:
			if other.grow(6.0).intersects(rect):
				overlaps = true
				break
		if overlaps:
			continue
		placed.append(rect)
		draw_string(font, rect.position + Vector2(0.0, text_size.y * 0.8), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, _label_size, colour)


# --- Meshes ----------------------------------------------------------------

func _collect_visible(world_rect: Rect2) -> PackedStringArray:
	var out := PackedStringArray()
	for country_id: String in atlas.geometry.country_ids():
		if atlas.geometry.bbox_of(country_id).intersects(world_rect):
			out.append(country_id)
	return out


func _meshes_for(country_id: String, holes: bool) -> ArrayMesh:
	var cache: Dictionary = _hole_meshes if holes else _meshes
	if cache.has(country_id):
		return cache[country_id] as ArrayMesh
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var added := false
	for rings: Array in atlas.geometry.polygons_of(country_id):
		for index in rings.size():
			if (index == 0) == holes:
				continue
			var ring: PackedVector2Array = rings[index]
			for vertex_index: int in Geometry2D.triangulate_polygon(ring):
				var point := ring[vertex_index]
				tool.add_vertex(Vector3(point.x, point.y, 0.0))
				added = true
	var mesh: ArrayMesh = null
	if added:
		mesh = tool.commit()
	cache[country_id] = mesh
	return mesh


# --- Input -----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		camera.zoom_at(magnify.position, magnify.factor)
		accept_event()
	elif event is InputEventPanGesture:
		var pan := event as InputEventPanGesture
		camera.pan_by_pixels(-pan.delta * 24.0)
		accept_event()
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event as InputEventKey)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				camera.zoom_at(event.position, MapCamera.ZOOM_STEP)
			accept_event()
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				camera.zoom_at(event.position, 1.0 / MapCamera.ZOOM_STEP)
			accept_event()
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_drag(event.position)
				grab_focus()
			else:
				_end_drag(event.position)
			accept_event()
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_begin_drag(event.position)
			else:
				_end_drag(event.position)
			accept_event()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _dragging:
		var delta := event.position - _pointer
		_pointer = event.position
		_drag_distance += delta.length()
		camera.pan_by_pixels(delta)
		accept_event()
		return
	_update_hover(event.position)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			_begin_drag(event.position)
		elif _touches.size() == 2:
			_pinch_distance = _touch_spread()
		grab_focus()
	else:
		var was_tap := _touches.size() == 1 and _drag_distance < TAP_SLOP
		_touches.erase(event.index)
		if _touches.is_empty():
			if was_tap:
				tap(event.position)
			_dragging = false
			_drag_distance = 0.0
		_pinch_distance = _touch_spread()
	accept_event()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _touches.size() >= 2 and _pinch_distance > 0.0:
		var spread := _touch_spread()
		var midpoint := _touch_midpoint()
		if spread > 0.0:
			camera.zoom_at(midpoint, spread / _pinch_distance)
		_pinch_distance = spread
		accept_event()
		return
	if _dragging:
		_drag_distance += event.relative.length()
		camera.pan_by_pixels(event.relative)
		accept_event()


func _handle_key(event: InputEventKey) -> void:
	var step := 48.0
	match event.keycode:
		KEY_PLUS, KEY_EQUAL, KEY_KP_ADD:
			camera.zoom_in()
		KEY_MINUS, KEY_KP_SUBTRACT:
			camera.zoom_out()
		KEY_LEFT:
			camera.pan_by_pixels(Vector2(step, 0.0))
		KEY_RIGHT:
			camera.pan_by_pixels(Vector2(-step, 0.0))
		KEY_UP:
			camera.pan_by_pixels(Vector2(0.0, step))
		KEY_DOWN:
			camera.pan_by_pixels(Vector2(0.0, -step))
		_:
			return
	accept_event()


func _begin_drag(point: Vector2) -> void:
	_dragging = true
	_drag_distance = 0.0
	_pointer = point


func _end_drag(point: Vector2) -> void:
	if _dragging and _drag_distance < TAP_SLOP:
		tap(point)
	_dragging = false
	_drag_distance = 0.0


func _update_hover(point: Vector2) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hover_ms < HOVER_INTERVAL_MS:
		return
	_last_hover_ms = now
	var country_id := country_at_point(point)
	if country_id == _hovered_id:
		return
	_hovered_id = country_id
	mouse_default_cursor_shape = (Control.CURSOR_POINTING_HAND if not country_id.is_empty()
			else Control.CURSOR_ARROW)
	hover_changed.emit(_hovered_id)
	queue_redraw()


func _touch_spread() -> float:
	var points: Array = _touches.values()
	if points.size() < 2:
		return 0.0
	return (points[0] as Vector2).distance_to(points[1] as Vector2)


func _touch_midpoint() -> Vector2:
	var points: Array = _touches.values()
	if points.size() < 2:
		return size * 0.5
	return ((points[0] as Vector2) + (points[1] as Vector2)) * 0.5


# --- Events ----------------------------------------------------------------

func _on_camera_changed() -> void:
	queue_redraw()
	view_changed.emit()


func _on_resized() -> void:
	camera.set_view_size(size)
	queue_redraw()


func _on_mouse_exited() -> void:
	if _hovered_id.is_empty():
		return
	_hovered_id = ""
	hover_changed.emit("")
	queue_redraw()


func _on_theme_changed(_palette_id: String) -> void:
	_refresh_fonts()
	queue_redraw()


func _refresh_fonts() -> void:
	_label_font = get_theme_font(&"font", &"Eyebrow")
	_label_size = get_theme_font_size(&"font_size", &"Eyebrow")


func _color(key: String) -> Color:
	return ThemeManager.color(key)
