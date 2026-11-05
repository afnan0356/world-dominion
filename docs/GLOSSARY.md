# Glossary

Plain-language explanations of the technical terms used in this project's documentation. Written for
a reader who is new to game development — the owner of this project — and kept alphabetical so it can
be looked up rather than read front to back.

Where a term is specific to a tool we use, the tool is named.

---

**ADM0 / admin-0** — "administrative level zero": the top level of a country map, i.e. whole countries
and territories rather than provinces. The atlas is built from an admin-0 dataset.

**Antimeridian** — the 180° meridian in the Pacific, where longitude wraps from +180° to −180°. Shapes
that cross it look enormous on a flat map (Russia, Fiji, the United States). Our pipeline splits such
shapes into pieces at the line so nothing stretches across the whole world.

**Atlas / world atlas** — in this project, the three committed files (`countries.json`, `geometry.json`,
`manifest.json`) plus the code that loads them. "The atlas" is the game's world: who exists and where
their borders are.

**Autoload (Godot)** — a script Godot starts once, before any screen, so every screen can use it. We
have two: `Settings` (which remembers your preferences) and `ThemeManager` (which applies the chosen
colours). They are declared in `project.godot`.

**baked / cached mesh** — pre-computed triangles that the graphics card can draw immediately. We
triangulate each country once and reuse the result, which is why panning the map is cheap.

**benchmark** — a script that measures how long something takes, so a claim like "loading takes 64 ms"
can be checked instead of guessed. Ours is `tools/atlas_benchmark.tscn`.

**bbox (bounding box)** — the smallest rectangle that contains a shape, written as
`[min_lon, min_lat, max_lon, max_lat]`. Used to skip shapes that are off-screen quickly.

**CI (continuous integration)** — GitHub Actions: every push runs linting, data validation and the test
suite automatically. A red CI run means the branch is not mergeable.

**class_name (GDScript)** — a line that gives a script a globally usable name, e.g.
`class_name StartEligibility`. Other scripts can then refer to the type without preloading a path.

**dossier** — the country information panel in the game: sourced sections (overview, geography,
administration, sources) plus clearly marked sections that are not implemented yet.

**deterministic** — same input, same result, every time. The 30-second stress test is deterministic
because the camera path is computed from elapsed time, not from random numbers.

**dequantise** — turn the stored small integers back into degrees. Coordinates are stored as
`round(degrees × 200)` to halve the file size; dividing by 200 recovers the coordinate.

**elision / ellipsis** — shortening text with "…" when there is no room. Used for long country names in
narrow layouts.

**frame / frame time** — one picture drawn by the game, and how many milliseconds it took. 16.7 ms gives
60 frames per second; 33.4 ms gives 30. A "p95" (95th-percentile) frame time means 95% of frames were
at least that fast.

**gdlint** — the linter for GDScript (part of *gdtoolkit*). It enforces style rules, e.g. maximum line
length. `gdlint` failing blocks a merge.

**GeoJSON** — a text format for geographic shapes (a JSON file of coordinates). This is what Natural
Earth publishes and what our build script reads.

**headless** — running Godot without a window or graphics card. Used for the test suite and benchmarks,
which is why this project can measure CPU work but not frame rate.

**hull fallback** — if a shape cannot be turned into triangles, we fill it with its convex hull (the
"shrink-wrapped" outline) instead of deleting it. The benchmark reports how often this happens; after
the Taiwan repair it is zero.

**ISO alpha-2 / alpha-3** — the two- and three-letter country codes (`BD`, `BGD`). When the source data
has no valid code we store `null` and the game says so, rather than inventing one.

**LOD (level of detail)** — showing less detail when it would not be visible anyway, e.g. thinner
borders or fewer labels when zoomed out.

**linting** — automatic checking of code style and obvious mistakes.

**manifest** — `data/world/manifest.json`: where the data came from, which commit, what the build did,
how many things it produced, and what is known to be imperfect. It is the atlas's receipt.

**Natural Earth** — the public-domain map dataset this project uses (1:50m scale). Its own fields
(`TYPE`, `SOVEREIGNT`, `NOTE`) are reproduced verbatim; see
[`DISPUTED_TERRITORIES.md`](DISPUTED_TERRITORIES.md).

**overlay (UI)** — a panel drawn on top of a screen without moving its layout. The performance overlay
and the search results list are both overlays.

**polygon / ring** — a polygon is one landmass; its first ring is the outline and any further rings are
holes (lakes). Ring 0 is always the outline in our files.

**quantisation** — rounding coordinates to a fixed grid (1/200 of a degree here) so files are smaller
and results are identical on every platform.

**RefCounted (Godot)** — a base class for objects that are freed automatically when nothing uses them.
Most of our data classes (records, configs, test suites) extend it.

**regression test** — a test that exists to stop a fixed bug or a promised behaviour from silently
coming back.

**responsive layout** — one interface that rearranges itself for phone, tablet and desktop rather than
having separate builds. Our tokens: compact below 620 px, medium, expanded from 1024 px.

**scene (.tscn)** — Godot's saved arrangement of nodes (a screen, a component). Screens in `src/ui/` are
scenes with a script attached.

**schema version** — the integer at the top of every data file. Adding a field is safe; removing or
changing the meaning of one requires bumping it so old readers fail loudly.

**self-intersection (hairpin)** — a shape whose outline crosses itself. Angles like this break
triangulation, so the build repairs them and records each repair.

**signal (Godot)** — an event a node emits so other parts of the game can react ("a country was
selected"). Signals keep the map from needing to know who is listening.

**source commit (pinned)** — the exact Git commit of Natural Earth we build from
(`ca96624a56bd078437bca8184e78163e5039ad19`). Pinning it is what makes a rebuild byte-identical.

**stable ID** — the identifier that never changes (`BGD`), used to join data between files. Display
names may change; IDs may not.

**stress test** — the 30-second camera run that measures frame times on a real device and prints a
verdict. Started from Settings → Advanced / Developer.

**SubViewport** — an off-screen drawing area used by the tests to lay out a screen at a specific size
without showing it.

**triangulation** — splitting a polygon into triangles, which is what a graphics card draws. If a shape
is malformed, triangulation fails — that is what the Taiwan repair fixed.

**UNVERIFIED (project convention)** — a claim, usually about frame time, that has *not* been measured on
a real device. It is written in capitals and never softened into an estimate.

**validator** — `tools/validate_world_atlas.py`: the script that audits the atlas and regenerates
[`DATA_QUALITY.md`](DATA_QUALITY.md). It fails the build on a real error and reports honest gaps.

**viewport** — the drawing area of the window; the map's visible rectangle.

**WCAG AA** — the accessibility contrast standard (4.5:1 for normal text). Tests assert contrast for
every text/surface pair in both palettes.

**Word wrap** — breaking long text onto several lines instead of clipping it.
