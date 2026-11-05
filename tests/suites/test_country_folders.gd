extends TestCase
## The per-country folder tree, checked from inside the game.
##
## The folders are the human-readable source of truth; the pack
## (`countries.json`, `geometry.json`, `manifest.json`) is generated from them and
## is what the game actually loads. These tests prove the two cannot drift: every
## record has a folder, every folder has the required files, the folder names are
## safe on every target platform, the sources are recorded, and the pack carries
## the hashes of the bytes it was built from.
##
## The deeper structural audit (and the deliberately broken fixtures that prove it
## catches problems) lives in `tools/validate_country_folders.py`, which CI runs
## before the engine is even installed.

const FOLDERS := "res://data/world/countries"
const REQUIRED := ["identity.json", "geometry.json", "sources.json", "README.md"]
const ID_PATTERN := "^[A-Z0-9][A-Z0-9-]{0,31}$"
## Degrees. The folders round their bounding box, the pack recomputes it from
## quantised coordinates; the same tolerance the standalone validator uses.
const BBOX_TOLERANCE := 0.02
const RESERVED := ["CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5",
		"COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6",
		"LPT7", "LPT8", "LPT9"]

var _atlas: WorldAtlas


func _load() -> void:
	if _atlas == null:
		_atlas = WorldAtlas.load_default()


func _folder_names() -> PackedStringArray:
	var names := PackedStringArray()
	var dir := DirAccess.open(FOLDERS)
	if dir == null:
		return names
	for name: String in dir.get_directories():
		names.append(name)
	names.sort()
	return names


func _read_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


func test_every_record_has_one_folder_and_no_folder_is_orphaned() -> void:
	_load()
	var registry_ids: Array = []
	for record: CountryRecord in _atlas.registry.all():
		registry_ids.append(record.id)
	registry_ids.sort()
	var folders := _folder_names()
	check_eq(folders.size(), registry_ids.size(),
			"the folder count and the record count agree (%d vs %d)"
			% [folders.size(), registry_ids.size()])
	var missing: Array = []
	var orphaned: Array = []
	for country_id: String in registry_ids:
		if country_id not in folders:
			missing.append(country_id)
	for name: String in folders:
		if not _atlas.registry.has_country(name):
			orphaned.append(name)
	check_eq(missing.size(), 0, "every record has a folder (missing: %s)" % str(missing))
	check_eq(orphaned.size(), 0, "no folder lacks a record (orphans: %s)" % str(orphaned))


func test_folder_names_are_portable_on_every_platform() -> void:
	var expression := RegEx.new()
	check_eq(expression.compile(ID_PATTERN), OK, "the id pattern compiles")
	var bad: Array = []
	var lowered := {}
	var collisions: Array = []
	for name: String in _folder_names():
		if expression.search(name) == null:
			bad.append(name)
		if name in RESERVED:
			bad.append(name + " (reserved on Windows)")
		var folded := name.to_lower()
		if lowered.has(folded):
			collisions.append("%s/%s" % [lowered[folded], name])
		lowered[folded] = name
	check_eq(bad.size(), 0, "every folder name is ASCII uppercase and reserved-name safe")
	check_eq(collisions.size(), 0,
			"no two folders differ only by case (%s)" % str(collisions))


func test_every_folder_holds_its_required_files() -> void:
	var problems: Array = []
	var readmes_matching := 0
	for name: String in _folder_names():
		var dir := DirAccess.open("%s/%s" % [FOLDERS, name])
		if dir == null:
			problems.append("%s: cannot open" % name)
			continue
		for required: String in REQUIRED:
			if not dir.file_exists(required):
				problems.append("%s: missing %s" % [name, required])
		var identity := _read_json("%s/%s/identity.json" % [FOLDERS, name])
		if str(identity.get("id", "")) != name:
			problems.append("%s: identity.json id is %s" % [name, identity.get("id")])
		var readme := FileAccess.get_file_as_string("%s/%s/README.md" % [FOLDERS, name])
		if readme.begins_with("# ") and readme.contains("`%s`" % name):
			readmes_matching += 1
		else:
			problems.append("%s: README does not name the record" % name)
	check_eq(problems.size(), 0,
			"required files, ids and READMEs are all in place (%s)" % str(problems.slice(0, 5)))
	check_eq(readmes_matching, _folder_names().size(),
			"every folder has a README naming its record")


func test_every_folder_records_its_sources() -> void:
	_load()
	var pinned := str((_atlas.manifest.get("source") as Dictionary).get("commit", ""))
	var problems: Array = []
	for name: String in _folder_names():
		var sources := _read_json("%s/%s/sources.json" % [FOLDERS, name])
		if sources.is_empty():
			problems.append("%s: sources.json is unreadable" % name)
			continue
		for key: String in ["dataset", "repository", "commit", "version", "licence",
				"attribution", "retrieved", "url"]:
			if str(sources.get(key, "")).strip_edges().is_empty():
				problems.append("%s: %s is empty" % [name, key])
		if str(sources.get("commit", "")) != pinned:
			problems.append("%s: commit %s is not the pinned %s"
					% [name, sources.get("commit"), pinned])
		if not str(sources.get("licence", "")).contains("Public Domain"):
			problems.append("%s: licence is not public domain" % name)
	check_eq(problems.size(), 0,
			"every folder records dataset, commit, licence and attribution (%s)"
			% str(problems.slice(0, 5)))


func test_capital_files_exist_exactly_where_a_capital_is_sourced() -> void:
	_load()
	var problems: Array = []
	var with_file := 0
	for record: CountryRecord in _atlas.registry.all():
		var path := "%s/%s/capital.json" % [FOLDERS, record.id]
		var exists := FileAccess.file_exists(path)
		var has_capital := not record.capital.is_empty()
		if exists:
			with_file += 1
			var capital := _read_json(path)
			if str(capital.get("name", "")) != record.capital:
				problems.append("%s: capital name disagrees with the record" % record.id)
			var point: Variant = capital.get("point")
			if not point is Array or (point as Array).size() != 2:
				problems.append("%s: capital point is not a pair" % record.id)
		if exists != has_capital:
			problems.append("%s: capital file %s but record %s a capital"
					% [record.id, "present" if exists else "absent",
					"has" if has_capital else "has no"])
	check_eq(problems.size(), 0,
			"capital.json is present exactly when the source has a capital (%s)"
			% str(problems.slice(0, 5)))
	check_gte(float(with_file), 150.0,
			"at least 150 records have a sourced capital (%d)" % with_file)


func test_folder_geometry_matches_the_pack() -> void:
	_load()
	var geometry_ids: PackedStringArray = _atlas.geometry.country_ids()
	var problems: Array = []
	for country_id: String in geometry_ids:
		var doc := _read_json("%s/%s/geometry.json" % [FOLDERS, country_id])
		if doc.is_empty():
			problems.append("%s: geometry.json is unreadable" % country_id)
			continue
		var pack_polygons: int = _atlas.geometry.polygon_count_of(country_id)
		var folder_polygons: int = (doc.get("polygons") as Array).size()
		if pack_polygons != folder_polygons:
			problems.append("%s: %d polygons in the folders, %d in the pack"
					% [country_id, folder_polygons, pack_polygons])
		var pack_bbox: Rect2 = _atlas.geometry.bbox_of(country_id)
		var box: Array = doc.get("bbox", [])
		# The folder stores the bounding box rounded to three decimals; the pack
		# recomputes it from quantised ring coordinates. They must agree within the
		# same 0.02° drift tolerance the standalone validator uses, not exactly.
		if box.size() == 4:
			var edges: Array = [float(box[0]), float(box[1]), float(box[2]), float(box[3])]
			var pack_edges: Array = [pack_bbox.position.x, pack_bbox.position.y,
					pack_bbox.end.x, pack_bbox.end.y]
			for index in 4:
				if absf(edges[index] - pack_edges[index]) > BBOX_TOLERANCE:
					problems.append("%s: bbox edge %d disagrees with the pack (%s vs %s)"
							% [country_id, index, str(edges[index]), str(pack_edges[index])])
					break
	check_eq(problems.size(), 0,
			"folder geometry and pack geometry agree (%s)" % str(problems.slice(0, 5)))


func test_the_pack_records_the_hashes_of_the_bytes_it_was_built_with() -> void:
	_load()
	var pack: Dictionary = _atlas.manifest.get("pack") as Dictionary
	check_false(pack.is_empty(), "the manifest records a pack block")
	check_eq(str(FileAccess.get_sha256("res://data/world/countries.json")),
			str(pack.get("countries_sha256", "")),
			"countries.json matches the hash recorded when it was built from the folders")
	check_eq(str(FileAccess.get_sha256("res://data/world/geometry.json")),
			str(pack.get("geometry_sha256", "")),
			"geometry.json matches the hash recorded when it was built from the folders")
	check_eq(int(pack.get("records", 0)), int((_atlas.manifest.get("folders") as Dictionary)
			.get("count", 0)),
			"the pack and the folder block agree on the record count")
