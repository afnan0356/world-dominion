extends TestCase
## Geometry, hit-testing and political-neutrality checks.
##
## The shapes are the part of this milestone most likely to break silently: a
## malformed ring, a dropped island or a country quietly merged into a neighbour
## would still "look like a map". These tests therefore check the shapes
## themselves, the geometry-to-metadata contract, and the dataset's own
## classification of disputed and dependent units.

const OCEAN_POINTS: Array[Vector2] = [
	Vector2(0.0, -60.0), Vector2(-140.0, -40.0), Vector2(-30.0, 10.0),
	Vector2(160.0, 10.0), Vector2(0.0, 80.0),
]

var _atlas: WorldAtlas


func _load() -> void:
	if _atlas == null:
		_atlas = WorldAtlas.load_default()


func test_geometry_parses_with_a_complete_world() -> void:
	_load()
	var geometry := _atlas.geometry
	check_true(geometry.is_loaded(), "geometry.json must parse")
	check_eq(geometry.issues().size(), 0,
			"the shipped geometry must load without issues (%s)" % str(geometry.issues()))
	check_gte(float(geometry.count()), 200.0, "the world must contain 200+ shapes")
	check_gt(float(geometry.polygon_count()), 1000.0,
			"multi-island countries must keep their separate polygons")
	check_gt(float(geometry.vertex_count()), 50000.0,
			"the atlas must carry real detail, not a rectangle per country")
	for country_id: String in geometry.country_ids():
		var polygons := geometry.polygons_of(country_id)
		check_gt(float(polygons.size()), 0.0, "%s has no polygons" % country_id)
		for rings: Array in polygons:
			check_gt(float(rings.size()), 0.0, "%s has a polygon without rings" % country_id)


func test_coordinates_are_inside_the_world() -> void:
	_load()
	var geometry := _atlas.geometry
	var points_checked := 0
	for country_id: String in geometry.country_ids():
		for rings: Array in geometry.polygons_of(country_id):
			var outline: PackedVector2Array = rings[0]
			check_eq(outline[0], outline[-1],
					"%s: outlines must start and end at the same point" % country_id)
			for ring: PackedVector2Array in rings:
				check_gte(float(ring.size()), 3.0,
						"%s: rings need at least three points" % country_id)
				for point: Vector2 in ring:
					points_checked += 1
					check_true(is_finite(point.x) and is_finite(point.y),
							"%s: non-finite coordinate" % country_id)
					check_true(absf(point.x) <= 180.0 and absf(point.y) <= 90.0,
							"%s: coordinate outside the world at %s" % [country_id, point])
	check_gt(float(points_checked), 50000.0, "the coordinate sweep must cover the atlas")


func test_multi_polygon_countries_keep_their_islands() -> void:
	_load()
	var geometry := _atlas.geometry
	var multi := 0
	for country_id: String in geometry.country_ids():
		if geometry.polygons_of(country_id).size() > 1:
			multi += 1
	check_gt(float(multi), 50.0, "dozens of countries are archipelagos or have exclaves")
	check_gte(float(geometry.polygons_of("FRA").size()), 5.0,
			"France keeps its overseas parts as separate polygons")
	check_gte(float(geometry.polygons_of("USA").size()), 5.0,
			"the United States keeps Alaska and Hawaii as separate polygons")
	# Disconnected parts are far apart; a single bounding box must still contain them.
	var france_bbox := geometry.bbox_of("FRA")
	check_true(france_bbox.size.x > 40.0,
			"France's bbox spans the Atlantic because of its overseas parts")


func test_holes_are_preserved() -> void:
	_load()
	var geometry := _atlas.geometry
	var with_holes := 0
	for country_id: String in geometry.country_ids():
		for rings: Array in geometry.polygons_of(country_id):
			if rings.size() > 1:
				with_holes += 1
				break
	check_gt(float(with_holes), 0.0, "enclaves such as Lesotho produce holes")
	var lookup := _atlas.lookup
	check_eq(lookup.country_at(Vector2(28.2, -29.6)), "LSO",
			"a point inside Lesotho resolves to Lesotho")
	check_eq(lookup.country_at(Vector2(28.0, -26.2)), "ZAF",
			"a point in South Africa outside Lesotho still resolves to South Africa")
	check_eq(lookup.country_at(Vector2(12.4578, 43.9424)), "SMR",
			"San Marino's enclave is not swallowed by Italy")


func test_hit_testing_maps_known_places() -> void:
	_load()
	var lookup := _atlas.lookup
	var expectations := {
		Vector2(90.4, 23.7): "BGD",
		Vector2(2.35, 48.85): "FRA",
		Vector2(13.4, 52.5): "DEU",
		Vector2(139.7, 35.7): "JPN",
		Vector2(10.0, 25.0): "DZA",
		Vector2(31.1, 29.9): "EGY",
		Vector2(151.2, -33.9): "AUS",
		Vector2(-46.6, -23.5): "BRA",
		Vector2(-0.12, 51.5): "GBR",
		Vector2(103.82, 1.35): "SGP",
		Vector2(37.6, 55.75): "RUS",
		Vector2(-21.9, 64.15): "ISL",
		Vector2(-149.9, 61.2): "USA",
		Vector2(0.0, -80.0): "ATA",
	}
	for point: Vector2 in expectations:
		check_eq(lookup.country_at(point), expectations[point],
				"hit test at %s must resolve to %s" % [point, expectations[point]])
	for point: Vector2 in OCEAN_POINTS:
		check_eq(lookup.country_at(point), "",
				"the open ocean at %s belongs to no country" % point)
	check_eq(lookup.country_at(Vector2(-400.0, 0.0)), "",
			"a point outside the world resolves to nothing")


func test_lookup_index_narrows_candidates() -> void:
	_load()
	var lookup := _atlas.lookup
	check_gt(float(lookup.candidates(Vector2(90.4, 23.7)).size()), 0.0,
			"a populated cell must have candidates")
	check_lte(float(lookup.candidates(Vector2(90.4, 23.7)).size()), 24.0,
			"the spatial grid must narrow a click to a handful of countries")
	check_lte(float(lookup.candidates(Vector2(0.0, -60.0)).size()), 2.0,
			"a southern-ocean cell has at most a couple of bbox candidates")


func test_malformed_geometry_is_reported_not_fatal() -> void:
	var cases := {
		"not an object": "nope",
		"no countries": {"schema": 1, "scale": 200},
		"odd length ring": {"scale": 200, "countries": {"AAA": {"polygons": [[[0, 0, 10, 0, 10]]]}}},
		"two point ring": {"scale": 200, "countries": {"AAA": {"polygons": [[[0, 0, 10, 10]]]}}},
		"out of range": {"scale": 200,
			"countries": {"AAA": {"polygons": [[[0, 0, 90000, 0, 0, 90000]]]}}},
		"ring is not an array": {"scale": 200, "countries": {"AAA": {"polygons": [[5]]}}},
		"polygons missing": {"scale": 200, "countries": {"AAA": {}}},
	}
	for label: String in cases:
		var geometry := WorldGeometry.from_data(cases[label], "test")
		check_false(geometry.is_loaded(), "%s: nothing usable must be loaded" % label)
		check_gt(float(geometry.issues().size()), 0.0, "%s: the problem must be reported" % label)
		check_eq(geometry.polygon_count(), 0, "%s: no polygons counted" % label)
	var valid := {"scale": 200, "countries": {
		"AAA": {"polygons": [[[0, 0, 100, 0, 100, 100, 0, 100]]]},
		"BBB": {"polygons": [[[0, 0, 100, 0]], [[-100, -100, -100, 0]]]},
	}}
	var mixed := WorldGeometry.from_data(valid, "test")
	check_eq(mixed.count(), 1, "only the well-formed country is loaded")
	check_true(mixed.has_country("AAA"), "the valid shape survives a broken sibling")
	check_true(not mixed.has_country("BBB"), "the broken shape is dropped")


func test_empty_geometry_is_safe() -> void:
	var geometry := WorldGeometry.from_data({"scale": 200, "countries": {}}, "test")
	check_false(geometry.is_loaded(), "an empty atlas is not loaded")
	check_eq(geometry.country_ids().size(), 0, "no ids")
	check_eq(geometry.bbox_of("AAA"), Rect2(), "an unknown bbox is empty")
	check_eq(geometry.polygons_of("AAA").size(), 0, "an unknown shape is empty")
	check_eq(geometry.rings_of("AAA").size(), 0, "an unknown ring list is empty")
	var atlas := WorldAtlas.from_data({"countries": []}, {"scale": 200, "countries": {}})
	check_false(atlas.is_ready(), "an atlas without shapes reports that it is not ready")
	check_true(atlas.lookup == null, "no spatial index is built for an empty atlas")


func test_disputed_and_dependent_units_keep_the_source_classification() -> void:
	_load()
	var israel := _atlas.registry.get_country("ISR")
	var palestine := _atlas.registry.get_country("PSE")
	check_not_null(israel, "Israel must exist in the atlas")
	check_not_null(palestine, "Palestine must exist in the atlas")
	if israel == null or palestine == null:
		return
	# The dataset's own classification, preserved verbatim: this project does not
	# arbitrate sovereignty, and both units keep their own geometry and id.
	check_eq(israel.type, "Disputed", "Israel keeps the dataset's classification")
	check_eq(palestine.type, "Indeterminate", "Palestine keeps the dataset's classification")
	check_eq(palestine.sovereignty, "Israel",
			"the source's sovereignty field is preserved, not silently rewritten")
	check_eq(palestine.note, "Partial self-admin.",
			"the source's note is preserved verbatim")
	check_eq(palestine.id, "PSE", "Palestine keeps its own stable id")
	check_true(_atlas.geometry.has_country("ISR") and _atlas.geometry.has_country("PSE"),
			"both units keep their own geometry")
	check_true(palestine.political_label().contains("Indeterminate"),
			"the panel's classification line reports the source's wording")
	# A point in the West Bank resolves to Palestine, not to a neighbour.
	check_eq(_atlas.lookup.country_at(Vector2(35.2, 32.0)), "PSE",
			"a point inside Palestine resolves to Palestine")
	# Other dependent and disputed units stay separately selectable too.
	var dependent := 0
	for record: CountryRecord in _atlas.registry.all():
		if record.type == "Dependency" or record.type == "Disputed":
			dependent += 1
			check_true(_atlas.geometry.has_country(record.id),
					"%s must keep its own shape" % record.id)
	check_gt(float(dependent), 20.0,
			"dependent and disputed territories must not be merged into their sovereign")


func test_metadata_and_geometry_agree() -> void:
	_load()
	for record: CountryRecord in _atlas.registry.all():
		var bbox := _atlas.geometry.bbox_of(record.id)
		check_lte(absf(bbox.position.x - record.bbox.position.x), 0.05,
				"%s: west edge disagreement" % record.id)
		check_lte(absf(bbox.position.y - record.bbox.position.y), 0.05,
				"%s: north edge disagreement" % record.id)
		check_lte(absf(bbox.end.x - record.bbox.end.x), 0.05,
				"%s: east edge disagreement" % record.id)
		check_lte(absf(bbox.end.y - record.bbox.end.y), 0.05,
				"%s: south edge disagreement" % record.id)


func test_antimeridian_shapes_stay_inside_the_world() -> void:
	_load()
	# Russia and Fiji cross 180°; the dataset splits them at the meridian, so every
	# stored coordinate stays in [-180, 180] and no shape wraps around the map.
	for country_id: String in ["RUS", "FJI", "NZL", "USA"]:
		var bbox := _atlas.geometry.bbox_of(country_id)
		check_gte(bbox.position.x, -180.0, "%s: west edge inside the world" % country_id)
		check_lte(bbox.end.x, 180.0, "%s: east edge inside the world" % country_id)
	# Russia legitimately reaches both sides of 180°, so its bounding box spans the
	# full width; what must not happen is a coordinate beyond ±180° (checked above)
	# or a polygon that wraps around the map.
	var russia := _atlas.geometry.bbox_of("RUS")
	check_lte(russia.end.x, 180.0, "Russia's eastern bbox edge stays inside the world")
	check_gte(russia.position.x, -180.0, "Russia's western bbox edge stays inside the world")
	check_gte(float(_atlas.geometry.polygons_of("RUS").size()), 2.0,
			"Russia keeps its detached parts as separate polygons")
