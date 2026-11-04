class_name SettingRow
extends GridContainer
## One settings entry: a title with an optional description on the left, and the
## control that changes it on the right.
##
## Below `STACK_BELOW_WIDTH` the row becomes a single column so labels never get
## squeezed on a phone in portrait-ish widths. The layout mode is derived from
## the row's own width, not from a device class.

const STACK_BELOW_WIDTH := 480

var _pending_title := ""
var _pending_description := ""
var _pending_control: Control = null

@onready var _title: Label = %Title
@onready var _description: Label = %Description
@onready var _slot: HBoxContainer = %Slot


func _ready() -> void:
	add_theme_constant_override("h_separation", DesignTokens.SPACE_24)
	add_theme_constant_override("v_separation", DesignTokens.SPACE_12)
	resized.connect(_update_columns)
	_update_columns()
	_apply_setup()


## Configures the row. Safe to call before the row enters the tree, which is the
## usual case when a form is assembled in code.
func setup(row_title: String, row_description: String, control: Control) -> void:
	_pending_title = row_title
	_pending_description = row_description
	_pending_control = control
	if is_node_ready():
		_apply_setup()


func _apply_setup() -> void:
	_title.text = _pending_title
	_description.text = _pending_description
	_description.visible = not _pending_description.is_empty()
	if _pending_control != null and _pending_control.get_parent() == null:
		_slot.add_child(_pending_control)


func _update_columns() -> void:
	var target := 1 if size.x < STACK_BELOW_WIDTH else 2
	if columns != target:
		columns = target
