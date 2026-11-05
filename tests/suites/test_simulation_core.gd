extends TestCase
## Simulation core: the calendar, the clock, determinism, the event bus and the
## system registry.
##
## These tests are the referee for the milestone's strictest promises:
##   * one tick is one in-game day, and a speed is expressed in days per second,
##     never in frames;
##   * a slow frame can delay ticks but can never skip or double-run one;
##   * the same seed and the same actions produce the same state hash;
##   * adding a system must not shift another system's random numbers;
##   * the only registered system is the calendar.

const SEED := 20260101


## A stand-in system that consumes a named random stream and writes the result
## into the world state. It exists so the determinism test covers the whole chain
## (tick -> system -> stream -> state -> hash) instead of only the clock.
class CountingSystem extends SimulationSystem:
	var total := 0
	var stream_name := "test_counter"

	func _init(system_id: String = "test_counter", order_value: int = 500,
			frequency_value: int = 1) -> void:
		id = system_id
		order = order_value
		frequency = frequency_value
		version = 1

	func update(context: Dictionary) -> bool:
		var streams: RandomStreams = context.get("streams")
		var world: WorldState = context.get("state")
		if streams == null or world == null:
			return false
		var draw := streams.stream(stream_name).next_int(0, 999)
		total = (total + draw) % 1000003
		var previous: Dictionary = world.section(world.player_country_id, "test_counter")
		var draws: int = int(previous.get("values", {}).get("draws", 0)) + 1
		world.write_section(world.player_country_id, "test_counter", 1,
				{"total": total, "draws": draws})
		return true


var _atlas: WorldAtlas


func _load() -> void:
	if _atlas == null:
		_atlas = WorldAtlas.load_default()


func _config(country_id: String = "BGD") -> CampaignConfig:
	_load()
	var config := CampaignConfig.new()
	config.scenario_id = "modern_world_2026"
	config.country_id = country_id
	config.start_date = "2026-01-01"
	var record := _atlas.registry.get_country(country_id) if _atlas.registry != null else null
	config.metadata = {
		"scenario_name": "Modern World",
		"country_name": record.name if record != null else country_id,
	}
	return config


func _world(seed_value: int = SEED, country_id: String = "BGD") -> WorldState:
	_load()
	return WorldState.new_campaign(_config(country_id), _atlas.registry,
			DataStamp.compute(_atlas), seed_value)


func _simulation_with_counter(world_state: WorldState,
		stream_name: String = "test_counter") -> Simulation:
	var simulation := Simulation.for_state(world_state)
	simulation.register_shipped_systems()
	var counter := CountingSystem.new()
	counter.stream_name = stream_name
	simulation.register_system(counter)
	simulation.clock.set_speed(4)
	return simulation


## Runs exactly `count` ticks, one per call, so the tick count is a fact rather
## than a product of frame timing.
func _run_ticks(simulation: Simulation, count: int) -> void:
	simulation.clock.set_speed(4)
	for _tick in range(count):
		simulation.advance(1.0 / GameClock.TICKS_PER_SECOND[4])


# --- Calendar --------------------------------------------------------------

func test_calendar_month_lengths_and_leap_years() -> void:
	var lengths := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	for month in range(1, 13):
		var expected: int = lengths[month - 1]
		check_eq(GameDate.days_in_month(2026, month), expected, "2026 month %d length" % month)
	check_eq(GameDate.days_in_month(2024, 2), 29, "2024 is a leap year")
	check_eq(GameDate.days_in_month(2000, 2), 29, "2000 is a leap year (divisible by 400)")
	check_eq(GameDate.days_in_month(1900, 2), 28, "1900 is not a leap year (divisible by 100)")
	check_eq(GameDate.days_in_month(2100, 2), 28, "2100 is not a leap year")
	check_true(GameDate.is_leap_year(2028), "2028 is a leap year")
	check_false(GameDate.is_leap_year(2027), "2027 is not a leap year")
	check_true(GameDate.is_valid(2024, 2, 29), "29 February 2024 exists")
	check_false(GameDate.is_valid(2026, 2, 29), "29 February 2026 does not exist")
	check_false(GameDate.is_valid(2026, 4, 31), "31 April does not exist")
	check_false(GameDate.is_valid(2026, 13, 1), "there is no thirteenth month")


func test_calendar_day_index_round_trips() -> void:
	for text: String in ["0001-01-01", "1900-02-28", "2024-02-29", "2026-01-01",
			"2026-12-31", "9999-12-31"]:
		var date := GameDate.parse(text)
		check_not_null(date, "%s parses" % text)
		if date == null:
			continue
		var index := date.to_day_index()
		check_gte(float(index), 1.0, "%s has a positive day index" % text)
		check_eq(GameDate.from_day_index(index).format_short(), text,
				"%s survives a day-index round trip" % text)
	check_eq(GameDate.parse("2026-01-02").to_day_index(),
			GameDate.parse("2026-01-01").to_day_index() + 1, "consecutive days differ by one")
	check_eq(GameDate.parse("2024-03-01").to_day_index(),
			GameDate.parse("2024-02-28").to_day_index() + 2,
			"the leap day is counted exactly once")
	for bad: String in ["", "2026-1-1", "2026-02-30", "01-01-2026", "2026-13-01"]:
		check_true(GameDate.parse(bad) == null, "'%s' is not a date" % bad)


func test_date_formatting_is_readable() -> void:
	var date := GameDate.parse("2026-01-01")
	check_eq(date.format_long(), "1 January 2026", "long dates read naturally")
	check_eq(date.format_month(), "January 2026", "months can be named on their own")
	check_eq(date.format_short(), "2026-01-01", "short dates stay machine-friendly")
	check_true(date.is_first_of_month(), "1 January is the first of a month")
	check_true(date.is_first_of_year(), "1 January is the first of a year")
	var mid := GameDate.parse("2026-02-14")
	check_false(mid.is_first_of_month(), "14 February is not the first of a month")
	check_false(mid.is_first_of_year(), "14 February is not the first of a year")
	check_true(GameDate.parse("2026-03-01").is_first_of_month(),
			"the first of March starts a new month")


# --- Clock -----------------------------------------------------------------

func test_tick_is_one_day_and_speeds_are_tick_rates() -> void:
	var clock := GameClock.for_new_campaign("2026-01-01")
	check_eq(clock.date().format_short(), "2026-01-01", "the clock starts on the scenario date")
	check_eq(clock.speed, 1, "a new campaign clock starts at normal speed")
	check_eq(clock.advance(0.5), 1, "speed 1 runs 2 days per second")
	clock.set_speed(2)
	check_eq(clock.advance(0.5), 4, "speed 2 runs 8 days per second")
	check_eq(clock.date().format_short(), "2026-01-06", "five ticks moved five days")
	check_eq(GameClock.TICK_DAYS, 1, "one tick is exactly one in-game day")

	for speed_value in [1, 2, 3, 4]:
		var probe := GameClock.for_new_campaign("2026-01-01")
		probe.set_speed(speed_value)
		var rate: float = GameClock.TICKS_PER_SECOND[speed_value]
		var expected := int(rate)
		var ticks := probe.advance(1.0)
		if expected > GameClock.MAX_TICKS_PER_FRAME:
			check_eq(ticks, GameClock.MAX_TICKS_PER_FRAME,
					"speed %d is capped inside one frame" % speed_value)
			continue
		check_eq(ticks, expected, "speed %d runs %d ticks per second" % [speed_value, expected])
		check_true(absf(probe.milliseconds_per_tick() - 1000.0 / rate) < 0.001,
				"speed %d reports its tick length" % speed_value)


func test_slow_frames_delay_ticks_but_never_skip_them() -> void:
	var clock := GameClock.for_new_campaign("2026-01-01")
	clock.set_speed(2)  # 8 ticks per second
	check_eq(clock.advance(0.1), 0, "a frame shorter than a tick runs nothing")
	check_eq(clock.advance(0.1), 1, "the remainder is carried, not rounded away")
	check_eq(clock.advance(0.01), 0, "a tiny frame still runs nothing")
	check_eq(clock.advance(0.01), 0, "two tiny frames do not double-run a tick")
	check_eq(clock.advance(0.2), 1, "carried remainders add up exactly")

	var frame := GameClock.for_new_campaign("2026-01-01")
	frame.set_speed(4)  # 128 ticks per second
	var ticks := frame.advance(10.0)
	check_eq(ticks, GameClock.MAX_TICKS_PER_FRAME,
			"a ten-second frame runs at most the per-frame cap")
	check_eq(frame.capped_frames, 1, "the cap is counted, not hidden")
	check_eq(frame.advance(0.0), 0, "a zero-length frame runs nothing")

	# A 60-frame-per-second second must deliver the same ticks as one long frame
	# would have, within a tick: time is measured, not frames counted.
	var smooth := GameClock.for_new_campaign("2026-01-01")
	smooth.set_speed(4)
	var total := 0
	for _frame in range(60):
		total += smooth.advance(1.0 / 60.0)
	check_lte(absf(float(total) - 128.0), 2.0,
			"60 frames at 60 fps deliver about 128 days (got %d)" % total)


func test_pause_stops_the_world_completely() -> void:
	_load()
	var world := _world()
	var simulation := Simulation.for_state(world)
	simulation.register_shipped_systems()
	_run_ticks(simulation, 5)
	var ticks_before := simulation.total_ticks
	var date_before := world.current_date().format_short()
	simulation.clock.pause()
	for _frame in range(120):
		simulation.advance(1.0 / 60.0)
	check_eq(simulation.total_ticks, ticks_before, "nothing runs while paused")
	check_eq(world.current_date().format_short(), date_before, "the date cannot move while paused")
	simulation.clock.toggle_pause()
	check_false(simulation.clock.is_paused(), "toggling pause resumes the clock")
	simulation.advance(0.5)
	check_gt(float(simulation.total_ticks), float(ticks_before), "resuming runs ticks again")


# --- Determinism -----------------------------------------------------------

func test_1000_ticks_are_deterministic() -> void:
	var first_world := _world(SEED)
	var second_world := _world(SEED)
	var first := _simulation_with_counter(first_world)
	var second := _simulation_with_counter(second_world)
	_run_ticks(first, 1000)
	check_eq(first.total_ticks, 1000, "the first run simulated 1000 days")
	_run_ticks(second, 1000)
	check_eq(second.total_ticks, 1000, "the second run simulated 1000 days")
	check_eq(first_world.current_date().format_short(),
			second_world.current_date().format_short(), "both runs ended on the same date")
	check_eq(first_world.state_hash(), second_world.state_hash(),
			"the same seed and the same days produce the same state hash")
	check_eq(first_world.section("BGD", "test_counter").get("values", {}),
			second_world.section("BGD", "test_counter").get("values", {}),
			"the consuming system produced identical state in both runs")

	var other_world := _world(SEED + 1)
	var other := _simulation_with_counter(other_world)
	_run_ticks(other, 1000)
	check_true(first_world.state_hash() != other_world.state_hash(),
			"a different seed produces a different world")


func test_named_streams_do_not_shift_each_other() -> void:
	var straight := RandomStreams.from_seed(SEED)
	var first_alpha := straight.stream("alpha").next_u32()
	var interleaved := RandomStreams.from_seed(SEED)
	for _draw in range(50):
		interleaved.stream("military").next_u32()
		interleaved.stream("economy").next_u32()
	var second_alpha := interleaved.stream("alpha").next_u32()
	check_eq(first_alpha, second_alpha,
			"consuming other streams first does not change a stream's numbers")
	check_eq(RandomStreams.from_seed(SEED).stream_seed("alpha"),
			RandomStreams.from_seed(SEED).stream_seed("alpha"),
			"a stream's seed is derived only from the campaign seed and its name")
	check_true(RandomStreams.from_seed(SEED).stream_seed("alpha")
			!= RandomStreams.from_seed(SEED).stream_seed("beta"),
			"different names get different streams")
	check_true(RandomStreams.from_seed(SEED).stream_seed("alpha")
			!= RandomStreams.from_seed(SEED + 1).stream_seed("alpha"),
			"a different campaign seed changes a stream")
	check_eq(RandomStreams.from_seed(SEED).stream("alpha").next_u32(),
			RandomStreams.from_seed(SEED).stream("alpha").next_u32(),
			"streams are reproducible across instances")
	var restored := RandomStreams.from_seed(SEED + 99)
	var issues: Array = []
	restored.restore(RandomStreams.from_seed(SEED).to_dict(), issues)
	check_eq(issues.size(), 0, "a stream table restores without complaint")
	check_eq(restored.stream("alpha").next_u32(), first_alpha,
			"restoring the stream table reproduces the same numbers")


func test_rng_stays_inside_its_range_and_is_reproducible() -> void:
	var rng := DeterministicRng.from_seed(7)
	var seen: Dictionary = {}
	for _draw in range(2000):
		var value := rng.next_int(3, 9)
		check_true(value >= 3 and value <= 9, "next_int never leaves its inclusive range")
		seen[value] = true
	check_eq(seen.size(), 7, "every value in the range eventually appears")
	var a := DeterministicRng.from_seed(99)
	var b := DeterministicRng.from_seed(99)
	for _draw in range(100):
		check_eq(a.next_u32(), b.next_u32(), "the same seed repeats the same sequence")
	var floats := DeterministicRng.from_seed(5)
	for _draw in range(500):
		var value := floats.next_float()
		check_true(value >= 0.0 and value < 1.0, "next_float stays in [0, 1)")


# --- Event bus -------------------------------------------------------------

func test_event_bus_orders_by_priority_then_subscription() -> void:
	var bus := EventBus.new()
	var order: Array[String] = []
	bus.subscribe("evt", func(_payload: Dictionary) -> void: order.append("late"),
			EventBus.DEFAULT_PRIORITY + 50)
	bus.subscribe("evt", func(_payload: Dictionary) -> void: order.append("first"), 10)
	bus.subscribe("evt", func(_payload: Dictionary) -> void: order.append("second"), 10)
	check_eq(bus.publish("evt"), 3, "publish reports how many handlers ran")
	check_eq(order, ["first", "second", "late"],
			"lower priority runs first; equal priorities keep subscription order")
	check_eq(bus.delivered_count(), 3, "delivery is counted")
	check_eq(bus.subscriber_count("evt"), 3, "subscribers are counted")
	check_eq(bus.pending_count(), 0, "nothing is left queued after delivery")


func test_event_bus_queues_nested_publishes_and_allows_unsubscribing() -> void:
	var bus := EventBus.new()
	var order: Array[String] = []
	var second_id := [0]
	var handler_a := func(_payload: Dictionary) -> void:
		order.append("outer-a")
		bus.publish("inner", {})
		bus.unsubscribe("outer", int(second_id[0]))
		order.append("outer-a-done")
	var handler_b := func(_payload: Dictionary) -> void:
		order.append("outer-b")
	bus.subscribe("outer", handler_a)
	second_id[0] = bus.subscribe("outer", handler_b)
	bus.subscribe("inner", func(_payload: Dictionary) -> void: order.append("inner"))
	bus.publish("outer", {"value": 1})
	check_eq(order, ["outer-a", "outer-a-done", "outer-b", "inner"],
			"a nested publish waits for the whole current event to finish")
	check_eq(bus.pending_count(), 0, "the queue drains")
	check_eq(bus.subscriber_count("outer"), 0, "unsubscribing during delivery is allowed")

	var history_bus := EventBus.new()
	history_bus.record_history = true
	history_bus.publish("logged", {"n": 1})
	check_eq(history_bus.history.size(), 1, "history records published events")
	history_bus.clear()
	check_eq(history_bus.history.size(), 0, "clearing removes history and subscriptions")


# --- Systems ---------------------------------------------------------------

func test_calendar_is_the_only_shipped_system() -> void:
	_load()
	var simulation := Simulation.for_state(_world())
	check_eq(simulation.systems().size(), 0, "a fresh simulation registers nothing by itself")
	simulation.register_shipped_systems()
	var systems := simulation.systems()
	check_eq(systems.size(), 1, "the build ships exactly one system")
	if systems.size() == 1:
		check_eq(systems[0].id, "calendar", "and it is the calendar")
		check_eq(systems[0].version, 1, "systems carry a version")
		check_eq(systems[0].frequency, SimulationSystem.Frequency.DAILY,
				"the calendar runs every day")
		check_true(systems[0].order < 100, "the clock owns the lowest order band")
	check_true(simulation.has_system("calendar"), "the calendar is addressable by id")
	var described := simulation.describe_systems()
	check_eq(described.size(), 1, "the status panel is built from the registry, not a list")
	for line: String in described:
		check_true(line.to_lower().contains("calendar"),
				"every described system is a registered one")


func test_registration_rejects_mistakes_and_sorts_by_order() -> void:
	_load()
	var simulation := Simulation.for_state(_world())
	check_false(simulation.register_system(null), "a null system is refused")
	check_false(simulation.register_system(CountingSystem.new("", 10)),
			"a system without an id is refused")
	check_false(simulation.register_system(CountingSystem.new("negative", -5)),
			"a negative order is refused")
	check_true(simulation.register_system(CountingSystem.new("second", 200)),
			"a valid system registers")
	check_false(simulation.register_system(CountingSystem.new("second", 200)),
			"a duplicate id is refused")
	check_true(simulation.register_system(CountingSystem.new("first", 100)),
			"order does not have to arrive sorted")
	var ordered: Array[String] = []
	for system: SimulationSystem in simulation.systems():
		ordered.append(system.id)
	check_eq(ordered, ["first", "second"], "systems run in ascending order")

	var monthly := CountingSystem.new("monthly", 300, SimulationSystem.Frequency.MONTHLY)
	var yearly := CountingSystem.new("yearly", 301, SimulationSystem.Frequency.YEARLY)
	check_true(monthly.is_due(GameDate.parse("2026-02-01")), "a monthly system runs on the 1st")
	check_false(monthly.is_due(GameDate.parse("2026-02-02")), "and not on the 2nd")
	check_true(yearly.is_due(GameDate.parse("2027-01-01")), "a yearly system runs on 1 January")
	check_false(yearly.is_due(GameDate.parse("2026-03-01")),
			"a yearly system does not run every month")


func test_month_and_year_events_fire_on_the_boundary() -> void:
	_load()
	var world := _world()
	var simulation := Simulation.for_state(world)
	simulation.register_shipped_systems()
	var months: Array[String] = []
	var years: Array[int] = []
	var day_count := [0]
	simulation.bus.subscribe(EventBus.MONTH_STARTED,
			func(payload: Dictionary) -> void: months.append(str(payload.get("label"))))
	simulation.bus.subscribe(EventBus.YEAR_STARTED,
			func(payload: Dictionary) -> void: years.append(int(str(payload.get("label")))))
	simulation.bus.subscribe(EventBus.DAY_ADVANCED,
			func(_payload: Dictionary) -> void: day_count[0] += 1)
	_run_ticks(simulation, 366)
	check_eq(day_count[0], 366, "one day event per tick")
	check_eq(months.size(), 12, "a year of ticks opens twelve months")
	check_eq(months[0], "February 2026", "the first month boundary after 1 January is February")
	check_eq(years, [2027], "crossing into 2027 fires one year event")
	check_eq(world.current_date().format_short(), "2027-01-02",
			"366 ticks from 1 January 2026 land on 2 January 2027")


# --- World state -----------------------------------------------------------

func test_world_state_validates_and_hashes_its_content() -> void:
	_load()
	var world := _world()
	check_eq(world.validation_errors(_atlas.registry).size(), 0,
			"a freshly created campaign is valid")
	check_eq(world.player_country_id, "BGD", "the player's country is stored by stable id")
	check_eq(world.scenario_id, "modern_world_2026", "the scenario is identified by id")
	check_eq(world.seed_value, SEED, "the seed is part of the state")
	check_false(world.state_hash().is_empty(), "the state has a hash")
	check_eq(world.state_hash(), world.state_hash(), "hashing is stable within a run")

	var clone := WorldState.from_dict(world.to_dict(), [])
	check_not_null(clone, "a state round-trips through its dictionary form")
	if clone != null:
		check_eq(clone.state_hash(), world.state_hash(),
				"a round trip preserves the state hash")

	var before := world.state_hash()
	world.write_section("BGD", "example", 1, {"value": 3})
	var after := world.state_hash()
	check_true(before != after, "extending a country changes the hash")
	check_eq(world.section("BGD", "example").get("values", {}).get("value", 0), 3,
			"extension sections round-trip")
	check_eq(world.section("BGD", "example").get("version", 0), 1,
			"an extension section carries its own version")

	world.add_playtime(30.0)
	check_eq(world.state_hash(), after, "playtime is excluded from the state hash")

	var broken := world.to_dict()
	broken["clock"] = {"day_index": 1.5, "speed": 2}
	var issues: Array = []
	var rejected := WorldState.from_dict(broken, issues)
	check_true(rejected == null or issues.size() > 0,
			"a fractional day index is refused, not rounded")


func test_session_tracks_playtime_and_autosaves_on_the_first_of_the_month() -> void:
	_load()
	var store := SaveStore.new("user://test_session_saves")
	_clear_directory(store.directory())
	var session := GameSession.start_new(_config(), _atlas, store, SEED)
	check_not_null(session, "a session starts from a valid configuration")
	if session == null:
		return
	check_eq(session.simulation.systems().size(), 1, "a session ships the calendar only")
	check_eq(session.world.player_country_id, "BGD", "the session plays the chosen country")
	check_eq(GameSession.default_seed(_config()), GameSession.default_seed(_config()),
			"the default seed is derived, not random")
	check_true(GameSession.default_seed(_config("NPL"))
			!= GameSession.default_seed(_config("BGD")),
			"a different nation gets a different default seed")

	session.simulation.clock.set_speed(4)
	var ticks := 0
	for _frame in range(40):
		ticks += session.tick(1.0 / GameClock.TICKS_PER_SECOND[4])
	check_eq(ticks, 40, "the session advances the simulation")
	check_gt(session.world.playtime_seconds, 0.0, "playtime is counted")
	check_true(session.pending_autosave, "crossing 1 February queued an autosave")
	var saved := session.drain_pending_autosave("2026-02-01T00:00:00Z")
	check_true(bool(saved.get("ok", false)), "the queued autosave is a real save")
	check_true(FileAccess.file_exists(store.path_for(SaveStore.AUTOSAVE_SLOT)),
			"the autosave exists on disk")
	check_eq(session.autosave_count, 1, "the autosave is counted once")
	check_true(session.drain_pending_autosave().is_empty(),
			"draining twice does not save twice")
	_clear_directory(store.directory())


## Deletes every file this suite wrote. Each suite uses its own directory so a
## test can never touch the developer's real saves.
func _clear_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)
