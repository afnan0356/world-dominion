extends TestCase
## Backup, worlds, and the three-choice recovery dialog (Milestone 08, Task 6).
##
## The promise under test is not "recovery works" but "nothing is decided behind the
## player's back": a damaged profile, a damaged world and a restore that would replace a
## world each ask the same three questions, each answer has a different, checkable effect on
## the files, and none of them deletes or repairs anything.

const WORLDS_SCENE := "res://src/ui/screens/worlds/worlds_screen.tscn"
const BACKUP_SCENE := "res://src/ui/screens/backup/backup_screen.tscn"
const PROFILE_SCENE := "res://src/ui/screens/profile/profile_screen.tscn"
const SAVE_DIR := "user://test_recovery_saves"
const BACKUP_DIR := "user://test_recovery_backups"
const PROFILE_PATH := "user://test_recovery_profile.json"
const SIZES := {
	"640x360": Vector2(640, 360),
	"1280x720": Vector2(1280, 720),
	"1920x1080": Vector2(1920, 1080),
	"390x844": Vector2(390, 844),
}

var _atlas: WorldAtlas
var _original_store: SaveStore


# --- Fixtures -------------------------------------------------------------

func _atlas_load() -> void:
	if _atlas == null:
		_atlas = WorldAtlas.load_default()


func _world(seed_value: int) -> WorldState:
	_atlas_load()
	var config := CampaignConfig.new()
	config.scenario_id = "modern_world_2026"
	config.country_id = "BGD"
	config.start_date = "2026-01-01"
	config.metadata = {"scenario_name": "Modern World", "country_name": "Bangladesh"}
	return WorldState.new_campaign(config, _atlas.registry, DataStamp.compute(_atlas),
			seed_value)


func _store() -> SaveStore:
	var store := SaveStore.new(SAVE_DIR)
	_clear_dir(SAVE_DIR)
	return store


func _clear_dir(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory := DirAccess.open(absolute)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		directory.remove(file_name)


func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _profile(name_value: String = "Keeper") -> PlayerProfile:
	var profile := PlayerProfile.create(8080, "2026-11-07")
	profile.display_name = name_value
	profile.username = "keeper"
	profile.username_locked = true
	return profile


## A profile file plus a readable rolling backup, then a damaged main file: the exact state
## the profile screen must ask about rather than paper over.
func _damaged_profile() -> ProfileStore:
	var store := ProfileStore.new(PROFILE_PATH)
	_remove_file(PROFILE_PATH)
	_remove_file(PROFILE_PATH.get_basename() + ".old.json")
	var profile := _profile()
	store.save(profile)
	store.save(profile)
	var handle := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	handle.store_string("{ this is not a profile")
	handle.close()
	return store


## Mounts a real screen. `configure` runs before the screen enters the tree, so a test can
## hand it its own store and paths and have `_ready()` use them — no second `_ready()` call.
func _mount(scene_path: String, size: Vector2 = Vector2(1280, 720),
		configure: Callable = Callable()) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Control = load(scene_path).instantiate()
	if configure.is_valid():
		configure.call(screen)
	holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for _frame in 3:
		await tree.process_frame
	return {"viewport": viewport, "screen": screen, "holder": holder}


## Points the global campaign service at a scratch store, so an "open world" attempt in a
## test cannot resume somebody else's slot.
func _use_store(store: SaveStore) -> void:
	_original_store = Game.store if _original_store == null else _original_store
	Game.close()
	Game.store = store


func _release_store() -> void:
	Game.close()
	if _original_store != null:
		Game.store = _original_store
	_original_store = null


func _buttons_with_text(node: Node, needle: String) -> Array:
	var found: Array = []
	for candidate: Node in node.find_children("*", "Button", true, false):
		if str((candidate as Button).text).contains(needle):
			found.append(candidate)
	return found


# --- The dialog itself ----------------------------------------------------

func test_the_dialog_offers_exactly_three_choices() -> void:
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	host.add_child(holder)
	var dialog := IntegrityDialog.new()
	holder.add_child(dialog)
	dialog.setup(PackedStringArray(["The file could not be read."]), true)
	await tree.process_frame
	check_eq(IntegrityDialog.CHOICES.size(), 3, "there are three answers and no fourth")
	for choice: String in IntegrityDialog.CHOICES:
		check_not_null(dialog.button_for(choice), "the %s choice has a button" % choice)
	check_eq(int(dialog.button_for(IntegrityDialog.CHOICE_BACKUP).custom_minimum_size.y),
			DesignTokens.CONTROL_HEIGHT, "every answer is a full-height control")
	var seen := [""]
	dialog.chosen.connect(func(choice: String) -> void: seen[0] = choice)
	dialog.choose(IntegrityDialog.CHOICE_CONTINUE)
	check_eq(str(seen[0]), IntegrityDialog.CHOICE_CONTINUE, "the dialog reports the answer")
	dialog.choose("something else")
	check_eq(str(seen[0]), IntegrityDialog.CHOICE_CONTINUE, "an unknown answer is ignored")
	dialog.setup(PackedStringArray(["No backup here."]), false)
	check_false(dialog.backup_available(), "the backup answer knows when it has nothing to use")
	check_true(dialog.button_for(IntegrityDialog.CHOICE_BACKUP).disabled,
			"and its button is disabled rather than lying")
	dialog.choose(IntegrityDialog.CHOICE_BACKUP)
	check_eq(str(seen[0]), IntegrityDialog.CHOICE_CONTINUE,
			"a disabled backup answer cannot be chosen")
	holder.queue_free()


# --- Profile load ---------------------------------------------------------

func test_a_damaged_profile_asks_before_using_the_backup() -> void:
	var store := _damaged_profile()
	var before := FileAccess.get_file_as_string(PROFILE_PATH)
	var mounted := await _mount(PROFILE_SCENE, Vector2(1280, 720),
			func(candidate: Control) -> void: candidate.set("profile_store", store))
	var screen: ProfileScreen = mounted["screen"]
	await tree.process_frame
	check_true(screen.recovery_prompt_open(), "a damaged profile opens the dialog")
	check_gt(float(screen.recovery_problems().size()), 0.0, "with the engine's own reasons")
	check_true(_buttons_with_text(screen, "backup").size() > 0,
			"and the backup answer is on screen")
	var answer := screen.resolve_recovery(IntegrityDialog.CHOICE_BACKUP)
	await tree.process_frame
	check_eq(answer, "loaded_backup", "choosing the backup loads the previous copy")
	check_eq(screen.current_profile().display_name, "Keeper",
			"which is the profile the backup held")
	check_eq(FileAccess.get_file_as_string(PROFILE_PATH), before,
			"and the damaged file is left exactly as it was found")
	(mounted["viewport"] as Node).queue_free()


func test_continuing_with_a_damaged_profile_changes_no_file() -> void:
	var store := _damaged_profile()
	var before := FileAccess.get_file_as_string(PROFILE_PATH)
	var backup_before := FileAccess.get_file_as_string(PROFILE_PATH.get_basename()
			+ ".old.json")
	var mounted := await _mount(PROFILE_SCENE, Vector2(1280, 720),
			func(candidate: Control) -> void: candidate.set("profile_store", store))
	var screen: ProfileScreen = mounted["screen"]
	await tree.process_frame
	var answer := screen.resolve_recovery(IntegrityDialog.CHOICE_CONTINUE)
	await tree.process_frame
	check_eq(answer, "continued", "continuing is a distinct answer")
	check_false(screen.recovery_prompt_open(), "and the question is answered")
	check_true(screen.status_text().length() > 0, "the screen says what happened")
	check_eq(FileAccess.get_file_as_string(PROFILE_PATH), before,
			"the damaged profile is still there, untouched")
	check_eq(FileAccess.get_file_as_string(PROFILE_PATH.get_basename() + ".old.json"),
			backup_before, "and so is the backup")
	(mounted["viewport"] as Node).queue_free()


func test_cancelling_a_damaged_profile_leaves_the_screen() -> void:
	var store := _damaged_profile()
	var before := FileAccess.get_file_as_string(PROFILE_PATH)
	var mounted := await _mount(PROFILE_SCENE, Vector2(1280, 720),
			func(candidate: Control) -> void: candidate.set("profile_store", store))
	var screen: ProfileScreen = mounted["screen"]
	await tree.process_frame
	var left := [false]
	screen.back_requested.connect(func() -> void: left[0] = true)
	var answer := screen.resolve_recovery(IntegrityDialog.CHOICE_CANCEL)
	check_eq(answer, "cancelled", "cancelling is reported")
	check_true(left[0], "and asks the shell to go back")
	check_eq(FileAccess.get_file_as_string(PROFILE_PATH), before,
			"with nothing written on the way out")
	(mounted["viewport"] as Node).queue_free()


# --- World load -----------------------------------------------------------

func _damaged_world_store() -> SaveStore:
	var store := _store()
	store.save("1", _world(11), "2026-01-01", "2026-02-01T00:00:00Z")
	store.save("1", _world(12), "2026-01-01", "2026-02-02T00:00:00Z")
	var handle := FileAccess.open(store.path_for("1"), FileAccess.WRITE)
	handle.store_string("{\"format\": \"world-dominion-save\", nonsense")
	handle.close()
	return store


func test_a_damaged_world_asks_before_using_the_backup() -> void:
	var store := _damaged_world_store()
	_use_store(store)
	var mounted := await _mount(WORLDS_SCENE, Vector2(1280, 720),
			func(candidate: Control) -> void: candidate.set("store", store))
	var screen: WorldsScreen = mounted["screen"]
	var state := screen.slot_state("1")
	check_true(bool(state["exists"]), "the slot is there")
	check_false(bool(state["ok"]), "and the screen saw that it cannot be read")
	check_true(bool(state["has_backup"]), "while a previous copy exists")
	check_eq(screen.choose_slot("1"), "prompt", "tapping it opens the dialog")
	check_true(screen.dialog_open(), "which is really on screen")
	check_eq(screen.resolve(IntegrityDialog.CHOICE_BACKUP), "opened_from_backup",
			"the backup answer loads the previous copy")
	check_true(FileAccess.get_file_as_string(store.path_for("1")).contains("nonsense"),
			"and the damaged file is not overwritten by a load")
	(mounted["viewport"] as Node).queue_free()
	_release_store()


func test_continuing_with_a_damaged_world_changes_no_file() -> void:
	var store := _damaged_world_store()
	var before := FileAccess.get_file_as_string(store.path_for("1"))
	_use_store(store)
	var mounted := await _mount(WORLDS_SCENE, Vector2(1280, 720),
			func(candidate: Control) -> void: candidate.set("store", store))
	var screen: WorldsScreen = mounted["screen"]
	check_eq(screen.choose_slot("1"), "prompt", "the dialog opens")
	check_eq(screen.resolve(IntegrityDialog.CHOICE_CONTINUE), "continued",
			"continuing is a distinct answer")
	check_eq(FileAccess.get_file_as_string(store.path_for("1")), before,
			"and the damaged world is exactly as it was")
	check_true(screen.status_text().length() > 0, "the screen says so in words")
	(mounted["viewport"] as Node).queue_free()
	_release_store()


func test_cancelling_a_damaged_world_does_nothing() -> void:
	var store := _damaged_world_store()
	var before := FileAccess.get_file_as_string(store.path_for("1"))
	_use_store(store)
	var mounted := await _mount(WORLDS_SCENE, Vector2(1280, 720),
			func(candidate: Control) -> void: candidate.set("store", store))
	var screen: WorldsScreen = mounted["screen"]
	screen.choose_slot("1")
	check_eq(screen.resolve(IntegrityDialog.CHOICE_CANCEL), "cancelled", "cancel is reported")
	check_false(screen.dialog_open(), "the dialog closes")
	check_eq(FileAccess.get_file_as_string(store.path_for("1")), before,
			"with the file untouched")
	(mounted["viewport"] as Node).queue_free()
	_release_store()


func test_a_readable_world_opens_without_asking_anything() -> void:
	var store := _store()
	store.save("2", _world(21), "2026-01-01", "2026-02-03T00:00:00Z")
	_use_store(store)
	var mounted := await _mount(WORLDS_SCENE, Vector2(1280, 720),
			func(candidate: Control) -> void: candidate.set("store", store))
	var screen: WorldsScreen = mounted["screen"]
	check_eq(screen.choose_slot("2"), "opened", "a good world opens straight away")
	check_false(screen.dialog_open(), "and asks nothing")
	check_eq(screen.choose_slot("3"), "empty", "an empty slot says it is empty")
	(mounted["viewport"] as Node).queue_free()
	_release_store()


# --- Restore --------------------------------------------------------------

func _backup_screen_with_bundle() -> Array:
	var store := _store()
	store.save("1", _world(31), "2026-01-01", "2026-02-04T00:00:00Z")
	var text := FileAccess.get_file_as_string(store.path_for("1"))
	var bundle := BackupBundle.build(_profile("Bundle Holder"), {"1": text},
			"2026-11-07T10:00:00Z", "A backup")
	_clear_dir(BACKUP_DIR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP_DIR))
	var target := BACKUP_DIR.path_join("bundle.json")
	BackupBundle.write_file(bundle, target)
	return [store, target, text]


func test_restoring_over_an_existing_world_asks_first() -> void:
	var prepared := _backup_screen_with_bundle()
	var store: SaveStore = prepared[0]
	var bundle_path := str(prepared[1])
	var bundle_text := str(prepared[2])
	# Replace the device's copy with different text, so an overwrite is visible.
	var handle := FileAccess.open(store.path_for("1"), FileAccess.WRITE)
	handle.store_string("{\"device\": \"copy\"}")
	handle.close()
	var before := FileAccess.get_file_as_string(store.path_for("1"))
	var mounted := await _mount(BACKUP_SCENE, Vector2(1280, 720),
			func(candidate: Control) -> void:
				candidate.set("store", store)
				candidate.set("backup_directory", BACKUP_DIR))
	var screen: BackupScreen = mounted["screen"]
	check_eq(screen.backup_files().size(), 1, "the backup folder holds one file")
	var asked := screen.begin_restore(bundle_path)
	check_true(bool(asked["prompt"]), "a restore that would replace a world asks first")
	check_true(screen.dialog_open(), "the dialog is on screen")
	var kept := screen.resolve(IntegrityDialog.CHOICE_BACKUP)
	check_true(bool(kept.get("kept", false)), "the backup answer keeps the device's copies")
	check_eq(FileAccess.get_file_as_string(store.path_for("1")), before,
			"so the world on this device is untouched")
	var asked_again := screen.begin_restore(bundle_path)
	check_true(bool(asked_again["prompt"]), "asking again is still required")
	var restored := screen.resolve(IntegrityDialog.CHOICE_CONTINUE)
	check_true((restored.get("restored", []) as Array).has("1"),
			"continuing writes the world from the backup")
	check_eq(FileAccess.get_file_as_string(store.path_for("1")), bundle_text,
			"and the file is the one the backup held, byte for byte")
	(mounted["viewport"] as Node).queue_free()


func test_cancelling_a_restore_writes_nothing() -> void:
	var prepared := _backup_screen_with_bundle()
	var store: SaveStore = prepared[0]
	var bundle_path := str(prepared[1])
	var handle := FileAccess.open(store.path_for("1"), FileAccess.WRITE)
	handle.store_string("{\"device\": \"copy\"}")
	handle.close()
	var before := FileAccess.get_file_as_string(store.path_for("1"))
	var mounted := await _mount(BACKUP_SCENE, Vector2(1280, 720),
			func(candidate: Control) -> void:
				candidate.set("store", store)
				candidate.set("backup_directory", BACKUP_DIR))
	var screen: BackupScreen = mounted["screen"]
	screen.begin_restore(bundle_path)
	var answer := screen.resolve(IntegrityDialog.CHOICE_CANCEL)
	check_true(bool(answer.get("cancelled", false)), "cancelling is reported")
	check_eq(FileAccess.get_file_as_string(store.path_for("1")), before,
			"and the file is untouched")
	check_false(screen.dialog_open(), "the dialog is gone")
	(mounted["viewport"] as Node).queue_free()


func test_a_backup_the_screen_makes_reads_back() -> void:
	var store := _store()
	store.save("1", _world(41), "2026-01-01", "2026-02-05T00:00:00Z")
	_clear_dir(BACKUP_DIR)
	var mounted := await _mount(BACKUP_SCENE, Vector2(1280, 720),
			func(candidate: Control) -> void:
				candidate.set("store", store)
				candidate.set("backup_directory", BACKUP_DIR))
	var screen: BackupScreen = mounted["screen"]
	screen.profile_store = ProfileStore.new(PROFILE_PATH)
	var written := screen.create_backup()
	check_true(bool(written["ok"]), "the screen writes a backup: %s"
			% str(written.get("error", "")))
	var path := str(written["path"])
	check_true(FileAccess.file_exists(path), "the file is where it says it is")
	var inspected := BackupBundle.inspect(FileAccess.get_file_as_string(path))
	check_true(bool(inspected["ok"]), "and it inspects as a sound bundle")
	var summary: Dictionary = inspected["summary"]
	check_eq(str(summary["player_name"]), _profile().display_name,
			"with the profile's own name in it")
	check_eq((summary["worlds"] as Array).size(), 1, "and the one world that exists")
	check_eq(screen.backup_files().size(), 1, "the list shows it")
	(mounted["viewport"] as Node).queue_free()
	_clear_dir(BACKUP_DIR)


# --- Layout ---------------------------------------------------------------

func test_the_recovery_screens_fit_every_size_in_both_themes() -> void:
	var original := Settings.get_theme_id()
	var worst := ""
	for theme_id: String in ["midnight", "parchment"]:
		Settings.set_theme_id(theme_id)
		await tree.process_frame
		for label: String in SIZES:
			var size: Vector2 = SIZES[label]
			_clear_dir(BACKUP_DIR)
			var mounted := await _mount(WORLDS_SCENE, size)
			var worlds: WorldsScreen = mounted["screen"]
			if worlds.size.distance_to(size) > 1.0 and worst.is_empty():
				worst = "%s/%s: the worlds screen is %s" % [theme_id, label, str(worlds.size)]
			for button: Node in _buttons_with_text(worlds, ""):
				var control := button as Control
				if control.visible and control.size.y + 0.5 < DesignTokens.CONTROL_HEIGHT \
						and worst.is_empty():
					worst = "%s/%s: %s is %s high" % [theme_id, label, str(control.name),
							str(control.size.y)]
			(mounted["viewport"] as Node).queue_free()
			var second := await _mount(BACKUP_SCENE, size,
					func(candidate: Control) -> void:
						candidate.set("backup_directory", BACKUP_DIR))
			var backup: BackupScreen = second["screen"]
			if backup.size.distance_to(size) > 1.0 and worst.is_empty():
				worst = "%s/%s: the backup screen is %s" % [theme_id, label, str(backup.size)]
			(second["viewport"] as Node).queue_free()
	Settings.set_theme_id(original)
	check_eq(worst, "", "both screens fit every size in both themes")
	_clear_dir(BACKUP_DIR)
