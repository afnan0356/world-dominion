class_name Progression
extends RefCounted
## XP, levels, VIP tiers and the one speed VIP unlocks.
##
## ONE RULE ABOVE ALL: progression is the *profile's* business. It does not know about
## countries, turns, wins or losses, and it never gates essential gameplay. A player who
## ignores progression entirely plays exactly the same game.
##
## THE CURVE. Levels 1 to 5 need 100, 200, 250, 300 and 500 XP in total — those five are
## fixed by the owner, and they are not evenly spaced: the cost of one level is 100, 100,
## 50, 50 and 200 XP. That single dip is inside the specified table and is documented in
## docs/PROGRESSION.md. **From level 5 upward the cost of a level never decreases**, which
## is the property the curve is judged on, and the cumulative total never decreases
## anywhere:
##
##     xp_to_reach(0) = 0
##     xp_to_reach(n) = BASE[n]                              for 1 <= n <= 5
##     xp_to_reach(n) = 500 + 200 * (n - 5) + 2 * (n - 6) * (n - 5)   for n >= 6
##
## which is the same as summing `increment(level) = 200 + 4 * (level - 6)` from level 6
## upward. Every number here is an **owner-reviewable default**: the curve is a design
## choice, not a measurement, and docs/PROGRESSION.md says so in the same words.
##
## THE TABLE IS GENERATED, NOT TYPED: `python3 tools/build_progression_doc.py` writes
## docs/PROGRESSION.md from this formula, and `--check` in CI fails when the document and
## the formula disagree.

const MAX_LEVEL := 1000

## Cumulative XP to reach levels 1..5, in the order the owner specified.
const BASE_XP := [100, 200, 250, 300, 500]

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


## XP needed to go from `level - 1` to `level`. From level 5 upward this never decreases;
## inside the owner-specified table (levels 1-5) it is whatever those totals imply.
static func increment(level: int) -> int:
	if level <= 1:
		return BASE_XP[0]
	if level <= BASE_XP.size():
		return int(BASE_XP[level - 1]) - int(BASE_XP[level - 2])
	return 200 + 4 * (level - 6)


## Cumulative XP required to be at `level`. Level 0 (a fresh profile) needs none.
static func xp_to_reach(level: int) -> int:
	if level <= 0:
		return 0
	if level <= BASE_XP.size():
		return int(BASE_XP[level - 1])
	var steps := level - 5
	return 500 + 200 * steps + 2 * (level - 6) * steps


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
