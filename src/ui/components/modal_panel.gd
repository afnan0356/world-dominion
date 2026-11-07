class_name ModalPanel
extends PanelContainer
## The one panel shape every Milestone 10 screen uses: a title, an optional row of tabs, a
## scrolling body and a footer row of actions.
##
## Why a component rather than a scene per screen: the behaviours a panel needs are the
## behaviours a *mistake* would otherwise repeat in each copy. They live here once:
##
## * **Escape closes the topmost panel, and only the topmost.** Panels are stacked in
##   `stack`; the last one opened is the one Escape acts on, so a confirmation dialog opened
##   over a menu closes alone instead of tearing down both.
## * **Focus is trapped inside.** Tab and Shift+Tab cycle through the panel's own controls and
##   never wander out to the game screen behind it, and when the panel closes focus goes back
##   to whatever had it before — a keyboard player never has to hunt for their place.
## * **The body scrolls, the header and footer do not.** A long message list, or a phone in
##   landscape, can never push the Close button off the bottom of the screen.
##
## A panel is a *container of actions*, never a place where content is invented: the caller
## supplies every line, and a panel with nothing to show says so plainly.

signal closed
signal tab_changed(tab_id: String)

## Panels currently open, oldest first. Shared on purpose: the stack is a property of the
## interface, not of one panel.
static var stack: Array = []

var title_text := ""
var tab_ids: Array = []
var footer_actions: Array = []

var _title_label: Label
var _tab_bar: HBoxContainer
var _content: VBoxContainer
var _footer: HBoxContainer
var _scroll: ScrollContainer
var _close_button: Button
var _current_tab := ""
var _previous_focus: Control
var _built := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	if not _built:
		build(title_text)


## Builds the panel's children. Called once; safe to call again after changing the title.
func build(panel_title: String) -> void:
	title_text = panel_title
	if _built:
		if _title_label != null:
			_title_label.text = title_text
		return
	_built = true
	name = "ModalPanel"
	add_theme_constant_override("separation", DesignTokens.SPACE_8)
	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	add_child(column)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	column.add_child(header)
	_title_label = _label(title_text, "Heading")
	_title_label.name = "Title"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.clip_text = true
	_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header.add_child(_title_label)
	_close_button = Button.new()
	_close_button.name = "Close"
	_close_button.text = Strings.t("panel.close")
	_close_button.theme_type_variation = &"GhostButton"
	_close_button.tooltip_text = Strings.t("panel.close_tooltip")
	_close_button.custom_minimum_size = Vector2(DesignTokens.CONTROL_HEIGHT,
			DesignTokens.CONTROL_HEIGHT)
	_close_button.pressed.connect(close)
	PressFeedback.attach(_close_button)
	header.add_child(_close_button)

	_tab_bar = HBoxContainer.new()
	_tab_bar.name = "Tabs"
	_tab_bar.add_theme_constant_override("separation", DesignTokens.SPACE_4)
	_tab_bar.visible = false
	column.add_child(_tab_bar)

	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	_scroll.add_child(_content)

	_footer = HBoxContainer.new()
	_footer.name = "Footer"
	_footer.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	column.add_child(_footer)


## The scrolling body. Everything a caller adds goes in here.
func content() -> VBoxContainer:
	build(title_text)
	return _content


## Adds a tab. The first tab added becomes the visible one. `on_show` (optional) builds that
## tab's content the first time it is shown, so an expensive tab costs nothing until asked.
func add_tab(tab_id: String, label: String, on_show: Callable = Callable()) -> void:
	build(title_text)
	_tab_bar.visible = true
	var button := Button.new()
	button.name = "Tab_%s" % tab_id
	button.text = label
	button.toggle_mode = true
	button.theme_type_variation = &"GhostButton"
	button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	button.set_meta("tab_id", tab_id)
	button.set_meta("on_show", on_show)
	button.pressed.connect(func() -> void: show_tab(tab_id))
	PressFeedback.attach(button)
	_tab_bar.add_child(button)
	tab_ids.append(tab_id)
	if _current_tab.is_empty():
		_current_tab = tab_id
		_highlight_tab()


## Shows a tab by id. Never creates content on its own: the caller's `on_show` does that.
func show_tab(tab_id: String) -> void:
	if not tab_ids.has(tab_id):
		return
	var changed := _current_tab != tab_id
	_current_tab = tab_id
	_highlight_tab()
	for button: Node in _tab_bar.get_children():
		if str(button.get_meta("tab_id", "")) != tab_id:
			continue
		var action: Variant = button.get_meta("on_show", null)
		var already_built := bool(button.get_meta("built", false))
		if action is Callable and (action as Callable).is_valid() and not already_built:
			button.set_meta("built", true)
			(action as Callable).call()
	if changed:
		tab_changed.emit(tab_id)


func current_tab() -> String:
	return _current_tab


## The footer row. A button added here stays visible while the body scrolls.
func footer() -> HBoxContainer:
	build(title_text)
	return _footer


## Adds a footer button that runs `action` and closes the panel when `closes` is true.
func add_action(label: String, action: Callable, closes: bool = true) -> Button:
	var button := Button.new()
	button.text = label
	button.theme_type_variation = &"PrimaryButton" if closes else &"GhostButton"
	button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	button.pressed.connect(func() -> void:
		if action.is_valid():
			action.call()
		if closes:
			close())
	PressFeedback.attach(button)
	var bar := footer()
	var spacer := bar.get_node_or_null("Spacer")
	if spacer == null:
		spacer = Control.new()
		spacer.name = "Spacer"
		(spacer as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_child(spacer)
	bar.add_child(button)
	footer_actions.append(button)
	return button


## Opens the panel over `host`, remembers the focus to restore, and takes focus itself.
func open(host: Control) -> void:
	build(title_text)
	if not stack.has(self):
		stack.append(self)
	if host != null and get_parent() != host:
		host.add_child(self)
	var viewport := get_viewport()
	if viewport != null:
		_previous_focus = viewport.gui_get_focus_owner()
	visible = true
	focus_first()


## Closes this panel and gives focus back to whoever had it. Returns false when the panel was
## not open, so a caller can ignore a double close.
func close() -> bool:
	if not stack.has(self):
		return false
	stack.erase(self)
	visible = false
	if _previous_focus != null and is_instance_valid(_previous_focus) \
			and _previous_focus.is_inside_tree():
		_previous_focus.grab_focus()
	_previous_focus = null
	closed.emit()
	return true


func is_open() -> bool:
	return stack.has(self)


## Escape closes the *topmost* panel only. This is deliberately handled in `_input` rather
## than through an action, so it works even when nothing inside the panel has focus.
func _input(event: InputEvent) -> void:
	if not visible or stack.is_empty() or stack.back() != self:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
		return
	if key.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		cycle_focus(key.shift_pressed)


## Moves focus to the next (or previous) of this panel's own focusable controls, wrapping at
## the ends. This is what keeps Tab inside the panel.
func cycle_focus(backwards: bool = false) -> void:
	var controls := focusables()
	if controls.is_empty():
		return
	var owner := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	var index := controls.find(owner)
	var next := 0
	if index >= 0:
		next = posmod(index + (-1 if backwards else 1), controls.size())
	controls[next].grab_focus()


## Every control inside the panel that can take focus, in reading order.
func focusables() -> Array:
	var out: Array = []
	for node: Node in find_children("*", "Control", true, false):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control.focus_mode == Control.FOCUS_NONE:
			continue
		if control is Button or control is LineEdit or control is TextEdit \
				or control is ScrollContainer:
			out.append(control)
	return out


func focus_first() -> void:
	var controls := focusables()
	if not controls.is_empty():
		controls[0].grab_focus()


## Every panel that is still open, oldest first, for tests and the diagnostics report.
static func open_panels() -> Array:
	var out: Array = []
	for panel: Variant in stack.duplicate():
		if is_instance_valid(panel) and (panel as Control).is_inside_tree():
			out.append(panel)
	return out


static func clear_stack() -> void:
	stack.clear()


func _highlight_tab() -> void:
	for button: Node in _tab_bar.get_children():
		var is_current := str(button.get_meta("tab_id", "")) == _current_tab
		(button as Button).set_pressed_no_signal(is_current)
		(button as Button).theme_type_variation = &"PrimaryButton" if is_current else &"GhostButton"


func _label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = StringName(variation)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
