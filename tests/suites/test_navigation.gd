extends TestCase
## End-to-end check of the application shell: the real screens are instantiated
## by the real router, navigation works, the back history is respected and the
## transition completes (or collapses when reduced motion is on).

const SCREENS := {
	"main_menu": preload("res://src/ui/screens/main_menu.tscn"),
	"settings": preload("res://src/ui/screens/settings_screen.tscn"),
	"about": preload("res://src/ui/screens/about_screen.tscn"),
	"campaign_setup": preload("res://src/ui/screens/campaign_setup.tscn"),
}


func test_router_navigates_and_returns() -> void:
	var host := Control.new()
	var overlay := ColorRect.new()
	host.add_child(overlay)
	host.theme = ThemeManager.current_theme()
	host.size = Vector2(1280, 720)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var router := ScreenRouter.new(host, overlay, SCREENS)
	self.host.add_child(host)
	host.add_child(router)

	router.start("main_menu")
	await _frames(2)
	check_eq(router.current_id(), "main_menu", "the router must start on the main menu")
	check_not_null(router.current_screen(), "the start screen must be instantiated")
	check_false(router.can_go_back(), "there is no history on the first screen")
	check_false(overlay.visible, "the transition overlay must be clear when idle")

	router.go_to("settings")
	await _frames(40)
	check_eq(router.current_id(), "settings", "navigation must reach the settings screen")
	check_true(router.can_go_back(), "navigating forward records history")
	check_false(overlay.visible, "the overlay must clear itself after a transition")

	router.go_to("campaign_setup")
	await _frames(40)
	check_eq(router.current_id(), "campaign_setup",
			"New Campaign must open the atlas setup screen")
	check_true(router.current_screen().has_signal("home_requested"),
			"the campaign screen can return to the title without stacking history")

	check_true(router.back(), "back must be available after navigating")
	await _frames(40)
	check_eq(router.current_id(), "settings", "back returns to the screen before the campaign")
	check_true(router.back(), "another back step is available")
	await _frames(40)
	check_eq(router.current_id(), "main_menu", "back reaches the title screen")
	check_false(router.can_go_back(), "history must be empty again")

	host.queue_free()


func test_screens_emit_navigation_intent() -> void:
	var menu: Control = SCREENS["main_menu"].instantiate()
	self.host.add_child(menu)
	await _frames(2)
	check_true(menu.has_signal("navigate_requested"),
			"the main menu must ask the app to navigate rather than doing it itself")
	var new_campaign: Button = menu.get_node("%NewCampaign")
	check_false(new_campaign.disabled, "New Campaign must be reachable")
	var about_row: Button = menu.get_node("%AboutEntry")
	check_false(about_row.disabled, "About & Credits must be reachable")
	menu.queue_free()


func _frames(count: int) -> void:
	for _i in count:
		await tree.process_frame
