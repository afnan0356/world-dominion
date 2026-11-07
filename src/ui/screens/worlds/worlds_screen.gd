class_name WorldsScreen
extends ResponsiveScreen
## Your worlds (Milestone 08, Task 6): the slots that exist, whether each one can be read,
## and — when one cannot — the three-choice dialog instead of a silent reset.
##
## The rule this screen exists to keep: a damaged world is never deleted, never "repaired"
## and never replaced without the player choosing that. "Continue with a warning" leaves the
## file exactly where it is and says so; "Use the backup" loads the copy the store kept;
## "Cancel" does nothing at all.
##
## Deleting is the second half of that rule (Milestone 09, Task 6). A row's **Delete** button
## opens a confirmation that names the world — slot, country, in-game date and how long it was
## played — and says whether a recovery copy can be made. Confirming makes the copy first, then
## deletes; the status line offers **Undo** for the rest of the session. Where no copy can be
## made, the confirmation says the deletion is permanent before the player agrees to it. The
## profile is a different file, in a different store, and nothing on this screen touches it.

signal back_requested
signal navigation_requested(screen_id: String, params: Dictionary)

const SLOTS := ["1", "2", "3", "autosave"]

var store := SaveStore.new()

var _list: VBoxContainer
var _status: Label
var _dialog: IntegrityDialog
var _pending_slot := ""
var _last_choice := ""
var _deletion: WorldDeletion
## The world whose deletion is currently being confirmed, and the world a status message is
## about (so Undo knows what it would restore).
var _confirming := ""
## True when the open confirmation told the player the deletion would be permanent. Confirm
## then passes that consent to the engine, and nothing else does.
var _confirm_permanent := false
var _undo_target := ""
var _undo_button: Button
var _rows: Dictionary = {}


func _ready() -> void:
	super()
	_deletion = WorldDeletion.new(store)
	# Anything left from a previous run is forgotten: the promise is one session, not forever.
	_deletion.begin_session()
	_rebuild()


## The world rows gained a Delete button, so the column must be able to shrink with the
## window instead of keeping its 560 px preferred width and clipping the button on a 640 px
## screen. The preferred width stays 560 for wide layouts.
func on_layout_changed(_mode: int, _is_short: bool, view_size: Vector2) -> void:
	var content := get_node_or_null("%Content") as Control
	if content == null:
		return
	var margin := DesignTokens.screen_margin(DesignTokens.layout_mode(view_size))
	content.custom_minimum_size.x = clampf(view_size.x - float(margin * 2) - DesignTokens.SPACE_24,
			240.0, 560.0)


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


# --- Deleting a world ------------------------------------------------------

## Opens the confirmation for a world. Returns what it describes, so a caller (or a test) can
## check the name, country and playtime without reading the screen's labels.
func ask_delete(slot_id: String) -> Dictionary:
	var description := _deletion.describe(slot_id)
	_confirming = slot_id
	_confirm_permanent = not _deletion.copy_possible(slot_id)
	for other: String in _rows:
		var panel := _confirm_panel_for(other)
		if panel != null:
			panel.visible = other == slot_id
	_undo_target = ""
	_update_undo_button()
	return description


## The engine behind this screen's delete buttons. Exposed for tests and for diagnostics: a
## test sets `inject_copy_failure` to exercise the permanent-deletion path a read-only device
## would produce.
func deletion_engine() -> WorldDeletion:
	return _deletion


## What the confirmation for `slot_id` says, without showing it.
func delete_description(slot_id: String) -> Dictionary:
	return _deletion.describe(slot_id)


func confirming_slot() -> String:
	return _confirming


## Confirms the pending deletion. Returns "deleted" (recoverable), "deleted_permanent",
## "cancelled" when nothing was pending, or "failed". A deletion is only allowed to proceed
## without a recovery copy when the confirmation the player read said it would be permanent.
func confirm_delete(slot_id: String = "") -> String:
	var slot := slot_id if not slot_id.is_empty() else _confirming
	if slot.is_empty():
		return "cancelled"
	var result := _deletion.delete(slot, _confirm_permanent)
	var description: Dictionary = result["description"]
	var label := str(description["label"])
	if not bool(result["ok"]):
		_set_status(Strings.t("worlds.delete_failed", [str(result["error"])]))
		_confirming = ""
		_rebuild()
		return "failed"
	_confirming = ""
	if bool(result["undo_available"]):
		_undo_target = slot
		_set_status(Strings.t("worlds.deleted", [label]))
	else:
		_undo_target = ""
		_set_status(Strings.t("worlds.deleted_permanent", [label]))
	DiagnosticsLog.warn(Strings.t("diagnostics.log_world_deleted", [label]))
	_rebuild()
	return "deleted" if bool(result["undo_available"]) else "deleted_permanent"


## Closes the confirmation without deleting anything.
func cancel_delete() -> void:
	_confirming = ""
	_confirm_permanent = false
	_rebuild()


## Puts back the world deleted earlier this session, if its recovery copy is still there.
func undo_delete() -> bool:
	if _undo_target.is_empty():
		return false
	var label := SaveStore.slot_label(_undo_target)
	var restored := _deletion.undo(_undo_target)
	if restored:
		_deletion.forget(_undo_target)
		_set_status(Strings.t("worlds.undone", [label]))
		_undo_target = ""
	else:
		_set_status(Strings.t("worlds.undo_failed"))
	_rebuild()
	return restored


func can_undo() -> bool:
	return not _undo_target.is_empty()


# --- Building -------------------------------------------------------------

func _rebuild() -> void:
	# The status line is rebuilt with everything else, so the message it was showing is carried
	# across: "Deleted … you can undo this" must not vanish because the list refreshed.
	var previous_status := status_text()
	var content: VBoxContainer = %Content
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	_rows.clear()
	_undo_button = null
	content.add_child(_label(Strings.t("worlds.title"), "ScreenTitleCompact"))
	content.add_child(_label(Strings.t("worlds.help"), "Body"))
	_list = VBoxContainer.new()
	_list.name = "Worlds"
	_list.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	content.add_child(_list)
	for slot_id: String in SLOTS:
		_list.add_child(_row_for(slot_id))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	_status = _label("", "Caption")
	_status.name = "Status"
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_child(_status)
	_undo_button = Button.new()
	_undo_button.name = "UndoDelete"
	_undo_button.text = Strings.t("worlds.undo")
	_undo_button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	_undo_button.pressed.connect(func() -> void: undo_delete())
	footer.add_child(_undo_button)
	content.add_child(footer)
	if not previous_status.is_empty():
		_status.text = previous_status
	_update_undo_button()
	var back := Button.new()
	back.name = "Back"
	back.text = Strings.t("worlds.back")
	back.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	back.theme_type_variation = &"GhostButton"
	back.pressed.connect(func() -> void: back_requested.emit())
	content.add_child(back)


func _row_for(slot_id: String) -> Control:
	var state := slot_state(slot_id)
	var holder := VBoxContainer.new()
	holder.name = "Row_%s" % slot_id
	holder.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	_rows[slot_id] = holder
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	holder.add_child(line)
	var row := Button.new()
	row.name = "World_%s" % slot_id
	row.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not bool(state["exists"]):
		row.text = Strings.t("worlds.row_empty", [SaveStore.slot_label(slot_id)])
		row.disabled = true
		line.add_child(row)
		return holder
	var summary: Dictionary = state["summary"]
	var detail := Strings.t("worlds.row_ok", [SaveStore.slot_label(slot_id),
			str(summary.get("player_country_name", "")), str(summary.get("date_label", ""))])
	if not bool(state["ok"]):
		detail = Strings.t("worlds.row_damaged", [SaveStore.slot_label(slot_id)])
	row.text = detail
	if bool(state["has_backup"]):
		row.tooltip_text = Strings.t("recovery.backup_hint")
	row.pressed.connect(func() -> void: choose_slot(slot_id))
	line.add_child(row)
	var delete_button := Button.new()
	delete_button.name = "Delete_%s" % slot_id
	delete_button.text = Strings.t("worlds.delete")
	delete_button.theme_type_variation = &"DangerButton"
	delete_button.custom_minimum_size = Vector2(96, DesignTokens.CONTROL_HEIGHT)
	delete_button.pressed.connect(func() -> void: ask_delete(slot_id))
	line.add_child(delete_button)
	holder.add_child(_confirmation_card(slot_id))
	return holder


## The two-step confirmation, built once per row and hidden until Delete is pressed. It names
## the world rather than asking "are you sure?" about nothing.
func _confirmation_card(slot_id: String) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Confirm_%s" % slot_id
	panel.theme_type_variation = &"PanelCard"
	panel.visible = false
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	panel.add_child(body)
	var description := _deletion.describe(slot_id)
	var title := _label(Strings.t("worlds.delete_title",
			[str(description["label"])]), "FieldLabel")
	body.add_child(title)
	var detail := ""
	if str(description["country"]).is_empty():
		detail = Strings.t("worlds.delete_unreadable")
	else:
		detail = Strings.t("worlds.delete_detail", [str(description["country"]),
				str(description["date"]), str(description["playtime_label"])])
	body.add_child(_label(detail, "Body"))
	# Whether the copy can be made is decided here, before the player agrees, not after.
	var reversible := not _confirm_permanent if slot_id == _confirming \
			else _deletion.copy_possible(slot_id)
	body.add_child(_label(Strings.t("worlds.delete_keep_copy" if reversible
			else "worlds.delete_permanent"), "Caption"))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	var confirm := Button.new()
	confirm.name = "ConfirmDelete_%s" % slot_id
	confirm.text = Strings.t("worlds.delete_confirm")
	confirm.theme_type_variation = &"DangerButton"
	confirm.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	confirm.pressed.connect(func() -> void: confirm_delete(slot_id))
	actions.add_child(confirm)
	var keep := Button.new()
	keep.name = "CancelDelete_%s" % slot_id
	keep.text = Strings.t("worlds.delete_cancel")
	keep.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	keep.pressed.connect(cancel_delete)
	actions.add_child(keep)
	body.add_child(actions)
	return panel


func _confirm_panel_for(slot_id: String) -> Control:
	var holder: Control = _rows.get(slot_id)
	if holder == null:
		return null
	return holder.get_node_or_null("Confirm_%s" % slot_id) as Control


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


## Undo is offered only while there is a recovery copy to restore, so the button cannot be
## pressed into nothing.
func _update_undo_button() -> void:
	if _undo_button == null or not is_instance_valid(_undo_button):
		return
	_undo_button.visible = _deletion != null and not _undo_target.is_empty() \
			and _deletion.undo_available(_undo_target)


func _set_status(text: String) -> void:
	if _status != null and is_instance_valid(_status):
		_status.text = text


func _label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = StringName(variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
