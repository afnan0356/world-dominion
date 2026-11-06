extends TestCase
## The integrity signature (Milestone 06, Task H), and the promise that a bad signature is
## never a silent wipe.
##
## The signature is a corruption and casual-edit detector, not anti-cheat: the key ships in
## the binary and the source is published, so a determined person can recompute it. These
## tests therefore check *detection* and the *three choices*, not "protection".

var _atlas: WorldAtlas


func _load() -> void:
	if _atlas == null:
		_atlas = WorldAtlas.load_default()


func _world(seed_value: int = 909090) -> WorldState:
	_load()
	var config: CampaignConfig = CampaignConfig.new()
	config.scenario_id = "modern_world_2026"
	config.country_id = "BGD"
	config.start_date = "2026-01-01"
	config.metadata = {"scenario_name": "Modern World", "country_name": "Bangladesh"}
	var world: WorldState = WorldState.new_campaign(config, _atlas.registry, DataStamp.compute(_atlas),
			seed_value)
	world.wallet.add(GameWallet.Currency.GOLD_COINS, 250)
	world.add_playtime(30.0)
	return world


func _store(name: String) -> SaveStore:
	var store := SaveStore.new("user://%s" % name)
	_clear_directory(store.directory())
	return store


func _clear_directory(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory := DirAccess.open(absolute)
	if directory == null:
		return
	for name: String in directory.get_files():
		directory.remove(name)


# --- the primitive -------------------------------------------------------------

func test_signing_is_stable_and_sensitive_to_its_body() -> void:
	var body := {"a": 1, "b": "two"}
	var signature: String = IntegritySignature.signature_of(body)
	check_true(signature.begins_with(IntegritySignature.VERSION + ":"),
			"the signature is tagged with its scheme version")
	check_eq(signature, IntegritySignature.signature_of({"b": "two", "a": 1}),
			"key order does not change the signature")
	check_eq(IntegritySignature.verify(body, signature), IntegritySignature.STATUS_OK,
			"a matching signature verifies")
	check_eq(IntegritySignature.verify({"a": 2, "b": "two"}, signature),
			IntegritySignature.STATUS_FAILED, "a changed value fails")
	check_eq(IntegritySignature.verify(body, ""), IntegritySignature.STATUS_MISSING,
			"a file with no signature is reported as unsigned, not as failed")


func test_a_value_surviving_json_still_verifies() -> void:
	var body := {"xp": 250, "gold": 10, "name": "Afnan"}
	var signature: String = IntegritySignature.signature_of(body)
	var round_tripped: Variant = JSON.parse_string(JSON.stringify(body))
	check_true(round_tripped is Dictionary, "the body survives a JSON round trip")
	if round_tripped is Dictionary:
		check_eq(IntegritySignature.verify(round_tripped, signature),
				IntegritySignature.STATUS_OK,
				"numbers that came back as floats sign the same as before")


# --- world saves ---------------------------------------------------------------

func test_a_world_save_is_signed_and_verifies() -> void:
	var store: SaveStore = _store("wd_integrity_saves")
	var saved := store.save("1", _world(), "2026-01-01", "2026-02-01T00:00:00Z")
	check_true(bool(saved["ok"]), "the world saves")
	var parsed: Dictionary = SaveFile.parse(FileAccess.get_file_as_string(store.path_for("1")))
	check_true(bool(parsed["ok"]), "and parses")
	check_eq(str(parsed["signature_status"]), IntegritySignature.STATUS_OK,
			"with a valid signature")
	_clear_directory(store.directory())


func test_editing_a_world_save_is_detected_even_with_a_recomputed_checksum() -> void:
	var store: SaveStore = _store("wd_integrity_tamper")
	store.save("1", _world(), "2026-01-01", "2026-02-01T00:00:00Z")
	var text: String = FileAccess.get_file_as_string(store.path_for("1"))
	var parsed: Variant = JSON.parse_string(text)
	check_true(parsed is Dictionary, "the save is JSON")
	if not (parsed is Dictionary):
		return
	var payload: Dictionary = parsed
	# Give the player a fortune and re-seal the file the way a casual edit would: the
	# checksum is recomputed, so only the signature can notice.
	var world: Dictionary = payload["world"]
	var wallet: Dictionary = world["wallet"]
	wallet["gold_coins"] = 9_000_000
	payload[SaveFile.CHECKSUM_KEY] = SaveFile.checksum_of(payload)
	var re_sealed: String = SaveFile.serialize(payload)
	var check: Dictionary = SaveFile.parse(re_sealed)
	check_eq(str(check["signature_status"]), IntegritySignature.STATUS_FAILED,
			"the signature catches an edit the checksum cannot")
	check_true(bool(check["ok"]), "the save is still loadable, so the player can choose")
	check_true(str(check["player_error"]).contains("changed"),
			"and the message says the file was changed")
	_clear_directory(store.directory())


func test_removing_the_signature_is_also_visible() -> void:
	var store: SaveStore = _store("wd_integrity_remove")
	store.save("1", _world(), "2026-01-01", "2026-02-01T00:00:00Z")
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(store.path_for("1")))
	if not (parsed is Dictionary):
		check_true(false, "the save is JSON")
		return
	var payload: Dictionary = parsed
	payload.erase(IntegritySignature.SIGNATURE_KEY)
	payload[SaveFile.CHECKSUM_KEY] = SaveFile.checksum_of(payload)
	var check: Dictionary = SaveFile.parse(SaveFile.serialize(payload))
	check_eq(str(check["signature_status"]), IntegritySignature.STATUS_MISSING,
			"a save with its signature cut out reports as unsigned, not as intact")
	_clear_directory(store.directory())


# --- the profile ---------------------------------------------------------------

func test_a_tampered_profile_reports_the_three_choices_without_resetting() -> void:
	var path := "user://wd_integrity_profile.json"
	var store := ProfileStore.new(path)
	var profile: PlayerProfile = PlayerProfile.create(21, "2026-11-06")
	profile.add_xp(260)
	profile.wallet.add(GameWallet.Currency.DIAMONDS, 40)
	store.save(profile)
	profile.wallet.add(GameWallet.Currency.GOLD_COINS, 999)
	store.save(profile)

	# Edit the main file's XP, keeping its checksum valid so only the signature complains.
	var text: String = FileAccess.get_file_as_string(path)
	var envelope: Variant = JSON.parse_string(text)
	if not (envelope is Dictionary):
		check_true(false, "the profile is JSON")
		return
	var document: Dictionary = envelope
	var body: Dictionary = document["profile"]
	body["xp"] = 1_000_000
	document["profile"] = body
	document["checksum"] = CanonicalJson.sha256(body)
	var handle := FileAccess.open(path, FileAccess.WRITE)
	handle.store_string(JSON.stringify(document))
	handle.close()

	var loaded := store.load_or_create(21, "2026-11-06")
	check_eq(str(loaded["signature_status"]), IntegritySignature.STATUS_FAILED,
			"the profile's signature fails")
	check_true((loaded["profile"] as PlayerProfile).xp == 1_000_000,
			"choice two: continue with a warning keeps what the file says")
	check_true((loaded["problems"] as PackedStringArray).size() > 0,
			"and the player is told")

	var backup := store.load_backup()
	check_true(bool(backup["ok"]), "choice one: the previous copy is available")
	if bool(backup["ok"]):
		var from_backup: PlayerProfile = backup["profile"]
		check_eq(from_backup.xp, 260, "and holds the XP as it was before the edit")
		check_eq(from_backup.wallet.gold_coins(), 0, "and the gold the edit added is gone")
		check_eq(str(backup["signature_status"]), IntegritySignature.STATUS_OK,
				"because the previous copy is intact")

	# Choice three is "cancel": nothing is written until the caller saves, so the edited
	# file is still exactly as the caller found it.
	check_true(FileAccess.file_exists(path), "cancelling leaves the file untouched")
	var still_edited: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if still_edited is Dictionary:
		check_eq(int(((still_edited as Dictionary)["profile"] as Dictionary)["xp"]),
				1_000_000, "the edited file was not rewritten by a failed check")
	_clear_directory("user://")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_an_unsigned_old_save_is_not_treated_as_tampered() -> void:
	# The frozen schema-1 fixture predates signatures by design. It must keep loading.
	var text: String = FileAccess.get_file_as_string("res://tests/fixtures/save_schema1_frozen.json")
	check_false(text.is_empty(), "the frozen fixture is committed")
	var parsed: Dictionary = SaveFile.parse(text)
	check_false(str(parsed["signature_status"]) == IntegritySignature.STATUS_FAILED,
			"an older save is not accused of tampering")
