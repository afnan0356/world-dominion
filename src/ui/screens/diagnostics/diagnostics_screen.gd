extends ResponsiveScreen
## Diagnostics (Milestone 09, Task 4).
##
## What this screen is for: when something goes wrong on a device nobody here owns, the player
## needs a way to hand over the few facts that matter without handing over their identity. It
## shows the build, the data version, the engine, the platform, the screen, the frame-rate cap
## and the game's own last 50 warnings and errors — and it can put that same text in a file or on
## the clipboard.
##
## Two promises it keeps on purpose: the text is built without reading the profile at all, and
## every path is scrubbed to its last component before it is shown or saved. `Settings`, the
## save stores and the profile are never consulted, so no amount of marker text in a profile can
## reach the report (`tests/suites/test_diagnostics.gd` proves it with exactly that).
##
## The log is the game's own log. Godot does not expose its console stream to a script, so
## engine-level warnings are not captured; the screen says so in the caption rather than letting
## a reader assume the list is complete.

signal back_requested()

const _STATUS_SECONDS := 6.0

var _header: AppHeader
var _content: VBoxContainer
var _log_view: RichTextLabel
var _status: Label
var _status_timer: Timer
var _copy_button: Button
var _last_report := ""

@onready var _scroll: ScrollContainer = %Scroll


func _ready() -> void:
	super()
	_build()
	_refresh()


func on_layout_changed(_mode: int, is_short: bool, view_size: Vector2) -> void:
	if _header == null:
		return
	_header.set_compact(is_short)
	var margin := DesignTokens.screen_margin(DesignTokens.layout_mode(view_size))
	var available := view_size.x - float(margin * 2) - DesignTokens.SPACE_24
	if _content != null:
		_content.custom_minimum_size.x = clampf(available, 240.0,
				float(DesignTokens.CONTENT_MEASURE))


# --- Public API (also what the tests drive) --------------------------------

## The text the export writes and the clipboard receives. Built fresh, so it is never stale.
func report_text() -> String:
	_last_report = DiagnosticsReport.build()
	return _last_report


## Puts the report on the clipboard. False where the platform has no clipboard; the screen
## then says so instead of pretending.
func copy_to_clipboard() -> bool:
	var copied := DiagnosticsReport.copy_to_clipboard()
	_set_status(Strings.t("diagnostics.copied") if copied
			else Strings.t("diagnostics.copy_unavailable"))
	return copied


## Writes the report into the game's own folder. Returns the same dictionary the report
## builder returns, so a caller can show the file name or the reason it failed.
func export_report() -> Dictionary:
	var result := DiagnosticsReport.write_to_disk()
	if bool(result["ok"]):
		_set_status(Strings.t("diagnostics.exported", [str(result["file_name"])]))
	else:
		_set_status(Strings.t("diagnostics.export_failed", [str(result["error"])]))
	_refresh()
	return result


## The selectable log view, for tests and for anyone who wants the text on screen.
func log_view() -> RichTextLabel:
	return _log_view


# --- Building --------------------------------------------------------------

func _build() -> void:
	_header = get_node("%Header") as AppHeader
	_header.title_text = Strings.t("diagnostics.title")
	_header.subtitle_text = Strings.t("diagnostics.subtitle")
	_header.meta_text = Strings.t("diagnostics.meta")
	_header.back_pressed.connect(func() -> void: back_requested.emit())
	_status_timer = Timer.new()
	_status_timer.one_shot = true
	_status_timer.wait_time = _STATUS_SECONDS
	_status_timer.timeout.connect(func() -> void:
		if _status != null:
			_status.visible = false)
	add_child(_status_timer)
	_content = get_node("%Content") as VBoxContainer

	_content.add_child(_label(Strings.t("diagnostics.intro"), "Body", true))
	_content.add_child(_section_heading(Strings.t("diagnostics.build")))
	var build_card := _card()
	var grid := GridContainer.new()
	grid.name = "BuildGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", DesignTokens.SPACE_24)
	grid.add_theme_constant_override("v_separation", DesignTokens.SPACE_8)
	for row: Array in DiagnosticsReport.context():
		grid.add_child(_label(str(row[0]), "Caption", false))
		var value := _label(str(row[1]), "Value", true)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(value)
	build_card.add_child(grid)

	_content.add_child(_section_heading(Strings.t("diagnostics.log")))
	var log_card := _card()
	log_card.add_child(_label(Strings.t("diagnostics.log_caption",
			[DiagnosticsLog.count(), DiagnosticsLog.LIMIT]), "Caption", true))
	# A RichTextLabel rather than a TextEdit: it grows with its content, so the whole log
	# scrolls with the page and a line can still be selected and copied by hand.
	_log_view = RichTextLabel.new()
	_log_view.name = "LogView"
	_log_view.bbcode_enabled = false
	_log_view.selection_enabled = true
	_log_view.fit_content = true
	_log_view.scroll_active = false
	_log_view.custom_minimum_size = Vector2(0, 96)
	_log_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_card.add_child(_log_view)
	log_card.add_child(_label(Strings.t("diagnostics.select_hint"), "Caption", true))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	var export_button := Button.new()
	export_button.name = "ExportButton"
	export_button.text = Strings.t("diagnostics.export")
	export_button.theme_type_variation = &"PrimaryButton"
	export_button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	export_button.pressed.connect(func() -> void: export_report())
	actions.add_child(export_button)
	_copy_button = Button.new()
	_copy_button.name = "CopyButton"
	_copy_button.text = Strings.t("diagnostics.copy")
	_copy_button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	_copy_button.disabled = not DiagnosticsReport.clipboard_available()
	_copy_button.pressed.connect(func() -> void: copy_to_clipboard())
	actions.add_child(_copy_button)
	log_card.add_child(actions)

	_status = _label("", "Body", true)
	_status.name = "Status"
	_status.visible = false
	log_card.add_child(_status)

	_content.add_child(_label(Strings.t("diagnostics.privacy"), "Caption", true))
	_content.add_child(_label(Strings.t("diagnostics.folder_note"), "Caption", true))


func _refresh() -> void:
	if _log_view == null:
		return
	var entries := DiagnosticsLog.entries()
	_log_view.text = Strings.t("diagnostics.log_empty") if entries.is_empty() \
			else DiagnosticsLog.text()


func _set_status(text: String) -> void:
	if _status == null:
		return
	_status.text = text
	_status.visible = true
	if _status_timer != null:
		_status_timer.start()


# --- Small helpers ---------------------------------------------------------

func _label(text: String, variation: String, wrap: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _section_heading(text: String) -> Label:
	return _label(text, "SectionHeading", false)


func _card() -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"PanelCard"
	var body := VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", DesignTokens.SPACE_12)
	panel.add_child(body)
	_content.add_child(panel)
	return body
