class_name FirstRunScreen
extends ResponsiveScreen
## The first-run flow: real loading, the terms, the notification preference, and the profile.
##
## Everything here is a fact about the build rather than a promise: the game is offline, it
## collects nothing, it has no purchases, and it cannot yet send notifications — so the
## notification step records a preference and says plainly that the feature is PLANNED.
##
## The same screen is opened from Settings with `{"review": true}`, in which case it stops
## after the notification preference and offers a way back.

signal navigation_requested(screen_id: String, params: Dictionary)
signal quit_requested
signal finished
signal declined
signal back_requested

const STEPS: PackedStringArray = ["loading", "terms", "notifications", "profile"]
## The terms sections, in reading order, as label/body key pairs.
const TERMS_SECTIONS := [
	["first_run.terms.offline_title", "first_run.terms.offline_body"],
	["first_run.terms.data_title", "first_run.terms.data_body"],
	["first_run.terms.saves_title", "first_run.terms.saves_body"],
	["first_run.terms.purchases_title", "first_run.terms.purchases_body"],
	["first_run.terms.changes_title", "first_run.terms.changes_body"],
]

var store := FirstRunStore.new()
var profile_store := ProfileStore.new()

var _step := "loading"
var _progress := 0.0
var _progress_label: Label
var _review := false
var _profile: PlayerProfile = null
var _name_field: LineEdit
var _username_field: LineEdit
var _problem_label: Label
var _notifications_choice := false

@onready var _content: VBoxContainer = %Content


func _ready() -> void:
	super()
	store.load_from()
	_show_loading()
	call_deferred("_run_loading")


func receive_params(params: Dictionary) -> void:
	_review = bool(params.get("review", false))


# --- Testable state -------------------------------------------------------

func current_step() -> String:
	return _step


func progress_value() -> float:
	return _progress


func review_mode() -> bool:
	return _review


func notifications_choice() -> bool:
	return _notifications_choice


func created_profile() -> PlayerProfile:
	return _profile


func problem_text() -> String:
	return "" if _problem_label == null else _problem_label.text


# --- Loading --------------------------------------------------------------

func _show_loading() -> void:
	_step = "loading"
	_clear()
	var title := _make_label(Strings.t("first_run.loading.title"), "ScreenTitle")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(title)
	var body := _make_label(Strings.t("first_run.loading.body"), "Caption")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(body)
	var bar := ProgressBar.new()
	bar.name = "Progress"
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, DesignTokens.SPACE_8)
	_content.add_child(bar)
	_progress_label = _make_label("", "Mono")
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_progress_label)


## The three things a launch genuinely has to do, each reported as it finishes. There is no
## timed filler here: if the atlas loads in a millisecond the bar jumps, and that is honest.
func _run_loading() -> void:
	_set_progress(0.0, Strings.t("first_run.loading.step", ["Opening the atlas", 1, 3]))
	await get_tree().process_frame
	var atlas := WorldAtlas.load_default()
	var ok := atlas != null and atlas.registry.count() > 0
	_set_progress(0.34, Strings.t("first_run.loading.step", ["Loading flags", 2, 3]))
	await get_tree().process_frame
	FlagImage.crosswalk()
	_set_progress(0.67, Strings.t("first_run.loading.step", ["Reading your settings", 3, 3]))
	await get_tree().process_frame
	store.load_from()
	_set_progress(1.0, Strings.t("first_run.loading.body"))
	await get_tree().process_frame
	if not ok:
		push_warning("FirstRunScreen: the atlas did not load; continuing so the message "
				+ "the player sees is the one from the setup screen.")
	_after_loading()


func _set_progress(value: float, text: String) -> void:
	_progress = clampf(value, 0.0, 1.0)
	if _progress_label != null and is_instance_valid(_progress_label):
		_progress_label.text = text
	var bar := _content.get_node_or_null("Progress") as ProgressBar
	if bar != null:
		bar.value = _progress


func _after_loading() -> void:
	if store.needs_terms() or _review:
		_show_terms()
	else:
		_show_notifications()


# --- Terms ----------------------------------------------------------------

func _show_terms() -> void:
	_step = "terms"
	_clear()
	_add_title(Strings.t("first_run.terms.title"))
	_content.add_child(_make_label(Strings.t("first_run.terms.version",
			[FirstRunStore.TERMS_VERSION, FirstRunStore.TERMS_DATE]), "Mono"))
	_content.add_child(_paragraph(Strings.t("first_run.terms.intro")))
	for pair: Array in TERMS_SECTIONS:
		var heading := _make_label(Strings.t(str(pair[0])), "FieldLabel")
		_content.add_child(heading)
		_content.add_child(_paragraph(Strings.t(str(pair[1]))))
	var buttons := _button_row()
	var accept := _make_button(Strings.t("first_run.terms.accept"), true)
	accept.name = "Accept"
	accept.pressed.connect(accept_terms)
	buttons.add_child(accept)
	if _review:
		var back := _make_button(Strings.t("first_run.common.back"), false)
		back.name = "Back"
		back.pressed.connect(func() -> void: back_requested.emit())
		buttons.add_child(back)
	else:
		var decline := _make_button(Strings.t("first_run.terms.decline"), false)
		decline.name = "Decline"
		decline.pressed.connect(decline_terms)
		buttons.add_child(decline)
	_content.add_child(buttons)


func accept_terms() -> void:
	store.accept_terms(_now())
	store.save_to()
	if _review:
		_show_notifications()
		return
	_show_notifications()


## Declining writes nothing at all: no acceptance is recorded, so the next launch asks
## again. The game then closes through the root's own quit path.
func decline_terms() -> void:
	declined.emit()
	quit_requested.emit()


# --- Notifications --------------------------------------------------------

func _show_notifications() -> void:
	_step = "notifications"
	_clear()
	_add_title(Strings.t("first_run.notifications.title"))
	_content.add_child(_paragraph(Strings.t("first_run.notifications.body")))
	var planned := _paragraph(Strings.t("first_run.notifications.planned"))
	planned.name = "Planned"
	_content.add_child(planned)
	var buttons := _button_row()
	var on := _make_button(Strings.t("first_run.notifications.on"), true)
	on.name = "NotificationsOn"
	on.pressed.connect(func() -> void: choose_notifications(true))
	buttons.add_child(on)
	var off := _make_button(Strings.t("first_run.notifications.off"), false)
	off.name = "NotificationsOff"
	off.pressed.connect(func() -> void: choose_notifications(false))
	buttons.add_child(off)
	_content.add_child(buttons)
	_content.add_child(_paragraph(Strings.t("first_run.notifications.saved")))


func choose_notifications(enabled: bool) -> void:
	_notifications_choice = enabled
	store.set_notifications(enabled, _now())
	store.save_to()
	if _review:
		back_requested.emit()
		return
	_show_profile()


# --- Profile --------------------------------------------------------------

func _show_profile() -> void:
	_step = "profile"
	_clear()
	_add_title(Strings.t("first_run.profile.title"))
	_content.add_child(_paragraph(Strings.t("first_run.profile.body")))

	_content.add_child(_make_label(Strings.t("first_run.profile.name_label"), "FieldLabel"))
	_name_field = LineEdit.new()
	_name_field.name = "DisplayName"
	_name_field.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	_name_field.max_length = PlayerProfile.NAME_MAX
	_content.add_child(_name_field)

	_content.add_child(_make_label(Strings.t("first_run.profile.username_label"),
			"FieldLabel"))
	_username_field = LineEdit.new()
	_username_field.name = "Username"
	_username_field.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	_username_field.max_length = PlayerProfile.USERNAME_MAX
	_content.add_child(_username_field)
	_content.add_child(_paragraph(Strings.t("first_run.profile.username_warning")))

	_content.add_child(_make_label(Strings.t("first_run.profile.avatar_label"), "FieldLabel"))
	# The starting avatar is real: the profile owns it from the moment it is created, and
	# the profile screen is where the other nineteen are chosen.
	var avatar_row := HBoxContainer.new()
	avatar_row.name = "AvatarRow"
	avatar_row.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	var starting_avatar := AvatarGlyph.new()
	starting_avatar.name = "StartingAvatar"
	starting_avatar.index = 0
	starting_avatar.custom_minimum_size = Vector2(56, 56)
	avatar_row.add_child(starting_avatar)
	avatar_row.add_child(_paragraph(Strings.t("first_run.profile.avatar_placeholder")))
	_content.add_child(avatar_row)

	_problem_label = _make_label("", "Caption")
	_problem_label.name = "Problem"
	_problem_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_problem_label)

	var buttons := _button_row()
	var create := _make_button(Strings.t("first_run.profile.create"), true)
	create.name = "CreateProfile"
	create.pressed.connect(create_profile)
	buttons.add_child(create)
	_content.add_child(buttons)


## Validates through the profile engine's own rules, then saves. Returns the same dictionary
## the store's save returns, so a test (and the screen) can tell what happened.
func create_profile() -> Dictionary:
	var name_text := "" if _name_field == null else _name_field.text.strip_edges()
	var username_text := "" if _username_field == null else _username_field.text.strip_edges()
	var candidate := PlayerProfile.create(Time.get_unix_time_from_system(), _today())
	var named := candidate.set_display_name(name_text, false)
	if not bool(named["ok"]):
		_reject(Strings.t("first_run.profile.name_problem", [str(named["reason"])]))
		return {"ok": false, "reason": str(named["reason"])}
	var user := candidate.set_username(username_text)
	if not bool(user["ok"]):
		_reject(Strings.t("first_run.profile.username_problem", [str(user["reason"])]))
		return {"ok": false, "reason": str(user["reason"])}
	_profile = candidate
	var saved := profile_store.save(candidate)
	if not bool(saved.get("ok", false)):
		_reject(str(saved.get("error", "")))
		return {"ok": false, "reason": str(saved.get("error", ""))}
	store.mark_complete(_now())
	store.save_to()
	finish()
	return {"ok": true, "reason": ""}


func finish() -> void:
	_step = "done"
	finished.emit()
	navigation_requested.emit("main_menu", {})


# --- Small builders -------------------------------------------------------

func _clear() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _add_title(text: String) -> void:
	var title := _make_label(text, "ScreenTitle")
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(title)


func _paragraph(text: String) -> Label:
	var label := _make_label(text, "Body")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _make_label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = StringName(variation)
	return label


func _make_button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	button.theme_type_variation = &"PrimaryButton" if primary else &"GhostButton"
	return button


func _button_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	return row


func _reject(reason: String) -> void:
	if _problem_label != null:
		_problem_label.text = reason


func _now() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


func _today() -> String:
	return Time.get_date_string_from_system(true)
