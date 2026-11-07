extends TestCase
## The profile screen and the twenty avatars (Milestone 08, Task 4).
##
## The rules under test: every number on the screen comes from the profile file and nowhere
## else; the avatars are drawn by the game itself, with a text label each, and a choice is
## saved; a rename says what it costs and what the player has *before* anything is spent;
## a username is set once and says so first; and the screen fits every reference size in
## both themes with focusable, finger-sized controls.

const SCENE := "res://src/ui/screens/profile/profile_screen.tscn"
const FIRST_RUN := "res://src/ui/screens/first_run/first_run_screen.tscn"
const MAIN_MENU := "res://src/ui/screens/main_menu.tscn"
const TEMP := "user://wd_profile_screen_test.json"
const SIZES := {
	"640x360": Vector2(640, 360),
	"1280x720": Vector2(1280, 720),
	"1920x1080": Vector2(1920, 1080),
	"390x844": Vector2(390, 844),
	"360x800": Vector2(360, 800),
}


func _profile() -> PlayerProfile:
	var profile := PlayerProfile.create(424242, "2026-11-07")
	profile.display_name = "Nadia"
	profile.username = "nadia_7"
	profile.username_locked = true
	profile.xp = 250
	profile.wallet.add(GameWallet.Currency.GOLD_COINS, 1200)
	profile.wallet.add(GameWallet.Currency.DIAMONDS, 150)
	return profile


func _fresh_profile() -> PlayerProfile:
	var profile := PlayerProfile.create(987654, "2026-11-07")
	profile.display_name = "Amina"
	profile.wallet.add(GameWallet.Currency.DIAMONDS, 150)
	return profile


func _mount(size: Vector2 = Vector2(1280, 720), profile: PlayerProfile = null) -> Dictionary:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: ProfileScreen = load(SCENE).instantiate()
	holder.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for _frame in 2:
		await tree.process_frame
	# A scratch store, so a test never touches the profile a player would have.
	screen.profile_store = ProfileStore.new(TEMP)
	if profile != null:
		screen.use_profile(profile)
	for _frame in 2:
		await tree.process_frame
	return {"viewport": viewport, "screen": screen, "holder": holder}


func _texts(node: Node, into: Array = []) -> Array:
	for child: Node in node.get_children():
		if child is Label:
			into.append((child as Label).text)
		_texts(child, into)
	return into


func _has_text(node: Node, needle: String) -> bool:
	for text: String in _texts(node):
		if text.contains(needle):
			return true
	return false


func _buttons(node: Node, into: Array = []) -> Array:
	for child: Node in node.get_children():
		if child is Button:
			into.append(child)
		_buttons(child, into)
	return into


func _clean() -> void:
	for path: String in [TEMP, TEMP.get_basename() + ".old.json"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- What the screen says --------------------------------------------------

func test_the_screen_shows_the_players_own_numbers() -> void:
	var profile := _profile()
	var mounted := await _mount(Vector2(1280, 720), profile)
	var screen: ProfileScreen = mounted["screen"]
	await tree.process_frame
	check_true(_has_text(screen, "Nadia"), "the display name is on the screen")
	check_true(_has_text(screen, "@nadia_7"), "so is the username")
	check_true(_has_text(screen, profile.player_id), "and the player ID from the file")
	check_true(_has_text(screen, Strings.t("profile.level", [profile.level()])),
			"the level is the profile's level")
	check_true(_has_text(screen, Strings.t("profile.wallet_gold", [1200])),
			"the Gold Coins balance is the profile's")
	check_true(_has_text(screen, Strings.t("profile.wallet_gems", [150])),
			"and so is the Red Gems balance")
	var bar: ProgressBar = screen.find_child("XPBar", true, false) as ProgressBar
	check_not_null(bar, "the XP bar exists")
	check_eq(int(bar.max_value), profile.xp_for_next_level(), "its span is the level's span")
	check_eq(int(bar.value), profile.xp_into_level(), "and its fill is the XP earned so far")
	check_true(_has_text(screen, Strings.t("profile.xp", [profile.xp_into_level(),
			profile.xp_for_next_level(), profile.level() + 1])),
			"the numbers beside the bar say the same thing")
	# Pinned to the curve itself, not only to the helpers the screen calls: 250 XP is level 1,
	# 150 XP into the 200 XP that level 2 costs.
	check_eq(profile.level(), 1, "250 XP is level 1 on the documented curve")
	check_eq(profile.xp_into_level(), 150, "150 XP earned inside it")
	check_eq(profile.xp_for_next_level(), 200, "and 200 XP in the level")
	check_eq(bar.max_value, 200.0, "which is the bar's length")
	check_true(_has_text(screen, Strings.t("profile.vip", [profile.vip()])),
			"the VIP tier comes from the level")
	(mounted["viewport"] as Node).queue_free()


func test_a_different_profile_gives_different_numbers() -> void:
	var quiet := PlayerProfile.create(1, "2026-11-07")
	quiet.display_name = "Quiet"
	quiet.xp = 0
	var busy := PlayerProfile.create(2, "2026-11-07")
	busy.display_name = "Busy"
	busy.xp = 900
	busy.wallet.add(GameWallet.Currency.GOLD_COINS, 77)
	var first := await _mount(Vector2(1024, 768), quiet)
	var quiet_texts := _texts(first["screen"])
	(first["viewport"] as Node).queue_free()
	var second := await _mount(Vector2(1024, 768), busy)
	var busy_texts := _texts(second["screen"])
	(second["viewport"] as Node).queue_free()
	check_true(_has_text_value(quiet_texts, Strings.t("profile.wallet_gold", [0])),
			"an empty wallet reads as zero")
	check_true(_has_text_value(busy_texts, Strings.t("profile.wallet_gold", [77])),
			"and a funded one reads as its balance")
	check_true(_has_text_value(busy_texts, Strings.t("profile.level", [busy.level()])),
			"the level follows the XP, not a constant")
	check_true(busy.level() > quiet.level(), "the two profiles really do differ")


func _has_text_value(texts: Array, needle: String) -> bool:
	for text: Variant in texts:
		if str(text).contains(needle):
			return true
	return false


# --- The avatars -----------------------------------------------------------

func test_twenty_avatars_are_drawn_in_code_with_a_name_each() -> void:
	check_eq(AvatarArt.COUNT, 20, "there are twenty avatars")
	check_eq(AvatarArt.NAMES.size(), AvatarArt.COUNT, "each one is named")
	check_eq(AvatarArt.COLORS.size(), AvatarArt.COUNT, "and each one has its own two colours")
	var names := {}
	var pairs := {}
	var empty := ""
	for index in AvatarArt.COUNT:
		var named := AvatarArt.name_of(index)
		if named.strip_edges().is_empty():
			empty = "avatar %d has no name" % index
		names[named] = true
		pairs["%s|%s" % [AvatarArt.ground_of(index).to_html(),
				AvatarArt.mark_of(index).to_html()]] = true
	check_eq(empty, "", "no avatar is nameless")
	check_eq(names.size(), 20, "the names are distinct")
	check_eq(pairs.size(), 20, "so are the colour pairs")
	check_true(AvatarArt.ground_of(0) != AvatarArt.ground_of(1),
			"two avatars do not draw the same ground")
	var directory := DirAccess.open("res://src/ui/profile")
	check_not_null(directory, "the avatar art lives in its own folder")
	var images := 0
	for filename: String in directory.get_files():
		if filename.get_extension() in ["png", "svg", "jpg", "jpeg", "webp"]:
			images += 1
	check_eq(images, 0, "there is not one image file under it: the art is code")


func test_every_gallery_cell_carries_a_drawing_and_its_name() -> void:
	var mounted := await _mount(Vector2(1280, 720), _profile())
	var screen: ProfileScreen = mounted["screen"]
	var gallery: AvatarGallery = screen.gallery()
	check_eq(gallery.button_count(), 20, "the grid holds every avatar")
	var problems: Array = []
	for index in gallery.button_count():
		var button: Button = gallery.button_at(index)
		var glyph := button.find_child("Glyph", true, false)
		var label := button.find_child("Label", true, false) as Label
		if glyph == null:
			problems.append("%s has no drawing" % button.name)
		if label == null or label.text != AvatarArt.name_of(index):
			problems.append("%s is not labelled %s" % [button.name, AvatarArt.name_of(index)])
		if button.tooltip_text.is_empty():
			problems.append("%s has no tooltip" % button.name)
		if button.custom_minimum_size.x + 0.5 < 48.0 or button.custom_minimum_size.y + 0.5 < 48.0:
			problems.append("%s is smaller than a finger" % button.name)
	check_eq(problems.size(), 0, "every cell is a labelled, finger-sized drawing: %s"
			% str(problems.slice(0, 4)))
	(mounted["viewport"] as Node).queue_free()
	_clean()


func test_choosing_avatars_saves_the_choice_and_marks_the_cell() -> void:
	_clean()
	var profile := _fresh_profile()
	profile.username_locked = true
	var mounted := await _mount(Vector2(1280, 720), profile)
	var screen: ProfileScreen = mounted["screen"]
	var gallery: AvatarGallery = screen.gallery()
	var seven: Button = gallery.button_at(7)
	seven.pressed.emit()
	await tree.process_frame
	check_eq(profile.avatar_id, 7, "the profile remembers the choice")
	check_eq(gallery.selected_index(), 7, "the grid marks it")
	var marks := ""
	for index in gallery.button_count():
		var mark := gallery.button_at(index).find_child("Mark", true, false) as Label
		if index == 7:
			marks = "" if mark == null else mark.text
		check_true(mark == null or index == 7 or mark.text.is_empty(),
				"only the chosen cell is ticked")
	check_eq(marks, "✓", "the chosen cell is ticked, not just tinted")
	var header := screen.find_child("HeaderAvatar", true, false) as AvatarGlyph
	check_not_null(header, "the header drawing exists")
	check_eq(header.index, 7, "and it is the avatar the player just picked")
	var reopened := ProfileStore.new(TEMP).load_or_create(1, "2026-11-07")
	var reloaded: PlayerProfile = reopened["profile"] as PlayerProfile
	check_eq(reloaded.avatar_id, 7, "the choice survives a reload from disk")
	(mounted["viewport"] as Node).queue_free()
	_clean()


# --- Renaming and its price ------------------------------------------------

func test_the_first_rename_is_free_and_the_next_shows_its_price_and_balance() -> void:
	_clean()
	var profile := _fresh_profile()
	profile.username_locked = true
	var mounted := await _mount(Vector2(1280, 720), profile)
	var screen: ProfileScreen = mounted["screen"]
	var offer := screen.name_change_offer()
	check_eq(int(offer["cost"]), 0, "the first change is free")
	check_eq(str(offer["text"]), Strings.t("profile.change_name_cost"),
			"and the screen says so in the table's words")
	check_true(_has_text(screen, Strings.t("profile.change_name_cost")),
			"the price is on the screen before the button is pressed")
	var free: Dictionary = screen.confirm_rename("Amina Two")
	check_true(bool(free["ok"]), "the free rename goes through")
	check_eq(profile.display_name, "Amina Two", "and the name changes")
	check_eq(profile.wallet.balance(GameWallet.Currency.DIAMONDS), 150,
			"without spending a single Red Gem")
	var paid: Dictionary = screen.name_change_offer()
	check_eq(int(paid["cost"]), 100, "the second change costs one hundred Red Gems")
	check_eq(int(paid["balance"]), 150, "and the offer carries the exact balance")
	check_eq(str(paid["text"]), Strings.t("profile.change_name_price", [100, 150]),
			"both numbers are in the sentence")
	check_true(_has_text(screen, Strings.t("profile.change_name_price", [100, 150])),
			"and both are shown before confirming")
	var renamed: Dictionary = screen.confirm_rename("Amina Three")
	check_true(bool(renamed["ok"]), "the paid rename goes through")
	check_eq(profile.wallet.balance(GameWallet.Currency.DIAMONDS), 50,
			"exactly one hundred Red Gems were spent")
	check_eq(profile.display_name, "Amina Three", "and the name is the new one")
	(mounted["viewport"] as Node).queue_free()
	_clean()


func test_a_rename_that_cannot_be_paid_for_does_not_happen() -> void:
	_clean()
	var profile := _fresh_profile()
	profile.username_locked = true
	profile.display_name_changes = 3
	profile.wallet.spend(GameWallet.Currency.DIAMONDS, 150)
	var mounted := await _mount(Vector2(1280, 720), profile)
	var screen: ProfileScreen = mounted["screen"]
	var offer := screen.name_change_offer()
	check_eq(int(offer["cost"]), 100, "the price is still asked")
	check_false(bool(offer["affordable"]), "but the wallet cannot meet it")
	screen.find_child("ChangeName", true, false).emit_signal("pressed")
	await tree.process_frame
	var confirm := screen.find_child("ConfirmRename", true, false) as Button
	check_not_null(confirm, "the confirmation opens")
	check_true(confirm.disabled, "with its confirm button disabled")
	var result: Dictionary = screen.confirm_rename("Amina Four")
	check_false(bool(result["ok"]), "a forced rename is still refused")
	check_eq(profile.wallet.balance(GameWallet.Currency.DIAMONDS), 0,
			"and nothing was taken")
	check_eq(profile.display_name, "Amina", "the name is untouched")
	(mounted["viewport"] as Node).queue_free()
	_clean()


# --- The username ----------------------------------------------------------

func test_a_username_says_it_is_once_and_then_cannot_change() -> void:
	var profile := _fresh_profile()
	var mounted := await _mount(Vector2(1280, 720), profile)
	var screen: ProfileScreen = mounted["screen"]
	check_true(_has_text(screen, Strings.t("first_run.profile.username_warning")),
			"the warning is shown before the player types anything")
	var field := screen.find_child("UsernameField", true, false) as LineEdit
	check_not_null(field, "the field exists while the username is unset")
	var accepted: Dictionary = screen.confirm_username("amina_9")
	check_true(bool(accepted["ok"]), "a valid username is accepted")
	check_eq(profile.username, "amina_9", "and stored")
	check_true(profile.username_locked, "and the lock is on")
	await tree.process_frame
	check_true(screen.find_child("UsernameField", true, false) == null,
			"the field is gone once the username is set")
	check_true(_has_text(screen, Strings.t("profile.username_once")),
			"the screen explains why, in the table's words")
	var again: Dictionary = screen.confirm_username("amina_10")
	check_false(bool(again["ok"]), "and a second attempt is refused")
	check_eq(profile.username, "amina_9", "leaving the first username in place")
	(mounted["viewport"] as Node).queue_free()
	_clean()


# --- What cannot be done yet ----------------------------------------------

func test_the_help_says_a_picture_cannot_be_linked_and_import_is_planned() -> void:
	var mounted := await _mount(Vector2(1280, 720), _profile())
	var screen: ProfileScreen = mounted["screen"]
	check_true(_has_text(screen, Strings.t("profile.avatar_help")),
			"the avatar help is on the screen")
	check_true(Strings.t("profile.avatar_help").contains("no picture from a link"),
			"and it says in plain words that a link cannot be used")
	check_true(_has_text(screen, Strings.t("profile.avatar_import_planned")),
			"importing a local picture is labelled PLANNED")
	check_true(Strings.t("profile.avatar_import_planned").contains("PLANNED"),
			"with that exact word")
	check_true(_has_text(screen, Strings.t("profile.achievements_planned")),
			"achievements are labelled PLANNED too")
	var source := FileAccess.get_file_as_string("res://src/ui/screens/profile/profile_screen.gd")
	check_false(source.contains("http"), "the screen never fetches anything")
	check_false(source.contains(".png"), "and loads no picture file")
	(mounted["viewport"] as Node).queue_free()
	_clean()


# --- Layout, themes, focus ------------------------------------------------

func test_the_screen_fits_every_reference_size_in_both_themes() -> void:
	var original := Settings.get_theme_id()
	var worst := ""
	for theme_id: String in ["midnight", "parchment"]:
		Settings.set_theme_id(theme_id)
		await tree.process_frame
		for label: String in SIZES:
			_clean()
			var size: Vector2 = SIZES[label]
			var mounted := await _mount(size, _profile())
			var screen: ProfileScreen = mounted["screen"]
			var viewport: SubViewport = mounted["viewport"]
			if screen.size.distance_to(size) > 1.0 and worst.is_empty():
				worst = "%s/%s: the screen is %s, not %s" % [theme_id, label,
						str(screen.size), str(size)]
			var gallery: AvatarGallery = screen.gallery()
			for index in gallery.button_count():
				var cell: Button = gallery.button_at(index)
				if (cell.size.x + 0.5 < 48.0 or cell.size.y + 0.5 < 48.0) and worst.is_empty():
					worst = "%s/%s: %s is %s" % [theme_id, label, cell.name, str(cell.size)]
			var header := screen.find_child("HeaderAvatar", true, false) as Control
			if (header == null or header.size.x + 0.5 < 48.0) and worst.is_empty():
				worst = "%s/%s: the header avatar is not finger sized" % [theme_id, label]
			var back := screen.find_child("Back", true, false) as Button
			if (back == null or back.size.y + 0.5 < DesignTokens.CONTROL_HEIGHT) \
					and worst.is_empty():
				worst = "%s/%s: Back is not a full control" % [theme_id, label]
			for button: Node in _buttons(screen):
				var control := button as Control
				if control.is_visible_in_tree() \
						and control.size.y + 0.5 < DesignTokens.CONTROL_HEIGHT \
						and worst.is_empty() and not (control is AvatarGallery):
					worst = "%s/%s: %s is %s high" % [theme_id, label, str(control.name),
							str(control.size.y)]
			(mounted["viewport"] as Node).queue_free()
			_clean()
	check_eq(worst, "", "the profile screen fits every size in both themes")
	Settings.set_theme_id(original)
	_clean()


func test_every_action_is_reachable_from_a_keyboard() -> void:
	_clean()
	var mounted := await _mount(Vector2(1280, 720), _fresh_profile())
	var screen: ProfileScreen = mounted["screen"]
	var un_focusable := ""
	for button: Node in _buttons(screen):
		var control: Button = button as Button
		if control.focus_mode != Control.FOCUS_ALL:
			un_focusable = str(control.name)
	check_eq(un_focusable, "", "every button takes keyboard focus")
	screen.focus_initial()
	await tree.process_frame
	var focused := screen.get_viewport().gui_get_focus_owner()
	if not PlatformInfo.has_touchscreen():
		check_not_null(focused, "the first action takes focus on open")
		check_true(focused is Button, "and it is a button")
	var order: Array = []
	for button: Node in _buttons(screen):
		order.append(str((button as Button).name))
	check_gte(float(order.size()), 22.0, "the grid's twenty plus the actions are all listed")
	var picked: Button = screen.gallery().button_at(3) as Button
	picked.grab_focus()
	await tree.process_frame
	check_eq(screen.get_viewport().gui_get_focus_owner(), picked,
			"focus can be moved to any avatar")
	picked.emit_signal("pressed")
	await tree.process_frame
	check_eq(screen.current_profile().avatar_id, 3, "and activating it chooses that avatar")
	(mounted["viewport"] as Node).queue_free()
	_clean()


# --- Getting there, and where the placeholder went ------------------------

func test_the_main_menu_offers_the_profile() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var menu: Control = load(MAIN_MENU).instantiate()
	holder.add_child(menu)
	for _frame in 2:
		await tree.process_frame
	var entry := menu.find_child("ProfileEntry", true, false) as Button
	check_not_null(entry, "the menu has a profile row")
	var went := [""]
	menu.connect("navigate_requested", func(screen_id: String) -> void: went[0] = screen_id)
	entry.emit_signal("pressed")
	check_eq(str(went[0]), "profile", "and pressing it asks for the profile screen")
	var application := load("res://src/app/main.gd").get_script_constant_map()
	var registered: Dictionary = application.get("SCREENS", {})
	check_true(registered.has("profile"), "the application registers the profile screen")
	(viewport as Node).queue_free()


func test_the_first_run_profile_step_shows_a_real_avatar() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var holder := Control.new()
	holder.theme = ThemeManager.current_theme()
	viewport.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var screen: FirstRunScreen = load(FIRST_RUN).instantiate()
	holder.add_child(screen)
	for _frame in 6:
		await tree.process_frame
	screen.accept_terms()
	screen.choose_notifications(false)
	for _frame in 2:
		await tree.process_frame
	var starting := screen.find_child("StartingAvatar", true, false)
	check_not_null(starting, "the profile step draws the starting avatar")
	check_true(starting is AvatarGlyph, "a drawing, not a box")
	check_true(screen.find_child("AvatarPlaceholder", true, false) == null,
			"the Task 2 placeholder is gone")
	check_true(_has_text(screen, Strings.t("first_run.profile.avatar_placeholder")),
			"and the words no longer promise a future milestone")
	check_false(Strings.t("first_run.profile.avatar_placeholder").contains("milestone"),
			"the sentence is true today")
	(viewport as Node).queue_free()
