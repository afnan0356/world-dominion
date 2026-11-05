class_name MapOptions
extends RefCounted
## A typed view over the map's display settings.
##
## These live in the same settings store as everything else, but they are read and
## written through `Settings.get_value`/`set_value` rather than through twenty more
## accessors on the settings service: an accessor pair per flag would be noise, and
## the settings service is already at its size limit.
##
## Nothing here changes data, hit boxes or a save. Every option is a display choice,
## and each one has a documented effect on what is drawn.

const SCHEMA := preload("res://src/core/config/settings_schema.gd")


static func labels() -> String:
	return str(Settings.get_value(SCHEMA.KEY_MAP_LABELS))


static func borders() -> bool:
	return bool(Settings.get_value(SCHEMA.KEY_MAP_BORDERS))


static func graticule() -> bool:
	return bool(Settings.get_value(SCHEMA.KEY_MAP_GRATICULE))


static func capitals() -> bool:
	return bool(Settings.get_value(SCHEMA.KEY_MAP_CAPITALS))


static func reference_lines() -> bool:
	return bool(Settings.get_value(SCHEMA.KEY_MAP_REFERENCE_LINES))


static func set_labels(value: String) -> void:
	Settings.set_value(SCHEMA.KEY_MAP_LABELS, value)


static func set_borders(enabled: bool) -> void:
	Settings.set_value(SCHEMA.KEY_MAP_BORDERS, enabled)


static func set_graticule(enabled: bool) -> void:
	Settings.set_value(SCHEMA.KEY_MAP_GRATICULE, enabled)


static func set_capitals(enabled: bool) -> void:
	Settings.set_value(SCHEMA.KEY_MAP_CAPITALS, enabled)


static func set_reference_lines(enabled: bool) -> void:
	Settings.set_value(SCHEMA.KEY_MAP_REFERENCE_LINES, enabled)


## Everything the map needs in one call, so a screen can apply the options with one
## pass instead of six reads.
static func snapshot() -> Dictionary:
	return {
		"labels": labels(),
		"borders": borders(),
		"graticule": graticule(),
		"capitals": capitals(),
		"reference_lines": reference_lines(),
		"detail": Settings.get_map_detail(),
	}


## Applies a snapshot to a map view. Kept here so the game screen and the atlas
## cannot drift apart in what "apply the options" means.
static func apply_to(map_view: Node) -> void:
	if map_view == null:
		return
	map_view.call("set_options", snapshot())
	map_view.call("set_detail_reduced", Settings.get_map_detail() == SCHEMA.DETAIL_REDUCED)
