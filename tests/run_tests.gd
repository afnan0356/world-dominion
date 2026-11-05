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
	"res://tests/suites/test_game_shell.gd",
	"res://tests/suites/test_country_folders.gd",
	"res://tests/suites/test_map_polish.gd",
]


func _ready() -> void:
	await _run_suites()


func _run_suites() -> void:
	print("")
	print("WORLD DOMINION · headless test suite")
	print("-----------------------------------")
	var total_assertions := 0
	var total_failures := 0
	for path: String in SUITE_PATHS:
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
		var test_count: int = await suite.run_all()
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
