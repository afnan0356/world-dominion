class_name FlagImage
extends RefCounted
## Country flags, loaded from the committed crosswalk and rasterised at run time.
##
## The flags are the MIT-licensed lipis/flag-icons SVGs (see THIRD_PARTY_LICENSES.md),
## pinned to v7.6.0. Only the files `data/world/flag_crosswalk.json` maps are committed, and
## the mapping is one rule: a record gets the flag of **its own** ISO alpha-2 code or none.
## Nothing is inferred, no parent country's flag is borrowed for a territory, and a record
## with no flag is shown a neutral badge with its code — never a guessed flag.
##
## Rasterising happens on first use at the size the interface asks for, and the result is
## kept in a small cache; nothing is rasterised at build time, so the repository holds only
## the source's own SVGs.
##
## Godot's own SVG reader is used (`Image.load_svg_from_string`), so no extra dependency is
## involved.

## The size a flag is drawn at. Big enough for a phone at 1× and crisp when scaled down.
const WIDTH := 48
const HEIGHT := 36
## How many rasterised flags are kept. A list of countries scrolls through more than this;
## the oldest entry is dropped rather than growing without limit.
const CACHE_LIMIT := 64
const CROSSWALK_PATH := "res://data/world/flag_crosswalk.json"
const ASSET_ROOT := "res://assets/flags/"

## Parsed crosswalk, loaded once per run.
static var _crosswalk: Dictionary = {}
static var _crosswalk_loaded := false
## File name → Texture2D, in insertion order so the oldest can be dropped.
static var _cache: Dictionary = {}


## The crosswalk, as committed. Empty when the file is missing or unreadable — the caller
## then shows badges, which is the honest result rather than an error dialog.
static func crosswalk() -> Dictionary:
	if _crosswalk_loaded:
		return _crosswalk
	_crosswalk_loaded = true
	var text := FileAccess.get_file_as_string(CROSSWALK_PATH)
	if text.is_empty():
		push_warning("FlagImage: %s is missing; every country will show a code badge."
				% CROSSWALK_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_crosswalk = parsed
	return _crosswalk


## The SVG file a record maps to, or "" when it has none. Never a guess.
static func file_for(country_id: String) -> String:
	var flags: Variant = crosswalk().get("flags", {})
	if not (flags is Dictionary) or not (flags as Dictionary).has(country_id):
		return ""
	return str(((flags as Dictionary)[country_id] as Dictionary).get("file", ""))


static func has_flag(country_id: String) -> bool:
	return not file_for(country_id).is_empty()


## The text a flagless record shows instead of a flag: its own code, so the badge says
## something true about the record rather than nothing.
static func badge_text(country_id: String, alpha_2: String = "") -> String:
	var code := alpha_2.strip_edges().to_upper()
	if code.is_empty():
		code = country_id.strip_edges().to_upper()
	return code


## The rasterised flag, or null when the record has none or the file cannot be read.
static func texture_for(country_id: String) -> Texture2D:
	var file := file_for(country_id)
	if file.is_empty():
		return null
	if _cache.has(file):
		# Refresh the insertion order so the cache behaves least-recently-used.
		var kept: Texture2D = _cache[file]
		_cache.erase(file)
		_cache[file] = kept
		return kept
	var text := FileAccess.get_file_as_string(ASSET_ROOT + file)
	if text.is_empty():
		push_warning("FlagImage: %s%s is unreadable." % [ASSET_ROOT, file])
		return null
	var image := Image.new()
	var error := image.load_svg_from_string(text, float(WIDTH))
	if error != OK or image.is_empty():
		push_warning("FlagImage: %s%s could not be rasterised (%d)."
				% [ASSET_ROOT, file, error])
		return null
	var texture := ImageTexture.create_from_image(image)
	_store(file, texture)
	return texture


static func cache_size() -> int:
	return _cache.size()


static func clear_cache() -> void:
	_cache.clear()


static func _store(file: String, texture: Texture2D) -> void:
	while _cache.size() >= CACHE_LIMIT:
		_cache.erase(_cache.keys()[0])
	_cache[file] = texture
