extends TestCase
## Flags: the pinned source, the committed crosswalk, and the rule that a record without a
## flag gets a neutral code badge rather than a guessed picture (Milestone 07, Task 3).

const CROSSWALK := "res://data/world/flag_crosswalk.json"
const ASSET_ROOT := "res://assets/flags/"


func _registry() -> CountryRegistry:
	return WorldAtlas.load_default().registry


func test_the_source_is_pinned_and_licensed_before_any_file() -> void:
	var text := FileAccess.get_file_as_string(CROSSWALK)
	check_false(text.is_empty(), "the crosswalk is committed")
	var parsed: Variant = JSON.parse_string(text)
	check_true(parsed is Dictionary, "and is JSON")
	if not (parsed is Dictionary):
		return
	var document: Dictionary = parsed
	var source: Dictionary = document.get("source", {})
	check_eq(str(source.get("name", "")), "lipis/flag-icons", "the source is named")
	check_eq(str(source.get("version", "")), "v7.6.0", "with the pinned version")
	check_eq(str(source.get("commit", "")), "0d8909b00aa8418802a5abf2afa82356b129a7ef",
			"and the release commit")
	check_eq(str(source.get("licence", "")), "MIT", "under the MIT licence")
	check_eq(str(source.get("retrieved", "")), "2026-11-06", "retrieved on the recorded date")
	var licences := FileAccess.get_file_as_string("res://THIRD_PARTY_LICENSES.md")
	check_true(licences.contains("lipis/flag-icons"), "the licence file names the source")
	check_true(licences.contains("0d8909b00aa8418802a5abf2afa82356b129a7ef"),
			"with the same commit")
	check_true(licences.contains("Copyright (c) 2013 Panayiotis Lipiridis"),
			"and the copyright line")


func test_every_record_is_either_mapped_or_reported_flagless() -> void:
	var parsed := JSON.parse_string(FileAccess.get_file_as_string(CROSSWALK)) as Dictionary
	var flags: Dictionary = parsed.get("flags", {})
	var flagless: Array = parsed.get("flagless", [])
	var registry := _registry()
	var missing: Array = []
	var extra: Array = []
	for record: CountryRecord in registry.all():
		var mapped := flags.has(record.id)
		var listed := false
		for entry: Variant in flagless:
			if str((entry as Dictionary).get("id", "")) == record.id:
				listed = true
				break
		if not mapped and not listed:
			missing.append(record.id)
		if mapped and listed:
			extra.append(record.id)
	check_eq(missing.size(), 0, "no record is silently omitted: %s" % str(missing))
	check_eq(extra.size(), 0, "and none is both mapped and flagless: %s" % str(extra))
	check_eq(flags.size() + flagless.size(), registry.count(),
			"the crosswalk accounts for every record exactly once")
	check_eq(int(parsed.get("matched_count", 0)), flags.size(),
			"and says how many are matched")
	check_eq(int(parsed.get("record_count", 0)), registry.count(),
			"and how many records exist")
	var reasoned := true
	for entry: Variant in flagless:
		if str((entry as Dictionary).get("reason", "")).strip_edges().is_empty():
			reasoned = false
	check_true(reasoned, "every flagless record says why")


func test_a_flag_is_only_ever_the_records_own_code() -> void:
	var parsed := JSON.parse_string(FileAccess.get_file_as_string(CROSSWALK)) as Dictionary
	var flags: Dictionary = parsed.get("flags", {})
	var registry := _registry()
	var wrong: Array = []
	var not_four_by_three: Array = []
	for country_id: String in flags:
		var entry: Dictionary = flags[country_id]
		var record: CountryRecord = registry.get_country(country_id)
		if record == null:
			wrong.append("%s is not a record" % country_id)
			continue
		var code := str(entry.get("iso_a2", "")).to_upper()
		if code != record.iso_a2.to_upper():
			wrong.append("%s would fly %s, its code is %s"
					% [country_id, code, record.iso_a2])
		if str(entry.get("file", "")) != "4x3/%s.svg" % code.to_lower():
			wrong.append("%s names the wrong file" % country_id)
		var text := FileAccess.get_file_as_string(ASSET_ROOT + str(entry.get("file", "")))
		if text.is_empty():
			not_four_by_three.append("%s has no file" % country_id)
		elif not _declares_four_by_three(text):
			not_four_by_three.append("%s is not a 4:3 drawing" % country_id)
	check_eq(wrong.size(), 0, "no record flies a flag it did not name: %s"
			% str(wrong.slice(0, 5)))
	check_eq(not_four_by_three.size(), 0, "every committed file is a 4:3 SVG: %s"
			% str(not_four_by_three.slice(0, 5)))


func test_a_flag_rasterises_at_the_size_the_interface_asks_for() -> void:
	FlagImage.clear_cache()
	var texture := FlagImage.texture_for("BGD")
	check_not_null(texture, "a mapped record gets a texture")
	if texture == null:
		return
	check_eq(texture.get_width(), FlagImage.WIDTH, "drawn at the requested width")
	check_eq(texture.get_height(), FlagImage.HEIGHT, "and height")
	check_eq(FlagImage.cache_size(), 1, "and kept in the cache")
	var again := FlagImage.texture_for("BGD")
	check_true(again == texture, "a second request reuses the cached texture")
	check_eq(FlagImage.cache_size(), 1, "without growing the cache")


func test_a_record_without_a_flag_gets_a_badge_not_a_guess() -> void:
	var parsed := JSON.parse_string(FileAccess.get_file_as_string(CROSSWALK)) as Dictionary
	var flagless: Array = parsed.get("flagless", [])
	check_true(flagless.size() > 0, "the data set has records without a flag")
	if flagless.is_empty():
		return
	var country_id := str((flagless[0] as Dictionary).get("id", ""))
	check_false(FlagImage.has_flag(country_id), "no flag is mapped for it")
	check_eq(FlagImage.texture_for(country_id), null, "and no texture is produced")
	check_eq(FlagImage.badge_text(country_id), country_id.to_upper(),
			"the badge shows its own code instead")
	check_eq(FlagImage.badge_text("BGD", "bd"), "BD", "a code is upper-cased, not invented")
	check_eq(FlagImage.texture_for("NOWHERE"), null, "an unknown record gets nothing")


func test_the_cache_stays_small() -> void:
	FlagImage.clear_cache()
	var parsed := JSON.parse_string(FileAccess.get_file_as_string(CROSSWALK)) as Dictionary
	var flags: Dictionary = parsed.get("flags", {})
	var ids: Array = flags.keys()
	ids.sort()
	var loaded := 0
	for index in mini(ids.size(), FlagImage.CACHE_LIMIT + 8):
		if FlagImage.texture_for(str(ids[index])) != null:
			loaded += 1
	check_gt(float(loaded), 0.0, "flags do load")
	check_lte(float(FlagImage.cache_size()), float(FlagImage.CACHE_LIMIT),
			"but the cache never grows past its limit (%d of %d loaded)"
			% [FlagImage.cache_size(), loaded])
	FlagImage.clear_cache()


func _declares_four_by_three(text: String) -> bool:
	var marker := text.find("viewBox=\"")
	if marker < 0:
		return false
	var start := marker + len("viewBox=\"")
	var closer := text.find("\"", start)
	if closer <= start:
		return false
	var parts := text.substr(start, closer - start).split(" ")
	if parts.size() != 4:
		return false
	var width := float(parts[2])
	var height := float(parts[3])
	if height <= 0.0:
		return false
	return absf(width / height - 4.0 / 3.0) < 0.000001
