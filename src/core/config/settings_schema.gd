class_name SettingsSchema
extends RefCounted
## Definitions and validation for player settings.
##
## Values loaded from disk are always passed through `sanitize()`, so a corrupt
## or outdated settings file degrades to defaults instead of breaking the game.

const KEY_THEME := "theme"
const KEY_UI_SCALE := "ui_scale"
const KEY_MOTION := "motion"
## Developer-only switches. Off by default, so a normal player never sees them.
const KEY_PERF_OVERLAY := "performance_overlay"
const KEY_DEV_TOOLS := "developer_tools"
## Map detail for slower devices: geography and selection are identical, only
## borders, labels and capital markers are reduced.
const KEY_MAP_DETAIL := "map_detail"

## Audio (Milestone 09). Three buses the player can tune, a mute for each, and the
## interface sounds switch, which is OFF by default: a first launch is silent.
const KEY_AUDIO_MASTER_VOLUME := "audio_master_volume"
const KEY_AUDIO_MUSIC_VOLUME := "audio_music_volume"
const KEY_AUDIO_EFFECTS_VOLUME := "audio_effects_volume"
const KEY_AUDIO_INTERFACE_VOLUME := "audio_interface_volume"
const KEY_AUDIO_MASTER_MUTED := "audio_master_muted"
const KEY_AUDIO_MUSIC_MUTED := "audio_music_muted"
const KEY_AUDIO_EFFECTS_MUTED := "audio_effects_muted"
const KEY_AUDIO_INTERFACE_MUTED := "audio_interface_muted"
const KEY_AUDIO_INTERFACE_SOUNDS := "audio_interface_sounds"

## The buses, in the order the settings screen shows them. `master` is the whole game;
## the other three feed it.
const AUDIO_BUSES: Array[String] = ["master", "music", "effects", "interface"]

## Performance (Milestone 09). A frame-rate cap the engine really obeys, and one
## quality preset that writes the map options below. Both are display choices: neither
## changes data, a hit box or a save.
const KEY_FPS_LIMIT := "fps_limit"
const KEY_QUALITY := "quality"

const FPS_30 := "30"
const FPS_60 := "60"
const FPS_UNLIMITED := "unlimited"
const FPS_LIMIT_OPTIONS: Array[String] = [FPS_30, FPS_60, FPS_UNLIMITED]
const FPS_LIMIT_LABELS := {
	FPS_30: "30",
	FPS_60: "60",
	FPS_UNLIMITED: "Unlimited",
}

const QUALITY_LOW := "low"
const QUALITY_MEDIUM := "medium"
const QUALITY_HIGH := "high"
## What the preset becomes the moment the player changes one map option by hand.
const QUALITY_CUSTOM := "custom"
const QUALITY_OPTIONS: Array[String] = [QUALITY_LOW, QUALITY_MEDIUM, QUALITY_HIGH,
		QUALITY_CUSTOM]
const QUALITY_LABELS := {
	QUALITY_LOW: "Low",
	QUALITY_MEDIUM: "Medium",
	QUALITY_HIGH: "High",
	QUALITY_CUSTOM: "Custom",
}

## Map options. Every one of them is a display choice: none of them changes the
## data, the hit boxes or what a save contains.
const KEY_MAP_LABELS := "map_labels"
const KEY_MAP_BORDERS := "map_borders"
const KEY_MAP_GRATICULE := "map_graticule"
const KEY_MAP_CAPITALS := "map_capitals"
const KEY_MAP_REFERENCE_LINES := "map_reference_lines"
## Recently viewed records, newest first. Local only: never saved into a campaign,
## never sent anywhere.
const KEY_RECENT_COUNTRIES := "recent_countries"

const LABEL_DENSITY_FULL := "full"
const LABEL_DENSITY_SPARSE := "sparse"

## Whether the player has seen the in-game first-run guide. Persisted so the guide
## appears once, and re-openable from the pause menu at any time.
const KEY_GUIDE_SEEN := "game_guide_seen"

const DETAIL_FULL := "full"
const DETAIL_REDUCED := "reduced"

const MOTION_FULL := "full"
const MOTION_REDUCED := "reduced"

## Interface scale options. Values are multipliers applied to the whole
## interface via `Window.content_scale_factor`.
const UI_SCALE_OPTIONS: Array[float] = [0.9, 1.0, 1.15, 1.3]
## How many recently viewed records the atlas remembers.
const RECENT_LIMIT := 8
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
const DETAIL_LABELS := {
	DETAIL_FULL: "Full",
	DETAIL_REDUCED: "Reduced",
}
const LABEL_DENSITY_LABELS := {
	LABEL_DENSITY_FULL: "All labels",
	LABEL_DENSITY_SPARSE: "Fewer labels",
}


static func defaults() -> Dictionary:
	return {
		KEY_THEME: Palette.DEFAULT_ID,
		KEY_UI_SCALE: 1.0,
		KEY_MOTION: MOTION_FULL,
		KEY_PERF_OVERLAY: false,
		KEY_DEV_TOOLS: false,
		KEY_MAP_DETAIL: DETAIL_FULL,
		KEY_FPS_LIMIT: FPS_60,
		KEY_QUALITY: QUALITY_HIGH,
		KEY_GUIDE_SEEN: false,
		KEY_MAP_LABELS: LABEL_DENSITY_FULL,
		KEY_MAP_BORDERS: true,
		KEY_MAP_GRATICULE: true,
		KEY_MAP_CAPITALS: true,
		KEY_MAP_REFERENCE_LINES: true,
		KEY_RECENT_COUNTRIES: [],
		KEY_AUDIO_MASTER_VOLUME: 0.8,
		KEY_AUDIO_MUSIC_VOLUME: 0.7,
		KEY_AUDIO_EFFECTS_VOLUME: 0.8,
		KEY_AUDIO_INTERFACE_VOLUME: 0.6,
		KEY_AUDIO_MASTER_MUTED: false,
		KEY_AUDIO_MUSIC_MUTED: false,
		KEY_AUDIO_EFFECTS_MUTED: false,
		KEY_AUDIO_INTERFACE_MUTED: false,
		KEY_AUDIO_INTERFACE_SOUNDS: false,
	}


static func keys() -> PackedStringArray:
	return PackedStringArray([KEY_THEME, KEY_UI_SCALE, KEY_MOTION, KEY_PERF_OVERLAY,
			KEY_DEV_TOOLS, KEY_MAP_DETAIL, KEY_FPS_LIMIT, KEY_QUALITY, KEY_GUIDE_SEEN,
			KEY_MAP_LABELS, KEY_MAP_BORDERS, KEY_MAP_GRATICULE, KEY_MAP_CAPITALS, KEY_MAP_REFERENCE_LINES,
			KEY_RECENT_COUNTRIES, KEY_AUDIO_MASTER_VOLUME, KEY_AUDIO_MUSIC_VOLUME,
			KEY_AUDIO_EFFECTS_VOLUME, KEY_AUDIO_INTERFACE_VOLUME, KEY_AUDIO_MASTER_MUTED,
			KEY_AUDIO_MUSIC_MUTED, KEY_AUDIO_EFFECTS_MUTED, KEY_AUDIO_INTERFACE_MUTED,
			KEY_AUDIO_INTERFACE_SOUNDS])


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
		KEY_MAP_LABELS:
			if value is String and (value == LABEL_DENSITY_FULL or value == LABEL_DENSITY_SPARSE):
				return value
		KEY_MAP_BORDERS, KEY_MAP_GRATICULE, KEY_MAP_CAPITALS, KEY_MAP_REFERENCE_LINES:
			if value is bool:
				return value
			if value is String and value.to_lower() in ["true", "false"]:
				return value.to_lower() == "true"
		KEY_RECENT_COUNTRIES:
			if value is Array:
				var kept: Array[String] = []
				for item: Variant in value:
					if item is String and not str(item).is_empty():
						kept.append(str(item))
				return kept.slice(0, RECENT_LIMIT)
		KEY_PERF_OVERLAY, KEY_DEV_TOOLS, KEY_GUIDE_SEEN:
			if value is bool:
				return value
			if value is String and value.to_lower() in ["true", "false"]:
				return value.to_lower() == "true"
		KEY_MAP_DETAIL:
			if value is String and (value == DETAIL_FULL or value == DETAIL_REDUCED):
				return value
		KEY_FPS_LIMIT:
			if value is String and FPS_LIMIT_OPTIONS.has(value):
				return value
			if value is int or value is float:
				var cap := int(value)
				if cap == 30:
					return FPS_30
				if cap == 60:
					return FPS_60
				if cap == 0:
					return FPS_UNLIMITED
		KEY_QUALITY:
			if value is String and QUALITY_OPTIONS.has(value):
				return value
		KEY_AUDIO_MASTER_VOLUME, KEY_AUDIO_MUSIC_VOLUME, KEY_AUDIO_EFFECTS_VOLUME, \
				KEY_AUDIO_INTERFACE_VOLUME:
			if value is float or value is int:
				if is_finite(float(value)):
					return clampf(float(value), 0.0, 1.0)
		KEY_AUDIO_MASTER_MUTED, KEY_AUDIO_MUSIC_MUTED, KEY_AUDIO_EFFECTS_MUTED, \
				KEY_AUDIO_INTERFACE_MUTED, KEY_AUDIO_INTERFACE_SOUNDS:
			if value is bool:
				return value
			if value is String and value.to_lower() in ["true", "false"]:
				return value.to_lower() == "true"
	return fallback


static func ui_scale_label(value: float) -> String:
	return UI_SCALE_LABELS.get(value, "%d%%" % roundi(value * 100.0))


static func motion_label(value: String) -> String:
	return MOTION_LABELS.get(value, MOTION_LABELS[MOTION_FULL])


static func detail_label(value: String) -> String:
	return DETAIL_LABELS.get(value, DETAIL_LABELS[DETAIL_FULL])


## The setting key for a bus volume or mute, by bus name. Empty for an unknown bus.
static func audio_volume_key(bus_name: String) -> String:
	match bus_name:
		"master":
			return KEY_AUDIO_MASTER_VOLUME
		"music":
			return KEY_AUDIO_MUSIC_VOLUME
		"effects":
			return KEY_AUDIO_EFFECTS_VOLUME
		"interface":
			return KEY_AUDIO_INTERFACE_VOLUME
	return ""


static func audio_mute_key(bus_name: String) -> String:
	match bus_name:
		"master":
			return KEY_AUDIO_MASTER_MUTED
		"music":
			return KEY_AUDIO_MUSIC_MUTED
		"effects":
			return KEY_AUDIO_EFFECTS_MUTED
		"interface":
			return KEY_AUDIO_INTERFACE_MUTED
	return ""


static func fps_limit_label(value: String) -> String:
	return FPS_LIMIT_LABELS.get(value, FPS_LIMIT_LABELS[FPS_60])


## The value `Engine.max_fps` takes for a limit. Zero means no cap, which is what the
## engine's own property uses for "unlimited".
static func fps_cap(value: String) -> int:
	match value:
		FPS_30:
			return 30
		FPS_60:
			return 60
	return 0


static func quality_label(value: String) -> String:
	return QUALITY_LABELS.get(value, QUALITY_LABELS[QUALITY_HIGH])


## What one quality preset means, as the concrete map options it writes. This is the
## single definition: the settings screen applies it and `docs/DESIGN_SYSTEM.md` documents
## the same table. `custom` means "whatever the map options already say".
static func quality_preset(level: String) -> Dictionary:
	match level:
		QUALITY_LOW:
			return {
				"detail": DETAIL_REDUCED,
				"labels": LABEL_DENSITY_SPARSE,
				"capitals": false,
				"graticule": false,
				"reference_lines": false,
			}
		QUALITY_MEDIUM:
			return {
				"detail": DETAIL_REDUCED,
				"labels": LABEL_DENSITY_FULL,
				"capitals": true,
				"graticule": false,
				"reference_lines": true,
			}
		QUALITY_HIGH:
			return {
				"detail": DETAIL_FULL,
				"labels": LABEL_DENSITY_FULL,
				"capitals": true,
				"graticule": true,
				"reference_lines": true,
			}
	return {}


static func label_density_label(value: String) -> String:
	return LABEL_DENSITY_LABELS.get(value, LABEL_DENSITY_LABELS[LABEL_DENSITY_FULL])
