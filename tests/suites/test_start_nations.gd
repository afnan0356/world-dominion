extends TestCase
## Starting-nation eligibility and the source-status note.
##
## Two promises are pinned here. First, the eligibility rule is data-driven: it is
## a list of the dataset's own `type` values in one file, and no place is named in
## code. Second, the rule only gates starting a campaign — every record stays
## searchable, viewable and fully documented.
##
## The rule is a default for the owner to review, not a final decision, so these
## tests check the mechanism (a type list decides) rather than defending the
## specific list forever.

const DATA_PATH := "res://data/world/start_eligibility.json"

var _registry: CountryRegistry


func _load() -> void:
	if _registry == null:
		_registry = CountryRegistry.from_file()


func _rules() -> StartEligibility:
	return StartEligibility.reload()


func test_rule_file_is_the_single_source() -> void:
	check_true(FileAccess.file_exists(DATA_PATH), "the eligibility rule lives in one data file")
	var data: Variant = DataLoader.load_json(DATA_PATH)
	check_true(data is Dictionary, "the rule file parses as a dictionary")
	var rules := _rules()
	check_eq(rules.issues().size(), 0, "the shipped rule file produces no issues")
	check_gte(float(rules.eligible_types().size()), 1.0, "at least one type may start a campaign")
	check_false(rules.reason().is_empty(), "an ineligible record has a neutral reason to show")
	check_true(rules.reason().contains("this version"),
			"the reason describes a limit of this version, not a judgement")


func test_rule_names_types_not_places() -> void:
	_load()
	var rules := _rules()
	# A record may not be mentioned in the rule's text, and every eligible type
	# must be a type the dataset actually uses.
	var types := {}
	for record: CountryRecord in _registry.all():
		types[record.type] = true
	for type_name: String in rules.eligible_types():
		check_true(types.has(type_name), "`%s` is a classification the dataset uses" % type_name)
	var text := rules.reason() + rules.note()
	for probe: String in ["Israel", "Taiwan", "Kosovo", "Palestine", "Sahara", "Crimea"]:
		check_false(text.contains(probe), "the rule text does not single out %s" % probe)


func test_eligibility_follows_the_type_list() -> void:
	_load()
	var rules := _rules()
	var eligible := 0
	var ineligible := 0
	for record: CountryRecord in _registry.all():
		var expected := rules.eligible_types().has(record.type)
		check_eq(rules.is_eligible(record), expected,
				"%s is eligible exactly when its type is listed" % record.id)
		if expected:
			eligible += 1
		else:
			ineligible += 1
	check_eq(eligible + ineligible, _registry.count(), "every record is classified")
	check_eq(eligible, 206, "206 records can start a campaign under the default rule")
	check_eq(ineligible, 36, "36 records cannot (28 dependencies, 4 disputed, 4 indeterminate)")


func test_default_rule_applies_to_records_the_source_marks_uncertain() -> void:
	_load()
	var rules := _rules()
	# Derived from the source's own type strings, not from a list of country ids.
	for country_id: String in ["ISR", "PSE", "ESH", "KOS", "FLK", "ATA"]:
		var record := _registry.get_country(country_id)
		check_not_null(record, "%s is in the atlas and can still be browsed" % country_id)
		check_false(rules.is_eligible(record), "%s cannot start a campaign (source type %s)" % [
				country_id, record.type])


func test_widening_the_rule_widens_eligibility_without_code_changes() -> void:
	_load()
	var rules := StartEligibility.new()
	rules._apply({"eligible_types": ["Dependency", "Disputed"]})
	check_true(rules.is_eligible(_registry.get_country("ISR")),
			"a rule that includes Disputed makes Israel eligible")
	check_false(rules.is_eligible(_registry.get_country("FRA")),
			"a rule that excludes Sovereign country makes France ineligible")
	check_eq(rules.issues().size(), 0, "a valid alternative rule reports no issues")


func test_rule_with_no_types_falls_back_instead_of_blocking_everything() -> void:
	var rules := StartEligibility.new()
	rules._apply({"eligible_types": []})
	check_eq(rules.issues().size(), 1, "an empty type list is reported, not silently applied")
	check_eq(rules.eligible_types(), StartEligibility.DEFAULT_TYPES,
			"an empty list falls back to the documented default rather than blocking the game")


func test_campaign_gate_rejects_ineligible_records() -> void:
	_load()
	var catalog := ScenarioCatalog.from_directory()
	var scenario := catalog.default_scenario()
	var rules := _rules()
	var blocked := CampaignConfig.create(scenario, _registry.get_country("PSE"))
	var errors := blocked.validate(catalog, _registry, rules)
	check_gte(float(errors.size()), 1.0, "an indeterminate record cannot start a campaign")
	check_true(errors[0].contains("starting nation"),
			"the rejection uses the neutral message (%s)" % errors[0])
	check_false(blocked.is_confirmable(catalog, _registry, rules),
			"the confirm button stays disabled for an ineligible record")

	var allowed := CampaignConfig.create(scenario, _registry.get_country("BGD"))
	check_eq(allowed.validate(catalog, _registry, rules).size(), 0,
			"an eligible record still validates")


func test_every_ineligible_record_is_still_documented() -> void:
	_load()
	var rules := _rules()
	for record: CountryRecord in _registry.all():
		if rules.is_eligible(record):
			continue
		var dossier := CountryDossier.build(record)
		check_eq(dossier.sections.size(),
				CountryDossier.RECORDED_SECTIONS.size()
				+ CountryDossier.planned_sections().size(),
				"%s keeps its full dossier" % record.id)
		var overview := dossier.section(CountryDossier.OVERVIEW)
		check_true(overview != null, "%s has an overview section" % record.id)


func test_uncertain_status_note_is_neutral_and_scoped() -> void:
	_load()
	var rules := _rules()
	for record: CountryRecord in _registry.all():
		var expected := record.type == "Disputed" or record.type == "Indeterminate"
		check_eq(CountryDossier.has_uncertain_status(record), expected,
				"%s status note depends on the source type" % record.id)
		var overview := CountryDossier.build(record).section(CountryDossier.OVERVIEW)
		if expected:
			check_eq(overview.note, CountryDossier.SOURCE_STATUS_NOTE,
					"%s carries the exact neutral note" % record.id)
		else:
			check_true(overview.note != CountryDossier.SOURCE_STATUS_NOTE,
					"%s must not claim an uncertain status" % record.id)
	# The note names the dataset and disclaims an official position; it takes no side.
	check_true(CountryDossier.SOURCE_STATUS_NOTE.contains("Natural Earth"),
			"the note names the dataset it follows")
	check_true(CountryDossier.SOURCE_STATUS_NOTE.contains("not an official position"),
			"the note disclaims an official position")
	for word: String in ["occup", "illegal", "rightful", "terror"]:
		check_false(CountryDossier.SOURCE_STATUS_NOTE.to_lower().contains(word),
				"the note contains no %s language" % word)
	check_eq(rules.eligible_types().size(), 3, "the note does not change the shipped rule")


func test_every_record_shows_its_source_classification() -> void:
	_load()
	for country_id: String in ["FRA", "ISR", "PSE", "GRL", "TWN", "HKG"]:
		var record := _registry.get_country(country_id)
		var overview := CountryDossier.build(record).section(CountryDossier.OVERVIEW)
		var values := {}
		for field: CountryDossier.Field in overview.fields:
			values[field.label] = field.value
		check_eq(values.get("Dataset classification"), record.type,
				"%s shows the source type verbatim" % country_id)
		check_true(values.has("Dataset classification"),
				"%s always shows a classification row" % country_id)


func test_capital_location_appears_only_when_sourced() -> void:
	_load()
	var dhaka := CountryDossier.build(_registry.get_country("BGD"))
	var administration := dhaka.section(CountryDossier.ADMINISTRATION)
	var values := {}
	for field: CountryDossier.Field in administration.fields:
		values[field.label] = field.value
	check_eq(values.get("Capital"), "Dhaka", "the capital name is sourced")
	check_true(values.has("Capital location"), "a sourced capital point is shown")
	check_true(str(values["Capital location"]).contains("°"),
			"the capital location is a human-readable coordinate (%s)"
			% str(values.get("Capital location")))

	# A unit with no capital point must show the honest gap, never a guess.
	var samoa := _registry.get_country("ASM")
	var unit_dossier := CountryDossier.build(samoa)
	var unit_section := unit_dossier.section(CountryDossier.ADMINISTRATION)
	var unit_values := {}
	for field: CountryDossier.Field in unit_section.fields:
		unit_values[field.label] = field.value
	check_eq(unit_values.get("Capital"), "Not recorded in source",
			"a missing capital is a stated gap")
	check_false(unit_values.has("Capital location"),
			"no capital point is invented for a record without one")
