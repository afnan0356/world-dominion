extends ResponsiveScreen
## The campaign screen: the first screen that is *inside* a game.
##
## What it is, honestly: a real clock, a real map, a real dossier and a real save
## system. What it is not: a simulation of economies, politics, diplomacy or war —
## none of those exist yet, and the status panel says so in words rather than
## showing placeholder numbers.
##
## The screen owns no game state. It binds to `Game.session` (an autoload), draws
## that session's world, and forwards input. That is what lets the player open
## Settings from the pause menu and come back to the same campaign, and what makes
## leaving to the main menu a single explicit action.
##
## Layout: landscape-first. On wide screens the dossier sits beside the map; on
## narrow or short screens it stacks underneath and scrolls. Nothing is hidden on a
## phone in landscape except panel width.

signal home_requested()
signal navigate_requested(screen_id: String)
signal navigation_requested(screen_id: String, params: Dictionary)

const MAP_SCENE := preload("res://src/ui/map/world_map_view.tscn")
const NAV_ROW := preload("res://src/ui/components/nav_row.tscn")
const SEGMENTED := preload("res://src/ui/components/segmented_control.tscn")
const INFO_PANEL := preload("res://src/ui/components/country_info_panel.gd")
const GUIDE_STEPS: Array = [
	{"title": "The date", "body": "The top bar shows the in-game date. One tick is one "
			+ "in-game day. At this stage of development the calendar is the only thing "
			+ "the simulation does — no economy or politics is running yet."},
	{"title": "Time controls", "body": "The pause button stops the clock. The four speed "
			+ "buttons choose how many in-game days pass per real second. Speeds are "
			+ "measured in days, not frames, so a slower device sees the same world."},
	{"title": "The map", "body": "Drag to pan, scroll or pinch to zoom, tap a country to "
			+ "read its dossier. Your own nation is marked with a ring and the words "
			+ "\"YOUR NATION\" — browsing another country never changes who you lead."},
	{"title": "The pause menu", "body": "Escape opens the pause menu: save, load, "
			+ "settings, this guide and quitting to the main menu. Keyboard: Space pauses, "
			+ "1 to 4 set the speed."},
]

var _map: WorldMapView
var _info: CountryInfoPanel
var _session: GameSession
var _atlas: WorldAtlas

var _date_label: Label
var _status_label: Label
var _player_label: Label
var _country_label: Label
var _autosave_label: Label
var _speed_control: SegmentedControl
var _comparison: Control
## The clock speed to put back when the overlay closes. `resume()` always picks a
## fixed speed, so the overlay remembers what the player had chosen instead.
var _comparison_previous_speed := -1
var _pause_button: Button
var _menu_button: Button
var _map_button: Button
var _map_options_panel: MapOptionsPanel
var _status_block: VBoxContainer
var _status_body: VBoxContainer
var _compact_bar := false
var _tertiary: HBoxContainer
var _bar_secondary: HBoxContainer
var _overlay_root: Control
var _pause_panel: PanelContainer
var _guide_panel: PanelContainer
var _confirm_panel: PanelContainer
var _slot_panel: PanelContainer
var _guide_index := 0
var _guide_label: Label
var _guide_counter: Label
var _autosave_timer: Timer
var _dirty := false
var _anim: AnimationService
var _inspector: MapInspector
var _shortcuts_panel: PanelContainer
var _entrance: ColorRect
var _entrance_label: Label
var _exit_after_save := false


func _ready() -> void:
	super()
	_map = %Map as WorldMapView
	_session = Game.current_session()
	_atlas = Game.get_atlas()
	_build_top_bar()
	_build_side_panel()
	_build_overlays()
	_bind_session()
	_apply_layout_again()


# --- Construction ----------------------------------------------------------

func _build_top_bar() -> void:
	var bar: PanelContainer = %TopBar
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", DesignTokens.SPACE_4)
	bar.add_child(stack)
	var primary := HBoxContainer.new()
	primary.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	stack.add_child(primary)
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	stack.add_child(secondary)
	_bar_secondary = secondary
	# A narrow phone gets a third row: four speed buttons plus a date do not fit
	# across 390 px, and a top bar that wide would stretch the map column with it.
	_tertiary = HBoxContainer.new()
	_tertiary.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	stack.add_child(_tertiary)

	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", 0)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_label = _label("LEADING", "Caption")
	_country_label = _label("—", "Subheading")
	# Country names are long and the top bar must never widen the screen: the name
	# clips with an ellipsis, and the full name is always in the dossier below.
	_country_label.clip_text = true
	_country_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	identity.add_child(_player_label)
	identity.add_child(_country_label)
	primary.add_child(identity)

	_autosave_label = _label("Autosaved", "Caption")
	_autosave_label.visible = false
	_autosave_label.modulate.a = 1.0
	primary.add_child(_autosave_label)

	_pause_button = Button.new()
	_pause_button.text = "Pause"
	_pause_button.theme_type_variation = &"GhostButton"
	_pause_button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	_pause_button.tooltip_text = "Pause or resume the clock. Space does the same."
	_pause_button.pressed.connect(toggle_pause)
	PressFeedback.attach(_pause_button)
	primary.add_child(_pause_button)

	_menu_button = Button.new()
	_menu_button.text = "Menu"
	_menu_button.theme_type_variation = &"GhostButton"
	_menu_button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	_menu_button.tooltip_text = "Open the pause menu. Escape does the same."
	_menu_button.pressed.connect(open_pause_menu)
	PressFeedback.attach(_menu_button)
	primary.add_child(_menu_button)

	_map_button = Button.new()
	_map_button.text = "Map"
	_map_button.theme_type_variation = &"GhostButton"
	_map_button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	_map_button.tooltip_text = "Map display: labels, borders, grid lines and capital markers."
	_map_button.pressed.connect(_open_map_options)
	primary.add_child(_map_button)

	var date_block := VBoxContainer.new()
	date_block.add_theme_constant_override("separation", 0)
	date_block.add_child(_label("IN-GAME DATE", "Caption"))
	_date_label = _label("—", "Subheading")
	date_block.add_child(_date_label)
	secondary.add_child(date_block)

	_status_block = VBoxContainer.new()
	_status_block.add_theme_constant_override("separation", 0)
	_status_block.add_child(_label("SIMULATION", "Caption"))
	_status_label = _label("Paused", "Subheading")
	_status_block.add_child(_status_label)
	secondary.add_child(_status_block)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	secondary.add_child(spacer)

	_speed_control = SEGMENTED.instantiate() as SegmentedControl
	_speed_control.setup(_speed_options(), "1")
	_speed_control.option_selected.connect(_on_speed_selected)
	secondary.add_child(_speed_control)


## Moves the speed control to its own row on the narrowest screens, where it cannot
## share a line with the date without widening the whole screen.
func _place_speed_control(stacked: bool) -> void:
	if _speed_control == null or _tertiary == null or _bar_secondary == null:
		return
	var wanted: HBoxContainer = _tertiary if stacked else _bar_secondary
	if _speed_control.get_parent() != wanted:
		_speed_control.reparent(wanted, false)
	_speed_control.size_flags_horizontal = (Control.SIZE_FILL if stacked
			else Control.SIZE_SHRINK_END)


func _speed_options() -> Array:
	var options: Array = []
	for speed_value: int in [1, 2, 3, 4]:
		options.append({"id": str(speed_value),
				"label": str(GameClock.SPEED_SHORT[speed_value])})
	return options


func _build_side_panel() -> void:
	var body: VBoxContainer = %SideBody
	_info = INFO_PANEL.new()
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.compare_requested.connect(_open_comparison)
	body.add_child(_info)
	body.add_child(HSeparator.new())
	body.add_child(_label("SIMULATION STATUS", "SectionHeading"))
	_status_body = VBoxContainer.new()
	_status_body.add_theme_constant_override("separation", DesignTokens.SPACE_4)
	body.add_child(_status_body)
	body.add_child(HSeparator.new())
	var hint := _label("Tap a country to read its dossier. Your own nation is marked on "
			+ "the map.", "Caption")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)


func _build_overlays() -> void:
	_anim = AnimationService.new(self)
	_overlay_root = %Overlays
	_inspector = MapInspector.new()
	_overlay_root.add_child(_inspector)
	_pause_panel = _build_pause_menu()
	_guide_panel = _build_guide()
	_slot_panel = _build_slot_chooser()
	_map_options_panel = MapOptionsPanel.new()
	_overlay_root.add_child(_map_options_panel)
	_confirm_panel = _build_confirm()
	_autosave_timer = Timer.new()
	_autosave_timer.one_shot = true
	_autosave_timer.wait_time = 2.5
	_autosave_timer.timeout.connect(func() -> void: _autosave_label.visible = false)
	add_child(_autosave_timer)
	_entrance = ColorRect.new()
	_entrance.color = ThemeManager.color(Palette.KEY_BG_BASE)
	_entrance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_entrance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entrance.visible = false
	var entrance_center := CenterContainer.new()
	entrance_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	entrance_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entrance_label = _label("Starting your campaign…", "Subheading")
	entrance_center.add_child(_entrance_label)
	_entrance.add_child(entrance_center)
	_overlay_root.add_child(_entrance)
	_overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _open_map_options() -> void:
	if _map == null or _map_options_panel == null:
		return
	_map_options_panel.open(_map)


func _new_modal(name_value: String) -> PanelContainer:
	var dim := ColorRect.new()
	dim.name = name_value
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelCard"
	panel.custom_minimum_size = Vector2(360.0, 0.0)
	center.add_child(panel)
	_overlay_root.add_child(dim)
	return panel


func _build_pause_menu() -> PanelContainer:
	var panel := _new_modal("PauseMenu")
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	panel.add_child(body)
	body.add_child(_label("PAUSED", "Eyebrow"))
	body.add_child(_wrap(_label("The clock is stopped while this menu is open.", "BodySmall")))
	var entries: Array = [
		["Resume", func() -> void: close_pause_menu()],
		["Save", func() -> void: save_to_slot("1")],
		["Save as…", func() -> void: _open_slot_chooser()],
		["Load game", func() -> void: navigation_requested.emit("load_game", {"from_game": true})],
		["Settings", func() -> void: navigate_requested.emit("settings")],
		["Show the guide again", func() -> void: open_guide()],
		["Keyboard shortcuts", func() -> void: _toggle_shortcuts()],
		["Map inspector", func() -> void: _toggle_inspector()],
		["About this version", func() -> void: navigate_requested.emit("about")],
		["Quit to main menu", func() -> void: _request_quit()],
	]
	for entry: Array in entries:
		var row: NavRow = NAV_ROW.instantiate()
		row.title_text = str(entry[0])
		row.pressed.connect(entry[1])
		body.add_child(row)
	var version_line := _wrap(_label("Early foundation: this build has a calendar, a map "
			+ "and saves. It has no economy, politics or country AI yet.", "Caption"))
	body.add_child(version_line)
	return panel


func _build_guide() -> PanelContainer:
	var panel := _new_modal("Guide")
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	panel.add_child(body)
	body.add_child(_label("GETTING STARTED", "Eyebrow"))
	_guide_counter = _label("", "Caption")
	body.add_child(_guide_counter)
	var title := _label("", "Subheading")
	title.name = "GuideTitle"
	body.add_child(title)
	_guide_label = _wrap(_label("", "BodySmall"))
	body.add_child(_guide_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	var skip := Button.new()
	skip.text = "Skip"
	skip.theme_type_variation = &"GhostButton"
	skip.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	skip.pressed.connect(close_guide)
	actions.add_child(skip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var next := Button.new()
	next.text = "Next"
	next.theme_type_variation = &"PrimaryButton"
	next.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	next.pressed.connect(_advance_guide)
	actions.add_child(next)
	body.add_child(actions)
	return panel


func _build_slot_chooser() -> PanelContainer:
	var panel := _new_modal("SlotChooser")
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	panel.add_child(body)
	body.add_child(_label("SAVE AS", "Eyebrow"))
	body.add_child(_label("Choose a slot. Saving over a slot keeps one backup of the "
			+ "previous save.", "Caption"))
	for slot: String in ["1", "2", "3"]:
		var row: NavRow = NAV_ROW.instantiate()
		row.title_text = "Slot %s" % slot
		row.pressed.connect(func() -> void: save_to_slot(slot))
		body.add_child(row)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.theme_type_variation = &"GhostButton"
	cancel.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	cancel.pressed.connect(func() -> void: panel.get_parent().get_parent().visible = false)
	body.add_child(cancel)
	return panel


func _build_confirm() -> PanelContainer:
	var panel := _new_modal("QuitConfirm")
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	panel.add_child(body)
	body.add_child(_label("LEAVE THE CAMPAIGN?", "Eyebrow"))
	body.add_child(_wrap(_label("The autosave keeps your progress. Anything since the last "
			+ "autosave will be lost if you leave now.", "BodySmall")))
	var save_first := Button.new()
	save_first.text = "Save to slot 1 and quit"
	save_first.theme_type_variation = &"PrimaryButton"
	save_first.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	save_first.pressed.connect(func() -> void:
		_exit_after_save = true
		save_to_slot("1"))
	body.add_child(save_first)
	var quit_anyway := Button.new()
	quit_anyway.text = "Quit without saving"
	quit_anyway.theme_type_variation = &"GhostButton"
	quit_anyway.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	quit_anyway.pressed.connect(func() -> void: _leave_campaign())
	body.add_child(quit_anyway)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.theme_type_variation = &"GhostButton"
	cancel.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	cancel.pressed.connect(func() -> void: panel.get_parent().get_parent().visible = false)
	body.add_child(cancel)
	return panel


# --- Session binding -------------------------------------------------------

func _bind_session() -> void:
	if _session == null or _session.world == null or _atlas == null or not _atlas.is_ready():
		_show_missing_session()
		return
	_map.set_atlas(_atlas)
	_map.set_detail_reduced(Settings.get_map_detail() == SettingsSchema.DETAIL_REDUCED)
	_map.mark_home(_session.world.player_country_id)
	_map.set_selected(_session.world.player_country_id)
	_map.country_activated.connect(_on_country_activated)
	_country_label.text = _session.world.player_country_name
	_country_label.tooltip_text = _session.world.player_country_name
	_refresh_clock_labels()
	_refresh_status_panel()
	_info.set_context(_dossier_context())
	var record := _atlas.registry.get_country(_session.world.player_country_id)
	if record != null:
		_info.show_country(record, _dossier_context())
		_map.focus_country(_session.world.player_country_id)
	_session.month_started.connect(_on_month_started)
	if not Settings.get_guide_seen():
		call_deferred("open_guide")


func _show_missing_session() -> void:
	_country_label.text = "No campaign"
	_date_label.text = "—"
	_status_label.text = "Stopped"
	var message := _wrap(_label("There is no campaign running. Start a new campaign or load "
			+ "a save from the main menu.", "BodySmall"))
	_status_body.add_child(message)


func _dossier_context() -> Dictionary:
	return {
		"atlas": _atlas,
		"registry": _atlas.registry if _atlas != null and _atlas.is_ready() else null,
		"scenario_name": _session.world.scenario_name if _session != null else "",
		"player_country_id": _session.world.player_country_id if _session != null else "",
		"statistics": _atlas.statistics if _atlas != null else null,
		"dataset": _atlas.manifest.get("source", {}).get("dataset", "") if _atlas != null else "",
		"dataset_version": _atlas.manifest.get("source", {}).get("version", "") if _atlas != null else "",
		"dataset_commit": _atlas.manifest.get("source", {}).get("commit", "") if _atlas != null else "",
		"licence": _atlas.manifest.get("source", {}).get("licence", "") if _atlas != null else "",
		"retrieved": _atlas.manifest.get("source", {}).get("retrieved", "") if _atlas != null else "",
	}


func _refresh_status_panel() -> void:
	for child: Node in _status_body.get_children():
		child.queue_free()
	if _session == null:
		return
	for line: String in _session.status_lines():
		_status_body.add_child(_wrap(_label(line, "BodySmall")))


## Fades a label or button back up from 40% so a change of state is noticeable
## without a flash. Under reduced motion the value is applied at once and no tween
## exists — the text simply reads differently, which is the whole point.
func _emphasise(animation: String, targets: Array) -> void:
	if _anim == null:
		return
	for target: Control in targets:
		if target == null:
			continue
		target.modulate.a = 0.4
		_anim.play(animation, target, "modulate:a", 1.0)


func _refresh_clock_labels() -> void:
	if _session == null or _session.world == null:
		return
	var date := _session.world.current_date()
	_date_label.text = (date.format_short() if _compact_bar else date.format_long()).to_upper()
	_status_label.text = _session.simulation.clock.speed_label()
	_pause_button.text = "Resume" if _session.simulation.clock.is_paused() else "Pause"
	_speed_control.set_selected(str(maxi(1, _session.simulation.clock.speed)))
	_player_label.text = "LEADING · %s" % _session.playtime_label().to_upper()


# --- Layout ----------------------------------------------------------------

func on_layout_changed(mode: int, is_short: bool, view_size: Vector2) -> void:
	if _map == null:
		return
	# Width decides the arrangement: a landscape phone has room beside the map even
	# though it has little height, and stacking there would leave the map a strip.
	var side_by_side := view_size.x >= 700.0
	var body: BoxContainer = %Body
	var side: PanelContainer = %SidePanel
	body.vertical = not side_by_side
	if side_by_side:
		side.custom_minimum_size.x = DesignTokens.DOSSIER_WIDTH if view_size.x >= 900.0 \
				else minf(280.0, view_size.x * 0.38)
		side.custom_minimum_size.y = 0.0
		side.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side.size_flags_horizontal = Control.SIZE_FILL
	else:
		side.custom_minimum_size.x = 0.0
		# The panel takes a share of the height rather than a fixed slab, so the map
		# keeps at least a usable band on a 640×360 window.
		side.custom_minimum_size.y = clampf(view_size.y * 0.34, 96.0, 260.0)
		side.size_flags_vertical = Control.SIZE_FILL
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top: PanelContainer = %TopBar
	top.add_theme_constant_override("margin_left", DesignTokens.SPACE_12)
	top.add_theme_constant_override("margin_right", DesignTokens.SPACE_12)
	# On a narrow screen the status word is redundant with the pause button's own
	# label ("Pause" / "Resume"), so it gives up its space rather than widening the
	# bar past the screen.
	# A short window gets the compact bar too: the map needs the height more than the
	# status word does.
	_compact_bar = mode == DesignTokens.LayoutMode.COMPACT or view_size.x < 700.0 or is_short
	# A short window gives 8 px of every bar control back to the map. The buttons are
	# still 40 px, which is a finger target; 48 px is what a roomy layout gets.
	var bar_height := DesignTokens.control_height(is_short)
	for button: Button in [_pause_button, _menu_button, _map_button]:
		if button != null:
			button.custom_minimum_size.y = bar_height
	if _status_block != null:
		_status_block.visible = not _compact_bar
	_place_speed_control(view_size.x < 480.0)
	_refresh_clock_labels()


func _apply_layout_again() -> void:
	on_layout_changed(DesignTokens.layout_mode(size), size.y < DesignTokens.HEIGHT_SHORT, size)


# --- Country comparison ----------------------------------------------------
# The comparison screen is a screen in its own right, but leaving a live campaign to
# visit it would destroy the session. So the game hosts the same scene as an overlay
# and pauses the clock while it is open: one implementation, reachable from both the
# atlas and the campaign dossier.

## Opens the comparison overlay with one country already chosen. Public because the
## tests drive it directly and the dossier button calls the same path.
func _open_comparison(country_id: String) -> void:
	if _comparison != null:
		_comparison.queue_free()
		_comparison = null
	var scene: PackedScene = load("res://src/ui/screens/comparison_screen.tscn")
	if scene == null:
		return
	var overlay := scene.instantiate() as Control
	if overlay == null:
		return
	_comparison = overlay
	_comparison_previous_speed = -1
	if _session != null and not _session.simulation.clock.is_paused():
		_comparison_previous_speed = _session.simulation.clock.speed
		_session.simulation.clock.pause()
	overlay.back_requested.connect(_close_comparison)
	_overlay_root.add_child(overlay)
	if overlay.has_method("receive_params"):
		overlay.call("receive_params", {"country_id": country_id})
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _close_comparison() -> void:
	if _comparison != null:
		_comparison.queue_free()
		_comparison = null
	if _comparison_previous_speed >= 0 and _session != null:
		_session.simulation.clock.set_speed(_comparison_previous_speed)
	_comparison_previous_speed = -1


func _comparison_open() -> bool:
	return _comparison != null


# --- Simulation loop -------------------------------------------------------

func _process(delta: float) -> void:
	if _session == null or _session.world == null:
		return
	if _pause_menu_open() or _guide_open() or _slot_open() or _confirm_open() \
			or _comparison_open():
		# Menus pause the clock. A menu that let a day pass while the player reads it
		# would be surprising, and it would also mean the pause menu does not pause.
		return
	var ticks := _session.tick(delta)
	if ticks > 0:
		_dirty = true
		_refresh_clock_labels()
	var result := _session.drain_pending_autosave()
	if not result.is_empty():
		_on_autosaved(result)


func _on_country_activated(country_id: String) -> void:
	# Browsing never changes who the player leads: the dossier follows the tap, the
	# home badge and the campaign stay where they are.
	if country_id.is_empty():
		_info.show_empty()
		return
	var record := _atlas.registry.get_country(country_id)
	if record == null:
		_info.show_unavailable("That country is not in this build's world data.")
		return
	_info.show_country(record, _dossier_context())


func _on_month_started(label: String) -> void:
	if _session != null and _session.autosave_enabled:
		_autosave_label.text = "Autosaving · %s" % label


func _on_autosaved(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		_autosave_label.text = "Autosave failed"
		_autosave_label.visible = true
		return
	_dirty = false
	_autosave_label.text = "Autosaved"
	_autosave_label.visible = true
	_autosave_label.modulate.a = 1.0
	if _autosave_timer != null:
		_autosave_timer.start()
	if _exit_after_save:
		_exit_after_save = false
		_leave_campaign()


func performance_counts() -> String:
	if _map == null:
		return ""
	var stats := _map.draw_stats()
	var ticks := _session.simulation.total_ticks if _session != null else 0
	var store := Game.store if Game != null else null
	if store == null:
		return "visible countries %d · labels %d · capital markers %d · ticks %d" % [
			int(stats.get("visible_countries", 0)), int(stats.get("labels", 0)),
			int(stats.get("capitals", 0)), ticks]
	# Save and load cost are shown because they are the numbers a phone can change and
	# a container cannot: the owner needs them without a profiler.
	return ("visible countries %d · labels %d · capital markers %d · ticks %d"
			+ "\nlast save %.2f ms · last load %.2f ms") % [
		int(stats.get("visible_countries", 0)), int(stats.get("labels", 0)),
		int(stats.get("capitals", 0)), ticks,
		store.last_save_milliseconds, store.last_load_milliseconds]


# --- Controls (public, also used by the tests) -----------------------------

func session() -> GameSession:
	return _session


func player_country_id() -> String:
	return _session.world.player_country_id if _session != null else ""


func viewed_country_id() -> String:
	return _info.selected_id() if _info != null else ""


func is_paused() -> bool:
	return _session == null or _session.simulation.clock.is_paused()


func set_speed(speed_value: int) -> void:
	if _session == null:
		return
	_session.simulation.clock.set_speed(speed_value)
	_refresh_clock_labels()


func toggle_pause() -> void:
	if _session == null:
		return
	_session.simulation.clock.toggle_pause()
	_refresh_clock_labels()
	_emphasise("pause_change", [_status_label, _pause_button])


func save_to_slot(slot: String) -> Dictionary:
	var result := {"ok": false, "player_error": "There is no campaign to save."}
	if _session != null:
		result = _session.save_to(slot)
	var panel := _slot_panel.get_parent().get_parent() as Control
	if panel != null:
		panel.visible = false
	if not bool(result["ok"]) and _pause_panel != null:
		_show_toast(str(result.get("player_error", "Saving failed.")))
	else:
		_dirty = false
		_on_autosaved(result)
	return result


func save_slot_count() -> int:
	return 3


func pause_menu_open() -> bool:
	return _pause_menu_open()


func guide_open() -> bool:
	return _guide_open()


## The cheat sheet as a panel over the campaign: routing to a screen would unload the
## running campaign, which is not what a player pressing a "what does this key do" key
## wants. The rows come from the same table the shortcut screen renders.
func _toggle_shortcuts() -> void:
	if _shortcuts_panel == null:
		_shortcuts_panel = _new_modal("Shortcuts")
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", DesignTokens.SPACE_4)
		_shortcuts_panel.add_child(body)
		body.add_child(_label("KEYBOARD SHORTCUTS", "Eyebrow"))
		body.add_child(_wrap(_label(Shortcuts.INTRO, "Caption")))
		for entry: Array in Shortcuts.ENTRIES:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", DesignTokens.SPACE_12)
			var keys := _label(str(entry[0]), "Mono")
			keys.custom_minimum_size.x = 120.0
			line.add_child(keys)
			var action := _label(str(entry[1]), "BodySmall")
			action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(action)
			body.add_child(line)
		var close_button := Button.new()
		close_button.text = "Close"
		close_button.theme_type_variation = &"PrimaryButton"
		close_button.custom_minimum_size.y = DesignTokens.TOUCH_TARGET_MIN
		close_button.pressed.connect(_toggle_shortcuts)
		PressFeedback.attach(close_button)
		body.add_child(close_button)
	var root := _shortcuts_panel.get_parent().get_parent() as Control
	root.visible = not root.visible
	if root.visible:
		_reveal_modal(_shortcuts_panel)
		_focus_first(_shortcuts_panel)


## Developer overlay, off until asked for. It never changes what the map draws; it
## reports what was loaded.
func _toggle_inspector() -> void:
	_inspector.visible = not _inspector.visible
	if _inspector.visible:
		var country_id := ""
		if _session != null and _session.world != null:
			country_id = _session.world.player_country_id
		_inspector.set_entry(_atlas, country_id)
		_inspector.position = Vector2(DesignTokens.SPACE_16, DesignTokens.SPACE_16)


## A modal fades and settles into place instead of appearing abruptly. Under
## reduced motion the service applies the final values immediately, and the panel is
## simply there — visible, focused and fully opaque.
func _reveal_modal(panel: Control) -> void:
	if _anim == null:
		return
	panel.modulate.a = 0.0
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.985, 0.985)
	_anim.play("panel_fade", panel, "modulate:a", 1.0, "modal")
	_anim.play("panel_slide", panel, "scale", Vector2.ONE, "modal")


func open_pause_menu() -> void:
	if _session != null and not _session.simulation.clock.is_paused():
		_session.simulation.clock.pause()
	_refresh_clock_labels()
	(_pause_panel.get_parent().get_parent() as Control).visible = true
	_reveal_modal(_pause_panel)
	_focus_first(_pause_panel)


func close_pause_menu() -> void:
	if _anim != null:
		_anim.cancel("modal")
	(_pause_panel.get_parent().get_parent() as Control).visible = false
	_refresh_clock_labels()


func open_guide() -> void:
	_guide_index = 0
	_render_guide()
	(_guide_panel.get_parent().get_parent() as Control).visible = true
	_reveal_modal(_guide_panel)


func close_guide() -> void:
	(_guide_panel.get_parent().get_parent() as Control).visible = false
	Settings.set_guide_seen(true)


func guide_step_count() -> int:
	return GUIDE_STEPS.size()


func guide_text() -> String:
	return _guide_label.text if _guide_label != null else ""


# --- Events ----------------------------------------------------------------

func _on_speed_selected(option_id: String) -> void:
	set_speed(int(option_id))
	_emphasise("speed_change", [_status_label])


func _request_quit() -> void:
	if _session != null and _dirty:
		(_confirm_panel.get_parent().get_parent() as Control).visible = true
		return
	_leave_campaign()


func _leave_campaign() -> void:
	if _session != null:
		_session.autosave()
	Game.close()
	home_requested.emit()


func _open_slot_chooser() -> void:
	(_slot_panel.get_parent().get_parent() as Control).visible = true


func _advance_guide() -> void:
	_guide_index += 1
	if _guide_index >= GUIDE_STEPS.size():
		close_guide()
		return
	_render_guide()


func _render_guide() -> void:
	var step: Dictionary = GUIDE_STEPS[_guide_index]
	var title: Label = _guide_panel.find_child("GuideTitle", true, false) as Label
	if title != null:
		title.text = str(step["title"])
	_guide_label.text = str(step["body"])
	_guide_counter.text = "Step %d of %d" % [_guide_index + 1, GUIDE_STEPS.size()]


func _pause_menu_open() -> bool:
	return (_pause_panel.get_parent().get_parent() as Control).visible


func _guide_open() -> bool:
	return (_guide_panel.get_parent().get_parent() as Control).visible


func _slot_open() -> bool:
	return (_slot_panel.get_parent().get_parent() as Control).visible


func _confirm_open() -> bool:
	return (_confirm_panel.get_parent().get_parent() as Control).visible


func _show_toast(message: String) -> void:
	_autosave_label.text = message
	_autosave_label.visible = true
	if _autosave_timer != null:
		_autosave_timer.start()


func _focus_first(node: Node) -> void:
	for child: Node in node.find_children("*", "Button", true, false):
		var button := child as Button
		if button != null and button.is_visible_in_tree() and not button.disabled:
			button.grab_focus()
			return


func _unhandled_input(event: InputEvent) -> void:
	if _entrance != null and _entrance.visible and (event is InputEventKey
			or event is InputEventMouseButton or event is InputEventScreenTouch):
		_skip_entrance()
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	match key:
		KEY_SPACE:
			toggle_pause()
		KEY_1, KEY_2, KEY_3, KEY_4:
			set_speed(key - KEY_0)
		KEY_F1:
			_toggle_shortcuts()
		KEY_F4:
			_toggle_inspector()
		KEY_ESCAPE:
			if _guide_open():
				close_guide()
			elif _slot_open() or _confirm_open():
				(_slot_panel.get_parent().get_parent() as Control).visible = false
				(_confirm_panel.get_parent().get_parent() as Control).visible = false
			elif _pause_menu_open():
				close_pause_menu()
			else:
				open_pause_menu()
		_:
			return
	get_viewport().set_input_as_handled()


# --- Entrance --------------------------------------------------------------

## A short, skippable "starting your campaign" transition. Reduced motion means no
## animation at all: the label appears and disappears, the game is immediately
## interactive.
## Any deliberate input dismisses the opening overlay at once. It is a transition,
## not a gate: nothing is waiting for it.
func _skip_entrance() -> void:
	if _entrance == null or not _entrance.visible:
		return
	if _anim != null:
		_anim.cancel("start")
	_entrance.visible = false


func play_entrance() -> void:
	if _entrance == null:
		return
	var reduce := Settings.get_reduce_motion()
	if reduce:
		_entrance.visible = false
		return
	_entrance.visible = true
	_entrance.modulate.a = 1.0
	if _anim == null:
		_anim = AnimationService.new(self)
	# The opening overlay is purely cosmetic and can be dismissed by any input; the
	# button that skips it lives in the top bar, which is never covered by it.
	var tween := _anim.play("campaign_start", _entrance, "modulate:a", 0.0, "start")
	if tween != null:
		tween.finished.connect(func() -> void: _entrance.visible = false)


func _label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label


func _wrap(label: Label) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
