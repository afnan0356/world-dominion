class_name Scenario
extends RefCounted
## One playable scenario definition, read from `data/scenarios/*.json`.
##
## A scenario is data, not code: it names the era, fixes the starting date and
## declares whether the build can actually start it. `implemented` is the honest
## switch — an unimplemented scenario may be listed for planning, but the setup
## screen refuses to start it and says why.

const DATE_PATTERN := "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
const MONTHS := [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December",
]

var id := ""
var name := ""
var start_date := ""
var description := ""
var note := ""
var implemented := false
var issues: PackedStringArray = []


static func from_dict(data: Variant) -> Scenario:
	if not data is Dictionary:
		return null
	var source: Dictionary = data
	var scenario := Scenario.new()
	scenario.id = str(source.get("id", ""))
	scenario.name = str(source.get("name", ""))
	scenario.start_date = str(source.get("start_date", ""))
	scenario.description = str(source.get("description", ""))
	scenario.note = str(source.get("note", ""))
	scenario.implemented = bool(source.get("implemented", false))
	if scenario.id.is_empty() or not scenario.id.is_valid_identifier():
		return null
	if scenario.name.is_empty():
		scenario.issues.append("scenario has no display name")
	if not is_valid_date(scenario.start_date):
		scenario.issues.append("start date '%s' is not a valid YYYY-MM-DD date"
				% scenario.start_date)
	return scenario


## A calendar-valid ISO date. Rejects impossible dates such as 2026-02-30.
static func is_valid_date(text: String) -> bool:
	var expression := RegEx.new()
	if expression.compile(DATE_PATTERN) != OK or expression.search(text) == null:
		return false
	var parts := text.split("-")
	if parts.size() != 3:
		return false
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	if month < 1 or month > 12 or day < 1:
		return false
	var lengths := [31, 29 if _is_leap(year) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return day <= int(lengths[month - 1])


static func _is_leap(year: int) -> bool:
	return (year % 4 == 0 and year % 100 != 0) or year % 400 == 0


## "1 January 2026" — used wherever the date is shown to the player.
static func format_date(text: String) -> String:
	if not is_valid_date(text):
		return text
	var parts := text.split("-")
	var day := int(parts[2])
	var month := int(parts[1])
	return "%d %s %s" % [day, MONTHS[month - 1], parts[0]]


func start_date_label() -> String:
	return format_date(start_date)


func is_usable() -> bool:
	return implemented and issues.is_empty() and is_valid_date(start_date)
