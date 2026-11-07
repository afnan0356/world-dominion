class_name TutorialPanel
extends PanelContainer
## The tutorial's panel (Milestone 08, Task 5): one step at a time, a Skip button on every
## step, and a final card that says what was earned.
##
## The panel never touches the profile. It announces `finished` when the last step is
## passed and `skipped` when the player leaves early; the screen that owns it is what pays
## the reward, once, through `PlayerProfile.complete_tutorial()`. That split is why a skip
## cannot pay by accident.

signal finished
signal skipped
signal closed

var _index := 0
var _note := ""
var _title_label: Label
var _body_label: Label
var _counter: Label
var _next: Button
var _skip: Button


func _ready() -> void:
	if _body_label != null:
		return
	add_theme_constant_override("separation", DesignTokens.SPACE_8)
	add_child(_make_label(Strings.t("tutorial.title"), "Eyebrow"))
	_counter = _make_label("", "Caption")
	_counter.name = "GuideCounter"
	add_child(_counter)
	_title_label = _make_label("", "Subheading")
	_title_label.name = "GuideTitle"
	add_child(_title_label)
	_body_label = _make_label("", "BodySmall")
	_body_label.name = "GuideBody"
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_body_label)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	_skip = Button.new()
	_skip.name = "GuideSkip"
	_skip.text = Strings.t("tutorial.skip")
	_skip.theme_type_variation = &"GhostButton"
	_skip.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	_skip.pressed.connect(skip)
	actions.add_child(_skip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	_next = Button.new()
	_next.name = "GuideNext"
	_next.text = Strings.t("tutorial.next")
	_next.theme_type_variation = &"PrimaryButton"
	_next.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	_next.pressed.connect(advance)
	actions.add_child(_next)
	add_child(actions)


## Starts again at step one. Reopening never clears the reward the profile already holds.
func open() -> void:
	_index = 0
	_note = ""
	refresh()


## Passes the finished card its sentence — the reward, or why there was none.
func show_result(text: String) -> void:
	_note = text
	refresh()


func advance() -> void:
	if _index >= TutorialSteps.count():
		closed.emit()
		return
	_index += 1
	if _index >= TutorialSteps.count():
		finished.emit()
	refresh()


func skip() -> void:
	skipped.emit()
	closed.emit()


func refresh() -> void:
	var total := TutorialSteps.count()
	var done := _index >= total
	if _title_label != null:
		_title_label.text = Strings.t("tutorial.done_title") if done \
				else TutorialSteps.title_of(_index)
	if _body_label != null:
		_body_label.text = _note if done else TutorialSteps.body_of(_index)
	if _counter != null:
		_counter.text = Strings.t("tutorial.finish") if done \
				else Strings.t("tutorial.counter", [mini(_index + 1, total), total])
	if _next != null:
		_next.text = Strings.t("tutorial.close") if done else Strings.t("tutorial.next")
	if _skip != null:
		_skip.visible = not done


func step_index() -> int:
	return _index


func is_complete() -> bool:
	return _index >= TutorialSteps.count()


func title_text() -> String:
	return "" if _title_label == null else _title_label.text


func body_text() -> String:
	return "" if _body_label == null else _body_label.text


func counter_text() -> String:
	return "" if _counter == null else _counter.text


func note() -> String:
	return _note


func next_button() -> Button:
	return _next


func skip_button() -> Button:
	return _skip


func _make_label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = StringName(variation)
	return label
