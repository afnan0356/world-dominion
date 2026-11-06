extends TestCase
## XP, levels, VIP tiers, the three speeds and the speed migration (Milestone 06, Task 1).
##
## The owner's correction is pinned here: the XP needed to advance **from** each of the
## first five levels is 100, 200, 250, 300 and 500, so the per-level cost rises at every
## step with no dip, and it keeps rising to level 1000. The speeds are exactly three:
## Normal (1 day per real second, the default), Fast-forward (10) for everyone, and one
## more at 20 for VIP 5 and above.

const LEGACY_FIXTURE := "res://tests/fixtures/save_schema1_frozen.json"


func test_the_first_five_per_level_costs_are_the_ones_specified() -> void:
	for level in range(1, 6):
		check_eq(Progression.increment(level), int(Progression.LEVEL_COSTS[level - 1]),
				"advancing from level %d costs %d XP" % [level - 1, Progression.increment(level)])
	check_eq(Progression.increment(1), 100, "level 0 to 1 costs 100")
	check_eq(Progression.increment(2), 200, "level 1 to 2 costs 200")
	check_eq(Progression.increment(3), 250, "level 2 to 3 costs 250")
	check_eq(Progression.increment(4), 300, "level 3 to 4 costs 300")
	check_eq(Progression.increment(5), 500, "level 4 to 5 costs 500")
	check_eq(Progression.xp_to_reach(0), 0, "a fresh profile needs no XP")
	check_eq(Progression.xp_to_reach(1), 100, "level 1 needs 100 XP in total")
	check_eq(Progression.xp_to_reach(2), 300, "level 2 needs 300 in total")
	check_eq(Progression.xp_to_reach(3), 550, "level 3 needs 550 in total")
	check_eq(Progression.xp_to_reach(4), 850, "level 4 needs 850 in total")
	check_eq(Progression.xp_to_reach(5), 1350, "level 5 needs 1,350 in total")


func test_the_per_level_cost_rises_at_every_step() -> void:
	var previous := 0
	var worst := ""
	for level in range(1, Progression.MAX_LEVEL + 1):
		var cost := Progression.increment(level)
		if cost <= previous and worst.is_empty():
			worst = "level %d costs %d after %d" % [level, cost, previous]
		previous = cost
	check_eq(worst, "", "the XP needed per level rises strictly across all 1000 levels")
	check_eq(Progression.increment(6), 550, "level 6 continues the rise by 50")
	check_eq(Progression.increment(7), 600, "and level 7 by another 50")


func test_totals_are_monotonic_and_match_their_own_steps() -> void:
	var previous := 0
	var wrong := ""
	for level in range(1, Progression.MAX_LEVEL + 1):
		var total := Progression.xp_to_reach(level)
		if total <= previous and wrong.is_empty():
			wrong = "level %d total %d does not exceed %d" % [level, total, previous]
		previous = total
		var summed := 0
		for step_level in range(1, level + 1):
			summed += Progression.increment(step_level)
		if summed != total and wrong.is_empty():
			wrong = "level %d: closed form %d, sum of steps %d" % [level, total, summed]
	check_eq(wrong, "", "totals rise and match their own increments")
	check_eq(Progression.xp_to_reach(Progression.MAX_LEVEL), 25274350,
			"level 1000 needs 25,274,350 XP")


func test_level_lookup_inverts_the_curve() -> void:
	var wrong := ""
	for level in [0, 1, 2, 3, 4, 5, 6, 7, 50, 99, 100, 500, 999, 1000]:
		var total := Progression.xp_to_reach(level)
		if Progression.level_for_xp(total) != level and wrong.is_empty():
			wrong = "level %d has %d XP but reads as level %d" % [level, total,
					Progression.level_for_xp(total)]
		if total > 0 and Progression.level_for_xp(total - 1) >= level and wrong.is_empty():
			wrong = "one XP short of level %d reads as level %d" % [level,
					Progression.level_for_xp(total - 1)]
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
	var totals := [0, 21850, 75600, 160600, 276850, 603100, 1054350, 2331850, 6386850,
			14268100, 25274350]
	for tier in totals.size():
		check_eq(Progression.xp_for_vip(tier), int(totals[tier]),
				"VIP %d totals %d XP" % [tier, int(totals[tier])])
	check_eq(Progression.xp_for_vip(11), -1, "there is no VIP 11")


func test_there_are_exactly_three_speeds() -> void:
	check_eq(GameClock.SPEED_MAX, 2, "two speeds are available to everyone")
	check_eq(GameClock.SPEED_MAX_VIP, 3, "and one more at VIP 5")
	check_eq(float(GameClock.TICKS_PER_SECOND[1]), 1.0, "Normal is one day per real second")
	check_eq(float(GameClock.TICKS_PER_SECOND[2]), 10.0, "Fast-forward is ten")
	check_eq(float(GameClock.TICKS_PER_SECOND[3]), 20.0, "the VIP speed is twenty")
	check_eq(GameClock.TICKS_PER_SECOND.size(), 3, "there is no fourth speed")
	check_eq(int(GameClock.PAUSED), 0, "pause is speed 0")
	check_eq(str(GameClock.SPEED_IDS[1]), "normal", "speeds have stable ids for saves")
	check_eq(str(GameClock.SPEED_IDS[3]), "vip_fast_forward", "including the VIP one")


func test_the_extra_speed_is_unlocked_by_vip_five_only() -> void:
	check_eq(Progression.max_speed_for_vip(0), 2, "VIP 0 has Fast-forward")
	check_eq(Progression.max_speed_for_vip(4), 2, "VIP 4 has no more")
	check_eq(Progression.max_speed_for_vip(5), 3, "VIP 5 unlocks the third speed")
	check_eq(Progression.max_speed_for_vip(10), 3, "and only the third")
	check_false(Progression.has_extra_speed(4), "VIP 4 does not have it")
	check_true(Progression.has_extra_speed(5), "VIP 5 does")
	check_eq(Progression.extra_speed_ticks(), 20.0, "and it is twenty days per second")
	check_eq(Progression.extra_speed_ticks(),
			float(GameClock.TICKS_PER_SECOND[GameClock.SPEED_MAX]) * 2.0,
			"exactly double the top speed everyone has")


func test_the_clock_clamps_to_what_the_player_has_earned() -> void:
	var clock := GameClock.new()
	clock.set_speed(3)
	check_eq(clock.speed, 2, "without VIP the clock stops at Fast-forward")
	clock.set_speed(3, Progression.max_speed_for_vip(5))
	check_eq(clock.speed, 3, "with VIP 5 the third speed is reachable")
	clock.set_speed(9, Progression.max_speed_for_vip(5))
	check_eq(clock.speed, GameClock.SPEED_MAX_VIP, "and it clamps at the third speed")
	clock.set_speed(0, Progression.max_speed_for_vip(5))
	check_eq(clock.speed, GameClock.PAUSED, "pause still works for everyone")


func test_speeds_are_tick_based_and_deterministic() -> void:
	check_eq(_ticks_to_day(1, 10), _ticks_to_day(1, 10), "the same ticks give the same date")
	check_eq(_ticks_to_day(3, 10), _ticks_to_day(1, 10),
			"the extra speed changes waiting time, not the simulation")
	var clock := GameClock.new()
	check_eq(clock.advance(1.0), 0, "a bare clock is paused and advances nothing")
	clock.set_speed(1)
	check_eq(clock.advance(1.0), 1, "one second at Normal advances one day")
	check_eq(clock.speed, 1, "and the clock was at Normal")
	clock.set_speed(2)
	check_eq(clock.advance(1.0), 10, "one second at Fast-forward advances ten days")
	clock.set_speed(3, GameClock.SPEED_MAX_VIP)
	check_eq(clock.advance(0.5), 10, "half a second at the VIP speed advances ten days")


func test_a_saved_speed_is_a_stable_id_and_old_numbers_are_migrated() -> void:
	var clock := GameClock.new()
	clock.set_speed(2)
	clock.step()
	var saved := clock.to_dict()
	check_eq(str(saved.get("speed_id", "")), "fast_forward", "the save names the speed")
	check_eq(int(saved.get("speed", -1)), 2, "and keeps the number for older builds")
	var restored := GameClock.new()
	restored.restore(saved)
	check_eq(restored.speed, 2, "a save with an id restores exactly")
	check_false(restored.migrated_speed, "and nothing had to be migrated")

	check_eq(GameClock.migrate_legacy_speed(0), 0, "old paused stays paused")
	check_eq(GameClock.migrate_legacy_speed(1), 1, "old 1 (2 days/s) is the nearest to Normal")
	check_eq(GameClock.migrate_legacy_speed(2), 2, "old 2 (8 days/s) is nearest Fast-forward")
	check_eq(GameClock.migrate_legacy_speed(3), 2, "old 3 (32 days/s) becomes Fast-forward")
	check_eq(GameClock.migrate_legacy_speed(4), 2, "old 4 (128 days/s) becomes Fast-forward")
	check_true(GameClock.migrate_legacy_speed(4) <= GameClock.SPEED_MAX,
			"a migration never grants the VIP speed")

	var legacy := {"day_index": 10, "speed": 4}
	var migrated := GameClock.new()
	var issues: Array = []
	check_eq(migrated.restore(legacy, issues), 0, "a legacy save restores without complaint")
	check_eq(migrated.speed, 2, "and its speed is translated")
	check_true(migrated.migrated_speed, "and the migration is recorded, not hidden")


func test_the_frozen_old_save_still_loads_its_speed() -> void:
	var text := FileAccess.get_file_as_string(LEGACY_FIXTURE)
	check_false(text.is_empty(), "the frozen schema-1 fixture is committed")
	var parsed := SaveFile.parse(text)
	check_true(bool(parsed["ok"]) or bool(parsed["needs_migration"]),
			"the old save is readable by this build")
	var payload: Dictionary = parsed["payload"]
	var world: Variant = payload.get("world")
	check_true(world is Dictionary, "it has a world")
	if not (world is Dictionary):
		return
	var clock_data: Variant = (world as Dictionary).get("clock")
	check_true(clock_data is Dictionary, "with a clock")
	if not (clock_data is Dictionary):
		return
	var stored := int(CanonicalJson.int_value((clock_data as Dictionary).get("speed")))
	var clock := GameClock.new()
	var issues: Array = []
	clock.restore(clock_data, issues)
	check_eq(clock.speed, GameClock.migrate_legacy_speed(stored),
			"the saved speed is translated by the documented rule")
	check_true(clock.speed <= GameClock.SPEED_MAX, "and lands on a speed everyone has")


func test_the_document_matches_the_implementation() -> void:
	var text := FileAccess.get_file_as_string("res://docs/PROGRESSION.md")
	check_false(text.is_empty(), "the progression document is committed")
	if text.is_empty():
		return
	var opener := text.find("<!-- progression-data")
	var closer := text.find("-->", opener)
	check_true(opener >= 0 and closer > opener, "it carries a machine-readable block")
	if opener < 0 or closer <= opener:
		return
	var start := opener + len("<!-- progression-data")
	var parsed: Variant = JSON.parse_string(text.substr(start, closer - start))
	check_true(parsed is Dictionary, "the block is JSON")
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	check_eq(int(data.get("max_level", 0)), Progression.MAX_LEVEL, "the document knows the cap")
	check_eq(int(data.get("max_vip", 0)), Progression.MAX_VIP, "and the VIP ceiling")
	var vip_levels: Array = data.get("vip_levels", [])
	check_eq(vip_levels.size(), Progression.VIP_LEVELS.size(), "and every VIP threshold")
	var sampled: Dictionary = data.get("sampled", {})
	check_gt(float(sampled.size()), 0.0, "the document samples levels")
	for key: String in sampled:
		check_eq(int(sampled[key]), Progression.xp_to_reach(int(key)),
				"level %s needs the same XP in both places" % key)
	var tutorial: Dictionary = data.get("tutorial", {})
	check_eq(int(tutorial.get("xp", -1)), Progression.TUTORIAL_XP, "the tutorial XP agrees")
	check_eq(int(tutorial.get("gold", -1)), Progression.TUTORIAL_GOLD, "the gold agrees")
	check_eq(int(tutorial.get("diamonds", -1)), Progression.TUTORIAL_DIAMONDS,
			"the Red Gems agree")
	var speed: Dictionary = data.get("speed", {})
	check_eq(int(speed.get("vip_tier", -1)), Progression.VIP_SPEED_TIER,
			"the VIP speed tier agrees")
	check_eq(int(speed.get("max", -1)), GameClock.SPEED_MAX, "and the public speed ceiling")
	var ticks: Dictionary = speed.get("ticks", {})
	check_eq(ticks.size(), GameClock.TICKS_PER_SECOND.size(), "the document lists every speed")
	for key: String in ticks:
		check_eq(int(ticks[key]), int(GameClock.TICKS_PER_SECOND[int(key)]),
				"speed %s has the same rate in both places" % key)


func test_tutorial_reward_is_small_and_documented() -> void:
	check_true(Progression.TUTORIAL_XP > 0, "the tutorial teaches something worth XP")
	check_true(Progression.TUTORIAL_XP <= Progression.xp_to_reach(2),
			"but not more than the first two levels")
	check_true(Progression.TUTORIAL_GOLD <= 1000, "gold is a token amount, not an economy")
	check_true(Progression.TUTORIAL_DIAMONDS < PlayerProfile.NAME_CHANGE_COST,
			"the tutorial does not pay for a name change by itself")


func _ticks_to_day(speed: int, ticks: int) -> int:
	var clock := GameClock.new()
	clock.set_speed(speed, GameClock.SPEED_MAX_VIP)
	for index in ticks:
		clock.step()
	return clock.day_index
