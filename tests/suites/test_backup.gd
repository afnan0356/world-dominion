extends TestCase
## One-file backup and restore (Milestone 06, Task G).
##
## The promises under test: a round trip restores exactly what was backed up; a truncated,
## tampered, wrong-version or hostile file is refused with a reason instead of being
## half-applied; you can restore everything or choose worlds; an existing world is never
## overwritten without confirmation; and restoring after deleting everything works.

var _atlas: WorldAtlas


func _load() -> void:
	if _atlas == null:
		_atlas = WorldAtlas.load_default()


func _world(seed_value: int, playtime: float) -> WorldState:
	_load()
	var config: CampaignConfig = CampaignConfig.new()
	config.scenario_id = "modern_world_2026"
	config.country_id = "BGD"
	config.start_date = "2026-01-01"
	config.metadata = {"scenario_name": "Modern World", "country_name": "Bangladesh"}
	var world: WorldState = WorldState.new_campaign(config, _atlas.registry, DataStamp.compute(_atlas),
			seed_value)
	world.add_playtime(playtime)
	world.wallet.add(GameWallet.Currency.GOLD_COINS, 25)
	return world


func _store(name: String) -> SaveStore:
	var store := SaveStore.new("user://%s" % name)
	_clear(store.directory())
	return store


func _clear(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory := DirAccess.open(absolute)
	if directory == null:
		return
	for name: String in directory.get_files():
		directory.remove(name)


## Two real worlds, saved by the real store, read back as the exact text a backup holds.
func _worlds(store: SaveStore) -> Dictionary:
	var texts := {}
	for slot: String in ["1", "2"]:
		var saved := store.save(slot, _world(slot.hash(), 60.0), "2026-01-01",
				"2026-02-01T00:00:00Z")
		if bool(saved["ok"]):
			texts[slot] = FileAccess.get_file_as_string(store.path_for(slot))
	return texts


func _profile() -> PlayerProfile:
	var profile: PlayerProfile = PlayerProfile.create(31, "2026-11-06")
	profile.set_display_name("Afnan")
	profile.add_xp(320)
	profile.complete_tutorial()
	return profile


func _bundle(store: SaveStore) -> Dictionary:
	return BackupBundle.build(_profile(), _worlds(store), "2026-11-06T12:00:00Z",
			"Before the long trip")


# --- round trip ----------------------------------------------------------------

func test_a_bundle_round_trips_profile_and_worlds() -> void:
	var store: SaveStore = _store("wd_backup_roundtrip")
	var bundle: Dictionary = _bundle(store)
	var text: String = BackupBundle.serialize(bundle)
	check_false(text.is_empty(), "the bundle serialises")
	var inspected: Dictionary = BackupBundle.inspect(text)
	check_true(bool(inspected["ok"]), "and inspects cleanly: %s"
			% str(inspected["problems"]))
	check_eq(str(inspected["checksum_status"]), "ok", "the checksum matches")
	check_eq(str(inspected["signature_status"]), "ok", "the signature matches")
	var summary: Dictionary = inspected["summary"]
	check_eq(str(summary["label"]), "Before the long trip", "the label is kept")
	check_eq(str(summary["player_name"]), "Afnan", "the profile name is in the summary")
	check_eq((summary["worlds"] as Array).size(), 2, "both worlds are listed")
	for line: Dictionary in summary["worlds"]:
		check_true(bool(line["valid"]), "%s is a valid world" % line["slot"])
		check_eq(str(line["country"]), "Bangladesh", "with its country")
		check_true(not str(line["date"]).is_empty(), "and its date")

	# Delete everything, then restore.
	_clear(store.directory())
	check_false(store.exists("1"), "the worlds are gone")
	var restored: Dictionary = BackupBundle.restore(inspected, store, "all", [], true)
	check_true(bool(restored["ok"]), "the restore runs")
	check_eq((restored["restored"] as Array).size(), 2, "both worlds come back")
	check_not_null(restored["profile"], "and the profile comes with them")
	check_eq((restored["profile"] as PlayerProfile).xp, _profile().xp,
			"with the XP it was backed up with")
	var parsed: Dictionary = SaveFile.parse(FileAccess.get_file_as_string(store.path_for("1")))
	check_true(bool(parsed["ok"]), "a restored world is a valid save")
	check_eq(str(parsed["signature_status"]), "ok", "with its signature intact")
	_clear(store.directory())


func test_a_world_restored_is_byte_identical_to_the_one_backed_up() -> void:
	var store: SaveStore = _store("wd_backup_bytes")
	var texts: Dictionary = _worlds(store)
	var bundle: Dictionary = BackupBundle.build(_profile(), texts, "2026-11-06T12:00:00Z", "Bytes")
	var inspected: Dictionary = BackupBundle.inspect(BackupBundle.serialize(bundle))
	_clear(store.directory())
	BackupBundle.restore(inspected, store, "all", [], true)
	check_eq(FileAccess.get_file_as_string(store.path_for("1")),
			str(texts["1"]), "the restored file is the same text, not a re-save")
	_clear(store.directory())


# --- refusals ------------------------------------------------------------------

func test_truncated_tampered_and_wrong_version_files_are_refused() -> void:
	var store: SaveStore = _store("wd_backup_bad")
	var text: String = BackupBundle.serialize(_bundle(store))

	var truncated: Dictionary = BackupBundle.inspect(text.substr(0, text.length() / 2))
	check_false(bool(truncated["ok"]), "a truncated file does not pass")
	check_true((truncated["problems"] as PackedStringArray).size() > 0,
			"and says so")

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		check_true(false, "the bundle is JSON")
		return
	var document: Dictionary = parsed
	var body: Dictionary = document["body"]
	((body["profile"] as Dictionary))["xp"] = 5000
	var tampered: Dictionary = BackupBundle.inspect(JSON.stringify(document))
	check_false(bool(tampered["ok"]), "an edited body fails the checksum and signature")
	check_eq(str(tampered["checksum_status"]), "failed", "the checksum notices")
	check_eq(str(tampered["signature_status"]), "failed", "and the signature notices")

	document["schema_version"] = BackupBundle.SCHEMA_VERSION + 5
	var future: Dictionary = BackupBundle.inspect(JSON.stringify(document))
	check_false(bool(future["ok"]), "a newer format is refused")
	check_true(str((future["problems"] as PackedStringArray)[0]).contains("newer"),
			"with a message that says it is newer")

	for hostile: String in ["", "not json", "[]", "{\"format\": \"other\"}"]:
		var refused: Dictionary = BackupBundle.inspect(hostile)
		check_false(bool(refused["ok"]), "hostile input %s is refused" % hostile.substr(0, 12))
	_clear(store.directory())


func test_an_existing_world_is_not_overwritten_without_confirmation() -> void:
	var store: SaveStore = _store("wd_backup_overwrite")
	var text: String = BackupBundle.serialize(_bundle(store))
	var inspected: Dictionary = BackupBundle.inspect(text)
	# The worlds are still on disk from the backup, so a restore would collide with them.
	var before: String = FileAccess.get_file_as_string(store.path_for("1"))
	var refused: Dictionary = BackupBundle.restore(inspected, store, "all", [], false)
	check_true(bool(refused["ok"]), "the restore runs")
	check_eq((refused["restored"] as Array).size(), 0, "but writes nothing")
	check_eq((refused["skipped"] as Array).size(), 2, "and reports both worlds as skipped")
	check_true(str((refused["reasons"] as PackedStringArray)[0]).contains("confirmation"),
			"explaining that overwriting was not confirmed")
	check_eq(FileAccess.get_file_as_string(store.path_for("1")), before,
			"the existing world is untouched")

	var confirmed: Dictionary = BackupBundle.restore(inspected, store, "all", [], true)
	check_eq((confirmed["restored"] as Array).size(), 2, "with confirmation it restores")
	_clear(store.directory())


func test_choosing_worlds_restores_only_those() -> void:
	var store: SaveStore = _store("wd_backup_choose")
	var document := BackupBundle.serialize(_bundle(store))
	var inspected: Dictionary = BackupBundle.inspect(document)
	_clear(store.directory())
	var chosen: Dictionary = BackupBundle.restore(inspected, store, "choose", ["2"], true)
	check_eq((chosen["restored"] as Array).size(), 1, "one world is restored")
	check_eq(str((chosen["restored"] as Array)[0]), "2", "the chosen one")
	check_false(store.exists("1"), "the other is not created")
	var missing: Dictionary = BackupBundle.restore(inspected, store, "choose", ["3"], true)
	check_eq((missing["restored"] as Array).size(), 0, "a slot that is not there writes nothing")
	check_true(str((missing["reasons"] as PackedStringArray)[0]).contains("not in this backup"),
			"and says so")
	_clear(store.directory())


func test_a_bundle_with_a_broken_world_skips_it_and_keeps_the_rest() -> void:
	var store: SaveStore = _store("wd_backup_broken_world")
	var texts: Dictionary = _worlds(store)
	texts["autosave"] = "{\"format\": \"world-dominion-save\", \"schema_version\": 2}"
	var bundle: Dictionary = BackupBundle.build(_profile(), texts,
			"2026-11-06T12:00:00Z", "One broken")
	var inspected: Dictionary = BackupBundle.inspect(BackupBundle.serialize(bundle))
	_clear(store.directory())
	var restored: Dictionary = BackupBundle.restore(inspected, store, "all", [], true)
	check_eq((restored["restored"] as Array).size(), 2, "the readable worlds restore")
	check_eq((restored["skipped"] as Array).size(), 1, "the broken one is skipped")
	check_false(store.exists("autosave"), "and is not invented into existence")
	_clear(store.directory())


func test_a_bundle_without_a_profile_still_restores_worlds() -> void:
	var store: SaveStore = _store("wd_backup_no_profile")
	var texts: Dictionary = _worlds(store)
	var bundle: Dictionary = BackupBundle.build(_profile(), texts,
			"2026-11-06T12:00:00Z", "Worlds only")
	var body: Dictionary = bundle["body"]
	body.erase("profile")
	bundle["checksum"] = CanonicalJson.sha256(body)
	bundle[IntegritySignature.SIGNATURE_KEY] = IntegritySignature.signature_of(body)
	var inspected: Dictionary = BackupBundle.inspect(BackupBundle.serialize(bundle))
	check_true(bool(inspected["ok"]), "the bundle is still valid")
	_clear(store.directory())
	var restored: Dictionary = BackupBundle.restore(inspected, store, "all", [], true)
	check_eq((restored["restored"] as Array).size(), 2, "the worlds restore")
	check_null_owner(restored["profile"])
	_clear(store.directory())


func check_null_owner(value: Variant) -> void:
	check_true(value == null, "and there is no profile to install")
