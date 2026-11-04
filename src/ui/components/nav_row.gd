class_name NavRow
extends Button
## A full-width navigation entry: title, optional description, optional status
## badge and a chevron. Used for the main menu and any future in-game menu.
##
## The row is a real `Button`, so touch, mouse and keyboard (Tab/Enter) all work
## through Godot's built-in focus handling. Hover and focus are communicated by
## a 2px brass accent bar sliding up in opacity plus the button's themed
## background — deliberately quieter than a colour-filling hover.
##
## Rows marked as planned are disabled, keep an explanatory caption and expose a
## "PLANNED" badge: unfinished features are visible but never pretend to work.

@export var title_text: String = "":
	set(value):
		title_text = value
		if is_node_ready():
			_apply_identity()
@export var caption_text: String = "":
	set(value):
		caption_text = value
		if is_node_ready():
			_apply_identity()
@export var status_text: String = "":
	set(value):
		status_text = value
		if is_node_ready():
			_apply_identity()

var _hovered := false

@onready var _title: Label = %Title
@onready var _caption: Label = %Caption
@onready var _badge: PanelContainer = %Badge
@onready var _badge_label: Label = %BadgeLabel
@onready var _chevron: TextureRect = %Chevron
@onready var _accent_bar: ColorRect = %AccentBar
@onready var _content: MarginContainer = %Content


func _ready() -> void:
	# The button draws no text of its own; children carry the content so that a
	# row can show a title, a description, a badge and an icon at once.
	text = ""
	clip_text = false
	focus_mode = Control.FOCUS_ALL
	_accent_bar.custom_minimum_size = Vector2(DesignTokens.BORDER_ACCENT, 0)
	_chevron.custom_minimum_size = Vector2(DesignTokens.ICON_SIZE_SMALL,
			DesignTokens.ICON_SIZE_SMALL)
	_content.add_theme_constant_override("margin_left", DesignTokens.SPACE_8)
	_apply_identity()
	_apply_theme_colors()
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))
	focus_entered.connect(_update_accent)
	focus_exited.connect(_update_accent)
	ThemeManager.theme_changed.connect(_on_theme_changed)


func _apply_identity() -> void:
	_title.text = title_text
	_caption.text = caption_text
	_caption.visible = not caption_text.is_empty()
	_badge_label.text = status_text.to_upper()
	_badge.visible = not status_text.is_empty()
	tooltip_text = caption_text if not caption_text.is_empty() else ""
	_apply_theme_colors()


func _apply_theme_colors() -> void:
	var colors: Dictionary = ThemeManager.colors()
	var interactive := not disabled
	_title.add_theme_color_override("font_color",
			colors[Palette.KEY_TEXT_PRIMARY] if interactive else colors[Palette.KEY_TEXT_DISABLED])
	_caption.add_theme_color_override("font_color", colors[Palette.KEY_TEXT_TERTIARY])
	_badge_label.add_theme_color_override("font_color", colors[Palette.KEY_TEXT_TERTIARY])
	_accent_bar.color = colors[Palette.KEY_ACCENT]
	_chevron.modulate = colors[Palette.KEY_TEXT_TERTIARY] if interactive else Color.TRANSPARENT
	if not interactive:
		_accent_bar.modulate.a = 0.0
	_update_accent()


func _on_hover_changed(is_hovering: bool) -> void:
	_hovered = is_hovering
	_update_accent()


## Fades the accent bar in when the row is hovered or keyboard-focused.
func _update_accent() -> void:
	if disabled or _accent_bar == null:
		return
	var target := 1.0 if (_hovered or has_focus()) else 0.0
	var duration := Motion.duration(DesignTokens.DURATION_FAST, Settings.get_reduce_motion())
	if duration <= 0.0:
		_accent_bar.modulate.a = target
		return
	create_tween().tween_property(_accent_bar, "modulate:a", target, duration)


func _on_theme_changed(_palette_id: String) -> void:
	_apply_theme_colors()
