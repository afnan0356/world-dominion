extends TestCase
## Content files must stay parseable and complete, because the interface reads
## them at runtime (build status, credits, licensing).

func test_app_meta_is_complete() -> void:
	var meta := DataLoader.load_dictionary("app_meta.json")
	check_false(meta.is_empty(), "app_meta.json must parse")
	check_gt(float(str(meta.get("milestone_label", "")).length()), 0.0,
			"milestone label must be present")
	for list_key: String in ["status", "implemented", "planned_next", "about_paragraphs"]:
		var list: Array = DataLoader.get_typed(meta, list_key, TYPE_ARRAY, [])
		check_gt(float(list.size()), 0.0, "app_meta.json must define '%s'" % list_key)
	var note := str(meta.get("status_note", ""))
	check_true(note.contains("No simulation"),
			"the build must state plainly what is not implemented")
	check_true(note.contains("world atlas"),
			"the build status must describe what this milestone added")


func test_credits_identify_the_creator() -> void:
	var credits := DataLoader.load_dictionary("credits.json")
	check_false(credits.is_empty(), "credits.json must parse")
	var creator: Dictionary = DataLoader.get_typed(credits, "creator", TYPE_DICTIONARY, {})
	check_eq(str(creator.get("name", "")), "Md. Afnan", "the project creator must be credited by name")
	check_eq(str(creator.get("role", "")), "Project Creator", "the creator's role must be recorded")


func test_human_and_ai_contributions_are_separate() -> void:
	var credits := DataLoader.load_dictionary("credits.json")
	check_true(credits.has("human_contributors"), "credits must separate human contributors")
	check_true(credits.has("ai_assisted"), "credits must separate AI-assisted contributions")
	var ai: Array = DataLoader.get_typed(credits, "ai_assisted", TYPE_ARRAY, [])
	check_gt(float(ai.size()), 0.0, "AI-assisted work must be disclosed")
	for entry: Variant in ai:
		check_true(entry is Dictionary, "AI entries must be objects")
		if entry is Dictionary:
			check_gt(float(str((entry as Dictionary).get("role", "")).length()), 0.0,
					"each AI contribution must describe what it covered")


func test_third_party_components_are_licensed() -> void:
	var credits := DataLoader.load_dictionary("credits.json")
	var built_with: Array = DataLoader.get_typed(credits, "built_with", TYPE_ARRAY, [])
	check_gt(float(built_with.size()), 0.0, "third-party components must be listed")
	var mentions_godot := false
	for entry: Variant in built_with:
		if entry is Dictionary:
			var name := str((entry as Dictionary).get("name", ""))
			var detail := str((entry as Dictionary).get("detail", ""))
			check_gt(float(detail.length()), 0.0, "'%s' must state its version/licence" % name)
			if name.contains("Godot"):
				mentions_godot = detail.contains("MIT")
	check_true(mentions_godot, "Godot Engine must be credited with its MIT licence")


func test_licensing_note_is_explicit() -> void:
	var credits := DataLoader.load_dictionary("credits.json")
	var note := str(credits.get("license_note", ""))
	check_gt(float(note.length()), 0.0, "the licensing situation must be documented in-app")
