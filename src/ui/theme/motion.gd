class_name Motion
extends RefCounted
## Motion helpers.
##
## Every animated transition in the interface routes through `duration()` so the
## player's "Reduced motion" setting is honoured in one place. Transitions are
## short (120–260 ms) and use a single easing family — cubic ease-out — so the
## game feels quick and calm rather than showy.

const TRANSITION := Tween.TRANS_CUBIC
const EASE := Tween.EASE_OUT


## Duration for a transition, or 0.0 when the player asked for reduced motion.
static func duration(base_duration: float, reduce_motion: bool) -> float:
	if reduce_motion or base_duration <= 0.0:
		return 0.0
	return base_duration


## Stagger delay for the n-th item of an entering group.
static func stagger(index: int, reduce_motion: bool) -> float:
	if reduce_motion:
		return 0.0
	return maxf(0.0, float(index)) * DesignTokens.STAGGER_STEP


## Applies the shared easing curve to a tween created for a UI transition.
static func ease_ui(tween: Tween) -> Tween:
	return tween.set_trans(TRANSITION).set_ease(EASE)
