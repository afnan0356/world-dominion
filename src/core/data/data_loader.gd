class_name DataLoader
extends RefCounted
## Small, defensive loader for the project's JSON data files (`res://data/`).
##
## Data files hold content that is likely to change — credits, build status,
## future world/country catalogues — so it lives outside scripts. Every failure
## path returns an empty value after reporting an error, which lets a screen
## degrade gracefully instead of crashing the application.

const DATA_ROOT := "res://data/"


## Reads and parses a JSON file under `res://data/`. `relative_path` may be given
## with or without the `res://` prefix. Returns `null` on any failure.
static func load_json(relative_path: String) -> Variant:
	var path := _resolve(relative_path)
	if not FileAccess.file_exists(path):
		push_error("DataLoader: file not found at %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataLoader: cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("DataLoader: malformed JSON in %s at line %d: %s" % [
			path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## Like `load_json`, but guarantees a Dictionary result (`{}` on failure).
static func load_dictionary(relative_path: String) -> Dictionary:
	var data: Variant = load_json(relative_path)
	if data is Dictionary:
		return data
	if data != null:
		push_error("DataLoader: expected an object in %s" % relative_path)
	return {}


## Returns `value` from `dictionary` when it is of the expected type, else
## `fallback`. Used to keep data-driven screens tolerant of partial content.
static func get_typed(dictionary: Dictionary, key: String, expected_type: int,
		fallback: Variant) -> Variant:
	var value: Variant = dictionary.get(key)
	if value != null and typeof(value) == expected_type:
		return value
	return fallback


static func _resolve(relative_path: String) -> String:
	if relative_path.begins_with("res://"):
		return relative_path
	return DATA_ROOT + relative_path
