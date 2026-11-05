class_name PressFeedback
extends RefCounted
## A short scale dip when a button is pressed, and nothing else.
##
## One helper, attached in a handful of places (`SegmentedControl`, `NavRow`,
## `MapControls`, the map display panel), so a press feels acknowledged without
## every screen inventing its own motion. The dip is 3% for 90 ms: enough to feel,
## too small to move a layout or to matter if a frame is dropped.
##
## Under "Reduced motion" no scale animation is created at all — the button's own
## pressed styling is the feedback, which the theme already provides. The scale is
## restored on release and on focus loss, so a cancelled press can never leave a
## button looking stuck.

const ANIMATION := "button_press"
const PRESSED_SCALE := 0.97


static func attach(button: BaseButton) -> void:
	if button == null or button.has_meta("press_feedback"):
		return
	button.set_meta("press_feedback", true)
	button.button_down.connect(func() -> void: _to(button, PRESSED_SCALE))
	button.button_up.connect(func() -> void: _to(button, 1.0))
	button.mouse_exited.connect(func() -> void: _to(button, 1.0))
	button.focus_exited.connect(func() -> void: _to(button, 1.0))


static func _to(button: BaseButton, value: float) -> void:
	if Settings.get_reduce_motion() or not is_instance_valid(button):
		button.scale = Vector2.ONE
		return
	if is_equal_approx(button.scale.x, value):
		return
	button.pivot_offset = button.size * 0.5
	var duration := AnimationTokens.duration_seconds(ANIMATION)
	var tween := button.create_tween()
	Motion.ease_ui(tween)
	tween.tween_property(button, "scale", Vector2(value, value), duration)
