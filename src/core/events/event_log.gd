class_name EventLog
extends RefCounted
## The campaign's history: every event that really happened, oldest first.
##
## Why a capped, oldest-first list:
##
## * **Oldest first** matches how a newspaper reads and how a person remembers. The newest
##   entry is at the end, and trimming removes from the *front*, so the recent past is the
##   part that survives.
## * **A cap** keeps a long campaign's save file small. `MAX_EVENTS` is a hard ceiling: the
##   save is kilobytes today and stays kilobytes after a year of play.
##
## The log never creates content of its own. `record()` is called by systems that have just
## done something (a save written, a campaign started), with the values they actually used.
## There is no sample data, no seed events and no "welcome" entry, so an empty list means
## exactly that: nothing has happened yet.

## How many events a campaign keeps. 200 is roughly a year of month-boundary autosaves plus
## room for everything else, and about 60 kB of save data in the worst case measured by
## `test_event_log.gd`.
const MAX_EVENTS := 200
## Never trimmed: a campaign that somehow recorded more than this in one load is damaged, and
## refusing is safer than silently dropping the player's history.
const LOAD_CEILING := 2000
const STORAGE_KEY := "events"

## Monotonic counter for ids. Saved with the log so that an id is never reused after a trim,
## which is what lets the read state stay attached to the right entry.
var next_sequence := 1
## Oldest first.
var entries: Array = []
## Non-fatal problems found while loading (for the diagnostics report), e.g. a record whose
## string key no longer exists.
var load_notes: PackedStringArray = []


## Adds an event that really happened. `day_index` and `date_label` come from the clock at the
## moment of recording; `values` fills the `%{name}` placeholders of `key`.
func record(event_category: String, event_severity: String, key: String, values: Dictionary,
		origin: String, day_index: int, date_label: String) -> GameEvent:
	var event := GameEvent.create("evt-%06d" % next_sequence, day_index, date_label,
			event_category, event_severity, key, values, origin)
	next_sequence += 1
	entries.append(event)
	_trim()
	return event


## Drops the oldest entries until the list fits the cap. Returns how many were dropped.
func _trim() -> int:
	var dropped := 0
	while entries.size() > MAX_EVENTS:
		entries.pop_front()
		dropped += 1
	return dropped


func size() -> int:
	return entries.size()


func is_empty() -> bool:
	return entries.is_empty()


## Newest first, which is the order both the Messages panel and the News screen read in.
func newest_first() -> Array:
	var out: Array = entries.duplicate()
	out.reverse()
	return out


## The new→old list narrowed by a category (`""` means every category) and a search query.
## The query is matched case-insensitively against the rendered sentence, its date label and
## its origin, so "autosave" and "2026" both work without a second index.
func filtered(event_category: String, query: String) -> Array:
	var needle := query.strip_edges().to_lower()
	var out: Array = []
	for event: GameEvent in newest_first():
		if not event_category.is_empty() and event.category != event_category:
			continue
		if not needle.is_empty():
			var haystack := ("%s %s %s" % [event.text(), event.date_label,
					event.origin_text()]).to_lower()
			if not haystack.contains(needle):
				continue
		out.append(event)
	return out


## How many events the player has not read yet. This is the number on the left rail's badge,
## and it is derived, never stored: a stale counter in a save would be one more thing to go
## wrong.
func unread_count() -> int:
	var count := 0
	for event: GameEvent in entries:
		if not event.read:
			count += 1
	return count


func unread_by_category() -> Dictionary:
	var counts := {}
	for event: GameEvent in entries:
		if event.read:
			continue
		counts[event.category] = int(counts.get(event.category, 0)) + 1
	return counts


## Marks one event read. Returns false when no event has that id, so a caller can tell the
## difference between "already read" and "no such entry".
func mark_read(event_id: String) -> bool:
	for event: GameEvent in entries:
		if event.id == event_id:
			event.read = true
			return true
	return false


## Marks everything read and returns how many entries changed.
func mark_all_read() -> int:
	var changed := 0
	for event: GameEvent in entries:
		if not event.read:
			event.read = true
			changed += 1
	return changed


func find(event_id: String) -> GameEvent:
	for event: GameEvent in entries:
		if event.id == event_id:
			return event
	return null


## The categories that actually occur, in the fixed order of `GameEvent.CATEGORIES`, so the
## filter row never offers an empty category that would look broken.
func used_categories() -> Array:
	var present := {}
	for event: GameEvent in entries:
		present[event.category] = true
	var out: Array = []
	for name: String in GameEvent.CATEGORIES:
		if present.has(name):
			out.append(name)
	return out


func to_dict() -> Dictionary:
	var list: Array = []
	for event: GameEvent in entries:
		list.append(event.to_dict())
	return {"next_sequence": next_sequence, "entries": list}


## Rebuilds a log. A missing block is the honest migration of a save written before the log
## existed: the campaign simply has no recorded history yet, and an empty log says so.
## Returns a log (never null); problems are appended to `issues` as text.
static func from_dict(data: Variant, issues: Array) -> EventLog:
	var log := EventLog.new()
	if data == null:
		return log
	if not data is Dictionary:
		issues.append("event log is not an object")
		return log
	var source: Dictionary = data
	var sequence: Variant = CanonicalJson.int_value(source.get("next_sequence"))
	if sequence == null or int(sequence) < 1:
		issues.append("event log has no valid sequence number")
	else:
		log.next_sequence = int(sequence)
	var raw_entries: Variant = source.get("entries", [])
	if not raw_entries is Array:
		issues.append("event log entries are not a list")
		return log
	var list: Array = raw_entries
	if list.size() > LOAD_CEILING:
		issues.append("event log holds %d entries, more than the %d this build accepts"
				% [list.size(), LOAD_CEILING])
		return log
	var seen := {}
	for item: Variant in list:
		var parsed := GameEvent.from_dict(item)
		var event: GameEvent = parsed["event"]
		if event == null:
			issues.append(str(parsed["issue"]))
			continue
		if seen.has(event.id):
			issues.append("event log repeats the id %s" % event.id)
			continue
		seen[event.id] = true
		if not str(parsed["issue"]).is_empty():
			log.load_notes.append(str(parsed["issue"]))
		log.entries.append(event)
	# Ids came from a counter that is stored separately; a file damaged just there would make
	# the next recorded event collide with an existing one, so the counter is pushed past the
	# highest id actually present.
	for event: GameEvent in log.entries:
		# The id is text ("evt-000009"), so the suffix is parsed as text rather than handed
		# to the JSON number reader, which refuses strings by design.
		var parts := event.id.split("-")
		if parts.size() != 2 or not parts[1].is_valid_int():
			continue
		var number := parts[1].to_int()
		if number >= log.next_sequence:
			log.next_sequence = number + 1
	while log.entries.size() > MAX_EVENTS:
		log.entries.pop_front()
	return log
