extends ResponsiveScreen
## Help (Milestone 09, Task 5).
##
## Plain language, short sections, no tutorial voice and no promises: what this build is, what
## you can do, how saving and backups work, why there is no account, what the notification
## choice does (nothing yet), and where to go when something breaks.
##
## Every section's claim is checkable. The content lives in `HelpSections`, where each entry
## names the screens and the files that make its sentence true; `tests/suites/test_help_roadmap
## .gd` resolves those against the application's screen table, so this screen cannot describe a
## screen that does not exist. The only sections without evidence are the two that explain scope
## rather than a feature, and that list is explicit.

signal back_requested()
## Navigation to a screen a section points at. The shell decides what that means.
signal navigation_requested(screen_id: String, params: Dictionary)

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


## The sections as they are rendered, for tests: one entry per card, in order.
func section_titles() -> PackedStringArray:
	var titles := PackedStringArray()
	for section: Dictionary in HelpSections.SECTIONS:
		titles.append(Strings.t(str(section["title_key"])))
	return titles


## Screen ids this page links to, in order. A test proves each one is in the shell's table.
func linked_screens() -> PackedStringArray:
	var ids := PackedStringArray()
	for section: Dictionary in HelpSections.SECTIONS:
		for screen_id: String in (section["screens"] as Array):
			ids.append(screen_id)
	return ids


# --- Building --------------------------------------------------------------

func _build() -> void:
	_header = get_node("%Header") as AppHeader
	_header.title_text = Strings.t("help.title")
	_header.subtitle_text = Strings.t("help.subtitle")
	_header.meta_text = Strings.t("help.meta")
	_header.back_pressed.connect(func() -> void: back_requested.emit())
	_content = get_node("%Content") as VBoxContainer
	_content.add_child(_label(Strings.t("help.intro"), "Body"))

	for section: Dictionary in HelpSections.SECTIONS:
		_content.add_child(_label(Strings.t(str(section["title_key"])), "SectionHeading"))
		var body := _card()
		body.add_child(_label(Strings.t(str(section["body_key"])), "Body"))
		_add_links(body, section)


## One full-height button per screen a section points at. This is how the page stays honest:
## a claim about saving comes with the buttons that reach the save screens.
func _add_links(body: VBoxContainer, section: Dictionary) -> void:
	var screens: Array = section["screens"]
	if screens.is_empty():
		return
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", DesignTokens.SPACE_8)
	row.add_theme_constant_override("v_separation", DesignTokens.SPACE_8)
	for screen_id: String in screens:
		var button := Button.new()
		button.name = "Open_%s" % screen_id
		button.text = HelpSections.label_for(screen_id)
		button.theme_type_variation = &"GhostButton"
		button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
		button.pressed.connect(func() -> void:
			navigation_requested.emit(screen_id, {}))
		row.add_child(button)
	body.add_child(row)


func _label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	if variation != "SectionHeading":
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _card() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelCard"
	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	panel.add_child(body)
	_content.add_child(panel)
	return body
