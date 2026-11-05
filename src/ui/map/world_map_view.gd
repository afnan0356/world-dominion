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
## Countries whose whole shape is smaller than this on screen are effectively
## untappable: a tap inside a 3-pixel island is luck. Such shapes get a generous
## selection radius, and only they do — a big neighbour never steals a tap.
const SNAP_MAX_SHAPE_PX := 11.0
const SNAP_RADIUS_PX := 18.0
## Below this on-screen size a country also gets a small marker, so a player can
## see that there is something to select at all.
const TINY_MARKER_PX := 6.0
## Cap on marker rings, so a world view cannot turn into a field of circles.
const TINY_MARKER_LIMIT := 48
## Mean kilometres per degree of latitude; also used for the scale bar.
const KILOMETRES_PER_DEGREE := 111.32
## The ratio between these two must exceed 2.5 so that one of 1/2/5 × 10^n always
## fits the window; at world zoom the map is wide enough to use most of it.
const SCALE_BAR_MIN_PX := 56.0
const SCALE_BAR_MAX_PX := 150.0
const OCEAN_LABEL_ZOOM := 1.8
## Capitals appear when the player has zoomed into something region-sized, and
## their names only when there is room for them. At world zoom, 196 city names
## would be noise; a marker that cannot be read is also noise.
const CAPITAL_MARKER_ZOOM := 2.4
const CAPITAL_LABEL_ZOOM := 3.6
const CAPITAL_MARKER_RADIUS := 2.5
## Ocean label anchors. These are *project-authored* placement anchors chosen so
## the words sit in open water; they are not dataset features and claim no
## geographic precision beyond "this ocean is around here".
const OCEAN_LABELS := [
	["NORTH PACIFIC OCEAN", Vector2(-150.0, 20.0)],
	["SOUTH PACIFIC OCEAN", Vector2(-120.0, -35.0)],
	["NORTH ATLANTIC OCEAN", Vector2(-35.0, 33.0)],
	["SOUTH ATLANTIC OCEAN", Vector2(-20.0, -30.0)],
	["INDIAN OCEAN", Vector2(75.0, -25.0)],
	["SOUTHERN OCEAN", Vector2(10.0, -58.0)],
	["ARCTIC OCEAN", Vector2(-20.0, 78.0)],
]

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
var _label_rects: Array[Rect2] = []
var _visible_capital_markers := 0
var _visible_label_count := 0
var _detail_reduced := false
## The player's country in a campaign. Marked with a shape *and* the words
## "YOUR NATION", never by colour alone, and never linked to selection: browsing a
## neighbour's dossier must not move the badge.
var _home_id := ""
var _capital_font: Font
var _capital_size := 11
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


## Reduced detail for slower devices: fewer borders, no ocean names, no capital
## markers or names, a lower label cap. Geography and selection are untouched, so
## nothing a player can tap or read about a country changes.
func set_detail_reduced(reduced: bool) -> void:
	if reduced == _detail_reduced:
		return
	_detail_reduced = reduced
	queue_redraw()


func detail_reduced() -> bool:
	return _detail_reduced


## Counts from the last draw, for the developer performance overlay and tests.
func drawn_label_count() -> int:
	return _visible_label_count


func drawn_capital_marker_count() -> int:
	return _visible_capital_markers


## Marks `country_id` as the player's country. Passing an unknown or empty id
## clears the mark rather than leaving a marker on the wrong country.
func mark_home(country_id: String) -> void:
	var next := ""
	if atlas != null and atlas.is_ready() and atlas.registry.has_country(country_id):
		next = country_id
	if next == _home_id:
		return
	_home_id = next
	queue_redraw()


func home_country_id() -> String:
	return _home_id


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
##
## `assist` enables the small-country assist: when a tap lands on water, the
## nearest country whose *whole shape* is under `SNAP_MAX_SHAPE_PX` on screen and
## whose edge/label anchor is within `SNAP_RADIUS_PX` is returned instead. That is
## a selection radius, not a moved or enlarged polygon — the shape never changes
## position or size, and a large neighbour can never absorb a nearby tap.
func country_at_point(point: Vector2, assist: bool = true) -> String:
	if atlas == null or atlas.lookup == null:
		return ""
	var country_id := atlas.lookup.country_at_screen(point, camera)
	if not country_id.is_empty():
		return country_id if atlas.registry.has_country(country_id) else ""
	return _nearest_small_country(point) if assist else ""


## Nearest tiny country within the assist radius, or "". Distance is measured to
## the country's label anchor when it has one (the source puts it inside or beside
## the shape) and to its bbox otherwise.
func _nearest_small_country(point: Vector2) -> String:
	var best_id := ""
	var best_distance := SNAP_RADIUS_PX
	# `_visible_ids` is filled by the last draw; if a tap somehow arrives first,
	# ask the atlas instead of silently losing the assist.
	var candidates := _visible_ids if not _visible_ids.is_empty() else visible_country_ids()
	for country_id: String in candidates:
		var bbox := atlas.geometry.bbox_of(country_id)
		var screen_size := bbox.size * camera.zoom
		if maxf(screen_size.x, screen_size.y) > SNAP_MAX_SHAPE_PX:
			continue
		var record: CountryRecord = atlas.registry.get_country(country_id)
		var anchor := camera.world_to_screen(bbox.get_center())
		if record != null and record.has_label:
			anchor = camera.world_to_screen(record.label)
		var distance := point.distance_to(anchor)
		if distance < best_distance:
			best_distance = distance
			best_id = country_id
	return best_id


## Reports the country under a point as an activation. Tap release, touch release
## and tests all go through here, so "what a tap means" has one definition: the
## country id, or "" for empty water and empty space.
func tap(point: Vector2) -> String:
	var country_id := country_at_point(point)
	country_activated.emit(country_id)
	return country_id


## Kilometres covered by one screen pixel at the current view centre. The
## projection is equirectangular, so a degree of longitude shrinks with latitude
## while a degree of latitude does not; the bar therefore reports the scale at the
## middle of what is on screen, and the drawing is honest about being local.
func kilometres_per_pixel() -> float:
	if camera.zoom <= 0.0:
		return 0.0
	var centre_latitude := camera.visible_rect().get_center().y
	var compressed := maxf(cos(deg_to_rad(clampf(centre_latitude, -85.0, 85.0))), 0.02)
	return (KILOMETRES_PER_DEGREE * compressed) / camera.zoom


## A round distance and the pixel width that represents it: 1, 2 or 5 times a
## power of ten, kept between `SCALE_BAR_MIN_PX` and `SCALE_BAR_MAX_PX` when the
## view allows. Returns an empty dictionary when the view has no usable scale.
func scale_bar() -> Dictionary:
	var per_pixel := kilometres_per_pixel()
	if per_pixel <= 0.0:
		return {}
	# Collect the round candidates that are at least readable, then prefer the
	# longest one that still fits the map. Two passes, no guessing.
	var candidates: Array = []
	for exponent in range(-3, 10):
		for step: float in [1.0, 2.0, 5.0]:
			var distance := step * pow(10.0, exponent)
			var pixels := distance / per_pixel
			if pixels >= SCALE_BAR_MIN_PX:
				candidates.append({"kilometres": distance, "pixels": pixels})
	if candidates.is_empty():
		return {}
	var chosen: Dictionary = {}
	for candidate: Dictionary in candidates:
		if float(candidate["pixels"]) > SCALE_BAR_MAX_PX:
			continue
		if chosen.is_empty() or float(candidate["pixels"]) > float(chosen["pixels"]):
			chosen = candidate
	if chosen.is_empty():
		# Nothing fits the window: take the shortest bar that is still readable
		# rather than a bar that runs off the map.
		chosen = candidates[0]
	var kilometres := float(chosen["kilometres"])
	return {
		"pixels": float(chosen["pixels"]),
		"kilometres": kilometres,
		"label": _distance_label(kilometres),
	}


static func _distance_label(kilometres: float) -> String:
	if kilometres >= 1000.0:
		return "%s 000 km" % String.num(kilometres / 1000.0, 0)
	return "%s km" % String.num(kilometres, 0)


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
		_draw_ocean_labels()
	_draw_tiny_markers()
	_draw_capitals()
	_draw_home_marker()
	_draw_scale_bar()
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
		var border_floor := BORDER_MIN_PIXELS * (2.0 if _detail_reduced else 1.0)
		if maxf(screen_size.x, screen_size.y) < border_floor:
			continue
		var is_selected := country_id == _selected_id
		var colour: Color = selected_border if is_selected else border
		var width := hairline * (float(DesignTokens.BORDER_ACCENT) if is_selected else 1.0)
		for ring: PackedVector2Array in atlas.geometry.rings_of(country_id):
			if ring.size() < 2:
				continue
			draw_polyline(ring, colour, width)


## Fills a country (or its holes) with one colour.
##
## The cached mesh is the fast path: one draw call, no triangulation at draw
## time. A ring that produced no triangles at all leaves its country unmeshed,
## and an unmeshed country is simply not filled — the map shows the rest of the
## world rather than failing the frame.
func _draw_fill(country_id: String, colour: Color, holes: bool) -> void:
	var mesh := _meshes_for(country_id, holes)
	if mesh == null or mesh.get_surface_count() == 0:
		return
	draw_mesh(mesh, null, Transform2D.IDENTITY, colour)


## A ring around countries too small to see, so the player knows there is
## something selectable there. The marker is drawn at the shape's centre and never
## inflates the shape itself.
func _draw_tiny_markers() -> void:
	if atlas == null or not atlas.is_ready():
		return
	var colour := _color(Palette.KEY_MAP_LABEL)
	var accent := _color(Palette.KEY_ACCENT)
	var drawn := 0
	for country_id: String in _visible_ids:
		if drawn >= TINY_MARKER_LIMIT:
			break
		var record: CountryRecord = atlas.registry.get_country(country_id)
		if country_id != _selected_id and (record == null or not record.has_label):
			continue
		var bbox := atlas.geometry.bbox_of(country_id)
		var screen_size := bbox.size * camera.zoom
		if maxf(screen_size.x, screen_size.y) > TINY_MARKER_PX:
			continue
		var anchor := camera.world_to_screen(bbox.get_center())
		if record != null and record.has_label:
			anchor = camera.world_to_screen(record.label)
		if anchor.x < -24.0 or anchor.y < -24.0 or anchor.x > size.x + 24.0 \
				or anchor.y > size.y + 24.0:
			continue
		var selected := country_id == _selected_id
		drawn += 1
		draw_arc(anchor, 5.0 if selected else 3.5, 0.0, TAU, 12,
				accent if selected else colour, 1.5, true)
		if selected:
			draw_arc(anchor, 9.0, 0.0, TAU, 16, accent, 1.0, true)


## Capital markers and, when zoomed in far enough, capital names.
##
## A country with no sourced capital draws nothing here: the marker comes from
## `record.has_capital_point`, which is only true when the dataset supplied both a
## capital name and that capital's location. Capital labels rank below country
## labels, so a capital name yields to the country it belongs to, and capital
## names yield to each other.
## Capital markers and labels that would be drawn right now.
##
## Returns `{markers: Array[Vector2], labels: Array[{rect, text}]}`. Pure in the
## same way as `label_layout`: no draw calls, so the culling rules (zoom gates,
## viewport bounds, no collision with a country label) are testable headless.
## Capital labels are laid out after country labels and give way to them.
func capital_layout() -> Dictionary:
	var markers: Array = []
	var labels: Array = []
	if atlas == null or not atlas.is_ready() or _detail_reduced:
		return {"markers": markers, "labels": labels}
	if camera.zoom_ratio() < CAPITAL_MARKER_ZOOM:
		return {"markers": markers, "labels": labels}
	var country_rects: Array[Rect2] = []
	for entry: Dictionary in label_layout():
		country_rects.append(entry["rect"])
	var placed: Array[Rect2] = []
	var with_labels := _show_labels and camera.zoom_ratio() >= CAPITAL_LABEL_ZOOM \
			and _capital_font != null
	for country_id: String in visible_country_ids():
		var record: CountryRecord = atlas.registry.get_country(country_id)
		if record == null or not record.has_capital_point:
			continue
		var point := camera.world_to_screen(record.capital_point)
		if point.x < -8.0 or point.y < -8.0 or point.x > size.x + 8.0 \
				or point.y > size.y + 8.0:
			continue
		markers.append(point)
		if not with_labels or record.capital.is_empty():
			continue
		var text := record.capital
		var text_size := _capital_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				_capital_size)
		var rect := Rect2(point + Vector2(6.0, -text_size.y * 0.5), text_size)
		if rect.position.x < 2.0 or rect.end.x > size.x - 2.0:
			continue
		if _overlaps_any(country_rects, rect.grow(2.0)) or _overlaps_any(placed, rect):
			continue
		placed.append(rect)
		labels.append({"rect": rect, "text": text})
	return {"markers": markers, "labels": labels}


func _draw_capitals() -> void:
	_visible_capital_markers = 0
	if atlas == null or not atlas.is_ready():
		return
	var marker_colour := _color(Palette.KEY_TEXT_SECONDARY)
	var ring_colour := _color(Palette.KEY_MAP_WATER)
	var label_colour := _color(Palette.KEY_MAP_LABEL)
	var layout := capital_layout()
	var markers: Array = layout["markers"]
	for point: Vector2 in markers:
		# A hollow centre keeps the marker readable on both palettes without
		# relying on a colour difference alone.
		draw_circle(point, CAPITAL_MARKER_RADIUS + 1.0, ring_colour)
		draw_circle(point, CAPITAL_MARKER_RADIUS, marker_colour)
	_visible_capital_markers = markers.size()
	for entry: Dictionary in layout["labels"]:
		var rect: Rect2 = entry["rect"]
		draw_string(_capital_font, rect.position, str(entry["text"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, _capital_size, label_colour)


## The player's nation: two concentric rings plus a caption. A ring and a word are
## readable without colour, in either palette, and at any zoom that shows the map.
func _draw_home_marker() -> void:
	if _home_id.is_empty() or atlas == null or not atlas.is_ready():
		return
	var record: CountryRecord = atlas.registry.get_country(_home_id)
	if record == null:
		return
	var anchor := record.label if record.has_label else record.bbox.get_center()
	var point := camera.world_to_screen(anchor)
	if point.x < 0.0 or point.y < 0.0 or point.x > size.x or point.y > size.y:
		return
	var colour := _color(Palette.KEY_ACCENT)
	var inner := 5.0
	var outer := 9.0
	draw_arc(point, inner, 0.0, TAU, 20, colour, 2.0, true)
	draw_arc(point, outer, 0.0, TAU, 24, colour, 1.5, true)
	if _capital_font == null:
		return
	var text := "YOUR NATION"
	var text_size := _capital_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			_capital_size)
	var position := point + Vector2(-text_size.x * 0.5, outer + text_size.y + 2.0)
	if position.x < 2.0 or position.x + text_size.x > size.x - 2.0:
		return
	draw_string(_capital_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _capital_size,
			colour)


func _overlaps_any(rects: Array[Rect2], rect: Rect2) -> bool:
	for other: Rect2 in rects:
		if other.grow(3.0).intersects(rect):
			return true
	return false


## Ocean names at world zoom only. They are drawn after the country labels, so
## each one is skipped when it would overlap a label that is already placed: an
## ocean name is orientation, a country name is information.
func _draw_ocean_labels() -> void:
	if _label_font == null or camera.zoom_ratio() > OCEAN_LABEL_ZOOM or _detail_reduced:
		return
	var colour := _color(Palette.KEY_MAP_LABEL)
	colour.a *= 0.75
	for entry: Array in OCEAN_LABELS:
		var text: String = entry[0]
		var anchor := camera.world_to_screen(entry[1])
		if anchor.x < 0.0 or anchor.y < 0.0 or anchor.x > size.x or anchor.y > size.y:
			continue
		var text_size := _label_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				_label_size)
		if anchor.x - text_size.x * 0.5 < 2.0 or anchor.x + text_size.x * 0.5 > size.x - 2.0:
			continue
		var rect := Rect2(anchor - Vector2(text_size.x * 0.5, text_size.y * 0.5), text_size)
		if _overlaps_label(rect):
			continue
		draw_string(_label_font, anchor - Vector2(text_size.x * 0.5, 0.0), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, _label_size, colour)


## Scale bar, bottom right. Screen space, so it is independent of the camera
## transform and always exactly as long as the distance it claims.
func _overlaps_label(rect: Rect2) -> bool:
	for placed: Rect2 in _label_rects:
		if placed.grow(4.0).intersects(rect):
			return true
	return false


func _draw_scale_bar() -> void:
	var bar := scale_bar()
	if bar.is_empty():
		return
	var pixels := float(bar["pixels"])
	if pixels <= 0.0 or pixels > size.x - 32.0:
		return
	var colour := _color(Palette.KEY_MAP_LABEL)
	var baseline := size.y - 26.0
	var left := size.x - pixels - 16.0
	if left < 12.0:
		return
	draw_line(Vector2(left, baseline), Vector2(left + pixels, baseline), colour, 1.5)
	draw_line(Vector2(left, baseline - 4.0), Vector2(left, baseline + 4.0), colour, 1.5)
	draw_line(Vector2(left + pixels, baseline - 4.0), Vector2(left + pixels, baseline + 4.0),
			colour, 1.5)
	if _label_font == null:
		return
	draw_string(_label_font, Vector2(left, baseline - 8.0), str(bar["label"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, _label_size, colour)


## Country labels that would be drawn right now: `{rect, text}` entries in
## drawing order. Pure with respect to the camera — it issues no draw calls, so
## tests can check culling and collisions without a GPU — and it is the single
## source of truth for what `_draw_labels` renders.
func label_layout() -> Array:
	var out: Array = []
	var font := _label_font
	if font == null or atlas == null or not atlas.is_ready():
		return out
	var max_rank := 2
	if _detail_reduced:
		max_rank = 1
	var ratio := camera.zoom_ratio()
	if ratio > 6.0:
		max_rank = 10
	elif ratio > 2.2:
		max_rank = 4
	var placed: Array[Rect2] = []
	for country_id: String in visible_country_ids():
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
		if _overlaps_any(placed, rect.grow(6.0)):
			continue
		placed.append(rect)
		out.append({"rect": rect, "text": text})
	return out


func _draw_labels() -> void:
	var font := _label_font
	if font == null:
		return
	var colour := _color(Palette.KEY_MAP_LABEL)
	_label_rects.clear()
	var layout := label_layout()
	for entry: Dictionary in layout:
		var rect: Rect2 = entry["rect"]
		_label_rects.append(rect)
		draw_string(font, rect.position + Vector2(0.0, rect.size.y * 0.8), str(entry["text"]),
				HORIZONTAL_ALIGNMENT_LEFT, -1, _label_size, colour)
	_visible_label_count = layout.size()


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
			var triangles := _triangles_for(ring, not holes)
			for point: Vector2 in triangles:
				tool.add_vertex(Vector3(point.x, point.y, 0.0))
				added = true
	var mesh: ArrayMesh = null
	if added:
		mesh = tool.commit()
	cache[country_id] = mesh
	return mesh


## Triangle vertices for one ring.
##
## Godot's ear clipper refuses outlines that are not simple polygons, and Natural
## Earth 1:50m contains a few (Taiwan's main island among them: the source
## coastline doubles back on itself). A landmass that will not triangulate is
## filled with its convex hull, which over-fills a bay instead of deleting an
## island from the world. A hole is skipped instead of hulled: inventing a convex
## lake would paint water over land that really is there.
func _triangles_for(ring: PackedVector2Array, allow_hull: bool) -> PackedVector2Array:
	var points := _triangulated(ring)
	if not points.is_empty():
		return points
	if not allow_hull:
		return PackedVector2Array()
	return _triangulated(Geometry2D.convex_hull(ring))


func _triangulated(ring: PackedVector2Array) -> PackedVector2Array:
	if ring.size() < 3:
		return PackedVector2Array()
	var indices := Geometry2D.triangulate_polygon(ring)
	if indices.is_empty():
		return PackedVector2Array()
	var points := PackedVector2Array()
	points.resize(indices.size())
	for slot in indices.size():
		points[slot] = ring[indices[slot]]
	return points


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
		KEY_HOME, KEY_0:
			camera.reset()
		KEY_ENTER, KEY_KP_ENTER:
			# Keyboard users have no pointer, so "activate" means the country in
			# the middle of the view.
			tap(size * 0.5)
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
	var country_id := country_at_point(point, false)
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
	_capital_font = get_theme_font(&"font", &"Caption")
	_capital_size = get_theme_font_size(&"font_size", &"Caption")


func _color(key: String) -> Color:
	return ThemeManager.color(key)
