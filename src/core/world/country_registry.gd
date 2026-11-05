class_name CountryRegistry
extends RefCounted
## In-memory catalogue of every country the atlas can select.
##
## The registry is deliberately ignorant of the map, the renderer and the UI: it
## parses `data/world/countries.json` into typed records, keeps them indexed by
## stable id, and answers search/filter queries. Anything that draws or lays out
## geography asks the registry for a record; nothing here knows what a polygon
## or a screen coordinate is.

const DEFAULT_PATH := "res://data/world/countries.json"
## Filter regions the interface offers, in display order. These are dataset
## classifications, not something the interface invents.
const FILTER_REGIONS: PackedStringArray = [
	"Africa", "Asia", "Europe", "North America", "Oceania", "South America",
]

## Latin diacritics that occur in the dataset's country names. Anything else is
## passed through unchanged, so an unmatched character simply does not match.
const ACCENT_FOLDS := {
	"à": "a", "á": "a", "â": "a", "ã": "a", "ä": "a", "å": "a", "ā": "a",
	"ç": "c", "ć": "c", "č": "c",
	"è": "e", "é": "e", "ê": "e", "ë": "e", "ē": "e", "ę": "e",
	"ì": "i", "í": "i", "î": "i", "ï": "i", "ī": "i",
	"ñ": "n", "ń": "n",
	"ò": "o", "ó": "o", "ô": "o", "õ": "o", "ö": "o", "ø": "o", "ō": "o",
	"š": "s", "ß": "ss",
	"ù": "u", "ú": "u", "û": "u", "ü": "u", "ū": "u",
	"ý": "y", "ÿ": "y",
	"ž": "z", "ł": "l", "đ": "d", "þ": "th", "æ": "ae", "œ": "oe",
}


var _records: Array[CountryRecord] = []
var _by_id: Dictionary = {}
var _by_region: Dictionary = {}
var _issues: PackedStringArray = []


## Loads the registry from disk. Never throws: a missing or malformed file
## yields an empty registry whose `issues()` explain what happened.
static func from_file(path: String = DEFAULT_PATH) -> CountryRegistry:
	var data: Variant = DataLoader.load_json(path)
	return from_data(data, path)


static func from_data(data: Variant, source: String = "inline") -> CountryRegistry:
	var registry := CountryRegistry.new()
	if not data is Dictionary:
		registry._issues.append("%s: expected a JSON object" % source)
		return registry
	var entries: Variant = (data as Dictionary).get("countries")
	if not entries is Array:
		registry._issues.append("%s: missing 'countries' array" % source)
		return registry
	for entry: Variant in entries:
		var record := CountryRecord.from_dict(entry)
		if record == null:
			registry._issues.append("%s: skipped a record without a valid id/name" % source)
			continue
		if registry._by_id.has(record.id):
			registry._issues.append("%s: duplicate id '%s' ignored" % [source, record.id])
			continue
		for problem: String in record.issues:
			registry._issues.append("%s [%s]: %s" % [source, record.id, problem])
		registry._records.append(record)
		registry._by_id[record.id] = record
		for region: String in _regions_of(record):
			if not registry._by_region.has(region):
				registry._by_region[region] = []
			(registry._by_region[region] as Array).append(record)
	for region: String in registry._by_region:
		var list: Array = registry._by_region[region]
		list.sort_custom(func(left: CountryRecord, right: CountryRecord) -> bool:
			return left.name.naturalnocasecmp_to(right.name) < 0)
	return registry


static func _regions_of(record: CountryRecord) -> PackedStringArray:
	if record.filter_region and not record.region.is_empty():
		return PackedStringArray([record.region])
	return PackedStringArray()


func is_loaded() -> bool:
	return not _records.is_empty()


func count() -> int:
	return _records.size()


func all() -> Array[CountryRecord]:
	return _records


func issues() -> PackedStringArray:
	return _issues


func has_country(country_id: String) -> bool:
	return _by_id.has(country_id)


## The record for `country_id`, or null. Callers must handle null: an unknown id
## is a normal outcome (saved data from an older build, a typo in a test).
func get_country(country_id: String) -> CountryRecord:
	return _by_id.get(country_id) as CountryRecord


func ids() -> PackedStringArray:
	var out := PackedStringArray()
	for record: CountryRecord in _records:
		out.append(record.id)
	return out


## Regions that actually contain records, in the documented filter order.
func regions() -> PackedStringArray:
	var out := PackedStringArray()
	for region: String in FILTER_REGIONS:
		if _by_region.has(region):
			out.append(region)
	return out


func region_count(region: String) -> int:
	var list: Variant = _by_region.get(region)
	return 0 if list == null else (list as Array).size()


## Records in `region`; an unknown or empty region returns every record.
func by_region(region: String) -> Array[CountryRecord]:
	if region.is_empty():
		return _records
	var list: Variant = _by_region.get(region)
	if list == null:
		return []
	var out: Array[CountryRecord] = []
	for record: CountryRecord in list:
		out.append(record)
	return out


## Case-insensitive, accent-insensitive search across name, long name and ISO
## codes. Matching happens against a folded key produced by the offline data
## pipeline, so "cote" finds "Côte d'Ivoire" without the runtime having to
## normalise Unicode.
func search(query: String) -> Array[CountryRecord]:
	var needle := _fold(query)
	if needle.is_empty():
		return _records
	var matches: Array[CountryRecord] = []
	for record: CountryRecord in _records:
		if _matches(record, needle):
			matches.append(record)
	# An exact ISO code beats a substring match on a name: typing "BD" must offer
	# Bangladesh first even though "Burundi" also contains those letters.
	matches.sort_custom(func(left: CountryRecord, right: CountryRecord) -> bool:
		return _rank(left, needle) < _rank(right, needle))
	return matches


## Lower is better: exact code, then code prefix, then anything else.
static func _rank(record: CountryRecord, needle: String) -> int:
	if record.iso_a2.to_lower() == needle or record.iso_a3.to_lower() == needle:
		return 0
	if record.name.to_lower() == needle:
		return 1
	if record.iso_a3.to_lower().begins_with(needle) or record.iso_a2.to_lower() \
			.begins_with(needle):
		return 2
	return 3


## Combined query + region filter: the intersection, never the union.
func filter(query: String, region: String) -> Array[CountryRecord]:
	var needle := _fold(query)
	var base: Array[CountryRecord] = by_region(region)
	var out: Array[CountryRecord] = []
	for record: CountryRecord in base:
		if needle.is_empty() or _matches(record, needle):
			out.append(record)
	return out


func _matches(record: CountryRecord, folded_needle: String) -> bool:
	if record.search_key.contains(folded_needle):
		return true
	# A record may be hand-authored without a search key; fall back to the name.
	return record.name.to_lower().contains(folded_needle)


## Lowercase, accent-free folding of the *query*, mirroring the pipeline's
## `fold()` so typing "Côte" matches the stored key "cote d'ivoire".
static func _fold(text: String) -> String:
	var lowered := text.strip_edges().to_lower()
	var out := ""
	for index in lowered.length():
		var character := lowered[index]
		out += ACCENT_FOLDS.get(character, character)
	return out




func region_label(region: String) -> String:
	return region if not region.is_empty() else "All regions"
