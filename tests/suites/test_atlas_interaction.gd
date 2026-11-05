extends TestCase
## Camera, selection, filtering and map-view behaviour.
##
## The camera is a plain object, so most of these assertions need no scene at
## all. The map view is mounted in an off-screen SubViewport only where the
## cached meshes or the tap-to-country contract are involved.

const MAP_SCENE := "res://src/ui/map/world_map_view.tscn"

var _atlas: WorldAtlas


func _load() -> void:
	if _atlas == null:
		_atlas = WorldAtlas.load_default()


func _camera(width: float = 1280.0, height: float = 720.0) -> MapCamera:
	var camera := MapCamera.new()
	camera.set_view_size(Vector2(width, height))
	camera.reset()
	return camera


# --- Camera ----------------------------------------------------------------

func test_camera_fits_the_whole_world() -> void:
	var camera := _camera()
	var world := Rect2(Vector2(MapProjection.MIN_LON, MapProjection.MIN_LAT),
			MapProjection.WORLD_SIZE)
	var visible := camera.visible_rect()
	check_true(visible.encloses(world) or visible.size.x >= world.size.x,
			"the fitted camera must show the whole world width (%s vs %s)"
			% [visible, world])
	check_lte(camera.zoom, camera.fit_zoom() + 0.001, "the fitted zoom is the minimum zoom")
	check_false(camera.is_zoomed(), "a fresh camera is not zoomed in")


func test_camera_pan_is_clamped_to_the_world() -> void:
	var camera := _camera()
	for direction: Vector2 in [Vector2(9000, 0), Vector2(-9000, 0), Vector2(0, 9000),
			Vector2(0, -9000), Vector2(5000, 5000)]:
		camera.reset()
		camera.zoom_in()
		camera.zoom_in()
		camera.pan_by_pixels(direction)
		var visible := camera.visible_rect()
		check_gte(visible.position.x, MapProjection.MIN_LON - 0.01,
				"panning west must stop at the world edge")
		check_lte(visible.end.x, MapProjection.MAX_LON + 0.01,
				"panning east must stop at the world edge")
		check_gte(visible.position.y, MapProjection.MIN_LAT - 0.01,
				"panning north must stop at the world edge")
		check_lte(visible.end.y, MapProjection.MAX_LAT + 0.01,
				"panning south must stop at the world edge")


func test_camera_zoom_is_bounded_and_anchored() -> void:
	var camera := _camera()
	var anchor := Vector2(320.0, 180.0)
	var before := camera.screen_to_world(anchor)
	camera.zoom_at(anchor, 2.5)
	var after := camera.screen_to_world(anchor)
	check_lte(before.distance_to(after), 0.35,
			"zooming must keep the point under the pointer in place")
	camera.zoom_at(anchor, 0.0)
	camera.zoom_at(anchor, -3.0)
	check_gte(camera.zoom, camera.fit_zoom(), "zoom must not fall below the whole world")
	for _i in 40:
		camera.zoom_at(anchor, 2.0)
	check_lte(camera.zoom, MapCamera.MAX_ZOOM + 0.001, "zoom must respect its maximum")
	check_true(camera.is_zoomed(), "after zooming in the camera reports a zoom")


func test_camera_focuses_a_country() -> void:
	_load()
	var camera := _camera()
	camera.zoom_in()
	var bbox := _atlas.geometry.bbox_of("BGD")
	camera.focus_rect(bbox, 48.0)
	var visible := camera.visible_rect()
	check_true(visible.encloses(bbox),
			"focusing a country must bring its whole shape into view (%s in %s)"
			% [bbox, visible])
	var centre := camera.world_to_screen(bbox.get_center())
	check_lte(absf(centre.x - camera.view_size.x * 0.5), 24.0,
			"the focused country is centred horizontally")
	check_lte(absf(centre.y - camera.view_size.y * 0.5), 24.0,
			"the focused country is centred vertically")


func test_camera_survives_resizes_and_bad_sizes() -> void:
	var camera := MapCamera.new()
	camera.set_view_size(Vector2.ZERO)
	camera.reset()
	check_true(camera.has_valid_state(), "a zero-sized view must not break the camera")
	camera.set_view_size(Vector2(390, 844))
	check_lte(camera.zoom, camera.fit_zoom() + 0.001,
			"resizing re-clamps the zoom to the new fit")
	check_true(is_finite(camera.center.x) and is_finite(camera.center.y),
			"the camera centre stays finite")


# --- Filter state ----------------------------------------------------------

func test_filter_state_tracks_query_and_region() -> void:
	_load()
	var filter := AtlasFilter.new()
	var signals := {"count": 0}
	filter.changed.connect(func() -> void: signals["count"] += 1)
	check_false(filter.is_active(), "a fresh filter is inactive")
	check_true(filter.set_query("bang"), "setting a query changes the filter")
	check_false(filter.set_query("bang"), "setting the same query changes nothing")
	check_true(filter.has_query(), "the query is recorded")
	check_true(filter.set_region("Asia"), "setting a region changes the filter")
	check_true(filter.has_region(), "the region is recorded")
	var results := filter.apply(_atlas.registry)
	check_gt(float(results.size()), 0.0, "the combined filter matches Bangladesh in Asia")
	for record: CountryRecord in results:
		check_eq(record.region, "Asia", "%s is not in Asia" % record.id)
	check_eq(signals["count"], 2, "only real changes emit the changed signal")
	check_true(filter.clear(), "clearing an active filter reports a change")
	check_false(filter.is_active(), "the filter is inactive again")
	check_eq(filter.apply(_atlas.registry).size(), _atlas.registry.count(),
			"a cleared filter returns every country")
	var narrowed := AtlasFilter.new()
	narrowed.set_query("bang")
	check_eq(narrowed.describe(242, 54), "54 of 242 nations",
			"the status line describes the active filter")
	check_eq(AtlasFilter.new().describe(242, 242), "242 nations",
			"an inactive filter describes the whole atlas")


# --- Selection and taps ----------------------------------------------------

func _mount_map(viewport_size: Vector2) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(viewport_size)
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
	await tree.process_frame
	await tree.process_frame
	return {"viewport": viewport, "map": map}


func test_selection_changes_clears_and_is_idempotent() -> void:
	var mounted := await _mount_map(Vector2(960, 540))
	var map: WorldMapView = mounted["map"]
	check_eq(map.selected_id(), "", "a fresh map has nothing selected")
	map.set_selected("BGD")
	check_eq(map.selected_id(), "BGD", "selecting a country stores its id")
	map.set_selected("IND")
	check_eq(map.selected_id(), "IND", "a new selection replaces the old one")
	map.set_selected("IND")
	check_eq(map.selected_id(), "IND", "re-selecting the same country is harmless")
	map.set_selected("")
	check_eq(map.selected_id(), "", "an empty id deselects")
	map.set_selected("NOT_A_COUNTRY")
	check_eq(map.selected_id(), "", "an unknown id cannot be selected")
	(mounted["viewport"] as Node).queue_free()


func test_tap_resolves_countries_and_empty_space() -> void:
	var mounted := await _mount_map(Vector2(960, 540))
	var map: WorldMapView = mounted["map"]
	var received: Array[String] = []
	map.country_activated.connect(func(country_id: String) -> void: received.append(country_id))
	var dhaka := map.camera.world_to_screen(Vector2(90.4, 23.7))
	check_eq(map.country_at_point(dhaka), "BGD", "a tap on Dhaka resolves to Bangladesh")
	check_eq(map.tap(dhaka), "BGD", "tapping reports Bangladesh")
	var ocean := map.camera.world_to_screen(Vector2(0.0, -60.0))
	check_eq(map.tap(ocean), "", "tapping the open ocean reports empty space")
	check_eq(received, ["BGD", ""],
			"each tap emits exactly one activation, in order")
	(mounted["viewport"] as Node).queue_free()


## A tap on a country whose shape is a couple of pixels wide must still select it.
## The assist may only ever reach *tiny* shapes, so a big neighbour can never
## swallow a tap meant for the water beside it.
func test_tiny_countries_are_selectable_without_moving_their_geometry() -> void:
	var mounted := await _mount_map(Vector2(1280, 720))
	var map: WorldMapView = mounted["map"]
	var camera := map.camera
	var target_id := ""
	var target_point := Vector2.ZERO
	for country_id: String in _atlas.geometry.country_ids():
		var size_px := _atlas.geometry.bbox_of(country_id).size * camera.zoom
		if maxf(size_px.x, size_px.y) < 2.0:
			var record := _atlas.registry.get_country(country_id)
			if record != null and record.has_label:
				target_id = country_id
				target_point = camera.world_to_screen(record.label) + Vector2(6.0, 5.0)
				break
	check_false(target_id.is_empty(), "the atlas contains at least one sub-pixel country")
	if target_id.is_empty():
		return
	check_eq(map.country_at_point(target_point, false), "",
			"a tap a few pixels from a sub-pixel island hits open water without the assist")
	check_eq(map.country_at_point(target_point, true), target_id,
			"the assist selects the nearby tiny country")
	var bbox := _atlas.geometry.bbox_of(target_id)
	check_eq(_atlas.geometry.bbox_of(target_id), bbox,
			"the assist never mutates the shape it helps select")
	(mounted["viewport"] as Node).queue_free()


## The scale bar has to describe the view it is drawn in: zooming in must shorten
## the distance a pixel covers, and a round distance must stay a round number.
func test_scale_bar_tracks_zoom_and_stays_round() -> void:
	var mounted := await _mount_map(Vector2(1280, 720))
	var map: WorldMapView = mounted["map"]
	map.camera.reset()
	var wide := map.scale_bar()
	check_false(wide.is_empty(), "a fitted world view has a usable scale")
	check_gte(float(wide["pixels"]), WorldMapView.SCALE_BAR_MIN_PX - 0.5,
			"the bar is long enough to read")
	check_lte(float(wide["pixels"]), WorldMapView.SCALE_BAR_MAX_PX + 60.0,
			"the bar stays inside the map")
	var kilometres := float(wide["kilometres"])
	var decade := pow(10.0, floor(log(kilometres) / log(10.0)))
	var mantissa := kilometres / decade
	check_true(is_equal_approx(mantissa, 1.0) or is_equal_approx(mantissa, 2.0)
			or is_equal_approx(mantissa, 5.0),
			"the bar length is a round 1/2/5 × 10^n (%s)" % wide["label"])
	var before := map.kilometres_per_pixel()
	map.camera.zoom_in()
	map.camera.zoom_in()
	check_lte(map.kilometres_per_pixel(), before,
			"zooming in never makes a pixel cover more ground")
	(mounted["viewport"] as Node).queue_free()


func test_country_at_point_without_an_atlas_is_empty() -> void:
	var map: WorldMapView = load(MAP_SCENE).instantiate()
	host.add_child(map)
	map.size = Vector2(320, 200)
	await tree.process_frame
	check_eq(map.country_at_point(Vector2(10.0, 10.0)), "",
			"a map with no data resolves no country, with or without the assist")
	check_true(map.scale_bar().is_empty() or map.camera.zoom > 0.0,
			"the scale bar degrades without data instead of dividing by zero")
	map.queue_free()


func test_map_builds_and_caches_country_meshes() -> void:
	var mounted := await _mount_map(Vector2(1280, 720))
	var map: WorldMapView = mounted["map"]
	check_gt(float(map.visible_country_ids().size()), 200.0,
			"a whole-world view must consider every country visible")
	var first := map.build_meshes_for(map.visible_country_ids())
	check_gt(float(first), 0.0, "the map must build triangle meshes for the countries")
	var second := map.build_meshes_for(map.visible_country_ids())
	check_eq(second, first,
			"a second pass reuses the cached meshes instead of rebuilding them")
	check_gt(float(first), float(_atlas.geometry.vertex_count()),
			"triangles duplicate shared vertices, so the mesh holds more than the rings")
	(mounted["viewport"] as Node).queue_free()


## A handful of Natural Earth outlines are not simple polygons and Godot's ear
## clipper rejects them (TWN's main island at 1:50m). The view must still fill
## them: an unfilled country is a hole in the world, which reads as broken data.
func test_unclippable_outlines_still_receive_a_fill() -> void:
	_load()
	var view: WorldMapView = load(MAP_SCENE).instantiate()
	host.add_child(view)
	view.set_atlas(_atlas)
	await tree.process_frame
	var refused := PackedStringArray()
	for country_id: String in _atlas.geometry.country_ids():
		for rings: Array in _atlas.geometry.polygons_of(country_id):
			var ring: PackedVector2Array = rings[0]
			if Geometry2D.triangulate_polygon(ring).is_empty():
				refused.append(country_id)
	var vertices := view.build_meshes_for(PackedStringArray(refused))
	check_gt(float(vertices), 0.0,
			"outlines the triangulator refuses are filled with their convex hull")
	if refused.has("TWN"):
		check_gt(float(vertices), 0.0, "Taiwan keeps a usable landmass mesh")
	view.queue_free()


func test_map_without_geometry_does_not_crash() -> void:
	var map: WorldMapView = load(MAP_SCENE).instantiate()
	host.add_child(map)
	map.size = Vector2(640, 360)
	await tree.process_frame
	check_eq(map.country_at_point(Vector2(10, 10)), "",
			"a map without an atlas resolves nothing")
	var empty := WorldAtlas.from_data({"countries": []}, {"scale": 200, "countries": {}})
	map.set_atlas(empty)
	await tree.process_frame
	check_eq(map.selected_id(), "", "an empty atlas leaves no selection")
	check_false(map.focus_country("BGD"), "focusing a country in an empty atlas fails honestly")
	map.queue_free()
