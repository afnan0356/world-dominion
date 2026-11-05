class_name AnimationTokens
extends RefCounted
## The named animations, in one table.
##
## Every animated transition in the game names an entry here instead of picking a
## duration at the call site. That is what makes two promises keepable:
##
## 1. `docs/ANIMATION.md` is generated from this table, so the documentation cannot
##    drift from the code — `tools/report_animations.py --check` fails when the file
##    is stale, and a test fails when a name is used in code but missing here.
## 2. "Reduced motion" has one answer per entry, written down, instead of being
##    re-decided (or forgotten) in each screen.
##
## Fields:
##   duration_ms  how long one run takes (0 = immediate, no tween at all)
##   easing       the curve family, always one of the two named below
##   trigger      what a player does that starts it
##   reduced      what happens instead when "Reduced motion" is on
##   flashes      how many times per second it changes visibly (0 for most; a
##                pulsing animation must stay at or below three)
##   loop         true when it repeats until it is cancelled

const EASE_UI := "cubic out"
const EASE_LINEAR := "linear"
const MAX_FLASHES_PER_SECOND := 3

const CATALOGUE := {
	"camera_fly": {
		"duration_ms": 440,
		"easing": EASE_UI,
		"trigger": "Selecting a country from search, the recent list or the dossier.",
		"reduced": "Jumps straight to the country with no camera movement.",
		"flashes": 0,
		"loop": false,
	},
	"selection_pulse": {
		"duration_ms": 1200,
		"easing": EASE_UI,
		"trigger": "A country is selected while motion is allowed.",
		"reduced": "The selection outline is drawn once, at a fixed weight.",
		"flashes": 1,
		"loop": true,
	},
	"panel_slide": {
		"duration_ms": 180,
		"easing": EASE_UI,
		"trigger": "A panel opens or closes (map display options, pause menu).",
		"reduced": "The panel appears or disappears in place.",
		"flashes": 0,
		"loop": false,
	},
	"panel_fade": {
		"duration_ms": 140,
		"easing": EASE_UI,
		"trigger": "A panel's dimming layer appears or disappears.",
		"reduced": "No fade; the layer is simply there or not.",
		"flashes": 0,
		"loop": false,
	},
	"button_press": {
		"duration_ms": 90,
		"easing": EASE_UI,
		"trigger": "Pressing a button.",
		"reduced": "No scale change; the button's own pressed state is enough.",
		"flashes": 0,
		"loop": false,
	},
	"speed_change": {
		"duration_ms": 160,
		"easing": EASE_UI,
		"trigger": "Changing the simulation speed.",
		"reduced": "The speed label changes immediately.",
		"flashes": 0,
		"loop": false,
	},
	"pause_change": {
		"duration_ms": 180,
		"easing": EASE_UI,
		"trigger": "Pausing or resuming the clock.",
		"reduced": "The status label changes immediately.",
		"flashes": 0,
		"loop": false,
	},
	"campaign_start": {
		"duration_ms": 320,
		"easing": EASE_UI,
		"trigger": "A campaign starts and the opening overlay fades away.",
		"reduced": "The overlay is dismissed at once; it can also be skipped at any time.",
		"flashes": 0,
		"loop": false,
	},
	"ambient_ocean": {
		"duration_ms": 500,
		"easing": EASE_LINEAR,
		"trigger": "The campaign clock is running and the sea is on screen.",
		"reduced": "The sea is completely still.",
		"flashes": 0,
		"loop": true,
	},
}


static func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for key: Variant in CATALOGUE:
		out.append(str(key))
	out.sort()
	return out


static func has(id: String) -> bool:
	return CATALOGUE.has(id)


static func entry(id: String) -> Dictionary:
	var value: Variant = CATALOGUE.get(id)
	return value if value is Dictionary else {}


static func duration_seconds(id: String) -> float:
	return float(entry(id).get("duration_ms", 0)) / 1000.0


static func is_loop(id: String) -> bool:
	return bool(entry(id).get("loop", false))


## Visible changes per second, as declared. The service and the tests both use this
## so the "no more than three flashes per second" rule has one definition.
static func flashes_per_second(id: String) -> float:
	var declared := float(entry(id).get("flashes", 0))
	if declared <= 0.0:
		return 0.0
	var period := duration_seconds(id)
	return declared * (1.0 / period) if period > 0.0 else INF


## True when this animation must be skipped entirely under reduced motion, rather
## than merely shortened. Returning "no tween" is a stronger promise than "a shorter
## tween": a camera that jumps cannot make anyone motion-sick.
static func is_disabled_by_reduced_motion(id: String) -> bool:
	return bool(entry(id).get("loop", false)) or id == "camera_fly" or id == "campaign_start"
