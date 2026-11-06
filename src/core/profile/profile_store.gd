class_name ProfileStore
extends RefCounted
## Reading and writing the one profile file, with the same care as a world save.
##
## The rules come from docs/SECURITY.md and are enforced here rather than promised there:
##
##   * **atomic writes.** The new file is written to a temporary path, read back and
##     checked, and only then swapped in. A write that fails or is interrupted leaves the
##     previous profile exactly as it was.
##   * **a rolling backup.** The previous profile is kept as `profile.old.json` on every
##     successful save, so a bad write costs at most the most recent change.
##   * **validation on load.** The file is parsed into typed values with explicit checks
##     (see PlayerProfile.from_dict); something malformed is repaired and reported, never
##     silently accepted and never silently deleted.
##   * **no destructive recovery.** A profile that cannot be read is left on disk. The
##     store falls back to the backup, and if that fails too it says so and creates a new
##     profile without touching either file.
##
## There is no encryption and no anti-tamper promise. A file on the player's own device is
## the player's own business; the checksum here catches corruption and casual edits, and
## docs/SECURITY.md says exactly that.

const FORMAT_ID := "world-dominion-profile"
const PATH := "user://profile.json"
const BACKUP_PATH := "user://profile.old.json"
const TEMP_PATH := "user://profile.tmp.json"

var _path: String
var _backup_path: String
var _temp_path: String


func _init(path: String = PATH) -> void:
	_path = path
	_backup_path = path.get_basename() + ".old.json"
	_temp_path = path.get_basename() + ".tmp.json"


func path() -> String:
	return _path


func backup_path() -> String:
	return _backup_path


func exists() -> bool:
	return FileAccess.file_exists(_path)


func backup_exists() -> bool:
	return FileAccess.file_exists(_backup_path)


## Write the profile. Returns {ok, error}; on failure the previous file is untouched.
func save(profile: PlayerProfile) -> Dictionary:
	var body := profile.to_dict()
	var envelope := {
		"format": FORMAT_ID,
		"schema_version": PlayerProfile.SCHEMA_VERSION,
		"checksum": CanonicalJson.sha256(body),
		"profile": body,
	}
	var text := CanonicalJson.stringify(envelope, [])
	if text.is_empty():
		return {"ok": false, "error": "The profile could not be serialised."}
	var staged := _stage(text)
	if not str(staged).is_empty():
		return {"ok": false, "error": staged}
	var installed := _install()
	if not installed.is_empty():
		return {"ok": false, "error": installed}
	return {"ok": true, "error": ""}


## Write the text to the temporary path and read it back. Returns "" on success, or a
## plain-language error.
func _stage(text: String) -> String:
	var temp := FileAccess.open(_temp_path, FileAccess.WRITE)
	if temp == null:
		return "The profile could not be written (%s)." % error_string(FileAccess.get_open_error())
	temp.store_string(text)
	temp.close()
	# Read the temporary file back before it replaces anything: a write that did not
	# survive the trip to disk must not become the player's profile.
	if FileAccess.get_file_as_string(_temp_path) != text:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_temp_path))
		return "The profile write did not verify and was discarded."
	return ""


## Move the staged file into place, setting the previous one aside. Returns "" on success.
func _install() -> String:
	var directory := DirAccess.open(ProjectSettings.globalize_path(_path).get_base_dir())
	if directory == null:
		return "The profile folder could not be opened."
	var absolute_temp := ProjectSettings.globalize_path(_temp_path)
	var absolute_main := ProjectSettings.globalize_path(_path)
	var absolute_backup := ProjectSettings.globalize_path(_backup_path)
	if FileAccess.file_exists(_path):
		if directory.file_exists(absolute_backup):
			directory.remove(absolute_backup)
		if directory.rename(absolute_main, absolute_backup) != OK:
			directory.remove(absolute_temp)
			return "The previous profile could not be set aside."
	if directory.rename(absolute_temp, absolute_main) != OK:
		return "The new profile could not be put in place."
	return ""


## Load the profile, or make one. `source` is "main", "backup" or "new" so the interface
## can tell the player which file it used. Anything repaired is in `problems`.
func load_or_create(seed_value: int, today: String) -> Dictionary:
	var result := {
		"ok": true, "profile": null, "source": "new",
		"problems": PackedStringArray(), "error": "",
	}
	var main := _read(_path)
	if main["ok"]:
		result["profile"] = main["profile"]
		result["source"] = "main"
		result["problems"] = main["problems"]
		return result

	# The main file is missing or unreadable. Say why, then try the rolling backup.
	var reasons := PackedStringArray()
	if not str(main["error"]).is_empty():
		reasons.append(str(main["error"]))
	var backup := _read(_backup_path)
	if backup["ok"]:
		result["profile"] = backup["profile"]
		result["source"] = "backup"
		reasons.append("The profile was restored from the previous copy. Anything "
				+ "changed since the last save was not kept.")
		for problem: String in backup["problems"]:
			reasons.append(problem)
		result["problems"] = reasons
		return result

	# Nothing readable. Do not delete anything: a file we cannot parse may still be the
	# only copy of something, and the owner of this device can look at it.
	var fresh := PlayerProfile.create(seed_value, today)
	if exists():
		reasons.append("The profile file could not be read and was left in place; a new "
				+ "profile was started. The old file is still on this device.")
	result["profile"] = fresh
	result["source"] = "new"
	result["problems"] = reasons
	return result


## Parse one file. Returns {ok, profile, problems, error}.
func _read(path: String) -> Dictionary:
	var failure := {"ok": false, "profile": null, "problems": PackedStringArray(),
			"error": ""}
	if not FileAccess.file_exists(path):
		failure["error"] = "No profile file was found."
		return failure
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		failure["error"] = "The profile file was empty."
		return failure
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		failure["error"] = "The profile file is not readable."
		return failure
	var envelope: Dictionary = parsed
	if str(envelope.get("format", "")) != FORMAT_ID:
		failure["error"] = "The file is not a World Dominion profile."
		return failure
	var body: Variant = envelope.get("profile")
	if not (body is Dictionary):
		failure["error"] = "The profile file has no profile in it."
		return failure
	var problems := PackedStringArray()
	var stored_checksum := str(envelope.get("checksum", ""))
	if not stored_checksum.is_empty() and stored_checksum != CanonicalJson.sha256(body):
		problems.append("The profile did not match its own checksum. It was read as "
				+ "written, with a warning; nothing was reset.")
	var profile := PlayerProfile.from_dict(body)
	for problem: String in profile.problems:
		problems.append(problem)
	return {"ok": true, "profile": profile, "problems": problems, "error": ""}
