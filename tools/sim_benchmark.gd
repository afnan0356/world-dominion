extends Node
## Headless benchmark for the simulation core and the save layer.
##
##   godot --headless --path . res://tools/sim_benchmark.tscn
##
## Reports measured numbers only. Nothing here estimates: every figure is timed
## with `Time.get_ticks_usec()` on the machine that runs it, and the doc that quotes
## them says which machine that was. Device numbers (a phone) stay UNVERIFIED until
## somebody runs this build on one.
##
## The numbers answer four questions the milestone asks for:
##   1. how long one simulated day costs at the start of a campaign;
##   2. how long a state hash takes (it runs on every save);
##   3. how long a save and a load take, and how big a save file is;
##   4. how much memory the core holds after building a campaign.

const TICKS := 10000
const HASH_SAMPLES := 200
const SAVE_SAMPLES := 5
const BENCH_DIR := "user://benchmark_saves"


func _ready() -> void:
	var atlas := WorldAtlas.load_default()
	if atlas == null or not atlas.is_ready():
		print("BENCHMARK FAILED: the world atlas did not load")
		get_tree().quit(1)
		return
	var config := CampaignConfig.new()
	config.scenario_id = "modern_world_2026"
	config.country_id = "BGD"
	config.start_date = "2026-01-01"
	config.metadata = {"scenario_name": "Modern World", "country_name": "Bangladesh"}

	print("")
	print("WORLD DOMINION · simulation and save benchmark")
	print("----------------------------------------------")
	print("engine          %s" % Engine.get_version_info().get("string", "?"))
	print("cpu             %s" % OS.get_processor_name())
	var started := Time.get_ticks_usec()
	var stamp := DataStamp.compute(atlas)
	var world := WorldState.new_campaign(config, atlas.registry, stamp, 20260101)
	var simulation := Simulation.for_state(world)
	simulation.register_shipped_systems()
	var build_ms := float(Time.get_ticks_usec() - started) / 1000.0
	print("campaign build  %.2f ms (world state + one system)" % build_ms)

	simulation.clock.set_speed(2)
	var tick_started := Time.get_ticks_usec()
	for _tick in range(TICKS):
		simulation.advance(1.0 / GameClock.TICKS_PER_SECOND[2])
	var ticks_us := Time.get_ticks_usec() - tick_started
	print("ticks           %d in %.1f ms → %.2f µs per simulated day (%s)" % [
		simulation.total_ticks, float(ticks_us) / 1000.0,
		float(ticks_us) / float(maxi(1, simulation.total_ticks)),
		world.current_date().format_short()])
	print("hash payload    %d countries with dynamic state" % world.country_ids().size())

	var hash_started := Time.get_ticks_usec()
	for _sample in range(HASH_SAMPLES):
		world.state_hash()
	var hash_us := float(Time.get_ticks_usec() - hash_started) / float(HASH_SAMPLES)
	print("state hash      %.2f µs per hash (SHA-256 over the canonical state)" % hash_us)

	var store := SaveStore.new(BENCH_DIR)
	_clear(BENCH_DIR)
	var save_ms := 0.0
	var bytes := 0
	for sample in range(SAVE_SAMPLES):
		var began := Time.get_ticks_usec()
		var result := store.save("1", world, "2026-01-01T00:00:00Z", "2026-02-01T00:00:00Z")
		save_ms += float(Time.get_ticks_usec() - began) / 1000.0
		bytes = int(result.get("bytes", 0))
		if not bool(result.get("ok", false)):
			print("BENCHMARK FAILED: save refused (%s)" % str(result.get("errors")))
			get_tree().quit(1)
			return
		if sample == 0:
			print("save size       %d bytes" % bytes)
	print("save            %.2f ms per atomic save (average of %d)" % [
		save_ms / float(SAVE_SAMPLES), SAVE_SAMPLES])

	var load_started := Time.get_ticks_usec()
	var loaded: Dictionary = store.load_slot("1", atlas.registry)
	var load_ms := float(Time.get_ticks_usec() - load_started) / 1000.0
	print("load (first)    %.2f ms (verify + rebuild + validate; includes the one-time "
			% load_ms + "atlas load)")
	# The first load in a process also builds the world atlas, which is why it is much
	# slower than every later one. Both numbers are printed rather than explained away.
	var warm_started := Time.get_ticks_usec()
	store.load_slot("1", atlas.registry)
	var warm_ms := float(Time.get_ticks_usec() - warm_started) / 1000.0
	print("load (again)    %.2f ms (with the atlas already in memory)" % warm_ms)
	if bool(loaded["ok"]):
		print("hash match      %s" % str((loaded["world"] as WorldState).state_hash()
				== world.state_hash()))
	print("memory          %.1f MiB of static memory after the campaign" % (
			Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0))
	print("UNVERIFIED      phone timings: no build of this milestone has run on a phone")
	print("BENCHMARK OK")
	_clear(BENCH_DIR)
	get_tree().quit(0)


func _clear(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)
