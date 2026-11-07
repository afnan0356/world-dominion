class_name HelpSections
extends RefCounted
## The Help screen's content, in one table (Milestone 09, Task 5).
##
## Help must only describe things a player can actually reach. Each section therefore declares
## its evidence: the screen ids it points at and the files that implement what it claims. The
## test resolves every screen id against the application's own screen table
## (`src/app/main.gd`) and checks every file exists, so a sentence about a screen that was
## removed — or never built — fails the suite instead of shipping.
##
## `prose_only` is the exception, and it is a short list on purpose: the two sections that
## explain *scope* (what this build is, and why there is no account) describe a decision, not a
## feature, so there is nothing to link to. Every other section must have evidence.

const SECTIONS := [
	{
		"title_key": "help.status_title",
		"body_key": "help.status_body",
		"screens": [],
		"files": [],
		"prose_only": true,
	},
	{
		"title_key": "help.can_do_title",
		"body_key": "help.can_do_body",
		"screens": ["campaign_setup", "game"],
		"files": ["res://src/ui/components/country_picker_panel.gd",
				"res://src/ui/tutorial/tutorial_steps.gd",
				"res://src/ui/components/country_info_panel.gd"],
		"prose_only": false,
	},
	{
		"title_key": "help.saving_title",
		"body_key": "help.saving_body",
		"screens": ["worlds", "backup"],
		"files": ["res://src/core/save/save_store.gd", "res://src/core/profile/backup_bundle.gd"],
		"prose_only": false,
	},
	{
		"title_key": "help.account_title",
		"body_key": "help.account_body",
		"screens": [],
		"files": [],
		"prose_only": true,
	},
	{
		"title_key": "help.notifications_title",
		"body_key": "help.notifications_body",
		"screens": ["settings"],
		"files": ["res://src/core/profile/first_run_store.gd"],
		"prose_only": false,
	},
	{
		"title_key": "help.report_title",
		"body_key": "help.report_body",
		"screens": ["diagnostics"],
		"files": ["res://src/core/diagnostics/diagnostics_report.gd",
				"res://src/core/diagnostics/diagnostics_log.gd"],
		"prose_only": false,
	},
]

## How a screen the section points at is named on its button.
const SCREEN_LABELS := {
	"campaign_setup": "New campaign",
	"game": "Campaign",
	"worlds": "Your worlds",
	"backup": "Backup and restore",
	"settings": "Settings",
	"diagnostics": "Diagnostics",
}


static func label_for(screen_id: String) -> String:
	return str(SCREEN_LABELS.get(screen_id, screen_id))
