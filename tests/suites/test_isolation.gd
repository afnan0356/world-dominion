extends TestCase
## Suite isolation (Milestone 12, Task 1).
##
## Three questions, and they are different:
##
##   1. **Can every piece of module state be emptied?** The game keeps caches and session flags in
##      `static var`s. If one has no reset, a suite inherits the previous suite's answers, and the
##      failure looks like a flake. This suite fills each cache and proves it empties.
##   2. **Does a suite leave files behind?** A save store under `user://` that nobody deletes is
##      read by the next suite's "no saves exist" test.
##   3. **Does the same work in a different order give the same answer?** Two saves written in
##      opposite orders, and a migration compared with the baseline **strictly** — including the
##      rule that a recorded digest may not be empty, which is exactly the requirement Milestone
##      11's rewritten assertion dropped when its red run turned green.

const FROZEN_SCHEMA1 := "res://tests/fixtures/save_schema1_frozen.json"
const SCRATCH := "user://test_isolation"

var _atlas: WorldAtlas


func before_suite() -> void:
	# Built once, here, rather than inside whichever test happens to run first: the suite hooks
	# exist so that "which test ran first" is never a question a suite depends on.
	_atlas = WorldAtlas.load_default()


func _world(seed_value: int = 424242) -> WorldState:
	var config := CampaignConfig.new()
	config.scenario_id = "modern_world_2026"
	config.country_id = "BGD"
	config.start_date = "2026-01-01"
	config.metadata = {"scenario_name": "Modern World", "country_name": "Bangladesh"}
	return WorldState.new_campaign(config, _atlas.registry, DataStamp.compute(_atlas),
			seed_value)


func _remove(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory != null:
		for file_name: String in directory.get_files():
			directory.remove(file_name)
	DirAccess.remove_absolute(path)


# --- 1. Every cache can be emptied ----------------------------------------

func test_every_static_cache_has_a_reset_that_actually_empties_it() -> void:
	IconAtlas.texture_for("map", 20)
	IconAtlas.texture_for("messages", 20)
	FlagImage.texture_for("BGD")
	ShellIcon.crosswalk()
	DiagnosticsLog.note("INFO", "isolation probe")
	CountryState.shared()
	ModalPanel.stack.append(null)

	check_gt(float(IconAtlas.cache_size()), 0.0, "the icon cache filled")
	check_gt(float(ShellIcon.cache_size()), 0.0, "the shell crosswalk parsed")
	check_gt(float(DiagnosticsLog.count()), 0.0, "the diagnostics log took an entry")
	check_gt(float(ModalPanel.stack.size()), 0.0, "the modal stack holds something")

	IconAtlas.clear_cache()
	ShellIcon.clear_cache()
	FlagImage.clear_cache()
	DiagnosticsLog.clear()
	WorldDeletion.reset_session()
	CountryState.reset_shared()
	StartEligibility.reload()
	ModalPanel.clear_stack()

	check_eq(IconAtlas.cache_size(), 0, "the icon cache empties")
	check_eq(ShellIcon.cache_size(), 0, "the shell crosswalk empties")
	check_eq(FlagImage.cache_size(), 0, "the flag cache empties")
	check_eq(DiagnosticsLog.count(), 0, "the diagnostics log empties")
	check_eq(ModalPanel.open_panels().size(), 0, "the modal stack empties")
	check_eq(WorldDeletion.session_size(), 0, "the deletion session flag clears")


func test_the_modal_stack_is_empty_and_stays_empty_between_suites() -> void:
	ModalPanel.clear_stack()
	check_eq(ModalPanel.open_panels().size(), 0, "no panel is open at the start of a suite")
	var first := ModalPanel.new()
	var second := ModalPanel.new()
	first.build("First")
	second.build("Second")
	host.add_child(first)
	host.add_child(second)
	first.open(host)
	second.open(host)
	check_eq(ModalPanel.open_panels().size(), 2, "two panels can be open")
	ModalPanel.clear_stack()
	check_eq(ModalPanel.open_panels().size(), 0, "and the reset closes both")
	first.queue_free()
	second.queue_free()


# --- 2. Nothing is left behind --------------------------------------------

func test_a_suite_directory_is_gone_after_the_shared_teardown() -> void:
	var store := SaveStore.new(SCRATCH)
	store.ensure_directory()
	var written := store.save("slot_1", _world(), "2026-11-07T10:00:00Z",
			"2026-11-07T10:00:00Z")
	check_true(bool(written.get("ok")), "the scratch save is written: %s"
			% str(written.get("errors")))
	check_true(DirAccess.dir_exists_absolute(SCRATCH), "the directory exists while the test runs")
	var report := SuiteIsolation.finish()
	check_false(DirAccess.dir_exists_absolute(SCRATCH),
			"the shared teardown deletes a suite-owned directory")
	check_true(int(report.get("cleaned", 0)) > 0, "and says how many entries it removed")
	SuiteIsolation.begin()


func test_a_file_written_at_the_root_of_user_is_reported_as_a_leak() -> void:
	SuiteIsolation.begin()
	var leak := "user://isolation_leak_probe.txt"
	var file := FileAccess.open(leak, FileAccess.WRITE)
	check_not_null(file, "the probe file opens")
	if file == null:
		return
	file.store_string("a file no suite owns")
	file.close()
	var leaks := SuiteIsolation.leftovers()
	check_true(leaks.has("isolation_leak_probe.txt"), "the leak is named: %s" % str(leaks))
	DirAccess.remove_absolute(leak)
	SuiteIsolation.finish()


# --- 3. Order does not change the answer ----------------------------------

func test_two_saves_written_in_opposite_orders_agree() -> void:
	var forward := "user://test_isolation_forward"
	var backward := "user://test_isolation_backward"
	var one := _world(1001)
	var two := _world(2002)
	var first := SaveStore.new(forward)
	var second := SaveStore.new(backward)
	first.save("slot_1", one, "2026-11-07T10:00:00Z", "2026-11-07T10:00:00Z")
	first.save("slot_2", two, "2026-11-07T10:05:00Z", "2026-11-07T10:05:00Z")
	second.save("slot_2", two, "2026-11-07T10:05:00Z", "2026-11-07T10:05:00Z")
	second.save("slot_1", one, "2026-11-07T10:00:00Z", "2026-11-07T10:00:00Z")
	check_eq(_slot_text(first), _slot_text(second),
			"writing slot 1 then 2 produces the same two files as 2 then 1")
	check_false(_slot_text(first).is_empty(), "and there was something to compare")
	_remove(forward)
	_remove(backward)


## The two slot files' contents, by slot, in slot order: the comparison is of the bytes the game
## actually wrote, not of a summary that could hide a difference.
func _slot_text(store: SaveStore) -> String:
	var parts := PackedStringArray()
	for slot: String in SaveStore.SLOT_IDS:
		if store.exists(slot):
			parts.append("%s=%s" % [slot, FileAccess.get_file_as_string(store.path_for(slot))])
	return "\n".join(parts)


# --- 4. The rule the rewritten assertion dropped --------------------------

func test_a_baseline_reference_is_never_empty() -> void:
	# Milestone 11's red run failed `baseline_matches()` and the rewrite compared two digest
	# strings instead. That comparison passes when *both* are empty, so the rewrite could turn a
	# red assertion green without changing any production code. This test closes that door: a
	# reference with no digest is a failure, whichever way it is asked.
	var section := CountryState.save_section()
	var digest := str((section["data"] as Dictionary).get("digest", ""))
	check_false(digest.is_empty(), "the save section records a digest")
	check_eq(digest.length(), 64, "the digest is a SHA-256")
	var world := _world()
	check_true(world.baseline_matches(CountryState.shared()),
			"a new campaign's reference matches the shipped baseline")
	check_true(CountryState.shared().digest() == CountryState.initialise().digest(),
			"the shared baseline and a fresh one hash the same")
	check_false(world.baseline_matches(null), "and a null baseline never matches")


func test_the_oldest_fixture_migrates_to_a_non_empty_reference_of_this_baseline() -> void:
	# The strict form of the two assertions Milestone 11 rewrote: the reference must be present,
	# non-empty and equal to what this build ships, in one predicate — so an empty digest on both
	# sides cannot pass.
	var text := FileAccess.get_file_as_string(FROZEN_SCHEMA1)
	check_false(text.is_empty(), "the frozen schema 1 fixture is committed")
	var payload: Variant = JSON.parse_string(text)
	check_true(payload is Dictionary, "and parses")
	if not (payload is Dictionary):
		return
	var migrated := SaveMigrations.migrate(payload as Dictionary)
	check_true(bool(migrated.get("ok")), "it migrates: %s" % str(migrated.get("errors")))
	var world: Variant = (migrated["payload"] as Dictionary).get("world")
	check_true(world is Dictionary, "the payload carries a world")
	if not (world is Dictionary):
		return
	var restored := WorldState.from_dict(world, [])
	var reference := restored.country_state_reference()
	check_false(str(reference.get("digest", "")).is_empty(),
			"the migrated save records a digest, not an empty string")
	check_true(restored.baseline_matches(CountryState.shared()),
			"and the recorded digest is this build's baseline")
	check_eq(int(reference.get("records", 0)), CountryState.shared().count(),
			"the record count agrees with the baseline")
