class_name GameClock
extends RefCounted
## The simulation clock: an in-game date that advances in whole days (ticks).
##
## TICK LENGTH: one tick is **one in-game day**. That is the unit every future
## system measures itself in, and it is fixed for this milestone.
##
## SPEED is defined as a number of ticks per *real second*, never as "once per
## frame". A device drawing 30 frames per second and a device drawing 120 frames
## per second therefore advance the same number of days per real second, and a
## slow frame does not advance the world further than a fast one — it only means
## more ticks are due in that frame.
##
## FRAME-TIME SAFETY: `advance()` never skips and never double-runs a tick. Time
## that is due but cannot be processed in one frame (because of the per-frame cap)
## stays in the accumulator and is processed by the following frames. The cap
## exists so that one very long frame cannot freeze the game catching up; it
## delays ticks, it never drops them.
##
## PAUSE means zero ticks: the date does not move and no system runs. Pausing does
## not clear the accumulator, so resuming continues from the same fraction of a
## tick rather than gaining or losing time.

const TICK_DAYS := 1
const PAUSED := 0
const SPEED_MIN := 1
## The highest speed every player has, always: fast-forward.
const SPEED_MAX := 2
## One speed above that, unlocked by VIP 5 and above (see Progression).
const SPEED_MAX_VIP := 3
## THE THREE SPEEDS (owner decision, Milestone 06 pass 3). One tick is one in-game day,
## so these numbers are days per real second:
##
##   | Speed | Days per real second | Who has it |
##   | ----: | -------------------: | ---------- |
##   | 1     |  1 (default)         | everyone   |
##   | 2     | 10                   | everyone   |
##   | 3     | 20                   | VIP 5 and above |
##
## They replaced the earlier four-speed set (2, 8, 32, 128). Saves store a stable speed
## **id** as well as the number, and `migrate_legacy_speed()` maps an old stored number to
## the nearest new speed — never up to the VIP speed, which has to be earned.
const TICKS_PER_SECOND := {1: 1.0, 2: 10.0, 3: 20.0}
const SPEED_LABELS := {1: "Normal", 2: "Fast-forward", 3: "VIP fast-forward"}
const SPEED_SHORT := {1: "1×", 2: "10×", 3: "20×"}
## Stable ids: a save names its speed by these, so renumbering the speeds later cannot
## change what an existing save means.
const SPEED_IDS := {0: "paused", 1: "normal", 2: "fast_forward", 3: "vip_fast_forward"}
## The reverse lookup, built once.
const SPEED_BY_ID := {
	"paused": 0, "normal": 1, "fast_forward": 2, "vip_fast_forward": 3,
}
## Old stored numbers (the previous four-speed set and the new one overlap at 1 and 2) to
## the speed that means the same thing today. 3 and 4 were 32 and 128 days per second; the
## nearest speed everyone has is 2 (10 days per second). No migration ever grants VIP.
const LEGACY_SPEED_MAP := {0: 0, 1: 1, 2: 2, 3: 2, 4: 2}
## At most this many ticks per frame are processed. Beyond it the remainder waits
## for the next frame, so a 400 ms hitch does not turn into a 40 ms-per-frame
## catch-up burst that stutters for seconds.
const MAX_TICKS_PER_FRAME := 64
## The documented start of the Modern World scenario. A save stores the day index
## as well, so changing this constant never moves an existing campaign.
const MODERN_WORLD_START := "2026-01-01"

var speed := PAUSED
## True when `restore()` had to translate an older stored speed. The interface can say so;
## nothing is hidden and nothing is reset.
var migrated_speed := false
var day_index := 1
var accumulator := 0.0
## Diagnostics: how many ticks were deferred because of the per-frame cap. The
## game never hides this; the developer overlay shows it and tests assert it.
var capped_frames := 0


static func for_new_campaign(start_date: String) -> GameClock:
	var clock := GameClock.new()
	var parsed := GameDate.parse(start_date)
	clock.day_index = parsed.to_day_index() if parsed != null else GameDate.parse(
			MODERN_WORLD_START).to_day_index()
	clock.speed = 1
	return clock


func date() -> GameDate:
	return GameDate.from_day_index(day_index)


func set_date(date: GameDate) -> void:
	if date == null or not date.is_valid_date():
		return
	day_index = date.to_day_index()
	accumulator = 0.0


func is_paused() -> bool:
	return speed == PAUSED


func ticks_per_second() -> float:
	return float(TICKS_PER_SECOND.get(speed, 0.0))


## Milliseconds of real time per in-game day at the current speed; 0 when paused.
func milliseconds_per_tick() -> float:
	var rate := ticks_per_second()
	if rate <= 0.0:
		return 0.0
	return 1000.0 / rate


## Set the speed, clamped to what this player is allowed. `max_speed` defaults to the
## speed every player has, so an existing caller cannot accidentally hand out the VIP
## speed; the session passes Progression.max_speed_for_vip(profile.vip()).
func set_speed(value: int, max_speed: int = SPEED_MAX) -> void:
	var ceiling := clampi(max_speed, SPEED_MIN, SPEED_MAX_VIP)
	speed = clampi(value, PAUSED, ceiling)


func pause() -> void:
	speed = PAUSED


func resume() -> void:
	if speed == PAUSED:
		speed = 2


## Space bar behaviour: pause if running, otherwise resume at the previous speed.
func toggle_pause() -> void:
	if is_paused():
		resume()
	else:
		pause()


func speed_label() -> String:
	if is_paused():
		return "Paused"
	return str(SPEED_LABELS.get(speed, ""))


func speed_short() -> String:
	return "❚❚" if is_paused() else str(SPEED_SHORT.get(speed, ""))


## How many ticks this frame should run. Pure arithmetic on real elapsed time;
## the remainder is carried, so ticks are delayed but never lost.
func advance(delta_seconds: float) -> int:
	if is_paused() or delta_seconds <= 0.0:
		return 0
	accumulator += delta_seconds * ticks_per_second()
	var due := int(floor(accumulator))
	if due <= 0:
		return 0
	var run := mini(due, MAX_TICKS_PER_FRAME)
	if due > run:
		capped_frames += 1
	accumulator -= float(run)
	return run


## Moves the calendar forward one tick. Called once per tick by the simulation,
## never by the interface, so the date can only change where systems can react.
func step() -> void:
	day_index = mini(day_index + TICK_DAYS, GameDate.max_day_index())


## The bits of the clock that are game state. The sub-tick accumulator is
## deliberately not saved: it depends on frame timing, and a reload must resume on
## an exact date rather than 0.4 of a day later.
func to_dict() -> Dictionary:
	return {
		"day_index": day_index,
		"speed": speed,
		"speed_id": str(SPEED_IDS.get(speed, "paused")),
	}


## Old stored speed number → today's speed. Public so the migration is testable on its own
## and so save code can reuse it instead of inventing a second rule.
static func migrate_legacy_speed(stored: int) -> int:
	return int(LEGACY_SPEED_MAP.get(clampi(stored, 0, 4), SPEED_MAX))


## Restores saved values, rejecting anything that is not a plain integer in range.
## Returns the number of problems found; the caller decides whether to refuse the
## save. Nothing is substituted silently.
func restore(data: Dictionary, issues: Array = []) -> int:
	var problems := 0
	# JSON hands a reader a number, not an "int": whole values are accepted, a
	# fractional day is refused rather than rounded.
	var day_value: Variant = CanonicalJson.int_value(data.get("day_index"))
	if day_value != null and int(day_value) >= 1 \
			and int(day_value) <= GameDate.max_day_index():
		day_index = int(day_value)
	else:
		issues.append("clock day_index is missing or out of range")
		problems += 1
	# The stable id is authoritative; the bare number is accepted from older saves and
	# translated. A file with neither is a problem the caller must decide about.
	var speed_id := str(data.get("speed_id", ""))
	var speed_value: Variant = CanonicalJson.int_value(data.get("speed"))
	migrated_speed = false
	if SPEED_BY_ID.has(speed_id):
		speed = int(SPEED_BY_ID[speed_id])
	elif speed_value != null and int(speed_value) >= PAUSED:
		var stored := int(speed_value)
		speed = migrate_legacy_speed(stored)
		migrated_speed = stored != speed
	else:
		issues.append("clock speed is missing or out of range")
		problems += 1
	accumulator = 0.0
	return problems
