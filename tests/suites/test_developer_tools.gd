extends TestCase
## The measuring tools: performance overlay, developer settings and the stress test.
##
## Two things are being protected. The developer tools must be off by default and
## harmless when on — they never write a metric to disk, never send anything and
## never change gameplay. And the stress test must be *repeatable*: its camera path
## is a pure function of time, so a device's numbers can be trusted and compared.

const SETTINGS_SCENE := "res://src/ui/screens/settings_screen.tscn"
const SETUP_SCENE := "res://src/ui/screens/campaign_setup.tscn"


func test_developer_settings_are_off_by_default() -> void:
	check_eq(SettingsSchema.defaults().get(SettingsSchema.KEY_PERF_OVERLAY), false,
			"the performance overlay is off until asked for")
	check_eq(SettingsSchema.defaults().get(SettingsSchema.KEY_DEV_TOOLS), false,
			"developer tools are off until asked for")
	check_eq(SettingsSchema.defaults().get(SettingsSchema.KEY_MAP_DETAIL),
			SettingsSchema.DETAIL_FULL, "full map detail is the default")
	check_true(SettingsSchema.keys().has(SettingsSchema.KEY_PERF_OVERLAY),
			"the overlay is part of the persisted schema")


func test_developer_settings_round_trip_and_sanitise() -> void:
	check_eq(SettingsSchema.sanitize(SettingsSchema.KEY_PERF_OVERLAY, "true"), true,
			"a stored string 'true' becomes a bool")
	check_eq(SettingsSchema.sanitize(SettingsSchema.KEY_PERF_OVERLAY, 1), false,
			"a nonsense value falls back to the default instead of a truthy accident")
	check_eq(SettingsSchema.sanitize(SettingsSchema.KEY_MAP_DETAIL, "sideways"),
			SettingsSchema.DETAIL_FULL, "an unknown detail level falls back to full")
	check_eq(SettingsSchema.sanitize(SettingsSchema.KEY_MAP_DETAIL, "reduced"),
			SettingsSchema.DETAIL_REDUCED, "a known detail level is accepted")
	check_eq(SettingsSchema.detail_label(SettingsSchema.DETAIL_REDUCED), "Reduced",
			"the detail level has a plain-language label")


func test_overlay_toggle_persists_and_follows_f3() -> void:
	var before := Settings.get_show_performance_overlay()
	Settings.set_show_performance_overlay(true)
	check_true(Settings.get_show_performance_overlay(), "the setting can be turned on")
	check_eq(Settings.toggle_performance_overlay(), false, "the F3 toggle flips it back")
	check_false(Settings.get_show_performance_overlay(), "the toggle writes through")
	Settings.set_show_performance_overlay(before)


func test_reduced_detail_changes_map_drawing_not_geography() -> void:

	var map := WorldMapView.new()
	host.add_child(map)
	map.set_atlas(WorldAtlas.load_default())
	map.size = Vector2(1280, 720)
	await tree.process_frame
	check_false(map.detail_reduced(), "the map starts at full detail")
	map.camera.set_view(Vector2(10.0, 51.0),
			map.camera.fit_zoom() * WorldMapView.CAPITAL_MARKER_ZOOM * 1.5)
	var full_visible := map.visible_country_ids().size()
	var full_labels := map.label_layout().size()
	var full_markers := (map.capital_layout()["markers"] as Array).size()
	check_gt(float(full_markers), 0.0, "the full-detail close-up draws capital markers")
	map.set_detail_reduced(true)
	check_true(map.detail_reduced(), "reduced detail is applied")
	var reduced_labels := map.label_layout().size()
	var reduced_markers := (map.capital_layout()["markers"] as Array).size()
	check_lte(float(reduced_labels), float(full_labels),
			"reduced detail never draws more labels")
	check_lte(float(reduced_markers), float(full_markers),
			"reduced detail never draws more capital markers")
	check_eq(map.visible_country_ids().size(), full_visible,
			"reduced detail does not hide countries from selection")
	map.set_detail_reduced(false)
	map.queue_free()


func test_stress_path_is_deterministic() -> void:
	var first := MapStressTest.new()
	var second := MapStressTest.new()
	first.start()
	second.start()
	# Same elapsed time must give the same camera, whatever the frame pacing.
	first.elapsed = 7.5
	second.elapsed = 7.5
	var a := first.camera_state()
	var b := second.camera_state()
	check_eq(a["center"], b["center"], "the same moment puts the camera in the same place")
	check_eq(a["zoom_factor"], b["zoom_factor"], "the same moment gives the same zoom")
	var start_state := MapStressTest.new()
	start_state.start()
	check_eq(start_state.camera_state()["fraction"], 0.0, "a run starts at the west edge")
	start_state.elapsed = start_state.duration
	check_eq(start_state.camera_state()["fraction"], 1.0, "a run ends at the east edge")
	# The path must stay inside the map's legal coordinates.
	var probe := MapStressTest.new()
	probe.start()
	for step: int in range(0, 101):
		probe.elapsed = probe.duration * float(step) / 100.0
		var state := probe.camera_state()
		var center: Vector2 = state["center"]
		check_gte(center.x, -180.0, "the path never leaves the world (longitude)")
		check_lte(center.x, 180.0, "the path never leaves the world (longitude)")
		check_gte(center.y, -90.0, "the path never leaves the world (latitude)")
		check_lte(center.y, 90.0, "the path never leaves the world (latitude)")
		check_gte(float(state["zoom_factor"]), 1.0, "the path never zooms past the fit view")
		check_lte(float(state["zoom_factor"]), 8.0, "the path never zooms closer than planned")


func test_stress_run_stops_at_the_documented_duration() -> void:
	var run := MapStressTest.new()
	run.start()
	var frames := 0
	# 30 seconds at a steady 60 fps, delivered as fixed deltas.
	while run.running and frames < 10000:
		run.advance(1.0 / 60.0)
		frames += 1
	check_false(run.running, "the run ends on its own")
	# 30 s at 60 fps is 1800 frames; a float accumulation may add the one frame
	# that crosses the finish line, so allow exactly that and nothing more.
	check_true(absf(float(frames) - 1800.0) <= 1.0,
			"30 seconds at 60 fps is 1800 frames (%d)" % frames)
	var stats := run.summary()
	check_eq(int(stats["count"]), frames, "every frame is sampled")
	check_eq(int(stats["stalls"]), 0, "no stall is reported for steady frames")
	check_true(absf(float(stats["average_ms"]) - 16.6667) < 0.01,
			"the average frame time is the one fed in (%.3f ms)" % float(stats["average_ms"]))


func test_stress_summary_excludes_stalls() -> void:
	var run := MapStressTest.new()
	run.start()
	for _i: int in range(0, 100):
		run.advance(0.016)
	run.advance(2.0)
	run.advance(0.016)
	var stats := run.summary()
	check_eq(int(stats["count"]), 101, "a 2-second stall is not counted as a frame")
	check_eq(int(stats["stalls"]), 1, "the stall is counted separately")
	check_lte(float(stats["worst_ms"]), MapStressTest.STALL_MS,
			"the worst frame stays a real frame time")


func test_stress_verdicts_follow_the_documented_thresholds() -> void:
	var smooth := MapStressTest.evaluate(12.0, 600)
	check_eq(smooth["verdict"], MapStressTest.VERDICT_SMOOTH, "12 ms is smooth")
	var acceptable := MapStressTest.evaluate(25.0, 600)
	check_eq(acceptable["verdict"], MapStressTest.VERDICT_ACCEPTABLE, "25 ms is acceptable")
	var slow := MapStressTest.evaluate(41.0, 600)
	check_eq(slow["verdict"], MapStressTest.VERDICT_SLOW, "41 ms is too slow")
	check_true(str(slow["detail"]).contains("Reduced map detail"),
			"a slow verdict points at the documented remedy")
	var empty := MapStressTest.evaluate(10.0, 3)
	check_eq(empty["verdict"], MapStressTest.VERDICT_INCOMPLETE,
			"a run of three frames is not reported as a result")
	check_eq(MapStressTest.evaluate(0.0, 0)["verdict"], MapStressTest.VERDICT_INCOMPLETE,
			"no samples means no verdict")
	check_eq(MapStressTest.percentile(PackedFloat32Array(), 0.95), 0.0,
			"an empty sample set has no percentile")
	var values := PackedFloat32Array([1.0, 2.0, 3.0, 4.0])
	check_eq(MapStressTest.percentile(values, 0.95), 4.0, "the 95th percentile is the top value")


func test_stress_test_needs_developer_tools() -> void:
	var settings_screen: Control = load(SETTINGS_SCENE).instantiate()
	host.add_child(settings_screen)
	var buttons := settings_screen.find_children("*", "Button", true, false)
	var stress_button: Button = null
	for button: Button in buttons:
		if button.text.contains("stress test"):
			stress_button = button
	check_not_null(stress_button, "settings can start the stress test")
	var was_enabled := Settings.get_developer_tools()
	Settings.set_developer_tools(false)
	check_false(stress_button.visible, "with developer tools off the button is hidden")
	Settings.set_developer_tools(true)
	check_true(stress_button.visible, "with developer tools on the button appears")
	Settings.set_developer_tools(was_enabled)
	settings_screen.queue_free()


func test_campaign_screen_ignores_a_stress_request_when_tools_are_off() -> void:
	var screen: Control = load(SETUP_SCENE).instantiate()
	host.add_child(screen)
	var was_enabled := Settings.get_developer_tools()
	Settings.set_developer_tools(false)
	screen.call("receive_params", {"stress_test": true})
	check_false(bool(screen.call("is_stress_test_running")),
			"a bypassed request does not start the test")
	Settings.set_developer_tools(was_enabled)
	screen.queue_free()


func test_overlay_reports_samples_and_stays_harmless() -> void:
	var overlay := PerformanceOverlay.new()
	host.add_child(overlay)
	Settings.set_show_performance_overlay(true)
	check_true(overlay.visible, "the overlay follows the setting")
	for _i: int in range(0, 40):
		overlay._process(0.016)
	var stats := overlay.stats()
	check_gte(float(stats["count"]), 40.0, "frames are sampled")
	check_lte(float(stats["worst_ms"]), MapStressTest.STALL_MS,
			"a rolling window keeps only real frames")
	check_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"the overlay never eats a click meant for the map")
	Settings.set_show_performance_overlay(false)
	check_false(overlay.visible, "turning the setting off hides it")
	overlay.queue_free()


func test_developer_documents_exist() -> void:
	for path: String in ["res://docs/PERFORMANCE.md", "res://docs/START_NATIONS.md",
			"res://docs/DISPUTED_TERRITORIES.md"]:
		check_true(FileAccess.file_exists(path), "%s is published" % path.get_file())
