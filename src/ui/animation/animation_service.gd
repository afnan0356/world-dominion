class_name AnimationService
extends RefCounted
## One small animation runner for the whole interface.
##
## A screen creates one `AnimationService` for itself and hands it the node that
## owns the tweens (usually the screen). That is the whole contract:
##
## * every animation names an entry in [AnimationTokens], so durations, easing and
##   the reduced-motion answer live in one table and in `docs/ANIMATION.md`;
## * nothing here accepts input, blocks input or changes focus, so a running
##   animation can never make the interface feel unresponsive;
## * asking for a value the target already has creates **no tween at all**, which is
##   what keeps an idle screen free of animation work;
## * `cancel_all()` runs when the host leaves the tree, so closing a screen cannot
##   leave a tween writing to a freed node.
##
## Under "Reduced motion" the service applies the final value immediately and
## creates no tween. Looping animations (the selection pulse, the ambient sea) are
## not merely shortened: they do not start.

var _host: Node
var _tweens: Array[Tween] = []
var _plays := 0
var _instant_applies := 0
var _cancelled := 0


func _init(host: Node) -> void:
	_host = host
	if _host != null and not _host.tree_exiting.is_connected(cancel_all):
		_host.tree_exiting.connect(cancel_all)


## Animates one property towards `to`. Returns the tween, or `null` when the value
## is already correct or motion is not wanted — in both cases nothing is scheduled.
func play(id: String, target: Object, property: String, to: Variant,
		group: String = "") -> Tween:
	if not _usable(id, target):
		return null
	if _already_at(target, property, to):
		return null
	if Settings.get_reduce_motion() or AnimationTokens.is_loop(id):
		_apply_instantly(target, property, to)
		return null
	var tween := _new_tween(group)
	tween.tween_property(target, property, to, AnimationTokens.duration_seconds(id))
	return _start(tween)


## Animates a method call along a 0→1 parameter, for values a property tween cannot
## express (the camera is clamped on every step, so its centre is written by hand).
func play_method(id: String, target: Object, method: String, from: float, to: float,
		group: String = "") -> Tween:
	if not _usable(id, target) or not target.has_method(method):
		return null
	if is_equal_approx(from, to):
		return null
	if Settings.get_reduce_motion() or AnimationTokens.is_loop(id):
		target.call(method, to)
		_instant_applies += 1
		return null
	var tween := _new_tween(group)
	tween.tween_method(Callable(target, method), from, to,
			AnimationTokens.duration_seconds(id))
	return _start(tween)


## Repeats a property back and forth until it is cancelled. Used for cues that must
## stay alive while a state lasts (the selection outline). Returns `null` under
## reduced motion, which is the documented alternative: a still outline.
func loop(id: String, target: Object, property: String, from: Variant, to: Variant,
		group: String = "") -> Tween:
	if not _usable(id, target):
		return null
	if Settings.get_reduce_motion():
		_apply_instantly(target, property, from)
		return null
	var tween := _new_tween(group)
	tween.set_loops()
	tween.tween_property(target, property, to, AnimationTokens.duration_seconds(id))
	tween.tween_property(target, property, from, AnimationTokens.duration_seconds(id))
	return _start(tween)


## Cancels every tween in `group` (all of them when the group is empty). Cancelling
## leaves the target wherever it had got to; callers that care about the end state
## apply it themselves.
func cancel(group: String = "") -> void:
	for tween: Tween in _tweens.duplicate():
		if group.is_empty() or str(tween.get_meta("group", "")) == group:
			tween.kill()
			_tweens.erase(tween)
			_cancelled += 1


## Stops everything and forgets it. Called when the host leaves the tree, so no
## tween can outlive the node it was writing to.
func cancel_all() -> void:
	cancel("")


func active_count() -> int:
	return _tweens.size()


## How many animations were actually started, for the tests and the developer
## overlay. A screen that "does nothing" should keep this number still.
func plays() -> int:
	return _plays


func instant_applies() -> int:
	return _instant_applies


func cancelled_count() -> int:
	return _cancelled


## True when a tween is running in `group` (or anywhere, for an empty group).
func is_running(group: String = "") -> bool:
	if group.is_empty():
		return not _tweens.is_empty()
	for tween: Tween in _tweens:
		if str(tween.get_meta("group", "")) == group:
			return true
	return false


func _usable(id: String, target: Object) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not AnimationTokens.has(id):
		push_error("AnimationService: unknown animation '%s'." % id)
		return false
	return AnimationTokens.duration_seconds(id) > 0.0


func _already_at(target: Object, property: String, to: Variant) -> bool:
	var current: Variant = target.get(property)
	if current == null:
		return false
	if current is float and to is float:
		return is_equal_approx(current, to)
	return current == to


func _apply_instantly(target: Object, property: String, to: Variant) -> void:
	target.set(property, to)
	_instant_applies += 1


func _new_tween(group: String) -> Tween:
	var tween := _host.create_tween()
	tween.set_meta("group", group)
	Motion.ease_ui(tween)
	_tweens.append(tween)
	return tween


func _start(tween: Tween) -> Tween:
	_plays += 1
	tween.finished.connect(func() -> void: _tweens.erase(tween), CONNECT_ONE_SHOT)
	return tween
