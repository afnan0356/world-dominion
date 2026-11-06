class_name SaveFile
extends RefCounted
## The save format: build it, parse it, verify it. No file access here.
##
## A save is one UTF-8 JSON document. Human-readable on purpose: a player can open
## it in a text editor, a reviewer can diff two of them, and a corrupted file can
## be understood instead of guessed at.
##
## THE SHAPE (schema 2)
##
##     {
##       "format": "world-dominion-save",
##       "schema_version": 2,
##       "game_version": "0.2.0",
##       "created_at": "2026-11-05T10:00:00Z",
##       "last_saved_at": "2026-11-05T10:12:00Z",
##       "slot": 2,
##       "playtime_seconds": 812.5,
##       "scenario_id": "modern_world_2026",
##       "player_country_id": "BGD",
##       "data_stamp": { … },
##       "state_hash": "…sha256 of the world state…",
##       "world": { …WorldState.to_dict()… },
##       "checksum": "…sha256 of every other field…"
##     }
##
## Two independent integrity checks, because they answer different questions:
##
## * `state_hash` answers "is this the same campaign state?" — it is what
##   determinism tests compare, and what detects a state edited by hand.
## * `checksum` answers "was this file changed after the game wrote it?" — it
##   covers every other field, including the timestamps and the slot number.
##
## The checksum is computed over the *canonical* form (sorted keys, integers kept
## distinct from floats) so that a file that has been pretty-printed or re-ordered
## by an editor still verifies.
##
## WHAT A SAVE DOES NOT CONTAIN: map geometry, the registry, country names for every
## country, or any statistic the game does not have. Country state is keyed by
## stable id and resolved against the shipped registry on load.

const FORMAT_ID := "world-dominion-save"
const SCHEMA_VERSION := 2
## Refuse anything above this: a newer build may have written a shape this one
## cannot safely read, and guessing would risk damaging a player's campaign.
const MIN_SUPPORTED_SCHEMA := 1
const FORMAT_KEY := "format"
const CHECKSUM_KEY := "checksum"
const STATE_HASH_KEY := "state_hash"


## Builds the payload for `world`. `slot` and the timestamps are bookkeeping, not
## game state, and are excluded from the state hash on purpose.
static func build(world: WorldState, slot: String, created_at: String,
		now: String) -> Dictionary:
	var payload := {
		"format": FORMAT_ID,
		"schema_version": SCHEMA_VERSION,
		"game_version": world.game_version,
		"created_at": created_at,
		"last_saved_at": now,
		"slot": slot,
		"playtime_seconds": world.playtime_seconds,
		"scenario_id": world.scenario_id,
		"player_country_id": world.player_country_id,
		"player_country_name": world.player_country_name,
		"data_stamp": world.data_stamp.duplicate(true),
		STATE_HASH_KEY: world.state_hash(),
		"world": world.to_dict(),
	}
	# The signature covers the body but not itself, and the checksum covers both, so
	# removing the signature in a hand edit is itself detectable.
	payload[IntegritySignature.SIGNATURE_KEY] = IntegritySignature.sign(signed_body(payload))
	payload[CHECKSUM_KEY] = checksum_of(payload)
	return payload


## The part of a payload the signature covers: everything except the two derived fields.
static func signed_body(payload: Dictionary) -> Dictionary:
	var copy: Dictionary = payload.duplicate(true)
	copy.erase(CHECKSUM_KEY)
	copy.erase(IntegritySignature.SIGNATURE_KEY)
	return copy


static func checksum_of(payload: Dictionary) -> String:
	var copy: Dictionary = payload.duplicate(true)
	copy.erase(CHECKSUM_KEY)
	var errors: Array = []
	# A payload read back from JSON holds floats where it was written with ints;
	# normalising makes the digest depend on the values, not on the round trip.
	var digest := CanonicalJson.sha256(CanonicalJson.normalise_numbers(copy), errors)
	if digest.is_empty():
		return ""
	return digest


## Serialises a built payload. Returns "" when the payload cannot be represented
## exactly (NaN, infinity, unsupported type) — writing a lossy save is worse than
## refusing to write one.
static func serialize(payload: Dictionary) -> String:
	var errors: Array = []
	var text := CanonicalJson.stringify(payload, errors)
	if not errors.is_empty():
		push_error("SaveFile: refusing to serialise a payload (%s)." % str(errors))
		return ""
	return text


## Parses and verifies `text`. Never throws and never returns a half-valid save:
## `ok` is false unless the format, the schema and the checksum all pass.
##
## Returns:
##   ok           — true when the file may be used
##   payload      — the parsed dictionary (present even when verification failed,
##                  for diagnostics; do not use it to load a game)
##   errors       — precise, developer-facing messages
##   player_error — one plain-language sentence for the player, or ""
##   newer        — true when the file is from a newer schema than this build
static func parse(text: String) -> Dictionary:
	var result := {"ok": false, "payload": {}, "errors": [], "player_error": "",
			"newer": false, "needs_migration": false,
			"signature_status": IntegritySignature.STATUS_MISSING}
	var errors: Array = result["errors"]
	if text.strip_edges().is_empty():
		errors.append("the file is empty")
		result["player_error"] = "This save file is empty, so there is nothing to load."
		return result
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		errors.append("the file is not a JSON object")
		result["player_error"] = ("This file is not a WORLD DOMINION save. "
				+ "It may be damaged or from another game.")
		return result
	var payload: Dictionary = parsed
	result["payload"] = payload
	if str(payload.get(FORMAT_KEY, "")) != FORMAT_ID:
		errors.append("the 'format' field is not '%s'" % FORMAT_ID)
		result["player_error"] = ("This file is not a WORLD DOMINION save. "
				+ "It may be damaged or from another game.")
		return result
	var schema: Variant = CanonicalJson.int_value(payload.get("schema_version"))
	if schema == null:
		errors.append("schema_version is missing or is not an integer")
		result["player_error"] = ("This save does not say which version it was made with, "
				+ "so it cannot be loaded safely.")
		return result
	var version := int(schema)
	if version > SCHEMA_VERSION:
		errors.append("save schema %d is newer than this build's %d" % [version, SCHEMA_VERSION])
		result["newer"] = true
		result["player_error"] = ("This save was made by a newer version of the game "
				+ "(format %d; this build understands up to %d). It has been left untouched. "
				+ "Update the game to load it.") % [version, SCHEMA_VERSION]
		return result
	if version < MIN_SUPPORTED_SCHEMA:
		errors.append("save schema %d is older than the oldest supported %d"
				% [version, MIN_SUPPORTED_SCHEMA])
		result["player_error"] = ("This save is too old to be upgraded safely. "
				+ "It has been left untouched.")
		return result
	if not payload.get("world") is Dictionary:
		errors.append("the 'world' section is missing or is not an object")
		result["player_error"] = "This save is damaged: its world data is missing."
		return result
	if not payload.get(CHECKSUM_KEY) is String or str(payload.get(CHECKSUM_KEY)).is_empty():
		errors.append("the checksum is missing")
		result["player_error"] = ("This save has no checksum, so the game cannot tell whether "
				+ "it is complete. It may have been copied incompletely.")
		return result
	var stored := str(payload.get(CHECKSUM_KEY))
	var computed := checksum_of(payload)
	if computed.is_empty():
		errors.append("the payload contains a value that cannot be checksummed")
		result["player_error"] = "This save contains values the game cannot read."
		return result
	if stored != computed:
		errors.append("checksum mismatch (stored %s…, computed %s…)"
				% [stored.substr(0, 8), computed.substr(0, 8)])
		result["player_error"] = ("This save file has been changed or damaged since it was "
				+ "written, so it cannot be trusted. A backup may still work.")
		return result
	# Integrity signature (Milestone 06, Task H). A mismatch never fails the load on its
	# own: it is reported, and the interface offers the player a choice. A file written
	# before signatures existed is reported as unsigned, not as broken.
	result["signature_status"] = IntegritySignature.verify(signed_body(payload),
			str(payload.get(IntegritySignature.SIGNATURE_KEY, "")))
	if str(result["signature_status"]) == IntegritySignature.STATUS_FAILED:
		errors.append("the integrity signature does not match the file")
		result["player_error"] = IntegritySignature.describe(IntegritySignature.STATUS_FAILED) \
				+ " You can load it with a warning, or restore a backup."
	if version < SCHEMA_VERSION:
		# The file is intact but written in an older shape. It is not usable as-is:
		# the caller must migrate it and then verify the migrated payload, so that a
		# migration can never smuggle in a state that was never checksummed.
		result["needs_migration"] = true
		return result
	var world: Dictionary = payload["world"]
	var hash_ok := _verify_state_hash(world, str(payload.get(STATE_HASH_KEY, "")))
	if not hash_ok:
		errors.append("the world state hash does not match the stored hash")
		result["player_error"] = ("This save's world data does not match its own fingerprint, "
				+ "so it was edited or damaged. A backup may still work.")
		return result
	result["ok"] = true
	return result


static func _verify_state_hash(world: Dictionary, stored: String) -> bool:
	if stored.is_empty():
		return false
	var issues: Array = []
	var state := WorldState.from_dict(world, issues)
	if state == null:
		return false
	return state.state_hash() == stored


## Convenience for the UI: a summary read from a payload that parsed successfully.
static func summary(payload: Dictionary) -> Dictionary:
	var world: Variant = payload.get("world")
	var stamp: Variant = payload.get("data_stamp")
	if not stamp is Dictionary and world is Dictionary:
		stamp = (world as Dictionary).get("data_stamp")
	var stamp_label := ""
	if stamp is Dictionary:
		stamp_label = str((stamp as Dictionary).get("label", ""))
	var date_label := ""
	var speed := 0
	var seed_value := 0
	if world is Dictionary:
		var clock: Variant = (world as Dictionary).get("clock")
		var day: Variant = CanonicalJson.int_value((clock as Dictionary).get("day_index")) \
				if clock is Dictionary else null
		if day != null:
			date_label = GameDate.from_day_index(int(day)).format_long()
		var saved_speed: Variant = CanonicalJson.int_value((clock as Dictionary).get("speed")) \
				if clock is Dictionary else null
		speed = int(saved_speed) if saved_speed != null else 0
		var saved_seed: Variant = CanonicalJson.int_value((world as Dictionary).get("seed"))
		seed_value = int(saved_seed) if saved_seed != null else 0
	return {
		"slot": str(payload.get("slot", "")),
		"scenario_id": str(payload.get("scenario_id", "")),
		"player_country_id": str(payload.get("player_country_id", "")),
		"player_country_name": str(payload.get("player_country_name", "")),
		"date_label": date_label,
		"speed": speed,
		"seed": seed_value,
		"playtime_seconds": float(payload.get("playtime_seconds", 0.0)),
		"last_saved_at": str(payload.get("last_saved_at", "")),
		"created_at": str(payload.get("created_at", "")),
		"game_version": str(payload.get("game_version", "")),
		"data_stamp": stamp_label,
		"schema_version": int(CanonicalJson.int_value(payload.get("schema_version", 0)) or 0),
	}
