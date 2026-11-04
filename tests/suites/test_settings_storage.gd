extends TestCase
## Settings persistence: defaults, round-trips, and graceful recovery from a
## corrupt or outdated file.

const TEST_PATH := "user://tests/settings_test.cfg"


func _store() -> SettingsStore:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var store := SettingsStore.new(TEST_PATH)
	store.erase()
	return store


func test_defaults_are_returned_when_file_is_missing() -> void:
	var store := _store()
	var values := store.load_values()
	var defaults := SettingsSchema.defaults()
	for key: String in defaults:
		check_eq(values[key], defaults[key], "missing file must yield the default for '%s'" % key)


func test_values_round_trip() -> void:
	var store := _store()
	var values := SettingsSchema.defaults()
	values[SettingsSchema.KEY_THEME] = Palette.PARCHMENT
	values[SettingsSchema.KEY_UI_SCALE] = 1.15
	values[SettingsSchema.KEY_MOTION] = SettingsSchema.MOTION_REDUCED
	check_eq(store.save_values(values), OK, "settings must save")
	var reloaded := store.load_values()
	check_eq(reloaded[SettingsSchema.KEY_THEME], Palette.PARCHMENT, "theme must persist")
	check_eq(reloaded[SettingsSchema.KEY_UI_SCALE], 1.15, "interface scale must persist")
	check_eq(reloaded[SettingsSchema.KEY_MOTION], SettingsSchema.MOTION_REDUCED, "motion must persist")
	store.erase()


func test_invalid_stored_values_are_repaired() -> void:
	var store := _store()
	var raw := ConfigFile.new()
	raw.set_value(SettingsStore.SECTION, SettingsSchema.KEY_THEME, "not-a-theme")
	raw.set_value(SettingsStore.SECTION, SettingsSchema.KEY_UI_SCALE, 99.0)
	raw.set_value(SettingsStore.SECTION, SettingsSchema.KEY_MOTION, 42)
	check_eq(raw.save(TEST_PATH), OK, "fixture must be written")
	var values := store.load_values()
	check_eq(values[SettingsSchema.KEY_THEME], Palette.DEFAULT_ID, "bad palette is repaired")
	check_eq(values[SettingsSchema.KEY_UI_SCALE], 1.0, "bad scale is repaired")
	check_eq(values[SettingsSchema.KEY_MOTION], SettingsSchema.MOTION_FULL, "bad motion is repaired")
	store.erase()


func test_corrupt_file_falls_back_to_defaults() -> void:
	var store := _store()
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	check_not_null(file, "test fixture must be writable")
	if file != null:
		file.store_string("this is not a config file\n[[[")
		file.close()
	var values := store.load_values()
	check_eq(values[SettingsSchema.KEY_THEME], Palette.DEFAULT_ID,
			"a corrupt settings file must not break the game")
	store.erase()


func test_saved_file_has_no_secrets_or_network_data() -> void:
	var store := _store()
	store.save_values(SettingsSchema.defaults())
	var file := FileAccess.open(TEST_PATH, FileAccess.READ)
	check_not_null(file, "settings file must exist after saving")
	if file != null:
		var text := file.get_as_text()
		file.close()
		check_true(text.contains(SettingsStore.SECTION),
				"settings file must contain the settings section")
		for forbidden: String in ["http://", "https://", "token", "password"]:
			check_false(text.contains(forbidden), "settings file must not contain '%s'" % forbidden)
	store.erase()
