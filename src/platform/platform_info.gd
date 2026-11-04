class_name PlatformInfo
extends RefCounted
## The single place where the interface is allowed to ask "what am I running on?".
##
## Keeping these questions here means screens can adapt without sprinkling
## `OS.has_feature()` checks through gameplay code, and future platform-specific
## work (safe-area insets on notched phones, iOS signing, store builds) has one
## obvious home under src/platform/.

## Desktop runtime (Windows, macOS, Linux).
static func is_desktop() -> bool:
	return OS.has_feature("pc")


## Whether an in-app "Quit" action is appropriate. iOS discourages (and the App
## Store rejects) programmatic quitting, and Android's back gesture already
## handles it, so the main menu only offers Quit on desktop.
static func offers_quit_action() -> bool:
	return is_desktop()


## Human-readable platform name for the About screen and bug reports.
static func describe() -> String:
	return OS.get_name()


## True when a touchscreen is present. Used by the input guidance line; the
## interface itself supports touch, mouse and keyboard at the same time.
static func has_touchscreen() -> bool:
	return DisplayServer.is_touchscreen_available()


## Name of the active renderer, reported in the About screen. Useful when
## players report rendering problems on a specific device.
static func rendering_driver() -> String:
	return RenderingServer.get_current_rendering_method()
