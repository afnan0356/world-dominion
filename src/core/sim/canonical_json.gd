class_name CanonicalJson
extends RefCounted
## Deterministic JSON text for hashing and checksums.
##
## `JSON.stringify()` keeps dictionary insertion order, which differs depending on
## how a dictionary was built. Two saves holding the same state must hash the same,
## so this writer sorts every object's keys and normalises numbers:
##
## * there is **one canonical number form**, and both the writer and everything that
##   digests a payload go through `canonicalise()` first: a whole-valued float becomes
##   an integer (`2`, never `2.0`), `-0.0` becomes `0`, and any other float is rounded
##   to nine decimal places. That rounding is the documented precision of the format;
##   a value that needs more (a duration, a counter) is stored as an integer instead;
## * floats are then written with ten decimal places at most, which is enough to write
##   a rounded value back exactly, so text and digest agree in both directions;
## * NaN and infinity are refused — they are not valid save data, and writing them
##   as `null` would silently change the state;
## * strings and keys are escaped by the engine's own `JSON.stringify`.
##
## Arrays keep their order: a list's order is part of the state.

## The precision of the canonical number form: nine decimal places. A value that
## needs to be exact — a duration, a counter, money — is stored as an integer instead.
const PRECISION := 9

class InvalidValue:
	extends RefCounted
	var path := ""


## Canonical text for `value`. Returns "" and fills `error` when the value cannot
## be represented (NaN, infinity, or an unsupported type).
static func stringify(value: Variant, error: Array = []) -> String:
	var parts: PackedStringArray = []
	var result := _write(canonicalise(value), "$", parts, error)
	return result


## The canonical form of `value`: every whole-valued float is an integer, `-0.0` is
## `0`, and any other float is rounded to `PRECISION` decimal places. Writing and
## digesting both start here, so a payload and its own text can never disagree.
static func canonicalise(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[key] = canonicalise((value as Dictionary)[key])
		return out
	if value is Array:
		var items := []
		for item: Variant in value:
			items.append(canonicalise(item))
		return items
	if value is float:
		return _canonical_number(float(value))
	return value


static func _canonical_number(number: float) -> Variant:
	if is_nan(number) or is_inf(number):
		return number
	# A whole value is an integer, tested before anything is rounded: rounding a large
	# whole number by scaling it can introduce the very noise this is meant to remove.
	var whole: Variant = int_value(number)
	if whole != null:
		return whole
	# Otherwise round to the documented precision, but only when scaling stays inside the
	# range where integers are exact — a fraction too large for that is left as it is.
	var scaled := number * pow(10.0, float(PRECISION))
	if absf(scaled) < 9.0e15:
		var rounded: float = round(scaled) / pow(10.0, float(PRECISION))
		var rounded_whole: Variant = int_value(rounded)
		if rounded_whole != null:
			return rounded_whole
		return rounded
	return number


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
			error.append("%s is not a finite number" % path)
			return "null"
		if number == 0.0:
			return "0"
		# Only non-whole floats reach here: `canonicalise()` has already turned every
		# whole value into an integer. Ten decimal places writes a value rounded to
		# `PRECISION` back exactly, so reading the text returns the value that was written.
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
	return canonicalise(value)


## The number form used by saves written before Milestone 07: a whole float was
## written as `2.0`, not `2`, and nothing was rounded. Kept only so an old file can
## prove it is intact — everything new uses `canonicalise()`.
static func legacy_normalise(value: Variant) -> Variant:
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[key] = legacy_normalise((value as Dictionary)[key])
		return out
	if value is Array:
		var items := []
		for item: Variant in value:
			items.append(legacy_normalise(item))
		return items
	if value is float:
		var number: Variant = CanonicalJson.int_value(value)
		if number != null:
			return number
	return value


## Canonical text the way the pre-Milestone-07 writer produced it, for verifying files
## it wrote. Never use it to write a new file.
static func stringify_legacy(value: Variant, error: Array = []) -> String:
	return _write_legacy(legacy_normalise(value), error)


static func _write_legacy(value: Variant, error: Array) -> String:
	if value is Dictionary:
		var keys: Array = (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		var entries := PackedStringArray()
		for key: Variant in keys:
			entries.append(JSON.stringify(str(key)) + ":"
					+ _write_legacy((value as Dictionary)[key], error))
		return "{" + ", ".join(entries) + "}"
	if value is Array:
		var items := PackedStringArray()
		for item: Variant in value:
			items.append(_write_legacy(item, error))
		return "[" + ", ".join(items) + "]"
	if value is float:
		var number := float(value)
		if is_nan(number) or is_inf(number):
			error.append("a legacy float is not finite")
			return "null"
		if number == 0.0:
			return "0.0"
		if number == floor(number) and absf(number) < 1.0e15:
			return "%.1f" % number
		return String.num(number, 10)
	return _write(value, "$", PackedStringArray(), error)


## Digest of the legacy text, used only to recognise a file written before the
## canonical form changed.
static func sha256_legacy(value: Variant, error: Array = []) -> String:
	var text := stringify_legacy(value, error)
	if not error.is_empty():
		return ""
	return text.sha256_text()


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


## SHA-256 of the canonical text, which is `canonicalise()` then the canonical writer.
## `error` receives a message when the value cannot be hashed at all, and the result is
## then "".
static func sha256(value: Variant, error: Array = []) -> String:
	var text := stringify(value, error)
	# A value that could not be written exactly must not be hashed: the digest would
	# describe a "null" the value never contained, and a save would then verify
	# against data that was never there.
	if not error.is_empty():
		return ""
	return text.sha256_text()
