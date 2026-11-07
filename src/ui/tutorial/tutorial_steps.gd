class_name TutorialSteps
extends RefCounted
## The tutorial's steps (Milestone 08, Task 5), in the order a new player meets them.
##
## Two rules are structural rather than promises:
##
##   1. **Every step names a feature that exists.** A step's `feature` is an id in
##      `FEATURES`, and each of those carries the node a test looks for on the running game
##      screen. A step about a screen that does not exist has no anchor and fails the suite.
##   2. **No step claims a system that is not built.** `NOT_FEATURES` lists the systems this
##      project has not made. A sentence that mentions one must also say, in the same
##      sentence, that it is not there — `test_no_step_mentions_a_feature_that_does_not_exist`
##      is what enforces it.
##
## The words themselves live in `src/ui/strings.gd`; this file holds keys and structure.

## id → the node on the game screen that proves the feature is really there, plus what to
## say about it in the report. `%Name` means a unique node name; anything else is a plain
## child name, searched recursively.
const FEATURES := {
	"date": {"node": "Date", "what": "the in-game date in the top bar"},
	"speeds": {"node": "Speed", "what": "the speed control (Pause, Normal, Fast-forward)"},
	"map": {"node": "%Map", "what": "the interactive map"},
	"dossier": {"node": "%SidePanel", "what": "the country dossier panel"},
	"pause_menu": {"node": "PauseMenu", "what": "the pause menu"},
	"saving": {"node": "SlotChooser", "what": "the save-slot chooser"},
}

## Systems the project has not built. A step may mention one only to say it is absent.
const NOT_FEATURES := ["economy", "politics", "diplomacy", "military", "elections",
	"parliament", "trade", "warfare", "alliances", "budgets", "taxes", "army", "navy"]

## The steps, in order. `title_key` and `body_key` are string-table keys.
const STEPS: Array = [
	{"id": "date", "feature": "date", "title_key": "tutorial.date.title",
			"body_key": "tutorial.date.body"},
	{"id": "speeds", "feature": "speeds", "title_key": "tutorial.speeds.title",
			"body_key": "tutorial.speeds.body"},
	{"id": "map", "feature": "map", "title_key": "tutorial.map.title",
			"body_key": "tutorial.map.body"},
	{"id": "dossier", "feature": "dossier", "title_key": "tutorial.dossier.title",
			"body_key": "tutorial.dossier.body"},
	{"id": "pause_menu", "feature": "pause_menu", "title_key": "tutorial.pause.title",
			"body_key": "tutorial.pause.body"},
	{"id": "saving", "feature": "saving", "title_key": "tutorial.saving.title",
			"body_key": "tutorial.saving.body"},
]


static func count() -> int:
	return STEPS.size()


static func step(index: int) -> Dictionary:
	if index < 0 or index >= STEPS.size():
		return {}
	return STEPS[index]


static func title_of(index: int) -> String:
	var entry := step(index)
	return "" if entry.is_empty() else Strings.t(str(entry["title_key"]))


static func body_of(index: int) -> String:
	var entry := step(index)
	return "" if entry.is_empty() else Strings.t(str(entry["body_key"]))


## Node name the test resolves on a mounted game screen for `feature_id`.
static func anchor_of(feature_id: String) -> String:
	if not FEATURES.has(feature_id):
		return ""
	return str((FEATURES[feature_id] as Dictionary)["node"])


## Feature ids that no `FEATURES` entry backs. Empty is the only acceptable answer.
static func unknown_features() -> PackedStringArray:
	var missing := PackedStringArray()
	for entry: Variant in STEPS:
		var feature_id := str((entry as Dictionary)["feature"])
		if not FEATURES.has(feature_id):
			missing.append(feature_id)
	return missing
