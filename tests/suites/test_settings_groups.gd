extends TestCase
## The settings overhaul (Milestone 09, Task 2).
##
## Under test: the screen is organised into eight named groups in a fixed order; the frame-rate
## cap is written into `Engine.max_fps` (a ceiling the engine really obeys, not a label); the
## quality preset writes the documented map options and turns into `custom` the moment one of them
## is changed by hand; every value persists to the settings file immediately; the cheat sheet is
## the same table the shortcut screen renders; the backup links go to the two real screens; and
## nothing on the screen is a dead switch — including "realism", which is PLANNED and therefore
## text rather than a control.

const SETTINGS_SCENE := "res://src/ui/screens/settings_screen.tscn"

const GROUP_HEADINGS: Array[String] = ["DISPLAY", "PERFORMANCE", "AUDIO", "CONTROLS",
		"BACKUP", "PRIVACY AND TERMS", "ADVANCED / DEVELOPER", "ABOUT THIS BUILD"]

var _saved: Dictionary = {}


func _remember() -> void:
	_saved = {
		"fps": PerformanceOptions.fps_limit(),
		"quality": PerformanceOptions.quality(),
		"detail": Settings.get_map_detail(),
		"labels": MapOptions.labels(),
		"capitals": MapOptions.capitals(),
		"graticule": MapOptions.graticule(),
		"borders": MapOptions.borders(),
		"reference": MapOptions.reference_lines(),
		"theme": Settings.get_theme_id(),
	}


func _restore() -> void:
	Settings.set_value(SettingsSchema.KEY_FPS_LIMIT, _saved["fps"])
	Settings.set_value(SettingsSchema.KEY_MAP_DETAIL, _saved["detail"])
	Settings.set_value(SettingsSchema.KEY_MAP_LABELS, _saved["labels"])
	Settings.set_value(SettingsSchema.KEY_MAP_CAPITALS, _saved["capitals"])
	Settings.set_value(SettingsSchema.KEY_MAP_GRATICULE, _saved["graticule"])
	Settings.set_value(SettingsSchema.KEY_MAP_BORDERS, _saved["borders"])
	Settings.set_value(SettingsSchema.KEY_MAP_REFERENCE_LINES, _saved["reference"])
	Settings.set_value(SettingsSchema.KEY_QUALITY, _saved["quality"])
	Settings.set_theme_id(_saved["theme"])
	PerformanceOptions.apply_fps_cap()


func _mount(size: Vector2 = Vector2(1280, 800)) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Control = load(SETTINGS_SCENE).instantiate()
	holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await tree.process_frame
	await tree.process_frame
	return {"viewport": viewport, "screen": screen}


func _headings(screen: Node) -> Array[String]:
	var found: Array[String] = []
	for node: Node in screen.find_children("*", "Label", true, false):
		if (node as Label).theme_type_variation == &"SectionHeading":
			found.append((node as Label).text)
	return found


# --- Structure -------------------------------------------------------------

func test_the_screen_is_eight_named_groups_in_order() -> void:
	_remember()
	var mounted := await _mount()
	var headings := _headings(mounted["screen"])
	check_eq(headings, GROUP_HEADINGS, "the eight settings groups, in the documented order")
	(mounted["viewport"] as Node).queue_free()
	_restore()


func test_every_row_has_a_real_control() -> void:
	_remember()
	var mounted := await _mount()
	var rows := 0
	for node: Node in mounted["screen"].find_children("*", "GridContainer", true, false):
		if node is SettingRow:
			rows += 1
			var title_node := node.find_child("Title", true, false) as Label
			var slot := node.find_child("Slot", true, false) as HBoxContainer
			var label_text := "" if title_node == null else title_node.text
			check_true(slot != null and slot.get_child_count() > 0,
					"setting row '%s' has a real control" % label_text)
	check_gt(float(rows), 8.0, "the eight groups contain setting rows")
	(mounted["viewport"] as Node).queue_free()
	_restore()


func test_realism_is_planned_text_not_a_switch() -> void:
	_remember()
	var mounted := await _mount()
	var mentions := 0
	var clickable := false
	for node: Node in mounted["screen"].find_children("*", "Label", true, false):
		var label := node as Label
		if label.text.to_lower().contains("realism"):
			mentions += 1
			check_true(label.text.contains("PLANNED"),
					"the realism caption says PLANNED: %s" % label.text)
	for node: Node in mounted["screen"].find_children("*", "BaseButton", true, false):
		if (node as BaseButton).text.to_lower().contains("realism"):
			clickable = true
	check_gt(float(mentions), 0.0, "the planned realism setting is mentioned once")
	check_false(clickable, "and it is not offered as a control that does nothing")
	(mounted["viewport"] as Node).queue_free()
	_restore()


# --- The frame-rate cap ----------------------------------------------------

func test_the_fps_cap_reaches_the_engine_and_persists() -> void:
	_remember()
	PerformanceOptions.set_fps_limit(SettingsSchema.FPS_30)
	check_eq(PerformanceOptions.fps_cap_value(), 30, "30 means 30")
	check_eq(Engine.max_fps, 30, "and the engine now caps at 30 frames a second")
	PerformanceOptions.set_fps_limit(SettingsSchema.FPS_60)
	check_eq(Engine.max_fps, 60, "60 means 60")
	PerformanceOptions.set_fps_limit(SettingsSchema.FPS_UNLIMITED)
	check_eq(Engine.max_fps, 0, "unlimited is the engine's own 'no cap' value")
	# Written straight to the settings file, so a restart keeps the choice.
	var stored := SettingsStore.new().load_values()
	check_eq(stored[SettingsSchema.KEY_FPS_LIMIT], SettingsSchema.FPS_UNLIMITED,
			"the cap is in the settings file")
	check_eq(SettingsSchema.sanitize(SettingsSchema.KEY_FPS_LIMIT, 45), SettingsSchema.FPS_60,
			"a hand-edited number degrades to the default, not to a new cap")
	check_eq(SettingsSchema.sanitize(SettingsSchema.KEY_FPS_LIMIT, "nonsense"),
			SettingsSchema.FPS_60, "and so does nonsense")
	_restore()


# --- Quality ---------------------------------------------------------------

func test_each_quality_preset_writes_the_documented_map_options() -> void:
	_remember()
	PerformanceOptions.apply_quality(SettingsSchema.QUALITY_LOW)
	check_eq(Settings.get_map_detail(), SettingsSchema.DETAIL_REDUCED, "low reduces map detail")
	check_eq(MapOptions.labels(), SettingsSchema.LABEL_DENSITY_SPARSE, "low shows fewer labels")
	check_false(MapOptions.capitals(), "low hides capital markers")
	check_false(MapOptions.graticule(), "low hides the graticule")
	check_false(MapOptions.reference_lines(), "low hides the reference lines")
	check_eq(PerformanceOptions.quality(), SettingsSchema.QUALITY_LOW, "and records the preset")

	PerformanceOptions.apply_quality(SettingsSchema.QUALITY_MEDIUM)
	check_eq(Settings.get_map_detail(), SettingsSchema.DETAIL_REDUCED, "medium reduces detail")
	check_eq(MapOptions.labels(), SettingsSchema.LABEL_DENSITY_FULL, "but keeps every label")
	check_true(MapOptions.capitals(), "and explicitly keeps capital markers on")
	check_false(MapOptions.graticule(), "medium drops the graticule")
	check_true(MapOptions.reference_lines(), "and keeps reference lines")

	PerformanceOptions.apply_quality(SettingsSchema.QUALITY_HIGH)
	check_eq(Settings.get_map_detail(), SettingsSchema.DETAIL_FULL, "high restores full detail")
	check_eq(MapOptions.labels(), SettingsSchema.LABEL_DENSITY_FULL, "high shows every label")
	check_true(MapOptions.capitals(), "high shows capital markers")
	check_true(MapOptions.graticule(), "high shows the graticule")
	check_true(MapOptions.reference_lines(), "high shows reference lines")
	_restore()


func test_changing_one_map_option_makes_the_preset_custom() -> void:
	_remember()
	PerformanceOptions.apply_quality(SettingsSchema.QUALITY_HIGH)
	check_eq(PerformanceOptions.quality(), SettingsSchema.QUALITY_HIGH, "starting from High")
	MapOptions.set_borders(false)
	check_eq(PerformanceOptions.quality(), SettingsSchema.QUALITY_CUSTOM,
			"switching borders off by hand makes High a lie, so it becomes Custom")
	check_false(MapOptions.borders(), "and the map option itself really changed")
	Settings.set_map_detail(SettingsSchema.DETAIL_REDUCED)
	PerformanceOptions.note_manual_map_change()
	check_eq(PerformanceOptions.quality(), SettingsSchema.QUALITY_CUSTOM,
			"a detail change from the campaign panel also becomes Custom")
	PerformanceOptions.apply_quality(SettingsSchema.QUALITY_HIGH)
	check_eq(PerformanceOptions.quality(), SettingsSchema.QUALITY_HIGH,
			"choosing a preset again clears Custom")
	_restore()


func test_custom_chosen_by_hand_changes_no_option() -> void:
	_remember()
	PerformanceOptions.apply_quality(SettingsSchema.QUALITY_MEDIUM)
	var before := MapOptions.snapshot()
	PerformanceOptions.apply_quality(SettingsSchema.QUALITY_CUSTOM)
	var after := MapOptions.snapshot()
	for key: String in ["labels", "borders", "graticule", "capitals", "reference_lines", "detail"]:
		check_eq(after[key], before[key], "Custom leaves '%s' exactly as it was" % key)
	check_eq(PerformanceOptions.quality(), SettingsSchema.QUALITY_CUSTOM, "and is recorded")
	_restore()


# --- The screen's controls -------------------------------------------------

func test_the_screen_controls_show_and_write_the_stored_values() -> void:
	_remember()
	PerformanceOptions.set_fps_limit(SettingsSchema.FPS_30)
	PerformanceOptions.apply_quality(SettingsSchema.QUALITY_LOW)
	var mounted := await _mount()
	var screen: Control = mounted["screen"]
	var fps: SegmentedControl = screen.find_child("FpsLimit", true, false) as SegmentedControl
	var quality: SegmentedControl = screen.find_child("Quality", true, false) as SegmentedControl
	check_not_null(fps, "the frame-rate cap is on the screen")
	check_not_null(quality, "and so is quality")
	check_eq(fps.get_selected_id(), SettingsSchema.FPS_30, "the cap shows the stored value")
	check_eq(quality.get_selected_id(), SettingsSchema.QUALITY_LOW, "quality shows the stored value")

	fps.option_selected.emit(SettingsSchema.FPS_UNLIMITED)
	check_eq(PerformanceOptions.fps_limit(), SettingsSchema.FPS_UNLIMITED,
			"choosing a cap stores it")
	check_eq(Engine.max_fps, 0, "and the engine obeys it before anything else happens")
	quality.option_selected.emit(SettingsSchema.QUALITY_HIGH)
	check_eq(PerformanceOptions.quality(), SettingsSchema.QUALITY_HIGH, "choosing quality stores it")
	check_eq(Settings.get_map_detail(), SettingsSchema.DETAIL_FULL, "and applies the preset")
	(mounted["viewport"] as Node).queue_free()
	_restore()


func test_the_cheat_sheet_is_the_shortcut_table() -> void:
	_remember()
	var mounted := await _mount()
	var screen: Control = mounted["screen"]
	var grid: GridContainer = screen.find_child("ShortcutCheatSheet", true, false) as GridContainer
	check_not_null(grid, "the controls group renders the cheat sheet")
	check_eq(grid.columns, 2, "as a two-column table of keys and actions")
	check_eq(grid.get_child_count(), Shortcuts.ENTRIES.size() * 2,
			"one row per shortcut in Shortcuts.ENTRIES, and no invented row")
	var emitted: Array[String] = []
	screen.navigation_requested.connect(func(screen_id: String, _params: Dictionary) -> void:
		emitted.append(screen_id))
	var open: Button = screen.find_child("OpenShortcutSheet", true, false) as Button
	check_not_null(open, "there is a way to the full sheet")
	open.pressed.emit()
	check_eq(emitted, ["shortcuts"], "which opens the shortcut screen")
	(mounted["viewport"] as Node).queue_free()
	_restore()


func test_the_backup_group_links_to_the_two_real_screens() -> void:
	_remember()
	var mounted := await _mount()
	var screen: Control = mounted["screen"]
	var emitted: Array[String] = []
	screen.navigation_requested.connect(func(screen_id: String, _params: Dictionary) -> void:
		emitted.append(screen_id))
	(screen.find_child("OpenWorlds", true, false) as Button).pressed.emit()
	(screen.find_child("OpenBackup", true, false) as Button).pressed.emit()
	check_eq(emitted, ["worlds", "backup"], "the backup group opens the worlds and backup screens")
	(mounted["viewport"] as Node).queue_free()
	_restore()


func test_the_settings_controls_fit_every_size_in_both_themes() -> void:
	_remember()
	var original_theme := Settings.get_theme_id()
	var problem := ""
	for theme_id: String in ["midnight", "parchment"]:
		Settings.set_theme_id(theme_id)
		await tree.process_frame
		for size: Vector2 in [Vector2(640, 360), Vector2(1280, 720), Vector2(1920, 1080)]:
			var mounted := await _mount(size)
			var screen: Control = mounted["screen"]
			# A 640x360 window is the documented short-window case: 40 px controls, not 48.
			var floor_height := DesignTokens.CONTROL_HEIGHT_COMPACT if size.y <= DesignTokens.HEIGHT_SHORT \
					else DesignTokens.CONTROL_HEIGHT
			# Only the form: the header's back button is chrome at its documented 40 px.
			var form := screen.find_child("Content", true, false)
			for node: Node in form.find_children("*", "BaseButton", true, false):
				var button := node as BaseButton
				if not button.visible or button.custom_minimum_size.y <= 0.0:
					continue
				if button.size.y + 0.5 < floor_height and problem.is_empty():
					problem = "%s %s: '%s' is %.1f px high" % [theme_id, str(size),
							button.name, button.size.y]
			(mounted["viewport"] as Node).queue_free()
	Settings.set_theme_id(original_theme)
	_restore()
	check_eq(problem, "", "every settings control keeps its tap target at every size")
