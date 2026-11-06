# Glossary

Plain-language explanations of the technical terms used in this project's documentation. Written for
a reader who is new to game development — the owner of this project — and kept alphabetical so it can
be looked up rather than read front to back.

Where a term is specific to a tool we use, the tool is named.

---

**as-of year** — the year a figure refers to. The source this project uses is not live, so every number carries its own year ("163,046,161 people (2019)") and the game never shows a figure without it.

**attribution** — the credit a licence asks for, or that a project gives anyway. Natural Earth's data is public domain, so no credit is legally required; the game prints "Made with Natural Earth" because a reader deserves to know where the lines came from.

**autosave** — a save the game writes for you, without asking. Ours is written once per in-game
month and when you leave the campaign, into its own slot, so it never overwrites your manual saves.

**atomic write** — writing a new file somewhere safe first, checking it, and only then swapping it
into place, so a crash mid-write cannot destroy the old file. Used for every save.

**baseline reference data** — a starting fact, not a live one: the population and GDP a country has when a 2026 scenario begins. No system in the game changes these numbers, and they are never presented as current.

**canonical JSON** — JSON written in exactly one fixed way: keys sorted, integers and decimals kept
distinct. Two identical states then always produce identical bytes, which is what makes a checksum
and a state hash meaningful.

**checksum** — a fingerprint of a file's contents, used to detect damage. If one byte changes, the
checksum no longer matches and the game refuses the save instead of loading nonsense.

**crosswalk** — a small committed file that says which row of a source belongs to which record in our data (our `PSE` is the source's `PSX`, for example). The join is on codes, never on names, because names differ between datasets and are translated.

**derived value** — a number the project calculates instead of copying. A country's area here is derived from the outline the map draws, so it is approximate; every screen that shows it says "derived".

**deterministic** — the same inputs always produce the same result. In this game: the same seed and
the same player actions always produce the same world, on every device. Needed for testing, for bug
reports and for any future replay feature.

**easing** — how an animation speeds up or slows down. "Cubic out" starts quickly and settles gently, which is why the interface uses it for panels and camera moves.

**event bus** — a way for one part of the simulation to announce "the month started" without knowing
who cares. Listeners subscribe; publishers never call listeners directly. Ours delivers queued events
in a fixed order and never in the middle of another handler.

**exact integer** — a whole number with nothing after the decimal point. Population and dollars are stored this way, and a source value such as `10192317.3` is rejected rather than rounded, because rounding would invent precision the source does not have.

**flash limit** — the rule that nothing in the interface changes visibly more than three times a second. Anything faster is unpleasant and can be a health risk; the animation table declares a flash count per animation and the generator refuses to document anything above the limit.

**frame** — one pass of the game loop, ending in one picture on screen. Frames are not time: a slow
device produces fewer, longer frames.

**game clock / tick** — the heartbeat of the simulation. One **tick** is one in-game day. A speed is
a number of ticks per real second, never a number of ticks per frame.

**in-game date / day index** — the date inside the campaign. Stored as an integer count of days since
1 January of year 1, so the arithmetic is exact and a save can resume on exactly the right day.

**leap year** — a year with 29 February: divisible by 4, except centuries that are not divisible by
400. 2024 is one; 1900 is not; 2000 is.

**migration (save)** — upgrading an older save file's *shape* to the current one, one version at a
time, so an old campaign keeps working. Migrations never move data downward: a save from a newer
build is refused and left untouched.

**named random stream** — a separate random-number sequence per purpose ("economy", "weather"),
derived from the campaign seed and the stream's name. Adding a new system cannot shift the numbers
another system receives.

**playtime** — real seconds spent in a campaign. Saved, shown in the load list, and deliberately
excluded from the state hash because it is not game state.

**public domain** — a work with no licence conditions attached. Natural Earth's map data is public domain, which is why a project like this can ship it without paperwork.

**reduced motion** — a setting that removes animation for players who find it uncomfortable. Every
animation we add must have a reduced-motion form; usually that means appearing instantly. Under it
the animation service applies the final value at once, starts no tween at all, and never starts a
looping animation. `docs/ANIMATION.md` lists the answer for each animation.

**SaveStore** — the one place that writes and reads save files. Screens ask it; they never touch
`user://` themselves.

**schema / schema version** — the *shape* of a file, and a number saying which shape it is. Changing
the shape means a new number plus a migration. Our save schema is 2; schema 1 (an earlier draft) is
still readable.

**seed** — a number that initialises randomness. The same seed reproduces the same world. A new
campaign's seed is derived from the scenario, the chosen country and the start date, so it is
reproducible without the player having to type anything.

**state hash** — a fingerprint of the campaign's dynamic state (clock, seed, streams, wallet, country
sections). Two runs with the same seed must produce the same hash; a save whose hash does not match
its own contents is refused.

**coastline hint** — a one-character code per map ring saying whether that ring is a coastline (`1`),
a border shared with a neighbour (`0`), or a ring that mixes both (`2`). A segment used by one
record is coast, a segment used by two is a shared border; 200 of 242 records have at least one
coastline segment and the other 42 get a plain border with no invented waterline. Stored in
`data/world/coast.json`, generated from the geometry, and used only to decide how heavily to draw a
line. It is a hint, not geography: when it is missing, the map draws plain borders.

**graticule** — the grid of latitude and longitude lines drawn over a map. Ours can be switched off,
and the equator and the two tropics can be switched off separately.

**reference line** — the equator or one of the tropics. Drawn as dashes, in a quieter colour than any
border, because they are a reading aid and not a political line.

**region tint** — the very slight colour difference between countries that the dataset groups into
different world regions. It is a secondary cue: names, coastlines and selection ticks carry the
information a player must be able to read.

**display option** — a map setting that changes what is drawn (labels, borders, capitals, grid,
reference lines, reduced detail) and never what can be tapped. Stored in the settings store, not in a
save.

**minimum marker** — the small dot drawn for a country too small to have visible pixels at the current
zoom. It is a visual affordance only; the pointer still selects whatever the geometry says is under it.

**luminance step** — the guaranteed difference in brightness between two region tints. We check that no
two tints share a value, instead of quoting a contrast ratio a subtle tint cannot reach.

**static vs dynamic state** — static is shipped and read-only (map geometry, country names); dynamic
is played and saved (the clock, the wallet). Saves contain only dynamic state.

**statistics pack** — `data/world/statistics.json`, the whole-world copy of the sourced figures that the game reads. It is generated from the per-record files and compared byte for byte in CI.

**tween** — a short piece of code that changes a value smoothly over time. Every animation in this project is a tween created by one service, which also frees it when the screen closes.

**vintage** — the date or year a statistical release describes. Two sources can disagree about the same country simply because they measured different vintages, which is one reason this project uses one source per figure and never mixes them.

**world data stamp** — a short fingerprint of the shipped world data (source commit, country count,
vertex count and a fingerprint of the country ids) stored in each save, so the game can tell which
data a save expects without copying the map into it.

**`user://` (Godot)** — the per-application folder the game is allowed to write to on every platform.
Saves live under `user://saves`.

**UNVERIFIED** — a label we use for any claim nobody has tested yet, especially anything about phone
performance. It means "we do not know", not "probably fine".

**ADM0 / admin-0** — "administrative level zero": the top level of a country map, i.e. whole countries
and territories rather than provinces. The atlas is built from an admin-0 dataset.

**Antimeridian** — the 180° meridian in the Pacific, where longitude wraps from +180° to −180°. Shapes
that cross it look enormous on a flat map (Russia, Fiji, the United States). Our pipeline splits such
shapes into pieces at the line so nothing stretches across the whole world.

**Atlas / world atlas** — in this project, the three committed files (`countries.json`, `geometry.json`,
`manifest.json`) plus the code that loads them. "The atlas" is the game's world: who exists and where
their borders are.

**Autoload (Godot)** — a script Godot starts once, before any screen, so every screen can use it. We
have three: `Settings` (which remembers your preferences), `Game` (which holds the campaign you are
playing) and `ThemeManager` (which applies the chosen colours). They are declared in `project.godot`.

**baked / cached mesh** — pre-computed triangles that the graphics card can draw immediately. We
triangulate each country once and reuse the result, which is why panning the map is cheap.

**benchmark** — a script that measures how long something takes, so a claim like "loading takes 64 ms"
can be checked instead of guessed. Ours are
`tools/atlas_benchmark.tscn` (map loading) and `tools/sim_benchmark.tscn` (simulation and saves).

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

**damaged save** — a slot the parser refuses: truncated, edited, corrupted, or written by a newer
version. The screen says so in plain words, offers the backup, and never invents values to "repair" it.

**dequantise** — turn the stored small integers back into degrees. Coordinates are stored as
`round(degrees × 200)` to halve the file size; dividing by 200 recovers the coordinate.

**elision / ellipsis** — shortening text with "…" when there is no room. Used for long country names in
narrow layouts.

**export / import (save)** — writing a copy of a save to a file you choose, and reading one back.
Imports are validated exactly like a normal load and never overwrite a slot without asking.

**frame / frame time** — one picture drawn by the game, and how many milliseconds it took. 16.7 ms gives
60 frames per second; 33.4 ms gives 30. A "p95" (95th-percentile) frame time means 95% of frames were
at least that fast.

**guide (first-run)** — the short in-game explanation of the controls, shown once, skippable, and
re-openable from the pause menu. The full tutorial is deferred.

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

**rolling backup** — the one previous good copy of a save kept next to it (`<slot>.bak.json`). If a
write is interrupted, the backup is still there to fall back to.

**scene (.tscn)** — Godot's saved arrangement of nodes (a screen, a component). Screens in `src/ui/` are
scenes with a script attached.

**schema version** — the integer at the top of every data file. Adding a field is safe; removing or
changing the meaning of one requires bumping it so old readers fail loudly.

**self-intersection (hairpin)** — a shape whose outline crosses itself. Angles like this break
triangulation, so the build repairs them and records each repair.

**signal (Godot)** — an event a node emits so other parts of the game can react ("a country was
selected"). Signals keep the map from needing to know who is listening.

**slot** — one numbered save position (1–3) plus the autosave slot. A slot holds one campaign.

**source commit (pinned)** — the exact Git commit of Natural Earth we build from
(`ca96624a56bd078437bca8184e78163e5039ad19`). Pinning it is what makes a rebuild byte-identical.

**stable ID** — the identifier that never changes (`BGD`), used to join data between files. Display
names may change; IDs may not. The same ID appears in the dataset, the per-country folder, a save
file, the map inspector and a bug report, which is what makes a report reproducible.

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
