class_name AudioSettings
extends RefCounted
## The audio half of the settings file, in one small facade (Milestone 09, Task 1).
##
## Why a facade rather than more methods on `Settings`: the settings service is already at
## the linter's public-method limit, and "one method per key" does not scale to nine keys.
## The values still live in the same validated schema and the same file — this class only
## names them for the audio code and the settings screen.

## Bus names as the player sees them, in the order the settings screen lists them.
const BUSES: Array[String] = ["master", "music", "effects", "interface"]
const BUS_LABELS := {
	"master": "Master",
	"music": "Music",
	"effects": "Effects",
	"interface": "Interface",
}
const DEFAULT_VOLUME := 0.8


static func volume(bus_name: String) -> float:
	var key := SettingsSchema.audio_volume_key(bus_name)
	if key.is_empty():
		return DEFAULT_VOLUME
	return float(Settings.get_value(key))


static func set_volume(bus_name: String, value: float) -> void:
	var key := SettingsSchema.audio_volume_key(bus_name)
	if not key.is_empty():
		Settings.set_value(key, clampf(value, 0.0, 1.0))


static func muted(bus_name: String) -> bool:
	var key := SettingsSchema.audio_mute_key(bus_name)
	if key.is_empty():
		return false
	return bool(Settings.get_value(key))


static func set_muted(bus_name: String, value: bool) -> void:
	var key := SettingsSchema.audio_mute_key(bus_name)
	if not key.is_empty():
		Settings.set_value(key, value)


## Would this bus be heard? Muted on the bus itself or on Master means no.
static func audible(bus_name: String) -> bool:
	if muted("master") or volume("master") <= 0.0:
		return false
	if bus_name == "master":
		return true
	return not muted(bus_name) and volume(bus_name) > 0.0


## The interface click and confirm tones. Off by default: a first launch is silent.
static func interface_sounds() -> bool:
	return bool(Settings.get_value(SettingsSchema.KEY_AUDIO_INTERFACE_SOUNDS))


static func set_interface_sounds(enabled: bool) -> void:
	Settings.set_value(SettingsSchema.KEY_AUDIO_INTERFACE_SOUNDS, enabled)


static func label(bus_name: String) -> String:
	return str(BUS_LABELS.get(bus_name, bus_name.capitalize()))
