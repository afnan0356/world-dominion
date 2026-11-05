class_name CalendarSystem
extends SimulationSystem
## The only system registered in this milestone, and the only one that could be
## honest: it turns ticks into calendar events.
##
## It does nothing else. It invents no statistics, changes no country state, and
## its `describe()` line is what the simulation-status panel shows. Future systems
## (economy, politics, diplomacy, military) will register themselves beside there
## with their own order, frequency and version — when they exist.
##
## Events published, once per tick at most:
##   * `EventBus.DAY_ADVANCED` — every day, payload: day_index, date
##   * `EventBus.MONTH_STARTED` — on day 1 of a month, payload: date
##   * `EventBus.YEAR_STARTED` — on 1 January, payload: date

const ORDER_CLOCK := 10

var days_seen := 0
var months_seen := 0
var years_seen := 0


func _init() -> void:
	id = "calendar"
	order = ORDER_CLOCK
	frequency = Frequency.DAILY
	version = 1


func update(context: Dictionary) -> bool:
	var date: GameDate = context.get("date")
	var bus: EventBus = context.get("bus")
	if date == null or bus == null:
		return false
	days_seen += 1
	bus.publish(EventBus.DAY_ADVANCED, {
		"day_index": date.to_day_index(),
		"date": date.format_short(),
		"label": date.format_long(),
	})
	if date.is_first_of_month():
		months_seen += 1
		bus.publish(EventBus.MONTH_STARTED, {
			"date": date.format_short(),
			"label": date.format_month(),
		})
	if date.is_first_of_year():
		years_seen += 1
		bus.publish(EventBus.YEAR_STARTED, {
			"date": date.format_short(),
			"label": str(date.year),
		})
	return true


func describe() -> String:
	return "Calendar — one in-game day per tick, publishes day, month and year events"
