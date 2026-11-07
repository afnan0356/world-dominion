class_name TestCase
extends RefCounted
## Minimal assertion + discovery helpers for the project's headless test suite.
##
## A dependency-free runner is deliberate: WORLD DOMINION should not pull in a
## test framework before one is actually needed, and these suites are small.
## Suites define `func test_*() -> void` methods; async tests may use `await`.

var failures: Array[String] = []
var assertions := 0
var tree: SceneTree = null
## Node the suite may attach temporary scenes to (the runner itself).
var host: Node = null

var _current_test := ""


func suite_name() -> String:
	return get_script().resource_path.get_file().get_basename()


## Runs every `test_*` method. `order_seed` below zero keeps declaration order (the normal
## gate); a seed shuffles the methods reproducibly, so a run can prove that no test inside a
## suite depends on the one before it. The shuffle is seeded from the value and the suite's own
## path, so two suites with the same seed do not start from the same permutation.
func run_all(order_seed: int = -1) -> int:
	var names := PackedStringArray()
	for method: Dictionary in get_method_list():
		var method_name: String = method.get("name", "")
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	if order_seed >= 0:
		names = _shuffled(names, order_seed + suite_name().hash() % 100_000)
	var count := 0
	for method_name: String in names:
		_current_test = method_name
		count += 1
		print("  RUN %s" % method_name)
		await call(method_name)
	return count


## Called once before a suite's tests and once after, by the runner. Overriding these is how a
## suite states what it needs set up once — a world atlas, a store — instead of building it in the
## first test and hoping the others run later.
func before_suite() -> void:
	pass


func after_suite() -> void:
	pass


static func _shuffled(names: PackedStringArray, seed_value: int) -> PackedStringArray:
	var out := names.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(out.size() - 1, 0, -1):
		var swap: int = rng.randi_range(0, index)
		var held: String = out[index]
		out[index] = out[swap]
		out[swap] = held
	return out


# --- Assertions ------------------------------------------------------------

func check(condition: bool, message: String) -> bool:
	assertions += 1
	if not condition:
		failures.append("[%s] %s" % [_current_test, message])
		push_error("%s / %s: %s" % [suite_name(), _current_test, message])
	return condition


func check_eq(actual: Variant, expected: Variant, message: String) -> bool:
	return check(actual == expected, "%s (expected %s, got %s)" % [message, expected, actual])


func check_gt(actual: float, minimum: float, message: String) -> bool:
	return check(actual > minimum, "%s (expected > %s, got %s)" % [message, minimum, actual])


func check_gte(actual: float, minimum: float, message: String) -> bool:
	return check(actual >= minimum, "%s (expected >= %s, got %s)" % [message, minimum, actual])


func check_lte(actual: float, maximum: float, message: String) -> bool:
	return check(actual <= maximum, "%s (expected <= %s, got %s)" % [message, maximum, actual])


func check_true(value: bool, message: String) -> bool:
	return check(value, message)


func check_false(value: bool, message: String) -> bool:
	return check(not value, message)


func check_not_null(value: Variant, message: String) -> bool:
	return check(value != null, message)


## WCAG 2.1 relative luminance of an sRGB colour.
static func relative_luminance(color: Color) -> float:
	return 0.2126 * _linearize(color.r) + 0.7152 * _linearize(color.g) + 0.0722 * _linearize(color.b)


## WCAG contrast ratio between two opaque colours (1.0 – 21.0).
static func contrast_ratio(foreground: Color, background: Color) -> float:
	var a := relative_luminance(foreground)
	var b := relative_luminance(background)
	var lighter := maxf(a, b)
	var darker := minf(a, b)
	return (lighter + 0.05) / (darker + 0.05)


static func _linearize(channel: float) -> float:
	if channel <= 0.04045:
		return channel / 12.92
	return pow((channel + 0.055) / 1.055, 2.4)
