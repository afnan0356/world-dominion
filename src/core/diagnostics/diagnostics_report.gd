class_name DiagnosticsReport
extends RefCounted
## The diagnostics text and the file it is written to (Milestone 09, Task 4).
##
## What goes in: the build's version, the data pack's version and generation date, the engine,
## the platform, the window size and interface scale, the frame-rate cap, the coordinates the
## report was produced with, and the game's own last 50 warnings and errors.
##
## What never goes in: the player's name, username, player ID, avatar, wallet, level, save
## contents, or any path further into the device than the name of the game's own folder. The
## report is built without reading the profile at all, and every line is passed through
## `scrub()` so a path that reached the log by accident still cannot reach the file.
##
## It writes to `user://diagnostics/`, inside the game's own folder, because no file dialog has
## been verified on any target platform. Choosing another folder is PLANNED and documented as
## UNVERIFIED in `docs/WALKTHROUGH.md`; the screen also offers the whole text for copying, so
## the report is never trapped in a folder the player cannot open.

const LOG_FOLDER := "user://diagnostics"
const FILE_PREFIX := "world-dominion-diagnostics-"


## The key/value rows the screen shows and the export repeats, in display order.
static func context() -> Array[Array]:
	var engine := Engine.get_version_info()
	var version := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var manifest := DataLoader.load_dictionary("manifest.json")
	var source: Dictionary = manifest.get("source", {})
	var data_version := str(source.get("version", ""))
	if data_version.is_empty():
		data_version = "not recorded"
	elif not str(manifest.get("generated", "")).is_empty():
		data_version = "%s (generated %s)" % [data_version, str(manifest.get("generated"))]
	var window := _window_size()
	var scale_percent := roundi(Settings.get_ui_scale() * 100.0)
	return [
		["Version", "v%s" % version],
		["Data version", data_version],
		["Engine", "Godot %s" % str(engine.get("string", ""))],
		["Platform", PlatformInfo.describe()],
		["Renderer", PlatformInfo.rendering_driver()],
		["Screen", "%d × %d px at %d%% interface scale" % [int(window.x), int(window.y),
				scale_percent]],
		["Frame-rate cap", _fps_cap_label()],
	]


static func _window_size() -> Vector2:
	var root := Engine.get_main_loop() as SceneTree
	if root != null and root.root != null:
		return Vector2(root.root.size)
	return DisplayServer.window_get_size()


static func _fps_cap_label() -> String:
	var cap := PerformanceOptions.fps_cap_value()
	if cap <= 0:
		return "Unlimited"
	return "%d frames per second" % cap


## The report as plain text. Deterministic given the same state: no timestamps, no hostnames.
static func build() -> String:
	var lines := PackedStringArray()
	lines.append("WORLD DOMINION — diagnostics report")
	lines.append("")
	lines.append("This file describes the build, the device and the game's own recent warnings.")
	lines.append("It contains no player name, player ID, avatar, wallet or save contents, and")
	lines.append("no folder path beyond the name of the game's own folder. Nothing was sent")
	lines.append("anywhere to produce it.")
	lines.append("")
	lines.append("BUILD")
	for row: Array in context():
		lines.append("%s: %s" % [str(row[0]), str(row[1])])
	lines.append("")
	var entries := DiagnosticsLog.entries()
	lines.append("LOG — %d of at most %d lines, oldest first" % [entries.size(),
			DiagnosticsLog.LIMIT])
	if entries.is_empty():
		lines.append("(the game has not reported a warning or an error this session)")
	else:
		for entry: Dictionary in entries:
			lines.append("%s  %s" % [str(entry["level"]), str(entry["text"])])
	lines.append("")
	lines.append("Note: this is the game's own log, not the engine's console output. Godot 4.6")
	lines.append("does not expose its log stream to a script, so engine-level warnings are not")
	lines.append("included. That is a known limitation, not an omission.")
	return scrub("\n".join(lines)) + "\n"


## Removes anything that looks like a path, keeping only the last component. A log line is
## never worth a folder name from someone's device.
static func scrub(text: String) -> String:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		var words := line.split(" ")
		var kept := PackedStringArray()
		for word: String in words:
			if word.contains("/") or word.contains("\\"):
				kept.append(word.replace("\\", "/").get_file())
			else:
				kept.append(word)
		out.append(" ".join(kept))
	return "\n".join(out)


## Writes the report next to the game's own files. Returns {ok, path, file_name, text, error}.
static func write_to_disk() -> Dictionary:
	var text := build()
	var result := {"ok": false, "path": "", "file_name": "", "text": text, "error": ""}
	var absolute := ProjectSettings.globalize_path(LOG_FOLDER)
	var made := DirAccess.make_dir_recursive_absolute(absolute)
	if made != OK and not DirAccess.dir_exists_absolute(absolute):
		result["error"] = "the folder could not be created"
		DiagnosticsLog.error("Diagnostics export failed: the folder could not be created.")
		return result
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "")
	var file_name := "%s%s.txt" % [FILE_PREFIX, stamp]
	var path := LOG_FOLDER.path_join(file_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		result["error"] = "the file could not be opened for writing"
		DiagnosticsLog.error("Diagnostics export failed: the file could not be opened.")
		return result
	file.store_string(text)
	file.close()
	result["ok"] = true
	result["path"] = path
	result["file_name"] = file_name
	return result


## True where the platform provides a clipboard. The button is disabled (and the reason shown)
## where it does not, rather than silently doing nothing.
static func clipboard_available() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)


static func copy_to_clipboard() -> bool:
	if not clipboard_available():
		return false
	DisplayServer.clipboard_set(build())
	return true
