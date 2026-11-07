extends TestCase
## The event log (Milestone 10, Task 5): records, the cap, read state, the save round trip and
## the migration of a campaign written before the log existed.
##
## The suite is deliberately pedantic about three things, because each one is a way this
## feature could quietly lie to a player:
##
## * an event must carry the real in-game date it happened on, not the date it was read;
## * the log must never grow without limit, and trimming must drop the *oldest* entry;
## * a save written before this milestone must load with an empty log rather than a
##   reconstructed one. A history nobody recorded is not a history.

const LEGACY_FIXTURE := "res://tests/fixtures/save_schema1_frozen.json"


func _log() -> EventLog:
	return EventLog.new()


func _record(log: EventLog, key: String = "events.save.manual") -> GameEvent:
	return log.record("system", "info", key, {"slot": "2"}, "save.manual", 42, "12 February 2026")


# --- Records ---------------------------------------------------------------

func test_a_record_carries_the_facts_and_no_sentence() -> void:
	var log := _log()
	var event := _record(log)
	check_eq(log.size(), 1, "the log holds the entry")
	check_eq(event.id, "evt-000001", "ids are sequential and stable")
	check_eq(event.day_index, 42, "the in-game day is stored, not formatted")
	check_eq(event.date_label, "12 February 2026", "the date the clock worded at the time")
	check_eq(event.category, "system", "the category is recorded")
	check_eq(event.origin, "save.manual", "the system that raised it is recorded")
	check_false(event.string_key.contains(" "),
			"the event stores a string-table key, never a finished sentence")
	check_true(Strings.has(event.string_key), "the key exists in the table")
	check_eq(event.text(), "Saved to slot 2.", "the sentence is built from the table")


func test_unknown_categories_and_severities_fall_back_visibly() -> void:
	var log := _log()
	var event := log.record("economy-ish", "shouting", "events.save.manual", {"slot": "1"},
			"test", 1, "1 January 2026")
	check_eq(event.category, GameEvent.CATEGORY_FALLBACK,
			"a category the interface cannot colour becomes the safe one")
	check_eq(event.severity, GameEvent.SEVERITY_FALLBACK, "severity falls back too")


func test_only_real_keys_survive_a_round_trip() -> void:
	var log := _log()
	_record(log)
	var restored := EventLog.from_dict(log.to_dict(), [])
	check_eq(restored.size(), 1, "the entry survives")
	check_eq(restored.entries[0].text(), "Saved to slot 2.", "and still reads the same")


# --- The cap ---------------------------------------------------------------

func test_the_cap_drops_the_oldest_entry_first() -> void:
	var log := _log()
	for index in EventLog.MAX_EVENTS + 3:
		log.record("system", "info", "events.save.autosave",
				{"slot": str(index)}, "save.autosave", index, "day %d" % index)
	check_eq(log.size(), EventLog.MAX_EVENTS, "the log is capped")
	check_eq(log.entries[0].day_index, 3, "the three oldest entries were dropped")
	check_eq(log.entries[-1].day_index, EventLog.MAX_EVENTS + 2, "the newest entry is kept")
	check_eq(log.newest_first()[0].day_index, EventLog.MAX_EVENTS + 2,
			"the list reads newest first for the interface")


func test_ids_are_never_reused_after_a_trim() -> void:
	var log := _log()
	for index in EventLog.MAX_EVENTS:
		log.record("system", "info", "events.save.autosave", {"slot": str(index)},
				"save.autosave", index, "day %d" % index)
	var survivor := log.entries[0].id
	log.record("system", "info", "events.save.autosave", {"slot": "x"}, "save.autosave",
			999, "day 999")
	check_false(log.find(survivor) != null and log.entries[0].id == survivor,
			"the trimmed id does not come back")
	check_eq(log.entries[-1].id, "evt-%06d" % (EventLog.MAX_EVENTS + 1),
			"the counter kept counting")


# --- Read state ------------------------------------------------------------

func test_reading_is_a_state_the_interface_owns() -> void:
	var log := _log()
	var first := _record(log)
	_record(log, "events.save.autosave")
	check_eq(log.unread_count(), 2, "a new campaign's records are unread")
	log.mark_read(first.id)
	check_eq(log.unread_count(), 1, "one event is now read")
	check_true(log.mark_read(first.id) and log.unread_count() == 1,
			"marking the same entry twice changes nothing")
	check_false(log.mark_read("evt-999999"), "an unknown id is reported, not invented")
	check_eq(log.mark_all_read(), 1, "mark all read reports how many changed")
	check_eq(log.unread_count(), 0, "nothing is unread afterwards")
	check_eq(log.unread_by_category().size(), 0, "the per-category counts agree")


# --- Filtering -------------------------------------------------------------

func test_search_and_category_narrow_the_same_list() -> void:
	var log := _log()
	log.record("campaign", "notice", "events.campaign.started", {"country": "Bangladesh"},
			"campaign.start", 0, "1 January 2026")
	log.record("system", "info", "events.save.autosave", {"slot": "auto"},
			"save.autosave", 31, "1 February 2026")
	check_eq(log.filtered("", "").size(), 2, "no filter shows everything")
	check_eq(log.filtered("system", "").size(), 1, "a category narrows")
	check_eq(log.filtered("", "bangladesh").size(), 1, "search is case-insensitive")
	check_eq(log.filtered("", "nothing like this").size(), 0, "a miss is zero, not an error")
	check_eq(log.used_categories(), ["campaign", "system"],
			"the filter chips only offer categories that occur")


# --- Save round trip -------------------------------------------------------

func test_the_log_travels_inside_the_world() -> void:
	var atlas := WorldAtlas.load_default()
	var state := WorldState.new_campaign(_config(), atlas.registry, {}, 7)
	state.events.record("campaign", "notice", "events.campaign.started",
			{"country": state.player_country_name}, "campaign.start", 0, "1 January 2026")
	var issues: Array = []
	var restored := WorldState.from_dict(state.to_dict(), issues)
	check_eq(issues.size(), 0, "the world state round-trips without complaint")
	check_eq(restored.events.size(), 1, "the log is part of the world, not of the interface")
	check_eq(restored.events.entries[0].params.get("country", ""), state.player_country_name,
			"and keeps the country it named")
	check_true(restored.state_hash() == state.state_hash(),
			"the state hash ignores the log: history is a record, not campaign state")


func test_a_damaged_log_is_reported_rather_than_guessed() -> void:
	var issues: Array = []
	var log := EventLog.from_dict({"next_sequence": 3, "entries": [
			{"id": "evt-000001", "day_index": 4, "category": "system", "severity": "info",
					"key": "events.save.manual", "params": {"slot": "1"},
					"date_label": "4 January 2026", "origin": "save.manual", "read": false},
			{"id": "evt-000001", "day_index": 5, "category": "system", "severity": "info",
					"key": "events.save.manual", "params": {"slot": "2"},
					"date_label": "5 January 2026", "origin": "save.manual", "read": false},
			{"id": "evt-000009", "day_index": -1, "category": "system", "severity": "info",
					"key": "events.save.manual", "params": {}, "origin": "x", "read": false},
	]}, issues)
	check_eq(log.size(), 1, "the usable record survives")
	check_eq(issues.size(), 2, "the repeated id and the bad day are both reported")
	check_eq(log.next_sequence, 10, "the counter moves past the highest id actually present")


func test_a_save_from_before_the_log_loads_with_an_empty_one() -> void:
	# The frozen schema 1 fixture predates the event log entirely. It is the old-save fixture
	# for this migration: it must load, migrate 1 → 2 → 3 → 4, and come out with no history.
	var text := FileAccess.get_file_as_string(LEGACY_FIXTURE)
	check_true(not text.is_empty(), "the frozen fixture is readable")
	var parsed: Variant = JSON.parse_string(text)
	check_true(parsed is Dictionary, "the fixture is a JSON object")
	var migrated := SaveMigrations.migrate(parsed)
	check_true(bool(migrated["ok"]), "the old save migrates: %s" % str(migrated["errors"]))
	var payload: Dictionary = migrated["payload"]
	check_eq(int(payload["schema_version"]), SaveFile.SCHEMA_VERSION,
			"the migrated file is at the current schema")
	var world: Variant = payload.get("world")
	check_true(world is Dictionary, "the migrated file still holds a world")
	var events: Variant = (world as Dictionary).get("events")
	check_true(events is Dictionary, "the migration added an event block")
	var log := EventLog.from_dict(events, [])
	check_eq(log.size(), 0, "and the log is empty: nothing is invented for a pre-log campaign")
	var steps: Array = migrated["steps"]
	check_eq(steps.size(), 3, "three steps ran: 1→2, 2→3, 3→4")


func test_a_new_campaign_records_that_it_began() -> void:
	var atlas := WorldAtlas.load_default()
	var store := SaveStore.new("user://test_event_log_saves")
	var session := GameSession.start_new(_config(), atlas, store, 11)
	check_eq(session.world.events.size(), 1, "starting a campaign records one event")
	var event: GameEvent = session.world.events.entries[0]
	check_eq(event.category, "campaign", "it belongs to the campaign category")
	check_true(event.text().contains(session.world.player_country_name),
			"and it names the country the player leads")
	check_eq(event.day_index, session.world.clock.day_index,
			"the date is the campaign's own start date")
	_clear(store.directory())


func test_saving_records_that_it_happened() -> void:
	var atlas := WorldAtlas.load_default()
	var store := SaveStore.new("user://test_event_log_saves")
	var session := GameSession.start_new(_config(), atlas, store, 12)
	var before := session.world.events.size()
	var result := session.save_to("2", "2026-11-07T10:00:00Z")
	check_true(bool(result["ok"]), "the save is written")
	check_eq(session.world.events.size(), before + 1, "a manual save adds one record")
	check_true(session.world.events.entries[-1].text().contains("2"),
			"the record names the slot that was actually used")
	_clear(store.directory())


func _config() -> CampaignConfig:
	var atlas := WorldAtlas.load_default()
	var config := CampaignConfig.new()
	config.scenario_id = "modern_world_2026"
	config.country_id = "BGD"
	config.start_date = "2026-01-01"
	var record := atlas.registry.get_country("BGD")
	config.metadata = {"scenario_name": "Modern World",
			"country_name": record.name if record != null else "Bangladesh"}
	return config


func _clear(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		directory.remove(file_name)
