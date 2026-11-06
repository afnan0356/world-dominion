class_name GameSession
extends RefCounted
## One running campaign: the world state, its simulation and its save slots.
##
## This is the seam between "the player chose a nation" and "the game screen is
## open". Everything that can be tested without a screen lives here, so the game
## screen only has to draw and forward input.
##
## Responsibilities, deliberately narrow:
##   * build a `WorldState` from a validated `CampaignConfig`;
##   * advance the simulation by real elapsed time;
##   * keep the playtime counter;
##   * save into a slot and autosave once per in-game month.
##
## It owns no nodes, creates no textures and never touches the scene tree, so a
## test can run a thousand ticks through it in a loop with no window open.

signal autosaved(info: Dictionary)
signal month_started(label: String)

## The campaign seed used when the player does not choose one. Deriving it from
## the scenario, country and start date makes "new campaign as Bangladesh" produce
## the same world every time — reproducible for testing and for later replay
## features — while still differing per nation. A future "custom seed" option can
## pass an explicit value instead.
const DEFAULT_SEED_RULE := "scenario|country|start_date -> sha256 -> first 8 hex digits"

var world: WorldState
var simulation: Simulation
var store: SaveStore
var registry: CountryRegistry
var created_at := ""
var autosave_enabled := true
## True once the tick that starts an in-game month has run; the screen drains it
## after the frame's ticks so saving never happens inside a system update.
var pending_autosave := false
var last_autosave_label := ""
var autosave_count := 0
var last_save_slot := ""
var last_save_at := ""


static func default_seed(config: CampaignConfig) -> int:
	var material := "%s|%s|%s" % [config.scenario_id, config.country_id,
			config.start_date if not config.start_date.is_empty() else GameClock.MODERN_WORLD_START]
	var digest := material.sha256_text().substr(0, 8)
	return digest.hex_to_int() & 0xFFFFFFFF


static func start_new(config: CampaignConfig, atlas: WorldAtlas, store_in: SaveStore,
		seed_value: int = -1) -> GameSession:
	var session := GameSession.new()
	session.store = store_in if store_in != null else SaveStore.new()
	session.registry = atlas.registry if atlas != null else null
	session.created_at = _timestamp()
	var seed_to_use := default_seed(config) if seed_value < 0 else seed_value
	var stamp := DataStamp.compute(atlas) if atlas != null else {}
	session.world = WorldState.new_campaign(config, session.registry, stamp, seed_to_use)
	session.simulation = Simulation.for_state(session.world)
	session.simulation.register_shipped_systems()
	session._connect_autosave()
	# A campaign opens paused: the first thing the player sees should not be a clock
	# already running behind the guide. The saved speed is kept, so resuming is one
	# keypress away.
	session.simulation.clock.pause()
	return session


## Rebuilds a session from a loaded save. Returns {ok, session, errors,
## player_error, warnings, summary, migrated, used_backup}.
static func resume(slot: String, atlas: WorldAtlas, store_in: SaveStore) -> Dictionary:
	var store_to_use := store_in if store_in != null else SaveStore.new()
	var registry := atlas.registry if atlas != null else null
	var loaded := store_to_use.load_slot(slot, registry)
	if not bool(loaded["ok"]):
		return {"ok": false, "session": null, "errors": loaded["errors"],
				"player_error": loaded["player_error"], "warnings": loaded["warnings"],
				"summary": {}, "migrated": false, "used_backup": false}
	var session := GameSession.new()
	session.store = store_to_use
	session.registry = registry
	session.world = loaded["world"]
	session.simulation = Simulation.for_state(session.world)
	session.simulation.register_shipped_systems()
	session.created_at = str(loaded["summary"].get("created_at", _timestamp()))
	session.last_save_slot = slot
	session.last_save_at = str(loaded["summary"].get("last_saved_at", ""))
	session._connect_autosave()
	# Loading also starts paused, for the same reason: nothing should happen while the
	# screen is still being built.
	session.simulation.clock.pause()
	return {"ok": true, "session": session, "errors": [], "player_error": "",
			"warnings": loaded["warnings"], "summary": loaded["summary"],
			"migrated": loaded["migrated"], "used_backup": loaded["used_backup"]}


func _connect_autosave() -> void:
	if simulation == null or simulation.bus == null:
		return
	simulation.bus.subscribe(EventBus.MONTH_STARTED, _on_month_started)


func _on_month_started(payload: Dictionary) -> void:
	pending_autosave = autosave_enabled
	month_started.emit(str(payload.get("label", "")))


## Advances the simulation by real elapsed time and counts playtime. Returns the
## number of in-game days that were simulated this frame.
func tick(delta_seconds: float) -> int:
	if world == null or simulation == null:
		return 0
	var ticks := simulation.advance(delta_seconds)
	world.add_playtime(delta_seconds)
	return ticks


## Runs a pending autosave, if the month boundary has passed. Called once per
## frame by the screen *after* the tick, so the save never interrupts a system.
func drain_pending_autosave(now: String = "") -> Dictionary:
	if not pending_autosave:
		return {}
	pending_autosave = false
	return autosave(now)


func autosave(now: String = "") -> Dictionary:
	if world == null or store == null:
		return {"ok": false, "errors": ["no session"], "player_error": ""}
	var stamp := now if not now.is_empty() else _timestamp()
	var result := store.autosave(world, created_at, stamp)
	if bool(result["ok"]):
		autosave_count += 1
		last_autosave_label = stamp
		last_save_slot = SaveStore.AUTOSAVE_SLOT
		last_save_at = stamp
		autosaved.emit(result)
	return result


func save_to(slot: String, now: String = "") -> Dictionary:
	if world == null or store == null:
		return {"ok": false, "errors": ["no session"], "player_error": ""}
	var stamp := now if not now.is_empty() else _timestamp()
	var result := store.save(slot, world, created_at, stamp)
	if bool(result["ok"]):
		last_save_slot = slot
		last_save_at = stamp
	return result


func date_label() -> String:
	return world.date_label() if world != null else ""


func playtime_label() -> String:
	if world == null:
		return "0m"
	var total_minutes := int(world.playtime_seconds / 60.0)
	var hours := total_minutes / 60
	var minutes := total_minutes % 60
	if hours > 0:
		return "%dh %02dm" % [hours, minutes]
	return "%dm" % minutes


## Plain-language description of what is running, for the status panel.
func status_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	lines.append("Calendar simulation: running")
	for line: String in simulation.describe_systems():
		if not line.begins_with("Calendar"):
			lines.append(line)
	lines.append("Economy, politics, diplomacy and military: not in this version")
	lines.append("No statistics are simulated; the dossier's figures are sourced "
		+ "reference data, not simulated values")
	return lines


static func _timestamp() -> String:
	# UTC ISO-8601 without a timezone suffix: consistent, sortable, and free of
	# the player's local time zone, which keeps save lists comparable.
	return Time.get_datetime_string_from_system(true, true).replace(" ", "T") + "Z"
