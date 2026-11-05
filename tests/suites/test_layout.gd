extends TestCase
## Responsive layout checks.
##
## Each screen is mounted inside an off-screen SubViewport at a set of reference
## sizes — desktop, tablet, phone landscape, a small window and phone portrait —
## and the resulting Control rects are inspected. This catches the two failure
## modes that matter for a cross-platform shell: content that overflows the
## viewport, and controls that collapse to zero size.

const MAIN_MENU := "res://src/ui/screens/main_menu.tscn"
const SETTINGS := "res://src/ui/screens/settings_screen.tscn"
const ABOUT := "res://src/ui/screens/about_screen.tscn"

const VIEWPORTS := {
	"desktop 1280x720": Vector2(1280, 720),
	"desktop 1920x1080": Vector2(1920, 1080),
	"tablet 1024x768": Vector2(1024, 768),
	"phone landscape 844x390": Vector2(844, 390),
	"small window 640x360": Vector2(640, 360),
	"phone portrait 390x844": Vector2(390, 844),
}


func test_every_screen_fits_every_viewport() -> void:
	for screen_path: String in [MAIN_MENU, SETTINGS, ABOUT]:
		for label: String in VIEWPORTS:
			var viewport_size: Vector2 = VIEWPORTS[label]
			var mounted := await _mount(screen_path, viewport_size)
			var screen: Control = mounted["screen"]
			var context := "%s @ %s" % [screen_path.get_file(), label]
			check_eq(screen.size, viewport_size, "%s: screen must fill the viewport" % context)
			_check_subtree(screen, Rect2(Vector2.ZERO, viewport_size), context, false)
			(mounted["viewport"] as Node).queue_free()


func test_main_menu_adapts_its_navigation() -> void:
	var wide := await _mount(MAIN_MENU, Vector2(1440, 900))
	var dossier: Control = wide["screen"].get_node("%Dossier")
	check_true(dossier.visible, "expanded layouts show the build-status column")
	var wide_title: Label = wide["screen"].get_node("%Title")
	check_eq(wide_title.theme_type_variation, &"DisplayTitle",
			"wide layouts use the full display size")
	(wide["viewport"] as Node).queue_free()

	var phone := await _mount(MAIN_MENU, Vector2(844, 390))
	var phone_dossier: Control = phone["screen"].get_node("%Dossier")
	check_false(phone_dossier.visible, "phone layouts drop the dossier column")
	var continue_row: Control = phone["screen"].get_node("%ContinueCampaign")
	check_false(continue_row.visible, "short layouts hide the unavailable Continue entry")
	var phone_title: Label = phone["screen"].get_node("%Title")
	check_eq(phone_title.text, "WORLD DOMINION", "short layouts use a single-line title")
	check_eq(phone_title.theme_type_variation, &"DisplayTitleCompact",
			"short layouts use the compact display size")
	var settings_row: Control = phone["screen"].get_node("%SettingsEntry")
	check_gte(settings_row.size.y, 44.0, "navigation rows must stay tappable on small screens")
	(phone["viewport"] as Node).queue_free()


func test_only_unimplemented_entries_are_disabled() -> void:
	var mounted := await _mount(MAIN_MENU, Vector2(1280, 720))
	var screen: Control = mounted["screen"]
	# Milestone 02 made New Campaign real; Continue has no save system behind it
	# yet and must therefore stay visibly unavailable.
	var new_campaign := screen.get_node("%NewCampaign") as Button
	check_false(new_campaign.disabled, "New Campaign must be usable once the atlas shipped")
	var badge := new_campaign.find_child("Badge", true, false) as CanvasItem
	check_not_null(badge, "the navigation row exposes its status badge")
	if badge != null:
		check_false(badge.visible, "a working entry must not carry a PLANNED badge")
	var continue_row := screen.get_node("%ContinueCampaign") as Button
	check_true(continue_row.disabled, "Continue must stay disabled until saves exist")
	for path: String in ["%SettingsEntry", "%AboutEntry"]:
		var row := screen.get_node(path) as Button
		check_false(row.disabled, "%s must be usable" % path)
	(mounted["viewport"] as Node).queue_free()


func test_settings_rows_stack_on_narrow_screens() -> void:
	# A phone in portrait leaves well under the stacking width for the form.
	var narrow := await _mount(SETTINGS, Vector2(390, 844))
	var narrow_rows := _find_setting_rows(narrow["screen"])
	check_gt(float(narrow_rows.size()), 0.0, "settings must contain setting rows")
	for row: SettingRow in narrow_rows:
		check_eq(row.columns, 1, "narrow settings rows must stack into a single column")
	(narrow["viewport"] as Node).queue_free()

	var wide := await _mount(SETTINGS, Vector2(1280, 800))
	for row: SettingRow in _find_setting_rows(wide["screen"]):
		check_eq(row.columns, 2, "wide settings rows must keep label and control side by side")
	(wide["viewport"] as Node).queue_free()


func test_settings_lists_functional_controls_only() -> void:
	var mounted := await _mount(SETTINGS, Vector2(1280, 800))
	var screen: Control = mounted["screen"]
	var segmented := screen.find_children("*", "HBoxContainer", true, false).filter(
			func(node: Node) -> bool: return node is SegmentedControl)
	check_eq(segmented.size(), 3, "theme, interface scale and motion are all selectable")
	for control: Node in segmented:
		var segmented_control := control as SegmentedControl
		check_gte(float(segmented_control.button_count()), 2.0,
				"each segmented control offers at least two choices")
	(mounted["viewport"] as Node).queue_free()


# --- Helpers ---------------------------------------------------------------

func _mount(screen_path: String, viewport_size: Vector2) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(viewport_size)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Control = load(screen_path).instantiate()
	holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Layout is deferred; two frames guarantee containers have settled.
	await tree.process_frame
	await tree.process_frame
	return {"viewport": viewport, "screen": screen}


func _check_subtree(node: Control, bounds: Rect2, context: String, inside_scroll: bool) -> void:
	if not node.visible:
		return
	var rect := node.get_global_rect()
	check_true(is_finite(rect.position.x) and is_finite(rect.size.x),
			"%s: '%s' has a non-finite rect" % [context, node.name])
	if not inside_scroll:
		check_true(bounds.grow(0.5).encloses(rect),
				"%s: '%s' overflows the viewport (rect %s within %s)" % [context, node.name, rect, bounds])
	if node is Label:
		var label := node as Label
		if not label.text.is_empty() and label.visible:
			check_gt(label.size.x, 0.0, "%s: label '%s' collapsed horizontally" % [context, label.name])
			check_gt(label.size.y, 0.0, "%s: label '%s' collapsed vertically" % [context, label.name])
	var child_inside_scroll := inside_scroll or node is ScrollContainer
	for child: Node in node.get_children():
		if child is Control:
			_check_subtree(child as Control, bounds, context, child_inside_scroll)


func _find_setting_rows(root: Node) -> Array[SettingRow]:
	var rows: Array[SettingRow] = []
	for node: Node in root.find_children("*", "GridContainer", true, false):
		if node is SettingRow:
			rows.append(node as SettingRow)
	return rows
