extends ResponsiveScreen
## New Campaign → scenario → nation → review.
##
## The screen is the only place that ties the atlas pieces together: it loads the
## world data and the scenario catalogue, hands the atlas to the map, and mirrors
## map/selection/search state into the interface. Nothing in this file knows how a
## polygon is drawn; nothing in the map knows what a campaign is.
##
## Layout: on wide screens the map takes the left column and the dossier sits on
## the right; on a narrow screen the dossier moves underneath the map as a bottom
## sheet and the map keeps the remaining height, so the world is never hidden
## behind chrome. Both arrangements are the same nodes reparented, not two
## duplicated screens.
##
## Honesty: the confirm step produces a campaign configuration and shows a brief.
## This build does not simulate, and does not save. The overlay says so.

signal navigate_requested(screen_id: String)
signal back_requested()
signal home_requested()
signal navigation_requested(screen_id: String, params: Dictionary)

## How the map and the dossier share the screen.
##   SIDE   — map left, dossier right (desktop, tablet landscape)
##   STACK  — map on top, dossier underneath (phone portrait)
##   DRAWER — map only, dossier opens over it from the footer (very short windows,
##            where stacking would leave the world 40 pixels tall)
enum Arrangement { SIDE, STACK, DRAWER }

const _PANEL_WIDTH_EXPANDED := 380
const _PANEL_WIDTH_MEDIUM := 340
const _MAP_MIN_HEIGHT := 120
const _OVERLAY_MAX_WIDTH := 520
const _STEP_TITLES: PackedStringArray = ["SCENARIO", "NATION", "REVIEW"]

var _arrangement := Arrangement.SIDE
var _atlas: WorldAtlas
var _catalog: ScenarioCatalog
var _eligibility := StartEligibility.rules()
var _filter := AtlasFilter.new()
var _scenario: Scenario
var _selected: CountryRecord
var _results_panel: PanelContainer
var _dataset_line_ready := false
var _drawer_open := false
var _map_options: MapOptionsPanel
var _step_labels: Array[Label] = []
var _stress := MapStressTest.new()
var _stress_panel: PanelContainer
var _stress_lines: Label
var _picker: CountryPickerPanel
var _strip: FlagStrip
var _stress_active := false
var _step_caption: Label

## Built in code so the scene stays small; see `_build_recent_strip()`.
var _recent_strip: HFlowContainer
var _compact_layout := false
var _view_height := 0.0
@onready var _header: AppHeader = %Header
@onready var _body: VBoxContainer = %Body
@onready var _wide_body: HBoxContainer = %WideBody
@onready var _narrow_body: VBoxContainer = %NarrowBody
@onready var _side_panel: PanelContainer = %SidePanel
@onready var _search: CountrySearch = %Search
@onready var _regions: RegionFilter = %Regions
@onready var _panel_body: VBoxContainer = %PanelBody
@onready var _map_column: VBoxContainer = %MapColumn
@onready var _clear_button: Button = %ClearFilters
@onready var _map_frame: PanelContainer = %MapFrame
@onready var _map_stack: Control = %MapStack
@onready var _map: WorldMapView = %MapView
@onready var _controls: MapControls = %MapControls
@onready var _status: Label = %StatusLabel
@onready var _scenario_section: VBoxContainer = %ScenarioSection
@onready var _info: CountryInfoPanel = %InfoPanel
@onready var _dataset_line: Label = %DatasetLine
@onready var _selection_title: Label = %SelectionTitle
@onready var _selection_detail: Label = %SelectionDetail
@onready var _details_button: Button = %DetailsButton
@onready var _confirm_button: Button = %ConfirmButton
@onready var _overlay: Control = %ConfirmOverlay
@onready var _overlay_body: VBoxContainer = %OverlayBody


func _ready() -> void:
	super()
	_header.back_pressed.connect(func() -> void: back_requested.emit())
	_atlas = WorldAtlas.load_default()
	_catalog = ScenarioCatalog.from_directory()
	_scenario = _catalog.default_scenario()

	_search.setup(_atlas.registry)
	_build_recent_strip()
	_regions.setup(_atlas.registry)
	_map.set_atlas(_atlas)
	_map.country_activated.connect(_on_map_country_activated)
	_build_picker()
	_map.view_changed.connect(_on_view_changed)

	_controls.zoom_in_requested.connect(_map.camera.zoom_in)
	_controls.zoom_out_requested.connect(_map.camera.zoom_out)
	_controls.reset_requested.connect(_map.camera.reset)
	_controls.options_requested.connect(_open_map_options)

	_info.compare_requested.connect(_on_compare_requested)
	_search.country_chosen.connect(_on_search_country_chosen)
	_search.query_changed.connect(_on_query_changed)
	_regions.region_changed.connect(_on_region_changed)
	_clear_button.pressed.connect(_clear_filters)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_details_button.pressed.connect(_on_details_pressed)

	_selection_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selection_detail.clip_text = true
	_attach_results_overlay()
	_update_clear_button()
	_build_scenario_section()
	_show_atlas_state()
	_refresh_footer()
	MapOptions.apply_to(_map)
	Settings.changed.connect(_on_setting_changed)
	_map_stack.resized.connect(_layout_overlays)
	_on_view_changed()


## The picker: a group chooser with an A–Z list on the right, and a flag strip along the
## bottom of the map column. Both feed `select_country()`, so the map, the list, the strip
## and the dossier always show the same country.
func _build_picker() -> void:
	_picker = CountryPickerPanel.new()
	_picker.name = "Picker"
	_panel_body.add_child(_picker)
	_panel_body.move_child(_picker, 0)
	_picker.setup(_atlas.registry)
	_picker.country_chosen.connect(func(country_id: String) -> void:
		select_country(country_id, true))

	_strip = FlagStrip.new()
	_strip.name = "FlagStrip"
	_map_column.add_child(_strip)
	_strip.country_chosen.connect(func(country_id: String) -> void:
		select_country(country_id, true))
	_show_group_in_strip(_picker.current_group())
	# The strip is built after the first layout pass has run, so ask for one more now that
	# it exists: otherwise its full height is the height it keeps on a phone.
	_apply_layout()


## Fills the strip with the group the picker is showing, in A–Z order.
func _show_group_in_strip(group_id: String) -> void:
	if _strip == null or _atlas == null:
		return
	var members: Array = []
	var ids := _atlas.registry.ids()
	ids.sort()
	for country_id: String in ids:
		if _picker != null and _picker.group_of(country_id) == group_id:
			members.append(country_id)
	_strip.show_group(_atlas.registry, group_id, members)


## Keeps the list, the strip and the map on the same country, whichever one was used: the
## group follows the record, the strip is refilled for that group, and both are marked.
func _sync_picker_to(country_id: String) -> void:
	if _picker == null or country_id.is_empty():
		return
	var group_id := _picker.group_of(country_id)
	if group_id.is_empty():
		return
	if _picker.current_group() != group_id:
		_picker.select_group(group_id)
		_show_group_in_strip(group_id)
	_picker.set_selected(country_id)
	if _strip != null:
		_strip.set_selected(country_id)


## The "recently viewed" strip. It is rebuilt instead of updated so it cannot drift
## from the settings store, and it disappears entirely when the list is empty rather
## than showing an empty frame.
func _build_recent_strip() -> void:
	_recent_strip = HFlowContainer.new()
	_recent_strip.name = "RecentStrip"
	_recent_strip.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	_recent_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recent_strip.focus_mode = Control.FOCUS_NONE
	var parent := _search.get_parent()
	parent.add_child(_recent_strip)
	parent.move_child(_recent_strip, _search.get_index() + 1)
	_refresh_recent()


func _refresh_recent() -> void:
	if _recent_strip == null or _atlas == null:
		return
	for child: Node in _recent_strip.get_children():
		child.queue_free()
	var recent := AtlasHistory.recent_valid(_atlas.registry)
	if recent.is_empty() or _compact_layout:
		_recent_strip.visible = false
		return
	_recent_strip.visible = true
	var caption := Label.new()
	caption.text = "Recently viewed"
	caption.theme_type_variation = &"Caption"
	_recent_strip.add_child(caption)
	var shown := 0
	for country_id: String in recent:
		if shown >= 4:
			break
		var record := _atlas.registry.get_country(country_id)
		if record == null:
			continue
		var chip := Button.new()
		chip.text = record.name
		chip.theme_type_variation = &"Chip"
		# Chips wrap instead of widening the panel, and they are full touch targets.
		chip.tooltip_text = "Show %s in the atlas" % record.name
		chip.custom_minimum_size.y = DesignTokens.TOUCH_TARGET_MIN
		chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		chip.pressed.connect(func() -> void: select_country(country_id, true))
		_recent_strip.add_child(chip)
		shown += 1


func on_layout_changed(mode: int, is_short: bool, view_size: Vector2) -> void:
	_view_height = view_size.y
	_header.set_compact(is_short)
	# One more row of chips is one row too many on a 360 px-tall window: there the strip
	# hides, and the recently viewed list stays available from the search results.
	_compact_layout = is_short
	if _recent_strip != null:
		_refresh_recent()
	_arrangement = _choose_arrangement(mode, is_short)
	_search.set_compact(is_short)
	_regions.set_compact(is_short)
	_controls.set_compact(is_short or mode == DesignTokens.LayoutMode.COMPACT)
	_details_button.visible = _arrangement == Arrangement.DRAWER
	_details_button.text = "Hide details" if _drawer_open else "Details"
	_apply_vertical_rhythm(is_short)
	_map_frame.custom_minimum_size.y = _map_min_height()
	if _strip != null:
		# The strip is one more fixed row than a 390-pixel-tall window can carry at its full
		# size, so it shrinks with the rest of the screen rather than pushing the footer out.
			_strip.set_compact(is_short or mode == DesignTokens.LayoutMode.COMPACT)
	match _arrangement:
		Arrangement.SIDE:
			_place_side(mode)
		Arrangement.STACK:
			_place_stack(view_size)
		Arrangement.DRAWER:
			_place_drawer()
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_layout_overlays()


## A phone in landscape cannot afford desktop spacing: gaps halve, the confirm
## button loses 8 px of padding, and the map keeps the difference.
func _apply_vertical_rhythm(is_short: bool) -> void:
	_body.get_parent().add_theme_constant_override("separation",
			DesignTokens.SPACE_8 if is_short else DesignTokens.SPACE_12)
	_map_column.add_theme_constant_override("separation",
			DesignTokens.SPACE_4 if is_short else DesignTokens.SPACE_8)
	# 44 px is the smallest comfortable touch target on a phone; below that the
	# confirm action becomes a miss-tap generator.
	var footer_height := 44 if is_short else DesignTokens.TOUCH_TARGET_MIN
	_confirm_button.custom_minimum_size.y = footer_height
	_details_button.custom_minimum_size.y = footer_height


func _choose_arrangement(mode: int, is_short: bool) -> Arrangement:
	if mode != DesignTokens.LayoutMode.COMPACT:
		return Arrangement.SIDE
	return Arrangement.DRAWER if is_short else Arrangement.STACK


## The map gets whatever height is left; this floor only stops it collapsing to
## nothing when a very short window also has to fit the search and filter rows.
func _map_min_height() -> float:
	match _arrangement:
		Arrangement.DRAWER:
			return 72.0
		Arrangement.STACK:
			return 96.0
		_:
			# The flag strip costs the map column a row, so a short window gives the map 24
			# pixels less, and a very short one 48 less, which is what lets the footer stay
			# on screen.
			if _view_height > 0.0 and _view_height < 380.0:
				return 72.0
			return 96.0 if _compact_layout else 120.0


# --- Developer tools -------------------------------------------------------

## The router hands instructions through here (see ScreenRouter.go_to).
func receive_params(params: Dictionary) -> void:
	if not bool(params.get("stress_test", false)):
		return
	if not Settings.get_developer_tools():
		push_warning("CampaignSetup: stress test requested while developer tools are off; ignoring.")
		return
	start_stress_test.call_deferred()


## Starts the 30-second map stress test. The path is deterministic (see
## MapStressTest), so two runs on two devices can be compared honestly.
func start_stress_test() -> void:
	_stress_active = true
	_stress.start()
	_ensure_stress_panel()
	_stress_lines.text = "Stress test running… 0%"
	_stress_panel.visible = true


func is_stress_test_running() -> bool:
	return _stress_active


func stress_test() -> MapStressTest:
	return _stress


## Counts the developer overlay shows. Reading them costs nothing when the
## overlay is off because nobody asks.
func performance_counts() -> String:
	if _map == null:
		return ""
	var stats := _map.draw_stats()
	return "visible countries %d · labels %d · capital markers %d" % [
		int(stats.get("visible_countries", 0)), int(stats.get("labels", 0)),
		int(stats.get("capitals", 0))]


func _process(delta: float) -> void:
	if not _stress_active:
		return
	var running := _stress.advance(delta)
	var state := _stress.camera_state()
	var fit := _map.camera.fit_zoom()
	_map.camera.set_view(state["center"], fit * float(state["zoom_factor"]))
	_stress_lines.text = "Stress test running… %d%%" % int(round(_stress.progress() * 100.0))
	if running:
		return
	_stress_active = false
	_stress_lines.text = "\n".join(_stress.summary_lines())


func _ensure_stress_panel() -> void:
	if _stress_panel != null:
		return
	_stress_panel = PanelContainer.new()
	_stress_panel.visible = false
	_stress_panel.z_index = 20
	_stress_panel.theme_type_variation = &"PanelCard"
	_stress_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := MarginContainer.new()
	for side: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, DesignTokens.SPACE_8)
	_stress_panel.add_child(margin)
	_stress_lines = Label.new()
	_stress_lines.theme_type_variation = &"Caption"
	_stress_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stress_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_stress_lines)
	_map_stack.add_child(_stress_panel)
	_stress_panel.reset_size()
	_stress_panel.position = Vector2(DesignTokens.SPACE_8, DesignTokens.SPACE_8 + 44.0)
	_stress_panel.size = Vector2(minf(360.0, maxf(_map_stack.size.x - 16.0, 120.0)), 96.0)


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == SettingsSchema.KEY_RECENT_COUNTRIES:
		_refresh_recent()
	if key == SettingsSchema.KEY_MAP_DETAIL and _map != null:
		MapOptions.apply_to(_map)


# --- Public state (used by the router and by tests) ------------------------

func atlas() -> WorldAtlas:
	return _atlas


func catalog() -> ScenarioCatalog:
	return _catalog


func scenario() -> Scenario:
	return _scenario


func filter_state() -> AtlasFilter:
	return _filter


func selected_country_id() -> String:
	return "" if _selected == null else _selected.id


func is_confirm_enabled() -> bool:
	return not _confirm_button.disabled


func is_overlay_visible() -> bool:
	return _overlay.visible


func results_panel_visible() -> bool:
	return _results_panel != null and _results_panel.visible


## Selects a nation by stable id. Unknown ids clear the selection; an empty id
## deselects. Re-selecting the current country is a no-op, which is what makes a
## repeated tap harmless.
func select_country(country_id: String, focus_map: bool = false) -> bool:
	var record: CountryRecord = null
	if not country_id.is_empty() and _atlas != null:
		record = _atlas.registry.get_country(country_id)
	_selected = record
	var resolved := "" if record == null else record.id
	_map.set_selected(resolved)
	_info.show_country(record, _dossier_context(resolved))
	_refresh_steps()
	if record != null:
		# A convenient local list, kept in settings only: never in a save, never sent
		# anywhere, and it cannot change a campaign's state.
		AtlasHistory.remember(resolved)
		_refresh_recent()
	if focus_map and record != null:
		# Flying rather than jumping: the player asked to look at a country, so the
		# camera shows them where it went. Reduced motion jumps.
		_map.focus_country(resolved, 56.0, true)
	# The list and the strip follow every selection, whichever control made it.
	_sync_picker_to(resolved)
	_refresh_footer()
	_on_view_changed()
	return record != null


## Builds the campaign configuration for the current choice, or null when the
## configuration would not validate.
## Atlas facts the dossier needs but a country record does not own: dataset
## provenance, and how much geometry this particular unit has.
## The dossier's Compare button asks the host screen where the comparison lives. In
## the atlas that is its own screen; the router keeps the atlas in history, so going
## back returns to the same selection.
func _on_compare_requested(country_id: String) -> void:
	navigation_requested.emit("comparison", {"country_id": country_id})


func _dossier_context(country_id: String) -> Dictionary:
	if _atlas == null or _atlas.manifest.is_empty():
		return {}
	var source: Dictionary = _atlas.manifest.get("source", {})
	var processing: Dictionary = _atlas.manifest.get("processing", {})
	var context := {
		"dataset": source.get("dataset", ""),
		"dataset_version": source.get("version", ""),
		"dataset_commit": source.get("commit", ""),
		"licence": source.get("licence", ""),
		"retrieved": source.get("retrieved", ""),
		"scale": processing.get("scale", 0),
		"statistics": _atlas.statistics,
		"currency": _atlas.currency,
	}
	if country_id.is_empty() or _atlas.geometry == null:
		return context
	context["polygons"] = _atlas.geometry.polygon_count_of(country_id)
	context["rings"] = _atlas.geometry.rings_of(country_id).size()
	context["vertices"] = _atlas.geometry.vertex_count_of(country_id)
	return context


func build_campaign() -> CampaignConfig:
	var config := CampaignConfig.create(_scenario, _selected)
	if not config.validate(_catalog, _atlas.registry, _eligibility).is_empty():
		return null
	return config


func campaign_errors() -> PackedStringArray:
	return CampaignConfig.create(_scenario, _selected).validate(_catalog, _atlas.registry,
			_eligibility)


## The starting-nation rules this screen is using (data-driven, see
## `data/world/start_eligibility.json`). Exposed for tests and for the dossier
## footer line.
func eligibility() -> StartEligibility:
	return _eligibility


## True when the selected record may be played as a starting nation. Every record
## stays browsable and viewable; only confirmation is gated.
func selection_is_playable() -> bool:
	return _selected != null and _eligibility.is_eligible(_selected)


# --- Layout ----------------------------------------------------------------

func _place_side(mode: int) -> void:
	_move_columns(_wide_body)
	_wide_body.visible = true
	_narrow_body.visible = false
	_drawer_open = false
	_side_panel.visible = true
	_side_panel.z_index = 0
	_side_panel.custom_minimum_size = Vector2(
			float(_PANEL_WIDTH_EXPANDED if mode == DesignTokens.LayoutMode.EXPANDED
					else _PANEL_WIDTH_MEDIUM), 0.0)
	_side_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _place_stack(view_size: Vector2) -> void:
	_move_columns(_narrow_body)
	_wide_body.visible = false
	_narrow_body.visible = true
	_drawer_open = false
	_side_panel.visible = true
	_side_panel.z_index = 0
	_side_panel.custom_minimum_size = Vector2(0.0,
			clampf(view_size.y * 0.3, 96.0, 260.0))
	_side_panel.size_flags_vertical = Control.SIZE_FILL


func _place_drawer() -> void:
	_move_columns(_narrow_body)
	_wide_body.visible = false
	_narrow_body.visible = true
	_side_panel.custom_minimum_size = Vector2.ZERO
	_side_panel.size_flags_vertical = Control.SIZE_FILL
	_side_panel.z_index = 5
	if _side_panel.get_parent() != _map_stack:
		_side_panel.reparent(_map_stack, false)
	_side_panel.visible = _drawer_open


## Moves the shared widgets into `target`. The widgets are never duplicated, so
## there is exactly one map and one dossier regardless of the arrangement.
func _move_columns(target: Container) -> void:
	if _map_column.get_parent() != target:
		_map_column.reparent(target, false)
	if _side_panel.get_parent() != target:
		_side_panel.reparent(target, false)
	target.move_child(_map_column, 0)
	target.move_child(_side_panel, target.get_child_count() - 1)


func _open_map_options() -> void:
	if _map_options == null:
		_map_options = MapOptionsPanel.new()
		add_child(_map_options)
	_map_options.open(_map)


func _on_details_pressed() -> void:
	_drawer_open = not _drawer_open
	_side_panel.visible = _drawer_open and _arrangement == Arrangement.DRAWER
	_details_button.text = "Hide details" if _drawer_open else "Details"
	_layout_overlays()


func _layout_overlays() -> void:
	if _map_stack == null or _controls == null:
		return
	# The zoom cluster and the status line are anchored to the map frame, so they
	# follow it without this code guessing at a size the container has not
	# applied yet. Only the drawer needs arithmetic.
	if _arrangement == Arrangement.DRAWER and _side_panel.get_parent() == _map_stack:
		var drawer_height := clampf(_map_stack.size.y * 0.7, 110.0, 240.0)
		_side_panel.position = Vector2(0.0, maxf(_map_stack.size.y - drawer_height, 0.0))
		_side_panel.size = Vector2(_map_stack.size.x, drawer_height)
	_position_results_panel()


func _attach_results_overlay() -> void:
	_results_panel = _search.take_results_panel()
	if _results_panel == null:
		return
	_map_stack.clip_contents = false
	_results_panel.z_index = 10
	_results_panel.clip_contents = true
	_map_stack.add_child(_results_panel)
	_results_panel.minimum_size_changed.connect(_position_results_panel)
	_search.results_visibility_changed.connect(_on_results_visibility_changed)


func _position_results_panel() -> void:
	if _results_panel == null:
		return
	var width := minf(maxf(_map_stack.size.x - DesignTokens.SPACE_16, 160.0), 420.0)
	var height := minf(_results_panel.get_combined_minimum_size().y,
			maxf(_map_stack.size.y - DesignTokens.SPACE_16, 80.0))
	_results_panel.size = Vector2(width, height)
	_results_panel.position = Vector2(DesignTokens.SPACE_8, DesignTokens.SPACE_8)


# --- Scenario --------------------------------------------------------------

func _build_scenario_section() -> void:
	_clear_children(_scenario_section)
	_build_steps()
	_add_label(_scenario_section, "SCENARIO", "SectionHeading")
	if _scenario == null:
		var missing := _add_label(_scenario_section,
				"No scenario in this build can be started.", "BodySmall")
		missing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	var title := _add_label(title_row, _scenario.name, "FieldLabel")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_badge("IMPLEMENTED"))
	_scenario_section.add_child(title_row)
	_add_label(_scenario_section, "Starts %s" % _scenario.start_date_label(), "Caption")
	if not _scenario.description.is_empty():
		var description := _add_label(_scenario_section, _scenario.description, "BodySmall")
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not _scenario.note.is_empty():
		var note := _add_label(_scenario_section, _scenario.note, "Caption")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _catalog.implemented_count() == 1:
		var honest := _add_label(_scenario_section,
				"Only one scenario is implemented in this build.", "Caption")
		honest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Three-step progress line: scenario → nation → review. The caption spells the
## stage out in words, so the current step is never indicated by colour alone.
func _build_steps() -> void:
	_step_labels.clear()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SPACE_4)
	for index in _STEP_TITLES.size():
		var label := _add_label(row, "%d %s" % [index + 1, _STEP_TITLES[index]], "Mono")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_step_labels.append(label)
	_scenario_section.add_child(row)
	_step_caption = _add_label(_scenario_section, "", "Caption")
	_refresh_steps()


func _refresh_steps() -> void:
	var step := current_step()
	for index in _step_labels.size():
		var label := _step_labels[index]
		var done := index + 1 < step
		var active := index + 1 == step
		label.text = "%d %s%s" % [index + 1, _STEP_TITLES[index], " · DONE" if done else ""]
		label.add_theme_color_override("font_color", ThemeManager.color(
				Palette.KEY_ACCENT if active
				else (Palette.KEY_TEXT_SECONDARY if done else Palette.KEY_TEXT_TERTIARY)))
	if _step_caption != null:
		_step_caption.text = "Step %d of %d — %s" % [step, _STEP_TITLES.size(),
				_STEP_TITLES[step - 1]]
		if step == 3:
			_step_caption.text = "Step 3 of 3 — Review. Nothing is simulated or saved yet."


## Which stage the player is in: 1 scenario, 2 nation, 3 review. The stage is
## derived from real state, never tracked separately, so it cannot drift.
func current_step() -> int:
	if _overlay != null and _overlay.visible:
		return 3
	if _selected != null:
		return 2
	return 1


func _badge(text: String) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.theme_type_variation = &"Badge"
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"BadgeText"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	return badge


func _show_atlas_state() -> void:
	if _atlas.is_ready():
		var issues := _atlas.unshaped_country_ids()
		if not issues.is_empty():
			_info.show_unavailable("%d countries have no drawable shape in this dataset."
					% issues.size())
		return
	var reason := "The atlas files could not be read. "
	reason += " / ".join(_atlas.issues()) if not _atlas.issues().is_empty() else ""
	_info.show_unavailable(reason.strip_edges())


# --- Filtering and selection ----------------------------------------------

func _on_query_changed(query: String) -> void:
	_filter.set_query(query)
	_update_clear_button()
	_on_view_changed()


func _on_region_changed(region: String) -> void:
	_filter.set_region(region)
	_update_clear_button()
	_on_view_changed()


func _clear_filters() -> void:
	_filter.clear()
	_search.clear()
	_regions.set_region("")
	_update_clear_button()
	_on_view_changed()


func _update_clear_button() -> void:
	_clear_button.visible = _filter.is_active()


func _on_search_country_chosen(country_id: String) -> void:
	select_country(country_id, true)


func _on_map_country_activated(country_id: String) -> void:
	# An empty id means the player tapped open water or empty space: that clears
	# the selection rather than leaving a stale highlight behind.
	select_country(country_id, false)


func _on_results_visibility_changed(_visible: bool) -> void:
	_position_results_panel()


func _on_view_changed() -> void:
	if _atlas == null or _status == null:
		return
	var shown := _filter.apply(_atlas.registry).size()
	var total := _atlas.country_count()
	var parts := PackedStringArray()
	parts.append("Drag to pan · scroll or pinch to zoom")
	parts.append(_filter.describe(total, shown).to_upper())
	if _map.camera.is_zoomed():
		parts.append("%.1f× zoom" % _map.camera.zoom_ratio())
	_status.text = "  ·  ".join(parts)
	# The dataset line is static; building it on every camera change would allocate
	# for nothing while the player pans.
	if not _dataset_line_ready:
		_dataset_line_ready = true
		_update_dataset_line()


func _update_dataset_line() -> void:
	if _dataset_line == null:
		return
	var summary := _atlas.describe_dataset()
	_dataset_line.text = ("Country data: %s. Source, licence and processing are "
			+ "recorded in docs/DATA_SOURCES.md.") % (summary if not summary.is_empty()
					else _atlas.attribution())


func _refresh_footer() -> void:
	var errors := campaign_errors()
	if _selected == null:
		_selection_title.text = "No nation selected"
		_selection_detail.text = "Pick a country on the map or search for one."
	else:
		_selection_title.text = _selected.name
		var detail := _selected.region
		if _selected.has_iso_a3():
			detail += " · %s" % _selected.iso_a3
		if _selected.has_capital():
			detail += " · capital %s" % _selected.capital
		# A record that cannot start a campaign says so here, in neutral words,
		# without implying anything about the place itself.
		if not _eligibility.is_eligible(_selected):
			detail = _eligibility.reason()
		_selection_detail.text = detail
	if not errors.is_empty():
		_selection_detail.text = errors[0]
	_confirm_button.disabled = not errors.is_empty()


# --- Confirm ---------------------------------------------------------------

func _on_confirm_pressed() -> void:
	var config := build_campaign()
	if config == null:
		_refresh_footer()
		return
	_build_confirm_overlay(config)
	_overlay.visible = true
	_refresh_steps()
	_overlay.modulate.a = 0.0
	var duration := Motion.duration(DesignTokens.DURATION_BASE, Settings.get_reduce_motion())
	if duration <= 0.0:
		_overlay.modulate.a = 1.0
	else:
		var tween := create_tween()
		Motion.ease_ui(tween)
		tween.tween_property(_overlay, "modulate:a", 1.0, duration)


func _build_confirm_overlay(config: CampaignConfig) -> void:
	_clear_children(_overlay_body)
	_add_label(_overlay_body, "CAMPAIGN READY", "Eyebrow")
	var record := _atlas.registry.get_country(config.country_id)
	var title := _add_label(_overlay_body, record.name if record != null else "",
			"ScreenTitle")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", DesignTokens.SPACE_24)
	grid.add_theme_constant_override("v_separation", DesignTokens.SPACE_8)
	_add_overlay_row(grid, "Scenario", str(config.metadata.get("scenario_name", config.scenario_id)))
	_add_overlay_row(grid, "Starting date", Scenario.format_date(config.start_date))
	_add_overlay_row(grid, "Nation", str(config.metadata.get("country_name", config.country_id)))
	_add_overlay_row(grid, "Region", str(config.metadata.get("region", "")))
	var iso := record.iso_label() if record != null else ""
	_add_overlay_row(grid, "ISO", iso)
	_overlay_body.add_child(HSeparator.new())
	_overlay_body.add_child(grid)
	_overlay_body.add_child(HSeparator.new())

	var honest := _add_label(_overlay_body,
			"Starting the campaign opens the game screen: an in-game calendar, the world "
			+ "map, country dossiers and saves. No economy, politics, diplomacy or "
			+ "military simulation exists yet, and the game screen says so.", "BodySmall")
	honest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	var back := Button.new()
	back.text = "Back to map"
	back.theme_type_variation = &"GhostButton"
	back.custom_minimum_size.y = DesignTokens.TOUCH_TARGET_MIN
	back.pressed.connect(_close_overlay)
	actions.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var start := Button.new()
	start.text = "Start campaign"
	start.name = "StartCampaign"
	start.theme_type_variation = &"PrimaryButton"
	start.custom_minimum_size.y = DesignTokens.TOUCH_TARGET_MIN
	start.pressed.connect(func() -> void: _start_campaign(config))
	actions.add_child(start)
	_overlay_body.add_child(actions)
	back.grab_focus()


## Begins the campaign and hands over to the game screen. The session is created
## here, once, from the configuration the overlay just summarised, so what the
## player confirmed is exactly what gets played.
func _start_campaign(config: CampaignConfig) -> void:
	Game.start(config)
	navigation_requested.emit("game", {"started": true})


func _close_overlay() -> void:
	_overlay.visible = false
	_refresh_steps()
	_confirm_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if _overlay.visible and event.is_action_pressed("ui_cancel"):
		_close_overlay()
		get_viewport().set_input_as_handled()


# --- Helpers ---------------------------------------------------------------

func _add_label(parent: Node, text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _add_overlay_row(grid: GridContainer, key: String, value: String) -> void:
	var key_label := _add_label(grid, key.to_upper(), "SectionHeading")
	key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var value_label := _add_label(grid, value if not value.is_empty() else "Not recorded",
			"BodySmall")
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
