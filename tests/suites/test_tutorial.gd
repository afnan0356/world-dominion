extends TestCase
## The tutorial (Milestone 08, Task 5).
##
## The rules under test: every step teaches something the build actually has, in words that
## admit what it does not have; finishing pays the one-time reward exactly once per profile,
## through the profile's own rule; skipping pays nothing; and the whole thing can be opened
## again from the pause menu, at every reference size, in both themes.

const GAME_SCENE := "res://src/ui/screens/game_screen.tscn"
const TEST_SAVE_DIR := "user://test_tutorial_saves"
const TEST_PROFILE := "user://test_tutorial_profile.json"
const SIZES := {
	"640x360": Vector2(640, 360),
	"1280x720": Vector2(1280, 720),
	"1920x1080": Vector2(1920, 1080),
	"390x844": Vector2(390, 844),
}

var _atlas: WorldAtlas
var _original_store: SaveStore
var _original_guide := false


# --- Mounting a real campaign ---------------------------------------------

func _prepare() -> Dictionary:
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


func _mount(size: Vector2 = Vector2(1280, 720), profile: PlayerProfile = null) -> Dictionary:
	_clean_profile()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Control = load(GAME_SCENE).instantiate()
	holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The screen writes the tutorial reward to the profile; a test uses its own file.
	screen.set("profile_store", ProfileStore.new(TEST_PROFILE))
	if profile != null:
		screen.set("profile", profile)
	for _frame in 4:
		await tree.process_frame
	return {"viewport": viewport, "screen": screen}


func _teardown() -> void:
	Game.close()
	Game.store = _original_store
	_original_store = null
	Settings.set_guide_seen(_original_guide)
	_clean_profile()


func _clean_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)


func _clean_profile() -> void:
	for path: String in [TEST_PROFILE, TEST_PROFILE.get_basename() + ".old.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fresh_profile() -> PlayerProfile:
	var profile := PlayerProfile.create(20260101, "2026-11-07")
	profile.display_name = "Learner"
	profile.username = "learner"
	profile.username_locked = true
	return profile


func _panel(screen: Control) -> TutorialPanel:
	return screen.find_child("Tutorial", true, false) as TutorialPanel


# --- What the tutorial teaches -------------------------------------------

func test_every_step_teaches_a_feature_that_exists() -> void:
	check_gte(float(TutorialSteps.count()), 6.0, "the tutorial has the six documented steps")
	check_eq(TutorialSteps.unknown_features().size(), 0,
			"every step names a feature the feature table backs: %s"
			% str(TutorialSteps.unknown_features()))
	var seen := {}
	var duplicates: Array = []
	for index in TutorialSteps.count():
		var entry := TutorialSteps.step(index)
		var feature_id := str(entry.get("feature", ""))
		var anchor := TutorialSteps.anchor_of(feature_id)
		if anchor.is_empty():
			duplicates.append("step %d has no anchor" % index)
		if seen.has(feature_id):
			duplicates.append("%s is taught twice" % feature_id)
		seen[feature_id] = true
	check_eq(duplicates.size(), 0, "each feature is taught once, with an anchor: %s"
			% str(duplicates))
	check_eq(seen.size(), 6, "six distinct features are taught")


func test_every_anchor_is_really_on_the_game_screen() -> void:
	await _prepare()
	var mounted := await _mount(Vector2(1280, 720), _fresh_profile())
	var screen: Control = mounted["screen"]
	var missing: Array = []
	for feature_id: String in TutorialSteps.FEATURES:
		var anchor := TutorialSteps.anchor_of(feature_id)
		var found: Node = null
		if anchor.begins_with("%"):
			found = screen.get_node_or_null(anchor)
		else:
			found = screen.find_child(anchor, true, false)
		if found == null:
			missing.append("%s → %s" % [feature_id, anchor])
	check_eq(missing.size(), 0, "every taught feature has its control on screen: %s"
			% str(missing))
	# The pause menu and the save chooser are built when the screen is, not when opened;
	# the dossier panel is visible, which is what a step about it claims.
	var side := screen.get_node_or_null("%SidePanel") as Control
	check_true(side != null and side.visible, "the dossier step's panel is on screen")
	(mounted["viewport"] as Node).queue_free()
	_teardown()


func test_no_step_mentions_a_feature_that_does_not_exist() -> void:
	var problems: Array = []
	var negations := ["no ", "not ", "nothing", "never", "without", "cannot", "isn't"]
	for index in TutorialSteps.count():
		var body := TutorialSteps.body_of(index)
		if body.strip_edges().is_empty():
			problems.append("step %d has no text" % index)
		for raw_sentence: String in body.split("."):
			var sentence := raw_sentence.strip_edges().to_lower()
			if sentence.is_empty():
				continue
			for word: String in TutorialSteps.NOT_FEATURES:
				if not sentence.contains(word):
					continue
				var denied := false
				for negation: String in negations:
					if sentence.contains(negation):
						denied = true
				if not denied:
					problems.append("step %d claims %s: %s" % [index, word, sentence])
	check_eq(problems.size(), 0,
			"no step offers a system the game does not have: %s" % str(problems.slice(0, 4)))


func test_every_step_comes_from_the_string_table() -> void:
	var missing: Array = []
	for index in TutorialSteps.count():
		var entry := TutorialSteps.step(index)
		for key_name: String in ["title_key", "body_key"]:
			var key := str(entry.get(key_name, ""))
			if not Strings.has(key):
				missing.append(key)
		if TutorialSteps.title_of(index).strip_edges().is_empty():
			missing.append("empty title at %d" % index)
		if TutorialSteps.body_of(index).length() < 40:
			missing.append("short body at %d" % index)
	check_eq(missing.size(), 0, "every step's words are in the table: %s" % str(missing))
	var source := FileAccess.get_file_as_string("res://src/ui/tutorial/tutorial_steps.gd")
	var literal := ""
	for line: String in source.split("\n"):
		var found := _literal_sentence(line)
		if not found.is_empty():
			literal = found
	check_eq(literal, "", "the step file holds keys, not sentences: %s" % literal)


## A quoted piece of prose: four words or more, over twenty characters, starting with a
## capital. Key names and node names never match, which is the point.
func _literal_sentence(line: String) -> String:
	var start := line.find("\"")
	while start >= 0:
		var closer := line.find("\"", start + 1)
		if closer <= start:
			return ""
		var text := line.substr(start + 1, closer - start - 1)
		var first := text.substr(0, 1)
		if text.split(" ").size() >= 4 and text.length() > 20 and first == first.to_upper() \
				and first != first.to_lower():
			return text
		start = line.find("\"", closer + 1)
	return ""


# --- Paying, and not paying ----------------------------------------------

func test_finishing_pays_the_reward_once_per_profile() -> void:
	await _prepare()
	var profile := _fresh_profile()
	var mounted := await _mount(Vector2(1280, 720), profile)
	var screen: Control = mounted["screen"]
	var panel := _panel(screen)
	check_not_null(panel, "the tutorial panel exists")
	screen.call("open_guide")
	check_eq(panel.step_index(), 0, "it opens at the first step")
	for _step in TutorialSteps.count():
		panel.next_button().emit_signal("pressed")
		await tree.process_frame
	check_true(panel.is_complete(), "the last press lands on the closing card")
	check_true(profile.tutorial_completed, "finishing is recorded on the profile")
	check_true(profile.tutorial_reward_claimed, "and the reward is marked claimed")
	check_eq(profile.xp, Progression.TUTORIAL_XP, "100 XP was paid")
	check_eq(profile.wallet.balance(GameWallet.Currency.GOLD_COINS),
			Progression.TUTORIAL_GOLD, "100 Gold Coins were paid")
	check_eq(profile.wallet.balance(GameWallet.Currency.DIAMONDS),
			Progression.TUTORIAL_DIAMONDS, "25 Red Gems were paid")
	check_true(panel.note().contains(str(Progression.TUTORIAL_XP)),
			"the closing card says what was earned")
	var saved := ProfileStore.new(TEST_PROFILE).load_or_create(1, "2026-11-07")
	var on_disk: PlayerProfile = saved["profile"] as PlayerProfile
	check_true(on_disk != null and on_disk.tutorial_reward_claimed,
			"the profile on disk holds the claim, so a restart cannot pay twice")
	# Reopen and finish again: nothing more is paid.
	screen.call("open_guide")
	for _step in TutorialSteps.count():
		panel.next_button().emit_signal("pressed")
		await tree.process_frame
	check_eq(profile.xp, Progression.TUTORIAL_XP, "a second run pays no XP")
	check_eq(profile.wallet.balance(GameWallet.Currency.DIAMONDS),
			Progression.TUTORIAL_DIAMONDS, "and no Red Gems")
	check_true(panel.note().contains("already"), "the card says the reward was already paid")
	(mounted["viewport"] as Node).queue_free()
	_teardown()


func test_skipping_pays_nothing_and_still_marks_the_profile() -> void:
	await _prepare()
	var profile := _fresh_profile()
	var mounted := await _mount(Vector2(1280, 720), profile)
	var screen: Control = mounted["screen"]
	var panel := _panel(screen)
	screen.call("open_guide")
	panel.skip_button().emit_signal("pressed")
	await tree.process_frame
	check_true(Settings.get_guide_seen(), "skipping records that the guide was seen")
	check_false(profile.tutorial_completed, "but it does not claim completion")
	check_true(profile.tutorial_skipped, "it records the skip instead")
	check_eq(profile.xp, 0, "no XP is paid")
	check_eq(profile.wallet.balance(GameWallet.Currency.GOLD_COINS), 0, "no Gold Coins")
	check_eq(profile.wallet.balance(GameWallet.Currency.DIAMONDS), 0, "no Red Gems")
	(mounted["viewport"] as Node).queue_free()
	_teardown()


# --- Reaching it, and how it looks ---------------------------------------

func test_the_pause_menu_opens_the_tutorial_again() -> void:
	await _prepare()
	var mounted := await _mount(Vector2(1280, 720), _fresh_profile())
	var screen: Control = mounted["screen"]
	screen.call("open_pause_menu")
	var row: Node = null
	for candidate: Node in screen.find_children("*", "NavRow", true, false):
		if str(candidate.get("title_text")).to_lower().contains("guide"):
			row = candidate
	check_not_null(row, "the pause menu offers the guide again")
	(row as Button).emit_signal("pressed")
	await tree.process_frame
	check_true(bool(screen.call("guide_open")), "pressing it opens the tutorial")
	check_false(str(screen.call("guide_text")).is_empty(), "and it has a step to read")
	(mounted["viewport"] as Node).queue_free()
	_teardown()


func test_the_tutorial_fits_every_size_in_both_themes() -> void:
	var original := Settings.get_theme_id()
	var worst := ""
	for theme_id: String in ["midnight", "parchment"]:
		Settings.set_theme_id(theme_id)
		await tree.process_frame
		for label: String in SIZES:
			await _prepare()
			var size: Vector2 = SIZES[label]
			var mounted := await _mount(size, _fresh_profile())
			var screen: Control = mounted["screen"]
			screen.call("open_guide")
			for _frame in 2:
				await tree.process_frame
			var panel := _panel(screen)
			if panel == null:
				worst = "%s/%s: no tutorial panel" % [theme_id, label]
			else:
				if not _inside(panel, size) and worst.is_empty():
					worst = "%s/%s: the panel is at %s, outside %s" % [theme_id, label,
							str(panel.get_global_rect()), str(size)]
				for button: Button in [panel.skip_button(), panel.next_button()]:
					if button != null and button.size.y + 0.5 < DesignTokens.CONTROL_HEIGHT \
							and worst.is_empty():
						worst = "%s/%s: %s is %s high" % [theme_id, label, str(button.name),
								str(button.size.y)]
			(mounted["viewport"] as Node).queue_free()
			_teardown()
	Settings.set_theme_id(original)
	check_eq(worst, "", "the tutorial fits every size in both themes")


func _inside(control: Control, size: Vector2) -> bool:
	var rect := control.get_global_rect()
	return rect.position.x >= -0.5 and rect.position.y >= -0.5 \
			and rect.position.x + rect.size.x <= size.x + 0.5 \
			and rect.position.y + rect.size.y <= size.y + 0.5
