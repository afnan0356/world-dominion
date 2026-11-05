class_name CanonicalJson
extends RefCounted
## Deterministic JSON text for hashing and checksums.
##
## `JSON.stringify()` keeps dictionary insertion order, which differs depending on
## how a dictionary was built. Two saves holding the same state must hash the same,
## so this writer sorts every object's keys and normalises numbers:
##
## * integers are written as integers (`2`, never `2.0`);
## * floats are written with enough digits to round-trip, and `-0.0` becomes `0.0`;
## * NaN and infinity are refused — they are not valid save data, and writing them
##   as `null` would silently change the state;
## * strings and keys are escaped by the engine's own `JSON.stringify`.
##
## Arrays keep their order: a list's order is part of the state.

class InvalidValue:
	extends RefCounted
	var path := ""


## Canonical text for `value`. Returns "" and fills `error` when the value cannot
## be represented (NaN, infinity, or an unsupported type).
static func stringify(value: Variant, error: Array = []) -> String:
	var parts: PackedStringArray = []
	var result := _write(value, "$", parts, error)
	return result


static func _write(value: Variant, path: String, parts: PackedStringArray,
		error: Array) -> String:
	if value == null:
		return "null"
	if value is bool:
		return "true" if value else "false"
	if value is int:
		return str(value)
	if value is float:
		var number := float(value)
		if is_nan(number) or is_inf(number):
			if not error.is_empty():
				error.append("%s is not a finite number" % path)
			return "null"
		if number == 0.0:
			return "0.0"
		if number == floor(number) and absf(number) < 1.0e15:
			# A whole float is still written as a float so that a reader can tell
			# 2.0 from 2, which matters for strict type checks on load.
			return "%.1f" % number
		return String.num(number, 10)
	if value is String or value is StringName:
		return JSON.stringify(str(value))
	if value is Array:
		var items := PackedStringArray()
		for index in (value as Array).size():
			items.append(_write((value as Array)[index], "%s[%d]" % [path, index], parts, error))
		return "[" + ", ".join(items) + "]"
	if value is Dictionary or value is PackedStringArray:
		var source: Dictionary = {}
		if value is Dictionary:
			source = value
		else:
			for index in (value as PackedStringArray).size():
				source[str(index)] = (value as PackedStringArray)[index]
		var keys: Array = source.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var entries := PackedStringArray()
		for key: Variant in keys:
			entries.append(JSON.stringify(str(key)) + ":"
					+ _write(source[key], "%s.%s" % [path, str(key)], parts, error))
		return "{" + ", ".join(entries) + "}"
	if not error.is_empty():
		error.append("%s holds an unsupported type (%s)" % [path, type_string(typeof(value))])
	return "null"


## A copy of `value` where every whole-valued float becomes an int.
##
## JSON has one number type, so `2` written by this writer comes back as a float.
## Hashing a payload that went through that round trip would then differ from hashing
## the payload in memory, and a save would fail its own checksum. Normalising whole
## numbers makes the checksum depend on the *value*, not on whether a number happened
## to travel through JSON — while 2.5 stays 2.5, so a fractional value is still a
## different value.
static func normalise_numbers(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[key] = normalise_numbers((value as Dictionary)[key])
		return out
	if value is Array:
		var items := []
		for item: Variant in value:
			items.append(normalise_numbers(item))
		return items
	if value is float:
		var number := CanonicalJson.int_value(value)
		if number != null:
			return number
	return value


## The integer a parsed number represents, or null when it is not a whole number.
##
## JSON has a single number type, so a reader gets `2` and `2.0` for the same
## written digit — it must accept both as the integer two, and must refuse `2.5`
## rather than quietly rounding it. Bounds keep the value inside the range a
## double can represent exactly (2^53), so a huge value is rejected, not truncated.
static func int_value(value: Variant) -> Variant:
	if value is int:
		return value
	if value is float:
		var number := float(value)
		if is_finite(number) and number == floor(number) \
				and absf(number) <= 9007199254740992.0:
			return int(number)
	return null


## SHA-256 of the canonical text. `error` receives a message when the value cannot
## be hashed at all, and the result is then "".
static func sha256(value: Variant, error: Array = []) -> String:
	var text := stringify(value, error)
	if text.is_empty() and not error.is_empty():
		return ""
	return text.sha256_text()
