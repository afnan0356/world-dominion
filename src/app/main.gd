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
	"settings": preload("res://src/ui/screens/settings_screen.tscn"),
	"about": preload("res://src/ui/screens/about_screen.tscn"),
}
const START_SCREEN := "main_menu"

var _router: ScreenRouter

@onready var _host: Control = %ScreenHost
@onready var _overlay: ColorRect = %TransitionOverlay


func _ready() -> void:
	_router = ScreenRouter.new(_host, _overlay, SCREENS)
	add_child(_router)
	_router.screen_changed.connect(_on_screen_changed)
	_router.start(START_SCREEN)


func _unhandled_input(event: InputEvent) -> void:
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
	if screen.has_signal("back_requested"):
		screen.connect("back_requested", _on_back_requested)
	if screen.has_signal("quit_requested"):
		screen.connect("quit_requested", _on_quit_requested)
	if screen.has_signal("home_requested"):
		screen.connect("home_requested", _on_home_requested)


func _on_navigate_requested(screen_id: String) -> void:
	_router.go_to(screen_id)


func _on_back_requested() -> void:
	_router.back()


func _on_quit_requested() -> void:
	get_tree().quit()


## "Return to title" from the campaign brief: go back to the hub without
## stacking the setup screen in the back history.
func _on_home_requested() -> void:
	_router.go_to(START_SCREEN, false)
