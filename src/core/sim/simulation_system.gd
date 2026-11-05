class_name SimulationSystem
extends RefCounted
## Base class for every future simulation system (economy, politics, diplomacy…).
##
## A system declares three things and nothing else is assumed about it:
##
## * `order` — where it sits in the update sequence. Lower runs first. The
##   documented bands are: 0–99 clock and time, 100–199 state derivation,
##   200–299 systems that read derived state, 900+ reporting and bookkeeping.
## * `frequency` — how often it should run: every day, on the first day of a
##   month, or on the first day of a year. A monthly system runs *on* the first of
##   the month, never "whenever it happens to be called".
## * `version` — the version of the system's own rules, so a future save format
##   can migrate a system's state without guessing.
##
## `update()` must be deterministic: it may use the random stream named after the
## system, and must not read the clock, the frame time or the player's device.
## Anything that would make two identical campaigns diverge is a bug here.
##
## This milestone registers exactly one system, `CalendarSystem`. Placeholder
## systems are deliberately absent: a system that does nothing but exist would
## make the status panel lie.

enum Frequency { DAILY, MONTHLY, YEARLY }

const FREQUENCY_LABELS := {
	Frequency.DAILY: "daily",
	Frequency.MONTHLY: "monthly",
	Frequency.YEARLY: "yearly",
}

var id := ""
var order := 500
var frequency: Frequency = Frequency.DAILY
var version := 1


## Runs one update. `context` carries the clock date and the shared services
## (event bus, random streams, world state). Return false to report a skipped
## update; the simulation counts it and keeps going rather than aborting a tick.
func update(_context: Dictionary) -> bool:
	return true


## True when this system should run for the date the clock has just reached.
func is_due(date: GameDate) -> bool:
	match frequency:
		Frequency.MONTHLY:
			return date.day == 1
		Frequency.YEARLY:
			return date.month == 1 and date.day == 1
		_:
			return true


func frequency_label() -> String:
	return FREQUENCY_LABELS.get(frequency, "daily")


## A short, honest description for the simulation-status panel. Systems override
## it; the base text says nothing it cannot back up.
func describe() -> String:
	return "%s — %s, version %d" % [id, frequency_label(), version]
