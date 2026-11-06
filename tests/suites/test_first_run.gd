extends TestCase
## The first-run flow (Milestone 08, Task 2): terms, the notification preference, and profile
## creation — plus the rule that declining changes nothing.

const SCENE := "res://src/ui/screens/first_run/first_run_screen.tscn"
const TEMP := "user://test_first_run.json"
const SIZES := {
	"640x360": Vector2(640, 360),
	"1280x720": Vector2(1280, 720),
	"1920x1080": Vector2(1920, 1080),
}


func _clean() -> void:
	FirstRunStore.remove_file(TEMP)
	FirstRunStore.remove_file()


func _fresh_store() -> FirstRunStore:
	var store := FirstRunStore.new()
	store.load_from(TEMP)
	return store


func test_a_first_launch_asks_for_the_terms() -> void:
	_clean()
	var store := _fresh_store()
	check_true(store.needs_terms(), "with no file, the terms are needed")
	check_true(store.needs_first_run(), "and the flow has not been completed")
	check_eq(FirstRunStore.decide_start(TEMP), FirstRunStore.START_FIRST_RUN,
			"so the application opens the first-run screen")


func test_a_repeat_launch_goes_straight_to_the_menu() -> void:
	_clean()
	var store := _fresh_store()
	store.accept_terms("2026-11-06T10:00:00Z")
	store.mark_complete("2026-11-06T10:00:00Z")
	check_true(store.save_to(TEMP), "the file is written")
	check_eq(FirstRunStore.decide_start(TEMP), FirstRunStore.START_MAIN_MENU,
			"an accepted, completed first run opens the menu")
	check_false(_fresh_store().needs_terms(), "and the terms are not asked again")
	_clean()


func test_a_new_terms_version_asks_again() -> void:
	_clean()
	var store := _fresh_store()
	store.accept_terms("2026-11-06T10:00:00Z")
	store.mark_complete("2026-11-06T10:00:00Z")
	store.save_to(TEMP)
	# Rewrite the stored version as an older one, which is what a terms bump looks like.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEMP))
	data["terms_version"] = FirstRunStore.TERMS_VERSION - 1
	var file := FileAccess.open(TEMP, FileAccess.WRITE)
	file.store_string(CanonicalJson.stringify(data))
	file.close()
	var reloaded := _fresh_store()
	check_true(reloaded.needs_terms(), "an old accepted version does not count")
	check_eq(FirstRunStore.decide_start(TEMP), FirstRunStore.START_FIRST_RUN,
			"so the terms are shown again")
	check_eq(reloaded.notifications, bool(data.get("notifications", false)),
			"while the rest of the file is still read")
	_clean()


func test_the_whole_flow_from_terms_to_the_menu() -> void:
	_clean()
	var mounted := await _mount(SIZES["1280x720"])
	var screen: FirstRunScreen = mounted["screen"]
	await _settle()
	check_eq(screen.current_step(), "terms", "the flow opens on the terms")
	check_gte(screen.progress_value(), 1.0, "after the loading work actually finished")
	screen.accept_terms()
	check_eq(screen.current_step(), "notifications", "accepting moves to notifications")
	screen.choose_notifications(true)
	check_eq(screen.current_step(), "profile", "and then to the profile")
	check_true(_fresh_store().notifications, "the preference is recorded")
	var created: Dictionary = await _create_profile(screen, "Test Player", "test_player")
	check_true(bool(created["ok"]), "the profile is created: %s" % str(created["reason"]))
	check_not_null(screen.created_profile(), "and the screen holds it")
	check_true(_fresh_store().completed, "the flow is marked complete")
	check_eq(FirstRunStore.decide_start(), FirstRunStore.START_MAIN_MENU,
			"so the next launch opens the menu")
	(mounted["viewport"] as Node).queue_free()
	_clean()


func test_declining_records_nothing_and_quits() -> void:
	_clean()
	var mounted := await _mount(SIZES["1280x720"])
	var screen: FirstRunScreen = mounted["screen"]
	await _settle()
	var declined := [false]
	var quit := [false]
	screen.declined.connect(func() -> void: declined[0] = true)
	screen.quit_requested.connect(func() -> void: quit[0] = true)
	screen.decline_terms()
	check_true(declined[0], "declining is reported")
	check_true(quit[0], "and asks the application to close")
	check_false(FileAccess.file_exists(FirstRunStore.PATH), "nothing was written")
	check_true(_fresh_store().needs_terms(), "so the next launch asks again")
	(mounted["viewport"] as Node).queue_free()
	_clean()


func test_the_profile_step_refuses_bad_names_with_a_reason() -> void:
	_clean()
	var mounted := await _mount(SIZES["1280x720"])
	var screen: FirstRunScreen = mounted["screen"]
	await _settle()
	screen.accept_terms()
	screen.choose_notifications(false)
	check_eq(screen.current_step(), "profile", "we are on the profile step")
	var empty: Dictionary = await _create_profile(screen, "", "test_player")
	check_false(bool(empty["ok"]), "an empty display name is refused")
	check_false(str(empty["reason"]).is_empty(), "with a reason")
	check_false(screen.problem_text().is_empty(), "which the screen shows")
	var bad_user: Dictionary = await _create_profile(screen, "Test Player", "no spaces")
	check_false(bool(bad_user["ok"]), "an invalid username is refused")
	check_false(str(bad_user["reason"]).is_empty(), "with a reason too")
	(mounted["viewport"] as Node).queue_free()
	_clean()


func test_the_notification_step_promises_nothing_it_cannot_do() -> void:
	var planned := Strings.t("first_run.notifications.planned")
	check_true(planned.contains("PLANNED"), "the step says notifications are planned")
	var body := Strings.t("first_run.notifications.body")
	check_true(body.to_lower().contains("preference"), "and that it is a preference")
	var source := FileAccess.get_file_as_string("res://src/ui/screens/first_run/" \
			+ "first_run_screen.gd")
	check_false(source.contains("NotificationServer"),
			"there is no notification code in the screen")
	check_false(source.contains("OS.request_permission"),
			"and no OS permission is requested")


func test_the_flow_fits_every_size_in_both_themes() -> void:
	var original := Settings.get_theme_id()
	var worst := ""
	for theme_id: String in ["midnight", "parchment"]:
		Settings.set_theme_id(theme_id)
		await tree.process_frame
		for label: String in SIZES:
			_clean()
			var mounted := await _mount(SIZES[label])
			var screen: FirstRunScreen = mounted["screen"]
			await _settle()
			var content: Control = screen.get_node("%Content") as Control
			var viewport: SubViewport = mounted["viewport"]
			if content.size.x > viewport.size.x + 1.0 and worst.is_empty():
				worst = "%s/%s: content %s wider than %s" % [theme_id, label,
						str(content.size), str(viewport.size)]
			for button: Node in _buttons(screen):
				var control := button as Control
				if control.size.y + 0.5 < DesignTokens.CONTROL_HEIGHT and worst.is_empty():
					worst = "%s/%s: %s is %s high" % [theme_id, label, control.name,
							str(control.size.y)]
			(mounted["viewport"] as Node).queue_free()
	check_eq(worst, "", "the flow fits every size in both themes")
	Settings.set_theme_id(original)
	_clean()


func test_keyboard_only_can_complete_the_flow() -> void:
	_clean()
	var mounted := await _mount(SIZES["1280x720"])
	var screen: FirstRunScreen = mounted["screen"]
	await _settle()
	var accept := screen.find_child("Accept", true, false) as Button
	check_not_null(accept, "the terms offer an accept button")
	if accept != null:
		check_eq(accept.focus_mode, Control.FOCUS_ALL, "which keyboard focus can reach")
		accept.grab_focus()
		check_true(accept.has_focus(), "and focusing it works")
		accept.pressed.emit()
		check_eq(screen.current_step(), "notifications", "so Enter-style activation works")
	var on := screen.find_child("NotificationsOn", true, false) as Button
	check_not_null(on, "the preference offers a choice with focus")
	screen.choose_notifications(false)
	var create := screen.find_child("CreateProfile", true, false) as Button
	check_not_null(create, "and the profile step can be completed from the keyboard")
	(mounted["viewport"] as Node).queue_free()
	_clean()


# --- helpers --------------------------------------------------------------

func _mount(size: Vector2) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: Control = load(SCENE).instantiate()
	holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return {"viewport": viewport, "screen": screen, "holder": holder}


func _settle() -> void:
	for _frame in 6:
		await tree.process_frame


func _create_profile(screen: FirstRunScreen, display_name: String,
		username: String) -> Dictionary:
	var name_field := screen.find_child("DisplayName", true, false) as LineEdit
	var user_field := screen.find_child("Username", true, false) as LineEdit
	if name_field == null or user_field == null:
		return {"ok": false, "reason": "the fields are missing"}
	name_field.text = display_name
	user_field.text = username
	return screen.create_profile()


func _buttons(node: Node) -> Array:
	var out: Array = []
	for child: Node in node.get_children():
		if child is Button:
			out.append(child)
		out.append_array(_buttons(child))
	return out
