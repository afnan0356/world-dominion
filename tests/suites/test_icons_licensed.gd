extends TestCase
## The licensed icon set (Milestone 11, Task 1).
##
## Three things are being proved here, and they are separate on purpose:
##
## 1. **The set is what it claims to be.** `data/ui/icon_sources.json` is the hand-written
##    record of what was chosen; `data/ui/icon_crosswalk.json` and the SVGs under
##    `assets/icons/game_icons/` are generated from it. Every committed file must match the
##    hash the build recorded, and the manifest, crosswalk and files must agree on what exists.
## 2. **The attribution is real.** Every author appears in `THIRD_PARTY_LICENSES.md`, in
##    `data/credits.json`, and in the About screen a player can actually open — in the wording
##    the icon source's own licence file asks for.
## 3. **The runtime path works and does not leak.** Icons rasterise at the size asked for, take
##    the theme's colour in both themes, fall back to the project's drawn marks when a file is
##    unavailable, and the texture cache stays bounded under repeated asks.
##
## The freshness check against the *pinned commit* is `tools/build_icons.py --check`, which
## re-downloads the commit in CI: a test cannot reach the network, and a test that silently
## skipped would be worse than none.

const MANIFEST_PATH := "res://data/ui/icon_sources.json"
const CROSSWALK_PATH := "res://data/ui/icon_crosswalk.json"
const CREDITS_PATH := "res://data/credits.json"
const LICENCES_PATH := "res://THIRD_PARTY_LICENSES.md"
const ABOUT_SCENE := "res://src/ui/screens/about_screen.tscn"
const ICON_BUDGET_TOTAL := 400_000
const ICON_BUDGET_ONE := 12_000


func _manifest() -> Dictionary:
	var text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func _crosswalk() -> Dictionary:
	var text := FileAccess.get_file_as_string(CROSSWALK_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var icons: Variant = (parsed as Dictionary).get("icons")
		if icons is Dictionary:
			return icons
	return {}


func _icons() -> Dictionary:
	var icons := _crosswalk()
	check_gt(float(icons.size()), 0.0, "the icon crosswalk exists and lists icons")
	return icons


# --- The set -----------------------------------------------------------------

func test_manifest_and_crosswalk_agree() -> void:
	var manifest := _manifest()
	var crosswalk := _crosswalk()
	var entries: Variant = manifest.get("icons")
	check_true(entries is Array, "the manifest lists its icons")
	if not entries is Array:
		return
	var listed: Array = []
	for item: Variant in entries:
		if item is Dictionary:
			listed.append(str((item as Dictionary).get("meaning", "")))
	check_gte(float(listed.size()), 50.0, "the set is around sixty icons, not a token handful")
	check_eq(crosswalk.size(), listed.size(), "the crosswalk has exactly the manifest's icons")
	var missing: Array = []
	var extra: Array = []
	for meaning: Variant in listed:
		if not crosswalk.has(meaning):
			missing.append(meaning)
	for meaning: Variant in crosswalk.keys():
		if not listed.has(meaning):
			extra.append(meaning)
	check_eq(missing.size(), 0, "every manifest meaning is in the crosswalk: %s" % str(missing))
	check_eq(extra.size(), 0, "the crosswalk has nothing the manifest did not choose: %s"
			% str(extra))
	check_eq(str(manifest.get("pinned_commit", "")).length(), 40,
			"the manifest pins a full commit hash")
	var commit := _crosswalk_commit()
	check_eq(commit, str(manifest.get("pinned_commit", "")),
			"the crosswalk records the same pinned commit as the manifest")


func _crosswalk_commit() -> String:
	var text := FileAccess.get_file_as_string(CROSSWALK_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return str((parsed as Dictionary).get("pinned_commit", ""))
	return ""


func test_every_icon_file_is_committed_and_unmodified() -> void:
	var icons := _icons()
	var problems: Array = []
	for meaning: Variant in icons.keys():
		var entry: Dictionary = (icons[meaning] as Dictionary).duplicate()
		var path := str(entry.get("file", ""))
		if not path.begins_with("res://"):
			problems.append("%s has no resource path" % meaning)
			continue
		if not FileAccess.file_exists(path):
			problems.append("%s: %s is missing" % [meaning, path])
			continue
		var bytes := FileAccess.get_file_as_bytes(path)
		check_eq(bytes.size(), int(entry.get("bytes", -1)),
				"%s: the committed size matches the crosswalk" % meaning)
		var hash := FileAccess.get_sha256(path)
		if hash != str(entry.get("sha256", "")):
			problems.append("%s: %s does not match its recorded hash" % [meaning, path])
		check_lte(float(bytes.size()), float(ICON_BUDGET_ONE),
				"%s fits the per-icon size budget" % meaning)
	check_eq(problems.size(), 0, "every icon file matches the build record: %s" % str(problems))


func test_every_icon_names_its_author_and_licence() -> void:
	var icons := _icons()
	var bad: Array = []
	for meaning: Variant in icons.keys():
		var entry: Dictionary = icons[meaning] as Dictionary
		var author := str(entry.get("author", ""))
		var licence := str(entry.get("licence", ""))
		var source := str(entry.get("source", ""))
		if author.is_empty():
			bad.append("%s has no author" % meaning)
		if not (licence in ["CC BY 3.0", "CC0"]):
			bad.append("%s has licence '%s'" % [meaning, licence])
		if source.count("/") != 1 or not source.ends_with(".svg"):
			bad.append("%s has source '%s', not author/name.svg" % [meaning, source])
		if str(entry.get("author_url", "")) == "" and not (author in ["Skoll", "Zeromancer"]):
			bad.append("%s: %s has no URL, though the licence file gives one" % [meaning, author])
	check_eq(bad.size(), 0, "every icon names its author and licence: %s" % str(bad))
	var cc0 := 0
	for meaning: Variant in icons.keys():
		if str((icons[meaning] as Dictionary).get("licence", "")) == "CC0":
			cc0 += 1
	check_gte(float(cc0), 1.0, "the CC0 exception in the licence file is applied, not assumed")


func test_icon_set_fits_its_size_budget() -> void:
	var icons := _icons()
	# Two meanings may share one file (the category bar asks by category id), so count each
	# file once — the budget is about what ships, not about how many names point at it.
	var sizes := {}
	for meaning: Variant in icons.keys():
		var path := str((icons[meaning] as Dictionary).get("file", ""))
		sizes[path] = FileAccess.get_file_as_bytes(path).size()
	var total := 0
	for path: Variant in sizes.keys():
		total += int(sizes[path])
	check_lte(float(total), float(ICON_BUDGET_TOTAL), "the whole set fits the size budget")
	check_gt(float(total), 1000.0, "and the files are really there")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CROSSWALK_PATH))
	var recorded := int((parsed as Dictionary).get("total_bytes", -1))
	check_eq(recorded, total, "the crosswalk's total matches the files on disk")


func test_fallback_shapes_are_drawable() -> void:
	var icons := _icons()
	var known := ShellIcon.shapes()
	var bad: Array = []
	for meaning: Variant in icons.keys():
		var shape := str((icons[meaning] as Dictionary).get("shape", ""))
		if not known.has(shape):
			bad.append("%s → '%s'" % [meaning, shape])
	check_eq(bad.size(), 0, "every icon has a drawn fallback the code can draw: %s" % str(bad))
	for meaning: Variant in icons.keys():
		check_true(FileAccess.file_exists(str((icons[meaning] as Dictionary).get("file", ""))),
				"%s has both a file and a fallback" % meaning)


func test_no_icon_depicts_a_flag_belief_or_person() -> void:
	# The rule from the brief: no real-world flags, no religious symbols, no real people. The
	# check is on the chosen source paths and meanings, because that is where a wrong choice
	# would enter the repository.
	var banned := ["flag", "christian", "islam", "muslim", "jew", "hindu", "buddha", "church",
			"mosque", "temple", "jesus", "mary", "prophet", "portrait"]
	var icons := _icons()
	var offenders: Array = []
	for meaning: Variant in icons.keys():
		var lower := str(meaning).to_lower()
		var path := str((icons[meaning] as Dictionary).get("source", "")).to_lower()
		for word: String in banned:
			if lower.contains(word) or path.contains(word):
				offenders.append("%s (%s)" % [meaning, path])
	check_eq(offenders.size(), 0, "no icon means a nation, a faith or a person: %s"
			% str(offenders))


# --- Attribution --------------------------------------------------------------

func test_third_party_licences_credits_every_author() -> void:
	var text := FileAccess.get_file_as_string(LICENCES_PATH)
	check_true(text.contains("game-icons"), "the licence file records the icon source")
	check_true(text.contains(str(_crosswalk_commit())), "it records the pinned commit")
	check_true(text.contains("Creative Commons 3.0 BY"),
			"the source's own licence sentence is reproduced")
	check_true(text.contains("Icons made by {author}"),
			"the required credit wording is recorded, not paraphrased away")
	var icons := _icons()
	var authors := {}
	for meaning: Variant in icons.keys():
		authors[str((icons[meaning] as Dictionary).get("author", ""))] = true
	for author: Variant in authors.keys():
		check_true(text.contains(str(author)),
				"%s is credited in THIRD_PARTY_LICENSES.md" % author)


func test_credits_data_credits_every_author() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CREDITS_PATH))
	check_true(parsed is Dictionary, "the credits file parses")
	if not parsed is Dictionary:
		return
	var record: Variant = (parsed as Dictionary).get("icons")
	check_true(record is Dictionary, "the credits file has an icons block")
	if not record is Dictionary:
		return
	var block := record as Dictionary
	var icons := _icons()
	var authors := {}
	for meaning: Variant in icons.keys():
		authors[str((icons[meaning] as Dictionary).get("author", ""))] = true
	var listed: Array = []
	for entry: Variant in (block.get("authors", []) as Array):
		if entry is Dictionary:
			listed.append(str((entry as Dictionary).get("name", "")))
	check_eq(listed.size(), authors.size(), "the credits list exactly the set's authors")
	for author: Variant in authors.keys():
		check_true(listed.has(author), "%s is credited in data/credits.json" % author)
	check_true(str(block.get("attribution_format", "")).contains("Icons made by {author}"),
			"the credits carry the source's own credit wording")


func test_about_screen_shows_every_author() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Control = load(ABOUT_SCENE).instantiate()
	holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await tree.process_frame
	await tree.process_frame
	var text := _all_text(screen)
	check_true(text.contains("Icons made by"),
			"the About screen carries the icon credit sentence")
	var icons := _icons()
	var authors := {}
	for meaning: Variant in icons.keys():
		authors[str((icons[meaning] as Dictionary).get("author", ""))] = true
	for author: Variant in authors.keys():
		check_true(text.contains(str(author)),
				"the About screen names %s" % author)
	check_true(text.contains("CC0"), "and marks the CC0 author rather than blending them in")
	viewport.queue_free()


func _all_text(node: Node) -> String:
	var out := ""
	for child: Node in node.get_children():
		if child is Label:
			out += (child as Label).text + "\n"
		elif child is Button:
			out += (child as Button).text + "\n"
		out += _all_text(child)
	return out


# --- Runtime -------------------------------------------------------------------

func test_texture_is_rasterised_at_requested_size() -> void:
	IconAtlas.clear_cache()
	var texture := IconAtlas.texture_for("messages", 24)
	check_not_null(texture, "a known meaning loads its file")
	if texture == null:
		return
	check_lte(absf(float(texture.get_width()) - 24.0), 1.0,
			"the texture is the size asked for, not a 512 px monster")
	check_eq(texture.get_width(), texture.get_height(),
			"and square, as the source is")
	var big := IconAtlas.texture_for("messages", 48)
	check_not_null(big, "a second size loads too")
	if big != null:
		check_lte(absf(float(big.get_width()) - 48.0), 1.0,
				"the second size is its own texture, not the first one stretched")


func test_tint_follows_the_theme_in_both_themes() -> void:
	var midnight := ThemeManager.current_theme()
	var parchment := ThemeFactory.build(Palette.colors(Palette.PARCHMENT))
	var night_text := midnight.get_color("font_color", "Label")
	var day_text := parchment.get_color("font_color", "Label")
	check_true(night_text != day_text, "the two themes disagree about text colour, as they must")
	var dark_host := Control.new()
	dark_host.theme = midnight
	host.add_child(dark_host)
	var light_host := Control.new()
	light_host.theme = parchment
	host.add_child(light_host)
	var dark_icon := IconView.new()
	dark_host.add_child(dark_icon)
	dark_icon.setup("messages", 24, IconAtlas.tint_for(dark_icon))
	var light_icon := IconView.new()
	light_host.add_child(light_icon)
	light_icon.setup("messages", 24, IconAtlas.tint_for(light_icon))
	check_eq(dark_icon.modulate, night_text, "the icon takes the dark theme's text colour")
	check_eq(light_icon.modulate, day_text, "the icon takes the light theme's text colour")
	check_false(dark_icon.using_fallback(), "a real icon file was used in the dark theme")
	check_false(light_icon.using_fallback(), "and in the light theme")
	dark_host.queue_free()
	light_host.queue_free()


func test_missing_icon_falls_back_to_the_drawn_shape() -> void:
	IconAtlas.clear_cache()
	check_true(IconAtlas.texture_for("not_a_meaning", 24) == null,
		"an unknown meaning has no texture rather than a wrong one")
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	host.add_child(holder)
	var icon := IconView.new()
	holder.add_child(icon)
	icon.setup("not_a_meaning", 24, Color.WHITE)
	check_true(icon.using_fallback(), "an unknown meaning falls back to a drawn mark")
	check_not_null(icon.fallback_node(), "and the drawn mark exists as a node")
	if icon.fallback_node() != null:
		check_eq(icon.fallback_node().shape, "question",
				"an unknown meaning falls back to the neutral drawn mark, not to nothing")
	var known := IconView.new()
	holder.add_child(known)
	known.setup("military", 20, Color.WHITE)
	check_false(known.using_fallback(), "a known meaning prefers the licensed file")
	holder.queue_free()


func test_cache_is_bounded_and_reuses_textures() -> void:
	IconAtlas.clear_cache()
	# The working set is deliberately smaller than the cache limit: a working set larger than
	# the limit would thrash (each insert evicting the next thing asked for), which is a fact
	# about caches, not a bug this test should pin. 10 meanings x 6 sizes = 60 of 64.
	var meanings: Array = ["messages", "news", "country", "economy", "settings", "search",
			"filter", "help", "warning", "backup"]
	var sizes: Array = [16, 20, 24, 32, 48, 64]
	var first_round := 0
	for round_index: int in range(3):
		for meaning: Variant in meanings:
			for size: Variant in sizes:
				var texture := IconAtlas.texture_for(str(meaning), int(size))
				if texture == null:
					continue
				if round_index == 0:
					first_round += 1
	check_eq(first_round, meanings.size() * sizes.size(),
			"every asked-for meaning and size loaded, so the loops above were real work")
	check_eq(IconAtlas.textures_built(), first_round,
			"the second and third rounds were served from the cache, not rebuilt")
	check_lte(float(IconAtlas.cache_size()), float(IconAtlas.CACHE_LIMIT),
			"the cache stays inside its limit (%d entries)" % IconAtlas.cache_size())
	IconAtlas.clear_cache()
	check_eq(IconAtlas.cache_size(), 0, "clearing the cache empties it")
