extends TestCase
## XP, levels, VIP tiers and the one speed VIP unlocks (Milestone 06, Task B).
##
## The curve is a design choice, so the tests pin the parts the owner specified and the
## properties that must hold whatever the numbers become: the first five totals, XP per
## level never decreasing, monotonic totals, VIP boundaries, and the speed unlock being
## exactly one extra tier at double the top speed.


func test_the_first_five_levels_are_the_ones_specified() -> void:
	check_eq(Progression.xp_to_reach(0), 0, "a fresh profile needs no XP")
	check_eq(Progression.xp_to_reach(1), 100, "level 1 costs 100 XP")
	check_eq(Progression.xp_to_reach(2), 200, "level 2 costs 200 XP in total")
	check_eq(Progression.xp_to_reach(3), 250, "level 3 costs 250 XP in total")
	check_eq(Progression.xp_to_reach(4), 300, "level 4 costs 300 XP in total")
	check_eq(Progression.xp_to_reach(5), 500, "level 5 costs 500 XP in total")


func test_xp_per_level_never_decreases_from_level_five() -> void:
	# The five specified totals imply a dip in the middle of the table (100, 100, 50, 50,
	# 200); that is the owner's table, not a bug. From level 5 upward the cost of a level
	# must never fall, and the cumulative total must rise at every level.
	var previous := Progression.increment(5)
	var worst := ""
	for level in range(6, Progression.MAX_LEVEL + 1):
		var step := Progression.increment(level)
		check_true(step > 0, "level %d costs something" % level)
		if step < previous and worst.is_empty():
			worst = "level %d costs %d, after %d at level %d" % [level, step, previous, level - 1]
		previous = step
	check_eq(worst, "", "the XP needed per level never decreases from level 5 upward")


func test_totals_are_monotonic_and_add_up() -> void:
	var previous := 0
	var wrong := ""
	for level in range(1, Progression.MAX_LEVEL + 1):
		var total := Progression.xp_to_reach(level)
		if total <= previous and wrong.is_empty():
			wrong = "level %d total %d does not exceed %d" % [level, total, previous]
		previous = total
		# The closed form must equal the sum of the increments it stands for.
		var summed := 0
		for step_level in range(1, level + 1):
			summed += Progression.increment(step_level)
		if summed != total and wrong.is_empty():
			wrong = "level %d: closed form %d, sum of steps %d" % [level, total, summed]
	check_eq(wrong, "", "totals rise and match their own increments")
	check_gt(float(Progression.xp_to_reach(Progression.MAX_LEVEL)), 0.0,
			"level 1000 is reachable and has a total")


func test_level_lookup_inverts_the_curve() -> void:
	var wrong := ""
	for level in [0, 1, 2, 3, 4, 5, 6, 7, 50, 99, 100, 500, 999, 1000]:
		var total := Progression.xp_to_reach(level)
		if Progression.level_for_xp(total) != level and wrong.is_empty():
			wrong = "level %d has %d XP but reads as level %d" \
					% [level, total, Progression.level_for_xp(total)]
		if total > 0 and Progression.level_for_xp(total - 1) >= level and wrong.is_empty():
			wrong = "one XP short of level %d still reads as level %d" \
					% [level, Progression.level_for_xp(total - 1)]
	check_eq(wrong, "", "the level lookup lands exactly on the curve")
	check_eq(Progression.level_for_xp(0), 0, "no XP is level 0")
	check_eq(Progression.level_for_xp(-5), 0, "negative XP is level 0, never an error")


func test_vip_boundaries_are_exact() -> void:
	var table := {
		0: 0, 24: 0, 25: 1, 49: 1, 50: 2, 74: 2, 75: 3, 99: 3, 100: 4, 149: 4,
		150: 5, 199: 5, 200: 6, 299: 6, 300: 7, 499: 7, 500: 8, 749: 8, 750: 9,
		999: 9, 1000: 10,
	}
	for level: int in table:
		check_eq(Progression.vip_for_level(level), int(table[level]),
				"level %d is VIP %d" % [level, int(table[level])])
	check_eq(Progression.vip_for_level(5000), 10, "VIP never exceeds 10")
	check_eq(Progression.vip_for_level(-3), 0, "a negative level is VIP 0")


func test_vip_totals_are_reported() -> void:
	check_eq(Progression.xp_for_vip(0), 0, "VIP 0 costs nothing")
	check_eq(Progression.xp_for_vip(1), Progression.xp_to_reach(25), "VIP 1 totals at level 25")
	check_eq(Progression.xp_for_vip(5), Progression.xp_to_reach(150), "VIP 5 at level 150")
	check_eq(Progression.xp_for_vip(10), Progression.xp_to_reach(1000), "VIP 10 at level 1000")
	check_eq(Progression.xp_for_vip(11), -1, "there is no VIP 11")


func test_the_extra_speed_is_one_tier_at_double_the_top_speed() -> void:
	check_eq(GameClock.SPEED_MAX, 4, "every player still has the four shipped speeds")
	check_eq(Progression.max_speed_for_vip(0), GameClock.SPEED_MAX, "VIP 0 adds no speed")
	check_eq(Progression.max_speed_for_vip(4), GameClock.SPEED_MAX, "VIP 4 adds no speed")
	check_eq(Progression.max_speed_for_vip(5), GameClock.SPEED_MAX + 1, "VIP 5 adds one")
	check_eq(Progression.max_speed_for_vip(10), GameClock.SPEED_MAX + 1, "and only one")
	check_eq(Progression.extra_speed_ticks(),
			float(GameClock.TICKS_PER_SECOND[GameClock.SPEED_MAX]) * 2.0,
			"the extra speed is exactly double the top speed")
	check_eq(float(GameClock.TICKS_PER_SECOND[5]), 256.0, "256 ticks per second")
	check_false(Progression.has_extra_speed(4), "VIP 4 does not have it")
	check_true(Progression.has_extra_speed(5), "VIP 5 does")


func test_the_clock_clamps_to_what_the_player_has_earned() -> void:
	var clock := GameClock.new()
	clock.set_speed(5)
	check_eq(clock.speed, GameClock.SPEED_MAX, "without VIP the clock stops at the top speed")
	clock.set_speed(5, Progression.max_speed_for_vip(5))
	check_eq(clock.speed, 5, "with VIP 5 the extra speed is reachable")
	clock.set_speed(9, Progression.max_speed_for_vip(5))
	check_eq(clock.speed, GameClock.SPEED_MAX_VIP, "and it clamps at the extra speed")
	clock.set_speed(0, Progression.max_speed_for_vip(5))
	check_eq(clock.speed, GameClock.PAUSED, "pause still works for everyone")


func test_speeds_are_tick_based_and_deterministic() -> void:
	# The same number of ticks at the same speed produces the same date every time: the
	# extra speed changes how long the player waits, never what is computed.
	var first := _ticks_to_date(5, 400)
	var second := _ticks_to_date(5, 400)
	check_eq(first, second, "the same run gives the same date")
	var slower := _ticks_to_date(4, 400)
	check_eq(first, slower, "the extra speed is not a different simulation")


func _ticks_to_date(speed: int, ticks: int) -> String:
	var clock := GameClock.new()
	clock.set_speed(speed, GameClock.SPEED_MAX_VIP)
	# `step()` is the deterministic per-tick advance the frame loop calls; the speed only
	# decides how many of them a real second contains. Same ticks, same date.
	for index in ticks:
		clock.step()
	return str(clock.day_index)


func test_tutorial_reward_is_small_and_documented() -> void:
	check_true(Progression.TUTORIAL_XP > 0, "the tutorial teaches something worth XP")
	check_true(Progression.TUTORIAL_XP <= Progression.xp_to_reach(2),
			"but not more than the first two levels")
	check_true(Progression.TUTORIAL_GOLD <= 1000, "gold is a token amount, not an economy")
	check_true(Progression.TUTORIAL_DIAMONDS < PlayerProfile.NAME_CHANGE_COST,
			"the tutorial does not pay for a name change by itself")


func test_the_document_matches_the_implementation() -> void:
	# Two copies of one formula drift. The Python tool writes docs/PROGRESSION.md and CI
	# fails when it is stale; this test closes the other half of the loop by reading the
	# numbers out of the document and checking them against the code the game runs.
	var text := FileAccess.get_file_as_string("res://docs/PROGRESSION.md")
	check_false(text.is_empty(), "the progression document is committed")
	if text.is_empty():
		return
	var opener := text.find("<!-- progression-data")
	var closer := text.find("-->", opener)
	check_true(opener >= 0 and closer > opener, "it carries a machine-readable block")
	if opener < 0 or closer <= opener:
		return
	var payload := text.substr(opener + len("<!-- progression-data"), closer - opener)
	var parsed: Variant = JSON.parse_string(payload)
	check_true(parsed is Dictionary, "the block is JSON")
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	check_eq(int(data.get("max_level", 0)), Progression.MAX_LEVEL, "the document knows the cap")
	check_eq(int(data.get("max_vip", 0)), Progression.MAX_VIP, "and the VIP ceiling")
	var vip_levels: Array = data.get("vip_levels", [])
	check_eq(vip_levels.size(), Progression.VIP_LEVELS.size(), "and every VIP threshold")
	for index in vip_levels.size():
		check_eq(int(vip_levels[index]), int(Progression.VIP_LEVELS[index]),
				"VIP %d starts at level %d" % [index, int(vip_levels[index])])
	var sampled: Dictionary = data.get("sampled", {})
	check_gt(float(sampled.size()), 0.0, "the document samples levels")
	for key: String in sampled:
		check_eq(int(sampled[key]), Progression.xp_to_reach(int(key)),
				"level %s needs the same XP in both places" % key)
	var tutorial: Dictionary = data.get("tutorial", {})
	check_eq(int(tutorial.get("xp", -1)), Progression.TUTORIAL_XP, "the tutorial XP agrees")
	check_eq(int(tutorial.get("gold", -1)), Progression.TUTORIAL_GOLD, "the gold agrees")
	check_eq(int(tutorial.get("diamonds", -1)), Progression.TUTORIAL_DIAMONDS,
			"the Diamonds agree")
	var speed: Dictionary = data.get("speed", {})
	check_eq(int(speed.get("vip_tier", -1)), Progression.VIP_SPEED_TIER,
			"the VIP speed tier agrees")
	var ticks: Dictionary = speed.get("ticks", {})
	for key: String in ticks:
		check_eq(int(ticks[key]), int(GameClock.TICKS_PER_SECOND[int(key)]),
				"speed %s has the same tick rate in both places" % key)
