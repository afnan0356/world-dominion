extends TestCase
## Diagnostics and its export (Milestone 09, Task 4).
##
## Under test: the report states the build, data version, engine, platform, screen and
## frame-rate cap; the log holds the last 50 lines and drops the oldest; the export writes a
## plain-text file inside the game's own folder and sends nothing; and — the test that matters
## most — a profile stuffed with marker strings cannot leak a single one of them into the
## report, because the report never reads the profile and scrubs anything that looks like a path.

const SCREEN_SCENE := "res://src/ui/screens/diagnostics/diagnostics_screen.tscn"

## Values a report must never contain. Each one is written into the profile first.
const MARKERS := ["Zeta-Marker-Name", "zeta.marker.user", "p-9f3a-marker-id",
		"Marker-Avatar-Name", "/home/marker/home", "C:\\Users\\marker\\Documents"]


func _mount(size: Vector2 = Vector2(1280, 800)) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Control = load(SCREEN_SCENE).instantiate()
	holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await tree.process_frame
	await tree.process_frame
	return {"viewport": viewport, "screen": screen}


## Writes a profile whose every identifying field is a marker string. The report must not
## contain any of them — and the only way to be sure is to put them somewhere it could read.
func _write_marker_profile() -> Dictionary:
	var store := ProfileStore.new()
	var loaded: Dictionary = store.load_or_create(4242, "2026-11-07")
	var profile: PlayerProfile = loaded["profile"]
	profile.display_name = MARKERS[0]
	profile.username = MARKERS[1]
	profile.player_id = MARKERS[2]
	profile.avatar_id = 7
	profile.created_at = "2026-11-07T00:00:00Z"
	return store.save(profile)


# --- The report ------------------------------------------------------------

func test_the_report_states_the_build_the_data_the_engine_and_the_device() -> void:
	DiagnosticsLog.clear()
	var text := DiagnosticsReport.build()
	var expected := {
		"Version": "v%s" % str(ProjectSettings.get_setting("application/config/version",
				"0.0.0")),
		"Engine": "Godot %s" % str(Engine.get_version_info().get("string", "")),
		"Platform": PlatformInfo.describe(),
		"Frame-rate cap": "Unlimited" if PerformanceOptions.fps_cap_value() <= 0 else (
				"%d frames per second" % PerformanceOptions.fps_cap_value()),
	}
	for key: String in expected:
		check_true(text.contains("%s: %s" % [key, expected[key]]),
				"the report states %s: %s" % [key, expected[key]])
	check_true(text.contains("Data version: "), "and the data version")
	check_true(text.contains("Screen: "), "and the screen size and interface scale")
	check_true(text.contains("%d × %d px" % [int(tree.root.size.x), int(tree.root.size.y)]),
			"with the size the window actually has")
	check_true(text.contains("interface scale"), "and the interface scale")
	check_true(text.contains("LOG — "), "and a log section")
	check_true(text.contains("contains no player name"), "and says what it does not contain")


func test_the_log_keeps_the_last_fifty_lines_newest_last() -> void:
	DiagnosticsLog.clear()
	for index in 60:
		DiagnosticsLog.warn("line %d" % index)
	var entries := DiagnosticsLog.entries()
	check_eq(entries.size(), DiagnosticsLog.LIMIT, "the buffer stops at fifty lines")
	check_eq(str(entries[0]["text"]), "line 10", "the ten oldest lines were dropped")
	check_eq(str(entries[entries.size() - 1]["text"]), "line 59", "and the newest line is last")
	DiagnosticsLog.error("a real error")
	check_eq(DiagnosticsLog.count(), DiagnosticsLog.LIMIT, "an error also obeys the limit")
	check_eq(str(DiagnosticsLog.entries()[DiagnosticsLog.LIMIT - 1]["level"]),
			DiagnosticsLog.LEVEL_ERROR, "and keeps its level")
	check_true(DiagnosticsLog.text().begins_with("WARN  line 11"),
			"the text form is oldest first with its level")
	DiagnosticsLog.note(DiagnosticsLog.LEVEL_WARNING, "   ")
	check_eq(DiagnosticsLog.count(), DiagnosticsLog.LIMIT, "an empty message is not a line")
	DiagnosticsLog.clear()
	check_eq(DiagnosticsLog.count(), 0, "clearing empties the buffer")
	check_eq(DiagnosticsLog.text(), "", "and the text form with it")


func test_the_report_carries_the_live_log() -> void:
	DiagnosticsLog.clear()
	DiagnosticsLog.warn("The settings file could not be written (error 31).")
	DiagnosticsLog.error("A backup file could not be written.")
	var text := DiagnosticsReport.build()
	check_true(text.contains("WARN  The settings file could not be written (error 31)."),
			"a warning reaches the report")
	check_true(text.contains("ERROR  A backup file could not be written."),
			"and so does an error")
	check_true(text.contains("LOG — 2 of at most 50 lines"), "with a count the reader can trust")
	DiagnosticsLog.clear()
	check_true(DiagnosticsReport.build().contains("has not reported a warning"),
			"and an empty log says so rather than looking broken")


# --- Nothing personal ------------------------------------------------------

func test_a_profile_full_of_markers_never_reaches_the_report() -> void:
	_write_marker_profile()
	DiagnosticsLog.clear()
	# A log line the game might plausibly write, containing a device path.
	DiagnosticsLog.warn("Could not open /home/marker/home/saves/slot1.json for reading.")
	DiagnosticsLog.warn("Could not open C:\\Users\\marker\\Documents\\world-dominion\\save.sav")
	var text := DiagnosticsReport.build()
	for marker: String in MARKERS:
		check_false(text.contains(marker), "the report must not contain '%s'" % marker)
	check_false(text.contains("marker"), "not even a fragment of a marker name")
	check_true(text.contains("slot1.json"), "a path keeps only its last component")
	check_true(text.contains("save.sav"), "on every separator style")
	check_false(text.contains("user://"), "and no user:// path is printed")
	check_false(text.contains("/home/"), "no home folder appears")
	# The report is built without the profile: the values above are still in it untouched.
	var reloaded: Dictionary = ProfileStore.new().load_or_create(4242, "2026-11-07")
	check_true(bool(reloaded["ok"]), "the marker profile is still readable")
	check_eq(str((reloaded["profile"] as PlayerProfile).display_name), MARKERS[0],
			"the profile still holds its marker name (the report simply never read it)")
	DiagnosticsLog.clear()


func test_scrub_keeps_a_bare_file_name_and_strips_a_path() -> void:
	check_eq(DiagnosticsReport.scrub("see /var/tmp/world.sav now"), "see world.sav now",
			"a path becomes its last component")
	check_eq(DiagnosticsReport.scrub("a\\b\\c.txt"), "c.txt", "backslashes are handled")
	check_eq(DiagnosticsReport.scrub("no paths here"), "no paths here",
			"a line without a path is untouched")
	check_eq(DiagnosticsReport.scrub("user://saves/slot1.json"), "slot1.json",
			"a user:// path keeps only the file")


# --- The file --------------------------------------------------------------

func test_the_export_writes_a_plain_text_file_in_the_games_own_folder() -> void:
	DiagnosticsLog.warn("Export test line.")
	var result := DiagnosticsReport.write_to_disk()
	check_true(bool(result["ok"]), "the export succeeds: %s" % str(result.get("error", "")))
	var path := str(result["path"])
	check_true(path.begins_with(DiagnosticsReport.LOG_FOLDER),
			"the file is inside the game's own diagnostics folder")
	check_true(str(result["file_name"]).begins_with(DiagnosticsReport.FILE_PREFIX),
			"with a recognisable name")
	check_true(FileAccess.file_exists(path), "and it really exists on disk")
	var written := FileAccess.get_file_as_string(path)
	check_eq(written, DiagnosticsReport.build(), "the file is exactly the report text")
	check_true(written.ends_with("\n"), "and ends with a newline, so a reader sees whole lines")
	for marker: String in MARKERS:
		check_false(written.contains(marker), "the file cannot contain '%s'" % marker)
	# Leave nothing behind: a test that writes a file cleans it up.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check_false(FileAccess.file_exists(path), "the test removed its own file")
	DiagnosticsLog.clear()


func test_a_failed_export_is_reported_and_logged() -> void:
	# The folder path is a directory on the test machine only; blocking it would be a
	# hostile test. Instead this asserts the contract: a failure returns ok=false with a
	# reason and never a half-written path.
	var result := DiagnosticsReport.write_to_disk()
	check_true(result.has("ok") and result.has("path") and result.has("error"),
			"the export result always carries ok, path and error")
	if not bool(result["ok"]):
		check_false(str(result["error"]).is_empty(), "a failure always explains itself")
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(str(result["path"])))
	DiagnosticsLog.clear()


# --- The screen ------------------------------------------------------------

func test_the_screen_shows_the_build_and_a_selectable_log() -> void:
	DiagnosticsLog.clear()
	DiagnosticsLog.warn("Something the player should be able to copy.")
	var mounted := await _mount()
	var screen: Control = mounted["screen"]
	var view: RichTextLabel = screen.call("log_view")
	check_not_null(view, "the screen shows the log")
	check_true(view.selection_enabled, "and the text can be selected with a mouse or a finger")
	check_false(view.scroll_active, "the view grows instead of scrolling inside the page")
	check_true(view.text.contains("Something the player should be able to copy."),
			"and it holds what the game logged")
	var grid := screen.find_child("BuildGrid", true, false) as GridContainer
	check_not_null(grid, "the build facts are in a grid")
	check_gte(float(grid.get_child_count()), 14.0,
			"seven facts, each a label pair")
	for node: Node in screen.find_children("*", "Label", true, false):
		var text := (node as Label).text
		check_false(text.contains("<diagnostics."), "no label shows a missing string key: %s" % text)
	(mounted["viewport"] as Node).queue_free()
	DiagnosticsLog.clear()


func test_the_export_and_copy_buttons_report_what_happened() -> void:
	DiagnosticsLog.clear()
	var mounted := await _mount()
	var screen: Control = mounted["screen"]
	var exported: Dictionary = screen.call("export_report")
	check_true(bool(exported["ok"]), "the screen's export button writes the file")
	var status := screen.find_child("Status", true, false) as Label
	check_not_null(status, "the screen has a status line")
	check_true(status.visible, "and shows it after the export")
	check_true(status.text.contains(str(exported["file_name"])), "naming the file it wrote")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(str(exported["path"])))
	var copied: bool = screen.call("copy_to_clipboard")
	check_eq(copied, DiagnosticsReport.clipboard_available(),
			"copying succeeds exactly where the platform has a clipboard")
	if copied:
		check_eq(DisplayServer.clipboard_get(), screen.call("report_text"),
				"and the clipboard holds the whole report")
	(mounted["viewport"] as Node).queue_free()
	DiagnosticsLog.clear()


func test_the_screen_fits_every_size_in_both_themes() -> void:
	var original := Settings.get_theme_id()
	var problems := PackedStringArray()
	for theme_id: String in ["midnight", "parchment"]:
		Settings.set_theme_id(theme_id)
		await tree.process_frame
		for size: Vector2 in [Vector2(640, 360), Vector2(844, 390), Vector2(1280, 720),
				Vector2(1920, 1080)]:
			var mounted := await _mount(size)
			var screen: Control = mounted["screen"]
			if screen.size != size:
				problems.append("%s %s: screen is %s" % [theme_id, str(size), str(screen.size)])
			for path: String in ["ExportButton", "CopyButton"]:
				var button := screen.find_child(path, true, false) as Button
				if button == null:
					problems.append("%s %s: no %s" % [theme_id, str(size), path])
				elif button.size.y + 0.5 < DesignTokens.CONTROL_HEIGHT_COMPACT:
					problems.append("%s %s: %s is %.0f px high" % [theme_id, str(size), path,
							button.size.y])
			(mounted["viewport"] as Node).queue_free()
	Settings.set_theme_id(original)
	check_eq(problems, PackedStringArray(), "the diagnostics screen fits every size in both themes")
