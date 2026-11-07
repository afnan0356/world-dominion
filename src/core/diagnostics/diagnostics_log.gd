class_name DiagnosticsLog
extends RefCounted
## The last 50 warnings and errors the game itself reported (Milestone 09, Task 4).
##
## What this is: a ring buffer, in memory only, that the game writes to when something it can
## actually observe goes wrong — a settings file the device refused, a save that failed its
## checks, a backup that could not be read, an export that could not be written. The
## diagnostics screen shows it; the diagnostics export includes it.
##
## What this is **not**: a copy of the engine's own stderr. Godot 4.6 does not give a script a
## supported way to read the log stream it already printed, so engine-level warnings are not in
## this buffer. That limitation is stated on the screen, in `docs/WALKTHROUGH.md` and in the
## diagnostics export itself rather than being papered over.
##
## Nothing here is written to disk, sent anywhere, or kept after the game closes. The buffer
## holds plain sentences the game wrote; it never receives a player name, a player ID, an
## avatar or a file path, and the export scrubs paths anyway as a second line of defence.

const LIMIT := 50
const LEVEL_WARNING := "WARN"
const LEVEL_ERROR := "ERROR"

## Newest last. A plain array of dictionaries is enough at this size.
static var _entries: Array[Dictionary] = []
## Monotonic number, so a line can be referred to without a wall clock (and without a
## timestamp that says anything about the player's device).
static var _sequence := 0


static func warn(message: String) -> void:
	note(LEVEL_WARNING, message)


static func error(message: String) -> void:
	note(LEVEL_ERROR, message)


static func note(level: String, message: String) -> void:
	var text := message.strip_edges()
	if text.is_empty():
		return
	_sequence += 1
	_entries.append({"sequence": _sequence, "level": level, "text": text})
	while _entries.size() > LIMIT:
		_entries.pop_front()


## Oldest first, newest last. Copies the dictionaries so a caller cannot edit the buffer.
static func entries() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		copy.append(entry.duplicate())
	return copy


## The buffer as plain lines, `LEVEL  text`, oldest first.
static func text() -> String:
	var lines := PackedStringArray()
	for entry: Dictionary in _entries:
		lines.append("%s  %s" % [entry["level"], entry["text"]])
	return "\n".join(lines)


static func count() -> int:
	return _entries.size()


static func clear() -> void:
	_entries.clear()
	_sequence = 0
