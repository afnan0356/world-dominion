class_name FlagTile
extends Control
## A country's flag, or a neutral badge with its code — never a guess.
##
## The picture is requested **after** the row has been laid out (`call_deferred`), so opening
## a long list never blocks on rasterising flags. Until the texture exists, the badge is what
## is visible, which is also the permanent state for the five records that have no flag in
## the source data.

const WIDTH := 40
const HEIGHT := 30

var _badge: Label
var _picture: TextureRect
var _country_id := ""
var _alpha_2 := ""
var _loaded := false


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture = TextureRect.new()
	_picture.name = "Picture"
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.custom_minimum_size = Vector2(WIDTH, HEIGHT)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picture.visible = false
	add_child(_picture)
	_badge = Label.new()
	_badge.name = "Badge"
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.add_theme_font_size_override("font_size", 11)
	add_child(_badge)


## Points this tile at a record. The flag, if there is one, arrives a frame later.
func show_country(country_id: String, alpha_2: String = "") -> void:
	_country_id = country_id
	_alpha_2 = alpha_2
	_loaded = false
	_picture.texture = null
	_picture.visible = false
	_badge.visible = true
	_badge.text = FlagImage.badge_text(country_id, alpha_2)
	tooltip_text = Strings.t("flag.tooltip_missing", [_badge.text])
	if FlagImage.has_flag(country_id):
		call_deferred("_load_flag")


func _load_flag() -> void:
	if _loaded or _country_id.is_empty():
		return
	_loaded = true
	var texture := FlagImage.texture_for(_country_id)
	if texture == null or not is_instance_valid(_picture):
		return
	_picture.texture = texture
	_picture.visible = true
	_badge.visible = false
	tooltip_text = Strings.t("flag.tooltip", [_alpha_2.to_upper()])


## True once a flag is actually being drawn (false when the badge is what you see).
func has_texture() -> bool:
	return _picture != null and _picture.visible and _picture.texture != null


func badge_text() -> String:
	return "" if _badge == null else _badge.text


func badge_visible() -> bool:
	return _badge != null and _badge.visible
