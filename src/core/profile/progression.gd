class_name Progression
extends RefCounted
## XP, levels, VIP tiers and the one speed VIP unlocks.
##
## ONE RULE ABOVE ALL: progression is the *profile's* business. It does not know about
## countries, turns, wins or losses, and it never gates essential gameplay. A player who
## ignores progression entirely plays exactly the same game.
##
## THE CURVE (as corrected by the owner in Milestone 06 pass 3). The XP needed to advance
## *from* a level is:
##
##     level 0 → 1 : 100      level 3 → 4 : 300
##     level 1 → 2 : 200      level 4 → 5 : 500
##     level 2 → 3 : 250
##
## so the cost of one level **rises at every step, with no dip**: 100, 200, 250, 300, 500.
## Above level 5 it keeps rising smoothly, by a fixed extra 50 per level:
##
##     increment(n)   = LEVEL_COSTS[n - 1]                   for 1 <= n <= 5
##     increment(n)   = 500 + 50 * (n - 5)                   for n >= 6
##     xp_to_reach(n) = the sum of increment(1..n)
##                    = 1,350 + 500 * (n - 5) + 25 * (n - 5) * (n - 4)     for n >= 5
##
## The per-level cost is strictly increasing across all 1000 levels, and a test asserts
## exactly that. Every number here is an **owner-reviewable default**: the curve is a
## design choice, not a measurement, and docs/PROGRESSION.md says so in the same words.
##
## THE TABLE IS GENERATED, NOT TYPED: `python3 tools/build_progression_doc.py` writes
## docs/PROGRESSION.md from this formula, and `--check` in CI fails when the document and
## the formula disagree.

const MAX_LEVEL := 1000

## XP needed to advance from each of the first five levels, in the owner's order:
## 0→1 costs 100, 1→2 costs 200, 2→3 costs 250, 3→4 costs 300, 4→5 costs 500.
const LEVEL_COSTS := [100, 200, 250, 300, 500]
## The extra a level costs above level 5, per level, on top of `LEVEL_COSTS[4]`.
const COST_STEP := 50

## The level at which each VIP tier begins. VIP 8 and 9 are proposals; everything above
## VIP 5 is display-only until there is something to unlock with it.
const VIP_LEVELS := [0, 25, 50, 75, 100, 150, 200, 300, 500, 750, 1000]
const MAX_VIP := 10

## The VIP tier that unlocks the extra speed. Nothing else is gated by VIP, ever.
const VIP_SPEED_TIER := 5

## Tutorial reward, once per profile. Small on purpose: enough to feel like a start,
## far too small to be a grind loop or an economy.
const TUTORIAL_XP := 100
const TUTORIAL_GOLD := 100
const TUTORIAL_DIAMONDS := 25

## The extra speed is exactly twice the current top speed, and it is still a fixed number
## of ticks per real second, so the simulation stays deterministic.
const VIP_SPEED_MULTIPLIER := 2.0


## XP needed to go from `level - 1` to `level`. Strictly increasing at every level.
static func increment(level: int) -> int:
	if level <= 0:
		return 0
	if level <= LEVEL_COSTS.size():
		return int(LEVEL_COSTS[level - 1])
	return int(LEVEL_COSTS[LEVEL_COSTS.size() - 1]) + COST_STEP * (level - 5)


## Cumulative XP required to be at `level`. Level 0 (a fresh profile) needs none.
static func xp_to_reach(level: int) -> int:
	if level <= 0:
		return 0
	if level <= LEVEL_COSTS.size():
		var total := 0
		for index in level:
			total += int(LEVEL_COSTS[index])
		return total
	var steps := level - 5
	var first_five := 0
	for cost: Variant in LEVEL_COSTS:
		first_five += int(cost)
	return first_five + 500 * steps + 25 * steps * (steps + 1)


## The level a profile with this much XP has reached. Closed-form search over the same
## function the table is generated from, so the two can never drift.
static func level_for_xp(xp: int) -> int:
	if xp <= 0:
		return 0
	var low := 0
	var high := MAX_LEVEL
	while low < high:
		var middle := (low + high + 1) / 2
		if xp_to_reach(middle) <= xp:
			low = middle
		else:
			high = middle - 1
	return low


## VIP tier for a level: derived, never stored, so a profile file cannot claim one.
static func vip_for_level(level: int) -> int:
	var tier := 0
	for index in VIP_LEVELS.size():
		if level >= int(VIP_LEVELS[index]):
			tier = index
	return clampi(tier, 0, MAX_VIP)


## The level at which a VIP tier begins, or -1 beyond the table.
static func level_for_vip(vip: int) -> int:
	if vip < 0 or vip >= VIP_LEVELS.size():
		return -1
	return int(VIP_LEVELS[vip])


## Total XP needed to reach a VIP tier; -1 when the tier does not exist.
static func xp_for_vip(vip: int) -> int:
	var level := level_for_vip(vip)
	if level < 0:
		return -1
	return xp_to_reach(level) if level > 0 else 0


## True when this VIP tier has earned the extra speed.
static func has_extra_speed(vip: int) -> bool:
	return vip >= VIP_SPEED_TIER


## The highest speed number available at this VIP tier. Speed numbers are the ones the
## game clock already uses, plus one above them.
static func max_speed_for_vip(vip: int) -> int:
	return GameClock.SPEED_MAX + (1 if has_extra_speed(vip) else 0)


## Ticks per real second for the extra speed: exactly double the shipped top speed.
static func extra_speed_ticks() -> float:
	return float(GameClock.TICKS_PER_SECOND[GameClock.SPEED_MAX]) * VIP_SPEED_MULTIPLIER


## A one-line summary for the profile screen and the docs.
static func describe_vip(vip: int) -> String:
	if vip <= 0:
		return "No VIP tier yet"
	return "VIP %d" % vip
