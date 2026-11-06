class_name FirstRunStore
extends RefCounted
## Remembers what the first-run flow has been told: which terms version was accepted, the
## notification preference, and whether the flow has been completed once.
##
## This is a small plain file (`user://first_run.json`), separate from the profile on purpose:
## the terms have to be shown and accepted *before* a profile exists. It holds no personal
## information — three numbers and two timestamps — and it is never uploaded anywhere.

const PATH := "user://first_run.json"
const SCHEMA_VERSION := 1
## Bump this whenever the terms text changes in a way a player should see. The flow shows
## the terms again when the stored version is not this one.
const TERMS_VERSION := 1
const TERMS_DATE := "2026-11-06"

const START_FIRST_RUN := "first_run"
const START_MAIN_MENU := "main_menu"

var terms_version := 0
var terms_accepted := false
var terms_accepted_at := ""
var notifications := false
var completed := false
var updated_at := ""
var problems := PackedStringArray()


## Reads the file. A missing file is not a problem: it means this is a first launch.
func load_from(path: String = PATH) -> void:
	problems.clear()
	if not FileAccess.file_exists(path):
		return
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		problems.append("the first-run file was empty")
		return
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		problems.append("the first-run file was not readable")
		return
	var data: Dictionary = parsed
	var schema: Variant = CanonicalJson.int_value(data.get("schema_version"))
	if schema == null or int(schema) != SCHEMA_VERSION:
		problems.append("the first-run file has an unknown version")
		return
	var stored_version: Variant = CanonicalJson.int_value(data.get("terms_version"))
	terms_version = int(stored_version) if stored_version != null else 0
	terms_accepted = bool(data.get("terms_accepted", false))
	terms_accepted_at = str(data.get("terms_accepted_at", ""))
	notifications = bool(data.get("notifications", false))
	completed = bool(data.get("completed", false))
	updated_at = str(data.get("updated_at", ""))


func save_to(path: String = PATH) -> bool:
	var data := {
		"schema_version": SCHEMA_VERSION,
		"terms_version": terms_version,
		"terms_accepted": terms_accepted,
		"terms_accepted_at": terms_accepted_at,
		"notifications": notifications,
		"completed": completed,
		"updated_at": updated_at,
	}
	var text := CanonicalJson.stringify(data)
	if text.is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		problems.append("the first-run file could not be written")
		return false
	file.store_string(text)
	file.close()
	return true


## True when the player has not accepted *this* version of the terms.
func needs_terms() -> bool:
	return not terms_accepted or terms_version != TERMS_VERSION


func needs_first_run() -> bool:
	return not completed or needs_terms()


func accept_terms(now: String) -> void:
	terms_version = TERMS_VERSION
	terms_accepted = true
	terms_accepted_at = now
	updated_at = now


func set_notifications(enabled: bool, now: String = "") -> void:
	notifications = enabled
	if not now.is_empty():
		updated_at = now


func mark_complete(now: String) -> void:
	completed = true
	updated_at = now


## Which screen the application should open with. Kept here so the rule is testable without
## building the application: terms first, then the menu.
static func decide_start(path: String = PATH) -> String:
	var store := FirstRunStore.new()
	store.load_from(path)
	if store.needs_first_run():
		return START_FIRST_RUN
	return START_MAIN_MENU


static func remove_file(path: String = PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
