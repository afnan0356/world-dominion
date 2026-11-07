extends Node
## The audio service (Milestone 09, Task 1).
##
## What this is: four buses (Master, Music, Effects, Interface), volumes and mute switches
## that live in the settings file and apply the moment they change, and two sounds the game
## generates for itself at runtime — a short interface click and a soft confirm tone. There
## is no audio file in this repository, and none is downloaded; the tones are built from
## samples in `_build_tone()`, so the licence question is answered by construction.
##
## What this is **not**: music, ambient beds and any recorded effect are **PLANNED**. The
## two generated tones are the only sound the build can make. Interface sounds are **off by
## default** and stay silent until the player turns them on, which is why nothing here
## surprises someone opening the game for the first time.
##
## What happens when there is nothing to play: nothing. `play_click()` and `play_confirm()`
## return false and no player is created, so a build with no sounds is silent rather than
## broken.
##
## **System silent state**: where a platform exposes a "silent mode" the service defers to
## it (`system_reports_silent()`). Godot 4.6 exposes no such query on any desktop platform,
## and this build has never run on a phone, so the hook returns false today and
## `docs/ARCHITECTURE.md` records that as UNVERIFIED rather than claiming respect it cannot
## demonstrate.

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_EFFECTS := "Effects"
const BUS_INTERFACE := "Interface"
const BUSES: PackedStringArray = [BUS_MUSIC, BUS_EFFECTS, BUS_INTERFACE]

## 16-bit mono at 44.1 kHz: the smallest format Godot plays without a decoder, and small
## enough to generate inside one frame.
const MIX_RATE := 44100
const CLICK_HZ := 880.0
const CLICK_SECONDS := 0.045
const CONFIRM_HZ := 660.0
const CONFIRM_HZ_UP := 880.0
const CONFIRM_SECONDS := 0.26

var _interface_player: AudioStreamPlayer
var _click: AudioStreamWAV
var _confirm: AudioStreamWAV
var _buses_ready := false


func _ready() -> void:
	_ensure_buses()
	_build_streams()
	if Settings.has_signal("changed"):
		Settings.changed.connect(_on_setting_changed)
	# Every button in the game gets the same feedback, without each screen remembering to
	# ask for it. The hook is cheap and does nothing while interface sounds are off.
	get_tree().node_added.connect(_on_node_added)
	apply_from_settings()


# --- Buses ----------------------------------------------------------------

## Creates Music, Effects and Interface if they are not there yet, and routes each to
## Master. Idempotent: calling it twice does not add a second bus of the same name.
func _ensure_buses() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, BUS_MASTER)
	_buses_ready = true


func bus_index(bus_name: String) -> int:
	return AudioServer.get_bus_index(bus_name)


## True when the service found or made every bus it needs.
func buses_ready() -> bool:
	return _buses_ready and AudioServer.get_bus_index(BUS_MASTER) >= 0


# --- Settings -------------------------------------------------------------

## Applies every stored volume and mute switch. Called on start and on every change, so a
## slider moves the bus immediately — there is nothing to restart.
func apply_from_settings() -> void:
	_ensure_buses()
	for bus_name: String in AudioSettings.BUSES:
		_set_bus(_godot_bus(bus_name), AudioSettings.volume(bus_name),
				AudioSettings.muted(bus_name))
	if not interface_sounds_enabled() and _interface_player != null:
		_interface_player.stop()


func _set_bus(bus_name: String, volume: float, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, muted)
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(volume, 0.0, 1.0)))


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key.begins_with("audio_"):
		apply_from_settings()


func interface_sounds_enabled() -> bool:
	return AudioSettings.interface_sounds()


static func _godot_bus(bus_name: String) -> String:
	return BUS_MASTER if bus_name == "master" else bus_name.capitalize()


## The hook for a platform silent mode. No platform this build runs on exposes one, so it
## answers false; a future platform layer can answer differently and nothing else changes.
func system_reports_silent() -> bool:
	return false


## True when a sound would actually be heard: sounds on, interface bus audible, and the
## platform not reporting silence.
func can_play_interface() -> bool:
	if not interface_sounds_enabled() or system_reports_silent():
		return false
	return AudioSettings.audible("interface") \
			and AudioServer.get_bus_index(BUS_INTERFACE) >= 0


## Hooks a button the moment it enters the tree. `pressed` is the only signal used, so a
## disabled button is silent and nothing plays for keyboard focus changes.
func _on_node_added(node: Node) -> void:
	if not (node is BaseButton):
		return
	var button := node as BaseButton
	if button.has_meta("audio_hooked"):
		return
	button.set_meta("audio_hooked", true)
	button.pressed.connect(play_click)


# --- Playing --------------------------------------------------------------

## The interface click. Returns true when it was actually played, false when it was not
## (sounds off, muted, or no stream) — callers never need to check anything.
func play_click() -> bool:
	return _play(_click, 0.0)


## The soft confirm tone, used when the tutorial reward is paid. Same audio settings as the
## click, and the same honest return value.
func play_confirm() -> bool:
	return _play(_confirm, 0.0)


func _play(stream: AudioStreamWAV, _offset: float) -> bool:
	if stream == null or not can_play_interface():
		return false
	_ensure_player()
	if _interface_player == null or not _interface_player.is_inside_tree():
		return false
	_interface_player.stream = stream
	_interface_player.play()
	return true


func _ensure_player() -> void:
	if _interface_player != null and is_instance_valid(_interface_player):
		return
	_interface_player = AudioStreamPlayer.new()
	_interface_player.name = "InterfacePlayer"
	_interface_player.bus = BUS_INTERFACE
	add_child(_interface_player)


## The generated click, for tests and for anything that wants to know whether the two tones
## were built at all.
func click_stream() -> AudioStreamWAV:
	return _click


func confirm_stream() -> AudioStreamWAV:
	return _confirm


func has_generated_sounds() -> bool:
	return _click != null and _confirm != null


# --- Generation -----------------------------------------------------------

## Both sounds are synthesised here: a sine with a short attack and a smooth decay. No file,
## no sample library, nothing to license.
func _build_streams() -> void:
	_click = _build_tone(CLICK_HZ, CLICK_HZ, CLICK_SECONDS, 0.5)
	_confirm = _build_tone(CONFIRM_HZ, CONFIRM_HZ_UP, CONFIRM_SECONDS, 0.35)


static func _build_tone(start_hz: float, end_hz: float, seconds: float,
		peak: float) -> AudioStreamWAV:
	var frames := int(MIX_RATE * seconds)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	for frame in frames:
		var progress := float(frame) / float(maxi(frames - 1, 1))
		var hz := lerpf(start_hz, end_hz, progress)
		phase += TAU * hz / float(MIX_RATE)
		# 8 ms attack, then a cosine decay to zero: a soft edge, never a click of its own.
		var attack := minf(progress / 0.18, 1.0)
		var decay := pow(maxf(1.0 - progress, 0.0), 2.0)
		var value := sin(phase) * peak * attack * decay
		var sample := int(clampf(value, -1.0, 1.0) * 32767.0)
		data.encode_s16(frame * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
