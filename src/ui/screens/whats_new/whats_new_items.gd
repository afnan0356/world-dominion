class_name WhatsNewItems
extends RefCounted
## The What is new screen's content, in one table (Milestone 11, Task 5).
##
## Each entry is a sentence and the files that make it true. `tests/suites/
## test_whats_new.gd` reads every path and fails when one is gone, so a release note cannot
## describe work that was reverted or a file that was renamed. That is the whole point of the
## screen: notes about a build in progress rot faster than any other page, and the only defence
## is to make rot a test failure.
##
## Entries are grouped by milestone, newest first. Nothing here claims a feature is complete;
## `state_key` is the badge the section shows, and `MISSING` is the section about absence, which
## is as much a part of "what is new" as the additions.

const RELEASES := [
	{
		"milestone": 11,
		"title_key": "whats_new.m11_title",
		"state_key": "whats_new.m11_state",
		"items": [
			{
				"title_key": "whats_new.icons_title",
				"body_key": "whats_new.icons_body",
				"evidence": [
					"data/ui/icon_sources.json",
					"src/ui/icons/icon_atlas.gd",
					"src/ui/hud/shell_icon.gd",
					"THIRD_PARTY_LICENSES.md",
				],
			},
			{
				"title_key": "whats_new.inventory_title",
				"body_key": "whats_new.inventory_body",
				"evidence": [
					"docs/FEATURE_INVENTORY.md",
					"docs/SCREEN_MAP.md",
				],
			},
			{
				"title_key": "whats_new.countries_title",
				"body_key": "whats_new.countries_body",
				"evidence": [
					"src/core/world/country_state.gd",
					"docs/SAVE_FORMAT.md",
					"tests/fixtures/save_schema1_frozen.json",
				],
			},
			{
				"title_key": "whats_new.data_title",
				"body_key": "whats_new.data_body",
				"evidence": [
					"docs/DATA_CANDIDATES.md",
					"tools/check_data_candidates.py",
				],
			},
		],
	},
]

## The section about what this build does not do. Deliberately not a list of promises: the
## roadmap already owns that, and a second list of dates would be a second thing to keep true.
const MISSING := {
	"title_key": "whats_new.missing_title",
	"body_key": "whats_new.missing_body",
	"evidence": [
		"docs/DATA_CANDIDATES.md",
		"docs/FEATURE_INVENTORY.md",
	],
}


## Every key the screen reads, for the test that checks the string table.
static func string_keys() -> PackedStringArray:
	var keys := PackedStringArray()
	for release: Dictionary in RELEASES:
		keys.append(str(release["title_key"]))
		keys.append(str(release["state_key"]))
		for item: Dictionary in release["items"]:
			keys.append(str(item["title_key"]))
			keys.append(str(item["body_key"]))
	keys.append(str(MISSING["title_key"]))
	keys.append(str(MISSING["body_key"]))
	return keys


## Every file any entry cites, without duplicates, in the order they appear.
static func evidence_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for release: Dictionary in RELEASES:
		for item: Dictionary in release["items"]:
			for path: String in item["evidence"]:
				if not paths.has(path):
					paths.append(path)
	for path: String in MISSING["evidence"]:
		if not paths.has(path):
			paths.append(path)
	return paths


## The entry count the screen renders, for the test that compares what is drawn with this table.
static func entry_count() -> int:
	var total := 0
	for release: Dictionary in RELEASES:
		total += (release["items"] as Array).size()
	return total
