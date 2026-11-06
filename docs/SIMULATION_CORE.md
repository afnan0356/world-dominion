# Simulation core

This is how time passes inside WORLD DOMINION, how randomness works, how systems are
plugged in, and what "deterministic" actually promises. It describes **Milestone 03**: the
core exists, the save layer exists, and exactly **one** system is registered — the calendar.

Read `docs/SAVE_FORMAT.md` next for what gets written to disk, and
`docs/OPEN_ENDED_DESIGN.md` for where this is going.

---

## 1. The one-paragraph version

A **tick** is one in-game day. The game clock is a counted integer (`day_index`), not a
floating date, so a month boundary is exactly a tick landing on the 1st of a month. Real
elapsed time is converted into ticks by a documented rate: `ticks per second × delta`. The
conversion carries its remainder and is capped per frame, so a slow frame delays ticks but
can never skip or double-run one. Systems are registered with an order, a frequency and a
version, they run in a documented order, and they talk to the rest of the game through a
queued event bus. Randomness comes from named streams derived from the campaign seed, so the
same seed and the same actions produce the same state hash on every platform.

---

## 2. The calendar

| Property | Value | Where it is enforced |
| --- | --- | --- |
| Scenario start | **1 January 2026** (Modern World) | `GameClock.MODERN_WORLD_START`, scenario file |
| Tick length | **1 in-game day** | `GameClock.TICK_DAYS` |
| Speeds | Normal 1, Fast-forward 10, VIP 20 **days per real second** (pause = 0) | `GameClock.TICKS_PER_SECOND` |
| Saved speed | a stable id (`paused`, `normal`, `fast_forward`, `vip_fast_forward`) | `GameClock.SPEED_IDS` |
| Speed migration | old 1 and 2 keep their meaning; old 3 and 4 become Fast-forward; never the VIP speed | `GameClock.migrate_legacy_speed()` |
| Pause | speed 0: `advance()` returns 0, no system runs | `GameClock.is_paused()` |
| Max ticks per frame | **64**, remainder carried | `GameClock.MAX_TICKS_PER_FRAME` |
| Month lengths | Gregorian, with leap rules | `GameDate.days_in_month()` |
| Leap years | Divisible by 4, except centuries not divisible by 400 | `GameDate.is_leap_year()` |

Speeds are named *Slow, Normal, Fast, Fastest* in the interface and are labelled 1×–4×. The
labels are not the promise: the promise is the tick rate. A device that renders 20 frames per
second and one that renders 120 both see 32 in-game days per second at the same speed; the
slower device simply runs more ticks per frame, up to the cap.

The clock is stored as an integer day index (`days since 1 January of year 1`), which is why a
save can resume on an exact date and why comparisons are cheap. The sub-tick accumulator is
**not saved**: it depends on frame timing and is not game state.

### Why a per-frame cap

At the fastest speed, 128 days per second is roughly two days per frame at 60 fps — fine. But
one hiccup of two seconds would ask for 256 days in a single frame, and running that work in
one frame makes the hiccup worse. The cap runs at most 64 ticks per frame and *keeps the
remainder*, so the lost time comes back over the next frames. The number of capped frames is
counted (`GameClock.capped_frames`) and reported by the developer overlay, so a slow device is
visible instead of silently drifting.

---

## 3. Determinism: what is promised, and how

**Promise:** for the same campaign seed and the same player actions, the simulation reaches
the same state, and therefore the same state hash, on every platform.

How that is achieved:

1. **No wall-clock time inside systems.** The only inputs are the current date, the state and
   named random streams. `Time.get_ticks_usec()` is used for *reporting* timings, never for
   deciding anything.
2. **Integer time.** The date is an integer day index; no floating-point date arithmetic can
   drift between platforms.
3. **Integer randomness.** The generator (`DeterministicRng`) is SplitMix32 over 32-bit
   integers: no platform-dependent float rounding, no engine RNG, no global seed.
4. **Named streams.** Each system asks for its own stream by name. The stream's seed is the
   FNV-1a hash of the name, multiplied into the campaign seed. Adding a new system, or adding
   draws in one system, cannot shift another system's numbers.
5. **Fixed update order.** Systems run in ascending `order`, then by id — a total order, so
   two systems with the same band still run in a stable sequence.
6. **No iteration-order dependence.** Country state is keyed by stable id and hashed after
   canonical sorting (`CanonicalJson`), so a hash never depends on dictionary insertion order.

**Tested:** `tests/suites/test_simulation_core.gd` runs 1,000 ticks twice from the same seed
and compares the state hash, and repeats with a different seed to prove the hash actually
moves. It also proves a named stream is unaffected by draws taken from other streams.

**Not promised:** identical *pixels*, identical *timings*, or identical results if the player
does something different. Determinism is about the simulation, not about frame rate.

**Why it matters later:** replays, bug reports ("here is my seed and my 200 ticks") and
multiplayer are only honest if the core is deterministic now, while it is still one system
large. It is much cheaper to keep than to add.

---

## 4. The event bus

A publish/subscribe bus (`EventBus`) with four documented rules:

1. **Queued, not recursive.** `publish()` appends to a queue. Delivery happens after the
   current handler returns. A handler that publishes cannot re-enter its own event.
2. **Ordered.** Handlers run in ascending `priority`; equal priorities run in subscription
   order. Both are deterministic, so a replay sees the same sequence.
3. **No mutation during delivery.** Subscribing or unsubscribing during delivery is allowed and
   takes effect for the *next* delivery: the handler list is snapshotted first. A handler that
   removes itself mid-event still receives the event it is handling, and every other handler
   still runs.
4. **Payloads are read-only by convention.** Handlers receive a dictionary and must not write
   to it. Mutation belongs in systems, which have explicit update order; a handler that edits
   shared state would make the order of *listeners* matter.

Events published today: `sim.day_advanced`, `sim.month_started`, `sim.year_started` (from the
calendar) and `ui.focus_country_changed` (reserved for interface focus). Event names are
constants on `EventBus`; there are no string literals scattered through the code.

---

## 5. Systems: registration, order, frequency, version

```gdscript
class_name MySystem extends SimulationSystem

func _init() -> void:
    id = "my_system"            # unique, stable, never shown to the player
    order = 250                 # when it runs (see the bands below)
    frequency = Frequency.DAILY # DAILY, MONTHLY or YEARLY
    version = 1                 # bump when this system's saved state changes shape

func update(context: Dictionary) -> bool:
    # context: date (GameDate), clock, bus, streams, state (WorldState)
    return true                 # false means "I could not run" — counted, not fatal
```

| Order band | Reserved for | Examples |
| --- | --- | --- |
| 0–99 | The clock and calendar | `calendar` (10) |
| 100–199 | Derived values computed from state | *planned* |
| 200–299 | Systems that read derived values | *planned* |
| 900+ | Reporting and diagnostics | *planned* |

Rules that the code enforces:

* an empty id, a negative order, or a duplicate id is **refused loudly** (`push_error`, and
  `register_system` returns `false`) — a registration mistake must never look like a system
  that quietly did not run;
* a system that returns `false` is counted in `Simulation.skipped_updates` and the tick
  continues: one broken system cannot freeze the calendar;
* `frequency` decides *which* days a system runs on: `DAILY` every tick, `MONTHLY` on the
  first of a month, `YEARLY` on 1 January. This is frequency, **not polling** — a monthly
  system does not wake up on the other 30 days to discover it has nothing to do.

**Shipped systems in this milestone: the calendar, and nothing else.**
`Simulation.register_shipped_systems()` exists so that the status panel, the tests and the
build status all read from the same place. There are no placeholder systems: a system that
does nothing but occupy a row in the panel would be a lie about what the game does.

---

## 6. WorldState: the dynamic half of the world

`WorldState` is everything the game *changes*: the clock, the seed, the random-stream
positions, the wallet, the playtime counter, the data stamp and per-country extension
sections. It contains **no map geometry**: geometry is static, lives in the atlas, and is
read-only at runtime.

| Static (read-only, shipped data) | Dynamic (saved) |
| --- | --- |
| Country registry: ids, names, ISO codes, region, eligibility | Clock, seed, stream positions |
| Geometry: polygons, rings, bounding boxes | Wallet balances |
| Capital points, label anchors | Playtime, per-country sections |
| Data stamp (a fingerprint of the above) | Data stamp of the data it was played against |

Per-country state is an extension point, not a schema:

```gdscript
world.write_section("BGD", "example", 1, {"value": 3}, "campaign_setup")
world.section("BGD", "example")   # {version, source, values}
```

Only the player's country has an entry today, and it is created empty: it proves the
mechanism without inventing a number. A later milestone adds a section with `version: 1`;
changing it later adds `version: 2` and a migration for that section.

**Validation before saving or after loading** checks, with precise messages: required keys,
types, integer-ness (a fractional day index is refused, not rounded), ranges, and that every
country id referred to exists in the shipped registry. `WorldState.state_hash()` is a SHA-256
over the canonical state, excluding playtime and timestamps, used both for the determinism
test and for detecting a state that does not match the file that contains it.

---

## 7. What runs on a frame

```
frame (delta seconds)
└─ GameSession.tick(delta)
   ├─ Simulation.advance(delta)
   │  ├─ GameClock.advance(delta)      → ticks due this frame (capped, remainder carried)
   │  └─ for each tick:
   │     ├─ clock.step()               → the date moves one day
   │     └─ for each system in order whose frequency matches the new date:
   │        └─ system.update(context)  → may publish events
   │           └─ bus delivers queued events after each handler returns
   └─ world.add_playtime(delta)
   └─ drain a pending autosave (never inside a system)
```

Paused, overlaid by a menu, or with no session, the loop does **nothing** — no ticks, no
systems, no autosave.

---

## 8. Measured cost

`tools/sim_benchmark.tscn` prints these numbers, and only these numbers are quoted:

```
godot --headless --path . res://tools/sim_benchmark.tscn
```

| Measurement | Value |
| --- | --- |
| campaign build (world state + one system) | see the CI benchmark log |
| cost of one simulated day at the start | see the CI benchmark log |
| state hash | see the CI benchmark log |
| save time, load time, save size | see the CI benchmark log |

The figures are produced by `tools/sim_benchmark.gd` on the machine that ran it (for this
milestone: a headless CI runner, 2 shared CPUs). **Phone timings are UNVERIFIED.** Nothing in
this document is an estimate presented as a measurement.

---

## 9. Not in this milestone (planned)

* Country statistics of any kind. No population, GDP or military value is simulated, and the
  game screen says so rather than showing a placeholder.
* Any economy, politics, diplomacy or military system. Their order bands and frequencies are
  reserved and documented above.
* Simulation-generated events in the sense of "something happened in the world". The bus
  exists and is exercised, but the only events are calendar boundaries.
* Player-defined goals — design only, see `docs/OPEN_ENDED_DESIGN.md`.
