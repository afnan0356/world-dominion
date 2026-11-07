extends Node
## Headless test runner.
##
##   godot --headless --path . res://tests/test_runner.tscn
##
## Exits with status 0 when every assertion passes and 1 otherwise, so CI can
## block a merge on a broken design token, a bad settings file or an overflowing
## screen. Autoloads are available because this runs as a real scene.

## Suite paths rather than preloads: a suite with a compile error then fails this
## runner with a clear message instead of preventing the runner itself from
## loading (which would look like a hang in CI).
const SUITE_PATHS: PackedStringArray = [
	"res://tests/suites/test_design_system.gd",
	"res://tests/suites/test_settings_storage.gd",
	"res://tests/suites/test_game_wallet.gd",
	"res://tests/suites/test_data_files.gd",
	"res://tests/suites/test_country_data.gd",
	"res://tests/suites/test_world_geometry.gd",
	"res://tests/suites/test_atlas_interaction.gd",
	"res://tests/suites/test_dossier.gd",
	"res://tests/suites/test_data_recovery.gd",
	"res://tests/suites/test_campaign.gd",
	"res://tests/suites/test_campaign_ui.gd",
	"res://tests/suites/test_layout.gd",
	"res://tests/suites/test_navigation.gd",
	"res://tests/suites/test_start_nations.gd",
	"res://tests/suites/test_developer_tools.gd",
	"res://tests/suites/test_simulation_core.gd",
	"res://tests/suites/test_save_system.gd",
	"res://tests/suites/test_canonical_json.gd",
	"res://tests/suites/test_flags.gd",
	"res://tests/suites/test_flags_in_screens.gd",
	"res://tests/suites/test_first_run.gd",
	"res://tests/suites/test_country_picker.gd",
	"res://tests/suites/test_profile_screen.gd",
	"res://tests/suites/test_tutorial.gd",
	"res://tests/suites/test_recovery_screens.gd",
	"res://tests/suites/test_game_shell.gd",
	"res://tests/suites/test_country_folders.gd",
	"res://tests/suites/test_map_polish.gd",
	"res://tests/suites/test_animation.gd",
	"res://tests/suites/test_completion.gd",
	"res://tests/suites/test_statistics.gd",
	"res://tests/suites/test_camera_framing.gd",
	"res://tests/suites/test_country_codes.gd",
	"res://tests/suites/test_progression.gd",
	"res://tests/suites/test_profile.gd",
	"res://tests/suites/test_integrity.gd",
	"res://tests/suites/test_backup.gd",
	"res://tests/suites/test_audio.gd",
	"res://tests/suites/test_settings_groups.gd",
	"res://tests/suites/test_main_menu.gd",
	"res://tests/suites/test_diagnostics.gd",
	"res://tests/suites/test_help_roadmap.gd",
	"res://tests/suites/test_world_deletion.gd",
	"res://tests/suites/test_currency.gd",
	"res://tests/suites/test_performance_claims.gd",
	"res://tests/suites/test_research_docs.gd",
	# Milestone 10
	"res://tests/suites/test_event_log.gd",
	"res://tests/suites/test_panel_framework.gd",
	"res://tests/suites/test_game_hud.gd",
	# Milestone 11
	"res://tests/suites/test_icons_licensed.gd",
	"res://tests/suites/test_country_state.gd",
	"res://tests/suites/test_whats_new.gd",
	# Milestone 12
	"res://tests/suites/test_isolation.gd",
]
## A deliberately failing suite, loaded only when GD_SELF_CHECK=1. It proves the CI
## gate rejects a failing run; see tests/canary/test_self_check_negative.gd.
const CANARY_SUITE := "res://tests/canary/test_self_check_negative.gd"

## Order configuration, from the environment so CI can run the same binary three ways:
## `GD_TEST_ORDER=normal` (the default) or `shuffle`, and `GD_TEST_SEED=<integer>`.
##
## A shuffled run with a fixed seed is reproducible: the seed is printed, the suite order is
## printed, and the per-test order inside each suite is derived from the seed and the suite's own
## path. Two runs with two seeds that agree on every suite's verdict and assertion count are
## evidence that no suite depends on what ran before it. CI compares all three runs and fails on
## any difference; see `tools/check_suite_stability.py`.
const ORDER_NORMAL := "normal"
const ORDER_SHUFFLE := "shuffle"


func _ready() -> void:
	await _run_suites()


## The order the run will use, and the seed that produced it. Read before any suite runs so the
## log always says which of the three runs this was.
func _order() -> String:
	var requested := OS.get_environment("GD_TEST_ORDER").strip_edges().to_lower()
	return ORDER_SHUFFLE if requested == ORDER_SHUFFLE else ORDER_NORMAL


func _seed() -> int:
	var text := OS.get_environment("GD_TEST_SEED").strip_edges()
	return text.to_int() if text.is_valid_int() else 0


## A deterministic shuffle: same seed, same order, on every machine, because Godot's
## `RandomNumberGenerator` is a documented PCG32 and is seeded explicitly here.
func _shuffled(paths: Array, seed_value: int) -> Array:
	var out := paths.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(out.size() - 1, 0, -1):
		var swap: int = rng.randi_range(0, index)
		var held: Variant = out[index]
		out[index] = out[swap]
		out[swap] = held
	return out


func _run_suites() -> void:
	print("")
	print("WORLD DOMINION · headless test suite")
	print("-----------------------------------")
	var total_assertions := 0
	var total_failures := 0
	var paths := Array(SUITE_PATHS)
	if OS.get_environment("GD_SELF_CHECK") == "1":
		paths.append(CANARY_SUITE)
		print("SELF-CHECK: the deliberately failing canary suite is included")
	var order := _order()
	var seed_value := _seed()
	if order == ORDER_SHUFFLE:
		paths = _shuffled(paths, seed_value)
	print("ORDER %s seed=%d suites=%d" % [order, seed_value, paths.size()])
	if order == ORDER_SHUFFLE:
		for path: String in paths:
			print("ORDER-SUITE %s" % path.get_file().get_basename())
	for path: String in paths:
		# A suite that fails to compile must fail the run loudly. Without this the
		# runner would stop without a result and appear to hang.
		print("SUITE %s" % path)
		var suite_script: Script = load(path)
		var suite: TestCase = suite_script.new() as TestCase if suite_script != null else null
		if suite == null:
			print("FAIL  %s (suite did not compile)" % path)
			print("Assertions: %d · Failures: 1" % total_assertions)
			print("RESULT: FAIL")
			# Quitting from inside `_ready` can leave the engine without a running
			# main loop, which looks exactly like a hang in CI. Let one frame pass
			# first so the exit status is actually delivered.
			await get_tree().process_frame
			get_tree().quit(1)
			return
		suite.tree = get_tree()
		suite.host = self
		# One shared setup and teardown around every suite, whatever the suite itself does.
		suite.before_suite()
		SuiteIsolation.begin()
		var test_count: int = await suite.run_all(-1 if order == ORDER_NORMAL else seed_value)
		var isolation := SuiteIsolation.finish()
		suite.after_suite()
		if not (isolation["leaks"] as Array).is_empty():
			print("LEAK  %s left files in user://: %s"
					% [suite.suite_name(), str(isolation["leaks"])])
		total_assertions += suite.assertions
		total_failures += suite.failures.size()
		var status := "PASS" if suite.failures.is_empty() else "FAIL"
		print("%s  %-26s %2d tests · %3d assertions" % [
			status, suite.suite_name(), test_count, suite.assertions])
		for failure: String in suite.failures:
			print("      - %s" % failure)
	print("-----------------------------------")
	print("Assertions: %d · Failures: %d" % [total_assertions, total_failures])
	print("RESULT: %s" % ("PASS" if total_failures == 0 else "FAIL"))
	get_tree().quit(0 if total_failures == 0 else 1)
