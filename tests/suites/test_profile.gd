extends TestCase
## The player profile (Milestone 06, Task A): creation, validation, costs, the username
## lock, atomic writes, backup recovery and hostile files.
##
## Every test that touches the disk uses its own file name and removes it afterwards, so
## the suite never depends on what another test left behind.

const TEST_TODAY := "2026-11-06"

var _paths: PackedStringArray = PackedStringArray()


func _cleanup() -> void:
	for path: String in _paths:
		var absolute: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(absolute)
		var backup: String = ProjectSettings.globalize_path(path.get_basename() + ".old.json")
		if FileAccess.file_exists(path.get_basename() + ".old.json"):
			DirAccess.remove_absolute(backup)
		var temp: String = ProjectSettings.globalize_path(path.get_basename() + ".tmp.json")
		if FileAccess.file_exists(path.get_basename() + ".tmp.json"):
			DirAccess.remove_absolute(temp)
	_paths.clear()


func _store(name: String) -> ProfileStore:
	var path := "user://%s.json" % name
	_paths.append(path)
	return ProfileStore.new(path)


# --- creation -----------------------------------------------------------------

func test_a_new_profile_has_one_generated_numeric_id() -> void:
	var profile: PlayerProfile = PlayerProfile.create(12345, TEST_TODAY)
	check_eq(profile.player_id.length(), PlayerProfile.PLAYER_ID_DIGITS,
			"the player ID is %d digits" % PlayerProfile.PLAYER_ID_DIGITS)
	var all_digits := true
	for index in profile.player_id.length():
		var code := profile.player_id.unicode_at(index)
		if code < 0x30 or code > 0x39:
			all_digits = false
	check_true(all_digits, "and it is numeric, as documented")
	check_false(profile.player_id.begins_with("0"), "it never starts with a zero")
	check_eq(profile.created_at, TEST_TODAY, "the creation date is recorded")
	check_eq(profile.level(), 0, "a new profile is level 0")
	check_eq(profile.vip(), 0, "and VIP 0")
	check_eq(profile.wallet.gold_coins(), 0, "with an empty wallet")
	check_eq(profile.wallet.diamonds(), 0, "both currencies empty")
	check_eq(profile.avatar_id, 0, "and the first avatar")
	check_eq(profile.schema_version, PlayerProfile.SCHEMA_VERSION, "at the current version")


func test_the_same_seed_gives_the_same_id_and_a_different_seed_does_not() -> void:
	check_eq(PlayerProfile.generate_player_id(99), PlayerProfile.generate_player_id(99),
			"the ID generator is deterministic, which is what makes it testable")
	check_true(PlayerProfile.generate_player_id(99) != PlayerProfile.generate_player_id(100),
			"two installations get different IDs")


# --- display name and username -------------------------------------------------

func test_display_name_rules_are_structural_and_say_why() -> void:
	for bad: String in ["", "   ", " this has spaces around it "]:
		check_false(PlayerProfile.name_problem(bad).is_empty(),
				"rejects %s" % [bad.strip_edges().is_empty() and "an empty name" or "padding"])
	check_false(PlayerProfile.name_problem("x".repeat(25)).is_empty(),
			"rejects a name over %d characters" % PlayerProfile.NAME_MAX)
	check_true(PlayerProfile.name_problem("x".repeat(24)).is_empty(),
			"accepts a name of exactly %d characters" % PlayerProfile.NAME_MAX)
	check_false(PlayerProfile.name_problem("bad\ttab").is_empty(),
			"rejects control characters")
	check_false(PlayerProfile.name_problem("Аlex").is_empty(),
			"rejects a Cyrillic look-alike mixed into a Latin name")
	check_true(PlayerProfile.name_problem("Александр").is_empty(),
			"accepts a name written entirely in one non-Latin alphabet")
	check_true(PlayerProfile.name_problem("Afnan").is_empty(), "accepts an ordinary name")
	check_true(PlayerProfile.name_problem("Md. Afnan").is_empty(), "and one with a full stop")


func test_the_first_name_change_is_free_and_the_rest_cost_diamonds() -> void:
	var profile: PlayerProfile = PlayerProfile.create(1, TEST_TODAY)
	check_eq(profile.next_name_change_cost(), 0, "the first change is free")
	var first := profile.set_display_name("Afnan")
	check_true(bool(first["ok"]), "the first change succeeds")
	check_eq(int(first["charged"]), 0, "and costs nothing")
	check_eq(profile.display_name, "Afnan", "the name is set")
	check_eq(profile.display_name_changes, 1, "and counted")
	check_eq(profile.next_name_change_cost(), PlayerProfile.NAME_CHANGE_COST,
			"the next change costs %d Diamonds" % PlayerProfile.NAME_CHANGE_COST)

	var poor := profile.set_display_name("Someone")
	check_false(bool(poor["ok"]), "a second change without Diamonds is refused")
	check_true(str(poor["reason"]).contains("Red Gems"), "and says what it costs")
	check_eq(profile.display_name, "Afnan", "a refusal changes nothing")

	profile.wallet.add(GameWallet.Currency.DIAMONDS, PlayerProfile.NAME_CHANGE_COST)
	var paid := profile.set_display_name("Someone")
	check_true(bool(paid["ok"]), "with enough Diamonds the change goes through")
	check_eq(int(paid["charged"]), PlayerProfile.NAME_CHANGE_COST, "the cost is charged")
	check_eq(profile.wallet.diamonds(), 0, "and the Diamonds are gone")
	check_eq(profile.display_name_changes, 2, "each change is counted")


func test_a_rejected_name_costs_nothing() -> void:
	var profile: PlayerProfile = PlayerProfile.create(2, TEST_TODAY)
	profile.set_display_name("First")
	profile.wallet.add(GameWallet.Currency.DIAMONDS, 500)
	var before := profile.wallet.diamonds()
	var result := profile.set_display_name("")
	check_false(bool(result["ok"]), "an empty name is refused")
	check_eq(profile.wallet.diamonds(), before, "and no Diamonds are taken")
	check_eq(profile.display_name, "First", "the old name stands")


func test_the_username_is_set_once_and_then_locked_for_good() -> void:
	var profile: PlayerProfile = PlayerProfile.create(3, TEST_TODAY)
	check_false(profile.username_locked, "a new profile has no username")
	check_false(bool(profile.set_username("AB")["ok"]), "too short is refused")
	check_false(bool(profile.set_username("Has Space")["ok"]), "a space is refused")
	check_false(bool(profile.set_username("UPPER")["ok"]), "upper case is refused")
	var assigned := profile.set_username("afnan_0356")
	check_true(bool(assigned["ok"]), "a valid username is accepted")
	check_true(profile.username_locked, "and locks immediately")
	var second := profile.set_username("another")
	check_false(bool(second["ok"]), "a second attempt is refused")
	check_eq(profile.username, "afnan_0356", "and the first one stands")
	var reloaded: PlayerProfile = PlayerProfile.from_dict(profile.to_dict())
	check_true(reloaded.username_locked, "the lock survives a save and load")
	check_false(bool(reloaded.set_username("sneaky")["ok"]), "even on the reloaded profile")


# --- wallet and tutorial -------------------------------------------------------

func test_the_wallet_survives_a_round_trip_exactly() -> void:
	var profile: PlayerProfile = PlayerProfile.create(4, TEST_TODAY)
	profile.wallet.add(GameWallet.Currency.GOLD_COINS, 1234)
	profile.wallet.add(GameWallet.Currency.DIAMONDS, 56)
	var reloaded: PlayerProfile = PlayerProfile.from_dict(profile.to_dict())
	check_eq(reloaded.wallet.gold_coins(), 1234, "gold survives")
	check_eq(reloaded.wallet.diamonds(), 56, "Diamonds survive")
	check_false(reloaded.repaired, "and nothing had to be repaired")


func test_the_tutorial_reward_pays_once_per_profile() -> void:
	var profile: PlayerProfile = PlayerProfile.create(5, TEST_TODAY)
	var first := profile.complete_tutorial()
	check_eq(int(first["xp"]), Progression.TUTORIAL_XP, "the first completion pays XP")
	check_eq(int(first["gold_coins"]), Progression.TUTORIAL_GOLD, "and gold")
	check_eq(int(first["diamonds"]), Progression.TUTORIAL_DIAMONDS, "and Diamonds")
	check_true(profile.tutorial_done(), "the tutorial is recorded as done")
	var second := profile.complete_tutorial()
	check_eq(int(second["xp"]), 0, "a second completion pays nothing")
	check_eq(profile.wallet.gold_coins(), Progression.TUTORIAL_GOLD, "the balance did not double")
	var reloaded: PlayerProfile = PlayerProfile.from_dict(profile.to_dict())
	var third := reloaded.complete_tutorial()
	check_eq(int(third["diamonds"]), 0, "and it still pays nothing after a reload")


func test_skipping_the_tutorial_pays_nothing_and_can_be_reopened() -> void:
	var profile: PlayerProfile = PlayerProfile.create(6, TEST_TODAY)
	profile.skip_tutorial()
	check_true(profile.tutorial_skipped, "the skip is recorded")
	check_false(profile.tutorial_done(), "but the tutorial is not completed")
	check_eq(profile.wallet.gold_coins(), 0, "and nothing is paid")
	check_eq(profile.xp, 0, "no XP either")
	var later := profile.complete_tutorial()
	check_eq(int(later["xp"]), Progression.TUTORIAL_XP,
			"a skipped tutorial can be finished later, and then it pays")


func test_terms_acceptance_is_versioned() -> void:
	var profile: PlayerProfile = PlayerProfile.create(7, TEST_TODAY)
	check_false(profile.has_accepted_terms(1), "a new profile has accepted nothing")
	profile.accept_terms(1, TEST_TODAY)
	check_true(profile.has_accepted_terms(1), "accepting version 1 is recorded")
	check_false(profile.has_accepted_terms(2), "a newer version asks again")
	var reloaded: PlayerProfile = PlayerProfile.from_dict(profile.to_dict())
	check_true(reloaded.has_accepted_terms(1), "and the acceptance survives a reload")


# --- storage: atomic writes, backups, hostile files ----------------------------

func test_save_then_load_round_trips_through_the_file() -> void:
	var store: ProfileStore = _store("wd_profile_roundtrip")
	var profile: PlayerProfile = PlayerProfile.create(8, TEST_TODAY)
	profile.set_display_name("Afnan")
	profile.add_xp(260)
	profile.wallet.add(GameWallet.Currency.GOLD_COINS, 777)
	var saved := store.save(profile)
	check_true(bool(saved["ok"]), "the profile is written: %s" % saved["error"])
	var loaded := store.load_or_create(8, TEST_TODAY)
	check_eq(str(loaded["source"]), "main", "it is read back from the main file")
	var restored: PlayerProfile = loaded["profile"]
	check_eq(restored.display_name, "Afnan", "the name survives")
	check_eq(restored.level(), 2, "260 XP is level 2 under the corrected curve")
	check_eq(restored.wallet.gold_coins(), 777, "the wallet survives")
	_cleanup()


func test_a_second_save_keeps_the_previous_one_as_a_backup() -> void:
	var store: ProfileStore = _store("wd_profile_backup")
	var profile: PlayerProfile = PlayerProfile.create(9, TEST_TODAY)
	profile.set_display_name("First")
	store.save(profile)
	# A later change costs Diamonds, so the test pays for it.
	profile.wallet.add(GameWallet.Currency.DIAMONDS, PlayerProfile.NAME_CHANGE_COST)
	profile.set_display_name("Second")
	store.save(profile)
	check_true(store.backup_exists(), "the previous profile is kept")
	var main := store.load_or_create(9, TEST_TODAY)
	check_eq(str(main["source"]), "main", "the newest profile is the one loaded")
	check_eq((main["profile"] as PlayerProfile).display_name, "Second", "and it is the newest")
	_cleanup()


func test_a_damaged_profile_falls_back_to_the_backup_without_deleting_it() -> void:
	var store: ProfileStore = _store("wd_profile_recover")
	var profile: PlayerProfile = PlayerProfile.create(10, TEST_TODAY)
	profile.set_display_name("Good")
	store.save(profile)
	profile.set_display_name("Newer")
	store.save(profile)
	# Damage the main file exactly as a half-finished copy would.
	var handle := FileAccess.open(store.path(), FileAccess.WRITE)
	handle.store_string("{ this is not json")
	handle.close()
	var recovered := store.load_or_create(10, TEST_TODAY)
	check_eq(str(recovered["source"]), "backup", "the backup is used")
	check_eq((recovered["profile"] as PlayerProfile).display_name, "Good",
			"and it holds the previous profile")
	check_true((recovered["problems"] as PackedStringArray).size() > 0,
			"the player is told what happened")
	check_true(FileAccess.file_exists(store.path()), "the damaged file is still on disk")
	_cleanup()


func test_hostile_profile_files_are_refused_or_repaired_never_trusted() -> void:
	var cases := {
		"empty": "",
		"not json": "]]]",
		"wrong format": "{\"format\": \"something-else\", \"profile\": {}}",
		"no profile": "{\"format\": \"world-dominion-profile\"}",
		"array": "[1,2,3]",
	}
	for label: String in cases:
		var store: ProfileStore = _store("wd_profile_hostile_%s" % label.replace(" ", "_"))
		var handle := FileAccess.open(store.path(), FileAccess.WRITE)
		handle.store_string(str(cases[label]))
		handle.close()
		var loaded := store.load_or_create(11, TEST_TODAY)
		var profile: PlayerProfile = loaded["profile"]
		check_not_null(profile, "%s: a profile is always available" % label)
		check_true(profile.player_id.length() == PlayerProfile.PLAYER_ID_DIGITS,
				"%s: with a valid player ID" % label)
		check_eq(profile.wallet.gold_coins(), 0, "%s: and an empty wallet" % label)
		check_true(FileAccess.file_exists(store.path()),
				"%s: the unreadable file was not deleted" % label)
		_cleanup()


func test_a_tampered_value_is_clamped_and_reported() -> void:
	var store: ProfileStore = _store("wd_profile_tamper")
	var profile: PlayerProfile = PlayerProfile.create(12, TEST_TODAY)
	store.save(profile)
	var text: String = FileAccess.get_file_as_string(store.path())
	var parsed: Variant = JSON.parse_string(text)
	var envelope: Dictionary = parsed
	var body: Dictionary = envelope["profile"]
	body["xp"] = 99_999_999_999
	body["avatar_id"] = 999
	body["display_name"] = "  "
	body["player_id"] = "12345"
	envelope["profile"] = body
	var handle := FileAccess.open(store.path(), FileAccess.WRITE)
	handle.store_string(JSON.stringify(envelope))
	handle.close()
	var loaded := store.load_or_create(12, TEST_TODAY)
	var repaired: PlayerProfile = loaded["profile"]
	check_eq(repaired.xp, Progression.xp_to_reach(Progression.MAX_LEVEL) - 1,
			"absurd XP is clamped to the top of the curve")
	check_eq(repaired.avatar_id, 0, "an impossible avatar falls back to the first")
	check_eq(repaired.display_name, "Player", "an empty name falls back to the default")
	check_true(repaired.player_id.length() == PlayerProfile.PLAYER_ID_DIGITS,
			"a short player ID is replaced, not kept")
	check_true((loaded["problems"] as PackedStringArray).size() >= 4,
			"and every repair is reported")
	_cleanup()


func test_a_newer_schema_is_read_with_a_warning_and_nothing_deleted() -> void:
	var store: ProfileStore = _store("wd_profile_future")
	var profile: PlayerProfile = PlayerProfile.create(13, TEST_TODAY)
	store.save(profile)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(store.path()))
	var envelope: Dictionary = parsed
	envelope["schema_version"] = PlayerProfile.SCHEMA_VERSION + 1
	var handle := FileAccess.open(store.path(), FileAccess.WRITE)
	handle.store_string(JSON.stringify(envelope))
	handle.close()
	var loaded := store.load_or_create(13, TEST_TODAY)
	check_eq(str(loaded["source"]), "main", "a newer file is still read")
	check_true((loaded["problems"] as PackedStringArray).size() > 0,
			"with a warning about its version")
	check_true(FileAccess.file_exists(store.path()), "and it is not deleted")
	_cleanup()


func test_the_profile_is_separate_from_world_saves() -> void:
	# A profile file is not a save slot: the save store must not see one, and the profile
	# store must not need a country or a world.
	var store: ProfileStore = _store("wd_profile_not_a_save")
	store.save(PlayerProfile.create(14, TEST_TODAY))
	var saves := SaveStore.new("user://wd_profile_not_a_save_dir")
	check_false(store.path() == saves.path_for("1"),
			"the profile is not a save slot's file")
	check_false(store.path().begins_with(saves.directory()),
			"and it does not live in the save folder")
	var text: String = FileAccess.get_file_as_string(store.path())
	check_true(text.contains(ProfileStore.FORMAT_ID), "the file names its own format")
	check_false(text.contains("world-dominion-save"), "and is not a save file")
	_cleanup()
