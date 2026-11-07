extends TestCase
## Deleting a world (Milestone 09, Task 6).
##
## Under test: the confirmation names the world (slot, country, in-game date, playtime);
## cancelling changes nothing on disk; confirming makes a recovery copy first and then deletes
## only that slot; Undo restores it; when no copy can be made the screen says the deletion is
## permanent *before* it happens; and — the rule that matters most — the profile and every other
## world are untouched in every one of those paths.

const SUITE_DIR := "user://tests/deletion_saves"
const WORLDS_SCENE := "res://src/ui/screens/worlds/worlds_screen.tscn"
const PROFILE_PATH := "user://tests/deletion_profile.json"


func _store() -> SaveStore:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SUITE_DIR))
	var store := SaveStore.new(SUITE_DIR)
	_clear(store)
	return store


func _clear(store: SaveStore) -> void:
	for slot: String in SaveStore.SLOT_IDS:
		store.delete(slot)
	var copy_folder := store.directory().path_join(WorldDeletion.COPY_FOLDER)
	var directory := DirAccess.open(copy_folder)
	if directory != null:
		for file_name: String in directory.get_files():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(
					copy_folder.path_join(file_name)))


func _profile_store() -> ProfileStore:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	return ProfileStore.new(PROFILE_PATH)


func _write_world(store: SaveStore, slot: String, seed_value: int) -> void:
	var atlas := WorldAtlas.load_default()
	var record := atlas.registry.get_country("BGD")
	var config := CampaignConfig.new()
	config.scenario_id = "modern_world_2026"
	config.country_id = "BGD"
	config.start_date = "2026-01-01"
	config.metadata = {"scenario_name": "Modern World",
			"country_name": record.name if record != null else "BGD"}
	var world := WorldState.new_campaign(config, atlas.registry, DataStamp.compute(atlas),
			seed_value)
	world.add_playtime(3725.0)
	var result := store.save(slot, world, "2026-01-01T00:00:00Z", "2026-02-01T00:00:00Z")
	check_true(bool(result["ok"]), "the fixture world saves into slot %s" % slot)


func _file_size(path: String) -> int:
	if not FileAccess.file_exists(path):
		return -1
	return FileAccess.get_file_as_string(path).to_utf8_buffer().size()


func _cleanup(store: SaveStore) -> void:
	_clear(store)
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	var copy_folder := store.directory().path_join(WorldDeletion.COPY_FOLDER)
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(copy_folder)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(copy_folder))


# --- The engine ------------------------------------------------------------

func test_the_description_names_the_world() -> void:
	var store := _store()
	_write_world(store, "1", 4242)
	var deletion := WorldDeletion.new(store)
	var described := deletion.describe("1")
	check_eq(str(described["slot"]), "1", "the slot is named")
	check_eq(str(described["country"]), "Bangladesh", "the country is named")
	check_false(str(described["date"]).is_empty(), "the in-game date is named")
	check_eq(int(described["playtime_seconds"]), 3725, "the playtime is read from the save")
	check_eq(str(described["playtime_label"]), "1 h 02 min", "and shown in plain words")
	check_true(bool(described["exists"]), "and it says the world exists")
	check_eq(WorldDeletion.playtime_label(0), "less than a minute", "short playtime reads well")
	check_eq(WorldDeletion.playtime_label(600), "10 min", "minutes read well")
	_cleanup(store)


func test_delete_copies_first_then_deletes_only_that_slot() -> void:
	var store := _store()
	_write_world(store, "1", 111)
	_write_world(store, "2", 222)
	var profile := _profile_store()
	var loaded: Dictionary = profile.load_or_create(99, "2026-11-07")
	check_true(bool(profile.save(loaded["profile"])["ok"]), "the fixture profile is written")
	var profile_before := _file_size(PROFILE_PATH)
	check_true(profile_before > 0, "the fixture profile exists")
	var other_slot_size := _file_size(store.path_for("2"))
	var deletion := WorldDeletion.new(store)
	check_true(deletion.copy_possible("1"), "a recovery copy is possible on this device")

	var result := deletion.delete("1")
	check_true(bool(result["ok"]), "the deletion succeeds: %s" % str(result["error"]))
	check_true(bool(result["copy_made"]), "and it made a recovery copy first")
	check_true(bool(result["undo_available"]), "so the deletion is undoable this session")
	check_false(bool(result["permanent"]), "not permanent")
	check_false(store.exists("1"), "slot 1 is gone")
	check_true(store.exists("2"), "slot 2 is untouched")
	check_eq(_file_size(store.path_for("2")), other_slot_size, "byte for byte")
	check_eq(_file_size(PROFILE_PATH), profile_before,
			"the profile is a different file and was not touched")
	var reloaded: Dictionary = profile.load_or_create(99, "2026-11-07")
	check_eq(str((reloaded["profile"] as PlayerProfile).display_name),
			str((loaded["profile"] as PlayerProfile).display_name),
			"and it still loads with the same name")
	_cleanup(store)


func test_undo_puts_the_world_back() -> void:
	var store := _store()
	_write_world(store, "3", 333)
	var original := _file_size(store.path_for("3"))
	var deletion := WorldDeletion.new(store)
	var result := deletion.delete("3")
	check_true(bool(result["undo_available"]), "the copy is there to undo with")
	check_true(deletion.undo("3"), "undo restores the world")
	check_true(store.exists("3"), "the slot exists again")
	check_eq(_file_size(store.path_for("3")), original, "with the same bytes")
	check_false(deletion.undo_available("3"), "and the copy is not claimed twice")
	check_false(deletion.undo("3"), "a second undo has nothing to restore")
	_cleanup(store)


func test_deletion_without_a_copy_is_reported_as_permanent() -> void:
	var store := _store()
	_write_world(store, "1", 555)
	var deletion := WorldDeletion.new(store)
	deletion.inject_copy_failure = true
	check_false(deletion.copy_possible("1"), "the panel would warn about permanence beforehand")
	var refused := deletion.delete("1")
	check_false(bool(refused["ok"]), "without permission, no copy means no deletion")
	check_true(store.exists("1"), "so the world is still there")
	check_false(str(refused["error"]).is_empty(), "and the refusal says why")
	var allowed := deletion.delete("1", true)
	check_true(bool(allowed["ok"]), "with explicit permission the deletion goes ahead")
	check_true(bool(allowed["permanent"]), "and is reported as permanent")
	check_false(bool(allowed["undo_available"]), "with nothing to undo")
	check_false(deletion.undo("1"), "undo honestly does nothing")
	_cleanup(store)


func test_a_missing_slot_is_refused() -> void:
	var store := _store()
	var deletion := WorldDeletion.new(store)
	var result := deletion.delete("2")
	check_false(bool(result["ok"]), "there is nothing to delete in an empty slot")
	check_false(bool(result["copy_made"]), "and no copy is made for nothing")
	check_false(str(result["error"]).is_empty(), "the reason is stated")
	_cleanup(store)


func test_the_session_clears_last_runs_copies() -> void:
	var store := _store()
	_write_world(store, "1", 777)
	var deletion := WorldDeletion.new(store)
	var folder := deletion.copy_folder()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var stale := folder.path_join("stale.json")
	var file := FileAccess.open(stale, FileAccess.WRITE)
	if file != null:
		file.store_string("{}")
		file.close()
	# A copy from an earlier run is not this session's undo, so opening the screen forgets it.
	deletion.begin_session()
	check_false(FileAccess.file_exists(stale),
			"a copy from an earlier run is not offered as an undo")
	# A copy this session made survives: deleting a world, leaving the screen and coming back
	# must not take the undo away.
	_write_world(store, "2", 888)
	var deleted := deletion.delete("2")
	check_true(bool(deleted["undo_available"]), "this session's deletion is undoable")
	deletion.begin_session()
	check_true(deletion.undo_available("2"), "and opening the screen again keeps it")
	check_true(deletion.undo("2"), "so the undo still works")
	check_true(store.exists("2"), "the world is back")
	_cleanup(store)


# --- The screen ------------------------------------------------------------

func _mount_worlds(store: SaveStore) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: WorldsScreen = load(WORLDS_SCENE).instantiate()
	screen.store = store
	holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await tree.process_frame
	await tree.process_frame
	return {"viewport": viewport, "screen": screen}


func test_the_screen_confirms_cancels_and_deletes() -> void:
	var store := _store()
	_write_world(store, "1", 808)
	_write_world(store, "2", 909)
	var mounted := await _mount_worlds(store)
	var screen: WorldsScreen = mounted["screen"]
	var before := _file_size(store.path_for("1"))

	var described: Dictionary = screen.ask_delete("1")
	check_eq(screen.confirming_slot(), "1", "Delete opens a confirmation for that world")
	check_eq(str(described["country"]), "Bangladesh", "which names the country")
	check_true(str(described["playtime_label"]).contains("h"), "and the playtime played")
	var panel := screen.find_child("Confirm_1", true, false) as Control
	check_not_null(panel, "the confirmation panel exists")
	if panel != null:
		check_true(panel.visible, "and is shown")
		var confirm := screen.find_child("ConfirmDelete_1", true, false) as Button
		var keep := screen.find_child("CancelDelete_1", true, false) as Button
		check_not_null(confirm, "with a delete button")
		check_not_null(keep, "and a keep button")
		check_gte(confirm.size.y, DesignTokens.CONTROL_HEIGHT, "both full height")
		check_false(confirm.disabled, "a copy is possible, so delete is allowed")

	screen.cancel_delete()
	check_eq(screen.confirming_slot(), "", "cancelling clears the confirmation")
	check_eq(_file_size(store.path_for("1")), before, "and changes nothing on disk")

	screen.ask_delete("1")
	check_eq(screen.confirm_delete(), "deleted", "confirming deletes and offers an undo")
	check_false(store.exists("1"), "slot 1 is gone")
	check_true(store.exists("2"), "slot 2 is still there")
	check_true(screen.can_undo(), "the screen offers Undo")
	var undo := screen.find_child("UndoDelete", true, false) as Button
	check_not_null(undo, "with a real button")
	if undo != null:
		check_true(undo.visible, "which is visible while an undo exists")
		undo.pressed.emit()
	check_true(store.exists("1"), "and pressing it restores the world")
	check_false(screen.can_undo(), "after which there is nothing left to undo")
	(mounted["viewport"] as Node).queue_free()
	_cleanup(store)


func test_the_screen_reports_permanent_deletion() -> void:
	var store := _store()
	_write_world(store, "1", 1212)
	var mounted := await _mount_worlds(store)
	var screen: WorldsScreen = mounted["screen"]
	# Make the recovery copy fail the way a read-only device would, then rebuild the row so the
	# confirmation is drawn with that truth rather than with the truth from a moment ago.
	screen.deletion_engine().inject_copy_failure = true
	screen.cancel_delete()
	screen.ask_delete("1")
	var panel := screen.find_child("Confirm_1", true, false) as Control
	check_true(panel.visible, "the confirmation is open")
	check_eq(screen.confirm_delete(), "deleted_permanent",
			"with no copy the screen calls it permanent")
	check_false(store.exists("1"), "the world is gone")
	check_false(screen.can_undo(), "and no undo is offered")
	check_true(screen.status_text().contains("permanent"), "the status says so: %s"
			% screen.status_text())
	(mounted["viewport"] as Node).queue_free()
	_cleanup(store)


func test_the_delete_controls_fit_every_size_in_both_themes() -> void:
	var store := _store()
	_write_world(store, "1", 1313)
	var original := Settings.get_theme_id()
	var problems := PackedStringArray()
	for theme_id: String in ["midnight", "parchment"]:
		Settings.set_theme_id(theme_id)
		await tree.process_frame
		for size: Vector2 in [Vector2(640, 360), Vector2(1280, 720), Vector2(1920, 1080)]:
			var viewport := SubViewport.new()
			viewport.size = Vector2i(size)
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			host.add_child(viewport)
			var holder := Control.new()
			holder.theme = ThemeManager.current_theme()
			viewport.add_child(holder)
			holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var screen: WorldsScreen = load(WORLDS_SCENE).instantiate()
			screen.store = store
			holder.add_child(screen)
			screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			await tree.process_frame
			await tree.process_frame
			screen.ask_delete("1")
			for node: Node in screen.find_children("*", "BaseButton", true, false):
				var button := node as BaseButton
				if not button.visible or button.custom_minimum_size.y <= 0.0:
					continue
				if button.size.y + 0.5 < DesignTokens.CONTROL_HEIGHT_COMPACT:
					problems.append("%s @ %s: '%s' is %.0f px high" % [theme_id, str(size),
							button.name, button.size.y])
			viewport.queue_free()
	Settings.set_theme_id(original)
	check_eq(problems, PackedStringArray(),
			"the delete and confirm controls stay tappable at every size")
	_cleanup(store)
