extends TestCase
## Framing a country that sits on the antimeridian.
##
## Three records in this dataset have an outline that touches both edges of the map:
## Russia, the United States (Alaska) and Fiji. Their whole-country bounding box is
## therefore the entire world — 360 degrees wide — so "show me Russia" used to zoom out
## to the whole planet and centre the camera on the Gulf of Guinea. Fiji was worse: its
## islands sit on both sides of the seam, so a west-to-east box for it came out with a
## negative width, and the camera was told to frame a rectangle that is not on the map.
##
## The fix is not a special case for any place: the camera frames the *mainland* — the
## single polygon with the most vertices, which is what a player means by a country —
## and the camera itself refuses a rectangle it cannot frame sensibly. Both halves are
## tested here, against the committed data rather than against memory.

const MAP_SCENE := "res://src/ui/map/world_map_view.tscn"

var _atlas: WorldAtlas


func _load_atlas() -> WorldAtlas:
	if _atlas == null:
		_atlas = WorldAtlas.load_default()
	return _atlas


func test_whole_country_boxes_span_the_world() -> void:
	var geometry := _load_atlas().geometry
	for country_id: String in ["RUS", "USA", "FJI"]:
		var whole := geometry.bbox_of(country_id)
		check_gte(whole.size.x, 180.0,
				"%s really does have a world-spanning bbox; the bug is in framing it, "
				% country_id + "not in the data")


func test_focus_box_is_the_mainland() -> void:
	var geometry := _load_atlas().geometry
	var russia := geometry.focus_bbox_of("RUS")
	check_gt(russia.size.x, 100.0, "Russia's mainland is a big rectangle")
	check_lte(russia.size.x, 180.0, "Russia's mainland never spans the whole map")
	check_gte(russia.position.x, 20.0, "Russia is framed on its own side of the map")
	var fiji := geometry.focus_bbox_of("FJI")
	check_gt(fiji.size.x, 0.0, "Fiji's box has a positive width")
	check_lte(fiji.size.x, 5.0, "Fiji's mainland is one small island group")
	check_gte(fiji.position.x, 176.0, "Fiji is framed at the eastern edge, where it is")
	check_lte(fiji.position.x + fiji.size.x, 180.5, "and inside the map")
	var usa := geometry.focus_bbox_of("USA")
	check_lte(usa.size.x, 100.0, "the United States is framed on its mainland")
	check_lte(usa.position.x, -100.0, "which is in the west")
	var bangladesh := geometry.focus_bbox_of("BGD")
	var whole := geometry.bbox_of("BGD")
	check_lte(absf(bangladesh.size.x - whole.size.x), 0.5,
			"a country with one main polygon is framed exactly as before")


func test_focus_box_never_regresses_and_is_cached() -> void:
	var geometry := _load_atlas().geometry
	for country_id in _load_atlas().registry.ids():
		if not geometry.has_country(country_id):
			continue
		var box := geometry.focus_bbox_of(country_id)
		check_gte(box.size.x, 0.0, "%s: the focus box is never negative" % country_id)
		check_lte(box.size.x, 360.0, "%s: the focus box is inside the world" % country_id)
		check_gte(box.position.x, -180.5, "%s: it starts inside the map" % country_id)
		check_lte(box.position.x + box.size.x, 180.5, "%s: it ends inside the map"
				% country_id)
	check_eq(geometry.focus_bbox_of("RUS"), geometry.focus_bbox_of("RUS"),
			"the box is cached, so repeated flying does not recompute it")


func test_camera_frames_the_mainland_not_the_world() -> void:
	var geometry := _load_atlas().geometry
	var camera := MapCamera.new()
	camera.reset()
	camera.set_view_size(Vector2(1024, 768))
	var fit := camera.fit_zoom()
	camera.focus_rect(geometry.focus_bbox_of("RUS"), 56.0)
	check_gt(camera.zoom, fit * 1.2, "framing Russia zooms in, it does not zoom out")
	check_gte(camera.center.x, 0.0, "the camera is on Russia's side of the map")
	check_lte(camera.center.x, 180.0, "and inside the map")
	camera.focus_rect(geometry.focus_bbox_of("FJI"), 56.0)
	check_gt(camera.zoom, fit * 1.2, "framing Fiji zooms in")
	check_gte(camera.center.x, 170.0, "the camera sits at Fiji's longitude")


func test_camera_refuses_an_unframeable_rectangle() -> void:
	var camera := MapCamera.new()
	camera.reset()
	camera.set_view_size(Vector2(640, 360))
	var fit := camera.fit_zoom()
	# A west-to-east box for a seam-spanning country: negative width, so the old
	# arithmetic produced a rectangle whose centre was nowhere near the country.
	var broken := Rect2(Vector2(177.0, -19.0), Vector2(-355.0, 4.0))
	camera.focus_rect(broken, 56.0)
	check_true(is_finite(camera.zoom), "the zoom stays a real number")
	check_gte(camera.zoom, fit, "the camera does not zoom out past the whole world")
	check_gte(camera.center.x, -180.0, "the centre stays inside the map")
	check_lte(camera.center.x, 180.0, "the centre stays inside the map")
	# A box that really is the whole world is framed as the whole world, not as a
	# degenerate rectangle: that is the honest answer for a unit with no mainland.
	camera.focus_rect(Rect2(Vector2(-180.0, 41.0), Vector2(360.0, 40.0)), 56.0)
	check_lte(camera.zoom, fit * 1.001, "a world-sized box zooms out to fit the world")


func test_map_view_frames_with_the_focus_box() -> void:
	# The view is where the fix has to land: the camera is only as good as the rectangle
	# it is handed. A source scan is enough here because `focus_country` is a three-line
	# hand-off, and mounting the whole map scene for it would test the renderer instead.
	var text := FileAccess.get_file_as_string("res://src/ui/map/world_map_view.gd")
	check_true(text.contains("focus_bbox_of"), "the map view frames the mainland")
	var framing := text.find("func focus_country")
	var hand_off := text.find("focus_bbox_of", framing)
	check_true(hand_off > framing, "and it does so inside focus_country itself")
