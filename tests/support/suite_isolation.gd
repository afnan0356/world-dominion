class_name SuiteIsolation
extends RefCounted
## One shared setup and teardown for every suite (Milestone 12, Task 1).
##
## The suite used to be isolated by convention: each suite saved what it changed and put it back
## in its own teardown. Twenty suites did that, in twenty slightly different ways, and a suite
## that failed halfway put nothing back at all — the next suite then ran against a `Game` session
## somebody else opened, a settings file somebody else wrote, and a static cache somebody else
## filled. That is the shape of the Milestone 11 red run, whose assertions passed in the next run
## with the same production code.
##
## This file replaces the convention with one place that:
##
##   * drops every piece of module state the game keeps between calls (`static var` in
##     `CountryState`, `DiagnosticsLog`, `WorldDeletion`, `ShellIcon`, `IconAtlas`, `FlagImage`,
##     `StartEligibility`, `ModalPanel`) through an explicit `reset`/`clear` on each one, so a
##     cache added later without a reset is a visible gap rather than a silent leak;
##   * starts from a clean `user://` for the directories the suites use, and reports anything a
##     suite leaves behind;
##   * snapshots and restores the four autoloads' observable state — every setting, the audio
##     volumes, the active session and the save store — without caring whether a suite remembered
##     to.
##
## The runner calls `begin()` before a suite and `finish()` after it and prints what `finish()`
## reports, so a leak is visible in the log even when every assertion passed.

## Directories under `user://` that belong to suites rather than to the game. Anything here is
## deleted before a suite starts, so a suite cannot inherit files from the one before it.
const TEST_DIRECTORIES := [
	"user://test_hud_saves",
	"user://test_whats_new_saves",
	"user://test_saves",
	"user://test_worlds",
	"user://test_backup",
	"user://test_profile",
	"user://test_recovery",
	"user://test_deletion",
	"user://test_shell",
	"user://test_campaign",
]

## Files the game itself owns at the root of `user://`. Anything else at the root after a suite is
## a leak, and `leftovers()` names it.
const GAME_FILES := ["settings.cfg", "profile.json", "first_run.json", "diagnostics.log"]

static var _snapshot: Dictionary = {}
static var _root_before: Array = []
static var _started := false


## Everything a suite might change, captured before it runs.
static func begin() -> void:
	var settings := {}
	for key: String in SettingsSchema.defaults():
		settings[key] = Settings.get_value(key)
	var audio := {}
	for bus_name: String in AudioSettings.BUSES:
		audio[bus_name] = {"volume": AudioSettings.volume(bus_name),
				"muted": AudioSettings.muted(bus_name)}
	_snapshot = {
		"settings": settings,
		"audio": audio,
		"store": Game.store,
		"session": Game.has_session(),
	}
	_clear_directories()
	_root_before = _root_files()
	_reset_module_state()
	_started = true


## Puts everything back and returns what the suite left behind: `{"leaks": [...], "cleaned": n}`.
## Called even when the suite failed, because a failing suite is exactly the one that forgets.
static func finish() -> Dictionary:
	if Game.has_session():
		Game.close()
	if _started:
		if _snapshot.has("store"):
			Game.store = _snapshot["store"]
		var settings: Dictionary = _snapshot.get("settings", {})
		for key: String in settings:
			if Settings.get_value(key) != settings[key]:
				Settings.set_value(key, settings[key])
		var audio: Dictionary = _snapshot.get("audio", {})
		for bus_name: String in audio:
			var entry: Dictionary = audio[bus_name]
			AudioSettings.set_volume(bus_name, float(entry.get("volume", 1.0)))
			AudioSettings.set_muted(bus_name, bool(entry.get("muted", false)))
	var cleaned := _clear_directories()
	var leaks := leftovers()
	_root_before = []
	_started = false
	_reset_module_state()
	return {"leaks": leaks, "cleaned": cleaned}


## Files at the root of `user://` that were not there before the suite and that the game does not
## own. A suite that writes a save into `user://` directly, or a profile file it forgets, shows up
## here rather than in the next suite's results.
static func leftovers() -> Array:
	var out: Array = []
	for file_name: String in _root_files():
		if _root_before.has(file_name):
			continue
		if GAME_FILES.has(file_name):
			continue
		out.append(file_name)
	return out


## Drops every cache the game keeps in a `static var`. Each call is a real reset with a reason;
## adding a cache without one leaves the previous suite's answers visible to the next.
static func _reset_module_state() -> void:
	CountryState.reset_shared()
	DiagnosticsLog.clear()
	WorldDeletion.reset_session()
	ShellIcon.clear_cache()
	IconAtlas.clear_cache()
	FlagImage.clear_cache()
	StartEligibility.reload()
	ModalPanel.clear_stack()


## Deletes the suite-owned directories under `user://` and returns how many entries went.
static func _clear_directories() -> int:
	var removed := 0
	for path: String in TEST_DIRECTORIES:
		removed += _remove_tree(path)
	return removed


static func _remove_tree(path: String) -> int:
	if not DirAccess.dir_exists_absolute(path):
		return 0
	var removed := 0
	var directory := DirAccess.open(path)
	if directory == null:
		return 0
	for file_name: String in directory.get_files():
		if directory.remove(file_name) == OK:
			removed += 1
	for sub: String in directory.get_directories():
		removed += _remove_tree(path.path_join(sub))
	if DirAccess.remove_absolute(path) == OK:
		removed += 1
	return removed


static func _root_files() -> Array:
	var out: Array = []
	var directory := DirAccess.open("user://")
	if directory == null:
		return out
	for file_name: String in directory.get_files():
		out.append(file_name)
	for sub: String in directory.get_directories():
		out.append("%s/" % sub)
	out.sort()
	return out
