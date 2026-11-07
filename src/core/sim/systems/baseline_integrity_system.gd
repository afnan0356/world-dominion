class_name BaselineIntegritySystem
extends SimulationSystem
## Keeps the campaign's record of *which data it started from* honest.
##
## THE JOB, AND WHY IT IS A REAL ONE
##
## A save does not carry 242 baseline figures; it carries a reference — the dataset id, its
## commit, and a digest of every value (`CountryState`). The game ships its data with the
## build, so a later build can ship a corrected dataset. When that happens, the baseline a
## returning player sees is not the one their campaign recorded, and the honest thing to do is
## **say so once**, in the campaign's own log, rather than silently showing different numbers
## under the same label.
##
## That is this system's whole job. It has no other state, changes no figure, and does not run
## again once it has checked:
##
## * `verify()` is called by the session when a campaign starts or is loaded, so the answer is
##   available before the first tick;
## * `update()` is the belt and braces: if a caller only ever runs the simulation, the check
##   happens on the first tick and reports the same event. After that it returns true and does
##   nothing at all, which is why it costs nothing per tick.
##
## It publishes `EventBus.BASELINE_CHANGED` only when the digests disagree. A campaign that
## matches — which is every campaign started by the same build — produces no event, because
## "nothing changed" is not news.

const ORDER_STATE := 150
const EVENT_BASELINE_CHANGED := "world.baseline_changed"

var verified := false
var last_result: Dictionary = {}


func _init() -> void:
	id = "baseline_integrity"
	order = ORDER_STATE
	frequency = Frequency.DAILY
	version = 1


## Compares the campaign's recorded reference with the data this build ships.
## Returns {ok, reason, recorded, current, records} — never throws, never repairs.
func verify(world_state: WorldState, baseline: CountryState = null) -> Dictionary:
	var shipped := baseline if baseline != null else CountryState.shared()
	var recorded := ""
	var records := 0
	if world_state != null:
		var reference := world_state.country_state_reference()
		recorded = str(reference.get("digest", ""))
		records = int(reference.get("records", 0))
	var current := shipped.digest() if shipped != null else ""
	var result := {
		"ok": not recorded.is_empty() and recorded == current,
		"recorded": recorded,
		"current": current,
		"records": records,
		"reason": "",
	}
	if recorded.is_empty():
		result["reason"] = "the campaign records no baseline reference"
	elif current.is_empty():
		result["reason"] = "the build ships no baseline data"
	elif recorded != current:
		result["reason"] = "the shipped baseline data differs from the one this campaign recorded"
	verified = true
	last_result = result
	return result


## The first update checks; every later one is a no-op that reports success. Publishing on a
## mismatch lets a caller that never calls `verify()` still get the event.
func update(context: Dictionary) -> bool:
	var state: WorldState = context.get("state")
	var bus: EventBus = context.get("bus")
	if verified:
		return true
	var result := verify(state)
	if not bool(result["ok"]) and bus != null:
		bus.publish(EVENT_BASELINE_CHANGED, {
			"reason": str(result["reason"]),
			"recorded": str(result["recorded"]).substr(0, 12),
			"current": str(result["current"]).substr(0, 12),
		})
	return true


func describe() -> String:
	return "Baseline integrity — checks once that the campaign's baseline data still matches"


## A short line for the status panel: what was compared, and whether it matched.
func status_line() -> String:
	if last_result.is_empty():
		return "not checked yet"
	if bool(last_result["ok"]):
		return "baseline matches the shipped data (%d records)" % int(last_result["records"])
	return "baseline differs: %s" % str(last_result["reason"])
