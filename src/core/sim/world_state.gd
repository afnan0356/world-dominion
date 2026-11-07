class_name WorldState
extends RefCounted
## Everything that changes during a campaign, and nothing that does not.
##
## The split that this class exists to enforce:
##
## * **Static world data** — the country registry, the geometry, the scenario
##   definitions. Read-only, shipped with the game, never copied into a save.
## * **Dynamic game state** — this object: which scenario, which country the player
##   leads, the date, the seed, the random-stream positions, the wallet and the
##   per-country dynamic state. This is what a save contains.
##
## A save is therefore kilobytes, not megabytes, and a corrected coastline never
## invalidates a campaign: geometry is looked up by stable id at load time.
##
## WHAT A COUNTRY'S STATE MAY CONTAIN AT THIS MILESTONE
##
## Only a reference to the registry record: the stable id, and an empty `sections`
## dictionary reserved for later milestones. No population, GDP, military strength
## or approval is invented here — those arrive only with a sourced dataset and a
## documented section format (see docs/DATA_SCHEMA.md § Adding metadata).
##
## Future data goes in `sections`, one entry per sourced system, each with its own
## `version` and `source`, so a later milestone can add a section without touching
## the save format version:
##
##     state.country("BGD")["sections"]["economy"] = {
##         "version": 1, "source": "…", "values": {…},
##     }
##
## Validation rejects a section that is not a dictionary with an integer version,
## so a malformed extension cannot quietly reach a system.

const SCHEMA_VERSION := 1
## The number stamped into a save so a future version can migrate this shape.
const STATE_KEY := "world"

var schema_version := SCHEMA_VERSION
## Which build wrote this state. Informational only: the save format's own version
## is what decides migration, not the marketing version of the game.
var game_version := ""
var scenario_id := ""
var scenario_name := ""
var scenario_version := 1
var player_country_id := ""
## A copy of the display name at creation time, for save lists. The registry
## remains the source of truth; if they disagree the registry wins and the list
## says so rather than showing a stale name.
var player_country_name := ""
var seed_value := 0
var data_stamp: Dictionary = {}
var clock: GameClock
var streams: RandomStreams
var wallet: GameWallet
## Seconds of real play time, for the save list. Wall-clock derived, never hashed.
var playtime_seconds := 0.0
## Stable country id → {id: String, sections: Dictionary}.
var countries: Dictionary = {}
## The campaign's own history (Milestone 10). Never null: an empty log means nothing has
## happened yet, which is the truthful state of a brand-new campaign and the migration result
## for a save written before the log existed.
var events := EventLog.new()
## The per-country baseline, by reference (Milestone 11, save schema 5).
##
##     {"version": 1,
##      "data": {schema, statistics:{schema, source, commit, records}, currency:{…},
##               records, missing, digest},
##      "overrides": {}}
##
## The 242 baseline figures are **not** copied in here: `data.digest` identifies the shipped
## dataset they came from, and `CountryState` rebuilds them at load. `overrides` is the small
## layer a later milestone may use to record a campaign deliberately departing from the
## baseline, without turning a save into a copy of the atlas.
var country_state: Dictionary = {}


static func new_campaign(config: CampaignConfig, registry: CountryRegistry,
		stamp: Dictionary, seed_value_in: int) -> WorldState:
	var state := WorldState.new()
	state.game_version = str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	state.data_stamp = stamp.duplicate(true)
	state.seed_value = seed_value_in & 0xFFFFFFFF
	state.streams = RandomStreams.from_seed(state.seed_value)
	state.wallet = GameWallet.new()
	if config != null:
		state.scenario_id = config.scenario_id
		state.scenario_name = str(config.metadata.get("scenario_name", config.scenario_id))
		state.player_country_id = config.country_id
		var record: CountryRecord = registry.get_country(config.country_id) \
				if registry != null else null
		state.player_country_name = record.name if record != null else str(
				config.metadata.get("country_name", config.country_id))
		state.clock = GameClock.for_new_campaign(config.start_date)
		# The player's country gets an entry immediately: it is the only country
		# this milestone has any dynamic state for, and creating it proves the
		# extension point works without inventing a value.
		state.country(config.country_id)
	# Every campaign starts with the baseline reference, written by one documented initialiser
	# (`CountryState.save_section()`), so "where does a country's starting data come from?" has
	# exactly one answer.
	state.country_state = CountryState.save_section()
	return state


func _init() -> void:
	clock = GameClock.for_new_campaign(GameClock.MODERN_WORLD_START)
	streams = RandomStreams.from_seed(0)
	wallet = GameWallet.new()


func current_date() -> GameDate:
	return clock.date()


func date_label() -> String:
	return clock.date().format_long()


## The dynamic state for one country, created empty on first use.
func country(country_id: String) -> Dictionary:
	if not countries.has(country_id):
		countries[country_id] = {"id": country_id, "sections": {}}
	return countries[country_id] as Dictionary


func has_country_state(country_id: String) -> bool:
	return countries.has(country_id)


func country_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for key: String in countries.keys():
		ids.append(key)
	ids.sort()
	return ids


## The documented extension point for later milestones: attach a versioned,
## sourced section to a country. Refuses a version that is not a positive integer
## so a future reader can always trust the field.
func write_section(country_id: String, section_name: String, version: int,
		values: Dictionary, source: String = "") -> bool:
	if country_id.is_empty() or section_name.is_empty() or version < 1:
		push_error("WorldState: refusing a section without an id, name or version.")
		return false
	var entry := country(country_id)
	var sections: Dictionary = entry["sections"]
	sections[section_name] = {
		"version": version,
		"source": source,
		"values": values.duplicate(true),
	}
	return true


func section(country_id: String, section_name: String) -> Dictionary:
	if not countries.has(country_id):
		return {}
	var sections: Dictionary = (countries[country_id] as Dictionary).get("sections", {})
	return sections.get(section_name, {})


## The playtime as the exact integer the save format stores: milliseconds, rounded.
func playtime_ms() -> int:
	return int(round(playtime_seconds * 1000.0))


func add_playtime(delta_seconds: float) -> void:
	if delta_seconds > 0.0 and not is_nan(delta_seconds) and not is_inf(delta_seconds):
		playtime_seconds += delta_seconds


## Every reason this state is internally inconsistent, in plain language. Empty
## means consistent. `registry` may be null, in which case id existence is not
## checked; every other rule is always checked.
func validation_errors(registry: CountryRegistry = null) -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != SCHEMA_VERSION:
		errors.append("World state schema is version %d; this build understands %d."
				% [schema_version, SCHEMA_VERSION])
	if scenario_id.is_empty():
		errors.append("World state has no scenario id.")
	if player_country_id.is_empty():
		errors.append("World state has no player country.")
	if seed_value < 0 or seed_value > 0xFFFFFFFF:
		errors.append("World seed %d is outside the supported range." % seed_value)
	if clock == null:
		errors.append("World state has no clock.")
	elif not clock.date().is_valid_date():
		errors.append("World clock holds an invalid date.")
	if streams == null:
		errors.append("World state has no random streams.")
	if wallet == null:
		errors.append("World state has no wallet.")
	if events == null:
		errors.append("World state has no event log.")
	if data_stamp.is_empty():
		errors.append("World state has no data stamp, so it cannot be matched to a dataset.")
	# Absent is tolerated: a save written before schema 5 has no country-state section, and the
	# 4 → 5 migration adds it. Present-but-malformed is not tolerated, because a reader that
	# trusted it would silently show the wrong baseline.
	if not country_state.is_empty():
		var state_version: Variant = CanonicalJson.int_value(country_state.get("version"))
		if state_version == null or int(state_version) < 1:
			errors.append("Country state has no valid version.")
		if not country_state.get("data") is Dictionary:
			errors.append("Country state has no data reference.")
		if not country_state.get("overrides") is Dictionary:
			errors.append("Country state overrides are not an object.")
	if registry != null:
		if not player_country_id.is_empty() and not registry.has_country(player_country_id):
			errors.append("Player country '%s' is not in this build's registry."
					% player_country_id)
		for country_id: String in countries.keys():
			if not registry.has_country(country_id):
				errors.append("Country state '%s' is not in this build's registry." % country_id)
	if not countries.has(player_country_id) and not player_country_id.is_empty():
		errors.append("The player's country has no state entry.")
	for country_id: String in countries.keys():
		var entry: Variant = countries[country_id]
		if not entry is Dictionary:
			errors.append("Country state '%s' is not a dictionary." % country_id)
			continue
		var sections: Variant = (entry as Dictionary).get("sections")
		if not sections is Dictionary:
			errors.append("Country state '%s' has no sections dictionary." % country_id)
			continue
		for section_name: String in (sections as Dictionary).keys():
			var section_value: Variant = (sections as Dictionary)[section_name]
			if not section_value is Dictionary:
				errors.append("Section '%s' of '%s' is not a dictionary."
						% [section_name, country_id])
				continue
			var version: Variant = CanonicalJson.int_value(
					(section_value as Dictionary).get("version"))
			if version == null or int(version) < 1:
				errors.append("Section '%s' of '%s' has no valid version."
						% [section_name, country_id])
	return errors


## Everything that makes up the campaign's deterministic identity, in a fixed
## shape. Wall-clock values (playtime, timestamps) are deliberately excluded: two
## runs of the same seed and the same actions must hash the same even if one was
## played for longer.
##
## The event log is excluded for the same reason: it is a *record* of actions the
## hash already covers, and whether the player has read an entry is a view
## preference, not campaign state. The file's own checksum still covers the log, so
## an edited log is still detected as damage.
func hash_payload() -> Dictionary:
	return {
		"schema_version": schema_version,
		"scenario_id": scenario_id,
		"scenario_version": scenario_version,
		"player_country_id": player_country_id,
		"seed": seed_value,
		"day_index": clock.day_index,
		"speed": clock.speed,
		"countries": countries.duplicate(true),
		"country_state": country_state.duplicate(true),
		"streams": streams.to_dict(),
		"wallet": wallet.to_dict(),
		"ids_fingerprint": str(data_stamp.get("ids_fingerprint", "")),
	}


## SHA-256 over the canonical form of `hash_payload()`. Used by determinism tests
## (run twice, compare) and by save validation (detect a tampered state).
func state_hash() -> String:
	return CanonicalJson.sha256(hash_payload())


## Full serialisation for the save layer. Holds no geometry and no registry copy.
func to_dict() -> Dictionary:
	var country_states := {}
	for country_id: String in countries.keys():
		country_states[country_id] = (countries[country_id] as Dictionary).duplicate(true)
	return {
		"schema_version": schema_version,
		"game_version": game_version,
		"scenario_id": scenario_id,
		"scenario_name": scenario_name,
		"scenario_version": scenario_version,
		"player_country_id": player_country_id,
		"player_country_name": player_country_name,
		"seed": seed_value,
		"data_stamp": data_stamp.duplicate(true),
		"clock": clock.to_dict() if clock != null else {},
		"streams": streams.to_dict() if streams != null else {},
		"wallet": wallet.to_dict() if wallet != null else {},
		# Playtime is stored as an exact integer number of milliseconds. A float second
		# counter accumulates noise (4.000000000000001 after forty 0.1 s frames), and a
		# float that carries noise cannot be written and read back identically.
		"playtime_ms": playtime_ms(),
		"countries": country_states,
		"country_state": country_state.duplicate(true),
		"events": events.to_dict(),
	}


## Rebuilds a state from saved data. Every problem is appended to `issues`; the
## caller (the save layer) decides whether to refuse the file, and nothing is
## silently substituted. Returns null when the data is not a dictionary at all.
static func from_dict(data: Variant, issues: Array) -> WorldState:
	if not data is Dictionary:
		issues.append("world state is not an object")
		return null
	var source: Dictionary = data
	var state := WorldState.new()
	var version: Variant = CanonicalJson.int_value(source.get("schema_version"))
	if version == null:
		issues.append("world state has no integer schema version")
		state.schema_version = -1
	else:
		state.schema_version = int(version)
	state.game_version = str(source.get("game_version", ""))
	state.scenario_id = str(source.get("scenario_id", ""))
	state.scenario_name = str(source.get("scenario_name", ""))
	var scenario_version: Variant = CanonicalJson.int_value(
			source.get("scenario_version", 1))
	state.scenario_version = int(scenario_version) if scenario_version != null else 1
	state.player_country_id = str(source.get("player_country_id", ""))
	state.player_country_name = str(source.get("player_country_name", ""))
	var raw_seed: Variant = CanonicalJson.int_value(source.get("seed"))
	if raw_seed != null and int(raw_seed) >= 0 and int(raw_seed) <= 0xFFFFFFFF:
		state.seed_value = int(raw_seed)
	else:
		issues.append("world seed is missing or out of range")
	var stamp: Variant = source.get("data_stamp")
	if stamp is Dictionary:
		state.data_stamp = (stamp as Dictionary).duplicate(true)
	else:
		issues.append("world data stamp is missing")

	var clock_data: Variant = source.get("clock")
	if clock_data is Dictionary:
		state.clock.restore(clock_data, issues)
	else:
		issues.append("world clock is missing")

	state.streams = RandomStreams.from_seed(state.seed_value)
	var stream_data: Variant = source.get("streams")
	if stream_data is Dictionary:
		state.streams.restore(stream_data, issues)
	elif stream_data != null:
		issues.append("random stream states are not an object")

	var wallet_data: Variant = source.get("wallet")
	if wallet_data is Dictionary:
		state.wallet = GameWallet.from_dict(wallet_data)
		if state.wallet.had_invalid_values:
			issues.append("wallet held values that were not exact integers and were discarded")
	else:
		issues.append("wallet is missing")

	# Milliseconds are authoritative (Milestone 07). A save written before that carries
	# float seconds instead, and is read here so an old fixture still loads; the schema
	# migration converts it so that anything written now is exact.
	var playtime_ms_value: Variant = CanonicalJson.int_value(source.get("playtime_ms"))
	if playtime_ms_value != null:
		if int(playtime_ms_value) < 0:
			issues.append("playtime is negative")
		else:
			state.playtime_seconds = int(playtime_ms_value) / 1000.0
	else:
		var playtime: Variant = source.get("playtime_seconds")
		if playtime is float or playtime is int:
			var seconds := float(playtime)
			if is_nan(seconds) or is_inf(seconds) or seconds < 0.0:
				issues.append("playtime is not a finite non-negative number")
			else:
				state.playtime_seconds = seconds

	var country_data: Variant = source.get("countries")
	if country_data is Dictionary:
		for country_id: Variant in (country_data as Dictionary).keys():
			var key := str(country_id)
			var entry: Variant = (country_data as Dictionary)[country_id]
			if not entry is Dictionary:
				issues.append("country state '%s' is not an object" % key)
				continue
			var copy: Dictionary = (entry as Dictionary).duplicate(true)
			if not copy.get("sections") is Dictionary:
				copy["sections"] = {}
			copy["id"] = key
			state.countries[key] = copy
	elif country_data != null:
		issues.append("country states are not an object")

	# The event log is optional on purpose: a save written before Milestone 10 has no
	# `events` block, and reading it as an empty log is the migration. Nothing is invented to
	# fill it, so the Messages panel honestly says the campaign has no recorded history yet.
	state.events = EventLog.from_dict(source.get("events"), issues)

	# Schema 5's baseline reference. Absent in a save written before it, where the migration
	# supplies it; a present-but-malformed block is reported here and refused by validation,
	# because showing a baseline the save did not record would be a quiet lie.
	var country_state_data: Variant = source.get("country_state")
	if country_state_data is Dictionary:
		state.country_state = (country_state_data as Dictionary).duplicate(true)
	elif country_state_data != null:
		issues.append("country state is not an object")
	return state


## The baseline reference this campaign recorded, or an empty dictionary when the save predates
## schema 5 (the migration fills it, so this is only true for a hand-built state in a test).
func country_state_reference() -> Dictionary:
	var data: Variant = country_state.get("data")
	return (data as Dictionary).duplicate(true) if data is Dictionary else {}


## True when this campaign's recorded baseline is the one the running build ships. The
## comparison is by digest, so a changed figure is noticed — a changed commit alone would not
## be enough, because a dataset can be re-versioned without any value moving.
func baseline_matches(baseline: CountryState) -> bool:
	if baseline == null:
		return false
	var recorded := str(country_state_reference().get("digest", ""))
	return not recorded.is_empty() and recorded == baseline.digest()


## The override layer, empty until a later milestone deliberately departs from the baseline.
## Kept as its own accessor so the rule "overrides are not the baseline" is visible in code.
func baseline_overrides() -> Dictionary:
	var overrides: Variant = country_state.get("overrides")
	return (overrides as Dictionary).duplicate(true) if overrides is Dictionary else {}
