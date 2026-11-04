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


func _apply_runtime() -> void:
	# Interface scale is applied to the window so every screen, including future
	# gameplay screens, scales consistently.
	var root := get_tree().root if is_inside_tree() else null
	if root is Window:
		(root as Window).content_scale_factor = get_ui_scale()
