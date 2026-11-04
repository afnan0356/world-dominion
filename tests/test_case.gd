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


## Runs every `test_*` method in declaration-independent order.
func run_all() -> int:
	var count := 0
	for method: Dictionary in get_method_list():
		var method_name: String = method.get("name", "")
		if not method_name.begins_with("test_"):
			continue
		_current_test = method_name
		count += 1
		await call(method_name)
	return count


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
