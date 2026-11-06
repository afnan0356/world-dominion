extends Control
## Application root.
##
## Wires the persistent chrome (backdrop, transition overlay) to a `ScreenRouter`
## that owns screen lifetime. Screens stay decoupled from each other: they emit
## intent ("navigate to settings", "go back", "quit") and the root decides what
## that means.

const SCREENS := {
	"main_menu": preload("res://src/ui/screens/main_menu.tscn"),
	"campaign_setup": preload("res://src/ui/screens/campaign_setup.tscn"),
	"game": preload("res://src/ui/screens/game_screen.tscn"),
	"load_game": preload("res://src/ui/screens/load_game_screen.tscn"),
	"settings": preload("res://src/ui/screens/settings_screen.tscn"),
	"about": preload("res://src/ui/screens/about_screen.tscn"),
	"about_data": preload("res://src/ui/screens/about_data_screen.tscn"),
	"comparison": preload("res://src/ui/screens/comparison_screen.tscn"),
	"shortcuts": preload("res://src/ui/screens/shortcuts_screen.tscn"),
	"first_run": preload("res://src/ui/screens/first_run/first_run_screen.tscn"),
}
const START_SCREEN := "main_menu"

var _router: ScreenRouter
var _performance_overlay: PerformanceOverlay

@onready var _host: Control = %ScreenHost
@onready var _overlay: ColorRect = %TransitionOverlay


func _ready() -> void:
	_router = ScreenRouter.new(_host, _overlay, SCREENS)
	add_child(_router)
	_performance_overlay = PerformanceOverlay.new()
	add_child(_performance_overlay)
	_router.screen_changed.connect(_on_screen_changed)
	# First launch shows the terms and the profile step; after that the menu opens directly.
	var start := START_SCREEN
	if FirstRunStore.decide_start() == FirstRunStore.START_FIRST_RUN:
		start = "first_run"
	_router.start(start)


func _process(_delta: float) -> void:
	# The overlay asks the visible screen for its map counts; a screen without a
	# map simply does not implement the method.
	if _performance_overlay == null or not _performance_overlay.visible or _router == null:
		return
	var screen := _router.current_screen()
	if screen != null and screen.has_method("performance_counts"):
		_performance_overlay.set_map_counts(str(screen.call("performance_counts")))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_F1:
		# In a campaign the game screen owns this key, because there the sheet is a
		# panel over the campaign rather than a screen that would unload it.
		if _router.current_id() != "game":
			if _router.current_id() == "shortcuts":
				_router.back()
			else:
				_router.go_to("shortcuts")
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_F3:
		Settings.toggle_performance_overlay()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if _router.can_go_back() and not _router.is_transitioning():
		_router.back()
		get_viewport().set_input_as_handled()


func _on_screen_changed(_screen_id: String) -> void:
	var screen := _router.current_screen()
	if screen == null:
		return
	# Screens announce intent through signals; the root owns the response.
	if screen.has_signal("navigate_requested"):
		screen.connect("navigate_requested", _on_navigate_requested)
	if screen.has_signal("navigation_requested"):
		screen.connect("navigation_requested", _on_navigation_requested)
	if screen.has_signal("back_requested"):
		screen.connect("back_requested", _on_back_requested)
	if screen.has_signal("quit_requested"):
		screen.connect("quit_requested", _on_quit_requested)
	if screen.has_signal("home_requested"):
		screen.connect("home_requested", _on_home_requested)


func _on_navigate_requested(screen_id: String) -> void:
	_router.go_to(screen_id)


## Navigation that carries instructions: used by Settings to ask the campaign
## screen to run the developer stress test.
func _on_navigation_requested(screen_id: String, params: Dictionary) -> void:
	_router.go_to(screen_id, true, params)


func _on_back_requested() -> void:
	_router.back()


func _on_quit_requested() -> void:
	get_tree().quit()


## "Return to title" from the campaign brief: go back to the hub without
## stacking the setup screen in the back history.
func _on_home_requested() -> void:
	_router.go_to(START_SCREEN, false)
