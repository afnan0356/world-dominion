extends ResponsiveScreen
## Settings screen.
##
## Everything on this screen is functional: the theme, the interface scale and
## the motion preference are applied immediately and persisted to a local file.
## Nothing here is a placeholder for a future feature.

signal back_requested()
## Navigation carrying instructions (used by the developer stress test).
signal navigation_requested(screen_id: String, params: Dictionary)

const _SETTING_ROW := preload("res://src/ui/components/setting_row.tscn")
const _SEGMENTED := preload("res://src/ui/components/segmented_control.tscn")
const _RESET_ICON := preload("res://assets/icons/reset.svg")
const _RESET_CONFIRM_SECONDS := 4.0

var _theme_control: SegmentedControl
var _scale_control: SegmentedControl
var _motion_control: SegmentedControl
var _detail_control: SegmentedControl
var _overlay_control: SegmentedControl
var _dev_tools_control: SegmentedControl
var _stress_button: Button
var _audio_sliders: Dictionary = {}
var _audio_mutes: Dictionary = {}
var _interface_sounds_control: CheckButton
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

	_build_privacy_section()
	_build_audio_section()
	var motion := _add_section("MOTION", "")
	_motion_control = _new_segmented()
	_motion_control.setup(_motion_options(), Settings.get_motion_mode())
	_motion_control.option_selected.connect(func(option_id: String) -> void:
		Settings.set_motion_mode(option_id))
	motion.add_child(_new_row("Interface transitions",
			"Reduced motion removes screen fades and hover animations.", _motion_control))

	var map_section := _add_section("MAP",
			"How the world map is drawn. Reduced detail is for slower devices: "
			+ "borders, labels and capital markers are simplified, while the geography "
			+ "itself and what you can tap stay exactly the same.")
	_detail_control = _new_segmented()
	_detail_control.setup(_detail_options(), Settings.get_map_detail())
	_detail_control.option_selected.connect(func(option_id: String) -> void:
		Settings.set_map_detail(option_id))
	map_section.add_child(_new_row("Map detail",
			"Reduced hides ocean names and capital markers, thins borders and shows fewer labels.",
			_detail_control))

	var developer := _add_section("ADVANCED / DEVELOPER",
			"Measuring tools for testing the game on real hardware. They are off by default, "
			+ "store nothing, send nothing and do not change gameplay.")
	_overlay_control = _new_segmented()
	_overlay_control.setup(_on_off_options(), _bool_id(Settings.get_show_performance_overlay()))
	_overlay_control.option_selected.connect(func(option_id: String) -> void:
		Settings.set_show_performance_overlay(option_id == "on"))
	developer.add_child(_new_row("Performance overlay",
			"Shows FPS, frame times and draw calls in the corner. F3 toggles it at any time.",
			_overlay_control))

	_dev_tools_control = _new_segmented()
	_dev_tools_control.setup(_on_off_options(), _bool_id(Settings.get_developer_tools()))
	_dev_tools_control.option_selected.connect(func(option_id: String) -> void:
		Settings.set_developer_tools(option_id == "on"))
	developer.add_child(_new_row("Developer tools",
			"Reveals the map stress test below and on the campaign screen.", _dev_tools_control))

	_stress_button = Button.new()
	_stress_button.text = "Run 30-second map stress test"
	_stress_button.theme_type_variation = &"GhostButton"
	_stress_button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	_stress_button.tooltip_text = ("Pans and zooms the world map along a fixed path for 30 seconds, "
			+ "then reports average and 95th-percentile frame time on this device.")
	_stress_button.pressed.connect(_on_stress_pressed)
	var stress_row := _new_row("Map stress test",
			"Opens the campaign map and drives it along a repeatable path. Use it on a real phone "
			+ "to get numbers instead of guesses.", _stress_button)
	developer.add_child(stress_row)
	_update_developer_visibility()

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


## Four buses, a volume and a mute each, plus the interface sounds switch. The two tones
## that switch controls are generated in code; there is no audio file in the project, and
## music is PLANNED, not missing by accident.
func _build_audio_section() -> void:
	var audio := _add_section("AUDIO",
			"Volume and mute are saved on this device and applied immediately. The interface "
			+ "click and confirm tone are made by the game itself; music and recorded sound "
			+ "effects are PLANNED, so these buses are quiet for now until they exist.")
	for bus_name: String in AudioSettings.BUSES:
		audio.add_child(_new_row(AudioSettings.label(bus_name),
				"Volume for the %s bus." % bus_name.to_lower(), _audio_control(bus_name)))
	var tones := _new_row("Interface sounds",
			"A short click on every button and a soft tone when the tutorial pays its "
			+ "reward. Off by default; nothing else in the game makes a sound.",
			_interface_sounds_toggle())
	tones.name = "InterfaceSoundsRow"
	audio.add_child(tones)


func _audio_control(bus_name: String) -> Control:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", DesignTokens.SPACE_4)
	var slider := HSlider.new()
	slider.name = "%sVolume" % AudioSettings.label(bus_name)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = AudioSettings.volume(bus_name)
	slider.custom_minimum_size = Vector2(200, DesignTokens.CONTROL_HEIGHT)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float) -> void:
		AudioSettings.set_volume(bus_name, value))
	holder.add_child(slider)
	_audio_sliders[bus_name] = slider
	var mute := CheckButton.new()
	mute.name = "%sMuted" % AudioSettings.label(bus_name)
	mute.text = "Mute this bus"
	mute.button_pressed = AudioSettings.muted(bus_name)
	mute.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	mute.toggled.connect(func(pressed: bool) -> void:
		AudioSettings.set_muted(bus_name, pressed))
	holder.add_child(mute)
	_audio_mutes[bus_name] = mute
	return holder


func _interface_sounds_toggle() -> CheckButton:
	_interface_sounds_control = CheckButton.new()
	_interface_sounds_control.name = "InterfaceSounds"
	_interface_sounds_control.text = "Play the interface tones"
	_interface_sounds_control.button_pressed = AudioSettings.interface_sounds()
	_interface_sounds_control.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	_interface_sounds_control.toggled.connect(func(pressed: bool) -> void:
		AudioSettings.set_interface_sounds(pressed))
	return _interface_sounds_control


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


## The first-run screens, reachable again: the terms text, and the notification preference
## (a preference only — the game asks the device for nothing, and cannot notify yet).
func _build_privacy_section() -> void:
	var store := FirstRunStore.new()
	store.load_from()
	var section := _add_section("PRIVACY AND TERMS",
			"Readable again at any time. Nothing here is sent anywhere.")
	var terms_button := Button.new()
	terms_button.name = "ViewTerms"
	terms_button.text = "View terms and privacy"
	terms_button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	terms_button.pressed.connect(func() -> void:
		navigation_requested.emit("first_run", {"review": true}))
	var accepted := "not accepted yet"
	if store.terms_accepted:
		accepted = "accepted"
	section.add_child(_new_row("Terms and privacy",
			"Version %d — %s." % [FirstRunStore.TERMS_VERSION, accepted], terms_button))
	var choice := _new_segmented()
	choice.name = "NotificationsChoice"
	choice.setup([{"id": "on", "label": "On"}, {"id": "off", "label": "Off"}],
			"on" if store.notifications else "off")
	choice.option_selected.connect(func(option_id: String) -> void:
		var store_now := FirstRunStore.new()
		store_now.load_from()
		store_now.set_notifications(option_id == "on")
		store_now.save_to())
	section.add_child(_new_row("Notifications (PLANNED feature)",
			"Records your preference only. No permission is requested and nothing is sent.",
			choice))


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


func _detail_options() -> Array:
	var options: Array = []
	for detail: String in [SettingsSchema.DETAIL_FULL, SettingsSchema.DETAIL_REDUCED]:
		options.append({"id": detail, "label": SettingsSchema.detail_label(detail)})
	return options


func _on_off_options() -> Array:
	return [{"id": "off", "label": "Off"}, {"id": "on", "label": "On"}]


static func _bool_id(value: bool) -> String:
	return "on" if value else "off"


func _update_developer_visibility() -> void:
	if _stress_button == null:
		return
	_stress_button.visible = Settings.get_developer_tools()


## Starts the stress test on the campaign screen, which owns the map.
func _on_stress_pressed() -> void:
	navigation_requested.emit("campaign_setup", {"stress_test": true})


func _motion_options() -> Array:
	var options: Array = []
	for mode: String in [SettingsSchema.MOTION_FULL, SettingsSchema.MOTION_REDUCED]:
		options.append({"id": mode, "label": SettingsSchema.motion_label(mode)})
	return options


# --- State -----------------------------------------------------------------

func audio_slider_for(bus_name: String) -> HSlider:
	return _audio_sliders.get(bus_name) as HSlider


func audio_mute_for(bus_name: String) -> CheckButton:
	return _audio_mutes.get(bus_name) as CheckButton


func interface_sounds_toggle() -> CheckButton:
	return _interface_sounds_control


func _refresh_controls() -> void:
	if _theme_control != null:
		_theme_control.set_selected(Settings.get_theme_id())
	if _scale_control != null:
		_scale_control.set_selected(str(Settings.get_ui_scale()))
	if _motion_control != null:
		_motion_control.set_selected(Settings.get_motion_mode())
	if _detail_control != null:
		_detail_control.set_selected(Settings.get_map_detail())
	if _overlay_control != null:
		_overlay_control.set_selected(_bool_id(Settings.get_show_performance_overlay()))
	if _dev_tools_control != null:
		_dev_tools_control.set_selected(_bool_id(Settings.get_developer_tools()))
	_update_developer_visibility()
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
