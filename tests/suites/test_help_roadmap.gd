extends TestCase
## Help and Roadmap (Milestone 09, Task 5).
##
## Two guards are the point of this suite:
##
## 1. **Help cannot describe something unreachable.** Every section declares the screen ids and
##    files that make its sentence true; this suite resolves the ids against the application's own
##    screen table (`src/app/main.gd`) and checks every file exists. Only two sections are allowed
##    to be prose (scope, not features), and that list is asserted, not assumed.
## 2. **A roadmap item cannot outlive its source.** Every item names a document and a sentence
##    that must still be in it, and an item that claimed IMPLEMENTED would have to name files that
##    exist. Nothing is implemented today, so every status is a future one — and the suite checks
##    the allowed statuses rather than trusting the screen.

const HELP_SCENE := "res://src/ui/screens/help/help_screen.tscn"
const ROADMAP_SCENE := "res://src/ui/screens/roadmap/roadmap_screen.tscn"
const MAIN := "res://src/app/main.gd"
const PROSE_ONLY := ["help.status_title", "help.account_title"]


func _mount(scene_path: String, size: Vector2 = Vector2(1280, 800)) -> Dictionary:
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
	return {"viewport": viewport, "screen": screen}


func _screen_table() -> String:
	return FileAccess.get_file_as_string(MAIN)


func _is_registered(screen_id: String) -> bool:
	return _screen_table().contains("\"%s\": preload(" % screen_id)


# --- Help ------------------------------------------------------------------

func test_help_has_its_sections_in_order() -> void:
	var mounted := await _mount(HELP_SCENE)
	var screen: Control = mounted["screen"]
	var titles: PackedStringArray = screen.call("section_titles")
	check_eq(titles.size(), 6, "Help covers six questions")
	var expected := PackedStringArray([
		Strings.t("help.status_title"), Strings.t("help.can_do_title"),
		Strings.t("help.saving_title"), Strings.t("help.account_title"),
		Strings.t("help.notifications_title"), Strings.t("help.report_title"),
	])
	check_eq(titles, expected, "in the order the milestone lists them")
	(mounted["viewport"] as Node).queue_free()


func test_every_help_claim_is_reachable() -> void:
	var problems := PackedStringArray()
	for section: Dictionary in HelpSections.SECTIONS:
		var title := str(section["title_key"])
		var screens: Array = section["screens"]
		var files: Array = section["files"]
		if not bool(section["prose_only"]):
			if screens.is_empty() and files.is_empty():
				problems.append("%s: claims a feature but names no evidence" % title)
			if PROSE_ONLY.has(title):
				problems.append("%s: prose-only but marked as a feature" % title)
		for screen_id: String in screens:
			if not _is_registered(screen_id):
				problems.append("%s: points at a screen that is not in the shell: %s"
						% [title, screen_id])
		for path: String in files:
			if not FileAccess.file_exists(path):
				problems.append("%s: names a file that does not exist: %s" % [title, path])
	check_eq(problems, PackedStringArray(),
			"every Help sentence points at something that exists")
	# The prose exceptions are exactly two, and both explain scope rather than a feature.
	var prose := 0
	for section: Dictionary in HelpSections.SECTIONS:
		if bool(section["prose_only"]):
			prose += 1
			check_true(PROSE_ONLY.has(str(section["title_key"])),
					"%s is allowed to be prose" % str(section["title_key"]))
	check_eq(prose, PROSE_ONLY.size(), "only the two scope sections are prose")


func test_help_links_open_the_screens_they_name() -> void:
	var mounted := await _mount(HELP_SCENE)
	var screen: Control = mounted["screen"]
	var opened: Array[String] = []
	screen.navigation_requested.connect(func(screen_id: String, _params: Dictionary) -> void:
		opened.append(screen_id))
	var ids: PackedStringArray = screen.call("linked_screens")
	check_gt(float(ids.size()), 0.0, "Help links to real screens")
	for screen_id: String in ids:
		var button := screen.find_child("Open_%s" % screen_id, true, false) as Button
		check_not_null(button, "there is a button for %s" % screen_id)
		if button != null:
			check_gte(button.size.y, DesignTokens.CONTROL_HEIGHT_COMPACT,
					"the %s button is tappable" % screen_id)
			button.pressed.emit()
	for screen_id: String in ids:
		check_true(opened.has(screen_id), "pressing the %s button navigates" % screen_id)
	(mounted["viewport"] as Node).queue_free()


func test_help_never_shows_a_missing_string_key() -> void:
	var mounted := await _mount(HELP_SCENE)
	var screen: Control = mounted["screen"]
	for node: Node in screen.find_children("*", "Label", true, false):
		var text := (node as Label).text
		check_false(text.contains("<help."), "no label shows a missing key: %s" % text)
		check_false(text.is_empty(), "no label is empty")
	(mounted["viewport"] as Node).queue_free()


# --- Roadmap ---------------------------------------------------------------

func test_every_roadmap_item_cites_a_source_that_still_says_it() -> void:
	var problems := PackedStringArray()
	for item: Dictionary in RoadmapItems.ITEMS:
		var title := str(item["title_key"])
		var source := str(item["source_file"])
		var quote := str(item["source_quote"])
		if not FileAccess.file_exists(source):
			problems.append("%s: source document is missing: %s" % [title, source])
			continue
		var text := FileAccess.get_file_as_string(source)
		if not text.contains(quote):
			problems.append("%s: '%s' is no longer in %s" % [title, quote, source])
		var status := str(item["status"])
		if not RoadmapItems.statuses().has(status):
			problems.append("%s: unknown status '%s'" % [title, status])
		var evidence: Array = item["evidence"]
		if status == RoadmapItems.STATUS_IMPLEMENTED:
			if evidence.is_empty():
				problems.append("%s: claims IMPLEMENTED with no evidence" % title)
			for path: String in evidence:
				if not FileAccess.file_exists(path):
					problems.append("%s: evidence file is missing: %s" % [title, path])
		elif not evidence.is_empty():
			problems.append("%s: claims '%s' but lists implemented evidence" % [title, status])
	check_eq(problems, PackedStringArray(),
			"every roadmap item is traceable and no item claims more than it can prove")


func test_nothing_on_the_roadmap_claims_to_be_built() -> void:
	for item: Dictionary in RoadmapItems.ITEMS:
		check_true(str(item["status"]) in [RoadmapItems.STATUS_PLANNED,
				RoadmapItems.STATUS_NOT_PLANNED, RoadmapItems.STATUS_OPEN],
				"%s is future work, not a claim" % str(item["title_key"]))
	var mounted := await _mount(ROADMAP_SCENE)
	var statuses: PackedStringArray = mounted["screen"].call("status_labels")
	check_eq(statuses.size(), RoadmapItems.ITEMS.size(), "every item shows a status")
	for status: String in statuses:
		check_false(status == RoadmapItems.STATUS_IMPLEMENTED,
				"no roadmap card claims to be implemented")
	(mounted["viewport"] as Node).queue_free()


func test_the_roadmap_is_calm_and_has_no_motion() -> void:
	var before := tree.get_processed_tweens().size()
	var mounted := await _mount(ROADMAP_SCENE)
	await tree.process_frame
	var screen: Control = mounted["screen"]
	check_eq(tree.get_processed_tweens().size(), before,
			"opening the roadmap starts no tween")
	check_eq(screen.find_children("*", "AnimationPlayer", true, false).size(), 0,
			"and there is no AnimationPlayer to ignore the reduced-motion setting")
	check_eq(screen.find_children("*", "Tween", true, false).size(), 0,
			"and no Tween node is added to the page")
	# Reduced motion changes nothing here, because nothing moves: the same titles, in the
	# same order, either way.
	var original := Settings.get_motion_mode()
	var titles_normal: PackedStringArray = screen.call("item_titles")
	Settings.set_motion_mode(Settings.MOTION_REDUCED)
	await tree.process_frame
	var titles_reduced: PackedStringArray = screen.call("item_titles")
	check_eq(titles_reduced, titles_normal, "reduced motion leaves the page identical")
	Settings.set_motion_mode(original)
	(mounted["viewport"] as Node).queue_free()


func test_the_roadmap_lists_the_items_the_milestone_names() -> void:
	var keys: Array[String] = []
	for item: Dictionary in RoadmapItems.ITEMS:
		keys.append(str(item["title_key"]))
	for key: String in ["roadmap.multiplayer", "roadmap.notifications", "roadmap.mods",
			"roadmap.achievements", "roadmap.religion", "roadmap.economy",
			"roadmap.diplomacy", "roadmap.un"]:
		check_true(keys.has(key), "%s is on the roadmap" % key)
	check_eq(keys.size(), 8, "and nothing else is invented")
	# The two items the vision document contradicts are labelled with what it actually says.
	for item: Dictionary in RoadmapItems.ITEMS:
		if str(item["title_key"]) == "roadmap.multiplayer":
			check_eq(str(item["status"]), RoadmapItems.STATUS_NOT_PLANNED,
					"online multiplayer is not planned, and the vision says so")
		if str(item["title_key"]) == "roadmap.religion":
			check_eq(str(item["status"]), RoadmapItems.STATUS_OPEN,
					"religion is an open question, not a plan")


func test_both_screens_fit_every_size_in_both_themes() -> void:
	var original := Settings.get_theme_id()
	var problems := PackedStringArray()
	for theme_id: String in ["midnight", "parchment"]:
		Settings.set_theme_id(theme_id)
		await tree.process_frame
		for scene_path: String in [HELP_SCENE, ROADMAP_SCENE]:
			for size: Vector2 in [Vector2(640, 360), Vector2(844, 390), Vector2(1280, 720),
					Vector2(1920, 1080), Vector2(390, 844)]:
				var mounted := await _mount(scene_path, size)
				var screen: Control = mounted["screen"]
				if screen.size != size:
					problems.append("%s %s @ %s: screen is %s" % [scene_path.get_file(),
							theme_id, str(size), str(screen.size)])
				for node: Node in screen.find_children("*", "BaseButton", true, false):
					var button := node as BaseButton
					if not button.visible or button.custom_minimum_size.y <= 0.0:
						continue
					if button.size.y + 0.5 < DesignTokens.CONTROL_HEIGHT_COMPACT:
						problems.append("%s %s @ %s: '%s' is %.0f px high"
								% [scene_path.get_file(), theme_id, str(size), button.name,
								button.size.y])
				(mounted["viewport"] as Node).queue_free()
	Settings.set_theme_id(original)
	check_eq(problems, PackedStringArray(), "both screens fit every size in both themes")
