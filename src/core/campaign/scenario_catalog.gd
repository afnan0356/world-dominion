class_name ScenarioCatalog
extends RefCounted
## Every scenario definition shipped in `data/scenarios/`.
##
## Adding a scenario is a data change: drop a JSON file in the folder and it is
## listed (and startable, if it declares `"implemented": true`). Nothing in the
## UI hardcodes a scenario id.

const DEFAULT_DIR := "res://data/scenarios"

var _scenarios: Array[Scenario] = []
var _by_id: Dictionary = {}
var _issues: PackedStringArray = []


static func from_directory(directory: String = DEFAULT_DIR) -> ScenarioCatalog:
	var catalog := ScenarioCatalog.new()
	var dir := DirAccess.open(directory)
	if dir == null:
		catalog._issues.append("%s: directory is missing" % directory)
		return catalog
	var files := dir.get_files()
	files.sort()
	for file_name: String in files:
		if not file_name.ends_with(".json"):
			continue
		var data: Variant = DataLoader.load_json("%s/%s" % [directory, file_name])
		var scenario := Scenario.from_dict(data)
		if scenario == null:
			catalog._issues.append("%s: not a usable scenario definition" % file_name)
			continue
		catalog.add(scenario)
	return catalog


static func from_list(entries: Array) -> ScenarioCatalog:
	var catalog := ScenarioCatalog.new()
	for entry: Variant in entries:
		var scenario := Scenario.from_dict(entry)
		if scenario != null:
			catalog.add(scenario)
	return catalog


func add(scenario: Scenario) -> void:
	if _by_id.has(scenario.id):
		_issues.append("duplicate scenario id '%s' ignored" % scenario.id)
		return
	_scenarios.append(scenario)
	_by_id[scenario.id] = scenario
	for problem: String in scenario.issues:
		_issues.append("[%s] %s" % [scenario.id, problem])


func all() -> Array[Scenario]:
	return _scenarios


## Scenarios the build can actually start. The setup screen only offers these.
func implemented() -> Array[Scenario]:
	var out: Array[Scenario] = []
	for scenario: Scenario in _scenarios:
		if scenario.implemented:
			out.append(scenario)
	return out


func count() -> int:
	return _scenarios.size()


func implemented_count() -> int:
	return implemented().size()


func has_scenario(scenario_id: String) -> bool:
	return _by_id.has(scenario_id)


func get_scenario(scenario_id: String) -> Scenario:
	return _by_id.get(scenario_id) as Scenario


## The scenario a new campaign starts with: the first implemented one, or null
## when this build has none (in which case New Campaign must say so).
func default_scenario() -> Scenario:
	var usable := implemented()
	return usable[0] if not usable.is_empty() else null


func issues() -> PackedStringArray:
	return _issues
