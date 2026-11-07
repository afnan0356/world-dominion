class_name IconAtlas
extends RefCounted
## The game-icons.net set, rasterised when it is first asked for.
##
## The committed files are the source's own SVGs with exactly one change: the full-bleed
## background rectangle is gone, so a mark can be tinted by the theme instead of drawn as a
## white shape on a black square. Everything else — path data, viewBox — is byte-for-byte what
## the pinned commit holds, which is what `tools/build_icons.py --check` re-proves in CI.
##
## Why rasterise at runtime rather than at build time: the same SVG is asked for at 16 px in a
## chip and at 32 px in the top bar, on phones at 1× to 3× density. Godot's own SVG reader
## (`Image.load_svg_from_string`) is used, so there is no new dependency, and a small cache
## keeps repeated asks free without growing without limit.
##
## A missing or unreadable file is not an error the player sees: `texture_for()` returns null,
## and `IconView` falls back to the code-drawn mark this project already had. That fallback is
## why a broken asset cannot leave a button blank.

const CROSSWALK_PATH := "res://data/ui/icon_crosswalk.json"
## The viewBox every game-icons SVG uses. The scale for a requested pixel size follows from it.
const SOURCE_SIZE := 512.0
## How many rasterised sizes are kept. A screen asks for a handful of sizes; more than this and
## something is resizing every frame, which the cache is not there to hide.
const CACHE_LIMIT := 64

static var _crosswalk: Dictionary = {}
static var _loaded := false
static var _cache: Dictionary = {}
## How many textures have been built this run, for the leak test.
static var _built := 0


## The committed crosswalk. Empty when the file is missing, which makes every lookup fall back
## to the drawn marks rather than failing.
static func crosswalk() -> Dictionary:
	if _loaded:
		return _crosswalk
	_loaded = true
	var text := FileAccess.get_file_as_string(CROSSWALK_PATH)
	if text.is_empty():
		return _crosswalk
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		var icons: Variant = (parsed as Dictionary).get("icons")
		if icons is Dictionary:
			_crosswalk = icons
	return _crosswalk


static func has_icon(meaning: String) -> bool:
	return crosswalk().has(meaning)


## The record for one meaning: source path, author, licence, file, hash.
static func entry_for(meaning: String) -> Dictionary:
	var entry: Variant = crosswalk().get(meaning)
	return entry if entry is Dictionary else {}


## Every author whose work is in the set, with the URL the licence file gives, sorted by name.
static func authors() -> Array:
	var out: Array = []
	var seen := {}
	for meaning: String in crosswalk().keys():
		var entry := entry_for(meaning)
		var name := str(entry.get("author", ""))
		if name.is_empty() or seen.has(name):
			continue
		seen[name] = true
		out.append({"name": name, "url": str(entry.get("author_url", "")),
				"licence": str(entry.get("licence", "")), "count": 0})
	for entry: Dictionary in out:
		for meaning: String in crosswalk().keys():
			if str(entry_for(meaning).get("author", "")) == str(entry["name"]):
				entry["count"] = int(entry["count"]) + 1
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["name"]) < str(b["name"]))
	return out


## A rasterised texture for `meaning` at `pixels` square, or null when the icon is missing or
## cannot be read. The result is cached; tinting happens on the node, not here, so one texture
## serves every colour.
static func texture_for(meaning: String, pixels: int) -> Texture2D:
	var entry := entry_for(meaning)
	if entry.is_empty():
		return null
	var size := maxi(pixels, 8)
	var key := "%s@%d" % [meaning, size]
	if _cache.has(key):
		return _cache[key] as Texture2D
	var path := str(entry.get("file", ""))
	if path.is_empty():
		return null
	var svg := FileAccess.get_file_as_string(path)
	if svg.is_empty():
		return null
	var image := Image.new()
	var scale := float(size) / SOURCE_SIZE
	if image.load_svg_from_string(svg, scale) != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	_built += 1
	_store(key, texture)
	return texture


static func _store(key: String, texture: Texture2D) -> void:
	if _cache.size() >= CACHE_LIMIT:
		# Oldest first: the cache is insertion-ordered, so the first key is the stalest.
		var oldest: Variant = _cache.keys()[0]
		_cache.erase(oldest)
	_cache[key] = texture


static func cache_size() -> int:
	return _cache.size()


static func textures_built() -> int:
	return _built


static func clear_cache() -> void:
	_cache.clear()
	_built = 0


## The colour a mark should be drawn in: the theme's own text colour, so an icon is exactly as
## legible as the word beside it in both themes.
static func tint_for(node: Control) -> Color:
	if node == null:
		return Color.WHITE
	return node.get_theme_color("font_color", "Label")
