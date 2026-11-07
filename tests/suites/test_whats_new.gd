extends TestCase
## What is new (Milestone 11, Task 5).
##
## Three things are asserted here, and they are different kinds of claim:
##   * the page tells the truth — every sentence carries files that exist, every string key
##     resolves, and the version it shows is the one in the project file;
##   * the page is reachable — from the main menu's Library group and from the pause menu of a
##     running campaign, which are the two places a player would look;
##   * the page survives a small window — 640x360 is the smallest reference size, and a screen
##     whose text runs off the edge is not a screen.
##
## The same small-window test covers the modal panel: it is content-sized and centred, so
## before this task a tall panel opened on a 640x360 window put its own Close button below the
## bottom edge.

const WHATS_NEW_SCENE := "res://src/ui/screens/whats_new/whats_new_screen.tscn"
const MENU_SCENE := "res://src/ui/screens/main_menu.tscn"
const GAME_SCENE := "res://src/ui/screens/game_screen.tscn"
const SMALL := Vector2(640, 360)


func _mount(scene_path: String, size: Vector2 = Vector2(1280, 720)) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
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


func _unmount(mounted: Dictionary) -> void:
	(mounted["viewport"] as Node).queue_free()


# --- The page tells the truth ---------------------------------------------

func test_every_entry_cites_files_that_exist() -> void:
	var paths := WhatsNewItems.evidence_paths()
	check_gt(float(paths.size()), 0.0, "the table cites at least one file")
	for path: String in paths:
		check_true(FileAccess.file_exists("res://%s" % path),
				"the entry cites %s, which exists" % path)
	# No entry may rest on a single file it shares with every other entry: an entry whose only
	# evidence is a document every other entry also cites is not traceable to anything.
	for release: Dictionary in WhatsNewItems.RELEASES:
		for item: Dictionary in release["items"]:
			var evidence: Array = item["evidence"]
			check_gt(float(evidence.size()), 1.0,
					"%s cites more than one file" % str(item["title_key"]))
			check_false((item["body_key"] as String).is_empty(),
					"%s has a body" % str(item["title_key"]))


func test_every_string_key_resolves() -> void:
	for key: String in WhatsNewItems.string_keys():
		check_true(Strings.TABLE.has(key), "the string table has %s" % key)
		var text := Strings.t(key)
		check_false(text.begins_with("<%"), "the table resolves %s" % key)
		# A note is a sentence, not a stub. Ten characters is a deliberately low bar: it catches
		# a placeholder, not a house style.
		check_gte(float(text.length()), 10.0, "%s is a real sentence" % key)


func test_the_page_prints_the_version_the_project_file_declares() -> void:
	var mounted := await _mount(WHATS_NEW_SCENE)
	var screen: Control = mounted["screen"]
	var version := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	check_eq(screen.call("header_meta"), Strings.t("whats_new.meta", [version]),
			"the page shows the running version, not one typed into a string")
	check_eq(Strings.t("whats_new.meta", [version]).contains(version), true,
			"the version appears in the meta line")
	_unmount(mounted)


func test_every_entry_is_drawn_with_its_citation() -> void:
	var mounted := await _mount(WHATS_NEW_SCENE)
	var screen: Control = mounted["screen"]
	check_eq((screen.call("entry_titles") as PackedStringArray).size(),
			WhatsNewItems.entry_count(), "one card per entry in the table")
	var shown := screen.call("citations") as PackedStringArray
	for path: String in WhatsNewItems.evidence_paths():
		check_true(shown.has(path), "%s is printed on the page" % path)
	# The citations really are visible text, not just a return value: the page's labels contain
	# each one.
	var text := ""
	for node: Node in screen.find_children("*", "Label", true, false):
		text += (node as Label).text + "\n"
	for path: String in WhatsNewItems.evidence_paths():
		check_true(text.contains(path), "%s is readable on screen" % path)
	_unmount(mounted)


# --- The page is reachable -------------------------------------------------

func test_the_main_menu_opens_it_from_the_library_group() -> void:
	var mounted := await _mount(MENU_SCENE)
	var screen: Control = mounted["screen"]
	var opened: Array[String] = []
	screen.navigate_requested.connect(func(screen_id: String) -> void:
		opened.append(screen_id))
	var row := screen.get_node("%WhatsNewEntry") as NavRow
	check_not_null(row, "the Library group has a What is new row")
	check_false(row.disabled, "the row is usable")
	check_eq(row.title_text, "What is new", "the row names the screen it opens")
	row.pressed.emit()
	check_eq(opened, ["whats_new"], "the row asks for the What is new screen")
	_unmount(mounted)


func test_the_pause_menu_opens_it_without_leaving_the_campaign() -> void:
	var store := SaveStore.new("user://test_whats_new_saves")
	var original := Game.store
	Game.store = store
	Game.close()
	var config := CampaignConfig.new()
	config.scenario_id = "modern_world_2026"
	config.country_id = "BGD"
	config.start_date = "2026-01-01"
	Game.start(config)
	var guide_seen := Settings.get_guide_seen()
	Settings.set_guide_seen(true)
	var mounted := await _mount(GAME_SCENE)
	var screen: Control = mounted["screen"]
	var handled: Array[String] = []
	screen.navigate_requested.connect(func(screen_id: String) -> void:
		handled.append(screen_id))
	screen.call("open_pause_menu")
	var pause_menu := screen.find_node("PauseMenu", true, false) as Node
	check_not_null(pause_menu, "the campaign has a pause menu")
	var titles := PackedStringArray()
	for row: Node in pause_menu.find_children("*", "Button", true, false):
		titles.append((row as Button).text)
	check_true(titles.has("What is new"), "the pause menu offers the notes page")
	for row: Node in pause_menu.find_children("*", "Button", true, false):
		if (row as Button).text == "What is new":
			(row as Button).pressed.emit()
	check_eq(handled, ["whats_new"], "the pause menu asks the shell for the notes page")
	_unmount(mounted)
	Game.close()
	Game.store = original
	Settings.set_guide_seen(guide_seen)


# --- The page and the panels survive a small window -----------------------

func test_the_page_fits_a_640x360_window() -> void:
	var mounted := await _mount(WHATS_NEW_SCENE, SMALL)
	var screen: Control = mounted["screen"]
	var scroll := screen.get_node("%Scroll") as ScrollContainer
	var content := screen.get_node("%Content") as VBoxContainer
	check_lte(content.custom_minimum_size.x, scroll.size.x + 1.0,
			"the reading column narrows to the window instead of overflowing it")
	for node: Node in screen.find_children("*", "Label", true, false):
		var label := node as Label
		if not label.is_visible_in_tree():
			continue
		check_lte(label.get_global_rect().end.x, SMALL.x + 1.0,
				"the label %s stays inside the window" % label.text.substr(0, 24))
		var minimum := label.get_minimum_size()
		# A label that can wrap has a narrow minimum; one that cannot would ask for the width of
		# its whole sentence and push the window's layout out.
		check_lte(minimum.x, SMALL.x + 1.0,
				"the label %s can fit the window, so it wraps" % label.text.substr(0, 24))
	_unmount(mounted)


func test_a_modal_panel_stays_on_screen_and_keeps_its_way_out() -> void:
	# The panel is content-sized and centred, which is right on a desktop and wrong on a small
	# window. A body tall enough to fill a 640x360 window stands in for the worst case.
	var host_control := Control.new()
	host_control.theme = ThemeManager.current_theme()
	var panel := ModalPanel.new()
	panel.build("Long panel")
	panel.content().add_child(_tall_body(40))
	host_control.add_child(panel)
	var mounted := await _mount_control(host_control, SMALL)
	panel.open(host_control)
	await tree.process_frame
	await tree.process_frame
	var rect := panel.get_global_rect()
	check_lte(rect.end.y, SMALL.y + 1.0, "the panel does not hang off the bottom edge")
	check_gte(rect.position.y, -1.0, "the panel does not start above the window")
	check_lte(rect.end.x, SMALL.x + 1.0, "the panel does not hang off the right edge")
	var close_button := panel.find_child("Close", true, false) as Button
	check_not_null(close_button, "the panel still has its Close button")
	check_true(close_button.is_visible_in_tree(), "Close is visible")
	check_lte(close_button.get_global_rect().end.y, SMALL.y + 1.0,
			"Close is inside the window, not below the fold")
	check_gte(close_button.size.y, 32.0, "Close is still a tappable size")
	panel.close()
	ModalPanel.clear_stack()
	_unmount(mounted)


func _mount_control(control: Control, size: Vector2) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await tree.process_frame
	await tree.process_frame
	return {"viewport": viewport, "holder": holder}


## A body of `lines` wrapped labels: tall, and nothing the panel can shrink without scrolling.
func _tall_body(lines: int) -> VBoxContainer:
	var body := VBoxContainer.new()
	for index in range(lines):
		var label := Label.new()
		label.text = "Line %d — a sentence long enough to take up a row of the panel." % index
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(label)
	return body
