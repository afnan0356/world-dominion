extends ResponsiveScreen
## Title screen and primary navigation.
##
## The hub is organised into three groups — **Play** (a new campaign, the save to continue,
## every world on this device), **You** (profile and settings) and **Library** (help, roadmap,
## the data, shortcuts, diagnostics, credits). Group headings do for the eye what the old flat
## list could not: they say what belongs with what.
##
## The column **scrolls** rather than shrinking. Rows keep their 52-56 px height and the group
## headings keep their air at every size, including a 360 px-tall phone in landscape; the cost
## is that the Library sits below the fold on a short window, which is a scroll away rather than
## a squeezed, unreadable row. Entries that belong to later tasks in this milestone are visibly
## disabled and labelled "PLANNED" instead of being faked.

signal navigate_requested(screen_id: String)
signal quit_requested()

const SCREEN_CAMPAIGN_SETUP := "campaign_setup"
const SCREEN_LOAD_GAME := "load_game"
const SCREEN_GAME := "game"
const SCREEN_SETTINGS := "settings"
const SCREEN_ABOUT := "about"
const SCREEN_WORLDS := "worlds"
const SCREEN_HELP := "help"
const SCREEN_ROADMAP := "roadmap"
const SCREEN_SHORTCUTS := "shortcuts"
const SCREEN_DIAGNOSTICS := "diagnostics"
const SCREEN_ABOUT_DATA := "about_data"
const SCREEN_PROFILE := "profile"
const _MENU_WIDTH_EXPANDED := 420
const _MENU_WIDTH_MEDIUM := 340
## The floor for a navigation row, whatever the design tokens say. 48 px is the tap target the
## rest of the interface uses, and the menu is the screen most often used one-handed.
const _ROW_FLOOR := 48
## The smallest menu column worth showing before the title and status bar have had their space.
const _MIN_MENU_HEIGHT := 96

var _nav_rows: Array[NavRow] = []
var _version_text_full := ""
var _version_text_short := ""

@onready var _eyebrow: Label = %Eyebrow
@onready var _title: Label = %Title
@onready var _tagline: Label = %Tagline
@onready var _rule: ColorRect = %Rule
@onready var _menu_scroll: ScrollContainer = %MenuScroll
@onready var _menu: VBoxContainer = %Menu
@onready var _left: VBoxContainer = get_node("SafeArea/Layout/Content/Left") as VBoxContainer
@onready var _nav_new: NavRow = %NewCampaign
@onready var _nav_continue: NavRow = %ContinueCampaign
@onready var _nav_worlds: NavRow = %WorldsEntry
@onready var _nav_profile: NavRow = %ProfileEntry
@onready var _nav_settings: NavRow = %SettingsEntry
@onready var _nav_help: NavRow = %HelpEntry
@onready var _nav_roadmap: NavRow = %RoadmapEntry
@onready var _nav_about_data: NavRow = %AboutDataEntry
@onready var _nav_shortcuts: NavRow = %ShortcutsEntry
@onready var _nav_diagnostics: NavRow = %DiagnosticsEntry
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
	_nav_rows = [_nav_new, _nav_continue, _nav_worlds, _nav_profile, _nav_settings,
			_nav_help, _nav_roadmap, _nav_about_data, _nav_shortcuts, _nav_diagnostics,
			_nav_about, _nav_quit]
	# Quit is a platform affordance, and hiding it changes the column's height, so it is
	# decided before the first layout pass rather than after.
	_nav_quit.visible = PlatformInfo.offers_quit_action()
	_mark_planned(_nav_help)
	_mark_planned(_nav_roadmap)
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
	# The two-line wordmark is a luxury: it costs about 80 px of height, which is exactly
	# what the seventh menu row needed on a 720p window. Under 820 px tall the mark goes
	# single-line so the entries stay visible at full size.
	var single_line := is_short or view_size.y < 820.0
	var compact_display := single_line or mode == DesignTokens.LayoutMode.COMPACT
	_title.theme_type_variation = &"DisplayTitleCompact" if compact_display else &"DisplayTitle"
	_title.text = "WORLD DOMINION" if single_line else "WORLD\nDOMINION"
	_eyebrow.visible = not is_short
	_tagline.visible = not is_short
	_mode_label.visible = not is_short and mode != DesignTokens.LayoutMode.COMPACT

	# Rows keep their comfortable height at every size. The column scrolls instead of
	# squeezing: 48 px is the floor, and the design tokens give 56 / 52.
	var row_height := maxi(DesignTokens.nav_row_height(is_short), _ROW_FLOOR)
	for row: NavRow in _nav_rows:
		row.custom_minimum_size.y = row_height
	# Nothing is hidden to buy space any more — the scroll box does that. Every entry is
	# reachable on every window, and the group headings keep their 28 px of air.
	_menu.add_theme_constant_override("separation", DesignTokens.SPACE_4)

	# Vertical rhythm: tight on a phone in landscape, generous on a desktop.
	_spacer_top.custom_minimum_size.y = 2 if is_short else 12
	_spacer_rule.custom_minimum_size.y = 2 if is_short else 16
	# The tagline is hidden at this size, so its spacer goes with it; the menu needs the room.
	_spacer_tagline.custom_minimum_size.y = 0 if is_short else 16
	_spacer_menu.custom_minimum_size.y = DesignTokens.SPACE_8 if is_short else DesignTokens.SPACE_32
	# The version line is a desktop affordance; on very short screens it would cost the
	# menu 50px. The same information lives on the About screen.
	_status_bar.visible = view_size.y >= 400.0
	_update_status_bar(mode)
	_menu_scroll.custom_minimum_size.y = _menu_height(view_size, mode, is_short)

	match mode:
		DesignTokens.LayoutMode.EXPANDED:
			_menu_scroll.custom_minimum_size.x = _MENU_WIDTH_EXPANDED
		DesignTokens.LayoutMode.MEDIUM:
			_menu_scroll.custom_minimum_size.x = _MENU_WIDTH_MEDIUM
		_:
			_menu_scroll.custom_minimum_size.x = 0

	var show_dossier := mode == DesignTokens.LayoutMode.EXPANDED and not is_short
	_dossier.visible = show_dossier
	if show_dossier and _dossier_body.get_child_count() == 0:
		_build_dossier()


# --- Setup -----------------------------------------------------------------

## The menu height: what the rows need, or what the window can spare after the wordmark, the
## margins and the status bar — whichever is smaller. A scroll box that is a few pixels too
## tall would push the status bar off a short window, so this deliberately errs short.
func _menu_height(view_size: Vector2, mode: int, is_short: bool) -> float:
	var natural := _menu.get_combined_minimum_size().y
	var margin := DesignTokens.screen_margin(mode)
	var vertical := DesignTokens.SPACE_12 if is_short else margin
	var chrome := 0.0
	for child: Node in _left.get_children():
		if child == _menu_scroll:
			continue
		chrome += (child as Control).get_combined_minimum_size().y
	var status := _status_bar.get_combined_minimum_size().y if _status_bar.visible else 0.0
	var reserved := float(vertical * 2) + chrome + status + DesignTokens.SPACE_24 * 2.0
	return clampf(minf(natural, view_size.y - reserved), _MIN_MENU_HEIGHT,
			maxf(_MIN_MENU_HEIGHT, natural))


## A row for something this milestone has not built yet: disabled, captioned honestly and
## badged. The other library entries stay live, so the group reads as a group rather than as
## a wall of dead buttons.
func _mark_planned(row: NavRow) -> void:
	row.status_text = "PLANNED"
	row.caption_text = "Not built yet"
	row.disabled = true


func _connect_rows() -> void:
	_nav_new.pressed.connect(_on_navigate.bind(SCREEN_CAMPAIGN_SETUP))
	_nav_continue.pressed.connect(_on_continue_pressed)
	_nav_worlds.pressed.connect(_on_navigate.bind(SCREEN_WORLDS))
	_nav_profile.pressed.connect(_on_navigate.bind(SCREEN_PROFILE))
	_nav_settings.pressed.connect(_on_navigate.bind(SCREEN_SETTINGS))
	_nav_help.pressed.connect(_on_navigate.bind(SCREEN_HELP))
	_nav_roadmap.pressed.connect(_on_navigate.bind(SCREEN_ROADMAP))
	_nav_about_data.pressed.connect(_on_navigate.bind(SCREEN_ABOUT_DATA))
	_nav_shortcuts.pressed.connect(_on_navigate.bind(SCREEN_SHORTCUTS))
	_nav_diagnostics.pressed.connect(_on_navigate.bind(SCREEN_DIAGNOSTICS))
	_nav_about.pressed.connect(_on_navigate.bind(SCREEN_ABOUT))
	_nav_quit.pressed.connect(func() -> void: quit_requested.emit())


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
