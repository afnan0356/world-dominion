extends TestCase
## Sourced key figures: the file, the dossier group, and the comparison screen.
##
## The promise this suite defends is narrow and absolute: a number is shown only when
## the pinned source states it, together with the year it refers to; and when the
## source has nothing, the game says "Not available" rather than zero. Two records
## make that concrete — one whose population the source gives as a fraction (rejected
## by the builder, so the game shows nothing) and one whose GDP the source marks with
## a `-99` sentinel (also rejected).
##
## The third promise is scope: these figures are read-only reference data. They are not
## in `WorldState`, not in a save, and nothing simulates them. The last test walks the
## simulation and save code to prove no file there even mentions them.

const SCREEN_SCENE := "res://src/ui/screens/comparison_screen.tscn"
const STATISTICS_PATH := "res://data/world/statistics.json"
const MANIFEST_PATH := "res://data/world/manifest.json"
const BGD := "BGD"
const SOM := "SOM"
const VAT := "VAT"
const SIZES: Array[Vector2i] = [Vector2i(640, 360), Vector2i(1024, 768), Vector2i(1440, 900)]

var _statistics: CountryStatistics
var _atlas: WorldAtlas
var _screen: Control


func _load_statistics() -> CountryStatistics:
	if _statistics == null:
		_statistics = CountryStatistics.load_default()
	return _statistics


func _load_atlas() -> WorldAtlas:
	if _atlas == null:
		_atlas = WorldAtlas.load_default()
	return _atlas


func _open_screen() -> Control:
	if _screen != null and is_instance_valid(_screen):
		return _screen
	var scene: PackedScene = load(SCREEN_SCENE)
	_screen = scene.instantiate() as Control
	host.add_child(_screen)
	return _screen


func _close_screen() -> void:
	if _screen != null and is_instance_valid(_screen):
		host.remove_child(_screen)
		_screen.queue_free()
	_screen = null


# --- the file ---------------------------------------------------------------

func test_file_loads_with_its_source() -> void:
	var stats := _load_statistics()
	check_true(stats.is_loaded(), "statistics.json loads")
	check_eq(_load_statistics().count(), 242, "every record is in the file")
	check_eq(stats.schema, 1, "schema version is 1")
	check_true(stats.notice.contains("not live"), "the file carries its own not-live notice")
	for key in ["id", "dataset", "version", "licence", "url", "retrieved", "sha256",
			"attribution"]:
		check_true(not str(stats.source.get(key, "")).is_empty(),
				"source block records %s" % key)
	check_true(str(stats.source.get("licence", "")).contains("Public Domain"),
			"the licence is the source's public-domain dedication")
	check_true(str(stats.source.get("sha256", "")).length() == 64,
			"the source file hash is recorded, so a rebuild can be checked")


func test_manifest_and_pack_agree() -> void:
	var manifest := DataLoader.load_dictionary(MANIFEST_PATH)
	var block: Dictionary = manifest.get("statistics", {})
	check_false(block.is_empty(), "the manifest describes the statistics file")
	check_eq(int(block.get("schema", 0)), 1, "manifest statistics schema")
	var on_disk := FileAccess.get_sha256(STATISTICS_PATH)
	check_eq(str(block.get("sha256", "")), on_disk,
			"the manifest hash is the hash of the file on disk")
	check_eq(int(block.get("records_with_data", 0)), _load_statistics().count(),
			"the manifest count matches the file")
	check_true(str(block.get("report", "")).ends_with("STATISTICS_REPORT.md"),
			"the manifest points at the report a reviewer can read")


func test_every_figure_is_sourceful_and_dated() -> void:
	var stats := _load_statistics()
	var missing := 0
	for country_id in _load_atlas().registry.ids():
		if not stats.has(country_id):
			missing += 1
			continue
		for definition: Dictionary in stats.definitions():
			var key := str(definition["key"])
			var figure := stats.figure(country_id, key)
			if figure.is_empty():
				continue
			var value: Variant = figure.get("value")
			check_true(value is int, "%s.%s is an exact integer" % [country_id, key])
			check_gte(float(value), 0.0, "%s.%s is not negative" % [country_id, key])
			if bool(figure.get("derived", false)):
				check_true(not str(figure.get("method", "")).is_empty(),
						"%s.%s says how it was derived" % [country_id, key])
				check_eq(str(figure.get("as_of_label", "")), "map outline",
						"%s.%s is dated by what it came from" % [country_id, key])
			else:
				var year := int(figure.get("year", 0))
				check_true(year >= 1900 and year <= 2100,
						"%s.%s carries an as-of year" % [country_id, key])
				check_true(not str(figure.get("source_field", "")).is_empty(),
						"%s.%s names the source field" % [country_id, key])
	check_eq(missing, 0, "every registry record has a statistics file")


func test_source_values_are_what_the_source_says() -> void:
	var stats := _load_statistics()
	# Anchored to the pinned file, not to memory: these are the numbers the source
	# states for Bangladesh, and the year it states them for.
	check_eq(stats.value(BGD, "population"), 163046161, "Bangladesh population")
	check_eq(stats.year(BGD, "population"), 2019, "Bangladesh population year")
	check_eq(stats.value(BGD, "gdp_usd"), 302571000000, "Bangladesh GDP in dollars")
	check_eq(stats.year(BGD, "gdp_usd"), 2019, "Bangladesh GDP year")
	check_eq(stats.value(BGD, "area_km2"), 135638, "Bangladesh area from the outline")
	check_true(stats.is_derived(BGD, "area_km2"), "area is marked derived")
	check_false(stats.is_derived(BGD, "population"), "population is not derived")


func test_rejected_values_are_missing_not_zero() -> void:
	var stats := _load_statistics()
	# Somalia: the source writes 10192317.3 people — a fraction, so the builder rejects
	# it. Somalia still has a GDP and an area, so the file exists; population does not.
	check_true(stats.has(SOM), "Somalia has a statistics file")
	check_true(stats.value(SOM, "population") == null, "Somalia population is absent")
	check_eq(stats.figure(SOM, "population").size(), 0, "no population entry at all")
	check_true(stats.value(SOM, "gdp_usd") != null, "Somalia GDP is still shown")
	check_false(stats.describe(SOM, stats.definitions()[0]).contains("0 people"),
			"the missing figure is never rendered as zero")
	check_eq(stats.describe(SOM, stats.definitions()[0]), "Not available",
			"the missing figure is rendered as words")

	# Vatican City: GDP_MD is -99, the source's no-data sentinel.
	check_true(stats.value(VAT, "gdp_usd") == null, "Vatican GDP is absent")
	check_true(stats.value(VAT, "population") != null, "Vatican population is present")

	# A zero can also be real, and must be kept: these territories have no residents.
	check_eq(stats.value("ATC", "population"), 0, "an uninhabited territory keeps its zero")
	check_true(stats.has("ATC"), "the zero is a value, not a gap")


func test_unloaded_file_answers_nothing() -> void:
	var empty := CountryStatistics.from_file("res://data/world/does_not_exist.json")
	check_false(empty.is_loaded(), "a missing file loads as empty")
	check_eq(empty.count(), 0, "an empty file has no records")
	check_true(empty.value(BGD, "population") == null, "an empty file answers null")
	check_eq(empty.describe(BGD, empty.definitions()[0]), "Not available",
			"an empty file says Not available")


func test_integer_formatting_is_ascii_and_stable() -> void:
	check_eq(CountryStatistics.format_integer(0), "0", "zero")
	check_eq(CountryStatistics.format_integer(999), "999", "three digits")
	check_eq(CountryStatistics.format_integer(1000), "1,000", "thousands")
	check_eq(CountryStatistics.format_integer(163046161), "163,046,161", "millions")
	check_eq(CountryStatistics.format_integer(302571000000), "302,571,000,000", "billions")
	check_eq(CountryStatistics.format_integer(-1500), "-1,500", "negative values keep sign")


# --- the dossier ------------------------------------------------------------

func test_dossier_shows_key_figures_with_year_and_source() -> void:
	var atlas := _load_atlas()
	var record: CountryRecord = atlas.registry.get_country(BGD)
	var dossier := CountryDossier.build(record, {"statistics": _load_statistics()})
	var section := _section(dossier, CountryDossier.KEY_FIGURES)
	check_not_null(section, "the dossier has a Key figures group")
	if section == null:
		return
	check_eq(section.fields.size(), 4, "three figures plus the source line")
	var labels: Array[String] = []
	for field: CountryDossier.Field in section.fields:
		labels.append(field.label)
	check_eq(labels[0], "Population", "first figure is population")
	check_eq(labels[1], "GDP", "second figure is GDP")
	check_eq(labels[2], "Area (derived)", "area says it is derived")
	check_eq(labels[3], "Source", "the group names its source")
	check_eq(section.fields[0].value, "163,046,161 people (2019)",
			"population is formatted with its as-of year")
	check_true(section.fields[1].value.ends_with("(2019)"), "GDP carries its year")
	check_true(section.fields[2].value.contains("derived from the map outline"),
			"area says where it came from")
	check_true(section.fields[0].recorded, "a real figure is recorded")
	check_true(section.note.contains("not live"), "the group says it is not live")


func test_dossier_marks_gaps_instead_of_zero() -> void:
	var atlas := _load_atlas()
	var record: CountryRecord = atlas.registry.get_country(SOM)
	var section := _section(CountryDossier.build(record, {"statistics": _load_statistics()}),
			CountryDossier.KEY_FIGURES)
	check_not_null(section, "Somalia still has a Key figures group")
	if section == null:
		return
	check_eq(section.fields[0].value, "Not available", "missing population says so")
	check_false(section.fields[0].recorded, "a missing figure is styled as a gap")
	check_true(section.fields[1].value.contains("US dollars"), "GDP is still shown")


func test_dossier_without_statistics_says_so() -> void:
	var atlas := _load_atlas()
	var record: CountryRecord = atlas.registry.get_country(BGD)
	var section := _section(CountryDossier.build(record, {}), CountryDossier.KEY_FIGURES)
	check_not_null(section, "the group exists even with no file loaded")
	if section == null:
		return
	check_eq(section.fields.size(), 0, "no field is invented without a source")
	check_true(section.note.contains("Nothing is estimated"), "it says why it is empty")


func test_panel_hosts_the_group_and_a_compare_button() -> void:
	var atlas := _load_atlas()
	var panel := CountryInfoPanel.new()
	host.add_child(panel)
	panel.show_country(atlas.registry.get_country(BGD), {"statistics": _load_statistics()})
	check_not_null(panel.compare_button(), "the panel offers a compare button")
	if panel.compare_button() != null:
		check_eq(panel.compare_button().focus_mode, Control.FOCUS_ALL,
				"the compare button is keyboard focusable")
		check_gte(panel.compare_button().custom_minimum_size.y,
				float(DesignTokens.TOUCH_TARGET_MIN), "the compare button is finger sized")
	var dossier: CountryDossier = panel.dossier()
	check_not_null(_section(dossier, CountryDossier.KEY_FIGURES),
			"the panel renders the Key figures group")
	var fired := {"id": ""}
	panel.compare_requested.connect(func(country_id: String) -> void: fired["id"] = country_id)
	if panel.compare_button() != null:
		panel.compare_button().pressed.emit()
	check_eq(fired["id"], BGD, "pressing it reports the selected country")
	host.remove_child(panel)
	panel.queue_free()


# --- the comparison screen --------------------------------------------------

func test_comparison_screen_shows_one_two_and_three_countries() -> void:
	var screen := _open_screen()
	check_eq(screen.selected_ids().size(), 0, "it starts empty")
	check_true(screen.add_country(BGD), "one country added")
	check_eq(screen.selected_ids().size(), 1, "one column")
	check_eq(screen.cell_text("population", 0), "163,046,161", "population in column 1")
	check_eq(screen.as_of_text("population", 0), "2019", "the year is beside the value")
	check_true(screen.add_country("IND"), "two countries added")
	check_eq(screen.selected_ids().size(), 2, "two columns")
	check_true(screen.add_country("NPL"), "three countries added")
	check_eq(screen.selected_ids().size(), 3, "three columns")
	check_eq(screen.cell_text("population", 2), CountryStatistics.format_integer(
			int(_load_statistics().value("NPL", "population"))), "third column is its own value")
	check_false(screen.add_country("LKA"), "a fourth country is refused")
	check_eq(screen.selected_ids().size(), 3, "still three columns")
	check_true(screen.status_text().contains("Three countries"),
			"the refusal explains itself")
	_close_screen()


func test_comparison_screen_rejects_duplicates_and_unknowns() -> void:
	var screen := _open_screen()
	check_true(screen.add_country(BGD), "first add works")
	check_false(screen.add_country(BGD), "the same country cannot be added twice")
	check_false(screen.add_country("ZZZ"), "an unknown id is refused")
	check_false(screen.add_country(""), "an empty id is refused")
	check_eq(screen.selected_ids().size(), 1, "nothing changed")
	check_true(screen.status_text().contains("not in this build"),
			"the unknown id is explained")
	check_true(screen.remove_country(BGD), "removing works")
	check_eq(screen.selected_ids().size(), 0, "the table is empty again")
	check_false(screen.remove_country(BGD), "removing twice is harmless")
	_close_screen()


func test_comparison_screen_shows_a_dash_for_missing_values() -> void:
	var screen := _open_screen()
	check_true(screen.add_country(VAT), "Vatican City added")
	check_eq(screen.cell_text("gdp_usd", 0), "—", "a missing GDP is a dash")
	check_eq(screen.as_of_text("gdp_usd", 0), "", "a missing figure has no year")
	check_true(screen.cell_text("population", 0) != "0", "a missing figure is not zero")
	# Vatican City has no area either — its outline encloses nothing at 1:50m — so the
	# derived-value case needs a record that has one.
	check_eq(screen.cell_text("area_km2", 0), "—", "a missing area is a dash too")
	check_true(screen.add_country(BGD), "Bangladesh added beside it")
	check_eq(screen.as_of_text("area_km2", 1), "map outline (derived)",
			"derived figures say what they came from")
	check_false(screen.status_text().contains("rank"), "no ranking language")
	check_true(screen.status_text().contains("not live"), "the read-only notice is shown")
	_close_screen()


func test_comparison_screen_accepts_its_opening_country() -> void:
	var screen := _open_screen()
	screen.receive_params({"country_id": "FJI"})
	check_eq(screen.selected_ids().size(), 1, "the dossier's country is preselected")
	check_eq(screen.selected_ids()[0], "FJI", "and it is the right one")
	_close_screen()


func test_comparison_screen_is_keyboard_reachable() -> void:
	var screen := _open_screen()
	check_true(screen.add_country(BGD), "one column")
	var chips := screen.get_node("%Chips") as HBoxContainer
	check_gte(float(chips.get_child_count()), 1.0, "a remove chip exists")
	for child: Node in chips.get_children():
		var chip := child as Button
		check_not_null(chip, "each chip is a button")
		if chip != null:
			check_eq(chip.focus_mode, Control.FOCUS_ALL, "the chip takes keyboard focus")
	var search: CountrySearch = screen.search_field()
	check_not_null(search, "the search field is present")
	search.focus_field()
	var focused := screen.get_viewport().gui_get_focus_owner()
	check_not_null(focused, "the search field can take keyboard focus")
	check_true(focused is LineEdit, "focus lands in the text field, not on a label")
	# Enter on a focused chip removes that country: the whole flow is reachable with
	# the keyboard alone, which is what the focus traversal is for.
	var chip := chips.get_child(0) as Button
	if chip != null:
		chip.grab_focus()
		check_eq(screen.get_viewport().gui_get_focus_owner(), chip,
				"a chip can hold focus")
		chip.pressed.emit()
		check_eq(screen.selected_ids().size(), 0, "the chip removes the country")
	_close_screen()


func test_comparison_screen_fits_every_layout_and_theme() -> void:
	var screen := _open_screen()
	screen.add_country(BGD)
	screen.add_country(VAT)
	screen.add_country("IND")
	var content := screen.get_node("%Content") as Control
	for size: Vector2i in SIZES:
		screen.size = Vector2(size)
		screen.on_layout_changed(DesignTokens.layout_mode(Vector2(size)), false, Vector2(size))
		check_lte(content.custom_minimum_size.x, float(size.x),
				"the table fits the %dx%d layout" % [size.x, size.y])
		check_eq(screen.cell_text("population", 0), "163,046,161",
				"the values do not change with the layout")
	var original_theme := Settings.get_theme_id()
	for palette_id: String in Palette.ids():
		Settings.set_theme_id(palette_id)
		check_eq(ThemeManager.palette_id(), palette_id,
				"%s: the theme manager follows the setting" % palette_id)
		check_eq(screen.cell_text("gdp_usd", 1), "—",
				"%s: the missing value is still a dash" % palette_id)
		check_eq(screen.cell_text("population", 0), "163,046,161",
				"%s: the figures do not change with the theme" % palette_id)
	Settings.set_theme_id(original_theme)
	_close_screen()


func test_comparison_screen_has_no_ranking() -> void:
	var screen := _open_screen()
	screen.add_country(BGD)
	screen.add_country("IND")
	var forbidden := ["best", "worst", "rank", "score", "higher", "winner", "top "]
	var text: String = screen.status_text().to_lower()
	var headers := ""
	for child: Node in screen.table().get_children():
		if child is Label:
			headers += (child as Label).text.to_lower() + " "
	text += " " + headers
	for word: String in forbidden:
		check_false(text.contains(word), "the screen never says '%s'" % word.strip_edges())
	# The columns stay in the order the player chose them, whatever the values are.
	check_eq(screen.selected_ids()[0], BGD, "the first chosen country is the first column")
	check_eq(screen.selected_ids()[1], "IND", "the second is the second")
	_close_screen()


# --- scope ------------------------------------------------------------------

func test_statistics_never_reach_the_simulation_or_a_save() -> void:
	# The rule changed deliberately in Milestone 11, and this is the record of why.
	#
	# Until Milestone 10 the rule was "simulation and save code must not mention the figures at
	# all", which was easy to hold because nothing simulated anything. Milestone 11 gave every
	# country a baseline (`CountryState`) and one system that checks it, so a simulation file now
	# legitimately *reads* a baseline. The rule that matters was never "no file may say the word":
	# it is **nobody may read the raw dataset**. A system that opened `statistics.json` itself
	# would bypass the missing-value rule, the recorded data version, the override layer and the
	# change report — four things the baseline exists to guarantee.
	#
	# So the ban is now on the raw data and the parser, in both layers:
	# (A save file *is* read by string in `SaveStore`, which is fine and unrelated: what is
	# banned here is reading the **dataset** — the parser, the two data files, and the loader
	# that wraps them.)
	var banned: Array[String] = ["CountryStatistics", "statistics.json", "key_figures",
			"currency_crosswalk.json", "DataLoader.load_json", "DataLoader.load_dictionary"]
	var offenders: PackedStringArray = []
	for folder: String in ["res://src/core/sim", "res://src/core/save"]:
		for path in _gd_files_under(folder):
			var text := FileAccess.get_file_as_string(path)
			for needle: String in banned:
				if text.contains(needle):
					offenders.append("%s mentions %s" % [path.get_file(), needle])
	check_eq(offenders.size(), 0,
			"only CountryState reads the dataset: %s" % ", ".join(offenders))
	# And the API is really the path: the one system that checks the baseline asks CountryState,
	# so a later refactor cannot quietly reintroduce a second reader.
	var system := FileAccess.get_file_as_string(
			"res://src/core/sim/systems/baseline_integrity_system.gd")
	check_true(system.contains("CountryState"), "the baseline check asks CountryState, not a file")
	check_true(system.contains("country_state_reference()"),
			"and compares against the reference the campaign recorded")
	# The loader is still read-only: no setter, no write path, no link to world state.
	var loader := FileAccess.get_file_as_string(
			"res://src/core/world/country_statistics.gd")
	check_false(loader.contains("func set_"), "the loader has no write path")
	check_false(loader.contains("WorldState."),
			"the loader does not touch world state")
	# The baseline is read-only by construction: no write API at all.
	var baseline := FileAccess.get_file_as_string("res://src/core/world/country_state.gd")
	check_false(baseline.contains("func set_"), "the baseline has no setter")
	check_false(baseline.contains("func write_"), "and no write function")
	check_true(baseline.contains("duplicate(true)"),
			"and it hands out copies, so a caller cannot edit it in place")


func _gd_files_under(path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if dir.current_is_dir():
			out.append_array(_gd_files_under(path.path_join(name)))
		elif name.ends_with(".gd"):
			out.append(path.path_join(name))
		name = dir.get_next()
	dir.list_dir_end()
	return out


func _section(dossier: CountryDossier, section_id: String) -> CountryDossier.Section:
	if dossier == null:
		return null
	for section: CountryDossier.Section in dossier.sections:
		if section.id == section_id:
			return section
	return null
