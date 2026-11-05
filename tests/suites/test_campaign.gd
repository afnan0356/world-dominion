extends TestCase
## Scenario catalogue, campaign configuration and the New Campaign flow.
##
## The rule these tests enforce is the one the brief is strictest about: a
## configuration that cannot be played must never be confirmable, and the build
## must never pretend to have a scenario, a simulation or a save it does not have.

const SETUP_SCENE := "res://src/ui/screens/campaign_setup.tscn"

var _atlas: WorldAtlas
var _catalog: ScenarioCatalog


func _load() -> void:
	if _atlas == null:
		_atlas = WorldAtlas.load_default()
	if _catalog == null:
		_catalog = ScenarioCatalog.from_directory()


# --- Catalogue -------------------------------------------------------------

func test_catalogue_lists_only_defined_scenarios() -> void:
	_load()
	check_gt(float(_catalog.count()), 0.0, "at least one scenario must be shipped")
	check_gt(float(_catalog.implemented_count()), 0.0,
			"the build must be able to start a campaign")
	check_eq(_catalog.issues().size(), 0,
			"scenario definitions must load cleanly (%s)" % str(_catalog.issues()))
	var default_scenario := _catalog.default_scenario()
	check_not_null(default_scenario, "a default scenario must exist")
	if default_scenario == null:
		return
	check_true(default_scenario.implemented, "the default scenario must be implemented")
	check_eq(default_scenario.start_date, "2026-01-01",
			"the modern-world scenario starts on 1 January 2026")
	check_true(_catalog.has_scenario(default_scenario.id),
			"the default scenario must be addressable by id")
	check_true(default_scenario.is_usable(), "the shipped scenario must be usable")
	for scenario: Scenario in _catalog.all():
		check_false(scenario.name.strip_edges().is_empty(), "scenarios need names")
		check_true(Scenario.is_valid_date(scenario.start_date),
				"%s: scenarios need a valid start date" % scenario.id)


func test_scenario_dates_are_validated_not_assumed() -> void:
	for valid: String in ["2026-01-01", "2024-02-29", "1999-12-31"]:
		check_true(Scenario.is_valid_date(valid), "%s must be a valid date" % valid)
	for invalid: String in ["2026-02-29", "2026-13-01", "2026-00-10", "2026-1-1", "",
			"01-01-2026", "2026-04-31", "not a date"]:
		check_false(Scenario.is_valid_date(invalid), "%s must be rejected" % invalid)
	check_eq(Scenario.format_date("2026-01-01"), "1 January 2026",
			"dates must read in the interface's voice")
	check_eq(Scenario.format_date("nope"), "nope",
			"an unparseable date is passed through rather than invented")


func test_catalogue_rejects_malformed_definitions() -> void:
	var catalog := ScenarioCatalog.from_list([
		{"id": "modern_world_2026", "name": "Modern World", "start_date": "2026-01-01",
			"implemented": true},
		{"id": "modern_world_2026", "name": "Duplicate", "start_date": "2026-01-01"},
		{"name": "No identifier", "start_date": "2026-01-01"},
		{"id": "broken_date", "name": "Broken", "start_date": "yesterday", "implemented": true},
		"not a dictionary",
	])
	check_eq(catalog.count(), 2, "only definitions with an id and a name are kept")
	var issues := " ".join(catalog.issues())
	check_true(issues.contains("duplicate"), "duplicate scenario ids must be reported")
	check_true(issues.contains("valid"), "invalid dates must be reported")
	check_true(catalog.has_scenario("broken_date"), "a broken definition is still visible")
	check_false(catalog.get_scenario("broken_date").is_usable(),
			"a scenario with an invalid date cannot be started")


# --- Configuration ---------------------------------------------------------

func _config_for(scenario_id: String, country_id: String) -> CampaignConfig:
	_load()
	var scenario := _catalog.get_scenario(scenario_id)
	var record := _atlas.registry.get_country(country_id)
	var config := CampaignConfig.create(scenario, record)
	if scenario == null:
		config.scenario_id = scenario_id
	if record == null:
		config.country_id = country_id
	return config


func test_a_complete_choice_is_confirmable() -> void:
	_load()
	var config := _config_for("modern_world_2026", "BGD")
	var errors := config.validate(_catalog, _atlas.registry)
	check_eq(errors.size(), 0, "a scenario plus a country must validate (%s)" % str(errors))
	check_true(config.is_confirmable(_catalog, _atlas.registry), "the choice is confirmable")
	check_eq(config.start_date, "2026-01-01", "the start date comes from the scenario")
	check_eq(config.metadata.get("country_name"), "Bangladesh",
			"the configuration captures display metadata at creation time")
	check_true(config.summary().contains("Bangladesh"), "the summary names the nation")
	var restored := CampaignConfig.from_dict(config.to_dict())
	check_not_null(restored, "a configuration must survive a round trip")
	check_eq(restored.country_id, config.country_id, "the country survives the round trip")
	check_eq(restored.schema_version, CampaignConfig.SCHEMA_VERSION,
			"the format is versioned")


func test_incomplete_or_invalid_choices_are_refused() -> void:
	_load()
	var no_country := _config_for("modern_world_2026", "")
	var errors := no_country.validate(_catalog, _atlas.registry)
	check_gt(float(errors.size()), 0.0, "a campaign without a nation cannot be confirmed")
	check_false(no_country.is_confirmable(_catalog, _atlas.registry),
			"and the UI gate must agree")

	var unknown_country := _config_for("modern_world_2026", "ZZZ")
	check_false(unknown_country.is_confirmable(_catalog, _atlas.registry),
			"an unknown country cannot be confirmed")

	var unknown_scenario := _config_for("no_such_scenario", "BGD")
	check_false(unknown_scenario.is_confirmable(_catalog, _atlas.registry),
			"an unknown scenario cannot be confirmed")

	var bad_version := _config_for("modern_world_2026", "BGD")
	bad_version.schema_version = 99
	check_false(bad_version.is_confirmable(_catalog, _atlas.registry),
			"a future format version is refused rather than half-read")

	var wrong_date := _config_for("modern_world_2026", "BGD")
	wrong_date.start_date = "1999-01-01"
	check_false(wrong_date.is_confirmable(_catalog, _atlas.registry),
			"a start date that does not belong to the scenario is refused")

	var invalid_date := _config_for("modern_world_2026", "BGD")
	invalid_date.start_date = "2026-02-30"
	check_true(" ".join(invalid_date.validate(_catalog, _atlas.registry)).contains("date"),
			"an impossible date is reported as such")

	check_true(CampaignConfig.from_dict(null) == null, "a null document is not a configuration")
	check_true(CampaignConfig.from_dict("nope") == null, "a string is not a configuration")


func test_unimplemented_scenarios_cannot_be_started() -> void:
	_load()
	var planned := Scenario.from_dict({
		"id": "planned_era", "name": "Planned Era", "start_date": "1914-01-01",
		"implemented": false,
	})
	var catalog := ScenarioCatalog.new()
	catalog.add(planned)
	check_eq(catalog.implemented_count(), 0, "a scenario marked unimplemented is not offered")
	check_true(catalog.default_scenario() == null,
			"a build with no implemented scenario has no default")
	var config := CampaignConfig.create(planned, _atlas.registry.get_country("BGD"))
	var errors := config.validate(catalog, _atlas.registry)
	check_gt(float(errors.size()), 0.0, "the configuration is refused")
	check_true(" ".join(errors).contains("not implemented"),
			"the refusal says the scenario is not implemented")


# --- Screen flow -----------------------------------------------------------

func _mount_setup(viewport_size: Vector2) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(viewport_size)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Control = load(SETUP_SCENE).instantiate()
	holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await tree.process_frame
	await tree.process_frame
	return {"viewport": viewport, "screen": screen}


func _button(root: Node, text_value: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.text == text_value:
			return button
	return null


func test_setup_screen_starts_without_a_choice() -> void:
	var mounted := await _mount_setup(Vector2(1280, 720))
	var screen: Control = mounted["screen"]
	check_eq(screen.call("selected_country_id"), "", "nothing is selected on arrival")
	check_false(screen.call("is_confirm_enabled"),
			"the confirm action must be unavailable before a nation is chosen")
	check_true(screen.call("build_campaign") == null,
			"no campaign can be built from an empty choice")
	check_not_null(screen.call("scenario"), "a default scenario is preselected")
	(mounted["viewport"] as Node).queue_free()


func test_choosing_a_nation_enables_and_builds_a_campaign() -> void:
	var mounted := await _mount_setup(Vector2(1280, 720))
	var screen: Control = mounted["screen"]
	check_true(screen.call("select_country", "BGD", false), "selecting Bangladesh succeeds")
	check_eq(screen.call("selected_country_id"), "BGD", "the selection is stored by id")
	check_true(screen.call("is_confirm_enabled"), "a valid choice enables the confirm action")
	var config: CampaignConfig = screen.call("build_campaign")
	check_not_null(config, "the screen can build a campaign from the choice")
	check_eq(config.country_id, "BGD", "the configuration points at Bangladesh")
	var info: CountryInfoPanel = screen.get_node("%InfoPanel")
	check_eq(info.selected_id(), "BGD", "the dossier follows the selection")
	check_false(screen.call("select_country", "NOT_A_COUNTRY", false),
			"an unknown id is refused")
	check_eq(screen.call("selected_country_id"), "",
			"refusing an unknown id clears rather than keeping a stale selection")
	(mounted["viewport"] as Node).queue_free()


func test_confirm_shows_an_honest_brief_and_can_be_closed() -> void:
	var mounted := await _mount_setup(Vector2(1280, 720))
	var screen: Control = mounted["screen"]
	screen.call("select_country", "BGD", false)
	var confirm: Button = screen.get_node("%ConfirmButton")
	confirm.pressed.emit()
	await tree.process_frame
	check_true(screen.call("is_overlay_visible"), "confirming shows the campaign brief")
	var text := _collect_text(screen.get_node("%OverlayBody"))
	check_true(text.contains("BANGLADESH"), "the brief names the nation (%s)" % text)
	check_true(text.contains("1 JANUARY 2026"), "the brief states the starting date")
	check_true(text.contains("MODERN WORLD"), "the brief names the scenario")
	check_true(text.contains("NO SIMULATION"),
			"the brief states that no simulation is running")
	check_true(text.contains("NOTHING IS SAVED"),
			"the brief states that nothing is saved")
	screen.call("_close_overlay")
	await tree.process_frame
	check_false(screen.call("is_overlay_visible"), "the brief can be dismissed")
	(mounted["viewport"] as Node).queue_free()


func test_search_selects_and_focuses_a_nation() -> void:
	var mounted := await _mount_setup(Vector2(1280, 720))
	var screen: Control = mounted["screen"]
	var search: CountrySearch = screen.get_node("%Search")
	search.set_query("bang")
	await tree.process_frame
	check_true(search.is_list_visible(), "typing a query opens the result list")
	check_true(search.visible_result_ids().has("BGD"), "the list contains Bangladesh")
	var button := search.result_button(0)
	check_not_null(button, "the first result must be a real button")
	if button != null:
		button.pressed.emit()
	await tree.process_frame
	check_eq(screen.call("selected_country_id"), "BGD",
			"choosing a result selects the nation")
	check_true(screen.call("is_confirm_enabled"), "the choice becomes confirmable")
	search.set_query("zzzzz")
	await tree.process_frame
	check_true(search.empty_state_visible(), "an empty result set shows an explanation")
	check_eq(search.visible_result_ids().size(), 0, "and lists nothing")
	(mounted["viewport"] as Node).queue_free()


func _collect_text(node: Node) -> String:
	var parts: PackedStringArray = []
	for child: Node in node.find_children("*", "Label", true, false):
		var label := child as Label
		if label != null:
			parts.append(label.text)
	return " ".join(parts).to_upper()
