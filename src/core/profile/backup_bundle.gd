class_name BackupBundle
extends RefCounted
## One file that holds everything a player would hate to lose: the profile and every world.
##
## FORMAT: plain JSON, on purpose. A backup the player cannot open in a text editor is a
## backup they have to trust; this project would rather be inspectable. The file carries a
## version, a plain-language label, a checksum and an integrity signature, and the restore
## path validates all of it before touching anything on disk.
##
## THE THREE PROMISES OF RESTORE:
##   1. **Nothing is overwritten without confirmation.** The caller passes
##      `overwrite_confirmed`; without it, existing worlds are reported and left alone.
##   2. **You can take everything or choose worlds.** `mode` is "all" or "choose" with an
##      explicit slot list.
##   3. **No invented data.** A world in the bundle that cannot be validated is listed as
##      rejected; a slot that is not in the bundle is not created out of nothing.
##
## WHAT IS NOT HERE: any network path, any account, any cloud. A backup is a file the
## player chooses where to put, using their own device's file handling.

const FORMAT_ID := "world-dominion-backup"
const SCHEMA_VERSION := 1
const CHECKSUM_KEY := "checksum"

const STATUS_OK := "ok"
const STATUS_MISSING := "missing"
const STATUS_FAILED := "failed"


## Build a bundle document from a profile and a set of world save texts.
## `worlds` maps a slot label to the *exact* text of that world's save file, so a restore
## can put the file back byte for byte rather than re-serialising it.
static func build(profile: PlayerProfile, worlds: Dictionary, created_at: String,
		label: String) -> Dictionary:
	var world_block := {}
	var summaries: Array = []
	for slot: String in worlds:
		world_block[slot] = {"text": str(worlds[slot])}
		var parsed: Dictionary = SaveFile.parse(str(worlds[slot]))
		if bool(parsed["ok"]):
			var summary: Dictionary = SaveFile.summary(parsed["payload"])
			summary["slot"] = slot
			summaries.append(summary)
	var body := {
		"format": FORMAT_ID,
		"schema_version": SCHEMA_VERSION,
		"created_at": created_at,
		"label": label,
		"profile": profile.to_dict(),
		"worlds": world_block,
		"world_summaries": summaries,
	}
	return {
		"format": FORMAT_ID,
		"schema_version": SCHEMA_VERSION,
		"created_at": created_at,
		"label": label,
		CHECKSUM_KEY: body_digest(body),
		IntegritySignature.SIGNATURE_KEY: IntegritySignature.signature_of(body),
		"body": body,
	}


## The digest of a bundle body. Numbers are normalised first: a body read back from JSON
## holds floats where it was written with ints, and a checksum that depended on the round
## trip would call every backup tampered with.
static func body_digest(body: Dictionary) -> String:
	return CanonicalJson.sha256(CanonicalJson.normalise_numbers(body))


static func serialize(bundle: Dictionary) -> String:
	var errors: Array = []
	var text: String = CanonicalJson.stringify(bundle, errors)
	if not errors.is_empty():
		push_error("BackupBundle: refusing to serialise a bundle (%s)." % str(errors))
		return ""
	return text


## Read a bundle without touching disk. Returns:
##   ok              — every check passed
##   body            — the payload (present when the structure is readable)
##   summary         — what the player sees before choosing: label, date, profile name,
##                     level, and one line per world
##   problems        — plain-language sentences, one per issue
##   checksum_status — "ok" / "missing"(older format) / "failed"
##   signature_status — "ok" / "missing" / "failed"
static func inspect(text: String) -> Dictionary:
	var result := {
		"ok": false, "body": {}, "summary": {}, "problems": PackedStringArray(),
		"checksum_status": STATUS_MISSING, "signature_status": STATUS_MISSING,
	}
	var problems: PackedStringArray = result["problems"]
	if text.strip_edges().is_empty():
		problems.append("The file is empty, so there is nothing to restore.")
		return result
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		problems.append("The file is not readable as a backup. It may be damaged.")
		return result
	var document: Dictionary = parsed
	if str(document.get("format", "")) != FORMAT_ID:
		problems.append("This file is not a WORLD DOMINION backup.")
		return result
	var version := int(document.get("schema_version", 0))
	if version > SCHEMA_VERSION:
		problems.append("This backup was made by a newer version of the game "
				+ "(format %d; this build understands up to %d). Nothing was changed."
				% [version, SCHEMA_VERSION])
		return result
	if version < 1:
		problems.append("This backup does not say which version it was made with.")
		return result
	var body: Variant = document.get("body")
	if not (body is Dictionary):
		problems.append("The backup has no contents.")
		return result
	result["body"] = body
	var body_dict: Dictionary = body

	var stored_checksum := str(document.get(CHECKSUM_KEY, ""))
	if stored_checksum.is_empty():
		problems.append("The backup has no checksum, so its contents cannot be verified.")
	else:
		if stored_checksum == body_digest(body_dict):
			result["checksum_status"] = STATUS_OK
		else:
			result["checksum_status"] = STATUS_FAILED
			problems.append("The backup's checksum does not match its contents: the file "
					+ "has been changed or damaged since it was made.")

	var signature_status: String = IntegritySignature.verify(body_dict,
			str(document.get(IntegritySignature.SIGNATURE_KEY, "")))
	result["signature_status"] = signature_status
	if signature_status == IntegritySignature.STATUS_FAILED:
		problems.append(IntegritySignature.describe(signature_status))

	var profile_body: Variant = body_dict.get("profile")
	if not (profile_body is Dictionary):
		problems.append("The backup contains no player profile.")
	else:
		var profile: PlayerProfile = PlayerProfile.from_dict(profile_body)
		for problem: String in profile.problems:
			problems.append(problem)

	var summary := {
		"label": str(document.get("label", "")),
		"created_at": str(document.get("created_at", "")),
		"player_name": "",
		"level": 0,
		"worlds": [],
	}
	if profile_body is Dictionary:
		var profile: PlayerProfile = PlayerProfile.from_dict(profile_body)
		summary["player_name"] = profile.display_name
		summary["level"] = profile.level()
	var worlds: Variant = body_dict.get("worlds")
	if worlds is Dictionary:
		for slot: String in worlds:
			var entry: Variant = (worlds as Dictionary)[slot]
			var text_value := ""
			if entry is Dictionary:
				text_value = str((entry as Dictionary).get("text", ""))
			var parsed_world: Dictionary = SaveFile.parse(text_value)
			var line := {
				"slot": slot, "valid": bool(parsed_world["ok"]), "country": "",
				"date": "", "playtime_seconds": 0.0, "last_saved_at": "",
			}
			if bool(parsed_world["ok"]):
				var world_summary: Dictionary = SaveFile.summary(parsed_world["payload"])
				line["country"] = str(world_summary.get("player_country_name", ""))
				line["date"] = str(world_summary.get("date_label", ""))
				line["playtime_seconds"] = float(world_summary.get("playtime_seconds", 0.0))
				line["last_saved_at"] = str(world_summary.get("last_saved_at", ""))
			else:
				problems.append("The world in slot \"%s\" cannot be read and would be "
						% slot + "skipped.")
			(summary["worlds"] as Array).append(line)
	result["summary"] = summary
	result["ok"] = result["checksum_status"] != STATUS_FAILED \
			and result["signature_status"] != STATUS_FAILED \
			and not (profile_body is Dictionary) == false
	return result


## Restore worlds from an inspected bundle. Returns:
##   ok        — the restore ran (individual worlds may still have been skipped)
##   restored  — slot labels written
##   skipped   — slot labels left alone, with the reason in `reasons`
##   reasons   — plain-language sentences, one per skip or problem
##   profile   — the PlayerProfile from the bundle, for the caller to install
static func restore(document: Dictionary, save_store: SaveStore, mode: String,
		slots: Array, overwrite_confirmed: bool) -> Dictionary:
	var result := {
		"ok": false, "restored": [], "skipped": [], "reasons": PackedStringArray(),
		"profile": null,
	}
	var reasons: PackedStringArray = result["reasons"]
	var body: Variant = document.get("body")
	if not (body is Dictionary):
		reasons.append("There is nothing in this backup to restore.")
		return result
	var body_dict: Dictionary = body
	var profile_body: Variant = body_dict.get("profile")
	if profile_body is Dictionary:
		result["profile"] = PlayerProfile.from_dict(profile_body)
	else:
		reasons.append("The backup has no player profile; only worlds can be restored.")

	var worlds: Variant = body_dict.get("worlds")
	if not (worlds is Dictionary):
		reasons.append("The backup has no worlds in it.")
		result["ok"] = true
		return result

	var wanted: Array = []
	if mode == "all":
		wanted = (worlds as Dictionary).keys()
	elif mode == "choose":
		for slot: Variant in slots:
			if (worlds as Dictionary).has(str(slot)):
				wanted.append(str(slot))
			else:
				reasons.append("Slot \"%s\" is not in this backup." % str(slot))
	else:
		reasons.append("Unknown restore mode \"%s\"." % mode)
		return result

	save_store.ensure_directory()
	for slot: String in wanted:
		var entry: Variant = (worlds as Dictionary)[slot]
		var text_value := ""
		if entry is Dictionary:
			text_value = str((entry as Dictionary).get("text", ""))
		var parsed: Dictionary = SaveFile.parse(text_value)
		if not bool(parsed["ok"]):
			(result["skipped"] as Array).append(slot)
			reasons.append("The world in slot \"%s\" could not be validated and was not "
					% slot + "restored.")
			continue
		if save_store.exists(slot) and not overwrite_confirmed:
			(result["skipped"] as Array).append(slot)
			reasons.append("The world in slot \"%s\" is already on this device; it was left "
					% slot + "alone because overwriting was not confirmed.")
			continue
		var written := save_store.write_raw(slot, text_value)
		if bool(written["ok"]):
			(result["restored"] as Array).append(slot)
		else:
			(result["skipped"] as Array).append(slot)
			reasons.append("The world in slot \"%s\" could not be written: %s"
					% [slot, str(written["error"])])
	result["ok"] = true
	return result


## Write a bundle to a file atomically. Returns {ok, error, path}.
static func write_file(bundle: Dictionary, path: String) -> Dictionary:
	var text := serialize(bundle)
	if text.is_empty():
		return {"ok": false, "error": "The backup could not be serialised.", "path": path}
	var temp := path + ".tmp"
	var handle := FileAccess.open(temp, FileAccess.WRITE)
	if handle == null:
		return {"ok": false, "error": "The backup file could not be created (%s)."
				% error_string(FileAccess.get_open_error()), "path": path}
	handle.store_string(text)
	handle.close()
	if FileAccess.get_file_as_string(temp) != text:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
		return {"ok": false, "error": "The backup did not verify after writing.",
				"path": path}
	var directory := DirAccess.open(ProjectSettings.globalize_path(path).get_base_dir())
	if directory == null:
		return {"ok": false, "error": "The backup folder could not be opened.", "path": path}
	if directory.file_exists(ProjectSettings.globalize_path(path)):
		directory.remove(ProjectSettings.globalize_path(path))
	if directory.rename(ProjectSettings.globalize_path(temp),
			ProjectSettings.globalize_path(path)) != OK:
		return {"ok": false, "error": "The backup could not be put in place.", "path": path}
	return {"ok": true, "error": "", "path": path}
