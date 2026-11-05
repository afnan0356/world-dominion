# Performance notes — world atlas

Measured on the development container used for this milestone, with a **headless** Godot 4.6.3
build (`vulkan=no opengl3=no`) compiled from the official 4.6.3-stable source tag. The environment
has no GPU, no display server and no OpenGL/EGL/Vulkan driver, so this document reports **CPU work
and data volume only**. Frame time on real hardware is *not* measured here and is labelled
unverified rather than estimated.

Reproduce with:

```bash
godot --headless --path . res://tools/atlas_benchmark.tscn
```

## Dataset size

| Measurement | Value |
| --- | --- |
| Countries and territories | 242 |
| Polygons (disconnected parts) | 1 620 |
| Rings (outlines + holes) | 1 631 |
| Vertices in the source geometry | 99 568 |
| Coordinate quantisation | 1/200° (0.005°, ≈550 m at the equator) |
| `data/world/geometry.json` | 1 144 KiB |
| `data/world/countries.json` | 93 KiB |
| `data/world/manifest.json` | 2 KiB |
| Total committed runtime data | ≈1.3 MiB |

For scale: the raw 1:50m GeoJSON these files come from is 3.0 MiB, and the 1:10m alternative is
13.3 MiB before any processing.

## Load and construction cost (CPU, headless)

| Operation | Time |
| --- | --- |
| Parse `countries.json` into 242 typed records | 8.7 ms |
| Parse `geometry.json` into 99 568 points | 52.7 ms |
| Build the 10° spatial index | 2.1 ms |
| Total atlas load (`WorldAtlas.load_default()`) | 63.6 ms |
| Build every country's triangle meshes (all 242, both fills and holes) | 1.6 ms, 288 345 mesh vertices |
| Point-in-country hit test (average of 5 000 queries) | 150 µs/query (1 019 of 5 000 sample points on land) |
| Tap resolution **with** the small-country assist (average of 5 000 taps) | 854 µs/query |
| Tap resolution **without** the assist, for comparison | 550 µs/query |
| Registry search (average of 2 000 queries) | 2.6 ms/query — see the note below |
| Scale bar at a fitted world view (1280×720) | 2 000 km across 64 px |
| Static engine memory after load | 31.9 MiB |

These are one run of `res://tools/atlas_benchmark.tscn` on the build container (Godot 4.6.3 headless,
single process, no display). **Run-to-run variance on a shared container is large**: repeated runs of
the same build during this milestone ranged from 55 ms to 102 ms for the total load and 132 µs to
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
* **1 631 rings were measured for triangulation, and one does not triangulate** (`TWN[0]`, Taiwan's
  main island at 1:50m: the source coastline doubles back on itself). The view fills that ring with its
  convex hull instead of leaving a hole in the world. The number is also printed by the benchmark
  (`hull-fallback rings`) so the compromise stays visible.

## Performance budget

Budgets are set from these measurements plus headroom, and are deliberately conservative:

| Metric | Budget | Measured | Status |
| --- | --- | --- | --- |
| Runtime data committed | ≤ 2 MiB | 1.3 MiB | met |
| Full atlas load (CPU) | ≤ 150 ms | 55–102 ms across runs | met |
| Mesh build for the whole world (CPU) | ≤ 8 ms | 1.6–2.2 ms | met |
| Hit test (CPU) | ≤ 500 µs | 132–199 µs | met |
| Tap with the tiny-country assist (CPU) | ≤ 2 ms | 0.85 ms | met |
| Search per keystroke (CPU) | ≤ 5 ms | 2.6–2.7 ms | met |
| Static memory after load | ≤ 96 MiB | 31.9 MiB | met |
| Draw calls per frame at world zoom | ≤ 700 | not measured | **unverified** |
| Frame time at 60 fps on desktop | ≤ 16.6 ms | not measured | **unverified** |
| Frame time at 30 fps on low-end mobile | ≤ 33 ms | not measured | **unverified** |

The two unverified rows need a GPU and a device. They are the numbers that decide whether the map
feels smooth, and no amount of CPU measurement substitutes for them. The design keeps per-frame work
small (cached meshes, culled borders, ≤26 labels, ocean labels only at world zoom) but that is an
argument, not evidence.

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
  renderer draws nothing, so any frame-time figure would be invented. The design decisions above are
  made to keep per-frame work small, but they are not a measurement.
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
