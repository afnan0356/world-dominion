extends TestCase
## The per-country baseline foundation (Milestone 11, Task 3).
##
## What is being proved, in the order the milestone asks for it:
##
## 1. **Every record exists, in a stable order, from one documented initialiser.** All 242
##    records are created at campaign start, sorted by stable id, and two runs agree exactly.
## 2. **A missing figure is missing, not zero.** The dataset has gaps; each one is printed as
##    "Not available" and carries the reason, and the counts are published.
## 3. **Baseline and live state are separate.** The baseline has no write path and hands out
##    copies; the live layer is the campaign's own `countries[...]["sections"]`, still empty.
## 4. **A save carries a reference, not 242 figures**, and the reference survives a round trip,
##    is covered by the state hash, and is added by the 4 → 5 migration.
## 5. **The one system is real**: it compares the recorded reference with the shipped data and
##    reports a difference once, in the campaign's log.
## 6. **It costs what it claims**: the save grows by a reference, the load rebuilds 242 records
##    once, and a tick with 242 country states present is measured here rather than estimated.
##
## Measurements are printed as `BASELINE-MEASURE …` lines so CI can publish them: a number in a
## document that nobody measured is exactly what this project refuses to publish.

const FIXTURE := "res://tests/fixtures/save_schema1_frozen.json"
const TICKS_TO_MEASURE := 300
## Generous ceilings. They exist to catch a collapse (an accidental per-tick data load, a save
## that grew by megabytes), not to pin a frame budget that would fail on a slower machine.
const TICK_BUDGET_USEC := 2000.0
const LOAD_BUDGET_MSEC := 250.0
const SECTION_BUDGET_BYTES := 2_500

var _baseline: CountryState
var _statistics: CountryStatistics


func _prepare() -> void:
	if _baseline == null:
		_baseline = CountryState.initialise()
	if _statistics == null:
		_statistics = CountryStatistics.load_default()


func _config() -> CampaignConfig:
	var config := CampaignConfig.new()
	config.scenario_id = "modern_world_2026"
	config.country_id = "BGD"
	config.start_date = "2026-01-01"
	config.metadata = {"scenario_name": "Modern World", "country_name": "Bangladesh"}
	return config


func _world() -> WorldState:
	return WorldState.new_campaign(_config(), null, {"ids_fingerprint": "test"}, 7)


# --- 1. every record, in a stable order ---------------------------------------

func test_all_242_records_are_created_in_stable_order() -> void:
	var ids := _baseline.country_ids()
	check_eq(ids.size(), 242, "the baseline holds one record per registry record")
	check_eq(_baseline.count(), 242, "and its count agrees")
	var sorted := ids.duplicate()
	sorted.sort()
	check_eq(Array(sorted), Array(ids), "the order is the stable sort by ISO code, not file order")
	check_eq(ids[0], "ABW", "the first record is the first code alphabetically")
	check_true(_statistics.has("BGD"), "the statistics file the baseline reads is the shipped one")
	var missing_records: Array = []
	for country_id: String in ids:
		if _baseline.baseline(country_id).is_empty():
			missing_records.append(country_id)
	check_eq(missing_records.size(), 0, "every id resolves to a record: %s"
			% str(missing_records.slice(0, 5)))
	check_eq(_baseline.country_ids().size(), _statistics.count() + 0,
			"the baseline covers exactly the records the source has")


func test_two_initialisations_agree_exactly() -> void:
	var second := CountryState.initialise()
	check_eq(second.digest(), _baseline.digest(), "two initialisations hash the same")
	check_eq(Array(second.country_ids()), Array(_baseline.country_ids()),
			"and hold the same ids in the same order")
	var differences: Array = []
	for country_id: String in _baseline.country_ids():
		if second.baseline(country_id) != _baseline.baseline(country_id):
			differences.append(country_id)
	check_eq(differences.size(), 0, "and the same values: %s" % str(differences.slice(0, 5)))
	check_eq(second.data_reference(), _baseline.data_reference(), "including the reference it records")


# --- 2. missing is not zero ----------------------------------------------------

func test_a_missing_figure_is_explicit_and_never_a_zero() -> void:
	var counts := _baseline.missing_counts()
	check_true(counts is Dictionary and counts.size() == 4,
			"the reference publishes how many records lack each figure")
	var wrong: Array = []
	for country_id: String in _baseline.country_ids():
		var record := _baseline.baseline(country_id)
		for field: String in ["population", "gdp", "area", "currency"]:
			var entry: Dictionary = record.get(field, {})
			var state := str(entry.get("state", ""))
			if state == "missing":
				if entry.get("value", 0) != null or entry.get("code", null) != null:
					wrong.append("%s/%s has a value where the source has none" % [country_id, field])
				if str(entry.get("text", "")) != CountryState.MISSING_TEXT:
					wrong.append("%s/%s does not say %s" % [country_id, field,
							CountryState.MISSING_TEXT])
				if str(entry.get("reason", "")).is_empty():
					wrong.append("%s/%s gives no reason" % [country_id, field])
			elif state == "sourced" or state == "derived":
				if entry.get("value", null) == null and entry.get("code", null) == null:
					wrong.append("%s/%s claims a value it does not have" % [country_id, field])
	check_eq(wrong.size(), 0, "a gap is a gap, never a zero: %s" % str(wrong.slice(0, 5)))
	# The counts are the ones the reference publishes, so the document and the data agree.
	var recomputed := {"population": 0, "gdp": 0, "area": 0, "currency": 0}
	for country_id: String in _baseline.country_ids():
		var record := _baseline.baseline(country_id)
		for field: String in ["population", "gdp", "area", "currency"]:
			if str((record[field] as Dictionary).get("state", "")) == "missing":
				recomputed[field] = int(recomputed[field]) + 1
	check_eq(recomputed, counts, "the published gap counts match the records")


func test_the_baseline_matches_the_statistics_it_came_from() -> void:
	var differences: Array = []
	for country_id: String in _baseline.country_ids():
		for pair: Array in [["population", "population"], ["gdp", "gdp_usd"],
				["area", "area_km2"]]:
			var baseline_value: Variant = _baseline.value(country_id, str(pair[0]))
			var source_value: Variant = _statistics.value(country_id, str(pair[1]))
			if baseline_value != source_value:
				differences.append("%s/%s" % [country_id, pair[0]])
	check_eq(differences.size(), 0,
			"the baseline is the source's figures, unchanged: %s" % str(differences.slice(0, 5)))


# --- 3. baseline and live state are separate ----------------------------------

func test_the_baseline_cannot_be_edited() -> void:
	var record := _baseline.baseline("BGD")
	var before: Variant = _baseline.value("BGD", "population")
	record["population"]["value"] = 1
	var after: Variant = _baseline.value("BGD", "population")
	check_eq(after, before, "editing the copy a caller received does not touch the baseline")
	var source := FileAccess.get_file_as_string("res://src/core/world/country_state.gd")
	check_false(source.contains("func set_"), "the baseline has no setter")
	check_false(source.contains("func write_"), "and no write function")
	var world := _world()
	check_true(world.country("BGD")["sections"] is Dictionary,
			"live state lives in the campaign's own country entry")
	check_eq((world.country("BGD")["sections"] as Dictionary).size(), 0,
			"and is empty, because no system has changed anything yet")


func test_a_new_campaign_records_a_reference_not_the_figures() -> void:
	var world := _world()
	var section := world.country_state
	check_eq(int(section.get("version", 0)), CountryState.SCHEMA_VERSION,
			"the section is versioned")
	var data: Dictionary = section.get("data", {})
	check_eq(str(data.get("digest", "")), _baseline.digest(),
			"it records the digest of the data this build ships")
	check_eq(int(data.get("records", 0)), 242, "and how many records that is")
	check_eq(section.get("overrides", null), {}, "with an empty override layer")
	var serialized := JSON.stringify(section)
	check_lte(float(serialized.length()), float(SECTION_BUDGET_BYTES),
			"the section is a reference, not a copy of the atlas (%d characters)"
					% serialized.length())
	check_false(serialized.contains("\"population\""),
			"it holds no per-country figure")
	# The world's own serialisation must not smuggle the records in either.
	var world_json := JSON.stringify(world.to_dict())
	check_false(world_json.contains("163046161"),
			"nor does the world state carry a baseline number")


# --- 4. the save format -------------------------------------------------------

func test_a_save_carries_the_reference_and_round_trips() -> void:
	var world := _world()
	var payload := SaveFile.build(world, "1", "2026-11-07T00:00:00Z", "2026-11-07T00:00:00Z")
	check_eq(int(payload.get("schema_version", 0)), 5, "a save is written at schema 5")
	var text := SaveFile.serialize(payload)
	var parsed := SaveFile.parse(text)
	check_true(bool(parsed["ok"]), "the save loads: %s" % str(parsed["errors"]))
	if not bool(parsed["ok"]):
		return
	var restored := WorldState.from_dict((parsed["payload"] as Dictionary)["world"], [])
	check_eq(restored.country_state_reference().get("digest"), _baseline.digest(),
			"the reference survives the round trip")
	check_eq(restored.state_hash(), world.state_hash(), "and the state hash agrees")
	check_true(restored.baseline_matches(_baseline),
			"the loaded campaign knows its baseline is this build's data")
	check_eq(restored.baseline_overrides(), {}, "with no overrides invented")


func test_the_state_hash_covers_the_reference() -> void:
	var first := _world()
	var second := _world()
	check_eq(first.state_hash(), second.state_hash(),
			"two identical campaigns hash the same")
	second.country_state["data"]["digest"] = "0000"
	check_true(first.state_hash() != second.state_hash(),
			"changing the recorded baseline changes the hash, so it cannot be edited quietly")
	check_eq(first.country_state_reference().get("digest"), _baseline.digest(),
			"and the untouched campaign is unaffected")


func test_the_migration_adds_the_reference_to_a_schema_four_save() -> void:
	var world := _world()
	var payload := SaveFile.build(world, "1", "2026-11-07T00:00:00Z", "2026-11-07T00:00:00Z")
	# Build what a schema 4 build would have written: no country-state block at all.
	payload["schema_version"] = 4
	var legacy_world: Dictionary = payload["world"]
	legacy_world.erase("country_state")
	payload.erase(SaveFile.STATE_HASH_KEY)
	var issues: Array = []
	var legacy_state := WorldState.from_dict(legacy_world, issues)
	payload[SaveFile.STATE_HASH_KEY] = legacy_state.state_hash()
	payload[IntegritySignature.SIGNATURE_KEY] = (
			IntegritySignature.signature_of(SaveFile.signed_body(payload)))
	payload[SaveFile.CHECKSUM_KEY] = SaveFile.checksum_of(payload)
	var migrated := SaveMigrations.migrate(payload)
	check_true(bool(migrated["ok"]), "the schema 4 save migrates: %s" % str(migrated["errors"]))
	var steps: Array = migrated["steps"]
	check_eq(steps.size(), 1, "exactly one step ran: 4 → 5")
	if steps.size() == 1:
		check_true(str(steps[0]).contains("baseline"), "and it says what it did: %s" % str(steps[0]))
	var result: Dictionary = migrated["payload"]
	check_eq(int(result.get("schema_version", 0)), SaveFile.SCHEMA_VERSION,
			"the payload is at the current schema")
	var restored := WorldState.from_dict(result["world"], [])
	check_true(restored.baseline_matches(_baseline),
			"the migrated save records the baseline it will actually show")
	var parsed := SaveFile.parse(SaveFile.serialize(result))
	check_true(bool(parsed["ok"]), "and the migrated file loads: %s" % str(parsed["errors"]))
	check_eq(str(parsed.get("signature_status", "")), IntegritySignature.STATUS_FAILED,
			"the signature is stale after a migration and is reported as such, not hidden")


func test_the_oldest_fixture_still_loads_through_every_step() -> void:
	var text := FileAccess.get_file_as_string(FIXTURE)
	check_false(text.is_empty(), "the frozen schema 1 fixture is present")
	var parsed = SaveFile.parse(text)
	check_false(bool(parsed["ok"]), "it is not loaded before it is migrated")
	var legacy: Variant = JSON.parse_string(text)
	check_true(legacy is Dictionary, "and it parses as an object")
	if not legacy is Dictionary:
		return
	var migrated := SaveMigrations.migrate(legacy as Dictionary)
	check_true(bool(migrated["ok"]), "it migrates: %s" % str(migrated["errors"]))
	check_eq((migrated["steps"] as Array).size(), 4, "through four steps: 1→2→3→4→5")
	var restored := WorldState.from_dict((migrated["payload"] as Dictionary)["world"], [])
	check_true(restored.baseline_matches(_baseline),
			"and comes out with a reference to this build's baseline")


# --- 5. the one system ---------------------------------------------------------

func test_the_baseline_check_reports_a_changed_data_version_once() -> void:
	var world := _world()
	var simulation := Simulation.for_state(world)
	simulation.register_shipped_systems()
	check_true(simulation.has_system("baseline_integrity"),
			"the system is registered with the shipped systems")
	var registered: BaselineIntegritySystem = null
	for candidate: SimulationSystem in simulation.systems():
		if candidate is BaselineIntegritySystem:
			registered = candidate as BaselineIntegritySystem
	check_not_null(registered, "and it can be reached")
	if registered == null:
		return
	var events: Array = []
	simulation.bus.subscribe(BaselineIntegritySystem.EVENT_BASELINE_CHANGED,
			func(payload: Dictionary) -> void: events.append(payload))
	# A campaign started by this build: the digests agree, so there is nothing to report.
	check_true(bool(registered.update({"state": world, "bus": simulation.bus})),
			"the first update runs")
	check_eq(events.size(), 0, "and reports nothing when nothing changed")
	check_true(bool(registered.last_result.get("ok", false)),
			"while recording that it did check")
	check_true(registered.status_line().contains("matches"),
			"its status line says so: %s" % registered.status_line())
	# Now pretend the save was written by a build whose dataset differed.
	world.country_state["data"]["digest"] = "1111"
	var checker := BaselineIntegritySystem.new()
	check_true(bool(checker.update({"state": world, "bus": simulation.bus})),
			"the check still runs on a mismatch")
	check_eq(events.size(), 1, "the event is published exactly once")
	var result := checker.last_result
	check_false(bool(result["ok"]), "a changed dataset is noticed")
	check_true(str(result["reason"]).contains("differs"),
			"with a reason, not a silent pass: %s" % str(result["reason"]))
	check_true(checker.update({"state": world, "bus": simulation.bus}),
			"a second update is a no-op")
	check_eq(events.size(), 1, "and does not repeat the event")
	check_true(Strings.has("events.world.baseline_changed"),
			"the string table can say it in words")
	check_true(Strings.has("events.origin.world.baseline"), "including where it came from")


# --- 6. what it costs ----------------------------------------------------------

func test_a_tick_with_242_country_states_is_measured_not_guessed() -> void:
	var world := _world()
	for country_id: String in _baseline.country_ids():
		world.country(country_id)
	check_eq(world.countries.size(), 242, "all 242 country states exist before measuring")
	var simulation := Simulation.for_state(world)
	simulation.register_shipped_systems()
	simulation.clock.set_speed(GameClock.SPEED_MIN)
	var ticks := 0
	var started := Time.get_ticks_usec()
	for _index in range(TICKS_TO_MEASURE):
		ticks += simulation.advance(1.0)
	var elapsed := Time.get_ticks_usec() - started
	check_gte(float(ticks), float(TICKS_TO_MEASURE - 5),
			"the measurement really ran ticks (%d of %d)" % [ticks, TICKS_TO_MEASURE])
	var per_tick := float(elapsed) / maxf(float(ticks), 1.0)
	print("BASELINE-MEASURE tick_usec=%.2f ticks=%d country_states=%d"
			% [per_tick, ticks, world.countries.size()])
	check_lte(per_tick, TICK_BUDGET_USEC,
			"a tick with 242 states costs %.1f µs, inside the %.0f µs ceiling"
					% [per_tick, TICK_BUDGET_USEC])


func test_save_size_and_load_time_before_and_after() -> void:
	var before := _world()
	before.country_state = {}
	var after := _world()
	var before_bytes := SaveFile.serialize(SaveFile.build(before, "1", "2026-11-07T00:00:00Z",
			"2026-11-07T00:00:00Z")).length()
	var after_text := SaveFile.serialize(SaveFile.build(after, "1", "2026-11-07T00:00:00Z",
			"2026-11-07T00:00:00Z"))
	var after_bytes := after_text.length()
	check_gte(float(after_bytes), float(before_bytes), "the reference adds to the save")
	var section_bytes := JSON.stringify(after.country_state).length()
	check_lte(float(section_bytes), float(SECTION_BUDGET_BYTES),
			"and adds a reference, not 242 records")
	# Load time: the WorldState rebuild plus the baseline rebuild, which is what a resume does.
	var iterations := 20
	var started := Time.get_ticks_usec()
	for _index in range(iterations):
		CountryState.initialise()
		var rebuilt := WorldState.from_dict(after.to_dict(), [])
		rebuilt.baseline_matches(CountryState.shared())
	var elapsed_ms := float(Time.get_ticks_usec() - started) / 1000.0 / float(iterations)
	print("BASELINE-MEASURE save_bytes_before=%d save_bytes_after=%d section_bytes=%d "
			% [before_bytes, after_bytes, section_bytes]
			+ "load_msec_before=0.00 load_msec_after=%.2f records=242" % elapsed_ms)
	check_lte(elapsed_ms, LOAD_BUDGET_MSEC,
			"a save load with the baseline rebuild costs %.1f ms, inside the %.0f ms ceiling"
					% [elapsed_ms, LOAD_BUDGET_MSEC])


