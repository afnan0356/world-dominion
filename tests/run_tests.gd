extends Node
## Headless test runner.
##
##   godot --headless --path . res://tests/test_runner.tscn
##
## Exits with status 0 when every assertion passes and 1 otherwise, so CI can
## block a merge on a broken design token, a bad settings file or an overflowing
## screen. Autoloads are available because this runs as a real scene.

const SUITES: Array = [
	preload("res://tests/suites/test_design_system.gd"),
	preload("res://tests/suites/test_settings_storage.gd"),
	preload("res://tests/suites/test_game_wallet.gd"),
	preload("res://tests/suites/test_data_files.gd"),
	preload("res://tests/suites/test_country_data.gd"),
	preload("res://tests/suites/test_world_geometry.gd"),
	preload("res://tests/suites/test_atlas_interaction.gd"),
	preload("res://tests/suites/test_dossier.gd"),
	preload("res://tests/suites/test_data_recovery.gd"),
	preload("res://tests/suites/test_campaign.gd"),
	preload("res://tests/suites/test_campaign_ui.gd"),
	preload("res://tests/suites/test_layout.gd"),
	preload("res://tests/suites/test_navigation.gd"),
	preload("res://tests/suites/test_start_nations.gd"),
	preload("res://tests/suites/test_developer_tools.gd"),
]


func _ready() -> void:
	await _run_suites()


func _run_suites() -> void:
	print("")
	print("WORLD DOMINION · headless test suite")
	print("-----------------------------------")
	var total_assertions := 0
	var total_failures := 0
	for suite_script: Script in SUITES:
		# A suite that fails to compile must fail the run loudly. Without this the
		# runner would stop without a result and appear to hang.
		var suite: TestCase = suite_script.new() as TestCase
		if suite == null:
			print("FAIL  %s (suite did not compile)" % suite_script.resource_path)
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
