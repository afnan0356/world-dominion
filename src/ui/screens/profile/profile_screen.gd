class_name ProfileScreen
extends ResponsiveScreen
## The player's profile: who they are, how far they have come, and the twenty avatars.
##
## Everything shown here comes from the profile file and nothing else — no placeholder
## numbers, no invented level, no avatar the player did not choose. A change of display name
## shows its price and the exact balance **before** anything is spent, and a username says
## once, in plain words, that it can only be set one time.
##
## There is no picture-from-a-link and no upload. The help text says so, and explains that
## importing a local picture is PLANNED because it needs a file picker that works on every
## platform.

signal back_requested
signal changed

var profile_store := ProfileStore.new()

var _profile: PlayerProfile
var _gallery: AvatarGallery
var _header_avatar: AvatarGlyph
var _name_field: LineEdit
var _username_field: LineEdit
var _status: Label
var _dialog: PanelContainer
var _dialog_body: VBoxContainer
var _recovery: IntegrityDialog
var _recovery_problems := PackedStringArray()
var _recovery_needed := false

@onready var _content: VBoxContainer = %Content


func _ready() -> void:
	super()
	if _profile == null:
		# The rolling backup is offered, never taken: `allow_backup` is false, so a damaged
		# profile leaves a question on screen instead of silently swapping in another file.
		var loaded := profile_store.load_or_create(Time.get_unix_time_from_system(),
				Time.get_date_string_from_system(true), false)
		_profile = loaded["profile"] as PlayerProfile
		_recovery_problems = loaded["problems"] as PackedStringArray
		_recovery_needed = not _recovery_problems.is_empty() \
				and profile_store.backup_exists()
	if _profile == null:
		_profile = PlayerProfile.create(Time.get_unix_time_from_system(),
				Time.get_date_string_from_system(true))
	_rebuild()


## Tests and the first-run flow hand in a specific profile instead of reading the file.
func use_profile(profile: PlayerProfile) -> void:
	_profile = profile
	if is_node_ready():
		_rebuild()


func current_profile() -> PlayerProfile:
	return _profile


func gallery() -> AvatarGallery:
	return _gallery


func status_text() -> String:
	return "" if _status == null else _status.text


## Saves the profile. Returns the store's result so a caller can report a failure honestly.
func persist() -> Dictionary:
	if _profile == null:
		return {"ok": false, "error": "no profile"}
	return profile_store.save(_profile)


func choose_avatar(index: int) -> Dictionary:
	if _profile == null:
		return {"ok": false, "error": "no profile"}
	_profile.avatar_id = clampi(index, 0, AvatarArt.COUNT - 1)
	if _gallery != null:
		_gallery.set_selected(_profile.avatar_id)
	if _header_avatar != null and is_instance_valid(_header_avatar):
		_header_avatar.index = _profile.avatar_id
	var saved := persist()
	if bool(saved.get("ok", false)):
		_set_status(_text("profile.avatar_title") + ": "
				+ AvatarArt.name_of(_profile.avatar_id))
		changed.emit()
	return saved


## What a name change would cost and what the player has, said before anything happens.
func name_change_offer() -> Dictionary:
	var cost: int = _profile.next_name_change_cost()
	var balance: int = _profile.wallet.balance(GameWallet.Currency.DIAMONDS)
	var text := ""
	if cost == 0:
		text = _text("profile.change_name_cost")
	else:
		text = Strings.t("profile.change_name_price", [cost, balance])
	return {"cost": cost, "balance": balance, "text": text,
			"affordable": cost == 0 or balance >= cost}


## Confirms a rename. Charges through the profile engine's own rule, so a cost can never be
## skipped by the screen.
func confirm_rename(candidate: String) -> Dictionary:
	var result := _profile.set_display_name(candidate)
	if not bool(result["ok"]):
		_set_status(str(result["reason"]))
		return result
	persist()
	var message := _profile.display_name
	_close_dialog()
	_rebuild()
	_set_status(message)
	changed.emit()
	return result


func confirm_username(candidate: String) -> Dictionary:
	var result := _profile.set_username(candidate)
	if not bool(result["ok"]):
		_set_status(str(result["reason"]))
		return result
	persist()
	_rebuild()
	_set_status("@" + _profile.username)
	changed.emit()
	return result


# --- Building -------------------------------------------------------------

func _rebuild() -> void:
	if _content == null or _profile == null:
		return
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_add_identity()
	_add_progress()
	_add_avatar_section()
	_add_name_section()
	_add_username_section()
	_add_planned_lines()
	if _recovery_needed:
		_add_recovery()
	var back := Button.new()
	back.name = "Back"
	back.text = _text("profile.back")
	back.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	back.theme_type_variation = &"GhostButton"
	back.pressed.connect(func() -> void: back_requested.emit())
	_content.add_child(back)
	_status = Label.new()
	_status.name = "Status"
	_status.theme_type_variation = &"Caption"
	_content.add_child(_status)


func _add_identity() -> void:
	var row := HBoxContainer.new()
	row.name = "Identity"
	row.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	_header_avatar = AvatarGlyph.new()
	_header_avatar.name = "HeaderAvatar"
	_header_avatar.index = _profile.avatar_id
	_header_avatar.custom_minimum_size = Vector2(96, 96)
	row.add_child(_header_avatar)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", DesignTokens.SPACE_4)
	column.add_child(_label(_profile.display_name, "ScreenTitleCompact"))
	column.add_child(_label("@" + _profile.username, "Mono"))
	column.add_child(_label(_text("profile.player_id") + ": " + _profile.player_id, "Caption"))
	row.add_child(column)
	_content.add_child(row)


func _add_progress() -> void:
	var level := _profile.level()
	var xp := _profile.xp
	var span := maxi(_profile.xp_for_next_level(), 1)
	var into := _profile.xp_into_level()
	_content.add_child(_label(Strings.t("profile.level", [level]), "FieldLabel"))
	var bar := ProgressBar.new()
	bar.name = "XPBar"
	bar.min_value = 0.0
	bar.max_value = float(span)
	bar.value = float(into)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, DesignTokens.SPACE_8)
	_content.add_child(bar)
	var xp_text := Strings.t("profile.xp", [into, span, level + 1])
	if xp >= Progression.xp_to_reach(Progression.MAX_LEVEL):
		xp_text = Strings.t("profile.max_level", [xp])
	_content.add_child(_label(xp_text, "Caption"))
	_content.add_child(_label(Strings.t("profile.vip", [_profile.vip()])
			if _profile.vip() > 0 else _text("profile.vip_none"), "Mono"))
	_content.add_child(_label(Strings.t("profile.wallet_gold",
			[_profile.wallet.balance(GameWallet.Currency.GOLD_COINS)]), "BodySmall"))
	_content.add_child(_label(Strings.t("profile.wallet_gems",
			[_profile.wallet.balance(GameWallet.Currency.DIAMONDS)]), "BodySmall"))


func _add_avatar_section() -> void:
	_content.add_child(_label(_text("profile.avatar_title"), "FieldLabel"))
	_gallery = AvatarGallery.new()
	_gallery.name = "Gallery"
	_gallery.avatar_chosen.connect(func(index: int) -> void: choose_avatar(index))
	_content.add_child(_gallery)
	_gallery.set_selected(_profile.avatar_id)
	_content.add_child(_paragraph(_text("profile.avatar_help")))


func _add_name_section() -> void:
	var button := Button.new()
	button.name = "ChangeName"
	button.text = _text("profile.change_name")
	button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	button.pressed.connect(_open_rename_dialog)
	_content.add_child(button)
	var offer := name_change_offer()
	var line := _paragraph(str(offer["text"]))
	line.name = "NameOffer"
	_content.add_child(line)


func _add_username_section() -> void:
	if _profile.username_locked:
		var locked := _paragraph(_text("profile.username_once"))
		locked.name = "UsernameLocked"
		_content.add_child(locked)
		return
	_content.add_child(_label(_text("profile.username_label"), "FieldLabel"))
	var warning := _paragraph(_text("first_run.profile.username_warning"))
	warning.name = "UsernameWarning"
	_content.add_child(warning)
	_username_field = LineEdit.new()
	_username_field.name = "UsernameField"
	_username_field.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	_content.add_child(_username_field)
	var set_button := Button.new()
	set_button.name = "SetUsername"
	set_button.text = _text("profile.username_set")
	set_button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	set_button.pressed.connect(func() -> void:
		if _username_field != null:
			confirm_username(_username_field.text.strip_edges()))
	_content.add_child(set_button)


func _add_planned_lines() -> void:
	for key: String in ["profile.avatar_import_planned", "profile.achievements_planned"]:
		var line := _paragraph(_text(key))
		line.name = "Planned"
		_content.add_child(line)


# --- Recovering a damaged profile ----------------------------------------

func _add_recovery() -> void:
	_recovery = IntegrityDialog.new()
	_recovery.name = "IntegrityDialog"
	_recovery.theme_type_variation = &"PanelCard"
	_recovery.chosen.connect(func(choice: String) -> void: resolve_recovery(choice))
	_content.add_child(_recovery)
	_recovery.setup(_recovery_problems, profile_store.backup_exists())


## What the player answered about a profile that could not be read. Nothing here deletes
## or rewrites the damaged file: "use the backup" reads the copy, "continue" keeps the new
## profile it fell back to, and "cancel" leaves the screen without touching either.
func resolve_recovery(choice: String) -> String:
	_recovery_needed = false
	var answer := "cancelled"
	match choice:
		IntegrityDialog.CHOICE_BACKUP:
			var backup := profile_store.read_backup()
			if bool(backup["ok"]):
				_profile = backup["profile"] as PlayerProfile
				answer = "loaded_backup"
			else:
				answer = "backup_failed"
		IntegrityDialog.CHOICE_CONTINUE:
			answer = "continued"
		_:
			_recovery = null
			back_requested.emit()
			return answer
	_recovery = null
	_rebuild()
	if answer == "loaded_backup":
		_set_status(Strings.t("recovery.done_backup"))
	elif answer == "backup_failed":
		_set_status(Strings.t("worlds.backup_unreadable"))
	else:
		_set_status(Strings.t("recovery.done_continue"))
	return answer


func recovery_prompt_open() -> bool:
	return _recovery != null and is_instance_valid(_recovery)


func recovery_problems() -> PackedStringArray:
	return _recovery_problems


# --- The rename dialog ----------------------------------------------------

func _open_rename_dialog() -> void:
	_close_dialog()
	var offer := name_change_offer()
	_dialog = PanelContainer.new()
	_dialog.name = "RenameDialog"
	_dialog.theme_type_variation = &"PanelCard"
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", DesignTokens.SPACE_16)
	margin.add_theme_constant_override("margin_right", DesignTokens.SPACE_16)
	margin.add_theme_constant_override("margin_top", DesignTokens.SPACE_16)
	margin.add_theme_constant_override("margin_bottom", DesignTokens.SPACE_16)
	_dialog.add_child(margin)
	_dialog_body = VBoxContainer.new()
	_dialog_body.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	margin.add_child(_dialog_body)
	_dialog_body.add_child(_paragraph(str(offer["text"])))
	_name_field = LineEdit.new()
	_name_field.name = "NameField"
	_name_field.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	_name_field.text = _profile.display_name
	_dialog_body.add_child(_name_field)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	var confirm := Button.new()
	confirm.name = "ConfirmRename"
	confirm.text = _text("first_run.common.continue")
	confirm.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	confirm.disabled = not bool(offer["affordable"])
	confirm.pressed.connect(func() -> void:
		if _name_field != null:
			confirm_rename(_name_field.text.strip_edges()))
	row.add_child(confirm)
	var cancel := Button.new()
	cancel.name = "CancelRename"
	cancel.text = _text("first_run.common.back")
	cancel.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	cancel.theme_type_variation = &"GhostButton"
	cancel.pressed.connect(_close_dialog)
	row.add_child(cancel)
	_dialog_body.add_child(row)
	_content.add_child(_dialog)
	if _name_field != null:
		_name_field.grab_focus()


func _close_dialog() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


func _set_status(text: String) -> void:
	if _status != null and is_instance_valid(_status):
		_status.text = text


# --- Small helpers --------------------------------------------------------

## The one lookup. Every sentence on this screen comes from the table, including the two
## the first-run flow already owns (the username warning and the shared buttons).
func _text(key: String) -> String:
	return Strings.t(key)


func _label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = StringName(variation)
	return label


func _paragraph(text: String) -> Label:
	var label := _label(text, "Body")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
