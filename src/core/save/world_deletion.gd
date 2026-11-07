class_name WorldDeletion
extends RefCounted
## Deleting a world, safely (Milestone 09, Task 6).
##
## The rule this class exists to keep: a world is never deleted without (a) the player being
## shown exactly which world it is — the slot, the country, the in-game date and how long they
## played it — and (b) a recovery copy being made first wherever the device allows one.
##
## What it deletes: the slot's own files, and nothing else. The profile lives in a different
## file and a different store, and no method here can reach it.
##
## The recovery copy lives in `user://saves/deleted/` for the rest of the session. `begin_session()`
## clears anything left over from a previous run, because the promise made to the player is
## "you can undo this until you close the game" — not "forever". When no copy can be made the
## deletion is still allowed, but only if the caller says so, and the answer then says plainly
## that the deletion is permanent.

const COPY_FOLDER := "deleted"

## Slots whose recovery copy was made by *this* process. "One session" is one process, so a
## copy that is not listed here belongs to an earlier run and is not offered as an undo.
static var _session_slots: Dictionary = {}
## Test hook, in the same spirit as `SaveStore.inject_failure_stage`: makes the recovery copy
## fail so the permanent-deletion path can be exercised without a read-only disk.
var inject_copy_failure := false
var store: SaveStore


func _init(save_store: SaveStore = null) -> void:
	store = save_store if save_store != null else SaveStore.new()


## Where this store's recovery copies live. Uses the store's own directory, so a test store in
## `user://tests/` keeps its copies there too.
func copy_folder() -> String:
	return store.directory().path_join(COPY_FOLDER)


## Forgets recovery copies left by an earlier run, and keeps the ones this run made — so a
## player who deletes a world, wanders through other screens and comes back still has their
## undo, while yesterday's copy is gone. Called whenever the worlds screen opens.
func begin_session() -> void:
	var directory := DirAccess.open(copy_folder())
	if directory == null:
		return
	for file_name: String in directory.get_files():
		if _session_slots.has(_slot_of(file_name)):
			continue
		DirAccess.remove_absolute(ProjectSettings.globalize_path(
				copy_folder().path_join(file_name)))


## The slot a recovery-copy file belongs to, or "" for anything else in the folder.
static func _slot_of(file_name: String) -> String:
	for slot: String in SaveStore.SLOT_IDS:
		if file_name == "%s.json" % slot or file_name == "%s.backup.json" % slot:
			return slot
	return ""


## Everything the confirmation screen needs to name the world it is about to delete.
func describe(slot: String, registry: CountryRegistry = null) -> Dictionary:
	var entry := store.inspect(slot, registry)
	var summary: Dictionary = entry["summary"]
	var seconds := int(summary.get("playtime_seconds", 0))
	return {
		"slot": slot,
		"label": SaveStore.slot_label(slot),
		"exists": bool(entry["exists"]),
		"valid": bool(entry["valid"]),
		"country": str(summary.get("player_country_name", "")),
		"date": str(summary.get("date_label", "")),
		"playtime_seconds": seconds,
		"playtime_label": playtime_label(seconds),
		"has_backup": bool(entry["has_backup"]),
	}


## A short, plain duration: "less than a minute", "42 min", "3 h 07 min".
static func playtime_label(seconds: int) -> String:
	if seconds < 60:
		return Strings.t("worlds.playtime_brief")
	var minutes := seconds / 60
	if minutes < 60:
		return Strings.t("worlds.playtime_minutes", [minutes])
	return Strings.t("worlds.playtime_hours", [minutes / 60, minutes % 60])


## Whether a recovery copy could be made right now. The confirmation panel uses this before the
## player agrees, so it never promises an undo it cannot deliver — and never warns about a
## permanence that will not happen either.
func copy_possible(slot: String) -> bool:
	if inject_copy_failure or not store.exists(slot):
		return false
	var folder := copy_folder()
	var absolute := ProjectSettings.globalize_path(folder)
	DirAccess.make_dir_recursive_absolute(absolute)
	if not DirAccess.dir_exists_absolute(absolute):
		return false
	var probe_path := folder.path_join(".copy-probe")
	var probe := FileAccess.open(probe_path, FileAccess.WRITE)
	if probe == null:
		return false
	probe.store_string("ok")
	probe.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(probe_path))
	return true


func undo_available(slot: String) -> bool:
	return FileAccess.file_exists(copy_folder().path_join("%s.json" % slot))


## Copies the slot's files aside, then deletes the slot. `allow_without_copy` is the caller's
## decision to delete permanently when the copy cannot be made; it defaults to false, so a
## failure to protect the file stops the deletion instead of losing data silently.
func delete(slot: String, allow_without_copy := false) -> Dictionary:
	var result := {
		"ok": false,
		"copy_made": false,
		"undo_available": false,
		"permanent": false,
		"error": "",
		"description": describe(slot),
	}
	if not store.exists(slot):
		result["error"] = "there is no world in that slot"
		return result
	result["copy_made"] = _copy_for_undo(slot)
	if not bool(result["copy_made"]) and not allow_without_copy:
		result["error"] = "a recovery copy could not be made"
		return result
	if not store.delete(slot):
		result["error"] = "the store refused to delete the slot"
		return result
	result["ok"] = true
	if bool(result["copy_made"]):
		_session_slots[slot] = true
	result["undo_available"] = undo_available(slot)
	result["permanent"] = not bool(result["undo_available"])
	return result


## Puts the world back from this session's recovery copy. False when there is nothing to
## restore — the screen then says the deletion was permanent rather than pretending.
func undo(slot: String) -> bool:
	if not undo_available(slot):
		return false
	var restored := _restore_file(copy_folder().path_join("%s.json" % slot), store.path_for(slot))
	if not restored:
		return false
	_restore_file(copy_folder().path_join("%s.backup.json" % slot),
			store.backup_path_for(slot))
	return store.exists(slot)


## Drops a recovery copy on purpose (after an undo, or when the player keeps the deletion).
func forget(slot: String) -> void:
	_remove(copy_folder().path_join("%s.json" % slot))
	_remove(copy_folder().path_join("%s.backup.json" % slot))
	_session_slots.erase(slot)


# --- Internals -------------------------------------------------------------

func _copy_for_undo(slot: String) -> bool:
	if inject_copy_failure:
		return false
	var folder := copy_folder()
	var absolute := ProjectSettings.globalize_path(folder)
	var made := DirAccess.make_dir_recursive_absolute(absolute)
	if made != OK and not DirAccess.dir_exists_absolute(absolute):
		return false
	var copied := true
	for path: String in [store.path_for(slot), store.backup_path_for(slot)]:
		if not FileAccess.file_exists(path):
			continue
		var target := folder.path_join(path.get_file())
		copied = _copy_file(path, target) and copied
	return copied and undo_available(slot)


func _copy_file(from_path: String, to_path: String) -> bool:
	var text := FileAccess.get_file_as_string(from_path)
	if text.is_empty():
		return false
	var file := FileAccess.open(to_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	return true


func _restore_file(from_path: String, to_path: String) -> bool:
	if not FileAccess.file_exists(from_path):
		return false
	return _copy_file(from_path, to_path)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
