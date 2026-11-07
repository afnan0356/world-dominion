class_name GameEvent
extends RefCounted
## One thing that actually happened in a campaign, in a shape the interface can render.
##
## An event is **not** a notification and **not** a headline. It is a record: something the
## simulation or the save layer really did, on a real in-game date, with the exact numbers
## that were involved. Nothing in this class invents content:
##
## * the date is the in-game day the event was recorded on, stored as an integer day index
##   (the same index `GameClock` uses) plus the label the clock produced at that moment, so a
##   list written months ago still reads correctly even if a later build changes formatting;
## * the text is a **string-table key plus its parameters**, never a finished sentence, so the
##   interface can translate it later without touching saved games;
## * `origin` names the system that raised it (`campaign.start`, `save.autosave`, …), which is
##   what the Messages panel shows under "Why am I seeing this?".
##
## Categories and severities are closed lists. A value outside them is refused at load time
## rather than shown, because a category the interface does not know how to colour would
## silently lose its place in the filters.

## The systems an event can belong to. These mirror the game screen's categories, so a player
## reading the log recognises the same words as the buttons they pressed.
const CATEGORIES := ["campaign", "economy", "government", "diplomacy", "military",
		"research", "world", "system"]
## How loudly it should read. `info` is history, `notice` is worth knowing, `warning` is
## something that went wrong or needs a decision.
const SEVERITIES := ["info", "notice", "warning"]
## Days are stored as integers; a record without a valid one is refused.
const CATEGORY_FALLBACK := "system"
const SEVERITY_FALLBACK := "info"

var id := ""
## In-game day index, as `GameClock.day_index()` reports it (day 0 is the campaign start).
var day_index := 0
## The in-game date as the clock worded it when the event was recorded, e.g. "3 March 2026".
var date_label := ""
var category := CATEGORY_FALLBACK
var severity := SEVERITY_FALLBACK
## A key in `Strings.TABLE` (for example `events.autosave`), never a literal sentence.
var string_key := ""
## Named values for the `%{name}` placeholders in that string. Values are strings or whole
## numbers; anything else is refused so a save cannot smuggle a nested object into a label.
var params: Dictionary = {}
## Which system raised it, in the same dotted style as settings keys.
var origin := ""
## Whether the player has read it in the Messages panel. Absent read state is unread: a
## record the interface never showed cannot have been read.
var read := false


static func create(event_id: String, day: int, label: String, event_category: String,
		event_severity: String, key: String, values: Dictionary, event_origin: String) -> GameEvent:
	var event := GameEvent.new()
	event.id = event_id
	event.day_index = maxi(day, 0)
	event.date_label = label
	event.category = event_category if CATEGORIES.has(event_category) else CATEGORY_FALLBACK
	event.severity = event_severity if SEVERITIES.has(event_severity) else SEVERITY_FALLBACK
	event.string_key = key
	event.params = values.duplicate(true)
	event.origin = event_origin
	return event


## The player-facing sentence, built from the string table at the moment it is shown — never
## stored, so improving the wording does not require touching saved games.
func text() -> String:
	return Strings.tn(string_key, params)


## A one-line explanation of who raised the event, for the Messages panel's "why" line.
func origin_text() -> String:
	var key := "events.origin.%s" % origin
	return Strings.t(key) if Strings.has(key) else origin


func to_dict() -> Dictionary:
	return {
		"id": id,
		"day_index": day_index,
		"date_label": date_label,
		"category": category,
		"severity": severity,
		"key": string_key,
		"params": params.duplicate(true),
		"origin": origin,
		"read": read,
	}


## Rebuilds an event. Returns null when the record is not usable, appending the precise
## reason to `issues`; the log decides whether one bad record is enough to refuse the file.
static func from_dict(data: Variant) -> Dictionary:
	if not data is Dictionary:
		return {"event": null, "issue": "event is not an object"}
	var source: Dictionary = data
	var id_value := str(source.get("id", ""))
	if id_value.is_empty():
		return {"event": null, "issue": "event has no id"}
	var day: Variant = CanonicalJson.int_value(source.get("day_index"))
	if day == null or int(day) < 0:
		return {"event": null, "issue": "event %s has no valid day index" % id_value}
	var category_value := str(source.get("category", CATEGORY_FALLBACK))
	if not CATEGORIES.has(category_value):
		return {"event": null,
				"issue": "event %s has unknown category '%s'" % [id_value, category_value]}
	var severity_value := str(source.get("severity", SEVERITY_FALLBACK))
	if not SEVERITIES.has(severity_value):
		return {"event": null,
				"issue": "event %s has unknown severity '%s'" % [id_value, severity_value]}
	var key := str(source.get("key", ""))
	var issue := ""
	if key.is_empty() or not Strings.has(key):
		# The record is still real, so it is kept rather than dropped: its sentence is
		# replaced by a plain "this entry cannot be read" line that names the key, which is
		# visible in the list instead of the event quietly disappearing from history.
		issue = "event %s names a string key this build does not have" % id_value
	var values := {}
	var raw_params: Variant = source.get("params", {})
	if raw_params is Dictionary:
		for name: Variant in (raw_params as Dictionary).keys():
			var value: Variant = (raw_params as Dictionary)[name]
			if value is String:
				values[str(name)] = value
			else:
				var number: Variant = CanonicalJson.int_value(value)
				if number == null:
					return {"event": null,
							"issue": "event %s has a parameter that is not text or a whole number"
									% id_value}
				values[str(name)] = int(number)
	elif raw_params != null:
		return {"event": null, "issue": "event %s has non-object parameters" % id_value}
	if not issue.is_empty():
		values = {"key": key}
		key = "events.unknown"
	var event := create(id_value, int(day), str(source.get("date_label", "")),
			category_value, severity_value, key, values, str(source.get("origin", "")))
	event.read = bool(source.get("read", false))
	return {"event": event, "issue": issue}
