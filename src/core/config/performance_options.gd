class_name PerformanceOptions
extends RefCounted
## The performance half of the settings file: a real frame-rate cap and one quality preset.
##
## The cap is applied to `Engine.max_fps` by `SettingsService._apply_runtime()`, so moving the
## choice on the settings screen changes the engine in the same frame — there is no restart and
## no second code path. `fps_cap_value()` is the only place that turns the stored string into the
## number the engine takes, which is what makes "the FPS cap really limits the engine" a testable
## claim instead of a comment.
##
## Quality is a *preset over the real map options*, not a new renderer. It writes the five display
## keys that already exist (`map_detail`, `map_labels`, `map_capitals`, `map_graticule`,
## `map_reference_lines`), and reduced map detail is what stops the ambient sea, so the documented
## mapping in `docs/DESIGN_SYSTEM.md` is the whole truth. Changing any map option by hand —
## on this screen or in the in-game map options panel — stores `custom`, so the screen never
## claims a preset the options below no longer match.

const SCHEMA := preload("res://src/core/config/settings_schema.gd")


static func fps_limit() -> String:
	return str(Settings.get_value(SCHEMA.KEY_FPS_LIMIT))


static func set_fps_limit(value: String) -> void:
	Settings.set_value(SCHEMA.KEY_FPS_LIMIT, value)


## 30, 60 or 0 for "no cap" — the value `Engine.max_fps` expects.
static func fps_cap_value() -> int:
	return SCHEMA.fps_cap(fps_limit())


## Pushes the stored cap into the engine. Cheap and idempotent, so it runs on every settings
## write rather than only on the one that changed the cap.
static func apply_fps_cap() -> void:
	Engine.max_fps = fps_cap_value()


static func quality() -> String:
	return str(Settings.get_value(SCHEMA.KEY_QUALITY))


## Applies a preset: the five map options first, then the label, so the label is never the one
## thing that disagrees with the options. Passing `custom` (or anything unknown) changes nothing
## but the label, because "custom" is defined as "whatever the options already say".
static func apply_quality(level: String) -> void:
	var preset := SCHEMA.quality_preset(level)
	if not preset.is_empty():
		Settings.set_value(SCHEMA.KEY_MAP_DETAIL, preset["detail"])
		Settings.set_value(SCHEMA.KEY_MAP_LABELS, preset["labels"])
		Settings.set_value(SCHEMA.KEY_MAP_CAPITALS, preset["capitals"])
		Settings.set_value(SCHEMA.KEY_MAP_GRATICULE, preset["graticule"])
		Settings.set_value(SCHEMA.KEY_MAP_REFERENCE_LINES, preset["reference_lines"])
	Settings.set_value(SCHEMA.KEY_QUALITY, level)


## Called by anything that changes one map display option by hand. A preset is a bundle, so
## changing a member of the bundle means the bundle no longer describes what is on screen.
static func note_manual_map_change() -> void:
	if quality() != SCHEMA.QUALITY_CUSTOM:
		Settings.set_value(SCHEMA.KEY_QUALITY, SCHEMA.QUALITY_CUSTOM)


## The preset a stored quality setting implies, for tests and for the screen's description of
## what each option does. Empty for `custom`.
static func preset_for(level: String) -> Dictionary:
	return SCHEMA.quality_preset(level)
