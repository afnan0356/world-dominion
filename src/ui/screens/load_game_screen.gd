extends ResponsiveScreen
## Lists save slots, checks each one, and loads the one the player chooses.
##
## The rule this screen exists to enforce: a slot is never shown as "ready" unless
## it actually loaded. A damaged slot is listed *with its reason*, next to the two
## safe choices the player has — restore the backup, or delete it — rather than
## disappearing or pretending to be empty.
##
## Nothing here loads automatically. Choosing a slot is an explicit action, and
## restoring a backup keeps the damaged file as `<slot>.damaged.json` so nothing
## is thrown away without a trace.

signal back_requested()
signal navigation_requested(screen_id: String, params: Dictionary)

const NAV_ROW := preload("res://src/ui/components/nav_row.tscn")

## Text of a validated file waiting for the player to choose a slot.
var pending_import_text := ""

var _entries: Array = []
var _rows: Dictionary = {}
var _message: Label


func _ready() -> void:
	super()
	var header: AppHeader = %Header
	header.back_pressed.connect(func() -> void: back_requested.emit())
	_message = %Message
	_build_actions()
	refresh()


func _build_actions() -> void:
	var actions: HBoxContainer = %Actions
	var import_button := Button.new()
	import_button.text = "Import a save file…"
	import_button.theme_type_variation = &"GhostButton"
	import_button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	import_button.tooltip_text = "Copy a save file back into a slot. The file is checked first."
	import_button.pressed.connect(_on_import_pressed)
	actions.add_child(import_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var back := Button.new()
	back.text = "Back"
	back.theme_type_variation = &"GhostButton"
	back.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	back.pressed.connect(func() -> void: back_requested.emit())
	actions.add_child(back)


## Rebuilds the list. Called on entry and after any change (load, delete, restore).
func refresh() -> void:
	var content: VBoxContainer = %Content
	for child: Node in content.get_children():
		child.queue_free()
	_rows.clear()
	_entries = Game.slot_entries()
	var any_valid := false
	for entry: Dictionary in _entries:
		content.add_child(_build_slot(entry))
		any_valid = any_valid or bool(entry["valid"])
	if not any_valid:
		_message.text = ("No usable saves yet. Start a new campaign, and an autosave will be "
				+ "written when the in-game month changes.")
	else:
		_message.text = "Saves are stored on this device only. Nothing is uploaded."


func _build_slot(entry: Dictionary) -> PanelContainer:
	var slot := str(entry["slot"])
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelCard"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	panel.add_child(box)
	var summary: Dictionary = entry["summary"]
	var title := "%s — %s" % [str(entry["label"]),
			str(summary.get("player_country_name", "empty"))]
	var caption := _describe(entry)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	var row: NavRow = NAV_ROW.instantiate()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.title_text = title
	row.caption_text = caption
	header.add_child(row)
	header.add_child(_badge(_state_label(entry)))
	box.add_child(header)
	if bool(entry["valid"]) and not str(summary.get("player_country_id", "")).is_empty():
		var marker := Label.new()
		marker.theme_type_variation = &"Caption"
		marker.text = "Country marker: %s" % str(summary.get("player_country_id", ""))
		box.add_child(marker)
	row.disabled = not bool(entry["valid"])
	if bool(entry["valid"]):
		row.pressed.connect(func() -> void: load_slot(slot))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	if bool(entry["valid"]):
		actions.add_child(_button("Load", func() -> void: load_slot(slot)))
		actions.add_child(_button("Export…", func() -> void: export_slot(slot)))
	if bool(entry["has_backup"]):
		actions.add_child(_button("Restore backup",
				func() -> void: restore_backup(slot)))
	if bool(entry["exists"]):
		actions.add_child(_button("Delete", func() -> void: delete_slot(slot)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	box.add_child(actions)
	_rows[slot] = panel
	return panel


## One short word for the card, so a damaged slot is obvious before reading a line.
func _state_label(entry: Dictionary) -> String:
	if not string_is_true(entry, "exists"):
		return "Empty"
	if not bool(entry["valid"]):
		return "Damaged"
	return "Ready"


func _badge(text: String) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.theme_type_variation = &"Badge"
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"BadgeText"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	return badge


func _describe(entry: Dictionary) -> String:
	if not string_is_true(entry, "exists"):
		return "Nothing saved here yet. A campaign saved into this slot will appear here."
	if not bool(entry["valid"]):
		return ("This save could not be read: %s If a backup exists, restoring it keeps "
				+ "the damaged file as a .damaged copy.") % str(entry["player_error"])
	var summary: Dictionary = entry["summary"]
	var playtime := float(summary.get("playtime_seconds", 0.0))
	var minutes := int(playtime / 60.0)
	return "%s · in-game %s · played %d min · saved %s" % [
		str(summary.get("player_country_id", "")),
		str(summary.get("date_label", "")),
		minutes,
		str(summary.get("last_saved_at", "")).replace("T", " ").replace("Z", "")]


## Small helper so a missing key reads as false rather than crashing a slot list.
static func string_is_true(entry: Dictionary, key: String) -> bool:
	return bool(entry.get(key, false))


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"GhostButton"
	button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	button.pressed.connect(action)
	return button


## Loads a slot and opens the game screen. Failure keeps the player here, shows the
## reason, and refreshes the list so a recoverable slot is visibly recoverable.
func load_slot(slot: String) -> Dictionary:
	var result := Game.resume(slot)
	if bool(result["ok"]):
		navigation_requested.emit("game", {"resumed": slot})
		return result
	_message.text = str(result.get("player_error", "That save could not be loaded."))
	refresh()
	return result


func restore_backup(slot: String) -> bool:
	var ok := Game.store.restore_backup(slot)
	_message.text = ("The backup was restored into slot %s. The damaged file was kept as a "
			+ ".damaged copy.") % slot if ok else "There is no backup to restore for this slot."
	refresh()
	return ok


func delete_slot(slot: String) -> bool:
	var ok := Game.store.delete(slot)
	_message.text = "Slot %s was deleted." % slot if ok else "That slot could not be deleted."
	refresh()
	return ok


## Exports a slot to a file the player picks. The dialog needs a window, so on a
## headless build the player is told plainly instead of getting a dead button.
func export_slot(slot: String) -> void:
	if not _dialogs_available():
		_message.text = "File dialogs are not available in this environment."
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.add_filter("*.json", "WORLD DOMINION save")
	dialog.current_file = "world-dominion-slot-%s.json" % slot
	dialog.file_selected.connect(func(path: String) -> void:
		var result := Game.store.export_slot(slot, path)
		_message.text = ("Exported to %s." % path) if bool(result["ok"]) \
				else str(result["player_error"])
		dialog.queue_free())
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)


func _on_import_pressed() -> void:
	if not _dialogs_available():
		_message.text = "File dialogs are not available in this environment."
		return
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.add_filter("*.json", "WORLD DOMINION save")
	dialog.file_selected.connect(func(path: String) -> void:
		var result := Game.store.import_file(path, Game.get_atlas().registry)
		if bool(result["ok"]):
			pending_import_text = str(result["text"])
			_message.text = ("That save is valid: %s, in-game %s. Choose a slot to import it "
					+ "into, or Import to slot 1.") % [
					str(result["summary"].get("player_country_name", "")),
					str(result["summary"].get("date_label", ""))]
			_show_import_choice()
		else:
			_message.text = str(result["player_error"])
		dialog.queue_free())
	dialog.canceled.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)


## Asks which slot to write the validated file into, warning about overwrites.
func _show_import_choice() -> void:
	var actions: HBoxContainer = %Actions
	for child: Node in actions.get_children():
		if child.has_meta("import_choice"):
			child.queue_free()
	for slot: String in SaveStore.SLOT_IDS:
		var button := _button("Into %s" % SaveStore.slot_label(slot),
				func() -> void: _finish_import(slot))
		button.set_meta("import_choice", true)
		actions.add_child(button)


func _finish_import(slot: String) -> void:
	if pending_import_text.is_empty():
		return
	var existing := Game.store.exists(slot)
	var result := Game.store.write_imported_text(slot, pending_import_text)
	if bool(result["ok"]):
		_message.text = ("Imported into %s%s." % [SaveStore.slot_label(slot),
				" (the previous save was kept as a backup)" if existing else ""])
		pending_import_text = ""
	else:
		_message.text = str(result["player_error"])
	refresh()


func _dialogs_available() -> bool:
	return not OS.has_feature("headless") and DisplayServer.get_name() != "headless"


# --- Public state for the tests -------------------------------------------

func slot_row_count() -> int:
	return _rows.size()


func message() -> String:
	return _message.text if _message != null else ""


func entry_for(slot: String) -> Dictionary:
	for entry: Dictionary in _entries:
		if str(entry["slot"]) == slot:
			return entry
	return {}
