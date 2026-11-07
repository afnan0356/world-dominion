extends TestCase
## Flags in the screens players already use, and the string table (Milestone 08, Task 1).
##
## The rules under test: a mapped record shows its flag, a record with no flag shows a
## neutral code badge, the badge is what is visible until the flag arrives (so a list never
## blocks on rasterising), and scrolling a long result list does not accumulate nodes or
## textures.

const FLAGLESS := ["ATC", "IOA", "CYN", "KAS", "SOL"]
## Files this milestone writes, listed so the guard is meaningful before a screen exists and
## grows as each task lands.
const NEW_FILES := ["res://src/ui/screens/diagnostics/diagnostics_screen.gd",
	"res://src/ui/screens/help/help_screen.gd",
	"res://src/ui/screens/roadmap/roadmap_screen.gd",
	"res://src/ui/components/flag_tile.gd",
	"res://src/ui/components/country_picker_panel.gd",
	"res://src/ui/components/flag_strip.gd",
	"res://src/ui/components/avatar_glyph.gd",
	"res://src/ui/components/avatar_gallery.gd",
	"res://src/ui/profile/avatar_art.gd",
	"res://src/ui/components/tutorial_panel.gd",
	"res://src/ui/tutorial/tutorial_steps.gd",
	"res://src/ui/components/integrity_dialog.gd"]


func _registry() -> CountryRegistry:
	return WorldAtlas.load_default().registry


func _host(size: Vector2 = Vector2(900, 600)) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = size
	holder.size = size
	holder.theme = ThemeManager.current_theme()
	host.add_child(holder)
	return holder


func test_the_search_list_shows_a_flag_for_a_mapped_record() -> void:
	var holder := _host()
	var search := CountrySearch.new()
	holder.add_child(search)
	search.setup(_registry())
	search.set_query("bangladesh")
	await tree.process_frame
	await tree.process_frame
	var button: Button = search.result_button(0)
	check_not_null(button, "the search found Bangladesh")
	if button == null:
		holder.queue_free()
		return
	var tile: FlagTile = button.find_child("Flag", true, false) as FlagTile
	check_not_null(tile, "the row carries a flag tile")
	if tile != null:
		check_true(tile.has_texture(), "and the flag is rasterised and shown")
		check_eq(tile.size, Vector2(FlagTile.WIDTH, FlagTile.HEIGHT),
				"drawn at the flag tile's documented size")
		check_false(tile.badge_visible(), "with no badge on top of it")
	holder.queue_free()


func test_a_record_without_a_flag_shows_its_own_code() -> void:
	var holder := _host()
	for country_id: String in FLAGLESS:
		var tile := FlagTile.new()
		holder.add_child(tile)
		tile.show_country(country_id)
		await tree.process_frame
		check_false(tile.has_texture(), "%s draws no flag" % country_id)
		check_true(tile.badge_visible(), "%s keeps its badge visible" % country_id)
		check_eq(tile.badge_text(), country_id, "%s shows its own code" % country_id)
	holder.queue_free()
	check_eq(FlagImage.file_for("SOL"), "", "and no file is claimed for it")


func test_the_badge_is_visible_until_the_flag_arrives() -> void:
	var holder := _host()
	var tile := FlagTile.new()
	holder.add_child(tile)
	tile.show_country("BGD", "BD")
	check_true(tile.badge_visible(), "the badge is what shows first")
	check_false(tile.has_texture(), "so nothing waits for a rasterised flag")
	check_eq(tile.badge_text(), "BD", "and the badge says the record's code")
	await tree.process_frame
	await tree.process_frame
	check_true(tile.has_texture(), "the flag arrives a frame later")
	check_false(tile.badge_visible(), "and replaces the badge")
	holder.queue_free()


func test_the_dossier_header_carries_the_flag() -> void:
	var holder := _host()
	var panel := CountryInfoPanel.new()
	holder.add_child(panel)
	var record := _registry().get_country("BGD")
	check_not_null(record, "Bangladesh is in the registry")
	if record == null:
		holder.queue_free()
		return
	panel.show_country(record)
	await tree.process_frame
	await tree.process_frame
	var tile: FlagTile = panel.find_child("Flag", true, false) as FlagTile
	check_not_null(tile, "the dossier header has a flag tile")
	if tile != null:
		check_true(tile.has_texture(), "and it draws the flag")
	holder.queue_free()


func test_scrolling_a_result_list_does_not_accumulate_tiles() -> void:
	var holder := _host()
	var search := CountrySearch.new()
	holder.add_child(search)
	search.setup(_registry())
	var queries := ["bang", "ind", "united", "ger", "fra", "jap", "bra", "ken", "nep", "pak"]
	var worst := ""
	for query: String in queries:
		search.set_query(query)
		await tree.process_frame
		var tiles := _count_tiles(search)
		var results := search.visible_result_ids().size()
		if tiles != results and worst.is_empty():
			worst = "query '%s' left %d tiles for %d results" % [query, tiles, results]
	check_eq(worst, "", "each search leaves exactly one tile per result")
	check_eq(_count_tiles(search), search.visible_result_ids().size(),
			"and the last search is no different")
	holder.queue_free()


func test_the_string_table_answers_every_key() -> void:
	var broken: Array = []
	for key: String in Strings.keys():
		var text := Strings.t(key, _sample_args(key))
		if text.is_empty() or text.begins_with("<") or text.contains("<%s>"):
			broken.append(key)
	check_eq(broken.size(), 0, "every key has a real sentence: %s" % str(broken))
	check_eq(Strings.t("no.such.key"), "<no.such.key>",
			"a missing key is visible, not silently empty")
	check_eq(Strings.t("search.no_match", ["Ruritania"]),
			"No nation matches \"Ruritania\". Try a different spelling or an ISO code.",
			"and placeholders are substituted")
	check_true(Strings.has("profile.wallet_gems"), "the table knows its own keys")


func test_new_screens_hold_no_hard_coded_sentences() -> void:
	# The guard the milestone asks for: any sentence a player reads in a *new* screen must
	# come from the string table. Comments and code identifiers are not sentences, so the
	# test looks for quoted strings of several words that start with a capital letter.
	var files := _new_screen_files()
	var seen: Array = []
	for path: String in files:
		var text := FileAccess.get_file_as_string(path)
		for line: String in text.split("\n"):
			var trimmed := line.strip_edges()
			if trimmed.begins_with("#") or trimmed.contains("Strings.t("):
				continue
			# push_warning/push_error text goes to the log, which a player never reads.
			if line.contains("push_warning") or line.contains("push_error"):
				continue
			var found := _long_sentence(line)
			if not found.is_empty():
				seen.append("%s: %s" % [path.get_file(), found])
	check_eq(seen.size(), 0, "no new screen holds a literal sentence: %s" % str(seen))
	check_gt(float(files.size()), 0.0, "the guard actually looked at the new screens")


func _new_screen_files() -> PackedStringArray:
	var out := PackedStringArray()
	for path: String in NEW_FILES:
		if FileAccess.file_exists(path):
			out.append(path)
	for folder in ["res://src/ui/screens/first_run", "res://src/ui/screens/profile",
			"res://src/ui/screens/worlds", "res://src/ui/screens/backup",
			"res://src/ui/screens/diagnostics", "res://src/ui/screens/help",
			"res://src/ui/screens/roadmap", "res://src/ui/screens"]:
		var directory := DirAccess.open(folder)
		if directory == null:
			continue
		for filename: String in directory.get_files():
			if not filename.ends_with(".gd"):
				continue
			if folder.ends_with("screens") and not (
					filename.begins_with("profile_screen") or filename.begins_with("picker")
					or filename.begins_with("backup") or filename.begins_with("worlds")
					or filename.begins_with("integrity")):
				continue
			out.append(folder.path_join(filename))
	return out


func _long_sentence(line: String) -> String:
	var start := line.find("\"")
	while start >= 0:
		var closer := line.find("\"", start + 1)
		if closer <= start:
			break
		var text := line.substr(start + 1, closer - start - 1)
		var words := text.split(" ")
		var first := text.substr(0, 1)
		if words.size() >= 4 and text.length() > 20 and first == first.to_upper() \
				and first != first.to_lower():
			return text
		start = line.find("\"", closer + 1)
	return ""


func _count_tiles(node: Node) -> int:
	var count := 0
	for child: Node in node.get_children():
		if child is FlagTile:
			count += 1
		count += _count_tiles(child)
	return count


func _sample_args(key: String) -> Array:
	if key.ends_with("no_match") or key.ends_with("tooltip_missing") or key.ends_with("selected"):
		return ["Bangladesh"]
	if key.contains("%d") and key.contains("%s"):
		return ["Loading the atlas", 1, 3]
	if key.contains("%d"):
		var count := key.count("%d")
		var values: Array = []
		for index in count:
			values.append(1)
		return values
	if key.contains("%s"):
		return ["Bangladesh"]
	return []
