extends TestCase
## The canonical number form (Milestone 07, Task 1).
##
## The bug this pins down: playtime was a float number of seconds. Forty frames of
## 0.1 s accumulate to 4.000000000000001, the writer printed that as "4.0000000000",
## the reader saw the whole number 4, and the two digests disagreed — so a save could
## refuse itself as tampered. The fix has two halves: the writer and every digest go
## through one `canonicalise()`, and durations are stored as exact integers.

const LEGACY_FIXTURE := "res://tests/fixtures/save_schema1_frozen.json"


func test_there_is_one_number_form() -> void:
	check_eq(CanonicalJson.stringify(2.0), "2", "a whole float is written as an integer")
	check_eq(CanonicalJson.stringify(2), "2", "and an integer the same way")
	check_eq(CanonicalJson.canonicalise(-0.0), 0, "negative zero becomes zero")
	check_eq(CanonicalJson.stringify(-0.0), "0", "and is written as zero")
	check_eq(CanonicalJson.stringify(0.0), "0", "so is positive zero")
	check_eq(CanonicalJson.stringify(4.000000000000001), "4",
			"float noise below the precision is rounded away")
	check_eq(CanonicalJson.stringify(0.1 + 0.2), "0.3", "and the usual float surprise too")
	check_eq(CanonicalJson.stringify(0.1234567890123), "0.123456789",
			"a real fraction keeps nine decimal places")
	check_eq(CanonicalJson.stringify({"a": 1.5, "b": [2.0, "x\n\"y\""]}),
			'{"a":1.5,"b":[2, "x\\n\\"y\\""]}',
			"keys are sorted, arrays keep order, strings are escaped")
	var errors: Array = []
	check_eq(CanonicalJson.stringify(INF, errors), "", "infinity cannot be written")
	check_false(errors.is_empty(), "and says so")
	check_eq(CanonicalJson.sha256(INF, errors), "", "and cannot be hashed either")


func test_a_digest_survives_the_text_it_produces() -> void:
	# Property-style: build awkward payloads from a seeded generator, write each one,
	# read it back and check the digest again. One assertion per property for the whole
	# run, so the count reflects the property rather than the loop.
	var rng := DeterministicRng.from_seed(20261106)
	var worst := ""
	for index in 300:
		var payload := _awkward_payload(rng, index)
		var before := CanonicalJson.sha256(payload)
		var parsed: Variant = JSON.parse_string(CanonicalJson.stringify(payload))
		if not (parsed is Dictionary):
			worst = "payload %d did not come back as an object" % index
			break
		var after := CanonicalJson.sha256(parsed)
		if before.is_empty() or before != after:
			worst = "payload %d: %s vs %s" % [index, before.substr(0, 8), after.substr(0, 8)]
			break
	check_eq(worst, "", "300 seeded payloads keep their digest through text")
	var noisy := 0.0
	for _frame in 40:
		noisy += 0.1
	check_true(noisy != 4.0, "forty 0.1 s frames really do accumulate noise")
	check_eq(CanonicalJson.sha256({"t": noisy}), CanonicalJson.sha256({"t": 4.0}),
			"and the noise no longer changes the digest")


func test_a_file_written_before_the_change_is_recognised_as_intact() -> void:
	var payload := {"format": SaveFile.FORMAT_ID, "schema_version": 2,
			"playtime_seconds": 90.0, "world": {"playtime_seconds": 90.0}}
	payload[SaveFile.CHECKSUM_KEY] = CanonicalJson.sha256_legacy(payload)
	var parsed := SaveFile.parse(SaveFile.serialize(payload))
	check_true(bool(parsed["legacy_checksum"]), "an old checksum is recognised as intact")
	var reason := ""
	for error: Variant in parsed["errors"]:
		if str(error).contains("mismatch"):
			reason = str(error)
	check_eq(reason, "", "and is not accused of being changed")
	var wrong := payload.duplicate(true)
	wrong[SaveFile.CHECKSUM_KEY] = CanonicalJson.sha256_legacy(payload).substr(0, 32) + "0"
	var refused := SaveFile.parse(SaveFile.serialize(wrong))
	check_false(bool(refused["legacy_checksum"]), "a wrong old checksum is still refused")


func test_the_frozen_old_save_is_intact_and_migrates() -> void:
	var text := FileAccess.get_file_as_string(LEGACY_FIXTURE)
	check_false(text.is_empty(), "the frozen schema-1 fixture is committed")
	var parsed := SaveFile.parse(text)
	var accused := false
	for error: Variant in parsed["errors"]:
		if str(error).contains("mismatch") or str(error).contains("signature"):
			accused = true
	check_false(accused, "the frozen save is not accused of being tampered with")
	check_true(bool(parsed["needs_migration"]), "and it is reported as needing a migration")
	var migrated := SaveMigrations.migrate(parsed["payload"] as Dictionary)
	check_true(bool(migrated["ok"]), "it migrates: %s" % str(migrated["errors"]))
	if not bool(migrated["ok"]):
		return
	var rewritten := SaveFile.serialize(migrated["payload"] as Dictionary)
	var reloaded := SaveFile.parse(rewritten)
	check_true(bool(reloaded["ok"]), "the migrated file verifies against its new checksum")
	check_eq(int(reloaded["payload"].get("schema_version", 0)), SaveFile.SCHEMA_VERSION,
			"and is at the current schema")
	var world: Dictionary = (reloaded["payload"] as Dictionary)["world"]
	check_true(world.get("playtime_ms") is int, "its playtime is exact integer milliseconds")
	check_false(world.has("playtime_seconds"), "with no float seconds left behind")
	var issues: Array = []
	var state := WorldState.from_dict(world, issues)
	check_not_null(state, "and its world still rebuilds")
	if state != null:
		check_eq(state.playtime_ms(), int(world.get("playtime_ms", -1)),
				"with the playtime the file states")


func _awkward_payload(rng: DeterministicRng, index: int) -> Dictionary:
	var numbers: Array = [0, 1, -1, 2.0, 4.000000000000001, 0.1, -0.0, 1.0e-9, 1.0e15,
			-1.0e15, 9007199254740992.0, 0.1234567890123]
	var texts: Array = ["", "plain", "quote\"inside", "line\nbreak", "tab\there",
			"back\\slash", "üñïçø", "emoji ✓"]
	return {
		"index": index,
		"number": numbers[index % numbers.size()],
		"rng": rng.next_int(-1000000, 1000000),
		"whole": float(rng.next_int(0, 1000)),
		"text": texts[index % texts.size()],
		"list": [numbers[(index + 1) % numbers.size()], texts[(index + 3) % texts.size()]],
		"nested": {"b": [1, 2.0, 3.5], "a": texts[(index + 5) % texts.size()]},
	}


func test_an_old_profile_envelope_still_loads() -> void:
	# Profiles never held a float, so their canonical text did not change — but the
	# envelope is keyed with the older form here on purpose, to prove that a file written
	# before Milestone 07 is still accepted instead of being called tampered with.
	var path := "user://test_canonical_profile_legacy.json"
	for suffix in ["", ".backup", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	var profile := PlayerProfile.create(20261106, "2026-11-06")
	var body := profile.to_dict()
	var envelope := {
		"format": "world-dominion-profile",
		"schema_version": PlayerProfile.SCHEMA_VERSION,
		"checksum": CanonicalJson.sha256_legacy(body),
		IntegritySignature.SIGNATURE_KEY: IntegritySignature.signature_of_legacy(body),
		"profile": body,
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	check_not_null(file, "the legacy profile fixture can be written")
	if file == null:
		return
	file.store_string(CanonicalJson.stringify(envelope))
	file.close()
	var store := ProfileStore.new(path)
	var loaded := store.load_or_create(20261106, "2026-11-06")
	check_true(bool(loaded["ok"]), "a profile written in the older form still loads")
	check_eq(str(loaded["source"]), "main", "from its own file, not a fresh profile")
	var problems: PackedStringArray = loaded["problems"]
	check_eq(problems.size(), 0, "without being accused of being changed")
	if loaded["profile"] != null:
		check_eq(str((loaded["profile"] as PlayerProfile).player_id), profile.player_id,
				"and it is the same profile")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
