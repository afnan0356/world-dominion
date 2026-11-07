extends TestCase
## The audio foundation (Milestone 09, Task 1).
##
## Under test: the four buses exist and are routed to Master; volume and mute live in the
## settings file and reach the bus the moment they change; the two interface tones are
## generated in code, not loaded from a file; interface sounds are off by default and stay
## silent until switched on; and nothing errors when there is nothing to play.

const SETTINGS_SCENE := "res://src/ui/screens/settings_screen.tscn"


func _original() -> Dictionary:
	var saved := {}
	for bus_name: String in AudioSettings.BUSES:
		saved[bus_name] = {"v": AudioSettings.volume(bus_name),
				"m": AudioSettings.muted(bus_name)}
	saved["interface"] = {"v": AudioSettings.volume("interface"),
			"m": AudioSettings.muted("interface")}
	saved["sounds"] = AudioSettings.interface_sounds()
	return saved


func _restore(saved: Dictionary) -> void:
	for bus_name: String in AudioSettings.BUSES:
		var entry: Dictionary = saved[bus_name]
		AudioSettings.set_volume(bus_name, float(entry["v"]))
		AudioSettings.set_muted(bus_name, bool(entry["m"]))
	AudioSettings.set_interface_sounds(bool(saved["sounds"]))
	Audio.apply_from_settings()


func _mount(size: Vector2 = Vector2(1280, 800)) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Control = load(SETTINGS_SCENE).instantiate()
	holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for _frame in 3:
		await tree.process_frame
	return {"viewport": viewport, "screen": screen}


# --- Buses and persistence -------------------------------------------------

func test_the_four_buses_exist_and_feed_master() -> void:
	check_true(Audio.buses_ready(), "the service made its buses")
	for bus_name: String in ["Music", "Effects", "Interface"]:
		var index := AudioServer.get_bus_index(bus_name)
		check_gte(float(index), 0.0, "bus %s exists" % bus_name)
		check_eq(AudioServer.get_bus_send(index), "Master",
				"bus %s feeds Master" % bus_name)
	check_gt(float(AudioServer.bus_count), 3.0, "there are four buses in total")


func test_volume_and_mute_persist_and_reach_the_bus() -> void:
	var saved := _original()
	AudioSettings.set_volume("music", 202.0)
	check_eq(AudioSettings.volume("music"), 1.0, "a volume above one is clamped, not stored")
	AudioSettings.set_volume("music", -3.0)
	check_eq(AudioSettings.volume("music"), 0.0, "and a negative one clamps at zero")
	AudioSettings.set_volume("music", 0.25)
	AudioSettings.set_muted("music", true)
	Audio.apply_from_settings()
	var index := AudioServer.get_bus_index("Music")
	check(absf(AudioServer.get_bus_volume_db(index) - linear_to_db(0.25)) < 0.01,
			"the bus volume is the setting")
	check_true(AudioServer.is_bus_mute(index), "and the mute is applied")
	AudioSettings.set_muted("music", false)
	AudioSettings.set_volume("music", 0.5)
	Audio.apply_from_settings()
	check(absf(AudioServer.get_bus_volume_db(index) - linear_to_db(0.5)) < 0.01,
			"moving the slider moves the bus, with nothing restarted")
	check_false(AudioServer.is_bus_mute(index), "unmuting is applied too")
	_restore(saved)


func test_the_settings_defaults_are_silent_for_reflex_sounds() -> void:
	var defaults: Dictionary = SettingsSchema.defaults()
	check_false(bool(defaults[SettingsSchema.KEY_AUDIO_INTERFACE_SOUNDS]),
			"interface sounds are off on a fresh settings file")
	check_eq(float(defaults[SettingsSchema.KEY_AUDIO_MASTER_VOLUME]), 0.8,
			"the master bus starts at 0.8")
	check_eq(float(defaults[SettingsSchema.KEY_AUDIO_INTERFACE_VOLUME]), 0.6,
			"and the interface bus at 0.6")
	for key_name: String in [SettingsSchema.KEY_AUDIO_MASTER_MUTED,
			SettingsSchema.KEY_AUDIO_MUSIC_MUTED, SettingsSchema.KEY_AUDIO_EFFECTS_MUTED,
			SettingsSchema.KEY_AUDIO_INTERFACE_MUTED]:
		check_false(bool(defaults[key_name]), "%s starts off" % key_name)


# --- The generated tones ---------------------------------------------------

func test_the_two_tones_are_generated_in_code() -> void:
	check_true(Audio.has_generated_sounds(), "the service built both tones")
	var click: AudioStreamWAV = Audio.click_stream()
	var confirm: AudioStreamWAV = Audio.confirm_stream()
	check_not_null(click, "there is a click stream")
	check_not_null(confirm, "there is a confirm stream")
	check_eq(click.mix_rate, 44100, "the click is 44.1 kHz mono 16-bit, the simplest format")
	check_false(click.stereo, "and mono")
	check_eq(click.format, AudioStreamWAV.FORMAT_16_BITS, "the click is 16-bit samples")
	check_gt(float(click.data.size()), 1000.0, "and holds real samples, not a placeholder")
	check_gt(float(confirm.data.size()), float(click.data.size()),
			"the confirm tone is longer than the click")
	var loudest := 0
	for index in range(0, mini(click.data.size(), 4000), 2):
		loudest = maxi(loudest, absi(click.data.decode_s16(index)))
	check_gt(float(loudest), 1000.0, "the click has actual samples in it")
	# Nothing in the project ships an audio file: the sounds are this function's output.
	for folder: String in ["res://assets", "res://src"]:
		check_eq(_audio_files(folder), 0, "%s holds no audio file" % folder)


func _audio_files(folder: String) -> int:
	var count := 0
	var directory := DirAccess.open(folder)
	if directory == null:
		return 0
	for file_name: String in directory.get_files():
		if file_name.get_extension() in ["wav", "ogg", "mp3", "flac"]:
			count += 1
	for sub: String in directory.get_directories():
		count += _audio_files(folder.path_join(sub))
	return count


# --- Silence is the default, and silence is safe --------------------------

func test_nothing_plays_until_interface_sounds_are_switched_on() -> void:
	var saved := _original()
	AudioSettings.set_interface_sounds(false)
	AudioSettings.set_muted("master", false)
	AudioSettings.set_volume("master", 1.0)
	AudioSettings.set_volume("interface", 1.0)
	Audio.apply_from_settings()
	check_false(Audio.can_play_interface(), "a fresh install would not be heard")
	check_false(Audio.play_click(), "so a click does not play")
	check_false(Audio.play_confirm(), "and neither does the confirm tone")
	AudioSettings.set_interface_sounds(true)
	check_true(Audio.can_play_interface(), "with the switch on, the interface bus is audible")
	check_true(Audio.play_click(), "a click plays")
	check_true(Audio.play_confirm(), "and so does the confirm tone")
	AudioSettings.set_muted("interface", true)
	check_false(Audio.play_click(), "muting the interface bus silences it again")
	AudioSettings.set_muted("interface", false)
	AudioSettings.set_muted("master", true)
	check_false(Audio.play_click(), "and so does muting master")
	_restore(saved)


func test_nothing_errors_when_there_is_nothing_to_play() -> void:
	var saved := _original()
	AudioSettings.set_interface_sounds(false)
	Audio.apply_from_settings()
	# Calling the service with the sounds switched off must be a no-op, not a warning.
	for _repeat in 5:
		Audio.play_click()
		Audio.play_confirm()
	check_false(Audio.play_click(), "and it keeps saying so rather than guessing")
	check_true(Audio.has_generated_sounds(), "the streams are still there to play later")
	_restore(saved)


func test_the_platform_silent_hook_exists_and_is_honest() -> void:
	check_false(Audio.system_reports_silent(),
			"no platform this build runs on reports a silent state, and the hook says so")


# --- The settings screen's audio controls ---------------------------------

func test_the_settings_screen_offers_every_audio_control() -> void:
	var saved := _original()
	AudioSettings.set_volume("effects", 0.35)
	AudioSettings.set_muted("music", true)
	AudioSettings.set_interface_sounds(false)
	var mounted := await _mount()
	var screen: Control = mounted["screen"]
	for bus_name: String in AudioSettings.BUSES:
		var slider: HSlider = screen.call("audio_slider_for", bus_name)
		var mute: CheckButton = screen.call("audio_mute_for", bus_name)
		check_not_null(slider, "the %s bus has a volume slider" % bus_name)
		check_not_null(mute, "and a mute switch")
		check_gte(slider.custom_minimum_size.y, 24.0, "the slider is tappable")
		check_gte(mute.custom_minimum_size.y, DesignTokens.CONTROL_HEIGHT,
				"the mute switch is a full-height control")
	check(absf(screen.call("audio_slider_for", "effects").value - 0.35) < 0.001,
			"the slider shows the stored volume")
	check_true(screen.call("audio_mute_for", "music").button_pressed,
			"and the mute shows the stored switch")
	var tones: CheckButton = screen.call("interface_sounds_toggle")
	check_not_null(tones, "there is an interface sounds switch")
	check_false(tones.button_pressed, "off, because that is the default")
	tones.button_pressed = true
	tones.toggled.emit(true)
	check_true(AudioSettings.interface_sounds(), "switching it on is recorded")
	check_true(Audio.can_play_interface(), "and takes effect at once")
	var slider: HSlider = screen.call("audio_slider_for", "effects")
	check_false(slider.editable == false, "the slider is editable")
	(mounted["viewport"] as Node).queue_free()
	_restore(saved)


func test_the_audio_controls_fit_every_size_in_both_themes() -> void:
	var original_theme := Settings.get_theme_id()
	var saved := _original()
	var worst := ""
	for theme_id: String in ["midnight", "parchment"]:
		Settings.set_theme_id(theme_id)
		await tree.process_frame
		for label: String in ["640x360", "1280x720", "1920x1080"]:
			var size := Vector2(640, 360) if label == "640x360" else (
					Vector2(1280, 720) if label == "1280x720" else Vector2(1920, 1080))
			var mounted := await _mount(size)
			var screen: Control = mounted["screen"]
			for bus_name: String in AudioSettings.BUSES:
				var mute: CheckButton = screen.call("audio_mute_for", bus_name)
				if mute.size.y + 0.5 < DesignTokens.CONTROL_HEIGHT and worst.is_empty():
					worst = "%s/%s: %s mute is %s high" % [theme_id, label, bus_name,
							str(mute.size.y)]
			(mounted["viewport"] as Node).queue_free()
	Settings.set_theme_id(original_theme)
	_restore(saved)
	check_eq(worst, "", "the audio controls fit every size in both themes")
