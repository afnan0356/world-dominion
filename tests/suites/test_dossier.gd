extends TestCase
## The country dossier: sections, sourced values, honest gaps, planned systems.
##
## The point of these tests is the honesty rule — the dossier may show a value the
## dataset records, or an explicit gap, and nothing else. They also pin the
## extension seam: sections are data, so a future system can add one without the
## panel growing a branch for it.

var _registry: CountryRegistry


func _load() -> void:
	if _registry == null:
		_registry = CountryRegistry.from_file()


func _dossier(country_id: String, context: Dictionary = {}) -> CountryDossier:
	_load()
	return CountryDossier.build(_registry.get_country(country_id), context)


func test_every_record_produces_the_four_recorded_sections() -> void:
	_load()
	for record: CountryRecord in _registry.all():
		var dossier := CountryDossier.build(record)
		var ids := PackedStringArray()
		for section: CountryDossier.Section in dossier.sections:
			ids.append(section.id)
			check_false(section.planned, "%s sections are recorded, not planned" % record.id)
		check_eq(ids, CountryDossier.RECORDED_SECTIONS,
				"%s dossier has the documented section order" % record.id)
		check_eq(dossier.country_id, record.id, "the dossier names its own country")


func test_sourced_values_are_shown_verbatim() -> void:
	var dossier := _dossier("BGD")
	var administration := dossier.section(CountryDossier.ADMINISTRATION)
	check_not_null(administration, "Bangladesh has an administration section")
	var values := {}
	for field: CountryDossier.Field in administration.fields:
		values[field.label] = field.value
	check_eq(values.get("Capital"), "Dhaka", "a sourced capital is shown exactly as recorded")
	check_eq(values.get("ISO alpha-3"), "BGD", "a sourced ISO code is shown")
	check_eq(values.get("ISO alpha-2"), "BD", "the alpha-2 code is shown")
	check_eq(values.get("Stable ID"), "BGD", "the stable id is part of the dossier")


func test_missing_values_become_explicit_gaps() -> void:
	# Palestine has no capital in the Natural Earth source; Somaliland has no ISO code
	# of its own in it either. (France used to be the second example, until Milestone 06
	# adopted the source's own corrected field and gave it FR/FRA — the gap moved, the
	# rule did not.)
	var dossier := _dossier("PSE")
	var administration := dossier.section(CountryDossier.ADMINISTRATION)
	check_not_null(administration, "Palestine has an administration section")
	var gaps := dossier.missing_fields()
	check_true(gaps.has("administration/Capital"), "a missing capital is reported as a gap")
	var somaliland := _dossier("SOL").missing_fields()
	check_true(somaliland.has("administration/ISO alpha-2"),
			"a record with no code of its own shows a gap, not a borrowed code")
	check_true(somaliland.has("administration/ISO alpha-3"), "and the alpha-3 is a gap too")
	var france := _dossier("FRA").missing_fields()
	check_false(france.has("administration/ISO alpha-2"),
			"a code the source has, once adopted, is no longer a gap")
	for field: CountryDossier.Field in administration.fields:
		if field.label == "Capital":
			check_false(field.recorded, "the capital field is marked as not recorded")
			check_eq(field.value, "Not recorded in source", "the gap is stated in words")


func test_no_section_invents_a_statistic() -> void:
	_load()
	# No dossier field may look like a population, GDP or military figure: the
	# dataset does not carry them and this build does not compute them.
	for record: CountryRecord in _registry.all():
		var dossier := CountryDossier.build(record)
		for section: CountryDossier.Section in dossier.sections:
			for field: CountryDossier.Field in section.fields:
				var label := field.label.to_lower()
				for forbidden: String in ["population", "gdp", "military", "approval",
						"stability", "economy", "currency"]:
					check_false(label.contains(forbidden),
							"%s dossier must not show a %s field" % [record.id, forbidden])
				check_false(field.value.contains("unknown %"),
						"no placeholder percentages")


func test_planned_sections_are_named_but_empty() -> void:
	var planned := CountryDossier.planned_sections()
	check_eq(planned.size(), 7, "the seven future systems are declared")
	for section: CountryDossier.Section in planned:
		check_true(section.planned, "%s is marked as planned" % section.id)
		check_eq(section.fields.size(), 0, "%s carries no invented values" % section.id)
		check_true(section.note.contains("Not implemented"),
				"%s says it is not implemented" % section.id)
	var titles := PackedStringArray()
	for section: CountryDossier.Section in planned:
		titles.append(section.title)
	check_true(titles.has("Population"), "population is a declared future section")
	check_true(titles.has("Military"), "military is a declared future section")


func test_geometry_context_appears_in_the_geography_section() -> void:
	var dossier := _dossier("IDN", {
		"polygons": 12, "rings": 14, "vertices": 4210, "scale": 200,
	})
	var geography := dossier.section(CountryDossier.GEOGRAPHY)
	check_not_null(geography, "Indonesia has a geography section")
	var values := {}
	for field: CountryDossier.Field in geography.fields:
		values[field.label] = field.value
	check_eq(values.get("Landmasses"), "12 polygons",
			"an archipelago reports its disconnected parts")
	check_eq(values.get("Vertices"), "4210", "the vertex count is the real one passed in")
	check_true(str(values.get("Map extent", "")).contains("°"),
			"the extent is expressed in degrees")


func test_extent_formatting_is_readable_and_signed() -> void:
	var bbox := Rect2(Vector2(-74.0, -34.0), Vector2(70.0, 40.0))
	check_eq(CountryDossier.extent_label(bbox), "34.0°S – 6.0°N · 74.0°W – 4.0°W",
			"extents use hemispheres instead of negative numbers")
	check_eq(CountryDossier.extent_label(Rect2()), "Not recorded in source",
			"a degenerate bbox is a gap, not a zero")


func test_sources_section_quotes_the_manifest() -> void:
	var dossier := _dossier("FRA", {
		"dataset": "Natural Earth 1:50m", "dataset_version": "5.2.0-pre",
		"dataset_commit": "ca96624a56bd078437bca8184e78163e5039ad19",
		"licence": "Public Domain", "retrieved": "2026-11-05",
	})
	var sources := dossier.section(CountryDossier.SOURCES)
	var values := {}
	for field: CountryDossier.Field in sources.fields:
		values[field.label] = field.value
	check_eq(values.get("Dataset version"), "5.2.0-pre", "the dataset version is shown")
	check_eq(values.get("Licence"), "Public Domain", "the licence is shown")
	check_eq(values.get("Source commit"), "ca96624a56", "the commit is shortened, not invented")


func test_a_null_record_yields_an_empty_dossier() -> void:
	var dossier := CountryDossier.build(null)
	check_eq(dossier.country_id, "", "no country, no id")
	check_eq(dossier.sections.size(), 0, "no country, no sections")
	check_eq(dossier.missing_fields().size(), 0, "nothing is reported missing for nothing")
