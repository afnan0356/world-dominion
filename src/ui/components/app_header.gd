class_name AppHeader
extends VBoxContainer
## Header for secondary screens: a back affordance, a small context line and the
## screen's title block.
##
## The back button is a real button rather than a swipe-only gesture so the same
## navigation works with mouse, keyboard and touch.

signal back_pressed()

@export var title_text: String = "":
	set(value):
		title_text = value
		if is_node_ready():
			_title.text = value
@export var subtitle_text: String = "":
	set(value):
		subtitle_text = value
		if is_node_ready():
			_subtitle.text = value
			_subtitle.visible = not value.is_empty()
@export var meta_text: String = "":
	set(value):
		meta_text = value
		if is_node_ready():
			_meta.text = value.to_upper()
			_meta.visible = not value.is_empty()

@onready var _back_button: Button = %BackButton
@onready var _row_title: Label = %RowTitle
@onready var _headings: VBoxContainer = $Headings
@onready var _title: Label = %Title
@onready var _subtitle: Label = %Subtitle
@onready var _meta: Label = %Meta


func _ready() -> void:
	_title.text = title_text
	_subtitle.text = subtitle_text
	_subtitle.visible = not subtitle_text.is_empty()
	_meta.text = meta_text.to_upper()
	_meta.visible = not meta_text.is_empty()
	_back_button.pressed.connect(func() -> void: back_pressed.emit())


## Short screens cannot afford a full title block: on a phone in landscape the
## header would take a third of the screen. The title shrinks and the subtitle
## steps aside; the page's section headings already say what it is.
func set_compact(compact: bool) -> void:
	# Compact keeps the title, but moves it onto the back-button row: one 40 px
	# row instead of a 94 px block, which is the difference between a map and no
	# map on a phone in landscape.
	_headings.visible = not compact
	_row_title.visible = compact
	_row_title.text = title_text
	_title.theme_type_variation = &"ScreenTitleCompact" if compact else &"ScreenTitle"
	_subtitle.visible = not compact and not subtitle_text.is_empty()
	# On a phone in landscape every row of header costs map: the context line goes
	# too, and the screen's own sections already say what the page is.
	_meta.visible = not compact and not meta_text.is_empty()
