extends ResponsiveScreen
## What is new (Milestone 11, Task 5).
##
## A build is not a release. This page says what changed since the last milestone, in the same
## calm register as the Roadmap, and it ends with what is still missing — because a notes page
## that only lists additions turns "in progress" into a claim nobody checked.
##
## The content lives in `WhatsNewItems`, where every sentence carries the files that make it
## true; `tests/suites/test_whats_new.gd` reads them. Nothing on this page animates: it is a
## list of cards in one reading column, and motion would only make it harder to read.
##
## Reachable from the main menu's Library group and from the pause menu in a campaign, so a
## player can find it without leaving the game or starting one.

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


# --- What the tests ask -----------------------------------------------------

## The entry titles in the order the screen shows them.
func entry_titles() -> PackedStringArray:
	var titles := PackedStringArray()
	for release: Dictionary in WhatsNewItems.RELEASES:
		for item: Dictionary in release["items"]:
			titles.append(Strings.t(str(item["title_key"])))
	return titles


## The file citations the screen drew, one per evidence path, for the test that compares them
## with the table: a citation the reader cannot see is not a citation.
func citations() -> PackedStringArray:
	var shown := PackedStringArray()
	for release: Dictionary in WhatsNewItems.RELEASES:
		for item: Dictionary in release["items"]:
			for path: String in item["evidence"]:
				if not shown.has(path):
					shown.append(path)
	for path: String in WhatsNewItems.MISSING["evidence"]:
		if not shown.has(path):
			shown.append(path)
	return shown


func header_meta() -> String:
	return "" if _header == null else _header.meta_text


# --- Content ----------------------------------------------------------------

func _build() -> void:
	_header = get_node("%Header") as AppHeader
	_header.title_text = Strings.t("whats_new.title")
	_header.subtitle_text = Strings.t("whats_new.subtitle")
	_header.meta_text = Strings.t("whats_new.meta", [_running_version()])
	_header.back_pressed.connect(func() -> void: back_requested.emit())
	_content = get_node("%Content") as VBoxContainer
	_content.add_child(muted(Strings.t("whats_new.intro")))
	for release: Dictionary in WhatsNewItems.RELEASES:
		_content.add_child(_heading(Strings.t(str(release["title_key"]))))
		for item: Dictionary in release["items"]:
			_content.add_child(_item_card(item))
	_content.add_child(_heading(Strings.t(str(WhatsNewItems.MISSING["title_key"]))))
	_content.add_child(_card(Strings.t(str(WhatsNewItems.MISSING["body_key"])),
			WhatsNewItems.MISSING["evidence"], ""))


func _item_card(item: Dictionary) -> PanelContainer:
	return _card(Strings.t(str(item["body_key"])), item["evidence"],
			Strings.t(str(item["title_key"])))


## One card: an optional title, the body, and the files the sentence rests on. The citation is
## a caption rather than a link — there is nothing to open a repository with at runtime — but it
## is always drawn, so a reader can look the claim up in the source.
func _card(body_text: String, evidence: Array, title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelCard"
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	panel.add_child(body)
	if not title_text.is_empty():
		var title := Label.new()
		title.text = title_text
		title.theme_type_variation = "FieldLabel"
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(title)
	var text := Label.new()
	text.text = body_text
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(text)
	var cited := PackedStringArray()
	for path: String in evidence:
		cited.append(path)
	var source := Label.new()
	source.text = " · ".join(cited)
	source.theme_type_variation = "Caption"
	source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(source)
	return panel


func _heading(text: String) -> Label:
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


## The build the player is running, from the project file — the same source the main menu's
## version line and every save read, so the page cannot claim a version the build is not.
func _running_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
