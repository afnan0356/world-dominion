class_name ShellPanels
extends RefCounted
## Everything the game screen's shell can open, in one place.
##
## The shell's zones open **panels**, never routes. Routing away from a live campaign would
## destroy the session (`ScreenRouter` frees the screen it swaps out), so every destination the
## shell offers — Messages, News, the country overview, the six categories that are not built
## yet, the player's own summary — is a `ModalPanel` drawn over the campaign. This class owns
## that rule so the screen does not have to repeat it five times:
##
## * **one panel at a time.** Opening a second closes the first, which is what a player
##   expects from a menu that replaces itself rather than stacking up.
## * **the clock pauses while a panel is open.** Reading the news should not cost a month.
## * **no data of its own.** The session, the profile and the atlas all arrive as callables
##   from the screen, so a panel can never show a figure the campaign does not have.

var host: Control
## Returns the running `GameWorld`'s event log, or null when there is no campaign.
var events_provider: Callable = Callable()
## Returns the dossier context dictionary the side panel uses.
var context_provider: Callable = Callable()
var session_provider: Callable = Callable()
var profile_provider: Callable = Callable()
var atlas_provider: Callable = Callable()
## Opens the comparison overlay; the screen owns that screen, not this class.
var comparison_handler: Callable = Callable()
## Called after anything that changes what the shell displays (e.g. a message marked read).
var changed_handler: Callable = Callable()

var _panel: ModalPanel


## True while a panel is open. The screen's simulation loop reads this.
func is_open() -> bool:
	return _panel != null and is_instance_valid(_panel) and _panel.is_open()


func current() -> ModalPanel:
	return _panel if is_open() else null


func open_messages() -> void:
	var panel := MessagesPanel.new()
	panel.read_state_changed.connect(_notify_changed)
	panel.prepare(_events())
	_show(panel)


func open_news() -> void:
	var panel := NewsPanel.new()
	panel.prepare(_events())
	_show(panel)


## The Country category and the top bar's flag both land here.
func open_country(country_id: String) -> void:
	var atlas: WorldAtlas = _call(atlas_provider, null)
	if atlas == null or not atlas.is_ready():
		return
	var record := atlas.registry.get_country(country_id)
	if record == null:
		return
	var panel := CountryOverviewPanel.new()
	panel.compare_requested.connect(_on_compare)
	panel.prepare(record, _context(), _events())
	_show(panel)


## A category button. Country has a screen; the other six do not, and the panel they open says
## so in one paragraph instead of showing an empty mock-up.
func open_category(category_id: String) -> void:
	if category_id == "country":
		var session: GameSession = _call(session_provider, null)
		open_country(session.world.player_country_id if session != null else "")
		return
	var panel := PlannedPanel.new()
	panel.prepare(category_id, Strings.t("hud.category.%s" % category_id))
	_show(panel)


## The avatar: the player's own figures, every one of them read from the profile file or the
## campaign clock.
func open_profile() -> void:
	var profile: PlayerProfile = _call(profile_provider, null)
	var session: GameSession = _call(session_provider, null)
	var panel := ModalPanel.new()
	panel.build(Strings.t("hud.profile_title"))
	var rows: Array = []
	if profile == null:
		rows.append([Strings.t("hud.profile_name"), Strings.t("field.not_available")])
		rows.append([Strings.t("hud.profile_level"), Strings.t("field.not_available")])
		rows.append([Strings.t("hud.profile_xp"), Strings.t("field.not_available")])
		rows.append([Strings.t("hud.gold"), Strings.t("field.not_available")])
		rows.append([Strings.t("hud.gems"), Strings.t("field.not_available")])
	else:
		rows.append([Strings.t("hud.profile_name"), profile.display_name])
		rows.append([Strings.t("hud.profile_level"), Strings.t("hud.level", [profile.level()])])
		rows.append([Strings.t("hud.profile_xp"), Strings.t("hud.xp",
				[profile.xp_into_level(), profile.xp_for_next_level()])])
		rows.append([Strings.t("hud.gold"), str(profile.wallet.gold_coins())])
		rows.append([Strings.t("hud.gems"), str(profile.wallet.diamonds())])
	rows.append([Strings.t("hud.profile_playtime"), session.playtime_label() if session != null
			else Strings.t("field.not_available")])
	for row: Array in rows:
		panel.content().add_child(_row(str(row[0]), str(row[1])))
	panel.add_action(Strings.t("panel.close"), Callable(), true)
	_show(panel)


func close_current() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.close()


func _show(panel: ModalPanel) -> void:
	if host == null:
		return
	if _panel != null and is_instance_valid(_panel):
		_panel.close()
		_panel.queue_free()
	_panel = panel
	# Two thirds of the screen at most: a panel that covered everything would be a screen, and
	# the point of these panels is that the campaign stays visible behind them.
	var available := host.size
	panel.custom_minimum_size = Vector2(minf(600.0, maxf(320.0, available.x - 48.0)),
			minf(520.0, maxf(240.0, available.y - 96.0)))
	host.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.closed.connect(_on_closed)
	panel.open(host)


func _on_closed() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	_notify_changed()


func _on_compare(country_id: String) -> void:
	close_current()
	if comparison_handler.is_valid():
		comparison_handler.call(country_id)


func _notify_changed() -> void:
	if changed_handler.is_valid():
		changed_handler.call()


func _events() -> EventLog:
	return _call(events_provider, null)


func _context() -> Dictionary:
	var value: Variant = _call(context_provider, {})
	return value if value is Dictionary else {}


func _call(handler: Callable, fallback: Variant) -> Variant:
	if handler.is_valid():
		return handler.call()
	return fallback


func _row(caption: String, value: String) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", DesignTokens.SPACE_8)
	var label := Label.new()
	label.text = caption
	label.theme_type_variation = &"Caption"
	label.custom_minimum_size.x = 160.0
	line.add_child(label)
	var text := Label.new()
	text.text = value
	text.theme_type_variation = &"BodySmall"
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	return line
