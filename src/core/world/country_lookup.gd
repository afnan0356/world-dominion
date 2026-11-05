class_name CountryLookup
extends RefCounted
## Answers "which country is under this point?" without iterating the world.
##
## A coarse lon/lat grid (10° cells) narrows a click to a handful of candidate
## countries by bounding box; only those are tested against their outlines.
## When bounding boxes overlap (enclaves, tiny states, disputed units) the
## smallest bbox wins, which is the shape the player can actually see.
##
## Hit-testing is independent of the renderer: it works on the same geometry the
## map draws, in degrees, and is unit-tested with synthetic shapes.

const CELL_SIZE := 10.0
const GRID_COLUMNS := 36
const GRID_ROWS := 18

var _geometry: WorldGeometry
var _cells: Dictionary = {}
var _areas: Dictionary = {}


func _init(geometry: WorldGeometry) -> void:
	_geometry = geometry
	_build()


func _build() -> void:
	if _geometry == null:
		return
	for country_id: String in _geometry.country_ids():
		var bbox := _geometry.bbox_of(country_id)
		if bbox.size.x <= 0.0 or bbox.size.y <= 0.0:
			continue
		_areas[country_id] = bbox.size.x * bbox.size.y
		for column in _lon_cells(bbox.position.x, bbox.end.x):
			for row in _lat_cells(bbox.position.y, bbox.end.y):
				var key := Vector2i(column, row)
				if not _cells.has(key):
					_cells[key] = PackedStringArray()
				var bucket: PackedStringArray = _cells[key]
				bucket.append(country_id)
				_cells[key] = bucket


func _lon_cells(minimum: float, maximum: float) -> Array[int]:
	var out: Array[int] = []
	for value in range(_lon_cell(minimum), _lon_cell(maximum) + 1):
		out.append(value)
	return out


func _lat_cells(minimum: float, maximum: float) -> Array[int]:
	var out: Array[int] = []
	for value in range(_lat_cell(minimum), _lat_cell(maximum) + 1):
		out.append(value)
	return out


func _lon_cell(longitude: float) -> int:
	return clampi(int(floor((longitude + 180.0) / CELL_SIZE)), 0, GRID_COLUMNS - 1)


func _lat_cell(latitude: float) -> int:
	return clampi(int(floor((latitude + 90.0) / CELL_SIZE)), 0, GRID_ROWS - 1)


func _cell_of(lon_lat: Vector2) -> Vector2i:
	return Vector2i(_lon_cell(lon_lat.x), _lat_cell(lon_lat.y))


## Country ids whose bounding box may contain `lon_lat`.
func candidates(lon_lat: Vector2) -> PackedStringArray:
	return _cells.get(_cell_of(lon_lat), PackedStringArray())


## The country under a lon/lat point, or "" when the point is water or outside.
func country_at(lon_lat: Vector2) -> String:
	if not MapProjection.is_inside_world(lon_lat):
		return ""
	var best := ""
	var best_area := INF
	for country_id: String in candidates(lon_lat):
		if not _geometry.bbox_of(country_id).has_point(lon_lat):
			continue
		if not shape_contains(country_id, lon_lat):
			continue
		var area: float = _areas.get(country_id, INF)
		if area < best_area:
			best_area = area
			best = country_id
	return best


func country_at_screen(screen_position: Vector2, camera: MapCamera) -> String:
	if camera == null:
		return ""
	return country_at(camera.screen_to_world(screen_position))


## True when `lon_lat` is inside the country's outline and outside its holes.
func shape_contains(country_id: String, lon_lat: Vector2) -> bool:
	for rings: Array in _geometry.polygons_of(country_id):
		if rings.is_empty():
			continue
		var outline: PackedVector2Array = rings[0]
		if not point_in_ring(lon_lat, outline):
			continue
		var in_hole := false
		for index in range(1, rings.size()):
			if point_in_ring(lon_lat, rings[index]):
				in_hole = true
				break
		if not in_hole:
			return true
	return false


## Even-odd ray casting. Written out rather than delegated to
## `Geometry2D.is_point_in_polygon` so the behaviour on the atlas' large,
## many-vertex rings is explicit and testable.
static func point_in_ring(point: Vector2, ring: PackedVector2Array) -> bool:
	var count := ring.size()
	if count < 3:
		return false
	var inside := false
	var previous := ring[count - 1]
	for index in count:
		var current := ring[index]
		var crosses := (current.y > point.y) != (previous.y > point.y)
		if crosses:
			var denominator := previous.y - current.y
			if not is_zero_approx(denominator):
				var crossing_x := current.x + (point.y - current.y) \
						* (previous.x - current.x) / denominator
				if point.x < crossing_x:
					inside = not inside
		previous = current
	return inside
