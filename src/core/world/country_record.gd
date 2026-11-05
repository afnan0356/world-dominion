class_name CountryRecord
extends RefCounted
## One selectable nation/territory in the world atlas.
##
## A record is a *read-only view of the source data*: nothing here is inferred.
## Optional values that the source does not provide (ISO codes, a capital city,
## a sovereignty note) are empty strings rather than invented placeholders, and
## `has_*` helpers state which case applies. Population, GDP, income group and
## every other statistical column present in the Natural Earth file are
## deliberately not imported (see docs/DATA_SOURCES.md).

## Stable identifier: ISO alpha-3 when the source provides one, otherwise
## Natural Earth's admin-0 code. Never derived from display names.
const ID_PATTERN := "^[A-Z]{3}(-[0-9]+)?$"

var id := ""
var name := ""
var name_long := ""
var iso_a2 := ""
var iso_a3 := ""
var region := ""
var subregion := ""
var capital := ""
var type := ""
var sovereignty := ""
var note := ""
var label_rank := 10
var tiny := false
var has_label := false
var label := Vector2.ZERO
var bbox := Rect2()
var filter_region := false
var search_key := ""

## Problems found while reading this record; empty when the record is usable.
var issues: PackedStringArray = []


## Builds a record from one entry of `data/world/countries.json`. Returns null
## only when the entry cannot identify itself (missing/invalid id or name):
## a record that is merely incomplete is still returned, with `issues` set.
static func from_dict(data: Variant) -> CountryRecord:
	if not data is Dictionary:
		return null
	var source: Dictionary = data
	var record := CountryRecord.new()
	record.id = str(source.get("id", ""))
	record.name = str(source.get("name", ""))
	if not record.is_valid_id() or record.name.is_empty():
		return null
	record.name_long = str(source.get("name_long", record.name))
	record.iso_a2 = _clean_iso(source.get("iso_a2"), 2)
	record.iso_a3 = _clean_iso(source.get("iso_a3"), 3)
	for entry: Array in [["iso_a2", record.iso_a2, 2], ["iso_a3", record.iso_a3, 3]]:
		var key: String = entry[0]
		var raw: Variant = source.get(key)
		if raw != null and str(raw) != "" and str(entry[1]).is_empty():
			record.issues.append("malformed %s '%s'" % [key, str(raw)])
	record.region = str(source.get("region", ""))
	record.subregion = str(source.get("subregion", ""))
	record.capital = str(source.get("capital", ""))
	record.type = str(source.get("type", ""))
	record.sovereignty = str(source.get("sovereignty", ""))
	record.note = str(source.get("note", ""))
	record.label_rank = int(source.get("label_rank", 10))
	record.tiny = bool(source.get("tiny", false))
	record.filter_region = bool(source.get("filter_region", false))
	record.search_key = str(source.get("search", record.name.to_lower()))
	var label_value: Variant = source.get("label")
	if label_value is Array and (label_value as Array).size() == 2:
		record.has_label = true
		record.label = Vector2(float(label_value[0]), float(label_value[1]))
	var bbox_value: Variant = source.get("bbox")
	if bbox_value is Array and (bbox_value as Array).size() == 4:
		record.bbox = Rect2(
			Vector2(float(bbox_value[0]), float(bbox_value[1])),
			Vector2(float(bbox_value[2]) - float(bbox_value[0]),
					float(bbox_value[3]) - float(bbox_value[1])))
		if record.bbox.size.x <= 0.0 or record.bbox.size.y <= 0.0:
			record.issues.append("degenerate bbox")
	else:
		record.issues.append("missing bbox")
	if record.region.is_empty():
		record.issues.append("missing region")
	return record


## ISO codes are kept only when the source value is a plain uppercase code of
## the expected length; a source value such as "CN-TW" in the alpha-2 column is
## reported as absent rather than silently presented as an ISO alpha-2 code.
static func _clean_iso(value: Variant, length: int) -> String:
	if value == null:
		return ""
	var code := str(value)
	if code.length() != length:
		return ""
	for index in code.length():
		if code[index] < "A" or code[index] > "Z":
			return ""
	return code


func is_valid_id() -> bool:
	var expression := RegEx.new()
	if expression.compile(ID_PATTERN) != OK:
		return false
	return expression.search(id) != null


func has_iso_a2() -> bool:
	return not iso_a2.is_empty()


func has_iso_a3() -> bool:
	return not iso_a3.is_empty()


## True when the dataset names a capital for this unit. Absence is a property of
## the source, not a hint to fill the gap.
func has_capital() -> bool:
	return not capital.is_empty()


func has_subregion() -> bool:
	return not subregion.is_empty()


## Human-readable ISO line, stating what is unknown instead of hiding it.
func iso_label() -> String:
	match [has_iso_a3(), has_iso_a2()]:
		[true, true]:
			return "%s · %s" % [iso_a3, iso_a2]
		[true, false]:
			return "%s · no alpha-2 code in source" % iso_a3
		[false, true]:
			return "%s · no alpha-3 code in source" % iso_a2
		_:
			return "No ISO code recorded in source"


## The political classification as the dataset states it. This project does not
## arbitrate sovereignty: the source's type, sovereignty and note are reported
## verbatim, and disputed units are visible as such rather than resolved.
func political_label() -> String:
	var parts: PackedStringArray = []
	if not type.is_empty():
		parts.append(type)
	if not sovereignty.is_empty() and sovereignty != name:
		parts.append("source records sovereignty as %s" % sovereignty)
	if not note.is_empty():
		parts.append(note)
	return " · ".join(parts)


## True when the dataset files this unit as anything other than a plain country.
func is_political_edge_case() -> bool:
	return type != "Sovereign country"


## Short label used on the map and in compact lists.
func short_name() -> String:
	return name if name.length() <= 18 else (name_long if name_long.length() <= 18 else name)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"name_long": name_long,
		"iso_a2": iso_a2,
		"iso_a3": iso_a3,
		"region": region,
		"subregion": subregion,
		"capital": capital,
		"type": type,
		"sovereignty": sovereignty,
		"note": note,
		"bbox": [bbox.position.x, bbox.position.y, bbox.end.x, bbox.end.y],
		"label_rank": label_rank,
	}
