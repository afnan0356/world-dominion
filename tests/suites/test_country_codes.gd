extends TestCase
## Real country codes and the country picker's groups.
##
## Two things are checked here, and both are checkable without a screen: that the codes
## the game shows are the ones the pinned source actually gives (and that a record with
## no code of its own says so), and that every record lands in exactly one picker group.
##
## The rules this defends:
##
## * a code is shown only when the source has one for **that** record — the two island
##   territories whose corrected field carries their administering state's code keep no
##   code, because three records answering to `AU` would be a lie and a boundary claim;
## * Kosovo's `XK` is `user-assigned`, never `iso-official`;
## * the stable id never depends on a displayed code, so every save still refers to the
##   same record;
## * search finds a record by either code, including the codes that were gaps before.

const CROSSWALK := "res://data/world/iso_codes_crosswalk.json"
const REGIONS := "res://data/world/picker_regions.json"
const STATUSES := ["iso-official", "user-assigned", "none"]

var _atlas: WorldAtlas


func _load_atlas() -> WorldAtlas:
	if _atlas == null:
		_atlas = WorldAtlas.load_default()
	return _atlas


func _ids(records: Array[CountryRecord]) -> PackedStringArray:
	var out := PackedStringArray()
	for record: CountryRecord in records:
		out.append(record.id)
	return out


func test_every_record_has_a_code_entry() -> void:
	var crosswalk := DataLoader.load_dictionary(CROSSWALK)
	var records: Dictionary = crosswalk.get("records", {})
	check_false(records.is_empty(), "the code crosswalk loads")
	check_eq(records.size(), 242, "one entry per record")
	var atlas := _load_atlas()
	var missing: PackedStringArray = []
	for record: CountryRecord in atlas.registry.all():
		var entry: Dictionary = records.get(record.id, {})
		if entry.is_empty():
			missing.append(record.id)
	check_eq(missing.size(), 0, "no record is missing from the crosswalk: %s"
			% ", ".join(missing))
	var source: Dictionary = crosswalk.get("source", {})
	for key in ["dataset", "commit", "version", "licence", "retrieved", "sha256"]:
		check_true(not str(source.get(key, "")).is_empty(),
				"the crosswalk records its source %s" % key)


func test_registry_codes_match_the_crosswalk() -> void:
	var records: Dictionary = DataLoader.load_dictionary(CROSSWALK).get("records", {})
	var atlas := _load_atlas()
	var mismatches: PackedStringArray = []
	for record: CountryRecord in atlas.registry.all():
		var entry: Dictionary = records.get(record.id, {})
		if record.iso_a2 != str(entry.get("iso_a2") or ""):
			mismatches.append("%s a2" % record.id)
		if record.iso_a3 != str(entry.get("iso_a3") or ""):
			mismatches.append("%s a3" % record.id)
		if record.code_status != str(entry.get("code_status") or ""):
			mismatches.append("%s status" % record.id)
	check_eq(mismatches.size(), 0, "the shipped codes are the crosswalk's: %s"
			% ", ".join(mismatches))


func test_code_statuses_are_the_three_documented_ones() -> void:
	var atlas := _load_atlas()
	var counts := {}
	for record: CountryRecord in atlas.registry.all():
		check_true(STATUSES.has(record.code_status),
				"%s: code_status %r is one of the documented values"
				% [record.id, record.code_status])
		counts[record.code_status] = int(counts.get(record.code_status, 0)) + 1
		if record.code_status == "none":
			check_eq(record.iso_a2, "", "%s: no code shown when the source has none" % record.id)
			check_eq(record.iso_a3, "", "%s: no three-letter code either" % record.id)
		else:
			check_gt(float(record.iso_a2.length()), 0.0, "%s: a code is shown" % record.id)
	check_eq(int(counts.get("none", 0)), 5, "five records have no code of their own")
	check_eq(int(counts.get("user-assigned", 0)), 1, "one user-assigned code")


func test_the_records_that_were_fixed() -> void:
	var atlas := _load_atlas()
	# Anchored to the pinned source's own corrected fields, not to memory: Norway,
	# France and Taiwan had no usable two-letter code in the plain field.
	var norway := atlas.registry.get_country("NOR")
	check_eq(norway.iso_a2, "NO", "Norway's two-letter code comes from the source")
	check_eq(norway.iso_a3, "NOR", "Norway's three-letter code")
	check_eq(norway.code_status, "iso-official", "and it is official")
	var france := atlas.registry.get_country("FRA")
	check_eq(france.iso_a2, "FR", "France's two-letter code")
	var taiwan := atlas.registry.get_country("TWN")
	check_eq(taiwan.iso_a2, "TW", "Taiwan's two-letter code is TW, not CN-TW")
	var kosovo := atlas.registry.get_country("KOS")
	check_eq(kosovo.iso_a2, "XK", "Kosovo keeps the widely used XK")
	check_eq(kosovo.code_status, "user-assigned", "and it is never called official")
	check_eq(kosovo.iso_a3, "", "Kosovo has no three-letter code in the source")
	# The two records whose corrected field names their administering state.
	for country_id: String in ["IOA", "ATC"]:
		var record := atlas.registry.get_country(country_id)
		check_eq(record.iso_a2, "", "%s does not borrow its parent's code" % country_id)
		check_eq(record.code_status, "none", "%s says it has no code" % country_id)


func test_stable_ids_did_not_move() -> void:
	# The ids the saves use are the registry ids and nothing else. A handful of records
	# gained a displayed code in this milestone; none of them may change identity.
	var expected := PackedStringArray(["BGD", "FRA", "NOR", "TWN", "KOS", "SOL", "CYN",
			"KAS", "IOA", "ATC", "USA", "PSE", "SSD", "ESH", "ALA"])
	var atlas := _load_atlas()
	for country_id: String in expected:
		check_true(atlas.registry.has_country(country_id),
				"%s is still the id a save refers to" % country_id)
	check_eq(atlas.registry.count(), 242, "and there are still 242 of them")


func test_search_finds_a_country_by_either_code() -> void:
	var atlas := _load_atlas()
	for pair: Array in [["FRA", "FRA"], ["NOR", "NOR"], ["TW", "TWN"], ["KOS", "XK"],
			["XK", "KOS"], ["KAS", "KAS"]]:
		var query: String = pair[0]
		var wanted: String = pair[1]
		var ids := _ids(atlas.registry.search(query))
		check_true(ids.has(wanted), "searching %r finds %s" % [query, wanted])
	# A record with no code at all is still reachable by its name.
	check_true(_ids(atlas.registry.search("Somaliland")).has("SOL"),
			"a record without a code is found by name")
	# Three letters that are not a code must not invent a result.
	check_false(_ids(atlas.registry.search("ZZZ")).has("NOR"), "an unknown code finds nothing")


func test_every_record_is_in_exactly_one_picker_group() -> void:
	var map := DataLoader.load_dictionary(REGIONS)
	var records: Dictionary = map.get("records", {})
	var groups: Array = map.get("groups", [])
	check_false(records.is_empty(), "the region map loads")
	check_eq(records.size(), 242, "every record is mapped")
	check_eq(groups.size(), 17, "seventeen groups, as documented")
	var known: Array[String] = []
	for group: Dictionary in groups:
		known.append(str(group.get("id", "")))
	var atlas := _load_atlas()
	var seen := {}
	for record: CountryRecord in atlas.registry.all():
		var mapped: Dictionary = records.get(record.id, {})
		check_false(mapped.is_empty(), "%s has a group" % record.id)
		var group := str(mapped.get("group", ""))
		check_true(known.has(group), "%s: %s is a documented group" % [record.id, group])
		check_eq(record.picker_group, group, "%s: the registry agrees with the map"
				% record.id)
		seen[record.id] = seen.get(record.id, 0) + 1
	for country_id: String in seen:
		check_eq(int(seen[country_id]), 1, "%s is assigned exactly once" % country_id)


func test_region_rules_explain_every_assignment() -> void:
	var map := DataLoader.load_dictionary(REGIONS)
	var rules: Array = map.get("rules", [])
	check_gt(float(rules.size()), 0.0, "the rules are published in the file")
	for rule: Dictionary in rules:
		check_true(not str(rule.get("group", "")).is_empty(), "a rule names its group")
		check_true(rule.has("continent"), "a rule names its continent or wildcard")
	for country_id: String in (map.get("records", {}) as Dictionary):
		var entry: Dictionary = map["records"][country_id]
		check_true(not str(entry.get("rule", "")).is_empty(),
				"%s records the rule that placed it" % country_id)
		check_true(not str(entry.get("continent", "")).is_empty(),
				"%s records the source's continent" % country_id)


func test_the_dossier_shows_both_codes_and_their_status() -> void:
	var atlas := _load_atlas()
	var dossier := CountryDossier.build(atlas.registry.get_country("NOR"),
			{"statistics": atlas.statistics})
	# Both codes are already shown where they belong — the geography and administration
	# groups — so this checks they are *somewhere* readable, and that the identity group
	# says what kind of code it is. Duplicating them into a third group was the first
	# attempt and it was removed: a fact shown twice can disagree with itself.
	var values := _all_fields(dossier)
	check_eq(values.get("ISO alpha-2", ""), "NO", "the dossier shows the two-letter code")
	check_eq(values.get("ISO alpha-3", ""), "NOR", "the dossier shows the three-letter code")
	check_eq(values.get("Code status", ""), "officially assigned", "and says it is official")
	var kosovo := CountryDossier.build(atlas.registry.get_country("KOS"), {})
	check_true(str(_all_fields(kosovo).get("Code status", "")).contains("not officially assigned"),
			"Kosovo's code says it is not official")
	var kosovo_status := _field(kosovo, "Code status")
	check_not_null(kosovo_status, "the status is shown")
	if kosovo_status != null:
		check_false(kosovo_status.recorded, "and is styled as a caveat, not a fact")
	var territory := CountryDossier.build(atlas.registry.get_country("ATC"), {})
	var territory_code := _field(territory, "ISO alpha-2")
	check_not_null(territory_code, "a record with no code still shows the row")
	if territory_code != null:
		check_false(territory_code.recorded, "and shows a gap rather than a code")
		check_eq(territory_code.value, "Not recorded in source", "the gap is stated plainly")


func _all_fields(dossier: CountryDossier) -> Dictionary:
	var values := {}
	for section: CountryDossier.Section in dossier.sections:
		for field: CountryDossier.Field in section.fields:
			values[field.label] = field.value
	return values


func _field(dossier: CountryDossier, label: String) -> CountryDossier.Field:
	for section: CountryDossier.Section in dossier.sections:
		for field: CountryDossier.Field in section.fields:
			if field.label == label:
				return field
	return null
