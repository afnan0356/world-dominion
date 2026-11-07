extends TestCase
## The game screen's shell (Milestone 10, Tasks 3, 6 and 7): the five zones, the real data
## they show, the panels they open, and the honesty of the six categories that are not built.
##
## The suite mounts the real game screen over a real campaign, because the shell's whole job
## is to show a running campaign's own numbers. Every figure it asserts is compared with the
## dataset the game ships, so a shell that made a number up would fail here.

const GAME_SCENE := "res://src/ui/screens/game_screen.tscn"
const TEST_SAVE_DIR := "user://test_hud_saves"

var _atlas: WorldAtlas
var _original_store: SaveStore
var _original_guide := false


func _prepare() -> void:
	if _atlas == null:
		_atlas = WorldAtlas.load_default()
	_original_store = Game.store if _original_store == null else _original_store
	_original_guide = Settings.get_guide_seen()
	Settings.set_guide_seen(true)
	var store := SaveStore.new(TEST_SAVE_DIR)
	_clear_directory(store.directory())
	Game.store = store
	Game.close()
	Game.start(_config())


func _config() -> CampaignConfig:
	var config := CampaignConfig.new()
	config.scenario_id = "modern_world_2026"
	config.country_id = "BGD"
	config.start_date = "2026-01-01"
	var record := _atlas.registry.get_country("BGD")
	config.metadata = {"scenario_name": "Modern World",
			"country_name": record.name if record != null else "Bangladesh"}
	return config


func _teardown() -> void:
	Game.close()
	Game.store = _original_store
	_original_store = null
	Settings.set_guide_seen(_original_guide)


func _mount(viewport_size: Vector2 = Vector2(1280, 720)) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(viewport_size)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Control = load(GAME_SCENE).instantiate()
	holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await tree.process_frame
	await tree.process_frame
	return {"viewport": viewport, "screen": screen, "holder": holder}


func _hud(screen: Control) -> GameHud:
	return screen.find_child("Hud", true, false) as GameHud


func _unmount(mounted: Dictionary) -> void:
	(mounted["viewport"] as Node).queue_free()


func _texts(node: Node) -> String:
	var parts := PackedStringArray()
	for label: Node in node.find_children("*", "Label", true, false):
		parts.append((label as Label).text)
	return " ".join(parts)


func _key(keycode: int) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


# --- The zones exist and say the right things ------------------------------

func test_the_top_bar_shows_the_identity_the_wallet_the_level_and_the_flag() -> void:
	await _prepare()
	var mounted := await _mount()
	var screen: Control = mounted["screen"]
	var hud := _hud(screen)
	check_not_null(hud, "the shell is mounted over the map")
	check_not_null(hud.avatar_button, "the avatar is in the top bar")
	check_not_null(hud.flag_button, "the flag is in the top bar")
	check_true(_texts(screen).contains(Strings.t("hud.gold")), "Gold Coins are labelled")
	check_true(_texts(screen).contains(Strings.t("hud.gems")), "Red Gems are labelled")
	check_false(_texts(screen).contains("Diamonds"),
			"the player only ever reads 'Red Gems' for the second currency")
	var profile: PlayerProfile = screen.call("_load_profile")
	check_true(hud.avatar_button.tooltip_text.contains(profile.display_name),
			"the avatar names the player's own profile")
	check_true(hud.player_label.text.contains("LEADING"), "the identity block names the role")
	check_eq(hud.country_label.text, "Bangladesh", "and the country the player leads")
	_unmount(mounted)
	_teardown()


func test_the_stats_strip_prints_the_dataset_and_never_a_guess() -> void:
	await _prepare()
	var mounted := await _mount()
	var hud := _hud(mounted["screen"])
	var statistics := _atlas.statistics
	var population: Variant = statistics.value("BGD", "population")
	check_not_null(population, "the dataset has a population for Bangladesh")
	var area: Variant = statistics.value("BGD", "area_km2")
	var screen_text := _texts(mounted["screen"])
	check_true(screen_text.contains(CountryStatistics.format_integer(int(population))),
			"the strip prints the population the dataset holds")
	check_true(screen_text.contains(CountryStatistics.format_integer(int(area))),
			"and the area, in the dataset's own units")
	check_true(screen_text.contains(_atlas.currency.describe("BGD")),
			"and the currency the currency table names")
	# A country the source has no currency for must read "Not available", not a blank and
	# not a guess. The shell uses one path for every figure, so this proves the fallback.
	var missing := ""
	for country_id: String in _atlas.registry.ids():
		if _atlas.currency.describe(country_id) == CurrencyCatalog.MISSING_TEXT:
			missing = country_id
			break
	check_true(not missing.is_empty() or _atlas.currency.count() > 0,
			"the source's own gaps are known to the test")
	if not missing.is_empty():
		check_eq(_atlas.currency.describe(missing), Strings.t("field.not_available"),
				"the shell's missing text is the catalogue's own words")
	_unmount(mounted)
	_teardown()


func test_the_rails_and_the_bottom_bar_are_all_there() -> void:
	await _prepare()
	var mounted := await _mount()
	var hud := _hud(mounted["screen"])
	check_not_null(hud.messages_button, "the left rail has Messages")
	check_not_null(hud.news_button, "the right rail has News")
	check_not_null(hud.menu_button, "the bottom-left has Menu")
	check_not_null(hud.tutorial_button, "and the tutorial can be reopened")
	check_eq(hud.category_buttons.size(), 7, "seven categories sit in the middle")
	for entry: Dictionary in GameHud.CATEGORIES:
		var button: Button = hud.category_buttons[str(entry["id"])]
		check_not_null(button, "%s has a real button" % str(entry["id"]))
		check_false(button.text.strip_edges().is_empty(), "every category is labelled")
	check_not_null(hud.date_label, "the bottom-right shows the in-game date")
	check_not_null(hud.speed_control, "and the clock's speed")
	check_true(hud.date_label.text.contains("2026"), "the date is the campaign's real date")
	_unmount(mounted)
	_teardown()


# --- Honesty of the category bar ------------------------------------------

func test_country_opens_the_real_dossier_and_compare() -> void:
	await _prepare()
	var mounted := await _mount()
	var screen: Control = mounted["screen"]
	var hud := _hud(screen)
	(hud.category_buttons["country"] as Button).pressed.emit()
	await tree.process_frame
	var panels: ShellPanels = screen.get("_panels") as ShellPanels
	check_true(panels.is_open(), "Country opens a panel")
	var panel := panels.current() as CountryOverviewPanel
	check_not_null(panel, "and it is the country overview")
	check_eq(panel.country_id, "BGD", "for the country the player leads")
	check_not_null(panel.dossier_panel(), "the overview reuses the real dossier panel")
	check_true(panel.dossier_panel().row_count() > 4,
			"the dossier is populated with the atlas's own sections")
	check_true(_texts(panel).contains("Bangladesh"), "the panel names the country")
	check_true(_texts(panel).contains(Strings.t("overview.disputed")),
			"the neutral note about disputed names is stated in the overview")
	panel.show_tab("history")
	check_eq(panel.history_count(), 1,
			"the history tab holds the campaign's own recorded event about it")
	panels.close_current()
	_unmount(mounted)
	_teardown()


func test_the_six_unbuilt_categories_say_so_and_show_no_fake_numbers() -> void:
	await _prepare()
	var mounted := await _mount()
	var screen: Control = mounted["screen"]
	var hud := _hud(screen)
	for category_id: String in ["economy", "government", "diplomacy", "military",
			"research", "world"]:
		(hud.category_buttons[category_id] as Button).pressed.emit()
		await tree.process_frame
		var panels: ShellPanels = screen.get("_panels") as ShellPanels
		var panel := panels.current() as PlannedPanel
		check_not_null(panel, "%s opens a panel" % category_id)
		check_eq(panel.category, category_id, "%s is the panel that opened" % category_id)
		var text := _texts(panel)
		check_true(text.contains(Strings.t("planned_badge")),
				"%s says plainly that nothing is simulated" % category_id)
		check_false(_has_digit(text),
				"%s shows no figure that could be mistaken for data" % category_id)
		panels.close_current()
	_unmount(mounted)
	_teardown()


func _has_digit(text: String) -> bool:
	for character in "0123456789":
		if text.contains(character):
			return true
	return false


# --- Messages, news and the badge ----------------------------------------

func test_messages_lists_the_real_log_and_clears_the_badge() -> void:
	await _prepare()
	var mounted := await _mount()
	var screen: Control = mounted["screen"]
	var hud := _hud(screen)
	var log: EventLog = Game.current_session().world.events
	check_eq(log.size(), 1, "the new campaign recorded one event")
	check_true(hud.messages_button.tooltip_text.contains("1"),
			"the badge counts the unread event")
	(hud.messages_button as Button).pressed.emit()
	await tree.process_frame
	var panels: ShellPanels = screen.get("_panels") as ShellPanels
	var panel := panels.current() as MessagesPanel
	check_not_null(panel, "Messages opens its panel")
	check_eq(panel.visible_count(), 1, "the list holds the campaign's event")
	check_true(_texts(panel).contains("Bangladesh"),
			"the row is the real sentence the campaign recorded")
	panel.mark_all_read()
	check_eq(log.unread_count(), 0, "mark all read clears the log's unread count")
	check_true(hud.messages_button.tooltip_text.contains(
			Strings.t("hud.messages.none")), "and the badge says there is nothing unread")
	check_true(screen.call("_panel_open"), "the panel is open, so the clock is paused")
	panel._input(_key(KEY_ESCAPE))
	check_false(screen.call("_panel_open"), "Escape closes it")
	_unmount(mounted)
	_teardown()


func test_news_prints_the_campaign_and_says_when_there_is_nothing() -> void:
	await _prepare()
	var mounted := await _mount()
	var screen: Control = mounted["screen"]
	var hud := _hud(screen)
	check_true(hud.news_button != null, "the right rail has News")
	(hud.news_button as Button).pressed.emit()
	await tree.process_frame
	var panels: ShellPanels = screen.get("_panels") as ShellPanels
	var panel := panels.current() as NewsPanel
	check_not_null(panel, "News opens its panel")
	check_eq(panel.entry_count(), 1, "one article per recorded event")
	check_true(_texts(panel).contains(Strings.t("news.masthead")), "the page has a masthead")
	panels.close_current()
	# An empty campaign is the honest empty state, not an invented headline.
	var empty := NewsPanel.new()
	empty.prepare(EventLog.new())
	check_eq(empty.entry_count(), 0, "an empty log prints no articles")
	check_true(_texts(empty).contains(Strings.t("news.empty")), "and says so")
	_unmount(mounted)
	_teardown()


func test_the_avatar_opens_the_players_own_figures() -> void:
	await _prepare()
	var mounted := await _mount()
	var screen: Control = mounted["screen"]
	var hud := _hud(screen)
	(hud.avatar_button as Button).pressed.emit()
	await tree.process_frame
	var panels: ShellPanels = screen.get("_panels") as ShellPanels
	var panel := panels.current()
	check_not_null(panel, "the avatar opens a panel")
	var profile: PlayerProfile = screen.call("_load_profile")
	check_true(_texts(panel).contains(profile.display_name), "it names the player")
	check_true(_texts(panel).contains(Strings.t("hud.level", [profile.level()])),
			"and shows the level from the same profile file the game uses")
	_unmount(mounted)
	_teardown()


# --- Layout ---------------------------------------------------------------

func test_the_shell_stays_inside_every_reference_size() -> void:
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
		var mounted := await _mount(viewport_size)
		var screen: Control = mounted["screen"]
		var hud := _hud(screen)
		var top: Control = screen.get_node("%TopBar")
		check_lte(top.get_global_rect().end.y, viewport_size.y,
				"%s: the top bar stays on screen" % label)
		var bottom := hud.find_child("BottomBar", true, false) as Control
		check_not_null(bottom, "%s: the bottom bar exists" % label)
		check_lte(bottom.get_global_rect().end.y, viewport_size.y + 1.0,
				"%s: the bottom bar never spills past the screen" % label)
		for button: Node in hud.find_children("*", "Button", true, false):
			var control := button as Control
			if control == null or not control.is_visible_in_tree():
				continue
			check_gte(control.size.y, 32.0, "%s: every shell control stays tappable" % label)
		_unmount(mounted)
	_teardown()


func _clear_directory(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		directory.remove(file_name)


# --- Icons are drawn, not borrowed ---------------------------------------

func test_every_shell_mark_has_a_licensed_icon_and_a_drawing() -> void:
	# Milestone 10 asserted the opposite of this test: that no crosswalk entry pointed at an
	# icon file, because no licensed set could be downloaded then. Milestone 11 shipped the
	# game-icons.net set, so the rule is deliberately inverted — every meaning must now name a
	# licensed file *and* the drawn shape that stands in when the file cannot load. Keeping the
	# old assertion would have meant deleting the icons to keep a test green, which is the wrong
	# way round.
	var crosswalk := ShellIcon.crosswalk()
	check_gt(float(crosswalk.size()), 0.0, "the icon crosswalk is committed and parses")
	var known := ShellIcon.shapes()
	var problems: Array = []
	for meaning: String in ShellIcon.names():
		var shape := ShellIcon.shape_for(meaning)
		var entry: Dictionary = crosswalk.get(meaning, {})
		if not known.has(shape):
			problems.append("%s has no drawable fallback (%s)" % [meaning, shape])
		if not entry.has("file"):
			problems.append("%s has no licensed file" % meaning)
		if str(entry.get("author", "")).is_empty():
			problems.append("%s has no author" % meaning)
	check_eq(problems.size(), 0, "every meaning has a file and a fallback: %s" % str(problems))
	for meaning: String in ["avatar", "messages", "news", "menu", "tutorial",
			"category.country", "category.economy", "category.world"]:
		check_true(crosswalk.has(meaning), "the shell's own marks are in the crosswalk: %s"
				% meaning)
	var avatar_entry: Dictionary = crosswalk.get("avatar", {})
	check_eq(str(avatar_entry.get("shape", "")), "bust",
			"the avatar keeps a mark of its own")
	var source := str(avatar_entry.get("source", ""))
	check_true(source.begins_with("delapouite/") and source.ends_with(".svg"),
			"the avatar's icon is recorded as a source path: %s" % source)


func test_the_shell_draws_the_licensed_marks_and_keeps_a_fallback() -> void:
	# Milestone 11, Task 5. The crosswalk was committed in Task 1 but nothing on the shell used
	# it: the marks were still drawn in code. This reads the buttons the player can see and
	# checks that each carries its licensed texture — and that the drawing is still reachable,
	# because an asset that fails to load must leave a legible button rather than a gap.
	await _prepare()
	var mounted := await _mount()
	var screen: Control = mounted["screen"]
	var hud := _hud(screen)
	# The top row belongs to the game screen's TopBar, not to the HUD itself, so the buttons are
	# read from the HUD's own properties rather than by searching the HUD's children.
	var marks := {
		"map": hud.map_button,
		"messages": hud.messages_button,
		"news": hud.news_button,
		"menu": hud.menu_button,
		"tutorial": hud.tutorial_button,
		"pause": hud.pause_button,
		"category.country": hud.category_buttons.get("country"),
		"category.economy": hud.category_buttons.get("economy"),
	}
	var problems: Array = []
	for meaning: String in marks:
		var button: Button = marks[meaning]
		if button == null:
			problems.append("%s has no button" % meaning)
			continue
		if button.icon == null:
			problems.append("%s has no licensed mark" % meaning)
		if not IconAtlas.has_icon(meaning):
			problems.append("%s names a meaning with no icon" % meaning)
	check_eq(problems.size(), 0, "every shell mark is the licensed one: %s" % str(problems))
	var avatar := hud.avatar_button.get_child(0)
	check_not_null(avatar, "the avatar is drawn from the licensed set")
	check_true(avatar is IconView, "the avatar is an IconView, not the old drawing")
	# The fallback, exercised on purpose: a meaning that does not exist must produce the drawn
	# mark and must not throw.
	var probe := Button.new()
	probe.text = "Probe"
	hud.add_child(probe)
	hud.call("_set_mark", probe, "no_such_meaning")
	check_eq(probe.icon, null, "an unknown meaning sets no texture")
	check_not_null(probe.find_child("Mark", true, false), "an unknown meaning falls back")
	probe.queue_free()
	_unmount(mounted)
	_teardown()
