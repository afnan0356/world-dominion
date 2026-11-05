extends TestCase
## The M04 completion surfaces: grouped dossier, Load Game states, the shortcut sheet,
## About the data, the developer inspector, and the keyboard/touch promises that go
## with them.
##
## Two of these tests are deliberately generic — focus reachability and node counting
## run over every screen a player can reach from the main menu — because the promise
## being checked ("a keyboard can reach everything", "leaving a screen frees it") is
## about the screens, not about one of them.

const SCREENS := {
	"main_menu": "res://src/ui/screens/main_menu.tscn",
	"load_game": "res://src/ui/screens/load_game_screen.tscn",
	"settings": "res://src/ui/screens/settings_screen.tscn",
	"about": "res://src/ui/screens/about_screen.tscn",
	"about_data": "res://src/ui/screens/about_data_screen.tscn",
	"shortcuts": "res://src/ui/screens/shortcuts_screen.tscn",
}
const LAYOUTS := {
	"desktop 1280x720": Vector2(1280, 720),
	"tablet 1024x768": Vector2(1024, 768),
	"phone portrait 390x844": Vector2(390, 844),
}

var _atlas: WorldAtlas


func _atlas_or_load() -> WorldAtlas:
	if _atlas == null:
		_atlas = WorldAtlas.load_default()
	return _atlas


func _mount(scene_path: String, view_size: Vector2 = Vector2(1280, 720)) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(view_size)
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
	return {"viewport": viewport, "holder": holder, "screen": screen}


func _unmount(mounted: Dictionary) -> void:
	(mounted["viewport"] as Node).queue_free()
	await tree.process_frame
	await tree.process_frame


# --- The dossier -----------------------------------------------------------

func test_dossier_has_the_five_groups_in_order() -> void:
	var record := _atlas_or_load().registry.get_country("BGD")
	check_not_null(record, "Bangladesh is in the dataset")
	var dossier := CountryDossier.build(record, {"vertices": 120})
	var ids := PackedStringArray()
	var titles := PackedStringArray()
	for section: CountryDossier.Section in dossier.sections:
		ids.append(section.id)
		titles.append(section.title)
	check_eq(ids, PackedStringArray(["overview", "geography", "administration",
			"sources", "completeness"]), "the five recorded groups are present, in order")
	check_eq(titles, PackedStringArray(["Identity", "Geography", "Administrative",
			"Data sources", "Data completeness"]), "their headings are the plain words")
	for section: CountryDossier.Section in dossier.sections:
		check_gt(float(section.fields.size()), 0.0, "%s has fields" % section.id)
		check_false(section.planned, "%s is recorded, not planned" % section.id)


func test_the_completeness_group_reports_gaps_without_scoring() -> void:
	var dossier := CountryDossier.build(_atlas_or_load().registry.get_country("BGD"))
	var section: CountryDossier.Section = null
	for candidate: CountryDossier.Section in dossier.sections:
		if candidate.id == CountryDossier.COMPLETENESS:
			section = candidate
	check_not_null(section, "the completeness group exists")
	check_true(section.note.contains("not a score"),
			"the note says it is a list of facts, not a score")
	check_false(section.note.contains("%"), "and it calculates no percentage")
	for field: CountryDossier.Field in section.fields:
		check_false(field.value.contains("http"),
				"%s does not link anywhere" % field.label)


func test_no_dossier_field_links_to_a_missing_document() -> void:
	var dossier := CountryDossier.build(_atlas_or_load().registry.get_country("JPN"))
	var linked := 0
	for section: CountryDossier.Section in dossier.sections:
		for field: CountryDossier.Field in section.fields:
			if field.value.contains("://") or field.value.begins_with("res://"):
				linked += 1
	check_eq(linked, 0, "nothing in the dossier points at a file or a URL")


# --- The screens -----------------------------------------------------------

func test_shortcut_sheet_matches_the_shortcut_table() -> void:
	var mounted := await _mount(SCREENS["shortcuts"])
	var screen: Control = mounted["screen"]
	check_eq(int(screen.call("row_count")), Shortcuts.ENTRIES.size(),
			"the sheet shows one row per shortcut")
	var seen := {}
	for entry: Array in Shortcuts.ENTRIES:
		check_eq(entry.size(), 3, "%s has keys, action and scope" % str(entry[0]))
		check_gt(float(str(entry[0]).length()), 0.0, "a key is named")
		check_gt(float(str(entry[1]).length()), 5.0, "the action is described")
		check_false(seen.has(str(entry[0])), "%s is listed once" % str(entry[0]))
		seen[str(entry[0])] = true
	check_true(seen.has("Esc"), "going back is on the sheet")
	await _unmount(mounted)


func test_about_the_data_reports_the_shipped_manifest() -> void:
	var mounted := await _mount(SCREENS["about_data"])
	var screen: Control = mounted["screen"]
	var facts: Dictionary = screen.call("facts")
	var manifest := _atlas_or_load().manifest
	var source: Dictionary = manifest.get("source", {})
	check_eq(str(facts["dataset"]), str(source.get("dataset", "")),
			"the dataset name comes from the manifest")
	check_eq(str(facts["version"]), str(source.get("version", "")),
			"so does the version")
	check_eq(str(facts["licence"]), str(source.get("licence", "")),
			"and the licence")
	check_true(str(facts["licence"]).length() > 0, "the licence is stated")
	check_eq(int(facts["countries"]), 242, "the record count matches the shipped pack")
	check_gt(float(str(facts["commit"]).length()), 0.0, "the source commit is shown")
	await _unmount(mounted)


func test_about_the_data_takes_no_position_on_any_country() -> void:
	var constants: Dictionary = (load("res://src/ui/screens/about_data_screen.gd")
			as GDScript).get_script_constant_map()
	var note := str(constants.get("DISPUTED_NOTE", ""))
	check_true(note.contains("no position"), "the note says it takes no position")
	var named := 0
	for record: CountryRecord in _atlas_or_load().registry.all():
		if note.contains(record.name):
			named += 1
	check_eq(named, 0, "the neutral note names no country")


func test_map_inspector_starts_hidden_and_reports_loaded_facts() -> void:
	var inspector := MapInspector.new()
	host.add_child(inspector)
	check_false(inspector.visible, "the inspector is off by default")
	inspector.set_entry(_atlas_or_load(), "BGD")
	check_false(inspector.visible, "filling it does not open it")
	check_gte(float(inspector.row_count()), 8.0,
			"it shows a heading plus stable id, name, type, polygons, vertices, shape")
	var text := _collect_text(inspector)
	check_true(text.contains("BGD"), "the stable ID is on screen")
	check_true(text.to_lower().contains("sovereignt") or text.contains("Country"),
			"the dataset's own source type is shown")
	inspector.set_entry(null, "")
	check_true(_collect_text(inspector).contains("No atlas loaded"),
			"an absent atlas reads as a reason, not as zeros")
	inspector.queue_free()


func _collect_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += (node as Label).text + "\n"
	for child: Node in node.get_children():
		out += _collect_text(child)
	return out


# --- Keyboard and touch ----------------------------------------------------

func _focusable_controls(screen: Control) -> Array[Control]:
	var out: Array[Control] = []
	var found := screen.find_children("*", "Control", true, false)
	for node: Node in found:
		var control := node as Control
		if control == null or control.focus_mode == Control.FOCUS_NONE:
			continue
		if not control.is_visible_in_tree():
			continue
		out.append(control)
	return out


func test_a_keyboard_can_reach_every_control_on_every_screen() -> void:
	for layout: String in LAYOUTS:
		for screen_name: String in SCREENS:
			var mounted := await _mount(SCREENS[screen_name], LAYOUTS[layout])
			var screen: Control = mounted["screen"]
			var controls := _focusable_controls(screen)
			check_gt(float(controls.size()), 0.0,
					"%s at %s has something to focus" % [screen_name, layout])
			var reachable := {}
			var current: Control = controls[0]
			reachable[current] = true
			# Tab through the screen the way a keyboard does, and stop when the chain
			# comes back to the start or runs away (which would be a loop bug).
			var steps := 0
			while steps < controls.size() * 4 + 8:
				var next: Control = current.find_next_valid_focus()
				if next == null or reachable.has(next):
					break
				reachable[next] = true
				current = next
				steps += 1
			check_eq(reachable.size(), controls.size(),
					"%s at %s: Tab reaches all %d focusable controls" % [
							screen_name, layout, controls.size()])
			await _unmount(mounted)


func test_new_controls_meet_the_touch_minimum() -> void:
	for layout: String in LAYOUTS:
		var mounted := await _mount(SCREENS["load_game"], LAYOUTS[layout])
		var screen: Control = mounted["screen"]
		var checked := 0
		for node: Node in screen.find_children("*", "Button", true, false):
			var button := node as Button
			if button == null or not button.is_visible_in_tree():
				continue
			var height := maxf(button.size.y, button.custom_minimum_size.y)
			check_gte(height, float(DesignTokens.TOUCH_TARGET_MIN),
					"button '%s' at %s is at least %d px tall" % [
							button.text, layout, DesignTokens.TOUCH_TARGET_MIN])
			checked += 1
		check_gt(float(checked), 0.0, "the Load Game screen has controls to measure")
		await _unmount(mounted)


func test_entering_and_leaving_a_screen_frees_it() -> void:
	for screen_name: String in ["main_menu", "load_game", "shortcuts", "about_data"]:
		var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		for _loop in 2:
			var mounted := await _mount(SCREENS[screen_name])
			await _unmount(mounted)
		var after := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		check_lte(float(after - before), 24.0,
				"%s: entering and leaving twice leaves no growing pile of nodes (%d -> %d)" % [
						screen_name, before, after])


# --- Colour ----------------------------------------------------------------

func test_the_new_colour_pairs_meet_contrast_in_both_themes() -> void:
	## The pairs the M04 work introduced, with the reason each one exists.
	var pairs := [
		["text_secondary on a panel", Palette.KEY_TEXT_SECONDARY, Palette.KEY_BG_PANEL,
				4.5],
		["mono text on a surface", Palette.KEY_TEXT_TERTIARY, Palette.KEY_BG_SURFACE, 4.5],
		["body text on a card", Palette.KEY_TEXT_PRIMARY, Palette.KEY_BG_SURFACE, 4.5],
		["chip text on hover", Palette.KEY_TEXT_SECONDARY, Palette.KEY_BG_HOVER, 4.5],
		["mono text on a panel", Palette.KEY_TEXT_TERTIARY, Palette.KEY_BG_PANEL, 4.5],
	]
	for palette_id: String in Palette.ids():
		var colors := Palette.colors(palette_id)
		for pair: Array in pairs:
			var ratio := contrast_ratio(colors[str(pair[1])], colors[str(pair[2])])
			check_gte(ratio, float(pair[3]), "%s: %s is %.2f:1, needs %.1f:1" % [
					palette_id, str(pair[0]), ratio, float(pair[3])])
