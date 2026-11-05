class_name StartEligibility
extends RefCounted
## Which records a player may start a campaign as, decided in one data file.
##
## Every record in the atlas can be browsed, searched, viewed on the map and read
## in the dossier. Starting a campaign is narrower: this build allows the source
## types listed in `data/world/start_eligibility.json`. The rule lives here and in
## that file so the owner can widen or narrow it by editing one list — there are
## no scattered `if country_id == …` checks anywhere in the code.
##
## The rule is a **default for review, not a final design decision** and it encodes
## no opinion about any place: it is expressed only in the dataset's own `type`
## strings, never in specific country ids.

const PATH := "res://data/world/start_eligibility.json"

## Used when the data file is missing or unreadable, and documented in
## docs/START_NATIONS.md. Failing to an empty rule would silently make every record
## ineligible; failing to these three types degrades to the shipped policy.
const DEFAULT_TYPES: PackedStringArray = ["Sovereign country", "Country", "Sovereignty"]
const DEFAULT_REASON := "Not available as a starting nation in this version."

## One shared instance so the shipped data file is the single source of truth for
## every validation path, including tests that never load the campaign screen.
static var _cached: StartEligibility = null

var _types: PackedStringArray = []
var _reason := DEFAULT_REASON
var _note := ""
var _issues: PackedStringArray = []
var _loaded := false


static func from_file(path: String = PATH) -> StartEligibility:
	var rules := StartEligibility.new()
	var data: Variant = DataLoader.load_json(path)
	if data is Dictionary:
		rules._apply(data)
	else:
		rules._issues.append("%s: could not be read; using the built-in default rule" % path)
		rules._apply_defaults()
	return rules


## The rules the game is running with. Loaded once from disk, so editing
## `data/world/start_eligibility.json` changes both the interface and validation.
static func rules() -> StartEligibility:
	if _cached == null:
		_cached = from_file()
	return _cached


## Drops the cache; used by tests and by a future settings action.
static func reload() -> StartEligibility:
	_cached = from_file()
	return _cached


## Built-in rules without touching the disk; the documented fallback when the data
## file is missing, and a deterministic fixture for tests.
static func built_in() -> StartEligibility:
	var rules := StartEligibility.new()
	rules._apply_defaults()
	return rules


func _apply_defaults() -> void:
	_types = DEFAULT_TYPES.duplicate()
	_reason = DEFAULT_REASON
	_loaded = true


func _apply(data: Dictionary) -> void:
	var entries: Variant = data.get("eligible_types")
	var collected := PackedStringArray()
	if entries is Array:
		for entry: Variant in entries:
			var text := str(entry).strip_edges()
			if not text.is_empty() and not collected.has(text):
				collected.append(text)
	if collected.is_empty():
		_issues.append("start_eligibility.json lists no eligible types; using the default rule")
		_apply_defaults()
		return
	_types = collected
	_reason = str(data.get("reason", DEFAULT_REASON)).strip_edges()
	if _reason.is_empty():
		_reason = DEFAULT_REASON
	_note = str(data.get("note", "")).strip_edges()
	_loaded = true


func eligible_types() -> PackedStringArray:
	return _types


## The neutral sentence shown when a record cannot start a campaign. It states a
## limit of this version, never a judgement about the place.
func reason() -> String:
	return _reason


## Owner-facing explanation of the rule, shown in the dossier footer and docs.
func note() -> String:
	return _note


func issues() -> PackedStringArray:
	return _issues


func is_eligible(record: CountryRecord) -> bool:
	if record == null:
		return false
	return _types.has(record.type)


## True when the atlas contains at least one eligible record; a guard against a
## rule file that would make the game impossible to start.
func has_any_eligible(registry: CountryRegistry) -> bool:
	if registry == null:
		return false
	for record: CountryRecord in registry.all():
		if is_eligible(record):
			return true
	return false


func eligible_ids(registry: CountryRegistry) -> PackedStringArray:
	var out := PackedStringArray()
	if registry == null:
		return out
	for record: CountryRecord in registry.all():
		if is_eligible(record):
			out.append(record.id)
	return out
