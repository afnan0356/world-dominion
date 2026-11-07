class_name Simulation
extends RefCounted
## Runs the clock and the registered systems. No UI, no scene, no engine nodes:
## it can be constructed in a test and advanced a thousand times in a loop.
##
## The order of a tick is fixed and documented:
##
##   1. the clock moves forward one day (`clock.step()`);
##   2. every registered system whose frequency matches the new date runs, in
##      ascending `order` then by id (a total order, so a replay is identical);
##   3. systems publish events; the bus delivers them after the current handler
##      returns, never in the middle of another system's update.
##
## A system that returns false is counted as skipped and the tick continues: one
## misbehaving system must not freeze the calendar for the player.
##
## Frequency, not polling: a monthly system runs exactly on the first day of each
## month. If the game is paused for a week of real time, nothing accumulates —
## ticks only happen when `advance()` is called with real elapsed time, and the
## clock carries the remainder so no tick is ever skipped or run twice.

const TICK_TIME_KEY := "tick_microseconds"

var clock: GameClock
var bus: EventBus
var state: WorldState
var total_ticks := 0
var skipped_updates := 0
var last_frame_ticks := 0
var last_frame_microseconds := 0
var last_tick_microseconds := 0

var _systems: Array[SimulationSystem] = []


static func for_state(world_state: WorldState) -> Simulation:
	var sim := Simulation.new()
	sim.state = world_state
	sim.clock = world_state.clock if world_state != null else GameClock.for_new_campaign(
			GameClock.MODERN_WORLD_START)
	sim.bus = EventBus.new()
	return sim


## Registers a system. Refuses a duplicate id, an empty id or a negative order,
## because a registration mistake must be loud rather than a silently missing
## update step.
func register_system(system: SimulationSystem) -> bool:
	if system == null or system.id.is_empty():
		push_error("Simulation: a system needs a non-empty id.")
		return false
	if system.order < 0:
		push_error("Simulation: system '%s' has a negative order." % system.id)
		return false
	for existing: SimulationSystem in _systems:
		if existing.id == system.id:
			push_error("Simulation: system '%s' is already registered." % system.id)
			return false
	_systems.append(system)
	_systems.sort_custom(func(a: SimulationSystem, b: SimulationSystem) -> bool:
		if a.order == b.order:
			return a.id < b.id
		return a.order < b.order)
	return true


func systems() -> Array[SimulationSystem]:
	return _systems.duplicate()


func has_system(system_id: String) -> bool:
	for system: SimulationSystem in _systems:
		if system.id == system_id:
			return true
	return false


## Registers the systems this build actually ships: the calendar, and the baseline
## integrity check. Kept in one function so the status panel and the tests can assert
## that no placeholder has crept in.
##
## `baseline_integrity` (Milestone 11) has a real job and does it once: it compares the
## dataset reference a campaign recorded with the dataset this build ships, and reports a
## mismatch in the campaign's own log. It is not a placeholder — a system that only existed
## to make a list longer would be deleted rather than registered.
func register_shipped_systems() -> void:
	if not has_system("calendar"):
		register_system(CalendarSystem.new())
	if not has_system("baseline_integrity"):
		register_system(BaselineIntegritySystem.new())


## Advances the simulation by real elapsed time. Returns the number of ticks run
## this frame (0 when paused or when no full tick is due yet).
func advance(delta_seconds: float) -> int:
	last_frame_ticks = 0
	var started := Time.get_ticks_usec()
	var due := clock.advance(delta_seconds)
	for _tick in due:
		_tick_once()
	last_frame_microseconds = Time.get_ticks_usec() - started
	last_frame_ticks = due
	return due


func _tick_once() -> void:
	clock.step()
	total_ticks += 1
	var date := clock.date()
	var tick_started := Time.get_ticks_usec()
	for system: SimulationSystem in _systems:
		if not system.is_due(date):
			continue
		if not system.update(_context(date)):
			skipped_updates += 1
	last_tick_microseconds = Time.get_ticks_usec() - tick_started


func _context(date: GameDate) -> Dictionary:
	return {
		"date": date,
		"clock": clock,
		"bus": bus,
		"streams": state.streams if state != null else null,
		"state": state,
	}


## One line per registered system, for the simulation-status panel. Consumers
## display this verbatim so the panel cannot claim a system that is not here.
func describe_systems() -> PackedStringArray:
	var lines := PackedStringArray()
	for system: SimulationSystem in _systems:
		lines.append(system.describe())
	return lines
