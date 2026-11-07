class_name IntegrityDialog
extends PanelContainer
## The three-choice recovery dialog (Milestone 08, Task 6).
##
## It is shown when a file the game needs is damaged: the profile, a world save, or a bundle
## being restored. It offers exactly three answers and no fourth:
##
##   * **Use the backup** — load the previous copy the game already kept. Enabled only when
##     that copy exists; the button says so when it does not.
##   * **Continue with a warning** — leave every file exactly as it is and carry on. This is
##     the choice that exists so nothing is ever repaired or deleted behind the player's back.
##   * **Cancel** — change nothing and go back.
##
## The dialog never touches a file. It reports the choice and the caller decides what it
## means for its own path, which is the only way the same three answers can be honest for a
## profile, a world and a restore.

signal chosen(choice: String)

const CHOICE_BACKUP := "backup"
const CHOICE_CONTINUE := "continue"
const CHOICE_CANCEL := "cancel"
const CHOICES := [CHOICE_BACKUP, CHOICE_CONTINUE, CHOICE_CANCEL]

var _title_label: Label
var _problems_label: Label
var _backup_button: Button
var _continue_button: Button
var _cancel_button: Button
var _backup_available := false


func _ready() -> void:
	if _title_label != null:
		return
	add_theme_constant_override("separation", DesignTokens.SPACE_8)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", DesignTokens.SPACE_16)
	margin.add_theme_constant_override("margin_right", DesignTokens.SPACE_16)
	margin.add_theme_constant_override("margin_top", DesignTokens.SPACE_16)
	margin.add_theme_constant_override("margin_bottom", DesignTokens.SPACE_16)
	add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	margin.add_child(body)
	_title_label = _label(Strings.t("recovery.title"), "Subheading")
	_title_label.name = "RecoveryTitle"
	body.add_child(_title_label)
	_problems_label = _label("", "BodySmall")
	_problems_label.name = "RecoveryProblems"
	_problems_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_problems_label)
	_backup_button = _action(body, "UseBackup", Strings.t("recovery.backup"),
			Strings.t("recovery.backup_hint"), CHOICE_BACKUP)
	_continue_button = _action(body, "ContinueAnyway", Strings.t("recovery.continue"),
			Strings.t("recovery.continue_hint"), CHOICE_CONTINUE)
	_cancel_button = _action(body, "CancelRecovery", Strings.t("recovery.cancel"),
			Strings.t("recovery.cancel_hint"), CHOICE_CANCEL)


## Fills the dialog. `problems` are the engine's own sentences, shown verbatim.
func setup(problems: PackedStringArray, backup_available: bool) -> void:
	_backup_available = backup_available
	if _problems_label != null:
		_problems_label.text = "\n".join(problems)
	if _backup_button != null:
		_backup_button.disabled = not backup_available
		_backup_button.tooltip_text = Strings.t("recovery.backup_hint") if backup_available \
				else Strings.t("recovery.no_backup")


func backup_available() -> bool:
	return _backup_available


## What the player has to answer with. Used by tests and by the keyboard handler.
func choose(choice: String) -> void:
	if not CHOICES.has(choice):
		return
	if choice == CHOICE_BACKUP and not _backup_available:
		return
	chosen.emit(choice)


func button_for(choice: String) -> Button:
	match choice:
		CHOICE_BACKUP:
			return _backup_button
		CHOICE_CONTINUE:
			return _continue_button
		CHOICE_CANCEL:
			return _cancel_button
	return null


func _action(parent: VBoxContainer, node_name: String, title: String, hint: String,
		choice: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = title
	button.tooltip_text = hint
	button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	button.pressed.connect(func() -> void: choose(choice))
	parent.add_child(button)
	return button


func _label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = StringName(variation)
	return label
