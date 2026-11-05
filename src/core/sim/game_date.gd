class_name GameDate
extends RefCounted
## A calendar date in the game world: year, month and day, with no time-of-day.
##
## Dates are plain proleptic-Gregorian calendar dates, which is the calendar the
## modern-world scenario uses. All arithmetic happens on a **day index** — the
## number of days since 1 January 0001 — so adding a day is integer addition and
## never a floating-point guess. The rules implemented here are the real ones:
##
## * a year is a leap year when it is divisible by 4, **except** centuries, which
##   are leap years only when divisible by 400 (so 2000 is a leap year, 1900 and
##   2100 are not);
## * February therefore has 28 days in a common year and 29 in a leap year;
## * April, June, September and November have 30 days; the rest have 31.
##
## Every one of those rules is asserted by `tests/suites/test_sim_calendar.gd`.
## Nothing here reads the system clock: an in-game date is game state, not the
## player's real date.

const MONTH_NAMES: PackedStringArray = ["January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"]
const DAYS_IN_MONTH: PackedInt32Array = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
## Year 0 of the day index. Documented because saves store the day index.
const EPOCH_LABEL := "1 January 0001"

var year := 1
var month := 1
var day := 1


static func make(year_value: int, month_value: int, day_value: int) -> GameDate:
	var date := GameDate.new()
	date.year = year_value
	date.month = month_value
	date.day = day_value
	return date


## Parses `YYYY-MM-DD`. Returns null (never a guessed date) when the text is not
## a real calendar date.
static func parse(text: String) -> GameDate:
	if not is_valid_text(text):
		return null
	var parts := text.split("-")
	return make(int(parts[0]), int(parts[1]), int(parts[2]))


static func is_valid_text(text: String) -> bool:
	if not text is String or text.length() != 10 or text[4] != "-" or text[7] != "-":
		return false
	var parts := text.split("-")
	if parts.size() != 3:
		return false
	for part: String in parts:
		if part.is_empty():
			return false
		for index in part.length():
			var code := part.unicode_at(index)
			if code < 48 or code > 57:
				return false
	return is_valid(int(parts[0]), int(parts[1]), int(parts[2]))


static func is_valid(year_value: int, month_value: int, day_value: int) -> bool:
	if year_value < 1 or year_value > 9999:
		return false
	if month_value < 1 or month_value > 12:
		return false
	return day_value >= 1 and day_value <= days_in_month(year_value, month_value)


static func is_leap_year(year_value: int) -> bool:
	if year_value % 4 != 0:
		return false
	if year_value % 100 != 0:
		return true
	return year_value % 400 == 0


static func days_in_month(year_value: int, month_value: int) -> int:
	if month_value < 1 or month_value > 12:
		return 0
	if month_value == 2 and is_leap_year(year_value):
		return 29
	return DAYS_IN_MONTH[month_value - 1]


static func days_in_year(year_value: int) -> int:
	return 366 if is_leap_year(year_value) else 365


## Days elapsed before 1 January of `year_value`.
static func days_before_year(year_value: int) -> int:
	var previous := year_value - 1
	return 365 * previous + previous / 4 - previous / 100 + previous / 400


## Builds a date from a day index (1 for 1 January 0001). Invalid indices are
## clamped into the supported range rather than producing a nonsense date.
static func from_day_index(day_index: int) -> GameDate:
	var index := clampi(day_index, 1, max_day_index())
	var date := GameDate.new()
	# Estimate the year from the average year length, then correct by one step at
	# a time. The estimate is never off by more than a couple of years, so the
	# correction is cheap and exact — no floating point in the result.
	var remaining := index - 1
	var year_value := clampi(1 + remaining / 365, 1, 9999)
	while days_before_year(year_value + 1) <= remaining:
		year_value += 1
	while year_value > 1 and days_before_year(year_value) > remaining:
		year_value -= 1
	date.year = year_value
	var day_of_year := remaining - days_before_year(year_value)
	date.month = 1
	while day_of_year >= days_in_month(year_value, date.month):
		day_of_year -= days_in_month(year_value, date.month)
		date.month += 1
	date.day = day_of_year + 1
	return date


static func max_day_index() -> int:
	return days_before_year(9999) + 364


## The day index for this date: 1 for 1 January 0001.
func to_day_index() -> int:
	var total := days_before_year(year) + day - 1
	for month_index in range(1, month):
		total += days_in_month(year, month_index)
	return total


func is_valid_date() -> bool:
	return is_valid(year, month, day)


func copy() -> GameDate:
	return GameDate.make(year, month, day)


func equals(other: GameDate) -> bool:
	return other != null and other.year == year and other.month == month and other.day == day


func compare(other: GameDate) -> int:
	if other == null:
		return 1
	if year != other.year:
		return -1 if year < other.year else 1
	if month != other.month:
		return -1 if month < other.month else 1
	if day != other.day:
		return -1 if day < other.day else 1
	return 0


func add_days(count: int) -> GameDate:
	return GameDate.from_day_index(to_day_index() + count)


func next_day() -> GameDate:
	return add_days(1)


func month_name() -> String:
	if month < 1 or month > 12:
		return ""
	return MONTH_NAMES[month - 1]


## "1 January 2026" — the form used in the interface.
func format_long() -> String:
	return "%d %s %d" % [day, month_name(), year]


## "2026-01-01" — the form used in files and tests.
func format_short() -> String:
	return "%04d-%02d-%02d" % [year, month, day]


## "January 2026" — used by the monthly autosave indicator and journal lines.
func format_month() -> String:
	return "%s %d" % [month_name(), year]


func is_first_of_month() -> bool:
	return day == 1


func is_first_of_year() -> bool:
	return month == 1 and day == 1


func _to_string() -> String:
	return format_short()
