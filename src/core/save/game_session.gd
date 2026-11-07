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
	session._connect_baseline()
	# A new campaign's baseline was written from the data this build ships, so this check
	# passes by construction. It runs anyway: "by construction" is an argument, and the check
	# is what makes the argument true after a data update.
	session._verify_baseline()
	# A campaign opens paused: the first thing the player sees should not be a clock
	# already running behind the guide. The saved speed is kept, so resuming is one
	# keypress away.
	session.simulation.clock.pause()
	# The first record in the campaign's history: it really did begin, on this in-game date,
	# with this country. Nothing is added when the session is only opened for a test, because
	# this function *is* the moment of creation.
	session.record_event("campaign", "notice", "events.campaign.started",
			{"country": session.world.player_country_name}, "campaign.start")
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
	session._connect_baseline()
	session.created_at = str(loaded["summary"].get("created_at", _timestamp()))
	session.last_save_slot = slot
	session.last_save_at = str(loaded["summary"].get("last_saved_at", ""))
	session._connect_autosave()
	# Loading also starts paused, for the same reason: nothing should happen while the
	# screen is still being built.
	session.simulation.clock.pause()
	# A resumed campaign records that it was resumed. Not an achievement, just history: the
	# Messages panel should be able to say when a campaign was picked up again.
	session.record_event("campaign", "info", "events.campaign.loaded",
			{"country": session.world.player_country_name}, "campaign.load")
	# The baseline a returning player sees is the one this build ships. When that is not the one
	# the save recorded, the campaign says so in its own log — once, at load — instead of showing
	# different figures under the same label.
	session._verify_baseline()
	return {"ok": true, "session": session, "errors": [], "player_error": "",
			"warnings": loaded["warnings"], "summary": loaded["summary"],
			"migrated": loaded["migrated"], "used_backup": loaded["used_backup"]}


## The baseline check reports through the simulation's bus so a headless test can see it; the
## session turns that into a campaign event, the same way the month rollover becomes an autosave.
func _connect_baseline() -> void:
	if simulation == null or simulation.bus == null:
		return
	simulation.bus.subscribe("world.baseline_changed", _on_baseline_changed)


func _on_baseline_changed(payload: Dictionary) -> void:
	record_event("world", "notice", "events.world.baseline_changed", {
		"recorded": str(payload.get("recorded", "")),
		"current": str(payload.get("current", "")),
		"reason": str(payload.get("reason", "")),
	}, "world.baseline")


## Runs the check once and records the event when the campaign's data no longer matches this
## build's. Returns the check's own result, so a test can assert on it without reading the log.
func _verify_baseline() -> Dictionary:
	var system := _baseline_system()
	if system == null:
		return {}
	var result := system.verify(world)
	if not bool(result["ok"]):
		_on_baseline_changed(result)
	return result


func _baseline_system() -> BaselineIntegritySystem:
	if simulation == null:
		return null
	for candidate: SimulationSystem in simulation.systems():
		if candidate is BaselineIntegritySystem:
			return candidate as BaselineIntegritySystem
	return null


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


## Records something that really happened, stamped with the in-game date at this moment.
##
## Every caller passes the exact values it used; this function never invents a subject, a
## number or a date. The event's text is a string-table key, so the sentence a player reads
## in 2027 can improve without changing a single saved game.
func record_event(event_category: String, severity: String, key: String, values: Dictionary,
		origin: String) -> GameEvent:
	if world == null or world.events == null:
		return null
	var clock := world.clock
	var day := clock.day_index if clock != null else 0
	var label := world.date_label() if clock != null else ""
	return world.events.record(event_category, severity, key, values, origin, day, label)


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
		record_event("system", "info", "events.save.autosave",
				{"slot": SaveStore.AUTOSAVE_SLOT}, "save.autosave")
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
		record_event("system", "info", "events.save.manual", {"slot": slot},
				"save.manual")
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
