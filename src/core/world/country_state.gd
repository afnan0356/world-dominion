class_name CountryState
extends RefCounted
## The **baseline** every country starts a campaign from, and nothing else.
##
## WHAT IS HERE, AND WHAT IS NOT
##
## A country's story has two layers, and this class exists to keep them apart:
##
## * **Baseline** — the sourced starting figures: population, GDP, area and currency, each with
##   the year it refers to and the dataset it came from. These never change during a campaign.
##   They are *this* class, and this class has no write path at all: no setter, no `write_`,
##   no way for a system to nudge a figure. A test proves that by looking for one.
## * **Live state** — everything a campaign changes: money spent, policies passed, buildings
##   built. That lives in `WorldState.countries[id]["sections"]` and, at this milestone, is
##   still empty because no system that would change it exists yet.
##
## A save therefore does **not** carry 242 copies of the baseline. It carries a *reference* —
## the dataset's id, commit, schema and a digest of the values — plus a small override layer
## for anything a campaign deliberately changes later. On load the baseline is rebuilt from the
## shipped data and the reference is checked against it; when the shipped data has changed
## since the save was written, `BaselineIntegritySystem` says so in the campaign's own log
## instead of quietly showing different figures under the same name.
##
## MISSING IS NOT ZERO
##
## A figure the source does not give is `{"value": null, "text": "Not available"}`. It is never
## `0`, because a zero is a claim ("the source says nobody lives here") and it is true for two
## records in this dataset. `missing_counts()` reports how many records lack each figure, which
## is the number the project publishes, not a silent gap.

const SCHEMA_VERSION := 1
const MISSING_TEXT := "Not available"
const CURRENCY_PATH := "res://data/world/currency_crosswalk.json"
## The order and wording of the figures, kept beside the code that formats them, as
## `CountryStatistics` does for its own display.
const FIELDS := ["population", "gdp", "area", "currency"]

## Built once per run for the save layer; tests build their own with `initialise()`.
static var _shared: CountryState = null

var schema := SCHEMA_VERSION
var _records: Dictionary = {}
var _ids: PackedStringArray = []
var _reference: Dictionary = {}


## A freshly built baseline from the shipped data. `statistics` may be passed in by a test;
## production callers use `shared()`.
static func initialise(statistics: CountryStatistics = null) -> CountryState:
	var state := CountryState.new()
	state._build(statistics)
	return state


## The process-wide baseline. Rebuilding 242 records for every campaign creation would be
## wasteful and pointless: the data cannot change while the game runs.
static func shared() -> CountryState:
	if _shared == null:
		_shared = initialise(null)
	return _shared


## Drops the process-wide baseline. Only the test harness calls this, once per suite, so one
## suite cannot hand the next a baseline it built from different input: the shared instance is
## the single piece of module state a campaign depends on, and a suite that mutated or
## instrumented it would otherwise change what every later suite sees.
static func reset_shared() -> void:
	_shared = null


## The save section for a campaign that starts now: a reference to the data, and an empty
## override layer. Written here, in one place, because "how a campaign is initialised" is a
## documented rule (`docs/SAVE_FORMAT.md`), not something each caller improvises.
static func save_section() -> Dictionary:
	var baseline := shared()
	return {
		"version": SCHEMA_VERSION,
		"data": baseline.data_reference(),
		"overrides": {},
	}


func _build(statistics: CountryStatistics) -> void:
	var stats := statistics if statistics != null else CountryStatistics.load_default()
	var currencies := _currency_entries()
	var ids := stats.country_ids()
	for country_id: String in currencies.keys():
		if not ids.has(country_id):
			ids.append(country_id)
	ids.sort()
	var missing := {"population": 0, "gdp": 0, "area": 0, "currency": 0}
	var matched_currency := 0
	var compact := {}
	for country_id: String in ids:
		var record := {
			"id": country_id,
			"population": _figure(stats, country_id, "population", "people"),
			"gdp": _figure(stats, country_id, "gdp_usd", "US dollars"),
			"area": _figure(stats, country_id, "area_km2", "square kilometres"),
			"currency": _currency(country_id, currencies),
		}
		for field: String in FIELDS:
			var entry: Dictionary = record[field]
			if str(entry.get("state", "")) == "missing":
				missing[field] = int(missing[field]) + 1
		if str((record["currency"] as Dictionary).get("state", "")) != "missing":
			matched_currency += 1
		_records[country_id] = record
		compact[country_id] = [
			(record["population"] as Dictionary).get("value"),
			(record["gdp"] as Dictionary).get("value"),
			(record["area"] as Dictionary).get("value"),
			(record["currency"] as Dictionary).get("code"),
		]
	_ids = ids
	_reference = {
		"schema": SCHEMA_VERSION,
		"statistics": {
			"schema": stats.schema,
			"source": str(stats.source.get("id", "")),
			"commit": str(stats.source.get("commit", "")),
			"records": stats.count(),
		},
		"currency": {
			"source": "cldr-core (ISO 4217 codes)",
			"matched": matched_currency,
			"records": ids.size(),
		},
		"records": ids.size(),
		"missing": missing,
		"digest": CanonicalJson.sha256({"schema": SCHEMA_VERSION, "values": compact}),
	}


## One sourced figure, or an explicit gap. `stats.value()` returns null when the source has
## nothing, which is the only honest signal available here.
func _figure(stats: CountryStatistics, country_id: String, key: String, unit: String) -> Dictionary:
	var value: Variant = stats.value(country_id, key)
	if value == null:
		return {
			"value": null,
			"text": MISSING_TEXT,
			"unit": unit,
			"state": "missing",
			"reason": "the source has no %s figure for this record" % key,
		}
	var entry := stats.figure(country_id, key)
	var derived := bool(entry.get("derived", false))
	return {
		"value": int(value),
		"text": stats.describe(country_id, {"key": key, "unit": unit}),
		"unit": unit,
		"state": "derived" if derived else "sourced",
		"year": stats.year(country_id, key),
		"as_of": stats.as_of_label(country_id, key),
		"source": str(stats.source.get("id", "")),
		"source_field": str(entry.get("source_field", "")),
	}


func _currency(country_id: String, currencies: Dictionary) -> Dictionary:
	var entry: Variant = currencies.get(country_id, {})
	var code := ""
	if entry is Dictionary:
		code = str((entry as Dictionary).get("iso_4217", ""))
	if code.is_empty():
		return {
			"code": null,
			"text": MISSING_TEXT,
			"unit": "ISO 4217",
			"state": "missing",
			"reason": "the record has no ISO 3166-1 code of its own, so no currency is claimed",
		}
	return {
		"code": code,
		"text": code,
		"unit": "ISO 4217",
		"state": "sourced",
		"source": "cldr-core",
	}


func _currency_entries() -> Dictionary:
	var data: Variant = DataLoader.load_json(CURRENCY_PATH)
	if data is Dictionary:
		var entries: Variant = (data as Dictionary).get("entries")
		if entries is Dictionary:
			return entries
	return {}


## Every record, in the stable order the campaign was initialised with.
func country_ids() -> PackedStringArray:
	return _ids.duplicate()


func count() -> int:
	return _records.size()


func has(country_id: String) -> bool:
	return _records.has(country_id)


## A record's baseline, as a copy: a caller cannot edit the baseline by accident, which is the
## whole point of calling it read-only.
func baseline(country_id: String) -> Dictionary:
	if not _records.has(country_id):
		return {}
	return (_records[country_id] as Dictionary).duplicate(true)


## The integer value of one figure, or null when it is missing. The one call a system is
## allowed: anything that wants a country's population asks here, and gets null if the data
## does not say.
func value(country_id: String, field: String) -> Variant:
	var record := baseline(country_id)
	if record.is_empty():
		return null
	var entry: Variant = record.get(field)
	if not entry is Dictionary:
		return null
	if field == "currency":
		# A currency is a code, not a number: the field has `code` where the others have
		# `value`, and both use null for "not available".
		return (entry as Dictionary).get("code")
	return (entry as Dictionary).get("value")


## The reference a save stores: what dataset, which commit, how many records, and a digest of
## every value. `BaselineIntegritySystem` compares this with the reference of the data the game
## is running now, which is how a changed dataset is noticed rather than hidden.
## (Not `reference()`: that name belongs to the engine's `RefCounted` and overriding it is a
## parse error, which the first CI run of this milestone found the honest way.)
func data_reference() -> Dictionary:
	return _reference.duplicate(true)


func digest() -> String:
	return str(_reference.get("digest", ""))


## How many records lack each figure. Published numbers, not a guess at a global total.
func missing_counts() -> Dictionary:
	var counts: Variant = _reference.get("missing", {})
	return (counts as Dictionary).duplicate(true) if counts is Dictionary else {}
