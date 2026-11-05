class_name SaveMigrations
extends RefCounted
## Upgrades an older save to the current shape, one version at a time.
##
## Rules, in order of importance:
##
## 1. **Never guess.** A migration moves data that is present and adds only fields
##    whose value can be derived exactly. Anything missing that a field needs is
##    reported, and the caller refuses the file rather than inventing a value.
## 2. **Never migrate downward.** A file newer than this build is refused, kept
##    untouched and explained to the player (see SaveFile.parse()).
## 3. **One step per version.** Schema 1 → 2 is one function. When schema 3
##    arrives, schema 1 will run 1 → 2 → 3 in order, so each step stays small and
##    testable on its own.
##
## What changed in 1 → 2 (this milestone's own earlier draft, kept supported so
## that anyone who played that build keeps their campaign):
##
## * the wallet moved from the top level into `world.wallet`;
## * the data stamp moved from the top level into `world.data_stamp`;
## * random-stream positions became explicit (`world.streams`, empty when absent);
## * the file gained a `format` marker and a `state_hash`.
##
## The checksum was already present in schema 1, so a migrated file is verified
## again from scratch afterwards — a migration cannot launder a damaged file.

const CURRENT := SaveFile.SCHEMA_VERSION


## Migrates `payload` in place-by-copy. Returns:
##   ok      — true when the payload is now at CURRENT
##   payload — the migrated payload (with a fresh checksum), or the input on failure
##   steps   — human-readable list of the migrations applied, for the log
##   errors  — precise reasons a step could not be applied
static func migrate(payload: Dictionary) -> Dictionary:
	var result := {"ok": false, "payload": payload, "steps": [], "errors": []}
	var errors: Array = result["errors"]
	var steps: Array = result["steps"]
	var schema: Variant = CanonicalJson.int_value(payload.get("schema_version"))
	if schema == null:
		errors.append("no integer schema_version to migrate")
		return result
	var version := int(schema)
	if version > CURRENT:
		errors.append("schema %d is newer than %d and is never migrated downward"
				% [version, CURRENT])
		return result
	if version == CURRENT:
		result["ok"] = true
		return result
	var working := payload.duplicate(true)
	var guard := 0
	while version < CURRENT:
		guard += 1
		if guard > 16:
			errors.append("migration did not converge")
			return result
		var step := _step(version, working)
		if not bool(step["ok"]):
			errors.append(str(step["error"]))
			return result
		working = step["payload"]
		steps.append(str(step["note"]))
		version += 1
	working["schema_version"] = CURRENT
	working.erase(SaveFile.CHECKSUM_KEY)
	working[SaveFile.CHECKSUM_KEY] = SaveFile.checksum_of(working)
	result["payload"] = working
	result["ok"] = true
	return result


static func _step(from_version: int, payload: Dictionary) -> Dictionary:
	match from_version:
		1:
			return _v1_to_v2(payload)
		_:
			return {"ok": false, "payload": payload,
					"error": "no migration defined from schema %d" % from_version}


static func _v1_to_v2(payload: Dictionary) -> Dictionary:
	var world_value: Variant = payload.get("world")
	if not world_value is Dictionary:
		return {"ok": false, "payload": payload, "error": "schema 1 save has no world object"}
	var world: Dictionary = (world_value as Dictionary).duplicate(true)
	# The wallet was a top-level object in schema 1; it becomes part of the world,
	# because it is campaign state that must be validated with the rest of it.
	if payload.has("wallet") and not world.has("wallet"):
		world["wallet"] = payload["wallet"]
	if not world.has("wallet"):
		return {"ok": false, "payload": payload,
				"error": "schema 1 save has neither a world wallet nor a top-level wallet"}
	# The data stamp moved into the world for the same reason.
	if payload.has("data_stamp") and not world.has("data_stamp"):
		world["data_stamp"] = payload["data_stamp"]
	if not world.has("data_stamp"):
		world["data_stamp"] = {"label": "unknown (migrated from schema 1)"}
	# Schema 1 had no random-stream positions. An empty map is exact: every stream
	# then starts from its derived seed, which is what schema 1 did.
	if not world.has("streams"):
		world["streams"] = {}
	world["schema_version"] = 1
	var migrated := payload.duplicate(true)
	migrated.erase("wallet")
	migrated.erase("data_stamp")
	migrated["format"] = SaveFile.FORMAT_ID
	migrated["world"] = world
	migrated.erase(SaveFile.STATE_HASH_KEY)
	var issues: Array = []
	var state := WorldState.from_dict(world, issues)
	if state == null:
		return {"ok": false, "payload": payload,
				"error": "schema 1 world could not be rebuilt for hashing"}
	migrated[SaveFile.STATE_HASH_KEY] = state.state_hash()
	return {"ok": true, "payload": migrated,
			"note": "schema 1 → 2: wallet and data stamp moved into the world, "
					+ "stream positions and state hash added"}
