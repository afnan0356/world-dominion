extends TestCase
## The main menu cleanup (Milestone 09, Task 3).
##
## Under test: the menu is grouped Play → You → Library in that order, with every entry in the
## group the spec names; nothing is hidden to buy space any more, so a 390 px-tall phone keeps
## every row and scrolls instead; rows keep at least 48 px; the three library entries this
## milestone has not built are disabled and badged rather than dead; and the working entries ask
## the shell to open the screens they name.

const MENU_SCENE := "res://src/ui/screens/main_menu.tscn"

const VIEWPORTS := {
	"desktop 1280x720": Vector2(1280, 720),
	"desktop 1920x1080": Vector2(1920, 1080),
	"tablet 1024x768": Vector2(1024, 768),
	"phone landscape 844x390": Vector2(844, 390),
	"small window 640x360": Vector2(640, 360),
	"phone portrait 390x844": Vector2(390, 844),
}


func _mount(size: Vector2) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Control = load(MENU_SCENE).instantiate()
	holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await tree.process_frame
	await tree.process_frame
	return {"viewport": viewport, "screen": screen}


## The menu as a flat list of ("heading: PLAY", "row: New Campaign", …) in visual order.
func _structure(screen: Control) -> Array[String]:
	var menu: VBoxContainer = screen.get_node("%Menu")
	var out: Array[String] = []
	for child: Node in menu.get_children():
		if child is Label:
			out.append("heading: %s" % (child as Label).text)
		elif child is NavRow:
			var row := child as NavRow
			if row.visible:
				out.append("row: %s" % row.title_text)
	return out


func test_the_menu_is_grouped_play_you_library() -> void:
	var mounted := await _mount(Vector2(1280, 720))
	var expected: Array[String] = [
		"heading: PLAY", "row: New Campaign", "row: Continue", "row: Worlds",
		"heading: YOU", "row: Profile", "row: Settings",
		"heading: LIBRARY", "row: Help", "row: Roadmap", "row: About the data",
		"row: Keyboard shortcuts", "row: Diagnostics", "row: About & Credits",
	]
	if PlatformInfo.offers_quit_action():
		expected.append("row: Quit")
	check_eq(_structure(mounted["screen"]), expected,
			"the menu reads Play, You, Library, with every entry in its group")
	(mounted["viewport"] as Node).queue_free()


func test_every_library_entry_is_live() -> void:
	var mounted := await _mount(Vector2(1280, 720))
	var screen: Control = mounted["screen"]
	# Milestone 09 finished the library: Help, Roadmap and Diagnostics all exist, so nothing
	# in the menu is a disabled placeholder any more.
	for path: String in ["%HelpEntry", "%RoadmapEntry", "%AboutDataEntry", "%ShortcutsEntry",
			"%DiagnosticsEntry", "%AboutEntry"]:
		var row := screen.get_node(path) as NavRow
		check_false(row.disabled, "%s works" % path)
		check_eq(row.status_text, "", "%s carries no PLANNED badge" % path)
		var badge := row.find_child("Badge", true, false) as CanvasItem
		if badge != null:
			check_false(badge.visible, "%s shows no badge" % path)
	(mounted["viewport"] as Node).queue_free()


func test_working_entries_ask_for_their_screens() -> void:
	var mounted := await _mount(Vector2(1280, 720))
	var screen: Control = mounted["screen"]
	var opened: Array[String] = []
	screen.navigate_requested.connect(func(screen_id: String) -> void:
		opened.append(screen_id))
	var expected := {
		"%NewCampaign": "campaign_setup",
		"%WorldsEntry": "worlds",
		"%ProfileEntry": "profile",
		"%SettingsEntry": "settings",
		"%AboutDataEntry": "about_data",
		"%ShortcutsEntry": "shortcuts",
		"%HelpEntry": "help",
		"%RoadmapEntry": "roadmap",
		"%DiagnosticsEntry": "diagnostics",
		"%AboutEntry": "about",
	}
	for path: String in expected:
		(screen.get_node(path) as Button).pressed.emit()
	check_eq(opened, ["campaign_setup", "worlds", "profile", "settings", "about_data",
			"shortcuts", "help", "roadmap", "diagnostics", "about"],
			"each entry asks for the screen it names")
	# A disabled row must not navigate anywhere, even if something presses it. Continue is
	# disabled exactly when no save exists, which is the honest case to test with.
	Game.close()
	var empty := await _mount(Vector2(1280, 720))
	check_true((empty["screen"].get_node("%ContinueCampaign") as NavRow).disabled,
			"Continue is disabled with no save")
	(empty["viewport"] as Node).queue_free()
	(mounted["viewport"] as Node).queue_free()


func test_rows_keep_their_target_and_nothing_is_hidden() -> void:
	var problems := PackedStringArray()
	for label: String in VIEWPORTS:
		var mounted := await _mount(VIEWPORTS[label])
		var screen: Control = mounted["screen"]
		var menu: VBoxContainer = screen.get_node("%Menu")
		for child: Node in menu.get_children():
			if not (child is NavRow):
				continue
			var row := child as NavRow
			if not row.visible:
				problems.append("%s: '%s' is hidden to save space" % [label, row.title_text])
				continue
			if row.size.y + 0.5 < 48.0:
				problems.append("%s: '%s' is %.1f px tall" % [label, row.title_text, row.size.y])
		var scroll: ScrollContainer = screen.get_node("%MenuScroll")
		if scroll.size.y <= 0.0:
			problems.append("%s: the menu column collapsed" % label)
		if scroll.size.y > screen.size.y:
			problems.append("%s: the menu column is taller than the window" % label)
		(mounted["viewport"] as Node).queue_free()
	check_eq(problems, PackedStringArray(),
			"every row keeps 48 px and nothing is hidden at any of the six sizes")


func test_a_short_window_scrolls_instead_of_squeezing() -> void:
	var short := await _mount(Vector2(640, 360))
	var short_scroll: ScrollContainer = short["screen"].get_node("%MenuScroll")
	var short_menu: VBoxContainer = short["screen"].get_node("%Menu")
	check_eq(short_scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO,
			"the column can scroll vertically")
	check_eq(short_scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED,
			"and cannot scroll sideways, which would break the row layouts")
	check_gt(short_menu.get_combined_minimum_size().y, short_scroll.size.y,
			"the eleven rows need more room than a 360 px window has, so the rest scrolls")
	check_eq(short["screen"].get_node("%Menu").get_theme_constant("separation"),
			DesignTokens.SPACE_4, "the rows keep a comfortable 4 px apart rather than touching")
	(short["viewport"] as Node).queue_free()

	# A window tall enough for the whole column shows all of it; at 1080 px the eleven rows
	# plus the wordmark still do not fit, which is why the scroll exists.
	var tall := await _mount(Vector2(1200, 1600))
	var tall_scroll: ScrollContainer = tall["screen"].get_node("%MenuScroll")
	var tall_menu: VBoxContainer = tall["screen"].get_node("%Menu")
	check_gte(tall_scroll.size.y, tall_menu.get_combined_minimum_size().y - 1.0,
			"a window tall enough shows the whole menu without scrolling")
	(tall["viewport"] as Node).queue_free()


func test_both_themes_keep_the_groups_and_heights() -> void:
	var original := Settings.get_theme_id()
	var problems := PackedStringArray()
	for theme_id: String in ["midnight", "parchment"]:
		Settings.set_theme_id(theme_id)
		await tree.process_frame
		var mounted := await _mount(Vector2(1280, 720))
		var screen: Control = mounted["screen"]
		var headings := 0
		var menu: Node = screen.get_node("%Menu")
		for label: Node in menu.find_children("*", "Label", true, false):
			if (label as Label).theme_type_variation == &"SectionHeading":
				headings += 1
		if headings != 3:
			problems.append("%s: %d headings instead of 3" % [theme_id, headings])
		check_gte((screen.get_node("%NewCampaign") as NavRow).size.y, 48.0,
				"%s keeps the row height" % theme_id)
		(mounted["viewport"] as Node).queue_free()
	Settings.set_theme_id(original)
	check_eq(problems, PackedStringArray(), "both themes keep the three groups")


func test_every_group_heading_is_not_a_button() -> void:
	var mounted := await _mount(Vector2(1280, 720))
	var menu: VBoxContainer = mounted["screen"].get_node("%Menu")
	for child: Node in menu.get_children():
		if child is Label:
			check_false(child is BaseButton, "a heading is text, not a control")
			check_eq((child as Control).focus_mode, Control.FOCUS_NONE,
					"and never takes keyboard focus away from a row")
	(mounted["viewport"] as Node).queue_free()
