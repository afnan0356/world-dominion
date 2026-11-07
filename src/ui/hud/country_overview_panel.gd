class_name CountryOverviewPanel
extends ModalPanel
## The Country panel (Milestone 10, Task 7): everything the game really knows about one
## country, in two tabs.
##
## **Overview** is the existing dossier — the same `CountryInfoPanel` the side panel and the
## atlas use, so there is exactly one implementation of "what do we know about this country".
## That panel already states every gap as "Not available", shows the sourced year of each
## figure, counts how many figures exist rather than scoring them, repeats the dataset's own
## neutral wording for disputed and dependent units, and carries the "Compare with…" shortcut.
## This file adds no second opinion about any of that.
##
## **History** lists the campaign's own events that name this country. It is not a narrative:
## it is the same records the Messages panel shows, filtered by the country's name, and it
## says plainly when there are none.

signal compare_requested(country_id: String)

var country_id := ""
var _record: CountryRecord
var _context: Dictionary = {}
var _events: EventLog
var _dossier: CountryInfoPanel


func prepare(record: CountryRecord, context: Dictionary, events: EventLog) -> void:
	_record = record
	_context = context.duplicate()
	_events = events
	country_id = record.id if record != null else ""
	build(Strings.t("overview.title"))
	add_tab("overview", Strings.t("overview.tab_overview"))
	add_tab("history", Strings.t("overview.tab_history"))
	add_action(Strings.t("overview.compare"), _emit_compare, false)
	show_tab("overview")


func show_tab(tab_id: String) -> void:
	super.show_tab(tab_id)
	_clear_content()
	if tab_id == "history":
		_fill_history()
	else:
		_fill_overview()


## The dossier inside the Overview tab, or null while the History tab is showing. A test
## reads it to prove the panel reuses the real dossier rather than a copy of it.
func dossier_panel() -> CountryInfoPanel:
	return _dossier


func history_count() -> int:
	var count := 0
	for child: Node in content().get_children():
		if child.name.begins_with("Event_"):
			count += 1
	return count


func _fill_overview() -> void:
	_dossier = CountryInfoPanel.new()
	_dossier.name = "Dossier"
	_dossier.compare_requested.connect(_emit_compare)
	content().add_child(_dossier)
	_dossier.show_country(_record, _context)
	var note := Label.new()
	note.name = "DisputedNote"
	note.text = Strings.t("overview.disputed")
	note.theme_type_variation = &"Caption"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content().add_child(note)


func _fill_history() -> void:
	_dossier = null
	var heading := Label.new()
	heading.text = Strings.t("overview.tab_history")
	heading.theme_type_variation = &"SectionHeading"
	content().add_child(heading)
	var found := 0
	var country_name: String = _record.name if _record != null else ""
	for event: GameEvent in _campaign_events():
		if not _mentions(event, country_name):
			continue
		found += 1
		var item := VBoxContainer.new()
		item.name = "Event_%s" % event.id
		item.add_theme_constant_override("separation", 0)
		var when := Label.new()
		when.text = event.date_label
		when.theme_type_variation = &"Caption"
		item.add_child(when)
		var line := Label.new()
		line.text = event.text()
		line.theme_type_variation = &"BodySmall"
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.add_child(line)
		content().add_child(item)
	if found == 0:
		var empty := Label.new()
		empty.name = "Empty"
		empty.text = Strings.t("overview.history_empty")
		empty.theme_type_variation = &"BodySmall"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content().add_child(empty)


func _campaign_events() -> Array:
	if _events == null:
		return []
	return _events.newest_first()


## An event concerns this country when it names it: the country's own name appears in the
## sentence, or the event's parameters carry that name. Nothing is inferred from category or
## proximity, because a guessed connection is a fabricated fact.
func _mentions(event: GameEvent, country_name: String) -> bool:
	if country_name.is_empty():
		return false
	if event.text().to_lower().contains(country_name.to_lower()):
		return true
	for value: Variant in event.params.values():
		if str(value).to_lower() == country_name.to_lower():
			return true
	return false


func _emit_compare(_ignored: Variant = null) -> void:
	compare_requested.emit(country_id)


func _clear_content() -> void:
	var box := content()
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()
