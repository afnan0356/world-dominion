extends TestCase
## The map polish layer: coastline hints, display options and the recent list.
##
## Three separate promises are checked here.
##
## 1. The renderer's coastline hint (`data/world/coast.json`) lines up with the
##    geometry it describes, ring for ring, and a missing file never invents a
##    coastline — the map falls back to a plain border.
## 2. The display options are display only: they change what is drawn and never
##    what can be tapped, and every value survives a round trip through the
##    settings store, including a nonsense value written by a broken file.
## 3. "Recently viewed" is local convenience, capped and deduplicated, and it
##    drops records that no longer exist instead of leaving dead entries.

const MAP_SCENE := "res://src/ui/map/world_map_view.tscn"

var _atlas: WorldAtlas
var _saved: Dictionary = {}


func _load() -> void:
	if _atlas == null:
		_atlas = WorldAtlas.load_default()


func _remember_settings() -> void:
	if not _saved.is_empty():
		return
	for key: String in [SettingsSchema.KEY_MAP_LABELS, SettingsSchema.KEY_MAP_BORDERS,
			SettingsSchema.KEY_MAP_GRATICULE, SettingsSchema.KEY_MAP_CAPITALS,
			SettingsSchema.KEY_MAP_REFERENCE_LINES, SettingsSchema.KEY_RECENT_COUNTRIES,
			SettingsSchema.KEY_MAP_DETAIL]:
		_saved[key] = Settings.get_value(key)


func _restore_settings() -> void:
	for key: String in _saved:
		Settings.set_value(key, _saved[key])
	_saved.clear()


func _mount(host: Node, viewport_size: Vector2i = Vector2i(1280, 720)) -> WorldMapView:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var map: WorldMapView = load(MAP_SCENE).instantiate()
	holder.add_child(map)
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_load()
	map.set_atlas(_atlas)
	return map


# --- Coastline hints -------------------------------------------------------

func test_every_country_has_one_code_per_ring() -> void:
	_load()
	for country_id: String in _atlas.geometry.country_ids():
		var rings := _atlas.geometry.rings_of(country_id)
		var codes := _atlas.geometry.ring_coast_codes(country_id)
		check_eq(codes.length(), rings.size(),
				"%s: %d rings need %d codes" % [country_id, rings.size(), rings.size()])
		var unknown := ""
		for index in codes.length():
			if not codes[index] in ["0", "1", "2"]:
				unknown = codes[index]
		check_true(unknown.is_empty(),
				"%s: coast codes are only 0 (land border), 1 (coast) or 2 (mixed)" % country_id)


func test_known_coastline_examples() -> void:
	_load()
	var mali := _atlas.geometry.ring_coast_codes("MLI")
	check_true(not mali.is_empty(), "Mali has rings")
	check_eq(mali.count("0"), mali.length(),
			"landlocked Mali has no coastline at all")
	var australia := _atlas.geometry.ring_coast_codes("AUS")
	check_true(not australia.is_empty(), "Australia has rings")
	check_eq(australia.count("1"), australia.length(),
			"an island continent's rings are all coastline")
	var bangladesh := _atlas.geometry.ring_coast_codes("BGD")
	check_true(bangladesh.contains("1"), "Bangladesh has a sea coast")
	check_true(bangladesh.contains("2"),
			"Bangladesh has at least one ring that mixes border and coast")


func test_missing_coast_data_never_invents_a_coastline() -> void:
	# An atlas built without the hint file must report plain borders, not a
	# coastline drawn around an inland border.
	var data := {
		"scale": 200,
		"countries": {
			"AAA": {"polygons": [[[[0, 0], [100, 0], [100, 100], [0, 100]]]]},
		},
	}
	var geometry := WorldGeometry.from_data(data, "inline")
	check_eq(geometry.ring_coast_codes("AAA"), "0",
			"without a coast file every ring is a plain border")
	check_eq(geometry.ring_coast_codes("ZZZ"), "",
			"a country with no rings has no codes")
	var with_coast := WorldGeometry.from_data(data, "inline",
			{"countries": {"AAA": "1"}})
	check_eq(with_coast.ring_coast_codes("AAA"), "1",
			"a supplied hint is reported as given")
	var padded := WorldGeometry.from_data(data, "inline",
			{"countries": {"AAA": "11"}})
	check_eq(padded.ring_coast_codes("AAA"), "1",
			"codes longer than the ring count are trimmed, never trusted blindly")


# --- Display options -------------------------------------------------------

func test_options_round_trip_through_settings() -> void:
	_remember_settings()
	MapOptions.set_labels(SettingsSchema.LABEL_DENSITY_SPARSE)
	MapOptions.set_borders(false)
	MapOptions.set_graticule(false)
	MapOptions.set_capitals(false)
	MapOptions.set_reference_lines(false)
	var snapshot := MapOptions.snapshot()
	check_eq(snapshot["labels"], SettingsSchema.LABEL_DENSITY_SPARSE, "label density is stored")
	check_false(snapshot["borders"], "borders are stored")
	check_false(snapshot["graticule"], "the graticule is stored")
	check_false(snapshot["capitals"], "capital markers are stored")
	check_false(snapshot["reference_lines"], "reference lines are stored")
	MapOptions.set_labels("nonsense")
	check_eq(MapOptions.labels(), SettingsSchema.LABEL_DENSITY_FULL,
			"an unknown density falls back to the default instead of breaking the map")
	MapOptions.set_labels(SettingsSchema.LABEL_DENSITY_FULL)
	MapOptions.set_borders(true)
	MapOptions.set_graticule(true)
	MapOptions.set_capitals(true)
	MapOptions.set_reference_lines(true)
	_restore_settings()
	check_eq(MapOptions.labels(), SettingsSchema.LABEL_DENSITY_FULL, "settings restored")


func test_display_options_never_change_hit_boxes() -> void:
	_remember_settings()
	var map := _mount(host)
	await tree.process_frame
	map.set_options({"labels": SettingsSchema.LABEL_DENSITY_SPARSE, "borders": false,
			"graticule": false, "capitals": false, "reference_lines": false})
	await tree.process_frame
	# A point that is definitely on land: the label anchor of a large country, put
	# through the same camera the view uses.
	var brazil := _atlas.registry.get_country("BRA")
	check_not_null(brazil, "Brazil exists in the atlas")
	var probe := map.camera.world_to_screen(brazil.label)
	var before := map.country_at_point(probe)
	check_false(before.is_empty(), "a tap on Brazil lands on a country")
	map.set_detail_reduced(true)
	await tree.process_frame
	check_eq(map.country_at_point(probe), before,
			"reduced detail must not change what a tap selects")
	check_true(map.draw_stats().get("reduced_detail", false),
			"the reduced-detail flag is reported")
	map.set_detail_reduced(false)
	map.queue_free()
	_restore_settings()


func test_label_density_is_capped_and_reduced_detail_is_thinner() -> void:
	_remember_settings()
	var map := _mount(host)
	await tree.process_frame
	map.set_options({"labels": SettingsSchema.LABEL_DENSITY_FULL})
	await tree.process_frame
	var full := map.label_layout()
	check_true(full.size() > 0, "the fitted map places at least one label")
	map.set_options({"labels": SettingsSchema.LABEL_DENSITY_SPARSE})
	await tree.process_frame
	var sparse := map.label_layout()
	check_lte(float(sparse.size()), 14.0, "the sparse density never exceeds its cap")
	check_lte(float(sparse.size()), float(full.size()),
			"the sparse density never draws more labels than full")
	for entry: Dictionary in sparse:
		var rect: Rect2 = entry["rect"]
		check_true(rect.position.x >= 0.0 and rect.end.x <= map.size.x,
				"a sparse label stays inside the view")
	map.set_detail_reduced(true)
	await tree.process_frame
	var reduced := map.label_layout()
	check_lte(float(reduced.size()), float(sparse.size()),
			"reduced detail does not add labels")
	map.set_detail_reduced(false)
	map.queue_free()
	_restore_settings()


# --- Recently viewed -------------------------------------------------------

func test_recent_list_is_newest_first_deduplicated_and_capped() -> void:
	_remember_settings()
	AtlasHistory.clear()
	for country_id: String in ["BGD", "USA", "IND", "BGD", "NPL", "BTN", "LKA",
			"MMR", "THA", "VNM", "KHM"]:
		AtlasHistory.remember(country_id)
	var recent := AtlasHistory.recent()
	check_lte(float(recent.size()), float(SettingsSchema.RECENT_LIMIT),
			"the recent list is capped")
	check_eq(recent[0], "KHM", "the newest entry comes first")
	check_eq(recent[1], "VNM", "the second newest follows")
	var unique := {}
	for country_id: String in recent:
		unique[country_id] = true
	check_eq(unique.size(), recent.size(), "an entry is never stored twice")
	check_false(recent.has("BGD"),
			"a country seen early has moved out of the capped list, not duplicated")
	AtlasHistory.clear()
	AtlasHistory.remember("BGD")
	AtlasHistory.remember("USA")
	AtlasHistory.remember("BGD")
	var doubled := AtlasHistory.recent()
	check_eq(doubled.size(), 2, "viewing a country twice does not duplicate it")
	check_eq(doubled[0], "BGD", "the re-viewed country moves to the front")
	AtlasHistory.remember("")
	check_eq(AtlasHistory.recent().size(), 2, "an empty id is ignored")
	AtlasHistory.clear()
	check_eq(AtlasHistory.recent().size(), 0, "the list can be cleared")
	_restore_settings()


func test_recent_list_drops_unknown_countries() -> void:
	_remember_settings()
	_load()
	AtlasHistory.clear()
	AtlasHistory.remember("BGD")
	AtlasHistory.remember("NOT_A_COUNTRY")
	var valid := AtlasHistory.recent_valid(_atlas.registry)
	check_eq(valid.size(), 1, "only a real record survives validation")
	check_eq(valid[0], "BGD", "the surviving record is the real one")
	check_eq(AtlasHistory.recent_valid(null).size(), 0, "no registry means no list")
	AtlasHistory.clear()
	_restore_settings()
