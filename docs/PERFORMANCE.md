# Performance notes — world atlas, simulation and saves

Measured on the development container used for this milestone, with a **headless** Godot 4.6.3
build (`vulkan=no opengl3=no`) compiled from the official 4.6.3-stable source tag. The environment
has no GPU, no display server and no OpenGL/EGL/Vulkan driver, so this document reports **CPU work
and data volume only**. Frame time on real hardware is *not* measured here and is labelled
unverified rather than estimated.

Reproduce with:

```bash
godot --headless --path . res://tools/atlas_benchmark.tscn   # atlas: load, index, meshes, taps
godot --headless --path . res://tools/sim_benchmark.tscn      # simulation + save/load cost
```

## Dataset size

| Measurement | Value |
| --- | --- |
| Countries and territories | 242 |
| Polygons (disconnected parts) | 1 620 |
| Rings (outlines + holes) | 1 631 |
| Vertices in the source geometry | 99 567 |
| Coordinate quantisation | 1/200° (0.005°, ≈550 m at the equator) |
| `data/world/geometry.json` | 1 144 KiB |
| `data/world/countries.json` | 100 KiB |
| `data/world/manifest.json` | 2 KiB |
| Total committed runtime data | ≈1.3 MiB |

For scale: the raw 1:50m GeoJSON these files come from is 3.0 MiB, and the 1:10m alternative is
13.3 MiB before any processing.

## Load and construction cost (CPU, headless)

| Operation | Time |
| --- | --- |
| Parse `countries.json` into 242 typed records | 8.7 ms |
| Parse `geometry.json` into 99 567 points | 52.7 ms |
| Build the 10° spatial index | 2.1 ms |
| Total atlas load (`WorldAtlas.load_default()`) | 63.6 ms |
| Build every country's triangle meshes (all 242, both fills and holes) | 2.2 ms, 288 456 mesh vertices |
| Point-in-country hit test (average of 5 000 queries) | 150 µs/query (1 019 of 5 000 sample points on land) |
| Tap resolution **with** the small-country assist (average of 5 000 taps) | 854 µs/query |
| Tap resolution **without** the assist, for comparison | 550 µs/query |
| Registry search (average of 2 000 queries) | 2.6 ms/query — see the note below |
| Scale bar at a fitted world view (1280×720) | 2 000 km across 64 px |
| Static engine memory after load | 31.9 MiB |

These are one run of `res://tools/atlas_benchmark.tscn` on the build container (Godot 4.6.3 headless,
single process, no display). **Run-to-run variance on a shared container is large**: repeated runs of
the same build during this milestone ranged from 55 ms to 106 ms for the total load and 132 µs to
199 µs for the hit test. Treat the table as "the order of magnitude is this", not as a benchmark
result, and re-run the command above to regenerate it.

Three honest notes:

* **Search at ~2.6 ms/query is the slowest operation measured.** The benchmark searches the loose term
  `"a"` on odd iterations, which matches a large share of the 242 records and therefore measures the
  worst case for substring ranking rather than a typical query. It is a keypress-frequency cost, not a
  per-frame one, and a few milliseconds of CPU per keystroke is acceptable; it is still the first thing
  to look at if search ever feels slow.
* **The small-country assist costs about 300 µs per tap** (854 µs with, 550 µs without) because it runs
  a second pass over the visible countries after the polygon test misses. At tap frequency — a few per
  second at most — that is irrelevant next to the 16 ms frame budget, and it buys selectability for
  shapes that are otherwise unhittable. Hover deliberately does not use the assist.
* **1 631 rings were measured for triangulation, and all of them now triangulate.** One ring used to
  fail (`TWN[0]`, Taiwan's main island at 1:50m, where the source coastline doubles back on itself in a
  one-vertex hairpin). The build now repairs that defect by removing the spike vertex — recorded in
  `manifest.json` under `repairs`, with the area change (−0.04%) — so nothing falls back to a convex
  hull any more. The benchmark still prints `hull-fallback rings` to keep the fallback honest: it
  reports **0**.

## Simulation and save cost (CPU, headless)

Measured by `res://tools/sim_benchmark.tscn` on the same headless build, in the same run that produced
the numbers above (CI runner: AMD EPYC 7763, no GPU, no display). The campaign it measures is the real
Modern World campaign: 242 countries in the registry, one country carrying dynamic state (the player's),
one registered system (the calendar).

| Measurement | Value |
| --- | --- |
| Build a campaign (state + system) | 0.31 ms |
| 10 000 simulated days (10 000 ticks) | 179.1 ms → **17.9 µs per in-game day** |
| State hash (SHA-256 over the canonical state) | 48.8 µs |
| Save file size | 1 247 bytes |
| Atomic save (build + verify + backup + swap) | 1.34 ms (average of 5) |
| Load, first time in a process | 66.3 ms — **includes the one-time atlas load** |
| Load again, atlas already in memory | 0.71 ms |
| Static memory after the campaign | 26.5 MiB |

What these numbers mean in practice:

* **A tick costs about 18 µs, and the simulation only runs ticks that are due.** At the fastest speed
  (128 in-game days per second) that is ~2.3 ms of CPU per real second — about 0.2% of one core. The
  cost grows with the number of *systems* and *countries with dynamic state*, both of which are one
  today, so this is a floor, not a forecast.
* **A save is a small file and a fast write.** ~1.2 KB and ~1.3 ms of CPU, on a frame that already
  finished its ticks, which is why autosaving does not stutter. Frame time itself is still
  **UNVERIFIED** (no GPU here) — the honest claim is "the work is small", not "the frame never drops".
* **The first load looks slow only because it loads the world atlas.** 66.3 ms versus 0.71 ms for the
  same save with the atlas warm. The load screen shows a save's details from a cached atlas, so the
  slow case is the first load after the game starts, and it is the same 60 ms the atlas costs on its
  own (see above).
* **Playtime and timestamps are excluded from the state hash**, so hashing is not affected by how long
  the player has been sitting in a menu.

Not measured, and therefore **UNVERIFIED**: save/load time on a phone, save time on a phone's flash
storage (which is much slower than a container's disk), and whether an autosave can be felt as a
stutter on a low-end device. The instrument exists (`F3` overlay shows the last save/load time in the
developer panel); it has not been run on hardware.

## Performance budget

Budgets are set from these measurements plus headroom, and are deliberately conservative:

| Metric | Budget | Measured | Status |
| --- | --- | --- | --- |
| Runtime data committed | ≤ 2 MiB | 1.3 MiB | met |
| Full atlas load (CPU) | ≤ 150 ms | 55–106 ms across runs | met |
| Mesh build for the whole world (CPU) | ≤ 8 ms | 1.6–2.2 ms | met |
| Hit test (CPU) | ≤ 500 µs | 132–199 µs | met |
| Tap with the tiny-country assist (CPU) | ≤ 2 ms | 0.85 ms | met |
| Search per keystroke (CPU) | ≤ 5 ms | 2.6–2.7 ms | met |
| Static memory after load | ≤ 96 MiB | 31.9 MiB | met |
| Cost of one simulated day (CPU) | ≤ 200 µs | 17.9 µs | met |
| Atomic save (CPU) | ≤ 20 ms | 1.34 ms | met |
| Load with a warm atlas (CPU) | ≤ 50 ms | 0.71 ms | met |
| Save file size | ≤ 8 KiB | 1.2 KB | met |
| Autosave visible as a stutter | — | not measured | **unverified** |
| Save/load on a phone | ≤ 100 ms | not measured | **unverified** |
| Draw calls per frame at world zoom | ≤ 700 | not measured | **unverified** |
| Frame time at 60 fps on desktop | ≤ 16.6 ms | not measured | **unverified** |
| Frame time at 30 fps on low-end mobile | ≤ 33 ms | not measured | **unverified** |

The two unverified rows need a GPU and a device. They are the numbers that decide whether the map
feels smooth, and no amount of CPU measurement substitutes for them. The design keeps per-frame work
small (cached meshes, culled borders, ≤26 labels, ocean labels only at world zoom) but that is an
argument, not evidence.

The build now ships the instrument for that last step, so the owner can replace these two rows with
measurements instead of estimates — see the next section.

## Measuring on a real device

Two tools in the game do the measuring. Both are off by default and neither stores or sends anything.

**The performance overlay** (Settings → Advanced / Developer → Performance overlay, or **F3** at any
time) shows a small corner readout: frames per second, the average / 95th-percentile / worst frame time
over the last 180 frames, the engine's draw-call count for the frame, and — on the campaign map — how
many countries, labels and capital markers are currently drawn. It ignores the mouse, so it cannot
affect what you tap.

**The 30-second map stress test** (Settings → Advanced / Developer → Run 30-second map stress test,
after turning Developer tools on) opens the campaign map and drives the camera along a fixed path: one
west-to-east sweep of the world while the zoom cycles three times between the whole-world view and a
close regional view. Because the path is a pure function of elapsed time, the same 30 seconds are
replayed on every device, so two devices' numbers — or two settings' numbers — are comparable. Stalls
longer than 250 ms (a window drag, the app being paused) are counted separately and excluded from the
timings.

The run ends with a verdict against the same budgets used above:

| Verdict | Rule | Meaning |
| --- | --- | --- |
| **Smooth** | 95th-percentile frame time ≤ 16.7 ms | holds 60 fps on that device |
| **Acceptable** | ≤ 33.4 ms | playable, below 60 fps |
| **Too slow** | > 33.4 ms | the run suggests Settings → Reduced map detail |
| **Not enough samples** | fewer than 10 frames | the run was interrupted or the window was not focused |

**Reduced map detail** (Settings → Map) is the documented remedy for a slow device. It keeps the
geography, the shapes and everything you can tap exactly as they are, and reduces only drawing work:
fewer labels (rank 1 only), no ocean names, no capital markers, and borders skipped for countries under
14 px on screen instead of 7 px.

| Measurement | Budget | Status |
| --- | --- | --- |
| Frame time, 95th percentile, stress test | ≤ 16.7 ms for "smooth", ≤ 33.4 ms for "acceptable" | **unverified — no device has run it yet** |
| Draw calls per frame, whole-world view | ≤ 700 | **unverified** — the overlay reports it, nothing has recorded it |

To record a result, run the stress test twice on the target phone — once at full detail and once at
reduced detail — and copy the two summary lines into this document with the device name. Until that
happens every frame-time claim in this repository stays marked unverified, and the target device for
that measurement is the owner's Realme 9i (Snapdragon 680, Android 13, 6 GB RAM).

## What one map frame is made of (model, not a capture)

`python3 tools/map_render_cost.py` counts the drawing work of a fitted 1280×720 frame from the
committed data; `--before` models the previous renderer. The current frame is **2,381 drawing
commands** against 2,376 before — the ocean gradient, the 15° grid, the equator/tropics dashes, the
selection cues and the legend cost five commands in total, because each of those is one batched
`draw_multiline` instead of one command per line. Vertices are unchanged at 99,567.

Before the batching, the same layers would have cost 20 commands for the grid and 318 for the
reference dashes alone. That is the whole argument for batching: a new layer earns its place by
costing one command, not a hundred.

This is a **model**. There is no GPU in this environment and the headless renderer does not draw, so
this milestone makes **no frame-time claim**. What is measured here is CPU-side work (parse, index,
mesh build, hit tests) and the number of drawing commands the renderer issues.

## Why the map is cheap to pan

The renderer does no per-frame geometry work for fills:

* Each country's rings are triangulated **once** (`Geometry2D.triangulate_polygon`) and committed to an
  `ArrayMesh` in world space. Panning and zooming only change the canvas transform, so they cost one
  draw call per visible country and nothing else.
* Countries are culled by their bounding box against the visible world rectangle, so a zoomed-in view
  draws a handful of meshes rather than 242.
* Holes are a second cached mesh per country drawn in the sea colour, which avoids polygon booleans
  entirely.
* Borders are the only per-frame geometry: world-space polylines with a width of `1 / zoom`. Countries
  smaller than 7 px on screen are skipped, and the world view is the worst case for that cost.
* Labels are limited to 26, chosen by the dataset's own `LABELRANK`, with overlap rejection. Ocean
  names are drawn only while the view is at world zoom (`zoom_ratio() <= 1.8`), so they cost nothing
  once the player zooms in.
* The small-country markers and the scale bar iterate the *visible* country list, which is already
  required for drawing; neither adds a per-country allocation.
* Hit-testing falls back to a nearest-tiny-country search only after the polygon test has already
  missed, and only over visible countries, so a tap costs at most one extra pass of ≤242 bbox checks.

## What is *not* measured

* **Frame time / frame rate on any device.** No GPU is available in this environment; the headless
  renderer draws nothing, so any frame-time figure would be invented. The in-game overlay and stress
  test exist precisely so the owner can produce the real number; until one is recorded here, every
  frame-time claim remains unverified.
* **Mobile-low-end behaviour.** Untested: no Android or iOS device was available, and no export build
  exists yet.
* **GPU memory for the meshes.** Roughly 99 568 source vertices expand to about three times that in
  triangles; the exact buffer footprint depends on the driver's vertex format and was not read back.
* **First-frame hitch** from building meshes. Meshes are built lazily per visible country during the
  first `_draw()`, so the first frame of the map does more work than later frames. The benchmark
  measures the cost of building *all* meshes at once as an upper bound, but the distribution across
  frames was not profiled on a device.

## Known limitations that affect cost

* The world view draws every country, because every country is visible. That is the most expensive
  state and the one the map opens in.
* Borders scale with the visible vertex count, not with the number of countries; a future
  simplification pass (strided borders at low zoom) is noted in [ROADMAP.md](../ROADMAP.md) as a
  candidate improvement if a low-end device struggles.
* The atlas is fully resident in memory once the screen is opened (≈1.3 MB of JSON plus parsed
  `Vector2` arrays and meshes). It is not streamed or paged.
