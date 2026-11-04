class_name SettingsStore
extends RefCounted
## Persistence for player settings (`user://settings.cfg`).
##
## Plain `ConfigFile` text keeps the file small, human-readable and diffable, and
## it is written entirely on-device: WORLD DOMINION has no accounts, no backend
## and makes no network requests for settings.

const DEFAULT_PATH := "user://settings.cfg"
const SECTION := "settings"

var _path: String


func _init(path: String = DEFAULT_PATH) -> void:
	_path = path


func exists() -> bool:
	return FileAccess.file_exists(_path)


## Reads stored values, falling back to defaults for anything missing, unknown
## or invalid. Never fails: a damaged file yields defaults plus a warning.
func load_values() -> Dictionary:
	var values := SettingsSchema.defaults()
	if not exists():
		return values
	var config := ConfigFile.new()
	var error := config.load(_path)
	if error != OK:
		push_warning("SettingsStore: could not read %s (error %d); using defaults." % [_path, error])
		return values
	for key: String in SettingsSchema.keys():
		if not config.has_section_key(SECTION, key):
			continue
		values[key] = SettingsSchema.sanitize(key, config.get_value(SECTION, key))
	return values


## Writes `values` atomically enough for a settings file: a full rewrite of a
## small text file. Returns the first error encountered so callers can tell the
## player that settings will not survive a restart.
func save_values(values: Dictionary) -> Error:
	var config := ConfigFile.new()
	for key: String in SettingsSchema.keys():
		config.set_value(SECTION, key, SettingsSchema.sanitize(key, values.get(key)))
	return config.save(_path)


func erase() -> Error:
	if not exists():
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(_path))
