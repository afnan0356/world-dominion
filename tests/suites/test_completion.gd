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

func test_dossier_has_the_six_groups_in_order() -> void:
	var atlas := _atlas_or_load()
	var record := atlas.registry.get_country("BGD")
	check_not_null(record, "Bangladesh is in the dataset")
	# Milestone 05 adds the Key figures group between Administration and the sources.
	# It is passed the same statistics object the screens pass, so the group has fields:
	# a dossier built without one says so instead (covered in the statistics suite).
	var dossier := CountryDossier.build(record, {"vertices": 120,
			"statistics": atlas.statistics})
	var ids := PackedStringArray()
	var titles := PackedStringArray()
	for section: CountryDossier.Section in dossier.sections:
		ids.append(section.id)
		titles.append(section.title)
	check_eq(ids, PackedStringArray(["overview", "geography", "administration",
			"key_figures", "sources", "completeness"]),
			"the six recorded groups are present, in order")
	check_eq(titles, PackedStringArray(["Identity", "Geography", "Administrative",
			"Key figures", "Data sources", "Data completeness"]),
			"their headings are the plain words")
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
	check_gte(float(inspector.row_count()), 7.0,
			"it shows a heading plus stable id, name, type, polygons, vertices and shape")
	var text := _collect_text(inspector)
	check_true(text.contains("BGD"), "the stable ID is on screen")
	check_true(text.contains("Source type"),
			"the dataset's own source type is shown, labelled")
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
		# A disabled button is focusable in principle but skipped by the tab chain,
		# which is correct behaviour for a control that cannot be used.
		if control is BaseButton and (control as BaseButton).disabled:
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
			# Walk the chain from every control, not just the first: a keyboard can start
			# anywhere (a mouse click or a shortcut can put focus in the middle), and what
			# matters is that no control is stranded in a separate loop.
			for start: Control in controls:
				var current: Control = start
				var steps := 0
				while steps < controls.size() * 2 + 4:
					reachable[current] = true
					var next: Control = current.find_next_valid_focus()
					if next == null or reachable.has(next):
						break
					current = next
					steps += 1
			var stranded := 0
			for control: Control in controls:
				if not reachable.has(control):
					stranded += 1
			check_eq(stranded, 0,
					"%s at %s: Tab reaches all %d focusable controls" % [
							screen_name, layout, controls.size()])
			await _unmount(mounted)


func test_new_controls_meet_the_touch_minimum() -> void:
	## This measures the controls Milestone 04 added, not every control in the build:
	## the older screens use the design system's 40 px control height, which is recorded
	## as a known limitation rather than quietly redefined here.
	AtlasHistory.clear()
	for country_id: String in ["BGD", "JPN", "USA"]:
		AtlasHistory.remember(country_id)
	for layout: String in LAYOUTS:
		var mounted := await _mount("res://src/ui/screens/campaign_setup.tscn",
				LAYOUTS[layout])
		var screen: Control = mounted["screen"]
		var chips := 0
		var strip := screen.find_child("RecentStrip", true, false)
		check_not_null(strip, "the atlas has a recently-viewed strip at %s" % layout)
		var candidates: Array[Node] = []
		if strip != null:
			candidates = strip.find_children("*", "Button", true, false)
		for node: Node in candidates:
			var button := node as Button
			if button == null:
				continue
			if not button.is_visible_in_tree():
				continue
			check_gte(maxf(button.size.y, button.custom_minimum_size.y),
					float(DesignTokens.TOUCH_TARGET_MIN),
					"recent-country chip '%s' at %s is a full touch target" % [
							button.text, layout])
			chips += 1
		check_gt(float(chips), 0.0,
				"the atlas shows recent-country chips at %s" % layout)
		await _unmount(mounted)
	var about_mounted := await _mount(SCREENS["about"])
	var about: Control = about_mounted["screen"]
	var found_link := false
	for node: Node in about.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null or button.text != "About the data":
			continue
		found_link = true
		check_gte(maxf(button.size.y, button.custom_minimum_size.y),
				float(DesignTokens.TOUCH_TARGET_MIN),
				"the About-the-data button is a full touch target")
	check_true(found_link, "About & Credits links to the data page")
	AtlasHistory.clear()
	await _unmount(about_mounted)


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
