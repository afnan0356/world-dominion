class_name WorldsScreen
extends ResponsiveScreen
## Your worlds (Milestone 08, Task 6): the slots that exist, whether each one can be read,
## and — when one cannot — the three-choice dialog instead of a silent reset.
##
## The rule this screen exists to keep: a damaged world is never deleted, never "repaired"
## and never replaced without the player choosing that. "Continue with a warning" leaves the
## file exactly where it is and says so; "Use the backup" loads the copy the store kept;
## "Cancel" does nothing at all.

signal back_requested
signal navigation_requested(screen_id: String, params: Dictionary)

const SLOTS := ["1", "2", "3", "autosave"]

var store := SaveStore.new()

var _list: VBoxContainer
var _status: Label
var _dialog: IntegrityDialog
var _pending_slot := ""
var _last_choice := ""


func _ready() -> void:
	super()
	_rebuild()


func slots() -> PackedStringArray:
	return PackedStringArray(SLOTS)


## What is in a slot, without changing anything. `allow_backup` is false on purpose: the
## screen must see the damage before deciding whether to use the backup.
func slot_state(slot_id: String) -> Dictionary:
	var state := {"slot": slot_id, "exists": false, "ok": false,
			"problems": PackedStringArray(), "has_backup": store.backup_exists(slot_id),
			"summary": {}}
	if not store.exists(slot_id):
		return state
	state["exists"] = true
	var loaded: Dictionary = store.load_slot(slot_id, null, false)
	state["ok"] = bool(loaded["ok"])
	state["summary"] = loaded["summary"]
	if not bool(loaded["ok"]):
		var problems: PackedStringArray = state["problems"]
		if not str(loaded["player_error"]).is_empty():
			problems.append(str(loaded["player_error"]))
		for error: Variant in loaded["errors"]:
			problems.append(Strings.t("worlds.engine_says", [str(error)]))
		state["problems"] = problems
	return state


## A tap on a world: opens it, or asks what to do about it. Returns what happened, which is
## what the tests assert.
func choose_slot(slot_id: String) -> String:
	var state := slot_state(slot_id)
	if bool(state["exists"]) and not bool(state["ok"]):
		# The player is about to be asked what to do. The diagnostics log keeps the fact and
		# the slot, and nothing about the person.
		DiagnosticsLog.warn(Strings.t("diagnostics.log_world_unreadable", [slot_id]))
	if not bool(state["exists"]):
		_set_status(Strings.t("worlds.empty_slot", [SaveStore.slot_label(slot_id)]))
		return "empty"
	if bool(state["ok"]):
		return open_world(slot_id)
	_pending_slot = slot_id
	_show_dialog(state["problems"], bool(state["has_backup"]))
	return "prompt"


## Answers the dialog. `choice` is one of the dialog's three constants.
func resolve(choice: String) -> String:
	_last_choice = choice
	_close_dialog()
	match choice:
		IntegrityDialog.CHOICE_BACKUP:
			var loaded: Dictionary = store.load_slot(_pending_slot, null, true)
			if bool(loaded["ok"]):
				_set_status(Strings.t("recovery.done_backup"))
				open_world(_pending_slot)
				return "opened_from_backup"
			_set_status(Strings.t("worlds.backup_unreadable"))
			return "backup_failed"
		IntegrityDialog.CHOICE_CONTINUE:
			_set_status(Strings.t("recovery.done_continue"))
			return "continued"
		_:
			_set_status(Strings.t("recovery.done_cancel"))
			return "cancelled"


## Resumes the world and asks the shell for the game screen. The campaign starts through
## `Game`, exactly as the load screen starts one, so there is one way in.
func open_world(slot_id: String) -> String:
	var resumed := Game.resume(slot_id)
	if not bool(resumed["ok"]):
		_set_status(Strings.t("worlds.open_failed", [str(resumed.get("player_error", ""))]))
		return "open_failed"
	_set_status("")
	navigation_requested.emit("game", {"resumed": slot_id})
	return "opened"


func last_choice() -> String:
	return _last_choice


func status_text() -> String:
	return "" if _status == null else _status.text


func dialog_open() -> bool:
	return _dialog != null and is_instance_valid(_dialog)


func dialog() -> IntegrityDialog:
	return _dialog


# --- Building -------------------------------------------------------------

func _rebuild() -> void:
	var content: VBoxContainer = %Content
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	content.add_child(_label(Strings.t("worlds.title"), "ScreenTitleCompact"))
	content.add_child(_label(Strings.t("worlds.help"), "Body"))
	_list = VBoxContainer.new()
	_list.name = "Worlds"
	_list.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	content.add_child(_list)
	for slot_id: String in SLOTS:
		_list.add_child(_row_for(slot_id))
	_status = _label("", "Caption")
	_status.name = "Status"
	content.add_child(_status)
	var back := Button.new()
	back.name = "Back"
	back.text = Strings.t("worlds.back")
	back.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	back.theme_type_variation = &"GhostButton"
	back.pressed.connect(func() -> void: back_requested.emit())
	content.add_child(back)


func _row_for(slot_id: String) -> Button:
	var state := slot_state(slot_id)
	var row := Button.new()
	row.name = "World_%s" % slot_id
	row.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if not bool(state["exists"]):
		row.text = Strings.t("worlds.row_empty", [SaveStore.slot_label(slot_id)])
		row.disabled = true
		return row
	var summary: Dictionary = state["summary"]
	var detail := Strings.t("worlds.row_ok", [SaveStore.slot_label(slot_id),
			str(summary.get("player_country_name", "")), str(summary.get("date_label", ""))])
	if not bool(state["ok"]):
		detail = Strings.t("worlds.row_damaged", [SaveStore.slot_label(slot_id)])
	row.text = detail
	if bool(state["has_backup"]):
		row.tooltip_text = Strings.t("recovery.backup_hint")
	row.pressed.connect(func() -> void: choose_slot(slot_id))
	return row


func _show_dialog(problems: PackedStringArray, backup_available: bool) -> void:
	_close_dialog()
	_dialog = IntegrityDialog.new()
	_dialog.name = "IntegrityDialog"
	_dialog.theme_type_variation = &"PanelCard"
	_dialog.chosen.connect(func(choice: String) -> void: resolve(choice))
	%Content.add_child(_dialog)
	_dialog.setup(problems, backup_available)
	var cancel := _dialog.button_for(IntegrityDialog.CHOICE_CANCEL)
	if cancel != null:
		cancel.grab_focus()


func _close_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


func _set_status(text: String) -> void:
	if _status != null and is_instance_valid(_status):
		_status.text = text


func _label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = StringName(variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
