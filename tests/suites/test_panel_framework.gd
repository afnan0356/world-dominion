extends TestCase
## The reusable panel and list (Milestone 10, Task 3).
##
## These are the pieces every new screen is built from, so they are tested on their own
## terms rather than through a screen: a panel that leaks focus, or a list whose empty state
## is indistinguishable from its no-match state, would be a defect in six places at once.

func _mount(control: Control, size: Vector2 = Vector2(900, 700)) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await tree.process_frame
	await tree.process_frame
	return {"viewport": viewport, "holder": holder}


func _key(keycode: int, shift: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.shift_pressed = shift
	return event


# --- ModalPanel ------------------------------------------------------------

func test_a_panel_has_a_title_a_body_a_footer_and_a_close_button() -> void:
	ModalPanel.clear_stack()
	var panel := ModalPanel.new()
	panel.build(Strings.t("messages.title"))
	var mounted := await _mount(panel)
	check_eq(panel.title_text, Strings.t("messages.title"), "the title is what was asked for")
	check_not_null(panel.find_child("Close", true, false), "it has a close button")
	check_not_null(panel.find_child("Scroll", true, false), "the body scrolls")
	check_not_null(panel.find_child("Footer", true, false), "there is a footer row")
	check_true(panel.content().is_inside_tree(), "content is reachable and attached")
	(mounted["viewport"] as Node).queue_free()


func test_escape_closes_the_topmost_panel_only() -> void:
	ModalPanel.clear_stack()
	var holder := Control.new()
	var mounted := await _mount(holder)
	var first := ModalPanel.new()
	first.build("First")
	first.open(holder)
	var second := ModalPanel.new()
	second.build("Second")
	second.open(holder)
	check_eq(ModalPanel.open_panels().size(), 2, "both panels are open and stacked")
	second._input(_key(KEY_ESCAPE))
	check_false(second.is_open(), "Escape closed the panel on top")
	check_true(first.is_open(), "and left the one underneath alone")
	first._input(_key(KEY_ESCAPE))
	check_false(first.is_open(), "a second Escape closes the next one")
	check_eq(ModalPanel.open_panels().size(), 0, "the stack is empty again")
	(mounted["viewport"] as Node).queue_free()


func test_tab_cycles_inside_the_panel_and_never_leaks_out() -> void:
	ModalPanel.clear_stack()
	var outside := Button.new()
	outside.name = "Outside"
	var holder := Control.new()
	var mounted := await _mount(holder)
	holder.add_child(outside)
	var panel := ModalPanel.new()
	panel.build("Trap")
	panel.add_action("Do the thing", Callable(), false)
	panel.open(holder)
	var controls := panel.focusables()
	check_gte(float(controls.size()), 2.0, "the panel has focusable controls")
	check_false(controls.has(outside), "a control outside the panel is never in the cycle")
	var first: Control = controls[0]
	first.grab_focus()
	for _step in controls.size() + 2:
		panel.cycle_focus(false)
		check_true(controls.has(holder.get_viewport().gui_get_focus_owner()),
				"focus stays inside the panel while tabbing forward")
	panel.cycle_focus(true)
	check_true(controls.has(holder.get_viewport().gui_get_focus_owner()),
			"and while tabbing backwards")
	(mounted["viewport"] as Node).queue_free()


func test_opening_and_closing_restores_focus() -> void:
	ModalPanel.clear_stack()
	var holder := Control.new()
	var mounted := await _mount(holder)
	var origin := Button.new()
	origin.name = "Origin"
	holder.add_child(origin)
	origin.grab_focus()
	var panel := ModalPanel.new()
	panel.build("Restore")
	panel.add_action("Done", Callable(), true)
	panel.open(holder)
	check_true(holder.get_viewport().gui_get_focus_owner() != origin,
			"opening moves focus into the panel")
	panel.close()
	await tree.process_frame
	check_eq(holder.get_viewport().gui_get_focus_owner(), origin,
			"closing gives focus back to where it came from")
	(mounted["viewport"] as Node).queue_free()


func test_tabs_are_announced_and_built_only_when_shown() -> void:
	ModalPanel.clear_stack()
	var holder := Control.new()
	var mounted := await _mount(holder)
	var panel := ModalPanel.new()
	panel.build("Tabs")
	var built: Array = []
	panel.add_tab("one", "One", func() -> void: built.append("one"))
	panel.add_tab("two", "Two", func() -> void: built.append("two"))
	panel.open(holder)
	panel.show_tab("one")
	panel.show_tab("two")
	panel.show_tab("one")
	check_eq(panel.current_tab(), "one", "the panel remembers the visible tab")
	check_eq(built, ["one", "two"],
			"each tab's content is built once, the first time it is shown")
	(mounted["viewport"] as Node).queue_free()


func test_the_body_scrolls_instead_of_pushing_the_footer_off() -> void:
	ModalPanel.clear_stack()
	var holder := Control.new()
	var mounted := await _mount(holder, Vector2(640, 360))
	var panel := ModalPanel.new()
	panel.build("Long")
	for index in 40:
		var line := Label.new()
		line.text = "line %d" % index
		panel.content().add_child(line)
	panel.add_action("Close", Callable(), true)
	panel.custom_minimum_size = Vector2(600, 240)
	panel.open(holder)
	await tree.process_frame
	await tree.process_frame
	var close_button := panel.find_child("Close", true, false) as Control
	check_not_null(close_button, "the close button exists")
	check_lte(close_button.get_global_rect().end.y, 360.0,
			"the footer stays inside a short screen while the body scrolls")
	(mounted["viewport"] as Node).queue_free()


# --- RecordList ------------------------------------------------------------

## Renders one record the way a panel would: a single label per row.
func _render(item: Variant) -> Control:
	var label := Label.new()
	label.text = str((item as Dictionary)["text"])
	return label


func _search_text(item: Variant) -> String:
	return str((item as Dictionary).get("search", ""))


func _records() -> Array:
	return [
		{"id": "1", "text": "Autosaved to slot auto.", "category": "system", "search":
				"Autosaved to slot auto."},
		{"id": "2", "text": "Saved to slot 2.", "category": "system", "search": "Saved slot 2"},
		{"id": "3", "text": "Bangladesh — the campaign begins.", "category": "campaign",
				"search": "Bangladesh campaign begins"},
	]


func test_the_list_searches_filters_and_says_why_it_is_empty() -> void:
	var list := RecordList.new()
	var mounted := await _mount(list)
	list.setup(_records(), _render, _search_text)
	check_eq(list.row_count(), 3, "every record is shown before filtering")
	list.set_filters([{"id": "system", "label": "System"},
			{"id": "campaign", "label": "Campaign"}])
	list.set_query("bangladesh")
	check_eq(list.row_count(), 1, "search narrows to the matching record")
	list.set_query("no such thing")
	check_eq(list.row_count(), 0, "a miss shows no rows")
	var empty := list.find_child("Empty", true, false) as Label
	check_true(empty != null and empty.visible, "the no-match state is visible")
	check_true(empty.text.contains("no such thing"),
			"and it repeats what was typed, so the player can see the cause")
	list.set_query("")
	list.set_filter("campaign")
	check_eq(list.row_count(), 1, "the category filter narrows")
	check_eq(list.visible_items().size(), 1, "the public count agrees with the rows")
	(mounted["viewport"] as Node).queue_free()


func test_an_empty_list_reads_differently_from_an_empty_search() -> void:
	var list := RecordList.new()
	var mounted := await _mount(list)
	list.setup([], func(_item: Variant) -> Control: return Label.new())
	var empty := list.find_child("Empty", true, false) as Label
	check_true(empty.visible, "an empty list shows its empty state")
	var nothing_yet := empty.text
	list.setup(_records(), func(_item: Variant) -> Control: return Label.new())
	list.set_query("zzz")
	check_true(empty.visible, "a search that matches nothing still shows a state")
	check_true(empty.text != nothing_yet,
			"and it is not the same sentence as 'nothing here yet'")
	(mounted["viewport"] as Node).queue_free()


func test_rows_are_focusable_so_a_keyboard_can_reach_them() -> void:
	var list := RecordList.new()
	var mounted := await _mount(list)
	list.setup(_records(), _render)
	var activated: Array = []
	list.row_activated.connect(func(key: String) -> void: activated.append(key))
	var rows := list.find_children("Row*", "Button", true, false)
	check_eq(rows.size(), 3, "one button per record")
	for row: Node in rows:
		check_eq((row as Button).focus_mode, Control.FOCUS_ALL,
				"every row can take keyboard focus")
	(rows[1] as Button).pressed.emit()
	check_eq(activated, ["2"], "pressing a row reports the record it stands for")
	(mounted["viewport"] as Node).queue_free()
