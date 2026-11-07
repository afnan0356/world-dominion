extends Node
## Autoload: `Settings`.
##
## Owns the player's local settings and applies the ones that affect the
## application shell (interface scale). Everything is stored on device only —
## there is no account, no synchronisation and no telemetry.

signal changed(key: String, value: Variant)
signal reset()

var _store := SettingsStore.new()
var _values: Dictionary = SettingsSchema.defaults()
var _last_save_error: Error = OK


func _ready() -> void:
	_values = _store.load_values()
	_apply_runtime()


func get_value(key: String) -> Variant:
	return _values.get(key, SettingsSchema.defaults().get(key))


func set_value(key: String, value: Variant) -> void:
	if not SettingsSchema.defaults().has(key):
		push_error("Settings: refusing to write unknown key '%s'." % key)
		return
	var sanitized: Variant = SettingsSchema.sanitize(key, value)
	if _values.get(key) == sanitized:
		return
	_values[key] = sanitized
	_persist()
	_apply_runtime()
	changed.emit(key, sanitized)


# --- Typed accessors -------------------------------------------------------

func get_theme_id() -> String:
	return str(get_value(SettingsSchema.KEY_THEME))


func set_theme_id(palette_id: String) -> void:
	set_value(SettingsSchema.KEY_THEME, palette_id)


func get_ui_scale() -> float:
	return float(get_value(SettingsSchema.KEY_UI_SCALE))


func set_ui_scale(scale_value: float) -> void:
	set_value(SettingsSchema.KEY_UI_SCALE, scale_value)


func get_motion_mode() -> String:
	return str(get_value(SettingsSchema.KEY_MOTION))


func set_motion_mode(mode: String) -> void:
	set_value(SettingsSchema.KEY_MOTION, mode)


## Developer performance overlay (F3 also toggles it). Off by default.
func get_show_performance_overlay() -> bool:
	return bool(get_value(SettingsSchema.KEY_PERF_OVERLAY))


func set_show_performance_overlay(enabled: bool) -> void:
	set_value(SettingsSchema.KEY_PERF_OVERLAY, enabled)


func toggle_performance_overlay() -> bool:
	set_show_performance_overlay(not get_show_performance_overlay())
	return get_show_performance_overlay()


## Developer tools: exposes the map stress test. Off by default.
func get_developer_tools() -> bool:
	return bool(get_value(SettingsSchema.KEY_DEV_TOOLS))


func set_developer_tools(enabled: bool) -> void:
	set_value(SettingsSchema.KEY_DEV_TOOLS, enabled)


## True once the player has seen the in-game first-run guide.
func get_guide_seen() -> bool:
	return bool(get_value(SettingsSchema.KEY_GUIDE_SEEN))


func set_guide_seen(seen: bool) -> void:
	set_value(SettingsSchema.KEY_GUIDE_SEEN, seen)


func get_map_detail() -> String:
	return str(get_value(SettingsSchema.KEY_MAP_DETAIL))


func set_map_detail(detail: String) -> void:
	set_value(SettingsSchema.KEY_MAP_DETAIL, detail)


## Convenience flag used by every animated transition in the interface.
func get_reduce_motion() -> bool:
	return get_motion_mode() == SettingsSchema.MOTION_REDUCED


## OK when the settings file was last written successfully. The settings screen
## surfaces a warning when this is not OK, rather than silently losing choices.
func get_last_save_error() -> Error:
	return _last_save_error


func reset_to_defaults() -> void:
	var defaults := SettingsSchema.defaults()
	var changed_keys: Array[String] = []
	for key: String in defaults:
		if _values.get(key) != defaults[key]:
			_values[key] = defaults[key]
			changed_keys.append(key)
	_persist()
	_apply_runtime()
	for key: String in changed_keys:
		changed.emit(key, _values[key])
	reset.emit()


# --- Internals -------------------------------------------------------------

func _persist() -> void:
	_last_save_error = _store.save_values(_values)
	if _last_save_error != OK:
		push_warning("Settings: could not save settings (error %d)." % _last_save_error)
		# The diagnostics screen is the only place a player can see this; a warning in the
		# console is not visible on a phone.
		DiagnosticsLog.warn("The settings file could not be written (error %d)." % _last_save_error)


func _apply_runtime() -> void:
	# Interface scale is applied to the window so every screen, including future
	# gameplay screens, scales consistently.
	var root := get_tree().root if is_inside_tree() else null
	if root is Window:
		(root as Window).content_scale_factor = get_ui_scale()
	# The frame-rate cap is an engine property, so it is applied here rather than on the
	# settings screen: every write path (screen, shortcut, hand-edited file at load) ends up
	# in the same place, and the cap holds from the first frame without a restart.
	PerformanceOptions.apply_fps_cap()
