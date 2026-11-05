class_name EventBus
extends RefCounted
## A tiny publish/subscribe bus so systems can talk without importing each other.
##
## The three rules that make it safe to build a simulation on:
##
## 1. **Delivery is queued, never recursive.** `publish()` called while events are
##    being delivered does not run the new handlers immediately: it appends them
##    and the current batch finishes first. A listener therefore can never see a
##    half-updated world caused by its own side effect.
## 2. **Order is defined.** Within one event, listeners run by ascending
##    `priority`, then by the order they subscribed. That is total and repeatable,
##    so a replay of the same actions produces the same sequence of calls.
## 3. **State is not mutated during delivery by the bus itself.** The listener list
##    is copied before delivery, so subscribing or unsubscribing mid-delivery
##    affects the *next* event, not the one in flight.
##
## Delivery is synchronous once the outermost `publish()` drains the queue: by the
## time `publish()` returns, every handler for every queued event has run. Systems
## are expected to change only their own state in a handler and to publish new
## events rather than calling other systems directly.

## Event names used by the simulation. Kept together so a typo is a compile-time
## misspelling rather than a silently ignored event.
const DAY_ADVANCED := "sim.day_advanced"
const MONTH_STARTED := "sim.month_started"
const YEAR_STARTED := "sim.year_started"
const FOCUS_COUNTRY_CHANGED := "ui.focus_country_changed"

const DEFAULT_PRIORITY := 100

## Set true to record every delivered event. Used by tests and by the developer
## overlay diagnostics; off in normal play so nothing grows without bound.
var record_history := false
var history: Array[Dictionary] = []
var history_limit := 200

var _subscriptions: Dictionary = {}
var _queue: Array[Dictionary] = []
var _delivering := false
var _next_id := 1
var _delivered := 0


## Subscribes `handler` to `event_name`. Returns an id for `unsubscribe()`.
## A handler that is not a valid Callable is rejected with an empty id, because a
## silent no-op subscription is worse than a loud failure.
func subscribe(event_name: String, handler: Callable, priority: int = DEFAULT_PRIORITY) -> int:
	if event_name.is_empty() or not handler.is_valid():
		push_error("EventBus: refusing an empty event name or an invalid handler.")
		return 0
	var entries: Array = _subscriptions.get(event_name, [])
	var entry := {"id": _next_id, "handler": handler, "priority": priority, "order": _next_id}
	entries.append(entry)
	# Keep the array sorted so delivery never sorts: priority first, then the
	# subscription order which is already unique.
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["priority"]) == int(b["priority"]):
			return int(a["order"]) < int(b["order"])
		return int(a["priority"]) < int(b["priority"]))
	_subscriptions[event_name] = entries
	_next_id += 1
	return int(entry["id"])


func unsubscribe(event_name: String, subscription_id: int) -> bool:
	if not _subscriptions.has(event_name):
		return false
	var entries: Array = _subscriptions[event_name]
	for index in entries.size():
		if int((entries[index] as Dictionary)["id"]) == subscription_id:
			entries.remove_at(index)
			_subscriptions[event_name] = entries
			return true
	return false


func unsubscribe_all(object: Object) -> int:
	var removed := 0
	for event_name: String in _subscriptions.keys():
		var entries: Array = _subscriptions[event_name]
		var kept: Array = []
		for entry: Dictionary in entries:
			var handler: Callable = entry["handler"]
			if handler.get_object() == object:
				removed += 1
				continue
			kept.append(entry)
		_subscriptions[event_name] = kept
	return removed


func subscriber_count(event_name: String) -> int:
	var entries: Array = _subscriptions.get(event_name, [])
	return entries.size()


func pending_count() -> int:
	return _queue.size()


func delivered_count() -> int:
	return _delivered


## Publishes an event. Returns the number of handlers that ran for it (0 when it
## was queued behind an in-flight batch).
func publish(event_name: String, payload: Dictionary = {}) -> int:
	_queue.append({"name": event_name, "payload": payload.duplicate(true)})
	if _delivering:
		return 0
	_delivering = true
	var ran := 0
	while not _queue.is_empty():
		var event: Dictionary = _queue.pop_front()
		ran += _deliver(event)
	_delivering = false
	return ran


func _deliver(event: Dictionary) -> int:
	var event_name := str(event["name"])
	var payload: Dictionary = event["payload"]
	var entries: Array = (_subscriptions.get(event_name, []) as Array).duplicate()
	_delivered += 1
	if record_history:
		history.append({"name": event_name, "payload": payload.duplicate(true),
				"listeners": entries.size()})
		if history.size() > history_limit:
			history.pop_front()
	var ran := 0
	for entry: Dictionary in entries:
		var handler: Callable = entry["handler"]
		# A handler whose object died is skipped rather than crashing a tick.
		if not handler.is_valid():
			continue
		handler.call(payload)
		ran += 1
	return ran


func clear() -> void:
	_subscriptions.clear()
	_queue.clear()
	history.clear()
	_delivered = 0


