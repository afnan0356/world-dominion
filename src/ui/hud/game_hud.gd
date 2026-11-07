class_name GameHud
extends Control
## The game screen's shell (Milestone 10, Task 3): five fixed zones around the map.
##
##   top      avatar · Gold Coins · Red Gems · XP and level · flag, plus a strip of real
##            country figures (population, area, currency) that say "Not available" where the
##            source data has no value
##   left     Messages, with the unread count
##   right    News, with the newest entry's date
##   bottom   Menu and the tutorial on the left, the category bar in the middle, the clock's
##            speed and the in-game date on the right
##
## Three rules shaped this file:
##
## 1. **The shell shows real data or nothing.** Every figure comes from the running campaign,
##    the player's profile or the shipped dataset. A missing figure is the string "Not
##    available"; nothing is made up to fill a space, and no category pretends to have a
##    screen that does not exist.
## 2. **A category that is not built says so.** Country opens the country overview; the other
##    six are planned, and pressing one opens a plain panel that says exactly that. They are
##    real buttons with an honest answer, not disabled stubs that look broken.
## 3. **The shell never takes the map's space.** It is an overlay inside the map area: it is
##    `mouse_filter = IGNORE` and only its controls accept the pointer, so dragging the map
##    between the zones still pans it.

signal pause_pressed
signal menu_pressed
signal map_pressed
signal speed_selected(value: int)
signal avatar_pressed
signal flag_pressed
signal messages_pressed
signal news_pressed
signal tutorial_pressed
signal category_selected(category_id: String)

const SEGMENTED := preload("res://src/ui/components/segmented_control.tscn")

## The bottom bar's categories, in the order the design system lists them. `available` is the
## truth about this build: only Country has a screen behind it.
const CATEGORIES := [
	{"id": "country", "key": "hud.category.country", "available": true},
	{"id": "economy", "key": "hud.category.economy", "available": false},
	{"id": "government", "key": "hud.category.government", "available": false},
	{"id": "diplomacy", "key": "hud.category.diplomacy", "available": false},
	{"id": "military", "key": "hud.category.military", "available": false},
	{"id": "research", "key": "hud.category.research", "available": false},
	{"id": "world", "key": "hud.category.world", "available": false},
]

# --- Public widgets the game screen keeps using -----------------------------
var player_label: Label
var country_label: Label
var date_label: Label
var status_label: Label
var autosave_label: Label
var speed_control: SegmentedControl
var pause_button: Button
var menu_button: Button
var map_button: Button
var tutorial_button: Button
var avatar_button: Button
var flag_button: Button
var messages_button: Button
var news_button: Button
var status_block: VBoxContainer
var category_buttons: Dictionary = {}

# --- Real data --------------------------------------------------------------
var _session: GameSession
var _profile: PlayerProfile
var _dossier: Callable = Callable()

var _gold_label: Label
var _gems_label: Label
var _level_label: Label
var _xp_label: Label
var _xp_bar: ProgressBar
var _population_value: Label
var _area_value: Label
var _currency_value: Label
var _identity: VBoxContainer
var _xp_block: VBoxContainer
var _unread_badge: Label
var _news_caption: Label
var _category_row: HBoxContainer
var _built := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_apply_width)
	if not _built:
		_apply_width()


## Builds the shell. `top_host` is the game screen's top-bar panel; the bottom bar and the
## two rails are added inside this Control, which lives over the map.
func build(top_host: Control) -> void:
	if _built:
		return
	_built = true
	_build_top(top_host)
	_build_rails()
	_build_bottom()


# --- Top zone ---------------------------------------------------------------

func _build_top(host: Control) -> void:
	var stack := VBoxContainer.new()
	stack.name = "TopStack"
	stack.add_theme_constant_override("separation", DesignTokens.SPACE_4)
	host.add_child(stack)
	var row := HBoxContainer.new()
	row.name = "TopRow"
	row.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	stack.add_child(row)

	avatar_button = Button.new()
	avatar_button.name = "Avatar"
	avatar_button.theme_type_variation = &"GhostButton"
	avatar_button.custom_minimum_size = Vector2(DesignTokens.CONTROL_HEIGHT,
			DesignTokens.CONTROL_HEIGHT)
	avatar_button.tooltip_text = Strings.t("hud.avatar_tooltip")
	# The mark is drawn in code (see ShellIcon): no licensed icon set could be downloaded, and
	# borrowing one whose licence nobody re-checked is not an option.
	var avatar_icon := ShellIcon.new()
	avatar_icon.name = "AvatarIcon"
	avatar_icon.icon_name = "avatar"
	avatar_icon.custom_minimum_size = Vector2(20, 20)
	avatar_icon.set_anchors_preset(Control.PRESET_CENTER)
	avatar_button.add_child(avatar_icon)
	avatar_button.pressed.connect(func() -> void: avatar_pressed.emit())
	PressFeedback.attach(avatar_button)
	row.add_child(avatar_button)

	_identity = VBoxContainer.new()
	_identity.add_theme_constant_override("separation", 0)
	_identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_label = _label("LEADING", "Caption")
	player_label.name = "Player"
	country_label = _label("—", "Subheading")
	country_label.name = "Country"
	country_label.clip_text = true
	country_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_identity.add_child(player_label)
	_identity.add_child(country_label)
	row.add_child(_identity)

	_gold_label = _stat(row, "Gold", Strings.t("hud.gold"))
	_gems_label = _stat(row, "Gems", Strings.t("hud.gems"))

	_xp_block = VBoxContainer.new()
	_xp_block.name = "XpBlock"
	_xp_block.add_theme_constant_override("separation", 0)
	_xp_block.add_child(_label(Strings.t("hud.xp_short", [0]), "Caption"))
	_level_label = _label("—", "Subheading")
	_level_label.name = "Level"
	_xp_block.add_child(_level_label)
	_xp_bar = ProgressBar.new()
	_xp_bar.name = "XpBar"
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(96, 6)
	_xp_bar.max_value = 1.0
	_xp_bar.value = 0.0
	_xp_block.add_child(_xp_bar)
	row.add_child(_xp_block)
	# The xp block's own caption is replaced on refresh by the exact numbers.
	_xp_label = _xp_block.get_child(0) as Label

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	autosave_label = _label(Strings.t("hud.autosaved"), "Caption")
	autosave_label.name = "Autosave"
	autosave_label.visible = false
	row.add_child(autosave_label)

	map_button = _ghost(Strings.t("hud.map"), "Map", Strings.t("hud.map_tooltip"))
	map_button.pressed.connect(func() -> void: map_pressed.emit())
	row.add_child(map_button)

	flag_button = Button.new()
	flag_button.name = "Flag"
	flag_button.theme_type_variation = &"GhostButton"
	flag_button.custom_minimum_size = Vector2(DesignTokens.CONTROL_HEIGHT,
			DesignTokens.CONTROL_HEIGHT)
	flag_button.tooltip_text = Strings.t("hud.flag_tooltip")
	flag_button.pressed.connect(func() -> void: flag_pressed.emit())
	PressFeedback.attach(flag_button)
	row.add_child(flag_button)

	# The second row: real figures for the player's own country, or "Not available".
	var strip := HBoxContainer.new()
	strip.name = "StatsStrip"
	strip.add_theme_constant_override("separation", DesignTokens.SPACE_16)
	stack.add_child(strip)
	_population_value = _figure(strip, "Population", Strings.t("hud.population"))
	_area_value = _figure(strip, "Area", Strings.t("hud.area"))
	_currency_value = _figure(strip, "Currency", Strings.t("hud.currency"))
	var strip_spacer := Control.new()
	strip_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(strip_spacer)
	status_block = VBoxContainer.new()
	status_block.name = "StatusBlock"
	status_block.add_theme_constant_override("separation", 0)
	status_block.add_child(_label(Strings.t("hud.simulation"), "Caption"))
	status_label = _label(Strings.t("hud.paused"), "Subheading")
	status_label.name = "Status"
	status_block.add_child(status_label)
	strip.add_child(status_block)


# --- Rails ------------------------------------------------------------------

func _build_rails() -> void:
	var left := VBoxContainer.new()
	left.name = "LeftRail"
	left.add_theme_constant_override("separation", DesignTokens.SPACE_4)
	left.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	left.anchor_top = 0.25
	left.anchor_bottom = 0.75
	left.offset_left = DesignTokens.SPACE_8
	left.offset_top = 0.0
	left.grow_horizontal = Control.GROW_DIRECTION_END
	add_child(left)
	messages_button = _ghost(Strings.t("hud.messages"), "Messages",
			Strings.t("messages.intro"))
	messages_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	messages_button.pressed.connect(func() -> void: messages_pressed.emit())
	left.add_child(messages_button)
	_unread_badge = _label(Strings.t("hud.messages.none"), "Caption")
	_unread_badge.name = "UnreadBadge"
	_unread_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_unread_badge)

	var right := VBoxContainer.new()
	right.name = "RightRail"
	right.add_theme_constant_override("separation", DesignTokens.SPACE_4)
	right.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	right.anchor_top = 0.25
	right.anchor_bottom = 0.75
	right.offset_right = -DesignTokens.SPACE_8
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(right)
	news_button = _ghost(Strings.t("hud.news"), "News", Strings.t("news.subtitle"))
	news_button.pressed.connect(func() -> void: news_pressed.emit())
	right.add_child(news_button)
	_news_caption = _label(Strings.t("hud.news.empty"), "Caption")
	_news_caption.name = "NewsCaption"
	_news_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_news_caption.custom_minimum_size.x = 120.0
	right.add_child(_news_caption)


# --- Bottom zone ------------------------------------------------------------

func _build_bottom() -> void:
	var column := VBoxContainer.new()
	column.name = "BottomBar"
	column.add_theme_constant_override("separation", DesignTokens.SPACE_4)
	column.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	column.offset_left = DesignTokens.SPACE_8
	column.offset_right = -DesignTokens.SPACE_8
	column.offset_top = -96.0
	column.offset_bottom = -DesignTokens.SPACE_8
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(column)

	# The category bar scrolls sideways rather than clipping: on a 640 px landscape phone
	# seven labels and a clock do not fit, and a bar that silently loses its last button
	# would look broken.
	var categories_scroll := ScrollContainer.new()
	categories_scroll.name = "CategoriesScroll"
	categories_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	categories_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	categories_scroll.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT + 4.0
	categories_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(categories_scroll)
	_category_row = HBoxContainer.new()
	_category_row.name = "Categories"
	_category_row.add_theme_constant_override("separation", DesignTokens.SPACE_4)
	_category_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	categories_scroll.add_child(_category_row)
	for entry: Dictionary in CATEGORIES:
		var button := Button.new()
		button.name = "Category_%s" % str(entry["id"])
		button.text = Strings.t(str(entry["key"]))
		button.theme_type_variation = &"GhostButton"
		button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("category_id", str(entry["id"]))
		button.set_meta("available", bool(entry["available"]))
		var category_id := str(entry["id"])
		button.pressed.connect(func() -> void: _on_category(category_id))
		PressFeedback.attach(button)
		_category_row.add_child(button)
		category_buttons[category_id] = button

	var controls := HBoxContainer.new()
	controls.name = "Controls"
	controls.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	column.add_child(controls)
	menu_button = _ghost(Strings.t("hud.menu"), "Menu", Strings.t("hud.menu_tooltip"))
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	controls.add_child(menu_button)
	tutorial_button = _ghost(Strings.t("hud.tutorial"), "Tutorial",
			Strings.t("hud.tutorial_tooltip"))
	tutorial_button.pressed.connect(func() -> void: tutorial_pressed.emit())
	controls.add_child(tutorial_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.add_child(spacer)

	speed_control = SEGMENTED.instantiate() as SegmentedControl
	speed_control.name = "Speed"
	speed_control.tooltip_text = Strings.t("hud.speed_tooltip")
	speed_control.option_selected.connect(_on_speed_selected)
	controls.add_child(speed_control)

	pause_button = _ghost(Strings.t("hud.pause"), "Pause", Strings.t("hud.pause_tooltip"))
	pause_button.pressed.connect(func() -> void: pause_pressed.emit())
	controls.add_child(pause_button)

	var date_block := VBoxContainer.new()
	date_block.name = "DateBlock"
	date_block.add_theme_constant_override("separation", 0)
	date_block.add_child(_label(Strings.t("hud.date"), "Caption"))
	date_label = _label("—", "Subheading")
	date_label.name = "Date"
	date_block.add_child(date_label)
	controls.add_child(date_block)


# --- Wiring -----------------------------------------------------------------

## Hands the shell the three sources of truth it may read: the running campaign, the player's
## profile and a callable returning the same dossier context the side panel uses. Nothing
## else is available to it, which is why it cannot invent a figure.
func bind(session: GameSession, profile: PlayerProfile, dossier: Callable) -> void:
	_session = session
	_profile = profile
	_dossier = dossier
	refresh()


## Re-reads every figure the shell shows. Cheap enough to call on any change: it only touches
## labels, and it is called after a save, a month boundary, a speed change and a read state
## change.
func refresh() -> void:
	if not _built:
		return
	_refresh_profile()
	_refresh_country()
	_refresh_messages()
	_refresh_news()


func _refresh_profile() -> void:
	var gold := _profile.wallet.gold_coins() if _profile != null else 0
	var gems := _profile.wallet.diamonds() if _profile != null else 0
	_gold_label.text = str(gold)
	_gems_label.text = str(gems)
	_gold_label.get_parent().tooltip_text = "%s: %s" % [Strings.t("hud.gold"), str(gold)]
	_gems_label.get_parent().tooltip_text = "%s: %s" % [Strings.t("hud.gems"), str(gems)]
	if _profile == null:
		_level_label.text = "—"
		_xp_label.text = Strings.t("field.not_available")
		_xp_bar.value = 0.0
		return
	var level := _profile.level()
	var into := _profile.xp_into_level()
	var needed := _profile.xp_for_next_level()
	_level_label.text = Strings.t("hud.level", [level])
	_xp_label.text = Strings.t("hud.xp", [into, needed])
	_xp_bar.max_value = maxf(float(needed), 1.0)
	_xp_bar.value = float(into)
	avatar_button.tooltip_text = "%s — %s" % [str(_profile.display_name),
			Strings.t("hud.avatar_tooltip")]


## The strip under the top bar. Population and area come from the shipped statistics; the
## currency name comes from the shipped currency table. Each one is either a real value or the
## words "Not available" — there is no third state.
func _refresh_country() -> void:
	var context: Dictionary = {}
	if _dossier.is_valid():
		context = _dossier.call()
	var country_id := _session.world.player_country_id if _session != null else ""
	_population_value.text = Strings.t("field.not_available")
	_area_value.text = Strings.t("field.not_available")
	_currency_value.text = Strings.t("field.not_available")
	if country_id.is_empty():
		return
	var statistics: Variant = context.get("statistics", null)
	if statistics != null:
		var population: Variant = statistics.call("value", country_id, "population")
		if population != null:
			_population_value.text = CountryStatistics.format_integer(int(population))
		var area: Variant = statistics.call("value", country_id, "area_km2")
		if area != null:
			_area_value.text = "%s km²" % CountryStatistics.format_integer(int(area))
	var currency: Variant = context.get("currency", null)
	if currency != null:
		var described := str(currency.call("describe", country_id))
		if not described.is_empty():
			_currency_value.text = described


## The campaign's event log, or null when there is no campaign. One accessor keeps the two
## rails reading the same list.
func _events() -> EventLog:
	if _session == null or _session.world == null:
		return null
	return _session.world.events


func _refresh_messages() -> void:
	var log := _events()
	var unread := log.unread_count() if log != null else 0
	if unread > 0:
		_unread_badge.text = Strings.t("hud.messages.unread", [unread])
		_unread_badge.theme_type_variation = &"BodySmall"
	else:
		_unread_badge.text = Strings.t("hud.messages.none")
		_unread_badge.theme_type_variation = &"Caption"
	messages_button.tooltip_text = _unread_badge.text


func _refresh_news() -> void:
	var log := _events()
	if log == null or log.is_empty():
		_news_caption.text = Strings.t("hud.news.empty")
		return
	var newest := log.entries.back() as GameEvent
	var when := newest.date_label if not newest.date_label.is_empty() else newest.text()
	_news_caption.text = Strings.t("hud.news.latest", [when])


# --- Wiring from the screen ------------------------------------------------

## The clock labels. The game screen calls this after every change instead of touching the
## labels itself, so a paused clock and the pause button can never disagree.
func set_clock(date_text: String, status_text: String, paused: bool, speed: int) -> void:
	if date_label == null:
		return
	date_label.text = date_text
	status_label.text = status_text
	pause_button.text = Strings.t("hud.resume") if paused else Strings.t("hud.pause")
	if speed_control != null:
		speed_control.set_selected(str(maxi(1, speed)))


## Rebuilds the speed buttons. The game screen decides which speeds the player has earned, so
## this is called with those options, never assumed.
func set_speeds(options: Array, selected: String) -> void:
	if speed_control == null:
		return
	speed_control.setup(options, selected)


func set_autosave_text(text: String, visible_now: bool) -> void:
	if autosave_label == null:
		return
	autosave_label.text = text
	autosave_label.visible = visible_now


func _on_category(category_id: String) -> void:
	category_selected.emit(category_id)


func _on_speed_selected(option_id: String) -> void:
	speed_selected.emit(int(option_id))


# --- Layout -----------------------------------------------------------------

func _apply_width() -> void:
	if not _built:
		return
	var width := size.x
	# A narrow window keeps the controls and drops the words. Every hidden element is
	# duplicated somewhere the player can still reach: the country's own name is in the
	# dossier, the map options are in the menu, and the autosave note is in Messages.
	_identity.visible = width >= 760.0
	_xp_block.visible = width >= 640.0
	autosave_label.visible = autosave_label.visible and width >= 900.0
	map_button.visible = width >= 560.0
	_gold_label.get_parent().visible = width >= 420.0
	status_block.visible = width >= 680.0
	# The rails only appear when there is map to put them beside; on a phone the two buttons
	# sit in the bottom bar's row instead of over the middle of a small map.
	var wide := width >= 620.0
	var left := get_node_or_null("LeftRail") as Control
	var right := get_node_or_null("RightRail") as Control
	if left != null:
		left.visible = wide
	if right != null:
		right.visible = wide
	messages_button.visible = wide
	news_button.visible = wide


func _label(text: String, variation: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = StringName(variation)
	return label


func _ghost(text: String, node_name: String, tooltip: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.theme_type_variation = &"GhostButton"
	button.custom_minimum_size.y = DesignTokens.CONTROL_HEIGHT
	button.tooltip_text = tooltip
	PressFeedback.attach(button)
	return button


## A caption over a value: the shape every figure in the shell uses.
func _figure(row: HBoxContainer, node_name: String, caption: String) -> Label:
	var block := VBoxContainer.new()
	block.name = node_name
	block.add_theme_constant_override("separation", 0)
	block.add_child(_label(caption, "Caption"))
	var value := _label(Strings.t("field.not_available"), "BodySmall")
	value.name = "Value"
	block.add_child(value)
	row.add_child(block)
	return value


## The same shape, smaller, for a wallet balance. Returns the value label; its parent is the
## whole block, which is what carries the tooltip.
func _stat(row: HBoxContainer, node_name: String, caption: String) -> Label:
	return _figure(row, node_name, caption)
