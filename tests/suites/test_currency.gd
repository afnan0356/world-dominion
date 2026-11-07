extends TestCase
## Currency data (Milestone 09, Task 7).
##
## The rules these tests defend: a currency is shown only when a pinned source names one
## for the record's **own** code; a gap is shown as "Not available" and never filled from
## a parent or a neighbour; the data is a label, not a simulation input, so nothing under
## `src/core/sim` or `src/core/save` may mention it; and the atlas pack's geography bytes
## are untouched by any of it.

const PACK_PATH := "res://data/world/currency.json"
const CROSSWALK_PATH := "res://data/world/currency_crosswalk.json"
const MANIFEST_PATH := "res://data/world/manifest.json"
const COUNTRIES_DIR := "res://data/world/countries"

## The records the source cannot answer for, with the reason each is refused. Pinned here
## so a change in the source or in the matching rule cannot pass silently: a new match
## means this list must be edited deliberately, and the report says why.
const UNMATCHED := {
	"ATA": "region",
	"BTN": "ambiguous",
	"HTI": "ambiguous",
	"LSO": "ambiguous",
	"NAM": "ambiguous",
	"PAN": "ambiguous",
	"PSE": "ambiguous",
	"ZWE": "ambiguous",
	"ATC": "no code",
	"CYN": "no code",
	"IOA": "no code",
	"KAS": "no code",
	"SOL": "no code",
}

var _catalog: CurrencyCatalog


func _load() -> CurrencyCatalog:
	if _catalog == null:
		_catalog = CurrencyCatalog.load_default()
	return _catalog


func test_the_pack_loads_and_every_entry_is_complete() -> void:
	var catalog := _load()
	check_true(catalog.is_loaded(), "the currency pack loads")
	check_gt(float(catalog.count()), 200.0, "most records have a currency from the source")
	check_eq(catalog.matched_count, catalog.count(),
			"the file's matched count agrees with what it holds")
	check_eq(catalog.record_count, 242, "the file knows how many records exist")
	for country_id: String in ["BGD", "USA", "DEU", "JPN", "ZAF"]:
		var entry := catalog.entry(country_id)
		check_false(entry.is_empty(), "%s has a currency" % country_id)
		check_eq(str(entry["code"]).length(), 3, "%s's code is three characters" % country_id)
		check_eq(str(entry["code"]), str(entry["code"]).to_upper(),
				"%s's code is uppercase" % country_id)
		check_false(str(entry["name"]).strip_edges().is_empty(),
				"%s's currency has an English name" % country_id)


func test_values_are_the_ones_the_source_gives() -> void:
	var catalog := _load()
	var bangladesh := catalog.entry("BGD")
	check_eq(str(bangladesh["code"]), "BDT", "Bangladesh uses the taka")
	check_eq(str(bangladesh["name"]), "Bangladeshi Taka", "with the source's English name")
	var japan := catalog.entry("JPN")
	check_eq(str(japan["code"]), "JPY", "Japan uses the yen")
	var panama := catalog.describe("PAN")
	check_eq(panama, CurrencyCatalog.MISSING_TEXT,
			"a region the source leaves ambiguous is not guessed at")


func test_every_gap_is_the_one_the_source_names() -> void:
	var catalog := _load()
	var registry := CountryRegistry.from_file()
	var unmatched: Array[String] = []
	for record: CountryRecord in registry.all():
		if not catalog.has(record.id):
			unmatched.append(record.id)
	unmatched.sort()
	var expected: Array[String] = []
	for country_id: String in UNMATCHED:
		expected.append(country_id)
	expected.sort()
	check_eq(unmatched, expected, "exactly the records the source cannot answer for are gaps")
	for country_id: String in unmatched:
		check_eq(catalog.describe(country_id), "Not available",
				"%s shows the gap, not a blank and not zero" % country_id)
		check_false(catalog.note(country_id).is_empty(),
				"%s explains the gap in words" % country_id)


func test_a_gap_is_never_borrowed_from_a_neighbour() -> void:
	var catalog := _load()
	var picked := 0
	for country_id: String in ["ATC", "CYN", "SOL", "KAS", "IOA"]:
		check_false(catalog.has(country_id), "%s has no currency of its own" % country_id)
		picked += 1
	check_eq(picked, 5, "the code-less records checked are the ones expected")
	# A record without a currency must not inherit one from the record it belongs to, and
	# the catalogue is keyed by id alone, so there is no code path that could do so.
	check_false(catalog.has(""), "an empty id is not a key")
	check_true(catalog.entry("ATC").is_empty(), "an unmatched record returns no entry")


func test_the_crosswalk_and_the_pack_agree() -> void:
	var data: Variant = DataLoader.load_json(CROSSWALK_PATH)
	check_true(data is Dictionary, "the crosswalk loads")
	var crosswalk: Dictionary = data
	var entries: Dictionary = crosswalk.get("entries", {})
	var pack: Dictionary = DataLoader.load_json(PACK_PATH)
	var countries: Dictionary = pack.get("countries", {})
	check_eq(entries.size(), 242, "the crosswalk covers every record")
	check_eq(countries.size(), int(pack.get("matched_count", -1)),
			"the pack's matched count agrees with its entries")
	for country_id: String in entries:
		var entry: Dictionary = entries[country_id]
		var matched := bool(entry.get("matched", false))
		check_eq(matched, countries.has(country_id),
				"%s's crosswalk row agrees with the pack" % country_id)
		if not matched:
			check_false(str(entry.get("reason", "")).strip_edges().is_empty(),
					"%s's refusal is explained in the crosswalk" % country_id)


func test_every_matched_record_has_a_folder_file_and_every_gap_has_none() -> void:
	var catalog := _load()
	var registry := CountryRegistry.from_file()
	var with_file := 0
	for record: CountryRecord in registry.all():
		var path := COUNTRIES_DIR.path_join(record.id).path_join("currency.json")
		var exists := FileAccess.file_exists(path)
		check_eq(exists, catalog.has(record.id),
				"%s's folder file exists exactly when the pack says it does" % record.id)
		if exists:
			with_file += 1
	check_eq(with_file, catalog.count(), "every pack entry comes from a folder file")


func test_the_manifest_records_the_currency_file_and_its_hash() -> void:
	var manifest: Dictionary = DataLoader.load_json(MANIFEST_PATH)
	var block: Variant = manifest.get("currency")
	check_true(block is Dictionary, "the manifest carries a currency block")
	if not block is Dictionary:
		return
	var entry: Dictionary = block
	check_eq(str(entry.get("file", "")), "currency.json", "the block names the pack file")
	check_eq(int(entry.get("records_with_currency", 0)), _load().count(),
			"the manifest count matches the pack")
	check_eq(str(entry.get("builder", "")), "tools/build_currency.py", "the builder is named")
	var text := FileAccess.get_file_as_string(PACK_PATH)
	check_eq(str(entry.get("sha256", "")).length(), 64, "the hash is a sha256")
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	check_eq(context.finish().hex_encode(), str(entry.get("sha256", "")),
			"the pack file still hashes to what the manifest records")


func test_the_simulation_and_saves_never_mention_currency() -> void:
	# The rule is structural: a currency is a label, so no simulation or save file may use it
	# as state. Scanning the folders is the only way to keep that true over time.
	#
	# Milestone 11 narrowed the rule in one place, deliberately. The per-country baseline now
	# records each record's ISO 4217 *code* — the milestone requires a currency "when sourced",
	# because a country's currency is part of what the data says about it. That is a label
	# carried as data, not a currency the simulation computes with. So:
	#
	#   * `src/core/save/**` still may not mention it at all (a save carries no currency state);
	#   * `src/core/sim/**` may mention it only in a comment that documents the baseline
	#     reference, and never in a line of code.
	#
	# A blanket exemption would have made the guard meaningless, so it is this narrow.
	var offenders: Array = []
	var seen_baseline_reference := false
	for folder: String in ["res://src/core/sim", "res://src/core/save"]:
		for path: String in _scripts_in(folder):
			var file_name := path.get_file()
			var text := FileAccess.get_file_as_string(path)
			if not text.to_lower().contains("currency"):
				continue
			if folder == "res://src/core/save":
				offenders.append("%s mentions currency" % file_name)
				continue
			for line: String in text.split("\n"):
				if not line.to_lower().contains("currency"):
					continue
				var trimmed := line.strip_edges()
				var is_comment := trimmed.begins_with("#")
				if is_comment and file_name == "world_state.gd":
					seen_baseline_reference = true
					continue
				offenders.append("%s uses currency in code: %s" % [file_name, trimmed])
	check_eq(offenders.size(), 0, "no simulation or save file uses a currency: %s"
			% str(offenders.slice(0, 5)))
	check_true(seen_baseline_reference,
			"the one comment that names it is the baseline reference's own documentation")


func test_the_dossier_shows_the_currency_or_says_not_available() -> void:
	var catalog := _load()
	var registry := CountryRegistry.from_file()
	var context := {"currency": catalog}
	var bangladesh := CountryDossier.build(registry.get_country("BGD"), context)
	var found := _field(bangladesh, "Currency")
	check_eq(found.get("value", ""), "Bangladeshi Taka (BDT)", "the dossier names the currency")
	check_true(bool(found.get("recorded", false)), "a sourced currency is marked as present")
	var panama := CountryDossier.build(registry.get_country("PAN"), context)
	var gap := _field(panama, "Currency")
	check_eq(gap.get("value", ""), "Not available", "a gap says Not available")
	check_false(bool(gap.get("recorded", true)), "and is not dressed up as a value")
	# Without the catalogue the row is absent rather than wrong: a caller that forgets to
	# pass it gets no currency line at all.
	var bare := CountryDossier.build(registry.get_country("BGD"), {})
	check_true(_field(bare, "Currency").is_empty(),
			"no catalogue, no currency row — never a guessed one")


func test_geography_is_byte_identical_to_the_manifest_hash() -> void:
	var manifest: Dictionary = DataLoader.load_json(MANIFEST_PATH)
	var pack: Dictionary = manifest.get("pack", {})
	var text := FileAccess.get_file_as_string("res://data/world/geometry.json")
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(text.to_utf8_buffer())
	check_eq(context.finish().hex_encode(), str(pack.get("geometry_sha256", "")),
			"the committed geometry still hashes to what the manifest records")
	var countries := FileAccess.get_file_as_string("res://data/world/countries.json")
	var second := HashingContext.new()
	second.start(HashingContext.HASH_SHA256)
	second.update(countries.to_utf8_buffer())
	check_eq(second.finish().hex_encode(), str(pack.get("countries_sha256", "")),
			"and so does the country list")


func test_the_report_and_the_completeness_page_name_the_source() -> void:
	var report := FileAccess.get_file_as_string("res://docs/CURRENCY_REPORT.md")
	check_gt(float(report.length()), 1000.0, "the currency report exists and has content")
	for needle: String in ["Unicode CLDR 48.0.0", "Unicode License v3", "Not available",
			"an exchange rate"]:
		check_true(report.contains(needle), "the report says \"%s\"" % needle)
	check_true(report.contains("| `PAN` |"),
			"the report lists a refused record by name and reason")
	var completeness := FileAccess.get_file_as_string("res://docs/DATA_COMPLETENESS.md")
	check_true(completeness.contains("currency.json"),
			"the completeness page counts the currency files")
	var licences := FileAccess.get_file_as_string("res://THIRD_PARTY_LICENSES.md")
	check_true(licences.contains("Unicode License v3"),
			"the licence is recorded with the other third-party notices")


func _field(dossier: CountryDossier, label: String) -> Dictionary:
	for section: CountryDossier.Section in dossier.sections:
		for field: CountryDossier.Field in section.fields:
			if field.label == label:
				return {"value": field.value, "recorded": field.recorded}
	return {}


func _scripts_in(folder: String) -> PackedStringArray:
	var out := PackedStringArray()
	var directory := DirAccess.open(folder)
	if directory == null:
		return out
	for file_name: String in directory.get_files():
		if file_name.ends_with(".gd"):
			out.append(folder.path_join(file_name))
	for sub: String in directory.get_directories():
		out.append_array(_scripts_in(folder.path_join(sub)))
	return out
