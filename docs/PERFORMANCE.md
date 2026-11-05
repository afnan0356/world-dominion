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
| Parse `countries.json` into 242 typed records | 7.8 ms |
| Parse `geometry.json` into 99 568 points | 45.8 ms |
| Build the 10° spatial index | 2.0 ms |
| Total atlas load (`WorldAtlas.load_default()`) | 55.6 ms |
| Build every country's triangle meshes (all 242, both fills and holes) | 1.7 ms, 288 345 mesh vertices |
| Point-in-country hit test (average of 5 000 queries) | 132 µs/query (1 019 of 5 000 sample points on land) |
| Registry search (average of 2 000 queries) | 2.3 ms/query — see the note below |
| Static engine memory after load | 31.7 MiB |

These are one run of `res://tools/atlas_benchmark.tscn` on the build container (Godot 4.6.3 headless,
single process, no display). They are indicative, not a benchmark suite: there is no averaging over
runs and the container is shared. Re-run the command above to regenerate them.

Two honest notes:

* **Search at 2.3 ms/query is the slowest operation measured.** The benchmark searches the loose term
  `"a"` on odd iterations, which matches a large share of the 242 records and therefore measures the
  worst case for substring ranking rather than a typical query. It is a keypress-frequency cost, not a
  per-frame one, and 2.3 ms of CPU per keystroke is acceptable; it is still the first thing to look at
  if search ever feels slow.
* **1 631 rings were measured for triangulation, and one does not triangulate** (`TWN[0]`, Taiwan's
  main island at 1:50m: the source coastline doubles back on itself). The view fills that ring with its
  convex hull instead of leaving a hole in the world. The number is also printed by the benchmark
  (`hull-fallback rings`) so the compromise stays visible.

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
* Labels are limited to 26, chosen by the dataset's own `LABELRANK`, with overlap rejection.

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
