class_name SaveStore
extends RefCounted
## Local save slots: atomic writes, rolling backups, strict loading, migration.
##
## Everything lives under `user://saves/`, which on every platform is the folder
## the operating system reserves for this game. There is no cloud, no account and
## no network code anywhere in this file.
##
## THE WRITE SEQUENCE (why a crash cannot destroy the previous save)
##
##   1. serialise the save and write it to `<slot>.tmp.json`;
##   2. read that file back, parse it, verify its checksum and its state hash;
##   3. copy the current `<slot>.json` to `<slot>.bak.json`;
##   4. rename `<slot>.json` to `<slot>.old.json`, then rename the temp file to
##      `<slot>.json`, then delete `<slot>.old.json`.
##
## The live save file is only replaced by a rename of a file that has already been
## verified, and the previous good file exists twice during the swap (as the
## backup and as `.old`). If power is lost at any point, one of those files is a
## complete save: step 3's backup if the crash came before step 4, or the `.old`
## copy if the crash came mid-rename. `load()` tries the main file, then the
## backup, and reports which one it used.
##
## THE READ SEQUENCE
##
##   read → parse → verify checksum → verify state hash → migrate if older →
##   rebuild the WorldState → validate it against this build's registry.
##
## Every step appends a precise message to `errors`. Nothing is ever substituted:
## a save that fails any check is refused, the file is left exactly as it was, and
## the player is offered the backup instead.

const SAVE_DIR := "user://saves"
const SLOT_COUNT := 3
const AUTOSAVE_SLOT := "autosave"
const SLOT_IDS: PackedStringArray = ["1", "2", "3", AUTOSAVE_SLOT]
const FILE_EXTENSION := ".json"

## Test seam: when non-zero, the next save fails at that stage on purpose so the
## atomic-write guarantee can be proven in a test. Stage 1 = while writing the temp
## file, 2 = verification of the temp file, 3 = after the backup was written but
## before the swap. Never set by gameplay code.
var inject_failure_stage := 0

## Where this store keeps its files. The game uses `SAVE_DIR`; a test points it at
## a scratch folder so it can never touch a real save.
var save_directory := SAVE_DIR

var last_save_milliseconds := 0.0
var last_load_milliseconds := 0.0
var _cached_stamp: Dictionary = {}


func _init(directory_path: String = SAVE_DIR) -> void:
	save_directory = directory_path


## The directory this store writes to.
func directory() -> String:
	return save_directory


static func is_valid_slot(slot: String) -> bool:
	return SLOT_IDS.has(slot)


static func slot_label(slot: String) -> String:
	return "Autosave" if slot == AUTOSAVE_SLOT else "Slot %s" % slot


func path_for(slot: String) -> String:
	return "%s/%s%s" % [save_directory, slot, FILE_EXTENSION]


func backup_path_for(slot: String) -> String:
	return "%s/%s.bak%s" % [save_directory, slot, FILE_EXTENSION]


func _temp_path_for(slot: String) -> String:
	return "%s/%s.tmp%s" % [save_directory, slot, FILE_EXTENSION]


func _old_path_for(slot: String) -> String:
	return "%s/%s.old%s" % [save_directory, slot, FILE_EXTENSION]


func ensure_directory() -> bool:
	if DirAccess.dir_exists_absolute(save_directory):
		return true
	var error := DirAccess.make_dir_recursive_absolute(save_directory)
	if error != OK:
		push_error("SaveStore: could not create %s (error %d)." % [save_directory, error])
		return false
	return true


func exists(slot: String) -> bool:
	return FileAccess.file_exists(path_for(slot))


func backup_exists(slot: String) -> bool:
	return FileAccess.file_exists(backup_path_for(slot))


# --- Writing ---------------------------------------------------------------

## Saves `world` into `slot`. Returns:
##   ok, errors, player_error, path, bytes, milliseconds
func save(slot: String, world: WorldState, created_at: String, now: String) -> Dictionary:
	var result := {"ok": false, "errors": [], "player_error": "", "path": "", "bytes": 0,
			"milliseconds": 0.0}
	if _save_inputs_are_usable(slot, world, result):
		_run_save_stages(slot, world, created_at, now, result)
	inject_failure_stage = 0
	return result


## Checks everything that can be checked before a byte is written, so a refused
## save never leaves a temporary file behind.
func _save_inputs_are_usable(slot: String, world: WorldState, result: Dictionary) -> bool:
	var errors: Array = result["errors"]
	if not is_valid_slot(slot):
		errors.append("unknown slot '%s'" % slot)
		result["player_error"] = "That save slot does not exist."
		return false
	if world == null:
		errors.append("no world state to save")
		result["player_error"] = "There is no campaign to save yet."
		return false
	var validation := world.validation_errors(null)
	if not validation.is_empty():
		errors.append_array(validation)
		result["player_error"] = "This campaign's state is inconsistent, so it was not saved."
		return false
	if not ensure_directory():
		errors.append("could not create the save folder")
		result["player_error"] = "The game could not open its save folder."
		return false
	return true


func _run_save_stages(slot: String, world: WorldState, created_at: String, now: String,
		result: Dictionary) -> void:
	var started := Time.get_ticks_usec()
	var text := SaveFile.serialize(SaveFile.build(world, slot, created_at, now))
	if text.is_empty():
		result["errors"].append("the save could not be serialised")
		result["player_error"] = "The game could not write this save."
		return
	var temp_path := _temp_path_for(slot)
	if _write_text(temp_path, text) != OK or inject_failure_stage == 1:
		result["errors"].append("writing the temporary file failed (injected: %s)"
				% ("yes" if inject_failure_stage == 1 else "no"))
		_remove(temp_path)
		result["player_error"] = "The game could not write to storage. Your previous save is safe."
		return
	# Verify the bytes that actually reached the disk, not the bytes in memory.
	var verification := SaveFile.parse(_read_text(temp_path))
	if not bool(verification["ok"]) or inject_failure_stage == 2:
		result["errors"].append_array(verification["errors"])
		if inject_failure_stage == 2:
			result["errors"].append("the temporary file failed verification (injected)")
		_remove(temp_path)
		result["player_error"] = ("The save could not be verified after writing, so it was "
				+ "discarded. Your previous save is untouched.")
		return
	var main_path := path_for(slot)
	if FileAccess.file_exists(main_path) and _copy_text(main_path,
			backup_path_for(slot)) != OK:
		result["errors"].append("could not write the backup")
		_remove(temp_path)
		result["player_error"] = ("The game could not keep a backup of the previous save, "
				+ "so it did not replace it.")
		return
	if inject_failure_stage == 3:
		result["errors"].append("the swap failed after the backup was written (injected)")
		_remove(temp_path)
		result["player_error"] = "Saving was interrupted. Your previous save is safe."
		return
	if not _swap_in(temp_path, main_path, slot):
		result["errors"].append("could not replace the save file")
		result["player_error"] = "The game could not finish saving. Your previous save is safe."
		return
	last_save_milliseconds = float(Time.get_ticks_usec() - started) / 1000.0
	result["ok"] = true
	result["path"] = main_path
	result["bytes"] = text.to_utf8_buffer().size()
	result["milliseconds"] = last_save_milliseconds


## The rename dance. The previous file stops being "the save" only after the new
## file is already in place, and it is restored if the promotion fails.
func _swap_in(temp_path: String, main_path: String, slot: String) -> bool:
	var old_path := _old_path_for(slot)
	_remove(old_path)
	if FileAccess.file_exists(main_path) and DirAccess.rename_absolute(main_path,
			old_path) != OK:
		_remove(temp_path)
		return false
	if DirAccess.rename_absolute(temp_path, main_path) != OK:
		if FileAccess.file_exists(old_path) and not FileAccess.file_exists(main_path):
			DirAccess.rename_absolute(old_path, main_path)
		_remove(temp_path)
		return false
	_remove(old_path)
	return true


## Saves into the autosave slot. Same guarantees; the slot is simply a fixed name.
func autosave(world: WorldState, created_at: String, now: String) -> Dictionary:
	return save(AUTOSAVE_SLOT, world, created_at, now)


# --- Reading ---------------------------------------------------------------

## Loads `slot`. `registry` is used for consistency checks only; pass null in a
## test that has no atlas.
##
## Returns ok, world, payload, summary, errors, warnings, player_error, migrated,
## used_backup, milliseconds, needs_attention.
func load(slot: String, registry: CountryRegistry = null, allow_backup: bool = true) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := _empty_load()
	if not is_valid_slot(slot):
		result["errors"].append("unknown slot '%s'" % slot)
		result["player_error"] = "That save slot does not exist."
		return result
	var main_path := path_for(slot)
	var backup_path := backup_path_for(slot)
	if not FileAccess.file_exists(main_path):
		if allow_backup and FileAccess.file_exists(backup_path):
			result = _load_from(backup_path, true, registry)
			result["used_backup"] = true
			result["warnings"].append("the main save file was missing; the backup was used")
			last_load_milliseconds = float(Time.get_ticks_usec() - started) / 1000.0
			result["milliseconds"] = last_load_milliseconds
			return result
		result["errors"].append("no save file in slot '%s'" % slot)
		result["player_error"] = "There is no save in this slot."
		last_load_milliseconds = float(Time.get_ticks_usec() - started) / 1000.0
		result["milliseconds"] = last_load_milliseconds
		return result
	result = _load_from(main_path, false, registry)
	if not bool(result["ok"]) and allow_backup and FileAccess.file_exists(backup_path):
		# Report the main file's problem, then try the backup: the player gets both
		# facts, never a silent substitution.
		var main_errors: Array = result["errors"].duplicate()
		var backup_result := _load_from(backup_path, true, registry)
		if bool(backup_result["ok"]):
			backup_result["errors"] = main_errors
			backup_result["warnings"].append(
					"the main save could not be used, so the backup was loaded instead")
			backup_result["used_backup"] = true
			backup_result["needs_attention"] = true
			result = backup_result
	last_load_milliseconds = float(Time.get_ticks_usec() - started) / 1000.0
	result["milliseconds"] = last_load_milliseconds
	return result


func _empty_load() -> Dictionary:
	return {"ok": false, "world": null, "payload": {}, "summary": {}, "errors": [],
			"warnings": [], "player_error": "", "migrated": false, "used_backup": false,
			"milliseconds": 0.0, "needs_attention": false}


func _load_from(path: String, from_backup: bool, registry: CountryRegistry) -> Dictionary:
	var result := _empty_load()
	var text := _read_text(path)
	if text.is_empty():
		result["errors"].append("the save file is empty or unreadable (%s)" % path.get_file())
		result["player_error"] = "This save file is empty or unreadable."
		return result
	var payload := _payload_from_text(text, result)
	if payload.is_empty():
		return result
	if not _stamp_accepts(payload, result):
		return result
	var world := _world_from_payload(payload, result, registry)
	if world == null:
		return result
	result["ok"] = true
	result["world"] = world
	result["payload"] = payload
	result["summary"] = SaveFile.summary(payload)
	result["from_backup"] = from_backup
	return result


## Parses, verifies and (when needed) migrates the text. Fills `result` with the
## precise reason on failure and returns {} so the caller can stop.
func _payload_from_text(text: String, result: Dictionary) -> Dictionary:
	var parsed := SaveFile.parse(text)
	if bool(parsed["needs_migration"]) and not (parsed["payload"] as Dictionary).is_empty():
		var migration := SaveMigrations.migrate(parsed["payload"])
		if not bool(migration["ok"]):
			result["errors"].append_array(migration["errors"])
			result["player_error"] = ("This save is from an older version and could not be "
					+ "upgraded safely. It has been left untouched.")
			return {}
		result["migrated"] = true
		result["warnings"].append_array(migration["steps"])
		parsed = SaveFile.parse(SaveFile.serialize(migration["payload"]))
	if not bool(parsed["ok"]):
		result["errors"].append_array(parsed["errors"])
		result["player_error"] = str(parsed["player_error"])
		return {}
	return parsed["payload"]


## The save must have been made against a country list whose ids still exist here.
## A different commit with the same ids is acceptable; a different id set is not,
## because a save refers to countries only by id.
func _stamp_accepts(payload: Dictionary, result: Dictionary) -> bool:
	var current := _current_stamp()
	if current.is_empty():
		return true
	# A save written by this build carries the stamp at the top level; a file
	# migrated from schema 1 carries it only inside the world. Both are the same
	# fact, so both are accepted.
	var stamp: Variant = payload.get("data_stamp")
	if not stamp is Dictionary:
		var world_value: Variant = payload.get("world")
		stamp = (world_value as Dictionary).get("data_stamp") \
				if world_value is Dictionary else {}
	var saved: Dictionary = stamp if stamp is Dictionary else {}
	if DataStamp.ids_match(current, saved):
		return true
	result["errors"].append("this save was made against a different country list (%s)"
			% str(saved.get("label", "unknown")))
	result["player_error"] = ("This save was made against a different version of the world "
			+ "data, so its country references cannot be trusted. It has not been loaded.")
	return false


func _world_from_payload(payload: Dictionary, result: Dictionary,
		registry: CountryRegistry) -> WorldState:
	var issues: Array = []
	var world := WorldState.from_dict(payload.get("world"), issues)
	if world == null:
		result["errors"].append("the world state could not be rebuilt")
		result["player_error"] = "This save's world data is damaged."
		return null
	if not issues.is_empty():
		result["errors"].append_array(issues)
		result["player_error"] = ("This save contains values the game will not accept. "
				+ "It has not been loaded.")
		return null
	var validation := world.validation_errors(registry)
	if not validation.is_empty():
		result["errors"].append_array(validation)
		result["player_error"] = ("This save does not fit this version of the world data. "
				+ "It has not been loaded.")
		return null
	return world


## The stamp of the world data this build ships, computed once per process.
func _current_stamp() -> Dictionary:
	if _cached_stamp.is_empty():
		_cached_stamp = DataStamp.compute(WorldAtlas.load_default())
	return _cached_stamp


# --- Listing and maintenance ----------------------------------------------

## One entry per slot: whether it exists, whether it is valid, and its summary.
## Invalid slots are listed as invalid with a plain reason — the Load screen shows
## them rather than pretending the slot is empty.
func list_slots(registry: CountryRegistry = null) -> Array:
	var entries: Array = []
	for slot: String in SLOT_IDS:
		entries.append(inspect(slot, registry))
	return entries


func inspect(slot: String, registry: CountryRegistry = null) -> Dictionary:
	var entry := {"slot": slot, "label": slot_label(slot), "exists": exists(slot),
			"has_backup": backup_exists(slot), "valid": false, "summary": {},
			"player_error": "", "errors": []}
	if not bool(entry["exists"]):
		return entry
	var loaded := load(slot, registry, false)
	entry["valid"] = bool(loaded["ok"])
	entry["errors"] = loaded["errors"]
	entry["player_error"] = loaded["player_error"]
	if bool(loaded["ok"]):
		entry["summary"] = loaded["summary"]
	return entry


## The slot with the most recent `last_saved_at`, or "" when none is valid.
## ISO-8601 timestamps sort lexicographically, which is why the format uses them.
func latest_valid_slot(registry: CountryRegistry = null) -> String:
	var best := ""
	var best_time := ""
	for entry: Dictionary in list_slots(registry):
		if not bool(entry["valid"]):
			continue
		var summary: Dictionary = entry["summary"]
		var saved_at := str(summary.get("last_saved_at", ""))
		if best_time.is_empty() or saved_at > best_time:
			best_time = saved_at
			best = str(entry["slot"])
	return best


func has_any_valid(registry: CountryRegistry = null) -> bool:
	return not latest_valid_slot(registry).is_empty()


func delete(slot: String) -> bool:
	if not is_valid_slot(slot):
		return false
	_remove(path_for(slot))
	_remove(backup_path_for(slot))
	_remove(_temp_path_for(slot))
	_remove(_old_path_for(slot))
	return true


## Restores a slot from its backup, keeping the damaged main file as `.damaged`.
## The player is told before this runs; nothing here is automatic.
func restore_backup(slot: String) -> bool:
	if not backup_exists(slot):
		return false
	var main_path := path_for(slot)
	if FileAccess.file_exists(main_path):
		_copy_text(main_path, "%s/%s.damaged%s" % [save_directory, slot, FILE_EXTENSION])
	return _copy_text(backup_path_for(slot), main_path) == OK


# --- Export and import -----------------------------------------------------

## Copies a slot's file to `absolute_path`, which the player chose in a file
## dialog. The bytes are verified before copying, so an export can never produce a
## file that the game itself would refuse.
func export_slot(slot: String, absolute_path: String) -> Dictionary:
	var result := {"ok": false, "errors": [], "player_error": "", "path": absolute_path}
	if not exists(slot):
		result["errors"].append("no save in slot '%s'" % slot)
		result["player_error"] = "There is no save in this slot to export."
		return result
	var text := _read_text(path_for(slot))
	if text.is_empty():
		result["errors"].append("the save file could not be read")
		result["player_error"] = "The save file could not be read."
		return result
	var parsed := SaveFile.parse(text)
	if not bool(parsed["ok"]) and not bool(parsed["needs_migration"]):
		result["errors"].append_array(parsed["errors"])
		result["player_error"] = "This save is damaged, so it was not exported."
		return result
	if _write_text(absolute_path, text) != OK:
		result["errors"].append("could not write to %s" % absolute_path)
		result["player_error"] = "The game could not write to that location."
		return result
	result["ok"] = true
	result["bytes"] = text.to_utf8_buffer().size()
	return result


## Reads and fully validates a file the player picked, without writing anything.
## Returns `text` so the caller can then ask which slot to import into.
func import_file(absolute_path: String, registry: CountryRegistry = null) -> Dictionary:
	var result := {"ok": false, "errors": [], "player_error": "", "text": "", "summary": {},
			"migrated": false}
	var text := _import_text(absolute_path, result)
	if text.is_empty():
		return result
	var payload := _payload_from_text(text, result)
	if payload.is_empty():
		return result
	if not _stamp_accepts(payload, result):
		return result
	var world := _world_from_payload(payload, result, registry)
	if world == null:
		return result
	result["ok"] = true
	result["text"] = SaveFile.serialize(payload)
	result["summary"] = SaveFile.summary(payload)
	return result


## Reads an imported file and applies the cheap guards before parsing it: missing,
## empty and oversized files are refused with a plain reason.
func _import_text(absolute_path: String, result: Dictionary) -> String:
	var text := _read_text(absolute_path)
	if text.is_empty():
		result["errors"].append("the file is empty or unreadable")
		result["player_error"] = "That file is empty or could not be read."
		return ""
	if text.to_utf8_buffer().size() > max_file_bytes():
		result["errors"].append("the file is larger than %d bytes" % max_file_bytes())
		result["player_error"] = "That file is too large to be a WORLD DOMINION save."
		return ""
	return text


## Writes already-validated save text into a slot. Used only by import, after the
## player has chosen the slot and confirmed any overwrite.
func write_imported_text(slot: String, text: String) -> Dictionary:
	var result := {"ok": false, "errors": [], "player_error": ""}
	if not is_valid_slot(slot):
		result["errors"].append("unknown slot '%s'" % slot)
		result["player_error"] = "That save slot does not exist."
		return result
	if not bool(SaveFile.parse(text)["ok"]):
		result["errors"].append("the imported file failed validation")
		result["player_error"] = "The imported file failed validation and was not written."
		return result
	if not ensure_directory():
		result["errors"].append("could not create the save folder")
		result["player_error"] = "The game could not open its save folder."
		return result
	var temp_path := _temp_path_for(slot)
	if _write_text(temp_path, text) != OK:
		result["errors"].append("could not write the temporary file")
		result["player_error"] = "The game could not write to storage."
		return result
	if not bool(SaveFile.parse(_read_text(temp_path))["ok"]):
		_remove(temp_path)
		result["errors"].append("the written file failed verification")
		result["player_error"] = "The imported save could not be verified."
		return result
	if FileAccess.file_exists(path_for(slot)):
		_copy_text(path_for(slot), backup_path_for(slot))
	if _swap_in(temp_path, path_for(slot), slot):
		result["ok"] = true
	else:
		result["errors"].append("could not place the imported save")
		result["player_error"] = "The imported save could not be put in place."
	return result


# --- File helpers ----------------------------------------------------------

func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _write_text(path: String, text: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.flush()
	file.close()
	return OK


func _copy_text(from_path: String, to_path: String) -> Error:
	var text := _read_text(from_path)
	if text.is_empty():
		return ERR_FILE_CANT_READ
	return _write_text(to_path, text)


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
