extends TestCase
## The country picker (Milestone 08, Task 3): committed groups, an A–Z list, an A–Z index, a
## search that matches names and both codes, and a flag strip that stays in step with the map.

const SETUP := "res://src/ui/screens/campaign_setup.tscn"
const SIZES := {
	"640x360": Vector2(640, 360),
	"1280x720": Vector2(1280, 720),
	"1920x1080": Vector2(1920, 1080),
}


func _registry() -> CountryRegistry:
	return WorldAtlas.load_default().registry


func _picker(size: Vector2 = Vector2(380, 640)) -> CountryPickerPanel:
	var holder := Control.new()
	holder.size = size
	holder.custom_minimum_size = size
	holder.theme = ThemeManager.current_theme()
	host.add_child(holder)
	var panel := CountryPickerPanel.new()
	holder.add_child(panel)
	panel.setup(_registry())
	return panel


func _mount(size: Vector2) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Control = load(SETUP).instantiate()
	holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await tree.process_frame
	await tree.process_frame
	return {"viewport": viewport, "screen": screen, "holder": holder}


func test_groups_come_from_the_committed_data() -> void:
	var panel := _picker()
	check_eq(panel.group_ids().size(), 17, "there are seventeen committed groups")
	var known := true
	for group_id: String in panel.group_ids():
		if panel.group_label(group_id).is_empty():
			known = false
	check_true(known, "every group has a label from the data")
	var data: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/world/picker_regions.json"))
	var records: Dictionary = data.get("records", {})
	var registry := _registry()
	var wrong: Array = []
	for country_id: String in registry.ids():
		if not records.has(country_id):
			wrong.append(country_id)
	check_eq(wrong.size(), 0, "every record is in a group: %s" % str(wrong.slice(0, 4)))
	check_eq(records.size(), registry.count(), "and no group names a record that is gone")
	panel.get_parent().queue_free()


func test_the_list_shows_one_letter_of_one_group() -> void:
	var panel := _picker()
	panel.select_group("south_asia")
	panel.select_letter("B")
	var ids := panel.visible_ids()
	check_gt(float(ids.size()), 0.0, "the letter B has records in South Asia")
	var wrong := ""
	for country_id: String in ids:
		var record := _registry().get_country(country_id)
		if record.name.substr(0, 1).to_upper() != "B":
			wrong = "%s starts with %s" % [country_id, record.name.substr(0, 1)]
		if panel.group_of(country_id) != "south_asia":
			wrong = "%s is not in the group" % country_id
	check_eq(wrong, "", "only that group's B records are listed")
	panel.select_letter("C")
	check_eq(panel.current_letter(), "C", "choosing a letter moves the list")
	panel.get_parent().queue_free()


func test_search_matches_names_and_both_codes() -> void:
	var panel := _picker()
	panel.set_query("bangladesh")
	check_true(panel.visible_ids().has("BGD"), "a name finds the record")
	panel.set_query("BD")
	check_true(panel.visible_ids().has("BGD"),
			"alpha-2 finds it (searching a group of one letter is not required)")
	panel.set_query("BGD")
	check_true(panel.visible_ids().has("BGD"), "alpha-3 finds it")
	panel.set_query("zzzz")
	check_eq(panel.visible_ids().size(), 0, "and nonsense finds nothing")
	panel.get_parent().queue_free()


func test_a_record_without_a_flag_shows_its_code_in_the_list() -> void:
	var panel := _picker()
	panel.set_query("Somaliland")
	var ids := panel.visible_ids()
	check_true(ids.has("SOL"), "the search finds the flagless record")
	var row: Button = panel.find_child("Row_SOL", true, false) as Button
	check_not_null(row, "and it has a row")
	if row != null:
		var tile: FlagTile = row.find_child("Flag", true, false) as FlagTile
		check_not_null(tile, "with a flag tile")
		if tile != null:
			check_false(tile.has_texture(), "which draws no flag")
			check_eq(tile.badge_text(), "SOL", "and shows its own code instead")
	panel.get_parent().queue_free()


func test_the_strip_marks_its_selection_without_colour() -> void:
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	host.add_child(holder)
	var strip := FlagStrip.new()
	holder.add_child(strip)
	var members: Array = []
	for country_id: String in ["BGD", "IND", "NPL", "LKA"]:
		members.append(country_id)
	strip.show_group(_registry(), "south_asia", members)
	check_eq(strip.item_count(), 4, "the strip holds the group's records")
	check_true(strip.set_selected("BGD"), "a member can be selected")
	var button: Button = strip.find_child("Flag_BGD", true, false) as Button
	check_not_null(button, "and its tile exists")
	if button != null:
		var mark: Label = button.find_child("Mark", true, false) as Label
		check_eq(mark.text, "✓", "the selection carries a tick")
		check_true(button.tooltip_text.contains("Bangladesh"), "and names the country")
		check_eq(button.get_theme_constant("outline_size"), 2, "and a heavier border")
	check_false(strip.set_selected("FRA"), "a record outside the group cannot be selected")
	check_eq(strip.selected_id(), "BGD", "so the selection is unchanged")
	holder.queue_free()


func test_the_map_the_list_and_the_strip_stay_in_step() -> void:
	var mounted := await _mount(SIZES["1280x720"])
	var screen: Control = mounted["screen"]
	var panel: CountryPickerPanel = screen.find_child("Picker", true, false) as CountryPickerPanel
	var strip: FlagStrip = screen.find_child("FlagStrip", true, false) as FlagStrip
	check_not_null(panel, "the screen carries the picker")
	check_not_null(strip, "and the flag strip")
	if panel == null or strip == null:
		(mounted["viewport"] as Node).queue_free()
		return
	screen.call("select_country", "BGD", false)
	check_eq(screen.call("selected_country_id"), "BGD", "the map has Bangladesh")
	check_eq(panel.selected_id(), "BGD", "the list marks it")
	check_eq(strip.selected_id(), "BGD", "the strip marks it")
	check_eq(panel.current_group(), "south_asia", "and the group followed the record")
	panel.choose("NPL")
	check_eq(screen.call("selected_country_id"), "NPL", "choosing in the list moves the map")
	check_eq(strip.selected_id(), "NPL", "and the strip")
	strip.find_child("Flag_IND", true, false).pressed.emit()
	check_eq(screen.call("selected_country_id"), "IND", "choosing a flag moves the map")
	check_eq(panel.selected_id(), "IND", "and the list")
	(mounted["viewport"] as Node).queue_free()


func test_the_picker_fits_every_size_in_both_themes() -> void:
	var original := Settings.get_theme_id()
	var worst := ""
	for theme_id: String in ["midnight", "parchment"]:
		Settings.set_theme_id(theme_id)
		await tree.process_frame
		for label: String in SIZES:
			var mounted := await _mount(SIZES[label])
			var screen: Control = mounted["screen"]
			var panel: CountryPickerPanel = screen.find_child("Picker", true, false) as CountryPickerPanel
			if panel != null:
				for button: Node in _buttons(panel):
					var control := button as Control
					if control.is_visible_in_tree() and control.size.y + 0.5 \
							< DesignTokens.CONTROL_HEIGHT and worst.is_empty():
						worst = "%s/%s: %s is %s high" % [theme_id, label, control.name,
								str(control.size.y)]
				var letter: Button = panel.find_child("Letter_A", true, false) as Button
				if letter != null:
					if letter.custom_minimum_size != Vector2(DesignTokens.CONTROL_HEIGHT,
							DesignTokens.CONTROL_HEIGHT) and worst.is_empty():
						worst = "%s: a letter button is not a square control" % theme_id
					if letter.focus_mode != Control.FOCUS_ALL and worst.is_empty():
						worst = "%s: a letter button cannot take focus" % theme_id
			(mounted["viewport"] as Node).queue_free()
	check_eq(worst, "", "the picker is usable at every size in both themes")
	Settings.set_theme_id(original)


func test_switching_groups_does_not_accumulate_rows() -> void:
	var panel := _picker()
	var groups := panel.group_ids()
	var worst := ""
	for index in groups.size():
		panel.select_group(groups[index])
		await tree.process_frame
		var rows := panel.visible_ids().size()
		var children := _button_count(panel.find_child("List", true, false))
		if rows != children and worst.is_empty():
			worst = "%s left %d rows for %d records" % [groups[index], children, rows]
	check_eq(worst, "", "each group shows exactly its own rows")
	panel.get_parent().queue_free()


func _buttons(node: Node) -> Array:
	var out: Array = []
	for child: Node in node.get_children():
		if child is Button:
			out.append(child)
		out.append_array(_buttons(child))
	return out


func _button_count(node: Node) -> int:
	return 0 if node == null else _buttons(node).size()
