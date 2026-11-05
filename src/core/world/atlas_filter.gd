class_name AtlasFilter
extends RefCounted
## Search text and region filter for the atlas, as a small state object.
##
## Held separately from the screen so that "what is currently filtered" can be
## asserted in tests and reused by another view later. The filter never holds
## results: it asks the registry, which keeps one source of truth for the data.

signal changed

var query := ""
var region := ""


func set_query(value: String) -> bool:
	var trimmed := value.strip_edges()
	if trimmed == query:
		return false
	query = trimmed
	changed.emit()
	return true


func set_region(value: String) -> bool:
	if value == region:
		return false
	region = value
	changed.emit()
	return true


func clear() -> bool:
	if not is_active():
		return false
	query = ""
	region = ""
	changed.emit()
	return true


func clear_query() -> bool:
	return set_query("")


func is_active() -> bool:
	return has_query() or has_region()


func has_query() -> bool:
	return not query.is_empty()


func has_region() -> bool:
	return not region.is_empty()


## Matching records, in registry (alphabetical) order.
func apply(registry: CountryRegistry) -> Array[CountryRecord]:
	if registry == null:
		return []
	return registry.filter(query, region)


## A short, honest description of the current filter for status lines.
func describe(total: int, shown: int) -> String:
	if not is_active():
		return "%d nations" % total
	return "%d of %d nations" % [shown, total]
