class_name CampaignConfig
extends RefCounted
## The versioned record of "what the player chose" — scenario, starting date and
## country — plus the metadata captured at creation time.
##
## It is a plain value object with no UI and no scene dependencies, so it can be
## validated in tests, serialised by a future save system and passed between
## screens. This milestone deliberately stops here: nothing simulates a turn and
## nothing is written to disk. `to_dict()` exists because the config format must
## be stable and versioned before a save system is built on top of it — it is not
## a save system, and the interface does not claim to have one.

const SCHEMA_VERSION := 1

var schema_version := SCHEMA_VERSION
var scenario_id := ""
var country_id := ""
var start_date := ""
## Display metadata captured when the campaign was configured: the country name
## and region as they read at that moment. Never used as a source of truth for
## gameplay data (which stays in the registry).
var metadata: Dictionary = {}


static func create(scenario: Scenario, country: CountryRecord) -> CampaignConfig:
	var config := CampaignConfig.new()
	if scenario != null:
		config.scenario_id = scenario.id
		config.start_date = scenario.start_date
		config.metadata["scenario_name"] = scenario.name
	if country != null:
		config.country_id = country.id
		config.metadata["country_name"] = country.name
		config.metadata["region"] = country.region
		config.metadata["subregion"] = country.subregion
	return config


static func from_dict(data: Variant) -> CampaignConfig:
	if not data is Dictionary:
		return null
	var source: Dictionary = data
	var config := CampaignConfig.new()
	config.schema_version = int(source.get("schema_version", 0))
	config.scenario_id = str(source.get("scenario_id", ""))
	config.country_id = str(source.get("country_id", ""))
	config.start_date = str(source.get("start_date", ""))
	var meta: Variant = source.get("metadata")
	if meta is Dictionary:
		config.metadata = (meta as Dictionary).duplicate(true)
	return config


func to_dict() -> Dictionary:
	return {
		"schema_version": schema_version,
		"scenario_id": scenario_id,
		"country_id": country_id,
		"start_date": start_date,
		"metadata": metadata.duplicate(true),
	}


func has_scenario() -> bool:
	return not scenario_id.is_empty()


func has_country() -> bool:
	return not country_id.is_empty()


## Every reason this configuration cannot start a campaign. Empty means valid.
##
## Validation is the gate in front of the confirm button: the UI shows the same
## messages it would refuse to act on, and a config that fails here can never be
## confirmed, whether it came from the screen or from a hand-edited file.
func validate(catalog: ScenarioCatalog, registry: CountryRegistry,
		eligibility: StartEligibility = null) -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != SCHEMA_VERSION:
		errors.append("Unsupported campaign format version %d." % schema_version)
	var scenario: Scenario = catalog.get_scenario(scenario_id) if catalog != null else null
	if scenario == null:
		errors.append("Scenario '%s' is not available." % scenario_id)
	elif not scenario.implemented:
		errors.append("Scenario '%s' is not implemented in this build." % scenario.name)
	elif not scenario.issues.is_empty():
		errors.append("Scenario '%s' is misconfigured." % scenario.name)
	var record: CountryRecord = registry.get_country(country_id) if registry != null else null
	if record == null:
		errors.append("Country '%s' is not in the atlas." % country_id)
	else:
		# Eligibility is checked here, in the model, so bypassing the interface
		# cannot start a campaign the rules do not allow.
		var rules := eligibility if eligibility != null else StartEligibility.rules()
		if not rules.is_eligible(record):
			errors.append(rules.reason())
	if not Scenario.is_valid_date(start_date):
		errors.append("Start date '%s' is not a valid date." % start_date)
	elif scenario != null and start_date != scenario.start_date:
		errors.append("Start date does not match the scenario's date.")
	return errors


func is_confirmable(catalog: ScenarioCatalog, registry: CountryRegistry,
		eligibility: StartEligibility = null) -> bool:
	return validate(catalog, registry, eligibility).is_empty()


## Short human description of the configuration, for summaries and tests.
func summary() -> String:
	var country := str(metadata.get("country_name", country_id))
	var scenario := str(metadata.get("scenario_name", scenario_id))
	return "%s · %s · %s" % [country, scenario, Scenario.format_date(start_date)]
