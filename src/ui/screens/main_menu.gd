extends ResponsiveScreen
## Title screen and primary navigation.
##
## This is the application shell's hub. Entries that belong to later milestones
## are visibly disabled and labelled "PLANNED" instead of being faked; the
## dossier column on wide screens states exactly what works in this build.

signal navigate_requested(screen_id: String)
signal quit_requested()

const SCREEN_CAMPAIGN_SETUP := "campaign_setup"
const SCREEN_LOAD_GAME := "load_game"
const SCREEN_GAME := "game"
const SCREEN_SETTINGS := "settings"
const SCREEN_ABOUT := "about"
const _MENU_WIDTH_EXPANDED := 420
const _MENU_WIDTH_MEDIUM := 340

var _nav_rows: Array[NavRow] = []
var _version_text_full := ""
var _version_text_short := ""

@onready var _eyebrow: Label = %Eyebrow
@onready var _title: Label = %Title
@onready var _tagline: Label = %Tagline
@onready var _rule: ColorRect = %Rule
@onready var _menu: VBoxContainer = %Menu
@onready var _nav_new: NavRow = %NewCampaign
@onready var _nav_continue: NavRow = %ContinueCampaign
@onready var _nav_load: NavRow = %LoadGameEntry
@onready var _nav_settings: NavRow = %SettingsEntry
@onready var _nav_about: NavRow = %AboutEntry
@onready var _nav_quit: NavRow = %QuitEntry
@onready var _dossier: PanelContainer = %Dossier
@onready var _dossier_body: VBoxContainer = %DossierBody
@onready var _version_label: Label = %VersionLabel
@onready var _mode_label: Label = %ModeLabel
@onready var _spacer_top: Control = %SpacerTop
@onready var _spacer_rule: Control = %SpacerRuleTop
@onready var _spacer_tagline: Control = %SpacerTaglineTop
@onready var _spacer_menu: Control = %SpacerMenuTop
@onready var _status_bar: VBoxContainer = %StatusBar
@onready var _spacer_bar: Control = %SpacerBar


func _ready() -> void:
	# The row list must exist before `super()` runs, because the base class
	# applies the responsive layout (which sets row heights) during `_ready`.
	_nav_rows = [_nav_new, _nav_continue, _nav_load, _nav_settings, _nav_about, _nav_quit]
	super()
	_connect_rows()
	_refresh_continue()
	_dossier.custom_minimum_size.x = DesignTokens.DOSSIER_WIDTH
	_build_status_bar()
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_apply_accent_color()


# --- Public API used by the router -----------------------------------------

func play_entrance() -> void:
	var reduce := Settings.get_reduce_motion()
	var targets: Array[Control] = [_eyebrow, _title, _rule, _tagline]
	for row: NavRow in _nav_rows:
		targets.append(row)
	var step := 0
	for target: Control in targets:
		if not target.visible:
			continue
		target.modulate.a = 0.0
		var duration := Motion.duration(DesignTokens.DURATION_BASE, reduce)
		if duration <= 0.0:
			target.modulate.a = 1.0
			continue
		var tween := create_tween()
		Motion.ease_ui(tween)
		var delay := Motion.stagger(step, reduce)
		if delay > 0.0:
			tween.tween_interval(delay)
		tween.tween_property(target, "modulate:a", 1.0, duration)
		step += 1


func on_layout_changed(mode: int, is_short: bool, view_size: Vector2) -> void:
	var compact_display := is_short or mode == DesignTokens.LayoutMode.COMPACT
	_title.theme_type_variation = &"DisplayTitleCompact" if compact_display else &"DisplayTitle"
	_title.text = "WORLD DOMINION" if is_short else "WORLD\nDOMINION"
	_eyebrow.visible = not is_short
	_tagline.visible = not is_short
	_mode_label.visible = not is_short and mode != DesignTokens.LayoutMode.COMPACT

	var row_height := DesignTokens.nav_row_height(is_short)
	if is_short:
		# Six entries at 52 px would push the last one off a 360 px-tall phone. 44 px
		# is still the minimum touch target, so nothing becomes unusable.
		row_height = mini(row_height, 44)
	elif view_size.y < 820.0:
		# A 720p window is the common desktop size and has less room than it looks.
		row_height = mini(row_height, 48)
	for row: NavRow in _nav_rows:
		row.custom_minimum_size.y = row_height
	# The About screen is also reachable from the pause menu, so on a window too short
	# to hold every entry the entry gives up its place instead of clipping the list.
	_nav_about.visible = view_size.y >= 480.0

	# Vertical rhythm: tight on a phone in landscape, generous on a desktop.
	_spacer_top.custom_minimum_size.y = 4 if is_short else 12
	_spacer_rule.custom_minimum_size.y = 4 if is_short else 16
	_spacer_tagline.custom_minimum_size.y = 4 if is_short else 16
	_spacer_menu.custom_minimum_size.y = 8 if is_short else 32
	# The version line is a desktop affordance; on very short screens it would
	# cost the menu 50px. The same information lives on the About screen.
	_status_bar.visible = view_size.y >= 400.0
	_update_status_bar(mode)

	match mode:
		DesignTokens.LayoutMode.EXPANDED:
			_menu.custom_minimum_size.x = _MENU_WIDTH_EXPANDED
		DesignTokens.LayoutMode.MEDIUM:
			_menu.custom_minimum_size.x = _MENU_WIDTH_MEDIUM
		_:
			_menu.custom_minimum_size.x = 0

	var show_dossier := mode == DesignTokens.LayoutMode.EXPANDED and not is_short
	_dossier.visible = show_dossier
	if show_dossier and _dossier_body.get_child_count() == 0:
		_build_dossier()


# --- Setup -----------------------------------------------------------------

func _connect_rows() -> void:
	_nav_new.pressed.connect(_on_navigate.bind(SCREEN_CAMPAIGN_SETUP))
	_nav_continue.pressed.connect(_on_continue_pressed)
	_nav_load.pressed.connect(_on_navigate.bind(SCREEN_LOAD_GAME))
	_nav_settings.pressed.connect(_on_navigate.bind(SCREEN_SETTINGS))
	_nav_about.pressed.connect(_on_navigate.bind(SCREEN_ABOUT))
	_nav_quit.pressed.connect(func() -> void: quit_requested.emit())
	_nav_quit.visible = PlatformInfo.offers_quit_action()


## Continue is enabled only when a save actually loads. An entry that promises to
## resume a game and then cannot is worse than one that says there is nothing yet.
func _refresh_continue() -> void:
	var has_save := false
	var caption := "No saves yet"
	if Game.has_valid_save():
		has_save = true
		var entries := Game.slot_entries()
		caption = "Most recent valid save"
		for entry: Dictionary in entries:
			if bool(entry["valid"]) and str(entry["slot"]) == Game.latest_slot():
				caption = "%s · %s" % [str(entry["summary"].get("player_country_name", "")),
						str(entry["summary"].get("date_label", ""))]
				break
	_nav_continue.disabled = not has_save
	_nav_continue.status_text = "" if has_save else "No saves"
	_nav_continue.caption_text = caption


func _on_continue_pressed() -> void:
	var slot := Game.latest_slot()
	if slot.is_empty():
		_refresh_continue()
		return
	var result := Game.resume(slot)
	if bool(result["ok"]):
		navigate_requested.emit(SCREEN_GAME)
		return
	# A save that passed the cheap check but failed the full one: say why, and open
	# the Load screen where the backup can be restored.
	navigate_requested.emit(SCREEN_LOAD_GAME)


func _build_status_bar() -> void:
	var version := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var meta := DataLoader.load_dictionary("app_meta.json")
	var milestone := str(meta.get("milestone_label", "Milestone 01"))
	var words := milestone.split(" ")
	# "Milestone 01 — Foundation" is trimmed to "Milestone 01" on narrow screens.
	var short_milestone := " ".join(words.slice(0, 2)) if words.size() >= 2 else milestone
	_version_text_full = ("v%s  ·  %s" % [version, milestone]).to_upper()
	_version_text_short = ("v%s  ·  %s" % [version, short_milestone]).to_upper()
	var engine := Engine.get_version_info()
	var engine_line: String = "Godot %d.%d  ·  %s" % [
		int(engine.get("major", 0)), int(engine.get("minor", 0)), PlatformInfo.describe()]
	_mode_label.text = engine_line.to_upper()
	_update_status_bar(DesignTokens.layout_mode(size))


## On a narrow bar the version label owns the whole width and ellipsises rather
## than pushing the line past the screen margin; everywhere else it keeps its
## natural width and the spacer holds the engine line on the right.
func _update_status_bar(mode: int) -> void:
	var compact_bar := mode == DesignTokens.LayoutMode.COMPACT
	_version_label.text = _version_text_short if compact_bar else _version_text_full
	_version_label.clip_text = compact_bar
	_version_label.text_overrun_behavior = (TextServer.OVERRUN_TRIM_ELLIPSIS if compact_bar
			else TextServer.OVERRUN_NO_TRIMMING)
	_version_label.size_flags_horizontal = (Control.SIZE_EXPAND_FILL if compact_bar
			else Control.SIZE_FILL)
	_spacer_bar.visible = not compact_bar


func _build_dossier() -> void:
	var meta := DataLoader.load_dictionary("app_meta.json")
	_add_label(_dossier_body, "BUILD STATUS", "SectionHeading")
	_dossier_body.add_child(_build_status_grid(meta))
	_dossier_body.add_child(HSeparator.new())
	_add_label(_dossier_body, "IN THIS BUILD", "SectionHeading")
	for item: Variant in DataLoader.get_typed(meta, "implemented", TYPE_ARRAY, []):
		_dossier_body.add_child(_build_bullet(str(item), true))
	_dossier_body.add_child(HSeparator.new())
	_add_label(_dossier_body, "PLANNED NEXT", "SectionHeading")
	for item: Variant in DataLoader.get_typed(meta, "planned_next", TYPE_ARRAY, []):
		_dossier_body.add_child(_build_bullet(str(item), false))


func _build_status_grid(meta: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", DesignTokens.SPACE_16)
	grid.add_theme_constant_override("v_separation", DesignTokens.SPACE_8)
	var rows: Array = DataLoader.get_typed(meta, "status", TYPE_ARRAY, [])
	for entry: Variant in rows:
		if not entry is Dictionary:
			continue
		var row: Dictionary = entry
		var key_label := _make_label(str(row.get("key", "")), "Caption")
		key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid.add_child(key_label)
		var value_label := _make_label(str(row.get("value", "")), "Value")
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		# Without wrapping, one long status word would widen the whole column and
		# push the screen past the window.
		value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(value_label)
	return grid


func _build_bullet(text: String, implemented: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	var marker := ColorRect.new()
	marker.custom_minimum_size = Vector2(DesignTokens.BORDER_ACCENT, DesignTokens.SPACE_12)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.color = ThemeManager.color(Palette.KEY_ACCENT) if implemented \
			else ThemeManager.color(Palette.KEY_BORDER_STRONG)
	row.add_child(marker)
	var label := _make_label(text, "BodySmall")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(label)
	return row


func _add_label(parent: Node, text: String, variation: String) -> void:
	parent.add_child(_make_label(text, variation))


func _make_label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# --- Events ----------------------------------------------------------------

func _on_navigate(screen_id: String) -> void:
	navigate_requested.emit(screen_id)


func _on_theme_changed(_palette_id: String) -> void:
	_apply_accent_color()
	# Markers and separators in the dossier are drawn from palette colours, so the
	# column is rebuilt rather than recoloured node by node.
	if _dossier.visible:
		for child: Node in _dossier_body.get_children():
			_dossier_body.remove_child(child)
			child.queue_free()
		_build_dossier()


func _apply_accent_color() -> void:
	_rule.color = ThemeManager.color(Palette.KEY_ACCENT)
