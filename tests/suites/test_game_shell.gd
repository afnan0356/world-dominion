extends TestCase
## The playable shell: the game screen, its pause menu, the first-run guide, the
## load screen and the main menu's Continue entry.
##
## These tests mount the real scenes into a `SubViewport` at every reference size,
## because "it works on a desktop" is not the promise. They also drive the screen
## the way a player would — keys, signals, buttons — rather than calling internals,
## and they check the thing that is easiest to get wrong in a router-based shell:
## that entering and leaving the campaign repeatedly leaves nothing behind and no
## stale campaign.

const GAME_SCENE := "res://src/ui/screens/game_screen.tscn"
const LOAD_SCENE := "res://src/ui/screens/load_game_screen.tscn"
const MENU_SCENE := "res://src/ui/screens/main_menu.tscn"
const TEST_SAVE_DIR := "user://test_shell_saves"

var _atlas: WorldAtlas
var _original_store: SaveStore
var _original_guide := false


func _mount(scene_path: String, viewport_size: Vector2 = Vector2(1280, 720)) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(viewport_size)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Control = load(scene_path).instantiate()
	holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await tree.process_frame
	await tree.process_frame
	return {"viewport": viewport, "screen": screen, "holder": holder}


## Gives the whole suite a scratch save folder and a running campaign, and returns
## a screen mounted on that campaign. The original store is restored in `_teardown`.
func _prepare(campaign: bool = true) -> Dictionary:
	if _atlas == null:
		_atlas = WorldAtlas.load_default()
	_original_store = Game.store if _original_store == null else _original_store
	# The guide is a first-run event. Tests that are not about it start with it
	# dismissed, because an open modal deliberately stops the clock.
	_original_guide = Settings.get_guide_seen()
	Settings.set_guide_seen(true)
	var store := SaveStore.new(TEST_SAVE_DIR)
	_clear_directory(store.directory())
	Game.store = store
	Game.close()
	if campaign:
		Game.start(_config())
	return {"store": store}


func _config(country_id: String = "BGD") -> CampaignConfig:
	var config := CampaignConfig.new()
	config.scenario_id = "modern_world_2026"
	config.country_id = country_id
	config.start_date = "2026-01-01"
	var record := _atlas.registry.get_country(country_id)
	config.metadata = {"scenario_name": "Modern World",
			"country_name": record.name if record != null else country_id}
	return config


func _teardown(keep_campaign: bool = false) -> void:
	if not keep_campaign:
		Game.close()
	Game.store = _original_store
	_original_store = null
	Settings.set_guide_seen(_original_guide)


func _clear_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)


func _key(keycode: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _titles(screen: Control) -> PackedStringArray:
	var titles := PackedStringArray()
	for node: Node in screen.find_children("*", "NavRow", true, false):
		titles.append(str(node.get("title_text")))
	return titles


# --- Game screen -----------------------------------------------------------

func test_the_game_screen_shows_the_running_campaign() -> void:
	var context := await _prepare()
	var mounted := await _mount(GAME_SCENE)
	var screen: Control = mounted["screen"]
	check_true(screen.session() != null, "the screen binds to the running campaign")
	check_eq(screen.player_country_id(), "BGD", "the player's country is the confirmed one")
	var body: VBoxContainer = screen.get_node("%SideBody")
	var text := _texts_of(body)
	check_true(text.to_lower().contains("bangladesh"),
			"the dossier shows the player's country (%s)" % text.substr(0, 80))
	check_true(text.to_lower().contains("calendar"),
			"the status panel names the one system that exists")
	check_true(text.to_lower().contains("not in this version"),
			"the status panel says plainly what is missing")
	var map: WorldMapView = screen.get_node("%Map")
	check_eq(map.home_country_id(), "BGD", "the player's nation is marked on the map")
	check_true(bool(screen.call("is_paused")),
			"the campaign starts paused until the player chooses")
	(mounted["viewport"] as Node).queue_free()
	_teardown()
	check_true(not Game.has_session(), "leaving the suite leaves no campaign running")
	check_false(context["store"] == Game.store, "the real save store was restored")


func test_time_controls_change_the_clock_not_the_frame_rate() -> void:
	await _prepare()
	var mounted := await _mount(GAME_SCENE)
	var screen: Control = mounted["screen"]
	var session: GameSession = screen.session()
	var start_date := session.world.current_date().format_short()
	screen.call("toggle_pause")
	check_false(session.simulation.clock.is_paused(), "the pause button resumes the clock")
	screen.set_speed(4)
	for _frame in range(40):
		await tree.process_frame
	check_eq(session.simulation.clock.ticks_per_second(), 128.0,
			"speed 4 is 128 in-game days per second")
	check_gt(float(session.simulation.total_ticks), 0.0, "unpausing runs ticks")
	check_true(session.world.current_date().format_short() != start_date,
			"the in-game date moved")
	check_eq(session.simulation.systems().size(), 1,
			"only the calendar is simulated, however long the screen runs")
	(mounted["viewport"] as Node).queue_free()
	_teardown()


func test_pause_menu_offers_the_documented_actions_and_stops_the_clock() -> void:
	await _prepare()
	var mounted := await _mount(GAME_SCENE)
	var screen: Control = mounted["screen"]
	var session: GameSession = screen.session()
	screen.set_speed(3)
	screen.call("toggle_pause")
	screen.call("open_pause_menu")
	check_true(screen.call("pause_menu_open"), "the pause menu opens")
	var titles := _titles(screen)
	for expected: String in ["Resume", "Save", "Save as…", "Load game", "Settings",
			"Quit to main menu"]:
		check_true(titles.has(expected), "the pause menu offers %s" % expected)
	var ticks_before := session.simulation.total_ticks
	for _frame in range(30):
		await tree.process_frame
	check_eq(session.simulation.total_ticks, ticks_before,
			"an open pause menu means a stopped clock")
	screen.call("close_pause_menu")
	screen.set_speed(4)
	for _frame in range(10):
		await tree.process_frame
	check_gt(float(session.simulation.total_ticks), float(ticks_before),
			"closing the menu resumes the campaign")
	(mounted["viewport"] as Node).queue_free()
	_teardown()


func test_keyboard_shortcuts_work_as_documented() -> void:
	await _prepare()
	var mounted := await _mount(GAME_SCENE)
	var screen: Control = mounted["screen"]
	var session: GameSession = screen.session()
	check_true(session.simulation.clock.is_paused(), "the campaign starts paused")
	screen.call("_unhandled_input", _key(KEY_SPACE))
	check_false(session.simulation.clock.is_paused(), "Space resumes")
	screen.call("_unhandled_input", _key(KEY_SPACE))
	check_true(session.simulation.clock.is_paused(), "Space pauses again")
	screen.call("_unhandled_input", _key(KEY_2))
	check_eq(session.simulation.clock.speed, 2, "the number keys choose the speed")
	check_false(session.simulation.clock.is_paused(), "choosing a speed resumes the clock")
	screen.call("_unhandled_input", _key(KEY_4))
	check_eq(session.simulation.clock.speed, 4, "speed 4 is reachable by keyboard")
	screen.call("_unhandled_input", _key(KEY_ESCAPE))
	check_true(screen.call("pause_menu_open"), "Escape opens the pause menu")
	check_true(session.simulation.clock.is_paused(), "opening the menu pauses")
	screen.call("_unhandled_input", _key(KEY_ESCAPE))
	check_false(screen.call("pause_menu_open"), "Escape closes the pause menu again")
	(mounted["viewport"] as Node).queue_free()
	_teardown()


func test_selecting_another_country_never_changes_who_you_lead() -> void:
	await _prepare()
	var mounted := await _mount(GAME_SCENE)
	var screen: Control = mounted["screen"]
	var map: WorldMapView = screen.get_node("%Map")
	var before: String = screen.player_country_id()
	map.country_activated.emit("NPL")
	await tree.process_frame
	check_eq(screen.player_country_id(), before,
			"tapping a neighbour does not change the player's country")
	check_eq(map.home_country_id(), before, "the home badge does not move")
	check_eq(screen.viewed_country_id(), "NPL", "the dossier follows the tap")
	var body: VBoxContainer = screen.get_node("%SideBody")
	check_true(_texts_of(body).to_lower().contains("nepal"),
			"the dossier is the tapped country's")
	map.country_activated.emit("")
	check_true(str(screen.viewed_country_id()).is_empty(),
			"deselecting clears the dossier instead of leaving stale text")
	check_eq(screen.player_country_id(), before,
			"deselecting never touches the campaign's country")
	(mounted["viewport"] as Node).queue_free()
	_teardown()


func test_saving_from_the_game_screen_writes_a_loadable_slot() -> void:
	var context := await _prepare()
	var mounted := await _mount(GAME_SCENE)
	var screen: Control = mounted["screen"]
	var session: GameSession = screen.session()
	screen.set_speed(4)
	screen.call("toggle_pause")
	for _frame in range(20):
		await tree.process_frame
	var saved: Dictionary = screen.save_to_slot("2")
	check_true(bool(saved["ok"]), "saving from the pause menu succeeds (%s)"
			% str(saved["errors"]))
	var store: SaveStore = context["store"]
	check_true(store.exists("2"), "the slot exists on disk")
	var loaded := store.load_slot("2", _atlas.registry)
	check_true(bool(loaded["ok"]), "the slot it wrote loads")
	if bool(loaded["ok"]):
		check_eq((loaded["world"] as WorldState).state_hash(), session.world.state_hash(),
				"the save is the campaign that is being played")
	(mounted["viewport"] as Node).queue_free()
	_teardown()


func test_the_first_run_guide_appears_once_and_can_be_reopened() -> void:
	await _prepare()
	Settings.set_guide_seen(false)
	var mounted := await _mount(GAME_SCENE)
	var screen: Control = mounted["screen"]
	await tree.process_frame
	check_true(screen.call("guide_open"), "the guide opens on a first campaign")
	var step_text := str(screen.call("guide_text"))
	check_false(step_text.is_empty(), "the guide has something to say")
	check_false(step_text.to_lower().contains("economy is simulated"),
			"the guide does not promise a simulation that does not exist")
	check_gte(float(screen.call("guide_step_count")), 3.0, "the guide has a few steps")
	screen.call("close_guide")
	check_false(screen.call("guide_open"), "the guide closes")
	check_true(Settings.get_guide_seen(), "closing the guide records that it was seen")
	screen.call("open_guide")
	check_true(screen.call("guide_open"), "the guide can be reopened from the pause menu")
	screen.call("close_guide")
	(mounted["viewport"] as Node).queue_free()
	_teardown()


# --- Layout and lifetime ---------------------------------------------------

func test_the_shell_fits_every_reference_size() -> void:
	await _prepare()
	var sizes := {
		"desktop 1920x1080": Vector2(1920, 1080),
		"desktop 1280x720": Vector2(1280, 720),
		"tablet 1024x768": Vector2(1024, 768),
		"phone landscape 844x390": Vector2(844, 390),
		"small landscape 640x360": Vector2(640, 360),
		"phone portrait 390x844": Vector2(390, 844),
	}
	for label: String in sizes:
		var viewport_size: Vector2 = sizes[label]
		var mounted := await _mount(GAME_SCENE, viewport_size)
		var screen: Control = mounted["screen"]
		var map: WorldMapView = screen.get_node("%Map")
		var panel: Control = screen.get_node("%SidePanel")
		var top: Control = screen.get_node("%TopBar")
		check_true(map.is_visible_in_tree(), "%s: the map is on screen" % label)
		check_gt(map.size.x, 60.0, "%s: the map keeps a usable width" % label)
		check_gt(map.size.y, 50.0, "%s: the map keeps a usable height" % label)
		check_true(panel.is_visible_in_tree(), "%s: the dossier panel is visible" % label)
		check_gt(panel.size.y, 40.0, "%s: the dossier panel has room" % label)
		check_lte(top.get_global_rect().end.y, viewport_size.y,
				"%s: the top bar never spills past the screen" % label)
		check_lte(panel.get_global_rect().end.x, viewport_size.x + 1.0,
				"%s: the dossier stays inside the screen" % label)
		for button: Node in top.find_children("*", "Button", true, false):
			var control := button as Control
			if control != null and control.is_visible_in_tree():
				check_gte(control.size.y, 32.0,
						"%s: every top-bar control stays tappable" % label)
		(mounted["viewport"] as Node).queue_free()
	_teardown()


func test_repeated_enter_and_leave_leaves_nothing_behind() -> void:
	await _prepare()
	var baseline := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for _cycle in range(3):
		var mounted := await _mount(GAME_SCENE)
		var screen: Control = mounted["screen"]
		check_not_null(screen.session(), "every entry finds the campaign")
		(mounted["viewport"] as Node).queue_free()
		for _frame in range(3):
			await tree.process_frame
	check_true(Game.has_session(), "browsing the shell never drops the running campaign")
	var after := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	check_lte(float(after), float(baseline) + 4.0,
			"three enter/leave cycles free everything they made (%d -> %d)"
					% [baseline, after])
	_teardown()


# --- Load screen and main menu ---------------------------------------------

func test_the_load_screen_lists_and_loads_a_slot() -> void:
	var context := await _prepare()
	var store: SaveStore = context["store"]
	var world: WorldState = Game.current_session().world
	check_true(bool(store.save("2", world, "2026-01-01T00:00:00Z",
			"2026-02-01T00:00:00Z")["ok"]), "a slot is prepared for the screen")
	Game.close()
	var mounted := await _mount(LOAD_SCENE)
	var screen: Control = mounted["screen"]
	check_eq(screen.call("slot_row_count"), SaveStore.SLOT_IDS.size(),
			"every slot has a row, including empty ones")
	var entry: Dictionary = screen.call("entry_for", "2")
	check_true(bool(entry.get("valid", false)), "the saved slot is listed as valid")
	check_false(bool(screen.call("entry_for", "3").get("valid", true)),
			"an empty slot is not listed as valid")
	var opened := [""]
	screen.navigation_requested.connect(func(screen_id: String, _params: Dictionary) -> void:
		opened[0] = screen_id)
	var result: Dictionary = screen.call("load_slot", "2")
	check_true(bool(result["ok"]), "the slot loads from the screen")
	check_eq(opened[0], "game", "loading a slot asks the shell to open the game screen")
	check_true(Game.has_session(), "the loaded campaign became the running one")
	(mounted["viewport"] as Node).queue_free()
	_teardown()


func test_continue_is_available_only_with_a_valid_save() -> void:
	var context := await _prepare(false)
	Game.close()
	var empty_mount := await _mount(MENU_SCENE)
	var empty_row: NavRow = empty_mount["screen"].get_node("%ContinueCampaign")
	check_true(empty_row.disabled, "Continue is disabled when nothing can be continued")
	check_false(str(empty_row.status_text).is_empty(),
			"and it says why rather than looking broken")
	(empty_mount["viewport"] as Node).queue_free()

	var store: SaveStore = context["store"]
	var world := WorldState.new_campaign(_config(), _atlas.registry, DataStamp.compute(_atlas),
			777)
	check_true(bool(store.save("1", world, "2026-01-01T00:00:00Z",
			"2026-02-01T00:00:00Z")["ok"]), "a save is written")
	var full_mount := await _mount(MENU_SCENE)
	var full_row: NavRow = full_mount["screen"].get_node("%ContinueCampaign")
	check_false(full_row.disabled, "Continue becomes available with a valid save")
	full_row.pressed.emit()
	await tree.process_frame
	check_true(Game.has_session(), "Continue loads the most recent valid save")
	check_eq(Game.current_session().world.seed_value, 777, "it loads the campaign that was saved")
	(full_mount["viewport"] as Node).queue_free()
	_teardown()


func _texts_of(node: Node) -> String:
	var parts := PackedStringArray()
	for child: Node in node.find_children("*", "Label", true, false):
		var label := child as Label
		if label != null:
			parts.append(label.text)
	return " ".join(parts)

