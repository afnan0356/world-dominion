extends ResponsiveScreen
## Roadmap (Milestone 09, Task 5).
##
## A calm page, not a pitch. It says what is in this build, then lists what is next with the
## honest status of each item — planned, explicitly not planned, or an open question for the
## project owner — and cites the document each item comes from.
##
## **No motion at all.** There are no tweens, no animations and nothing that changes position
## when it appears, so reduced motion needs no special case here; the test asserts that mounting
## the screen creates no tween. The page is a list of cards in one reading column, which is also
## why it is the least "designed" screen in the game on purpose.
##
## The items live in `RoadmapItems`, and each one names a source file plus a sentence that must
## still be in it. A test reads those files: an item whose source has changed fails the suite
## rather than quietly becoming a promise nobody made.

signal back_requested()

var _header: AppHeader
var _content: VBoxContainer

@onready var _scroll: ScrollContainer = %Scroll


func _ready() -> void:
	super()
	_build()


func on_layout_changed(_mode: int, is_short: bool, view_size: Vector2) -> void:
	if _header == null:
		return
	_header.set_compact(is_short)
	var margin := DesignTokens.screen_margin(DesignTokens.layout_mode(view_size))
	var available := view_size.x - float(margin * 2) - DesignTokens.SPACE_24
	if _content != null:
		_content.custom_minimum_size.x = clampf(available, 240.0,
				float(DesignTokens.CONTENT_MEASURE))


## The item titles in the order the screen shows them, for tests.
func item_titles() -> PackedStringArray:
	var titles := PackedStringArray()
	for item: Dictionary in RoadmapItems.ITEMS:
		titles.append(Strings.t(str(item["title_key"])))
	return titles


## The status labels the screen rendered, one per item.
func status_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	for item: Dictionary in RoadmapItems.ITEMS:
		labels.append(item["status"])
	return labels


func _build() -> void:
	_header = get_node("%Header") as AppHeader
	_header.title_text = Strings.t("roadmap.title")
	_header.subtitle_text = Strings.t("roadmap.subtitle")
	_header.meta_text = Strings.t("roadmap.meta")
	_header.back_pressed.connect(func() -> void: back_requested.emit())
	_content = get_node("%Content") as VBoxContainer
	_content.add_child(muted(Strings.t("roadmap.intro")))

	_content.add_child(heading(Strings.t("roadmap.now_title")))
	var now := _card()
	now.add_child(muted(Strings.t("roadmap.now_body")))

	_content.add_child(heading(Strings.t("roadmap.next_title")))
	for item: Dictionary in RoadmapItems.ITEMS:
		_content.add_child(_item_card(item))


func _item_card(item: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelCard"
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	panel.add_child(body)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	var title := Label.new()
	title.text = Strings.t(str(item["title_key"]))
	title.theme_type_variation = "FieldLabel"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(_badge(str(item["status"])))
	body.add_child(top)
	var text := Label.new()
	text.text = Strings.t(str(item["body_key"]))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(text)
	var source := Label.new()
	# Where the claim comes from. A reader who doubts the list can open the document.
	source.text = "%s · %s" % [str(item["source_file"]), str(item["source_quote"])]
	source.theme_type_variation = "Caption"
	source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(source)
	return panel


## The status pill. "Badge" is a real PanelContainer variation in the design system, and
## "BadgeText" a real Label variation, so no ad-hoc styling is invented here.
func _badge(status: String) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.theme_type_variation = &"Badge"
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var label := Label.new()
	label.text = status
	label.theme_type_variation = &"BadgeText"
	badge.add_child(label)
	return badge


func heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "SectionHeading"
	return label


func muted(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = "Body"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _card() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelCard"
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	panel.add_child(body)
	_content.add_child(panel)
	return body
