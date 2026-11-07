class_name NewsPanel
extends ModalPanel
## The News screen (Milestone 10, Task 6): a calm newspaper page printed from the campaign.
##
## A newspaper is a strange thing to imitate in a game that must never invent a headline, so
## this one does not try: it prints the campaign's own record, in date order, with the system
## that recorded each entry named underneath. No prose is generated, no trend is predicted and
## no "analyst expects" sentence exists anywhere in the file — the layout is a newspaper, the
## content is a log.
##
## The style is deliberately quiet: one column, hairline rules between items, a serif-sized
## masthead and no colour coding beyond the theme. Reading it should feel like reading, not
## like scanning alerts.


func prepare(log: EventLog) -> void:
	build(Strings.t("news.title"))
	var masthead := Label.new()
	masthead.name = "Masthead"
	masthead.text = Strings.t("news.masthead")
	masthead.theme_type_variation = &"Eyebrow"
	masthead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content().add_child(masthead)
	content().add_child(HSeparator.new())
	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = Strings.t("news.subtitle")
	subtitle.theme_type_variation = &"Caption"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content().add_child(subtitle)
	content().add_child(HSeparator.new())

	if log == null or log.is_empty():
		var empty := Label.new()
		empty.name = "Empty"
		empty.text = Strings.t("news.empty")
		empty.theme_type_variation = &"BodySmall"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content().add_child(empty)
		return

	# Newest first: the latest edition of the paper is what a reader wants on top.
	for event: GameEvent in log.newest_first():
		content().add_child(_article(event))


func entry_count() -> int:
	var count := 0
	for child: Node in content().get_children():
		if child.name.begins_with("Article_"):
			count += 1
	return count


func _article(event: GameEvent) -> Control:
	var item := VBoxContainer.new()
	item.name = "Article_%s" % event.id
	item.add_theme_constant_override("separation", 0)
	var when := Label.new()
	when.text = event.date_label.to_upper() if not event.date_label.is_empty() else ""
	when.theme_type_variation = &"Caption"
	item.add_child(when)
	var headline := Label.new()
	headline.text = event.text()
	headline.theme_type_variation = &"Subheading"
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_child(headline)
	var credit := Label.new()
	credit.text = Strings.t("news.entry_origin", [event.origin_text()])
	credit.theme_type_variation = &"Caption"
	credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_child(credit)
	item.add_child(HSeparator.new())
	return item
