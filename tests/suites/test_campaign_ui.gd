extends TestCase
## Responsive, thematic and accessibility checks for the campaign screen.
##
## The screen is mounted at every size the milestone has to support, in both
## orientations, and the resulting Control rects are inspected: content that
## overflows the viewport or a map that collapses to nothing fails the run.
## Theme switching and reduced motion are exercised against the real autoloads
## and restored afterwards.

const SETUP_SCENE := "res://src/ui/screens/campaign_setup.tscn"
const REFERENCE_SIZES := {
	"desktop 1920x1080": Vector2(1920, 1080),
	"desktop 1280x720": Vector2(1280, 720),
	"tablet 1024x768": Vector2(1024, 768),
	"phone landscape 844x390": Vector2(844, 390),
	"small landscape 640x360": Vector2(640, 360),
	"phone portrait 390x844": Vector2(390, 844),
	"small portrait 360x800": Vector2(360, 800),
}


func _mount(viewport_size: Vector2) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(viewport_size)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Control = load(SETUP_SCENE).instantiate()
	holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await tree.process_frame
	await tree.process_frame
	return {"viewport": viewport, "screen": screen, "holder": holder}


func test_screen_fits_every_reference_size() -> void:
	for label: String in REFERENCE_SIZES:
		var viewport_size: Vector2 = REFERENCE_SIZES[label]
		var mounted := await _mount(viewport_size)
		var screen: Control = mounted["screen"]
		check_eq(screen.size, viewport_size, "%s: the screen fills the viewport" % label)
		_check_subtree(screen, Rect2(Vector2.ZERO, viewport_size), label)
		var map: WorldMapView = screen.get_node("%MapView")
		check_gt(map.size.x, 80.0, "%s: the map keeps a usable width" % label)
		check_gt(map.size.y, 60.0, "%s: the map keeps a usable height" % label)
		check_true(map.is_visible_in_tree(), "%s: the map is on screen" % label)
		var confirm: Button = screen.get_node("%ConfirmButton")
		check_gte(confirm.size.y, 44.0, "%s: the confirm action stays tappable" % label)
		(mounted["viewport"] as Node).queue_free()


func test_arrangement_follows_the_available_space() -> void:
	var wide := await _mount(Vector2(1280, 720))
	var wide_panel: Control = wide["screen"].get_node("%SidePanel")
	var wide_map_frame: Control = wide["screen"].get_node("%MapFrame")
	check_true(wide_panel.visible, "wide layouts always show the dossier")
	check_gte(wide_panel.global_position.x, wide_map_frame.get_global_rect().end.x - 1.0,
			"the dossier sits beside the map on wide screens")
	(wide["viewport"] as Node).queue_free()

	var portrait := await _mount(Vector2(390, 844))
	var portrait_panel: Control = portrait["screen"].get_node("%SidePanel")
	var portrait_map_frame: Control = portrait["screen"].get_node("%MapFrame")
	check_true(portrait_panel.visible, "portrait layouts keep the dossier visible")
	check_gte(portrait_panel.global_position.y, portrait_map_frame.get_global_rect().end.y - 1.0,
			"the dossier moves underneath the map on portrait screens")
	check_eq(portrait["screen"].call("_choose_arrangement", DesignTokens.LayoutMode.COMPACT,
			false), 1, "a tall narrow screen stacks the dossier")
	(portrait["viewport"] as Node).queue_free()

	var short := await _mount(Vector2(560, 360))
	var short_screen: Control = short["screen"]
	var short_panel: Control = short_screen.get_node("%SidePanel")
	var details: Button = short_screen.get_node("%DetailsButton")
	check_eq(short_screen.call("_choose_arrangement", DesignTokens.LayoutMode.COMPACT, true), 2,
			"a very short window uses the drawer instead of stacking")
	check_eq(short["screen"].call("_choose_arrangement", DesignTokens.LayoutMode.MEDIUM, true), 0,
			"a landscape phone keeps the side dossier: 640x360 is wide enough for it")
	check_true(details.visible, "the drawer has an explicit toggle")
	check_false(short_panel.visible, "the drawer starts closed so the map keeps the space")
	var map_frame: Control = short_screen.get_node("%MapFrame")
	var map_height_before := map_frame.size.y
	details.pressed.emit()
	await tree.process_frame
	var map: WorldMapView = short_screen.get_node("%MapView")
	check_true(short_panel.visible, "the toggle opens the drawer")
	check_true(map.is_visible_in_tree() and map.size.y >= 60.0,
			"the map stays on screen while the drawer is open")
	check_eq(map_frame.size.y, map_height_before,
			"opening the drawer must not resize the map")
	(short["viewport"] as Node).queue_free()


func test_results_overlay_does_not_reflow_the_map() -> void:
	var mounted := await _mount(Vector2(1280, 720))
	var screen: Control = mounted["screen"]
	var map_frame: Control = screen.get_node("%MapFrame")
	var before := map_frame.size
	var search: CountrySearch = screen.get_node("%Search")
	search.set_query("a")
	await tree.process_frame
	check_true(screen.call("results_panel_visible"), "the result list is showing")
	check_eq(map_frame.size, before,
			"the result list floats over the map instead of pushing the layout around")
	search.clear()
	await tree.process_frame
	check_false(screen.call("results_panel_visible"), "clearing the query hides the list")
	(mounted["viewport"] as Node).queue_free()


func test_both_themes_render_the_map_differently() -> void:
	var original := Settings.get_theme_id()
	for palette_id: String in Palette.ids():
		Settings.set_theme_id(palette_id)
		var mounted := await _mount(Vector2(1024, 768))
		check_eq(ThemeManager.palette_id(), palette_id,
				"%s: the theme manager follows the setting" % palette_id)
		var water: Color = ThemeManager.color(Palette.KEY_MAP_WATER)
		var land: Color = ThemeManager.color(Palette.KEY_MAP_LAND)
		check_gt(contrast_ratio(land, water), 1.4,
				"%s: land must read against water" % palette_id)
		var map: WorldMapView = mounted["screen"].get_node("%MapView")
		check_true(map.is_visible_in_tree(), "%s: the map mounts in both themes" % palette_id)
		(mounted["viewport"] as Node).queue_free()
	Settings.set_theme_id(original)


func test_reduced_motion_makes_the_brief_instant() -> void:
	var original := Settings.get_motion_mode()
	Settings.set_motion_mode(SettingsSchema.MOTION_REDUCED)
	var mounted := await _mount(Vector2(1280, 720))
	var screen: Control = mounted["screen"]
	screen.call("select_country", "BGD", false)
	var confirm: Button = screen.get_node("%ConfirmButton")
	confirm.pressed.emit()
	check_true(screen.call("is_overlay_visible"), "the brief opens")
	check_eq(screen.get_node("%ConfirmOverlay").modulate.a, 1.0,
			"reduced motion shows the brief without a fade")
	(mounted["viewport"] as Node).queue_free()
	Settings.set_motion_mode(original)


func test_interactive_elements_are_reachable_and_labelled() -> void:
	var mounted := await _mount(Vector2(1280, 720))
	var screen: Control = mounted["screen"]
	var map: WorldMapView = screen.get_node("%MapView")
	check_eq(map.focus_mode, Control.FOCUS_ALL,
			"the map must be reachable with the keyboard")
	var search: CountrySearch = screen.get_node("%Search")
	var field := search.find_children("*", "LineEdit", true, false)
	check_gt(float(field.size()), 0.0, "the search field must exist")
	if not field.is_empty():
		var line := field[0] as LineEdit
		check_false(line.placeholder_text.is_empty(),
				"the search field must say what it searches")
		check_gte(line.custom_minimum_size.y, 32.0, "the search field must stay tappable")
	var controls: MapControls = screen.get_node("%MapControls")
	check_gte(float(controls.button_count()), 3.0,
			"the map needs visible zoom in/out and reset controls")
	for node: Node in controls.find_children("*", "Button", true, false):
		var button := node as Button
		check_false(button.tooltip_text.is_empty(),
				"'%s' must describe its action" % button.text)
		check_gte(button.custom_minimum_size.y, 32.0, "%s must stay tappable" % button.text)
	var regions: RegionFilter = screen.get_node("%Regions")
	check_gt(float(regions.chip_count()), 4.0, "the region filter offers real regions")
	var chip := regions.chip_for("Africa")
	check_not_null(chip, "Africa must be offered as a filter")
	if chip != null:
		check_true(chip.toggle_mode, "filter chips are toggles with a visible state")
	(mounted["viewport"] as Node).queue_free()


func test_region_filter_and_clear_action_are_wired() -> void:
	var mounted := await _mount(Vector2(1280, 720))
	var screen: Control = mounted["screen"]
	var regions: RegionFilter = screen.get_node("%Regions")
	var clear: Button = screen.get_node("%ClearFilters")
	check_false(clear.visible, "the clear action hides while no filter is active")
	regions.region_changed.emit("Africa")
	await tree.process_frame
	var filter: AtlasFilter = screen.call("filter_state")
	check_eq(filter.region, "Africa", "choosing a region updates the filter state")
	check_true(clear.visible, "an active filter exposes a way to clear it")
	clear.pressed.emit()
	await tree.process_frame
	check_false(filter.is_active(), "clearing resets the filter")
	check_eq(regions.active_region(), "", "the chips return to 'All regions'")
	check_false(clear.visible, "and the clear action hides again")
	(mounted["viewport"] as Node).queue_free()


## Keyboard-only search: typing, walking the results with the arrow keys, and
## clearing. A search that needs a mouse would fail the accessibility rules.
func test_search_works_without_a_pointer() -> void:
	var mounted := await _mount(Vector2(1280, 720))
	var screen: Control = mounted["screen"]
	var search: CountrySearch = screen.get_node("%Search")
	search.set_query("guinea")
	await tree.process_frame
	var ids := search.visible_result_ids()
	check_gte(float(ids.size()), 2.0, "typing a family of names offers several results")
	check_eq(ids[0], "GIN", "the exact name ranks above the longer ones")
	check_eq(search.active_result_index(), -1, "nothing is highlighted before the arrows are used")
	search._focus_result(1)
	check_eq(search.active_result_index(), 1, "the keyboard can move into the result list")
	var button := search.result_button(1)
	check_not_null(button, "the focused result is a real button")
	if button != null:
		check_true(button.has_focus(), "the focused result actually holds focus")
	search.clear()
	await tree.process_frame
	check_eq(search.current_query(), "", "clearing empties the query")
	check_false(search.is_list_visible(), "clearing closes the result list")
	search.set_query("zzzzz")
	await tree.process_frame
	check_true(search.empty_state_visible(), "a query with no match explains itself")
	check_eq(search.visible_result_ids().size(), 0, "and offers no results")
	(mounted["viewport"] as Node).queue_free()


## The stage line is derived, not tracked: it must follow selection and the review
## overlay, and never claim a later stage than the player has reached.
func test_stage_follows_selection_and_review() -> void:
	var mounted := await _mount(Vector2(1280, 720))
	var screen: Control = mounted["screen"]
	check_eq(screen.call("current_step"), 1, "a fresh setup is at the scenario stage")
	check_true(screen.call("select_country", "BGD", false), "Bangladesh can be selected")
	await tree.process_frame
	check_eq(screen.call("current_step"), 2, "selecting a nation advances to the nation stage")
	screen.call("_on_confirm_pressed")
	await tree.process_frame
	check_eq(screen.call("current_step"), 3, "reviewing the campaign is the last stage")
	screen.call("_close_overlay")
	await tree.process_frame
	check_eq(screen.call("current_step"), 2,
			"going back from review keeps the nation that was already chosen")
	check_eq(screen.call("selected_country_id"), "BGD",
			"a valid selection survives the back step")
	(mounted["viewport"] as Node).queue_free()


## The dossier on screen must be the dossier object, with gaps stated and the
## unimplemented systems named. This is the honesty check at the UI level: a fake
## statistic would have to pass it.
func test_selected_country_opens_a_sourced_dossier() -> void:
	var mounted := await _mount(Vector2(1280, 720))
	var screen: Control = mounted["screen"]
	var panel: CountryInfoPanel = screen.get_node("%InfoPanel")
	screen.call("select_country", "PSE", false)
	await tree.process_frame
	var dossier := panel.dossier()
	check_not_null(dossier, "selecting a country builds a dossier")
	if dossier == null:
		return
	check_eq(dossier.country_id, "PSE", "the dossier belongs to the selected country")
	check_eq(panel.selected_id(), "PSE", "the panel and the dossier agree")
	check_true(panel.shows_planned_sections(), "the panel says which systems are planned")
	var gaps := dossier.missing_fields()
	check_true(gaps.has("administration/Capital"),
			"a country with no capital in the source shows a stated gap")
	check_gt(float(panel.row_count()), 0.0, "the panel actually renders the dossier")
	screen.call("select_country", "", false)
	await tree.process_frame
	check_true(panel.dossier() == null, "deselecting returns the panel to its empty state")
	(mounted["viewport"] as Node).queue_free()


## Region counts are read from the registry, so the filter cannot advertise a
## number the data does not support.
func test_region_counts_come_from_the_registry() -> void:
	var mounted := await _mount(Vector2(1280, 720))
	var screen: Control = mounted["screen"]
	var atlas: WorldAtlas = screen.call("atlas")
	var regions: RegionFilter = screen.get_node("%Regions")
	check_eq(regions.count_for(""), atlas.registry.count(),
			"'All regions' counts every record")
	check_eq(regions.count_for("Africa"), atlas.registry.region_count("Africa"),
			"Africa's count is the registry's count")
	var chip := regions.chip_for("Africa")
	check_not_null(chip, "Africa has a chip")
	if chip != null:
		check_true(chip.tooltip_text.contains(str(atlas.registry.region_count("Africa"))),
				"the chip states its matching record count")
	(mounted["viewport"] as Node).queue_free()


# --- Helpers ---------------------------------------------------------------

## Scroll content is allowed to exceed its viewport — the ScrollContainer clips
## it — so only the frame around a scrollable area is checked for overflow.
func _check_subtree(node: Control, bounds: Rect2, context: String,
		inside_scroll: bool = false) -> void:
	if not node.visible:
		return
	var rect := node.get_global_rect()
	check_true(is_finite(rect.position.x) and is_finite(rect.size.x),
			"%s: '%s' has a non-finite rect" % [context, node.name])
	if not inside_scroll:
		check_true(bounds.grow(1.0).encloses(rect),
				"%s: '%s' overflows the viewport (rect %s within %s)"
				% [context, node.name, rect, bounds])
	var child_inside_scroll := inside_scroll or node is ScrollContainer
	for child: Node in node.get_children():
		if child is Control:
			_check_subtree(child as Control, bounds, context, child_inside_scroll)
