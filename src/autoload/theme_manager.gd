extends Node
## Autoload: `ThemeManager`.
##
## Builds the active theme from the player's palette choice and the design
## tokens, applies it to the root window (so every Control inherits it), and
## notifies custom-drawn widgets when the palette changes.

signal theme_changed(palette_id: String)

var _palette_id: String = Palette.DEFAULT_ID
var _colors: Dictionary = {}
var _theme: Theme


func _ready() -> void:
	Settings.changed.connect(_on_setting_changed)
	_apply(Settings.get_theme_id(), true)


func palette_id() -> String:
	return _palette_id


func current_theme() -> Theme:
	return _theme


func colors() -> Dictionary:
	return _colors


## Resolved colour for a palette key. Returns transparent rather than crashing
## when a caller asks for a key that does not exist.
func color(key: String) -> Color:
	return _colors.get(key, Color(0, 0, 0, 0))


func is_dark() -> bool:
	return Palette.is_dark(_palette_id)


## Strength of the procedural backdrop vignette: dark surfaces need a touch more
## separation between the content plane and the atmosphere behind it.
func vignette_strength() -> float:
	return 0.6 if is_dark() else 0.35


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == SettingsSchema.KEY_THEME:
		_apply(str(value))


func _apply(palette_id: String, force: bool = false) -> void:
	var resolved := palette_id if Palette.is_valid(palette_id) else Palette.DEFAULT_ID
	if not force and resolved == _palette_id and _theme != null:
		return
	_palette_id = resolved
	_colors = Palette.colors(_palette_id)
	_theme = ThemeFactory.build(_colors)
	var root := get_tree().root
	root.theme = _theme
	theme_changed.emit(_palette_id)
