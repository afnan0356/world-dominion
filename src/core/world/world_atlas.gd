class_name WorldAtlas
extends RefCounted
## Everything the map needs, assembled once: country records, geometry, a
## spatial index and the data-source manifest.
##
## This is the seam between *data* and *presentation*. A screen creates an atlas
## and hands it to the map view; the map view never reads JSON and the registry
## never learns about polygons. That also makes the whole pipeline testable
## headlessly in a few milliseconds.

const MANIFEST_PATH := "res://data/world/manifest.json"

var registry: CountryRegistry
var geometry: WorldGeometry
var lookup: CountryLookup
var manifest: Dictionary = {}
## Sourced reference figures. Read-only and independent of the simulation: no system
## mutates it, no save contains it. Screens show it; the game only reads it.
var statistics: CountryStatistics
var load_milliseconds := 0.0


static func load_default() -> WorldAtlas:
	return load_from(CountryRegistry.DEFAULT_PATH, WorldGeometry.DEFAULT_PATH)


## Loads an atlas from explicit paths. Missing geometry is tolerated: the
## registry still answers questions, the map simply has nothing to draw, and
## `issues()` says so instead of the game falling over.
static func load_from(registry_path: String, geometry_path: String,
		manifest_path: String = MANIFEST_PATH) -> WorldAtlas:
	var started := Time.get_ticks_usec()
	var atlas := WorldAtlas.new()
	atlas.registry = CountryRegistry.from_file(registry_path)
	atlas.geometry = WorldGeometry.from_file(geometry_path)
	if atlas.geometry.is_loaded():
		atlas.lookup = CountryLookup.new(atlas.geometry)
	atlas.manifest = DataLoader.load_dictionary(manifest_path)
	atlas.statistics = CountryStatistics.load_default()
	atlas.load_milliseconds = float(Time.get_ticks_usec() - started) / 1000.0
	return atlas


## Builds an atlas from already-parsed data; used by tests.
static func from_data(countries: Variant, geometry: Variant) -> WorldAtlas:
	var atlas := WorldAtlas.new()
	atlas.registry = CountryRegistry.from_data(countries)
	atlas.geometry = WorldGeometry.from_data(geometry)
	if atlas.geometry.is_loaded():
		atlas.lookup = CountryLookup.new(atlas.geometry)
	return atlas


func is_ready() -> bool:
	return registry != null and registry.is_loaded() and geometry != null \
			and geometry.is_loaded()


func country_count() -> int:
	return 0 if registry == null else registry.count()


## Country ids that exist in the registry but have no drawable shape, and vice
## versa. Both lists are empty for a consistent dataset; the data test asserts
## it, the map degrades gracefully if it ever stops being true.
func unshaped_country_ids() -> PackedStringArray:
	var out := PackedStringArray()
	if registry == null or geometry == null:
		return out
	for record: CountryRecord in registry.all():
		if not geometry.has_country(record.id):
			out.append(record.id)
	return out


func orphan_geometry_ids() -> PackedStringArray:
	var out := PackedStringArray()
	if registry == null or geometry == null:
		return out
	for country_id: String in geometry.country_ids():
		if not registry.has_country(country_id):
			out.append(country_id)
	return out


func issues() -> PackedStringArray:
	var out := PackedStringArray()
	if registry != null:
		out.append_array(registry.issues())
	if geometry != null:
		out.append_array(geometry.issues())
	return out


## One-line attribution suitable for a UI footer.
func attribution() -> String:
	var source: Variant = manifest.get("source")
	if not source is Dictionary:
		return "Country data: Natural Earth (public domain)"
	var entry: Dictionary = source
	return "%s · %s · public domain" % [
		str(entry.get("dataset", "Natural Earth")),
		str(entry.get("version", "")),
	]


## Human-readable dataset summary for the About/setup screens.
func describe_dataset() -> String:
	var source: Variant = manifest.get("source")
	var counts: Variant = manifest.get("counts")
	if not source is Dictionary or not counts is Dictionary:
		return ""
	var entry: Dictionary = source
	var total: Dictionary = counts
	return "%d countries · %d polygons · %s vertices · %s @ %s" % [
		int(total.get("countries", 0)),
		int(total.get("polygons", 0)),
		String.num(int(total.get("vertices", 0))),
		str(entry.get("version", "unknown version")),
		str(entry.get("retrieved", "unknown date")),
	]
