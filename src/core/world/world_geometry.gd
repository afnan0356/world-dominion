class_name WorldGeometry
extends RefCounted
## Polygon geometry for every atlas country, in longitude/latitude degrees.
##
## The file is generated offline (`tools/build_world_atlas.py`) and stores flat
## integer arrays in 1/scale degrees to stay compact. This class is the only
## place that knows that wire format: everything else receives `Vector2` points
## in degrees.
##
## Rings are ordered as the shape format intends — the first ring of a polygon
## is its outline, any further rings are holes (lesotho inside South Africa,
## for instance). Rendering a hole is the renderer's problem; the geometry's
## job is to report the shape faithfully.

const DEFAULT_PATH := "res://data/world/geometry.json"
const COAST_PATH := "res://data/world/coast.json"
const SCHEMA_VERSION := 1

var _polygons: Dictionary = {}
var _bboxes: Dictionary = {}
var _vertex_total := 0
var _ring_total := 0
var _polygon_total := 0
var _scale := 200.0
var _issues: PackedStringArray = []
var _coast: Dictionary = {}


static func from_file(path: String = DEFAULT_PATH,
		coast_path: String = COAST_PATH) -> WorldGeometry:
	var data: Variant = DataLoader.load_json(path)
	var geometry := from_data(data, path)
	var coast: Variant = DataLoader.load_json(coast_path)
	if coast is Dictionary and (coast as Dictionary).get("countries") is Dictionary:
		geometry._coast = (coast as Dictionary).get("countries")
	elif coast != null:
		geometry._issues.append("%s: coast file is not readable" % coast_path)
	return geometry


## Parses the atlas geometry. Malformed rings are dropped individually and
## reported through `issues()`; a broken shape never aborts the load and never
## crashes the caller, because a partially readable map is better than none.
static func from_data(data: Variant, source: String = "inline",
		coast: Variant = null) -> WorldGeometry:
	var geometry := WorldGeometry.new()
	if coast is Dictionary and (coast as Dictionary).get("countries") is Dictionary:
		geometry._coast = (coast as Dictionary).get("countries")
	if not data is Dictionary:
		geometry._issues.append("%s: expected a JSON object" % source)
		return geometry
	var root: Dictionary = data
	var scale_value: Variant = root.get("scale")
	if scale_value != null and float(scale_value) > 0.0:
		geometry._scale = float(scale_value)
	var countries: Variant = root.get("countries")
	if not countries is Dictionary:
		geometry._issues.append("%s: missing 'countries' object" % source)
		return geometry
	for country_id: Variant in (countries as Dictionary):
		var entry: Variant = (countries as Dictionary)[country_id]
		var id := str(country_id)
		if entry == null or not entry is Dictionary:
			geometry._issues.append("%s [%s]: entry is not an object" % [source, id])
			continue
		var parsed: Array = []
		for polygon: Variant in (entry as Dictionary).get("polygons", []):
			var rings: Array[PackedVector2Array] = []
			if polygon is Array:
				for ring: Variant in polygon:
					var points := geometry._parse_ring(ring, source, id)
					if points.size() >= 3:
						rings.append(points)
			if rings.is_empty():
				continue
			parsed.append(rings)
			geometry._ring_total += rings.size()
			geometry._polygon_total += 1
			for ring_points: PackedVector2Array in rings:
				geometry._vertex_total += ring_points.size()
		if parsed.is_empty():
			geometry._issues.append("%s [%s]: no usable polygons" % [source, id])
			continue
		geometry._polygons[id] = parsed
		geometry._bboxes[id] = _compute_bbox(parsed)
	return geometry


func _parse_ring(ring: Variant, source: String, country_id: String) -> PackedVector2Array:
	var points := PackedVector2Array()
	if not ring is Array:
		_issues.append("%s [%s]: ring is not an array" % [source, country_id])
		return points
	var flat: Array = ring
	if flat.size() < 6 or flat.size() % 2 != 0:
		_issues.append("%s [%s]: ring has %d values" % [source, country_id, flat.size()])
		return points
	for index in range(0, flat.size(), 2):
		var lon := float(flat[index]) / _scale
		var lat := float(flat[index + 1]) / _scale
		if not is_finite(lon) or not is_finite(lat):
			_issues.append("%s [%s]: non-finite coordinate" % [source, country_id])
			return PackedVector2Array()
		if absf(lon) > 180.0 or absf(lat) > 90.0:
			_issues.append("%s [%s]: coordinate outside the world" % [source, country_id])
			return PackedVector2Array()
		points.append(Vector2(lon, lat))
	return points


static func _compute_bbox(polygons: Array) -> Rect2:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for rings: Array in polygons:
		for ring: PackedVector2Array in rings:
			for point: Vector2 in ring:
				minimum = Vector2(minf(minimum.x, point.x), minf(minimum.y, point.y))
				maximum = Vector2(maxf(maximum.x, point.x), maxf(maximum.y, point.y))
	return Rect2(minimum, maximum - minimum)


func is_loaded() -> bool:
	return not _polygons.is_empty()


func count() -> int:
	return _polygons.size()


func has_country(country_id: String) -> bool:
	return _polygons.has(country_id)


func country_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for key: Variant in _polygons:
		out.append(str(key))
	return out


## Array of polygons, each an array of rings (`PackedVector2Array`), in degrees.
func polygons_of(country_id: String) -> Array:
	var value: Variant = _polygons.get(country_id)
	return value if value is Array else []


## Every ring of a country flattened into one list, for stroking borders.
func rings_of(country_id: String) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for rings: Array in polygons_of(country_id):
		for ring: PackedVector2Array in rings:
			out.append(ring)
	return out


## One character per ring, in the same order as `rings_of()`: `"1"` a coastline,
## `"0"` a land border shared with a neighbour, `"2"` a ring that mixes both.
##
## The classification comes from `data/world/coast.json`, built offline by
## `tools/build_coast_data.py`. It is a *hint for the renderer*, and a conservative
## one: when a country is missing from the file, or the file was never loaded, every
## ring reports `"0"`, so the map draws a plain border and never invents a coastline.
func ring_coast_codes(country_id: String) -> String:
	var rings := rings_of(country_id)
	var stored: Variant = _coast.get(country_id)
	var out := ""
	if stored is String:
		out = str(stored)
	if out.length() < rings.size():
		out += "0".repeat(rings.size() - out.length())
	elif out.length() > rings.size():
		out = out.substr(0, rings.size())
	return out


## Disconnected landmasses recorded for `country_id`; 0 for unknown ids.
func polygon_count_of(country_id: String) -> int:
	return polygons_of(country_id).size()


## Vertices across every ring of `country_id`, holes included.
func vertex_count_of(country_id: String) -> int:
	var total := 0
	for ring: PackedVector2Array in rings_of(country_id):
		total += ring.size()
	return total


func bbox_of(country_id: String) -> Rect2:
	var value: Variant = _bboxes.get(country_id)
	return value if value is Rect2 else Rect2()


func scale() -> float:
	return _scale


func polygon_count() -> int:
	return _polygon_total


func ring_count() -> int:
	return _ring_total


func vertex_count() -> int:
	return _vertex_total


func issues() -> PackedStringArray:
	return _issues
