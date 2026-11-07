class_name BackupScreen
extends ResponsiveScreen
## Backup and restore (Milestone 08, Task 6), on top of the existing `BackupBundle` engine.
##
## What this screen adds is a face, not a second implementation: the bundle format, the
## checksum, the signature and the restore rules all live in `src/core/profile/backup_bundle.gd`
## and are tested there. Here a player can make a backup, see what is in one, and put it back.
##
## **Where the files are.** Backups go into the game's own `user://backups` folder, which the
## player can reach with any file manager. Choosing an arbitrary folder or file through the
## platform's own file dialog is **PLANNED**: it needs a picker that behaves the same on
## Android, iOS, Windows, macOS and Linux, and that has not been verified on a device. This
## screen says so rather than pretending a file dialog is available.
##
## **What restore never does.** It never writes over a world without the player choosing the
## overwrite, and a file that cannot be read is never deleted or silently replaced: the
## three-choice dialog asks, every time.

signal back_requested
signal restart_requested

const BACKUP_DIR := "user://backups"
const CHOICE_ALL := "all"

var store := SaveStore.new()
var profile_store := ProfileStore.new()
## Tests point this at a scratch folder; in play it is the game's own backup folder.
var backup_directory := BACKUP_DIR

var _list: VBoxContainer
var _status: Label
var _dialog: IntegrityDialog
var _pending_text := ""
var _last_choice := ""


func _ready() -> void:
	super()
	_rebuild()


# --- Creating -------------------------------------------------------------

## Everything worth keeping, in one file: the profile and the exact text of every world.
func create_backup() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(backup_directory))
	var profile: PlayerProfile = profile_store.load_or_create(
			Time.get_unix_time_from_system(), Time.get_date_string_from_system(true))["profile"]
	var worlds := {}
	for slot_id: String in WorldsScreen.SLOTS:
		if store.exists(slot_id):
			worlds[slot_id] = FileAccess.get_file_as_string(store.path_for(slot_id))
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "%s/backup-%s.json" % [backup_directory, stamp]
	var bundle: Dictionary = BackupBundle.build(profile, worlds, stamp,
			Strings.t("backup.default_label"))
	var written: Dictionary = BackupBundle.write_file(bundle, path)
	written["worlds"] = worlds.size()
	_set_status(Strings.t("backup.created", [path]) if bool(written["ok"]) \
			else Strings.t("backup.failed", [str(written.get("error", ""))]))
	if not bool(written["ok"]):
		DiagnosticsLog.error(Strings.t("diagnostics.log_backup_failed"))
	_refresh_list()
	return written


func backup_files() -> PackedStringArray:
	var directory := DirAccess.open(ProjectSettings.globalize_path(backup_directory))
	var files := PackedStringArray()
	if directory == null:
		return files
	for file_name: String in directory.get_files():
		if file_name.ends_with(".json"):
			files.append(backup_directory.path_join(file_name))
	files.sort()
	return files


func inspect_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "problems": PackedStringArray([Strings.t("backup.missing")]),
				"summary": {}, "body": {}}
	return BackupBundle.inspect(FileAccess.get_file_as_string(path))


# --- Restoring ------------------------------------------------------------

## Starts a restore. Returns `{ok, prompt, problems, result}`: `prompt` means the dialog is
## open and the player has to answer before anything is written.
func begin_restore(path: String) -> Dictionary:
	_pending_text = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var inspected := inspect_file(path)
	var problems := PackedStringArray()
	if not bool(inspected["ok"]):
		for problem: Variant in inspected["problems"]:
			problems.append(str(problem))
	elif _has_existing_worlds(inspected):
		problems.append(Strings.t("backup.overwrite_warning"))
	if problems.is_empty():
		return {"ok": true, "prompt": false, "problems": problems,
				"result": _restore(false)}
	_show_dialog(problems, _device_backup_exists())
	return {"ok": false, "prompt": true, "problems": problems, "result": {}}


## Answers the dialog after `begin_restore` asked. Returns what actually happened.
func resolve(choice: String) -> Dictionary:
	_last_choice = choice
	_close_dialog()
	match choice:
		IntegrityDialog.CHOICE_BACKUP:
			# Keep what is on this device and write nothing from the file. This is the
			# choice that loses the least, so it is offered first.
			_set_status(Strings.t("backup.restore_kept"))
			return {"ok": true, "kept": true, "restored": [], "skipped": [],
					"reasons": PackedStringArray()}
		IntegrityDialog.CHOICE_CONTINUE:
			return _restore(true)
		_:
			_set_status(Strings.t("recovery.done_cancel"))
			return {"ok": false, "cancelled": true, "restored": [], "skipped": [],
					"reasons": PackedStringArray()}


func _restore(overwrite_confirmed: bool) -> Dictionary:
	var inspected := BackupBundle.inspect(_pending_text)
	var document := inspected
	var result: Dictionary = BackupBundle.restore(document, store, CHOICE_ALL, [],
			overwrite_confirmed)
	var restored: Array = result.get("restored", [])
	var reasons: PackedStringArray = result.get("reasons", PackedStringArray())
	var text := Strings.t("backup.restored_none")
	if not restored.is_empty():
		text = Strings.t("backup.restored", [", ".join(PackedStringArray(restored))])
	if not reasons.is_empty():
		text += " " + Strings.t("backup.reasons", [" ".join(reasons)])
	_set_status(text)
	_refresh_list()
	return result


func _has_existing_worlds(inspected: Dictionary) -> bool:
	var summary: Dictionary = inspected.get("summary", {})
	for line: Variant in summary.get("worlds", []):
		var slot_id := str((line as Dictionary).get("slot", ""))
		if store.exists(slot_id):
			return true
	return false


func _device_backup_exists() -> bool:
	if profile_store.backup_exists():
		return true
	for slot_id: String in WorldsScreen.SLOTS:
		if store.backup_exists(slot_id):
			return true
	return false


# --- Building -------------------------------------------------------------

func _rebuild() -> void:
	var content: VBoxContainer = %Content
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	content.add_child(_label(Strings.t("backup.title"), "ScreenTitleCompact"))
	content.add_child(_label(Strings.t("backup.help"), "Body"))
	var create := Button.new()
	create.name = "CreateBackup"
	create.text = Strings.t("backup.create")
	create.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	create.pressed.connect(create_backup)
	content.add_child(create)
	content.add_child(_label(Strings.t("backup.folder_note"), "Caption"))
	_list = VBoxContainer.new()
	_list.name = "Backups"
	_list.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	content.add_child(_list)
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
	_refresh_list()


func _refresh_list() -> void:
	if _list == null:
		return
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var files := backup_files()
	if files.is_empty():
		_list.add_child(_label(Strings.t("backup.empty"), "Caption"))
		return
	for path: String in files:
		_list.add_child(_row_for(path))


func _row_for(path: String) -> Button:
	var inspected := inspect_file(path)
	var summary: Dictionary = inspected.get("summary", {})
	var row := Button.new()
	row.name = "Backup_%s" % path.get_file().get_basename()
	row.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var worlds := (summary.get("worlds", []) as Array).size()
	row.text = Strings.t("backup.row", [str(summary.get("created_at", "")),
			str(summary.get("player_name", "")), int(summary.get("level", 0)), worlds])
	if not bool(inspected["ok"]):
		row.text = Strings.t("backup.row_damaged", [path.get_file()])
	row.pressed.connect(func() -> void: begin_restore(path))
	return row


func _show_dialog(problems: PackedStringArray, backup_available: bool) -> void:
	_close_dialog()
	_dialog = IntegrityDialog.new()
	_dialog.name = "IntegrityDialog"
	_dialog.theme_type_variation = &"PanelCard"
	_dialog.chosen.connect(func(choice: String) -> void: resolve(choice))
	%Content.add_child(_dialog)
	_dialog.setup(problems, backup_available)


func _close_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


func dialog_open() -> bool:
	return _dialog != null and is_instance_valid(_dialog)


func dialog() -> IntegrityDialog:
	return _dialog


func last_choice() -> String:
	return _last_choice


func status_text() -> String:
	return "" if _status == null else _status.text


func _set_status(text: String) -> void:
	if _status != null and is_instance_valid(_status):
		_status.text = text


func _label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = StringName(variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
