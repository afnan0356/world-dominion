extends ResponsiveScreen
## Settings screen.
##
## Everything on this screen is functional: the theme, the interface scale and
## the motion preference are applied immediately and persisted to a local file.
## Nothing here is a placeholder for a future feature.

signal back_requested()

const _SETTING_ROW := preload("res://src/ui/components/setting_row.tscn")
const _SEGMENTED := preload("res://src/ui/components/segmented_control.tscn")
const _RESET_ICON := preload("res://assets/icons/reset.svg")
const _RESET_CONFIRM_SECONDS := 4.0

var _theme_control: SegmentedControl
var _scale_control: SegmentedControl
var _motion_control: SegmentedControl
var _reset_button: Button
var _reset_timer: Timer
var _save_warning: Label
var _confirming_reset := false

@onready var _header: AppHeader = %Header
@onready var _scroll: ScrollContainer = %Scroll
@onready var _content: VBoxContainer = %Content


func _ready() -> void:
	super()
	_header.back_pressed.connect(func() -> void: back_requested.emit())
	_reset_timer = Timer.new()
	_reset_timer.one_shot = true
	_reset_timer.wait_time = _RESET_CONFIRM_SECONDS
	_reset_timer.timeout.connect(_cancel_reset)
	add_child(_reset_timer)
	Settings.changed.connect(_on_setting_changed)
	Settings.reset.connect(_refresh_controls)
	_build_form()
	_refresh_controls()


func on_layout_changed(_mode: int, is_short: bool, view_size: Vector2) -> void:
	_header.set_compact(is_short)
	var margin := DesignTokens.screen_margin(DesignTokens.layout_mode(view_size))
	var available := view_size.x - float(margin * 2) - DesignTokens.SPACE_24
	_content.custom_minimum_size.x = clampf(available, 240.0, float(DesignTokens.CONTENT_MEASURE))


# --- Form construction -----------------------------------------------------

func _build_form() -> void:
	var appearance := _add_section("APPEARANCE", "How the interface looks. Changes apply immediately.")
	_theme_control = _new_segmented()
	_theme_control.setup(_palette_options(), Settings.get_theme_id())
	_theme_control.option_selected.connect(func(palette_id: String) -> void:
		Settings.set_theme_id(palette_id))
	appearance.add_child(_new_row("Theme",
			"Midnight is built for long sessions and dark rooms; Parchment is a warm light surface.",
			_theme_control))

	_scale_control = _new_segmented()
	_scale_control.setup(_scale_options(), str(Settings.get_ui_scale()))
	_scale_control.option_selected.connect(func(option_id: String) -> void:
		Settings.set_ui_scale(float(option_id)))
	appearance.add_child(_new_row("Interface scale",
			"Scales text and controls across the whole game.", _scale_control))

	var motion := _add_section("MOTION", "")
	_motion_control = _new_segmented()
	_motion_control.setup(_motion_options(), Settings.get_motion_mode())
	_motion_control.option_selected.connect(func(option_id: String) -> void:
		Settings.set_motion_mode(option_id))
	motion.add_child(_new_row("Interface transitions",
			"Reduced motion removes screen fades and hover animations.", _motion_control))

	var privacy := _add_section("PRIVACY & DATA", "")
	var privacy_text := _new_label(
			"Settings are stored in a single local file on this device. "
			+ "WORLD DOMINION has no accounts, no analytics and no server dependency: "
			+ "the game is designed to run offline.", "Body")
	privacy_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	privacy.add_child(privacy_text)

	_reset_button = Button.new()
	_reset_button.text = "Reset settings"
	_reset_button.theme_type_variation = &"DangerButton"
	_reset_button.icon = _RESET_ICON
	_reset_button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	_reset_button.pressed.connect(_on_reset_pressed)
	privacy.add_child(_new_row("Restore defaults",
			"Returns the theme, interface scale and motion setting to their defaults.", _reset_button))

	_save_warning = _new_label("", "Caption")
	_save_warning.visible = false
	privacy.add_child(_save_warning)

	var build := _add_section("THIS BUILD", "")
	build.add_child(_build_info_grid())


func _add_section(heading: String, description: String) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	var heading_label := _new_label(heading.to_upper(), "SectionHeading")
	section.add_child(heading_label)
	if not description.is_empty():
		var description_label := _new_label(description, "Caption")
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section.add_child(description_label)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelCard"
	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", DesignTokens.SPACE_24)
	panel.add_child(body)
	section.add_child(panel)
	_content.add_child(section)
	return body


func _new_row(title: String, description: String, control: Control) -> SettingRow:
	var row: SettingRow = _SETTING_ROW.instantiate()
	row.setup(title, description, control)
	return row


func _new_segmented() -> SegmentedControl:
	return _SEGMENTED.instantiate() as SegmentedControl


func _new_label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	return label


func _build_info_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", DesignTokens.SPACE_24)
	grid.add_theme_constant_override("v_separation", DesignTokens.SPACE_8)
	var meta := DataLoader.load_dictionary("app_meta.json")
	var engine := Engine.get_version_info()
	var pairs := [
		["Version", "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.0.0"))],
		["Milestone", str(meta.get("milestone_label", "Milestone 01"))],
		["Engine", "Godot %d.%d" % [int(engine.get("major", 0)), int(engine.get("minor", 0))]],
		["Platform", PlatformInfo.describe()],
		["Renderer", PlatformInfo.rendering_driver()],
		["Storage", "Local device only"],
	]
	for pair: Array in pairs:
		var key_label := _new_label(str(pair[0]), "Caption")
		key_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(key_label)
		var value_label := _new_label(str(pair[1]), "Value")
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value_label)
	return grid


func _palette_options() -> Array:
	var options: Array = []
	for palette_id: String in Palette.ids():
		options.append({
			"id": palette_id,
			"label": Palette.display_name(palette_id),
			"tooltip": Palette.description(palette_id),
		})
	return options


func _scale_options() -> Array:
	var options: Array = []
	for scale_value: float in SettingsSchema.UI_SCALE_OPTIONS:
		options.append({
			"id": str(scale_value),
			"label": SettingsSchema.ui_scale_label(scale_value),
		})
	return options


func _motion_options() -> Array:
	var options: Array = []
	for mode: String in [SettingsSchema.MOTION_FULL, SettingsSchema.MOTION_REDUCED]:
		options.append({"id": mode, "label": SettingsSchema.motion_label(mode)})
	return options


# --- State -----------------------------------------------------------------

func _refresh_controls() -> void:
	if _theme_control != null:
		_theme_control.set_selected(Settings.get_theme_id())
	if _scale_control != null:
		_scale_control.set_selected(str(Settings.get_ui_scale()))
	if _motion_control != null:
		_motion_control.set_selected(Settings.get_motion_mode())
	_update_save_warning()


func _update_save_warning() -> void:
	if _save_warning == null:
		return
	var failed := Settings.get_last_save_error() != OK
	_save_warning.visible = failed
	if failed:
		_save_warning.text = "This device refused the settings file; changes will not persist."
		_save_warning.add_theme_color_override("font_color", ThemeManager.color(Palette.KEY_NEGATIVE))


func _on_setting_changed(_key: String, _value: Variant) -> void:
	_refresh_controls()


# --- Reset (two-step, no modal dialog) -------------------------------------

func _on_reset_pressed() -> void:
	if not _confirming_reset:
		_confirming_reset = true
		_reset_button.text = "Confirm reset"
		_reset_timer.start()
		return
	Settings.reset_to_defaults()
	_cancel_reset()


func _cancel_reset() -> void:
	_confirming_reset = false
	_reset_timer.stop()
	if _reset_button != null:
		_reset_button.text = "Reset settings"
