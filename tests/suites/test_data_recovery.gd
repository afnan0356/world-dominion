extends TestCase
## Failure handling for missing, malformed and inconsistent atlas data.
##
## The game must never crash on bad data, must never invent a replacement for it,
## and must keep a diagnostic trail a developer can read. Each test here breaks
## one thing and asserts what the player and the developer see.

const SEARCH_SCENE := "res://src/ui/components/country_search.gd"
const MAP_SCENE := "res://src/ui/map/world_map_view.tscn"


func test_a_missing_atlas_reports_instead_of_crashing() -> void:
	var atlas := WorldAtlas.load_from("res://data/world/does_not_exist.json",
			"res://data/world/does_not_exist.json", "res://data/world/does_not_exist.json")
	check_false(atlas.is_ready(), "an atlas with no files is not ready")
	check_eq(atlas.country_count(), 0, "and contains no countries")
	check_gt(float(atlas.issues().size()), 0.0, "the failure is recorded for the developer")
	check_eq(atlas.unshaped_country_ids().size(), 0,
			"asking for unshaped ids is safe on a missing dataset")
	check_eq(atlas.orphan_geometry_ids().size(), 0,
			"asking for orphan geometries is safe on a missing dataset")
	var dossier := CountryDossier.build(atlas.registry.get_country("BGD"))
	check_eq(dossier.sections.size(), 0, "no record means no dossier, not a fabricated one")


func test_a_registry_of_garbage_yields_an_explained_empty_registry() -> void:
	for payload: Variant in ["not json", 42, [], {"countries": "nope"},
			{"countries": [null, 3, {"name": "Nameless"}]}]:
		var registry := CountryRegistry.from_data(payload, "test")
		check_eq(registry.count(), 0, "garbage yields no countries (%s)" % str(payload))
		check_gt(float(registry.issues().size()), 0.0,
				"garbage is explained, not swallowed (%s)" % str(payload))
		check_eq(registry.search("bangladesh").size(), 0,
				"search on an empty registry returns nothing")
		check_eq(registry.regions().size(), 0, "an empty registry offers no regions")


func test_malformed_geometry_is_reported_and_survivable() -> void:
	var payload := {
		"scale": 200,
		"countries": {
			"AAA": {"bbox": [0, 0, 1, 1], "polygons": [[[0, 0, 10, 10]]]},
			"BBB": {"bbox": [0, 0, 1, 1], "polygons": "nope"},
			"CCC": {"polygons": []},
			"DDD": {"polygons": [[[0, 0, 200, 0, 200, 200, 0, 0]]]},
		},
	}
	var geometry := WorldGeometry.from_data(payload, "test")
	check_eq(geometry.count(), 1, "only the country with a usable ring survives")
	check_true(geometry.has_country("DDD"), "a valid ring keeps its country")
	check_false(geometry.has_country("AAA"), "a two-point ring cannot become a shape")
	check_false(geometry.has_country("BBB"), "a polygon list that is not a list is dropped")
	check_gt(float(geometry.issues().size()), 0.0, "and every drop is reported")
	check_eq(geometry.polygon_count_of("ZZZ"), 0, "an unknown country has no polygons")
	check_eq(geometry.vertex_count_of("ZZZ"), 0, "an unknown country has no vertices")
	check_eq(geometry.bbox_of("ZZZ"), Rect2(), "an unknown country has no bbox")


func test_a_broken_geometry_reference_does_not_reassign_a_country() -> void:
	# A registry record whose shape is missing must stay itself: the map must not
	# fall back to a neighbouring shape or to the country's bbox as a fake polygon.
	var atlas := WorldAtlas.from_data(
		{"countries": [{"id": "AAA", "name": "Alpha", "region": "Asia",
			"bbox": [0, 0, 10, 10], "label": [5, 5]}]},
		{"scale": 200, "countries": {}})
	var missing := atlas.unshaped_country_ids()
	check_eq(missing.size(), 1, "the unshaped country is listed")
	check_eq(missing[0], "AAA", "the country keeps its own id")
	check_eq(atlas.geometry.polygon_count_of("AAA"), 0, "no geometry is invented for it")
	check_eq(atlas.lookup, null, "and no spatial index is built from nothing")


func test_search_field_survives_an_empty_registry() -> void:
	var search: CountrySearch = load(SEARCH_SCENE).new()
	host.add_child(search)
	search.setup(CountryRegistry.from_data({"countries": []}, "test"))
	await tree.process_frame
	search.set_query("bangladesh")
	await tree.process_frame
	check_eq(search.visible_result_ids().size(), 0, "no registry, no results")
	check_true(search.empty_state_visible(), "the field says nothing matched")
	search.clear()
	check_eq(search.current_query(), "", "clearing still works")
	search.queue_free()


func test_map_with_broken_data_shows_an_empty_world() -> void:
	var map: WorldMapView = load(MAP_SCENE).instantiate()
	host.add_child(map)
	map.size = Vector2(640, 360)
	map.set_atlas(WorldAtlas.from_data({"countries": []}, {"scale": 200, "countries": {}}))
	await tree.process_frame
	check_eq(map.country_at_point(Vector2(320.0, 180.0)), "",
			"an empty atlas resolves no country")
	check_false(map.focus_country("BGD"), "focusing into an empty atlas reports failure")
	check_eq(map.visible_country_ids().size(), 0, "nothing is visible")
	map.queue_free()


func test_invalid_scenarios_fail_validation_with_a_reason() -> void:
	var atlas := WorldAtlas.load_default()
	var catalog := ScenarioCatalog.from_directory()
	var scenario := catalog.default_scenario()
	check_not_null(scenario, "the shipped scenario catalogue has a default scenario")
	if scenario == null:
		return
	var empty := CampaignConfig.create(null, null)
	var errors := empty.validate(catalog, atlas.registry)
	check_gt(float(errors.size()), 0.0, "a campaign without a scenario cannot be confirmed")
	var unknown_country := CampaignConfig.create(scenario, null)
	check_gt(float(unknown_country.validate(catalog, atlas.registry).size()), 0.0,
			"a campaign without a nation cannot be confirmed")
	var good := CampaignConfig.create(scenario, atlas.registry.get_country("BGD"))
	check_eq(good.validate(catalog, atlas.registry).size(), 0,
			"a scenario plus a real country validates")
	var mismatched := CampaignConfig.create(scenario, atlas.registry.get_country("BGD"))
	mismatched.country_id = "ZZZ"
	check_gt(float(mismatched.validate(catalog, atlas.registry).size()), 0.0,
			"a country id that is not in the registry is rejected")
