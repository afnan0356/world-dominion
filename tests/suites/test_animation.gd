extends TestCase
## The animation foundation: the camera flight, the service's rules, and the table.
##
## Four promises are checked here, because they are the ones a player notices and a
## reviewer cannot see in a still image:
##
## 1. the camera flight is clamped to the world and always obeys the player;
## 2. reduced motion never animates, and never leaves a tween behind;
## 3. nothing animates when nothing changes, and a still map does no work;
## 4. every animation is in the table, documented, and slow enough not to flash.
##
## A note on style: the map view's public surface is deliberately at its size limit
## (the linter enforces it), so a few facts are read through `call("_name")` or a
## private field. That is a test reaching inside on purpose, not an API.

const MAP_SCENE := "res://src/ui/map/world_map_view.tscn"
const DOC := "res://docs/ANIMATION.md"

var _atlas: WorldAtlas
var _saved_motion: Variant = null
var _saved_detail: Variant = null


func _load() -> void:
	if _atlas == null:
		_atlas = WorldAtlas.load_default()


func _remember() -> void:
	if _saved_motion != null:
		return
	_saved_motion = Settings.get_value(SettingsSchema.KEY_MOTION)
	_saved_detail = Settings.get_value(SettingsSchema.KEY_MAP_DETAIL)


func _restore() -> void:
	if _saved_motion == null:
		return
	Settings.set_value(SettingsSchema.KEY_MOTION, _saved_motion)
	Settings.set_value(SettingsSchema.KEY_MAP_DETAIL, _saved_detail)
	_saved_motion = null
	_saved_detail = null


func _reduce_motion(enabled: bool) -> void:
	_remember()
	Settings.set_value(SettingsSchema.KEY_MOTION,
			SettingsSchema.MOTION_REDUCED if enabled else SettingsSchema.MOTION_FULL)


func _mount(host_node: Node, viewport_size: Vector2i = Vector2i(1280, 720)) -> WorldMapView:
	var viewport := SubViewport.new()
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host_node.add_child(viewport)
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


# --- The table -------------------------------------------------------------

func test_every_animation_is_complete_documented_and_slow() -> void:
	var doc := FileAccess.get_file_as_string(DOC)
	check_false(doc.is_empty(), "docs/ANIMATION.md exists and is readable")
	var ids := AnimationTokens.ids()
	check_gte(float(ids.size()), 8.0, "the table covers the animations this build ships")
	for id: String in ids:
		var entry := AnimationTokens.entry(id)
		for field: String in ["duration_ms", "easing", "trigger", "reduced", "flashes"]:
			check_true(entry.has(field), "%s declares '%s'" % [id, field])
		check_gt(AnimationTokens.duration_seconds(id), 0.0, "%s has a duration" % id)
		check_true(str(entry["reduced"]).length() > 10,
				"%s says what happens under reduced motion" % id)
		check_lte(AnimationTokens.flashes_per_second(id), 3.0,
				"%s stays at or below three flashes per second" % id)
		check_true(doc.contains("`%s`" % id),
				"%s appears in the generated animation document" % id)


func test_unknown_animation_names_are_refused() -> void:
	var host_node := Node.new()
	host.add_child(host_node)
	var service := AnimationService.new(host_node)
	check_true(AnimationTokens.has("camera_fly"), "a known name is accepted")
	check_false(AnimationTokens.has("no_such_animation"), "an unknown name is not")
	var label := Label.new()
	host_node.add_child(label)
	var tween := service.play("no_such_animation", label, "modulate:a", 0.0)
	check_true(tween == null, "playing an unknown animation creates no tween")
	check_eq(service.active_count(), 0, "and leaves nothing running")
	host_node.queue_free()


# --- The service -----------------------------------------------------------

func test_nothing_animates_when_nothing_changes() -> void:
	var host_node := Node.new()
	host.add_child(host_node)
	var service := AnimationService.new(host_node)
	var control := Control.new()
	host_node.add_child(control)
	control.modulate.a = 1.0
	var first := service.play("panel_fade", control, "modulate:a", 1.0)
	check_true(first == null, "asking for the value it already has creates no tween")
	check_eq(service.plays(), 0, "no animation was started")
	check_eq(service.active_count(), 0, "and nothing is running")
	var second := service.play("panel_fade", control, "modulate:a", 0.0)
	check_not_null(second, "asking for a different value does animate")
	check_eq(service.plays(), 1, "exactly one animation was started")
	service.cancel_all()
	check_eq(service.active_count(), 0, "cancelling empties the list")
	host_node.queue_free()


func test_reduced_motion_applies_values_without_tweens() -> void:
	_reduce_motion(true)
	var host_node := Node.new()
	host.add_child(host_node)
	var service := AnimationService.new(host_node)
	var control := Control.new()
	host_node.add_child(control)
	control.modulate.a = 1.0
	var tween := service.play("panel_fade", control, "modulate:a", 0.25)
	check_true(tween == null, "reduced motion creates no tween")
	check_true(is_equal_approx(control.modulate.a, 0.25), "the final value is applied at once")
	check_eq(service.instant_applies(), 1, "the service reports an instant apply")
	var loop := service.loop("selection_pulse", control, "modulate:a", 1.0, 0.5)
	check_true(loop == null, "a looping animation does not start under reduced motion")
	check_eq(service.active_count(), 0, "nothing is left running")
	host_node.queue_free()
	_restore()


func test_tweens_are_freed_when_the_host_leaves_the_tree() -> void:
	var host_node := Node.new()
	host.add_child(host_node)
	var service := AnimationService.new(host_node)
	var control := Control.new()
	host_node.add_child(control)
	control.modulate.a = 1.0
	var tween := service.play("panel_slide", control, "modulate:a", 0.0)
	check_not_null(tween, "the animation started")
	check_gte(float(service.active_count()), 1.0, "it is tracked while it runs")
	host_node.queue_free()
	await tree.process_frame
	await tree.process_frame
	check_eq(service.active_count(), 0,
			"closing the screen freed every tween it owned")


func test_press_feedback_is_instant_under_reduced_motion() -> void:
	_reduce_motion(true)
	var button := Button.new()
	host.add_child(button)
	button.size = Vector2(100.0, 40.0)
	PressFeedback.attach(button)
	button.button_down.emit()
	check_true(is_equal_approx(button.scale.x, 1.0),
			"a press does not scale the button when motion is reduced")
	button.queue_free()
	_restore()


# --- The camera flight -----------------------------------------------------

func test_fly_to_stays_inside_the_world() -> void:
	_reduce_motion(false)
	var map := _mount(host)
	map.size = Vector2(1280.0, 720.0)
	map.camera.set_view_size(map.size)
	map.camera.reset()
	await tree.process_frame
	var started := map.camera.center
	# France, not a record whose bounding box spans the antimeridian: for one of those
	# the box covers most of the world, clamping legitimately refits the whole map, and
	# the landing point is the middle of the Atlantic. The in-bounds assertions below
	# are what cover that case honestly.
	# The flight frames the mainland, not the whole-country box (which, for France,
	# includes French Guiana and the Pacific collectivities and puts the centre off
	# Africa's coast). Since Milestone 05 the view asks `focus_bbox_of()` for exactly
	# this rectangle, so the test asks for the same one.
	var target := _atlas.geometry.focus_bbox_of("FRA").get_center()
	check_true(map.focus_country("FRA", 56.0, true), "the flight to France starts")
	check_true(bool(map.call("_is_flying")), "the camera reports that it is flying")
	var samples := 0
	var inside := true
	var sane_zoom := true
	# Headless frames are short, so the loop waits for the flight to end rather than
	# assuming a frame rate: the flight is 440 ms whether or not anything renders.
	while bool(map.call("_is_flying")) and samples < 2400:
		await tree.process_frame
		var centre := map.camera.center
		if not is_finite(centre.x) or not is_finite(centre.y):
			inside = false
		elif rect_world().grow(0.5).has_point(centre) == false:
			inside = false
		if map.camera.zoom < map.camera.fit_zoom() - 0.0001:
			sane_zoom = false
		samples += 1
	check_false(bool(map.call("_is_flying")), "the flight finished on its own")
	check_true(inside, "every frame of the flight kept the camera inside the world")
	check_true(sane_zoom, "and inside the zoom range")
	check_gte(float(samples), 1.0, "the flight was observed for at least one frame")
	var arrived := map.camera.center
	check_true(arrived.distance_to(target) < started.distance_to(target),
			"the camera ended nearer France than it began")
	check_true(_atlas.geometry.bbox_of("FRA").grow(6.0).has_point(arrived),
			"France is what the flight finished on")
	check_true(_atlas.geometry.focus_bbox_of("FRA").grow(2.0).has_point(arrived),
			"and it settled on France's mainland, not on its overseas parts")
	# The clamp, checked rather than hidden: a record whose outline touches both map
	# edges (Russia) still finishes a flight, and the camera still obeys the clamp even
	# though its mainland rectangle reaches the edge of the world.
	check_true(map.focus_country("RUS", 56.0, true), "a second flight to Russia starts")
	var guard := 0
	while bool(map.call("_is_flying")) and guard < 2400:
		await tree.process_frame
		guard += 1
	check_false(bool(map.call("_is_flying")), "the antimeridian flight finishes too")
	check_true(rect_world().grow(0.5).has_point(map.camera.center),
			"and leaves the camera inside the world")
	map.queue_free()
	_restore()


func rect_world() -> Rect2:
	return Rect2(MapProjection.MIN_LON, MapProjection.MIN_LAT,
			MapProjection.MAX_LON - MapProjection.MIN_LON,
			MapProjection.MAX_LAT - MapProjection.MIN_LAT)


func test_user_input_cancels_a_flight_immediately() -> void:
	_reduce_motion(false)
	var map := _mount(host)
	await tree.process_frame
	map.focus_country("AUS", 56.0, true)
	check_true(bool(map.call("_is_flying")), "the flight started")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = map.size * 0.5
	map.call("_gui_input", press)
	check_false(bool(map.call("_is_flying")), "a press stops the flight at once")
	var centre := map.camera.center
	await tree.process_frame
	await tree.process_frame
	check_true(map.camera.center.distance_to(centre) < 0.001,
			"the camera stays where the player left it")
	map.queue_free()
	_restore()


func test_reduced_motion_jumps_without_a_flight() -> void:
	_reduce_motion(true)
	var map := _mount(host)
	await tree.process_frame
	var before := map.camera.zoom
	check_true(map.focus_country("JPN", 56.0, true), "selecting Japan still works")
	check_false(bool(map.call("_is_flying")), "no flight exists under reduced motion")
	check_true(map.camera.zoom >= before, "the camera has already moved to the country")
	map.queue_free()
	_restore()


# --- Idle cost -------------------------------------------------------------

func test_a_still_map_does_no_ambient_work() -> void:
	_reduce_motion(false)
	var map := _mount(host)
	await tree.process_frame
	map.set_ambient_motion(false)
	var before := int(map.get("_ambient_frames"))
	for _frame in 8:
		await tree.process_frame
	check_eq(int(map.get("_ambient_frames")), before,
			"a paused, still map does not redraw for ambience")
	map.set_ambient_motion(true)
	# Advanced by hand: the cadence is half a second, and a headless frame is much
	# shorter than that, so waiting for real time would test the runner's frame rate
	# instead of the map's behaviour.
	map.call("_process", 0.6)
	check_gt(float(map.get("_ambient_frames")), float(before),
			"a running campaign lets the sea drift")
	map.set_detail_reduced(true)
	var reduced_frames := int(map.get("_ambient_frames"))
	map.call("_process", 1.0)
	check_eq(int(map.get("_ambient_frames")), reduced_frames,
			"reduced map detail stops the ambient sea")
	map.set_detail_reduced(false)
	map.queue_free()
	_restore()


func test_selection_pulse_only_runs_when_it_should() -> void:
	_reduce_motion(false)
	var map := _mount(host)
	await tree.process_frame
	map.set_selected("BGD")
	check_gt(float(map.get("_pulse")), 0.0, "a selection starts the outline pulse")
	check_lte(AnimationTokens.flashes_per_second("selection_pulse"), 3.0,
			"the pulse is slower than three flashes per second")
	map.set_selected("")
	await tree.process_frame
	check_true(is_equal_approx(float(map.get("_pulse")), 1.0),
			"clearing the selection returns the outline to its resting weight")
	_reduce_motion(true)
	map.set_selected("BGD")
	check_true(is_equal_approx(float(map.get("_pulse")), 1.0),
			"under reduced motion the selected outline does not pulse")
	map.queue_free()
	_restore()
