class_name ScreenRouter
extends Node
## Owns screen lifetime, navigation history and the transition between screens.
##
## The transition is a short fade to the backdrop colour, a swap at the darkest
## point, and a fade back in — so no two screens are ever visible at once and no
## screen ever paints a half-built frame. Durations come from `Motion`, which
## honours the player's reduced-motion setting.

signal screen_changed(screen_id: String)

const _FOCUS_METHOD := "focus_initial"
const _ENTRANCE_METHOD := "play_entrance"

var _host: Control
var _overlay: ColorRect
var _screens: Dictionary = {}
var _history: Array[String] = []
var _current: Control = null
var _current_id: String = ""
var _busy := false


func _init(host: Control, overlay: ColorRect, screens: Dictionary) -> void:
	name = "ScreenRouter"
	_host = host
	_overlay = overlay
	_screens = screens


## Shows the first screen without a transition.
func start(initial_id: String) -> void:
	if not _screens.has(initial_id):
		push_error("ScreenRouter: unknown start screen '%s'." % initial_id)
		return
	_set_overlay_alpha(0.0)
	_swap(initial_id)
	if _current != null and _current.has_method(_ENTRANCE_METHOD):
		_current.call(_ENTRANCE_METHOD)
	screen_changed.emit(initial_id)


## Navigates to `screen_id`. `remember` pushes the current screen onto the back
## history; going back passes false so history does not grow.
func go_to(screen_id: String, remember: bool = true) -> void:
	if _busy or screen_id == _current_id:
		return
	if not _screens.has(screen_id):
		push_error("ScreenRouter: unknown screen '%s'." % screen_id)
		return
	_busy = true
	if remember and not _current_id.is_empty():
		_history.append(_current_id)
	var reduce := Settings.get_reduce_motion()
	var fade_out := Motion.duration(DesignTokens.DURATION_SCREEN * 0.5, reduce)
	var fade_in := Motion.duration(DesignTokens.DURATION_SCREEN * 0.6, reduce)
	await _fade_to(1.0, fade_out)
	_swap(screen_id)
	if _current != null and _current.has_method(_ENTRANCE_METHOD):
		_current.call(_ENTRANCE_METHOD)
	await _fade_to(0.0, fade_in)
	_busy = false
	screen_changed.emit(screen_id)


## Returns to the previous screen. False when there is nothing to go back to.
func back() -> bool:
	if _busy or _history.is_empty():
		return false
	var previous: String = _history.pop_back()
	go_to(previous, false)
	return true


## The Control of the screen currently displayed, or null during a swap.
func current_screen() -> Control:
	return _current


func current_id() -> String:
	return _current_id


func can_go_back() -> bool:
	return not _history.is_empty()


func is_transitioning() -> bool:
	return _busy


func _swap(screen_id: String) -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	var scene: PackedScene = _screens.get(screen_id)
	var instance := scene.instantiate() if scene != null else null
	if instance == null:
		push_error("ScreenRouter: could not instantiate '%s'." % screen_id)
		return
	_current = instance as Control
	if _current == null:
		push_error("ScreenRouter: screen '%s' is not a Control." % screen_id)
		instance.queue_free()
		return
	_current_id = screen_id
	_host.add_child(_current)
	_current.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _current.has_method(_FOCUS_METHOD):
		_current.call_deferred(_FOCUS_METHOD)


func _fade_to(target_alpha: float, duration: float) -> void:
	_set_overlay_alpha(_overlay.color.a)
	if duration <= 0.0:
		_set_overlay_alpha(target_alpha)
		return
	var tween := create_tween()
	Motion.ease_ui(tween)
	tween.tween_property(_overlay, "color:a", target_alpha, duration)
	await tween.finished
	_overlay.visible = target_alpha > 0.0


func _set_overlay_alpha(alpha: float) -> void:
	var color: Color = ThemeManager.color(Palette.KEY_BG_BASE)
	color.a = alpha
	_overlay.color = color
	_overlay.visible = alpha > 0.0
