class_name AtlasHistory
extends RefCounted
## The "recently viewed" list for the atlas.
##
## Deliberately **not** part of a campaign: it is not in WorldState, not in a save
## and not in the wallet. It is a local convenience list in the settings store,
## capped at [constant SettingsSCHEMA.RECENT_LIMIT] entries, so looking at Paraguay
## cannot change a campaign's state hash.

const SCHEMA := preload("res://src/core/config/settings_schema.gd")


static func recent() -> PackedStringArray:
	var value: Variant = Settings.get_value(SCHEMA.KEY_RECENT_COUNTRIES)
	var out := PackedStringArray()
	if value is Array:
		for item: Variant in value:
			if item is String and not str(item).is_empty():
				out.append(str(item))
	return out


static func remember(country_id: String) -> void:
	if country_id.is_empty():
		return
	var rebuilt := PackedStringArray([country_id])
	for item: String in recent():
		if item != country_id and rebuilt.size() < SCHEMA.RECENT_LIMIT:
			rebuilt.append(item)
	Settings.set_value(SCHEMA.KEY_RECENT_COUNTRIES, Array(rebuilt))


static func clear() -> void:
	Settings.set_value(SCHEMA.KEY_RECENT_COUNTRIES, [])


## The recent ids that still exist in `registry`, newest first. A record removed
## from a future dataset simply drops out instead of leaving a dead entry.
static func recent_valid(registry: CountryRegistry) -> PackedStringArray:
	var out := PackedStringArray()
	if registry == null:
		return out
	for country_id: String in recent():
		if registry.has_country(country_id):
			out.append(country_id)
	return out
