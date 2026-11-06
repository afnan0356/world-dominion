class_name Shortcuts
extends RefCounted
## Every keyboard shortcut in the build, in one list.
##
## The cheat sheet screen renders this table and the tests read the same table, so a
## shortcut that exists cannot be missing from the sheet and the sheet cannot claim a
## shortcut that does nothing. Mouse and touch never need a shortcut: every action
## listed here is also a visible control.

## [keys, what it does, where it works]
const ENTRIES := [
	["Esc", "Go back, or close the open panel", "everywhere"],
	["Tab / Shift+Tab", "Move focus forward or back", "everywhere"],
	["Enter or Space", "Activate the focused control", "everywhere"],
	["F1", "Open or close this shortcut sheet", "everywhere"],
	["F3", "Show or hide the performance overlay", "everywhere"],
	["Space", "Pause or resume the clock", "campaign"],
	["1 2 3", "Set speed: Normal, Fast-forward, and the VIP speed (VIP 5 and above)",
			"campaign"],
	["F4", "Show or hide the map inspector", "campaign"],
	["+ / -", "Zoom the map in or out", "map"],
	["0", "Reset the map view", "map"],
]

const TITLE := "Keyboard shortcuts"
const INTRO := ("Every action below is also available with a mouse or a touch screen. "
		+ "Nothing in this build requires a keyboard.")
