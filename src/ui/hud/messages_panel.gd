class_name MessagesPanel
extends ModalPanel
## The Messages panel (Milestone 10, Task 6): the campaign's own record, newest first.
##
## It reads the event log and shows exactly what is in it. Nothing is generated, summarised
## or reworded: each row is the sentence the system that raised the event wrote, on the date
## it happened, with a line underneath saying who raised it — which is the honest answer to
## "why am I seeing this?".
##
## Reading is a state the panel owns, not the save: opening the panel does not mark anything
## read (a glance is not a read), confirming a message does. "Mark all read" is one press,
## because clearing a badge should never be homework.

signal read_state_changed

## The unread-only choice, readable by a test without reaching into the toggle button.
var unread_only_state := false

var _log: EventLog
var _list: RecordList
var _why: Label
var _unread_toggle: Button
var _mark_all: Button
var _unread_only := false
## The rendered rows for the current refresh; the list owns only what it was given.
var _records: Array = []


func prepare(log: EventLog) -> void:
	_log = log
	build(Strings.t("messages.title"))
	var intro := Label.new()
	intro.name = "Intro"
	intro.text = Strings.t("messages.intro")
	intro.theme_type_variation = &"BodySmall"
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content().add_child(intro)

	_list = RecordList.new()
	_list.name = "List"
	_list.filter_field = "category"
	_list.search_text_key = "text"
	_list.row_activated.connect(_on_row)
	content().add_child(_list)

	_why = Label.new()
	_why.name = "Why"
	_why.theme_type_variation = &"Caption"
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_why.modulate.a = 0.85
	content().add_child(_why)

	var bar := footer()
	_unread_toggle = _ghost_button(Strings.t("messages.unread_only"), "UnreadOnly")
	_unread_toggle.toggle_mode = true
	_unread_toggle.toggled.connect(_on_unread_toggled)
	bar.add_child(_unread_toggle)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_mark_all = _ghost_button(Strings.t("messages.mark_all"), "MarkAll")
	_mark_all.pressed.connect(mark_all_read)
	bar.add_child(_mark_all)
	refresh()


## Re-reads the log. Called when the panel opens and after any read-state change.
func refresh() -> void:
	if _list == null:
		return
	var records: Array = []
	for event: GameEvent in _log.newest_first():
		records.append({
			"id": event.id,
			"text": event.text(),
			"category": event.category,
			"date": event.date_label,
			"origin": event.origin_text(),
			"read": event.read,
			"search": "%s %s %s" % [event.text(), event.date_label, event.origin_text()],
		})
	_records = records
	var shown: Array = records
	if _unread_only:
		shown = []
		for record: Dictionary in records:
			if not bool(record["read"]):
				shown.append(record)
	_list.setup(shown, _render, Callable(), Strings.t("messages.empty"))
	# The chips follow the log: a category nothing has used this campaign is not offered,
	# because an empty filter looks like a fault.
	var filters: Array = []
	for category: String in _log.used_categories():
		filters.append({"id": category, "label": Strings.t("hud.category.%s" % category)})
	_list.set_filters(filters)
	var unread := _log.unread_count()
	_mark_all.disabled = unread == 0
	if unread == 0:
		_why.text = Strings.t("messages.mark_all_done")


func visible_count() -> int:
	return _list.row_count() if _list != null else 0


func _render(record: Variant) -> Control:
	var item: Dictionary = record
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	var headline := Label.new()
	headline.text = str(item["text"])
	headline.theme_type_variation = &"BodySmall" if not bool(item["read"]) else &"Caption"
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(headline)
	var meta := Label.new()
	meta.text = "%s · %s · %s" % [str(item["date"]), str(item["origin"]),
			Strings.t("messages.read") if bool(item["read"]) else Strings.t("messages.unread")]
	meta.theme_type_variation = &"Caption"
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(meta)
	return box


func _search_text(record: Variant) -> String:
	return str((record as Dictionary).get("search", ""))


func _on_row(key: String) -> void:
	var event := _log.find(key)
	if event == null:
		return
	var changed := not event.read
	_log.mark_read(key)
	_why.text = Strings.t("messages.why") + " " + event.origin_text()
	refresh()
	if changed:
		read_state_changed.emit()


## Marks every entry read. Public because the footer button and a keyboard shortcut both call
## it, and because a test should be able to press the promise rather than the button.
func mark_all_read() -> void:
	var changed := _log.mark_all_read()
	refresh()
	_why.text = Strings.t("messages.mark_all_done")
	if changed > 0:
		read_state_changed.emit()


func _on_unread_toggled(pressed: bool) -> void:
	_unread_only = pressed
	unread_only_state = pressed
	refresh()


func focus_target() -> Control:
	return _list.query_field() if _list != null else _mark_all


func _ghost_button(text: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.theme_type_variation = &"GhostButton"
	button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	PressFeedback.attach(button)
	return button
