class_name SettingsSchema
extends RefCounted
## Definitions and validation for player settings.
##
## Values loaded from disk are always passed through `sanitize()`, so a corrupt
## or outdated settings file degrades to defaults instead of breaking the game.

const KEY_THEME := "theme"
const KEY_UI_SCALE := "ui_scale"
const KEY_MOTION := "motion"

const MOTION_FULL := "full"
const MOTION_REDUCED := "reduced"

## Interface scale options. Values are multipliers applied to the whole
## interface via `Window.content_scale_factor`.
const UI_SCALE_OPTIONS: Array[float] = [0.9, 1.0, 1.15, 1.3]
const UI_SCALE_LABELS := {
	0.9: "90%",
	1.0: "100%",
	1.15: "115%",
	1.3: "130%",
}
const MOTION_LABELS := {
	MOTION_FULL: "Full",
	MOTION_REDUCED: "Reduced",
}


static func defaults() -> Dictionary:
	return {
		KEY_THEME: Palette.DEFAULT_ID,
		KEY_UI_SCALE: 1.0,
		KEY_MOTION: MOTION_FULL,
	}


static func keys() -> PackedStringArray:
	return PackedStringArray([KEY_THEME, KEY_UI_SCALE, KEY_MOTION])


## Returns `value` when it is a legal value for `key`, otherwise the default.
static func sanitize(key: String, value: Variant) -> Variant:
	var fallback: Variant = defaults().get(key)
	match key:
		KEY_THEME:
			if value is String and Palette.is_valid(value):
				return value
		KEY_UI_SCALE:
			if value is float or value is int:
				var scale_value := float(value)
				if UI_SCALE_OPTIONS.has(scale_value):
					return scale_value
		KEY_MOTION:
			if value is String and (value == MOTION_FULL or value == MOTION_REDUCED):
				return value
	return fallback


static func ui_scale_label(value: float) -> String:
	return UI_SCALE_LABELS.get(value, "%d%%" % roundi(value * 100.0))


static func motion_label(value: String) -> String:
	return MOTION_LABELS.get(value, MOTION_LABELS[MOTION_FULL])
