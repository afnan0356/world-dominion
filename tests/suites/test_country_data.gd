extends TestCase
## Country registry and data-source checks.
##
## These run against the shipped `data/world/` files, not fixtures: the point is
## to prove that the data the game actually loads is well formed, complete where
## it claims to be, and honest where the source has gaps. Nothing here asserts a
## value the project does not own — capital cities, ISO codes and classifications
## are checked for *shape and consistency*, not for this project's opinions.

var _atlas: WorldAtlas
var _registry: CountryRegistry
var _geometry: WorldGeometry


func _load() -> void:
	if _atlas != null:
		return
	_atlas = WorldAtlas.load_default()
	_registry = _atlas.registry
	_geometry = _atlas.geometry


func test_registry_parses_the_shipped_dataset() -> void:
	_load()
	check_true(_registry.is_loaded(), "countries.json must parse into a registry")
	check_gte(float(_registry.count()), 200.0,
			"the atlas must cover at least 200 countries and territories")
	check_eq(_registry.issues().size(), 0,
			"the shipped registry must load without issues (%s)" % str(_registry.issues()))


func test_ids_are_unique_and_well_formed() -> void:
	_load()
	var seen := {}
	var expression := RegEx.new()
	check_eq(expression.compile(CountryRecord.ID_PATTERN), OK, "the id pattern must compile")
	for record: CountryRecord in _registry.all():
		check_false(seen.has(record.id), "duplicate country id '%s'" % record.id)
		seen[record.id] = true
		check_not_null(expression.search(record.id), "id '%s' is not a stable code" % record.id)


func test_iso_codes_are_well_formed() -> void:
	_load()
	var missing_iso3 := 0
	for record: CountryRecord in _registry.all():
		if record.has_iso_a2():
			check_eq(record.iso_a2.length(), 2, "%s: alpha-2 code length" % record.id)
		if record.has_iso_a3():
			check_eq(record.iso_a3.length(), 3, "%s: alpha-3 code length" % record.id)
			check_eq(record.iso_a3, record.id,
					"%s: the stable id must be the ISO alpha-3 code when one exists" % record.id)
		else:
			missing_iso3 += 1
	# The source leaves some codes empty (Kosovo, Somaliland, Norway, France…).
	# Those records must report the gap rather than inventing a code.
	check_gt(float(missing_iso3), 0.0,
			"the dataset contains units without an ISO alpha-3 code")
	check_lte(float(missing_iso3), 40.0,
			"an implausible number of records are missing an ISO alpha-3 code")


func test_required_fields_are_present() -> void:
	_load()
	for record: CountryRecord in _registry.all():
		check_false(record.name.strip_edges().is_empty(), "%s: display name" % record.id)
		check_false(record.region.is_empty(), "%s: region" % record.id)
		check_gt(record.bbox.size.x, 0.0, "%s: bbox width" % record.id)
		check_gt(record.bbox.size.y, 0.0, "%s: bbox height" % record.id)
		check_false(record.search_key.is_empty(), "%s: search key" % record.id)


func test_missing_optional_values_are_explicit() -> void:
	_load()
	var without_capital := 0
	for record: CountryRecord in _registry.all():
		if not record.has_capital():
			without_capital += 1
			check_false(record.capital.to_lower().contains("unknown"),
					"%s: a missing capital must be empty, not an invented placeholder" % record.id)
		if not record.has_iso_a3():
			check_true(record.iso_label().contains("No ISO code"),
					"%s: the ISO line must say a code is missing" % record.id)
	check_gt(float(without_capital), 0.0,
			"the dataset records no capital for some territories; that must be visible")
	for record: CountryRecord in _registry.all():
		check_false(record.capital == "N/A", "%s: no 'N/A' placeholders" % record.id)


func test_geometry_references_resolve() -> void:
	_load()
	check_true(_geometry.is_loaded(), "geometry.json must parse")
	check_eq(_registry.count(), _geometry.count(),
			"every country must have exactly one geometry entry")
	check_eq(_atlas.unshaped_country_ids().size(), 0,
			"no country may be missing a shape (%s)" % str(_atlas.unshaped_country_ids()))
	check_eq(_atlas.orphan_geometry_ids().size(), 0,
			"no shape may exist without a country record (%s)" % str(_atlas.orphan_geometry_ids()))


func test_search_matches_names_and_codes_case_insensitively() -> void:
	_load()
	var lower := _registry.search("bangladesh")
	check_gte(float(lower.size()), 1.0, "search must find Bangladesh by lowercase name")
	check_eq(lower[0].id, "BGD", "the first match for 'bangladesh' is Bangladesh")
	check_eq(_registry.search("BANGLADESH").size(), lower.size(),
			"search must ignore case")
	check_eq(_registry.search("bgd")[0].id, "BGD", "search must match the ISO alpha-3 code")
	check_eq(_registry.search("bd")[0].id, "BGD", "search must match the ISO alpha-2 code")
	var folded := _registry.search("cote")
	check_gte(float(folded.size()), 1.0, "search must fold diacritics (Côte d'Ivoire)")
	check_eq(folded[0].id, "CIV", "'cote' must find Côte d'Ivoire")
	check_eq(_registry.search("zzzzz").size(), 0, "an unmatched query returns nothing")
	check_eq(_registry.search("   ").size(), _registry.count(),
			"an empty query returns every country")
	check_true(_registry.search("isr").any(func(record: CountryRecord) -> bool:
		return record.id == "ISR"), "search must find Israel by code and name")


## Search must be deterministic and free of duplicates: the same query twice, and
## the same query in different casing or with padding, must return the same ids in
## the same order. Two result rows for one country would be a UI bug.
func test_search_is_deterministic_and_never_duplicates() -> void:
	_load()
	for query: String in ["a", "an", "guinea", "saint", "island", "republic", "bd"]:
		var first := _registry.search(query)
		var second := _registry.search(query)
		check_eq(first.size(), second.size(), "'%s' returns a stable number of matches" % query)
		var seen := {}
		for index in first.size():
			check_eq(first[index].id, second[index].id,
					"'%s' returns the same order twice" % query)
			check_false(seen.has(first[index].id),
					"'%s' lists %s twice" % [query, first[index].id])
			seen[first[index].id] = true
		check_eq(_registry.search(query.to_upper()).size(), first.size(),
				"'%s' is case-insensitive" % query)
		check_eq(_registry.search("  %s  " % query).size(), first.size(),
				"'%s' ignores surrounding whitespace" % query)


## Ranking is a promise, not an accident: an exact ISO code or exact name must come
## before a prefix match, and a fresh load must produce exactly the same order, so
## a player who types the same thing twice sees the same list.
func test_search_ranking_is_stable_and_exact_matches_come_first() -> void:
	_load()
	for needle: String in ["bd", "bgd", "fji", "singapore", "seychelles"]:
		var results := _registry.search(needle)
		check_gt(float(results.size()), 0.0, "'%s' finds something" % needle)
		var leader := results[0]
		var leader_rank := CountryRegistry._rank(leader, needle.to_lower())
		for record: CountryRecord in results:
			var rank := CountryRegistry._rank(record, needle.to_lower())
			check_gte(float(rank), float(leader_rank),
					"'%s': no result outranks the first one" % needle)
	# An exact code must win outright.
	check_eq(_registry.search("bgd")[0].id, "BGD", "an exact ISO alpha-3 finds its country first")
	check_eq(_registry.search("BD")[0].id, "BGD", "an exact ISO alpha-2 finds its country first")
	# Reloading the registry must not shuffle identical queries.
	var reloaded := CountryRegistry.from_file()
	for needle: String in ["bd", "guinea", "saint"]:
		var first := _registry.search(needle)
		var second := reloaded.search(needle)
		check_eq(first.size(), second.size(), "'%s' has the same count after a reload" % needle)
		for index in first.size():
			check_eq(first[index].id, second[index].id,
					"'%s' keeps its order after a reload" % needle)


## Documented aliases: the search key carries the source's formal and sort names,
## which is where spellings such as "People's Republic of Bangladesh" come from.
## They are data, generated by the pipeline, not a hand-written alias table.
func test_long_and_alternate_names_match_the_same_record() -> void:
	_load()
	for entry: Array in [["people's republic of bangla", "BGD"],
			["ivory coast", "CIV"], ["state of the vatican city", "VAT"],
			["russian federation", "RUS"]]:
		var query: String = entry[0]
		var expected: String = entry[1]
		var matches := _registry.search(query)
		var ids := PackedStringArray()
		for record: CountryRecord in matches:
			ids.append(record.id)
		check_true(ids.has(expected),
				"'%s' must match %s (got %s)" % [query, expected, str(ids)])


func test_regions_cover_the_required_classifications() -> void:
	_load()
	var regions := _registry.regions()
	for expected: String in ["Africa", "Asia", "Europe", "North America", "Oceania",
			"South America"]:
		check_true(regions.has(expected), "regions() must expose %s" % expected)
		check_gt(float(_registry.region_count(expected)), 0.0, "%s must contain countries" % expected)
	var total := 0
	for region: String in regions:
		total += _registry.region_count(region)
	var classified := 0
	for record: CountryRecord in _registry.all():
		if record.filter_region:
			classified += 1
			check_true(regions.has(record.region),
					"%s: filterable records must use a filterable region" % record.id)
	check_eq(total, classified,
			"each filterable country belongs to exactly one region filter")
	check_eq(_registry.by_region("Antarctica").size(), 0,
			"Antarctica is not one of the required filter regions")


func test_query_and_region_filters_combine() -> void:
	_load()
	var africa := _registry.filter("", "Africa")
	check_gt(float(africa.size()), 30.0, "Africa must contain a plausible number of countries")
	for record: CountryRecord in africa:
		check_eq(record.region, "Africa", "%s is not in Africa" % record.id)
	var combined := _registry.filter("a", "Africa")
	check_gt(float(combined.size()), 0.0, "the combined filter must find matches")
	check_lte(float(combined.size()), float(africa.size()),
			"the combined filter must narrow, never widen")
	for record: CountryRecord in combined:
		check_eq(record.region, "Africa", "%s leaked through the region filter" % record.id)
		check_true(record.search_key.contains("a"), "%s does not match the query" % record.id)
	check_eq(_registry.filter("", "Nowhere").size(), 0, "an unknown region matches nothing")
	check_eq(_registry.filter("", "").size(), _registry.count(),
			"no filter returns every country")


func test_unknown_ids_return_null() -> void:
	_load()
	check_true(_registry.get_country("ZZZ") == null, "unknown ids must resolve to null")
	check_false(_registry.has_country("ZZZ"), "unknown ids are not present")
	check_true(_registry.get_country("") == null, "the empty id is not a country")
	check_true(_registry.get_country("bgd") == null,
			"ids are case-sensitive; search handles casing instead")


func test_registry_rejects_malformed_records() -> void:
	var data := {
		"countries": [
			{"id": "AAA", "name": "Alpha", "region": "Asia", "bbox": [-1, -1, 1, 1]},
			{"id": "AAA", "name": "Duplicate", "region": "Asia", "bbox": [-1, -1, 1, 1]},
			{"id": "BBB", "region": "Asia", "bbox": [-1, -1, 1, 1]},
			{"name": "No identifier", "bbox": [-1, -1, 1, 1]},
			{"id": "CCC", "name": "Gamma", "region": "Asia", "iso_a2": "CN-TW",
				"bbox": [1, 1, 2, 2]},
			{"id": "DDD", "name": "Delta", "region": "Asia"},
			"not even a dictionary",
		],
	}
	var registry := CountryRegistry.from_data(data, "test")
	check_eq(registry.count(), 3, "only records with an id, a name and a bbox survive")
	check_true(registry.has_country("AAA") and registry.has_country("CCC")
			and registry.has_country("DDD"), "the usable records are kept")
	check_false(registry.has_country("BBB"), "a nameless record is rejected")
	var joined := " ".join(registry.issues())
	check_true(joined.contains("duplicate"), "duplicates must be reported (%s)" % joined)
	check_true(joined.contains("malformed iso_a2"), "malformed ISO codes must be reported")
	var gamma := registry.get_country("CCC")
	check_eq(gamma.iso_a2, "", "a malformed alpha-2 code is dropped, not stored")
	check_eq(registry.from_data(null).count(), 0, "a null document yields an empty registry")
	check_eq(CountryRegistry.from_data({"nope": 1}).count(), 0,
			"a document without a countries array yields an empty registry")


func test_manifest_matches_the_shipped_data() -> void:
	_load()
	var manifest := _atlas.manifest
	check_false(manifest.is_empty(), "the data-source manifest must be shipped")
	var source: Dictionary = manifest.get("source", {})
	for key: String in ["dataset", "repository", "commit", "version", "licence", "url",
			"retrieved"]:
		check_false(str(source.get(key, "")).is_empty(),
				"the manifest must record '%s'" % key)
	check_true(str(source.get("licence", "")).contains("Public Domain"),
			"the licence must be recorded as public domain")
	check_true(str(source.get("url", "")).contains("natural-earth-vector"),
			"the manifest must point at the data source")
	var counts: Dictionary = manifest.get("counts", {})
	check_eq(int(counts.get("countries", -1)), _registry.count(),
			"the manifest's country count must match the registry")
	check_eq(int(counts.get("polygons", -1)), _geometry.polygon_count(),
			"the manifest's polygon count must match the geometry")
	check_eq(int(counts.get("vertices", -1)), _geometry.vertex_count(),
			"the manifest's vertex count must match the geometry")
	var processing: Dictionary = manifest.get("processing", {})
	check_gt(float((processing.get("steps", []) as Array).size()), 0.0,
			"the processing steps must be documented")
	var limitations := " ".join(manifest.get("known_limitations", []))
	check_true(limitations.contains("Palestine"),
			"the known limitations must document the neutral treatment of the "
			+ "Israel/Palestine map unit")
	check_true(limitations.contains("1:50m"),
			"the generalisation level must be documented")


func test_data_source_documentation_is_shipped() -> void:
	var path := "res://docs/DATA_SOURCES.md"
	check_true(FileAccess.file_exists(path), "docs/DATA_SOURCES.md must exist")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		check_true(false, "docs/DATA_SOURCES.md must be readable")
		return
	var text := file.get_as_text()
	file.close()
	check_true(text.contains("Natural Earth"), "the document must name the dataset")
	check_true(text.contains("nvkelso/natural-earth-vector"),
			"the document must name the repository")
	check_true(text.contains("Public Domain"), "the document must state the licence")
	check_true(text.contains("1:50m"), "the document must state the generalisation")
	check_true(text.contains("build_world_atlas.py"),
			"the document must describe the reproducible pipeline")
