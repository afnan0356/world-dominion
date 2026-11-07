class_name RoadmapItems
extends RefCounted
## The Roadmap screen's content, in one table (Milestone 09, Task 5).
##
## Every item is traceable to the project's own documents: `source_file` plus a `source_quote`
## that must appear in it. A test reads the file and fails if the quote is gone, so a roadmap
## item cannot outlive the decision it came from.
##
## Statuses are deliberately three, not two:
##   * `PLANNED` — the project intends to build it (the design documents say so).
##   * `NOT PLANNED` — the vision explicitly rules it out. Online multiplayer is the case:
##     `docs/GAME_VISION.md` says there is no plan for it, so calling it "planned" here would be
##     a promise the documents do not make. Planned multiplayer is hot-seat, listed below.
##   * `OPEN QUESTION` — the owner has not decided; the vision lists it as a question.
##
## `evidence` is the list of files that would prove an item *implemented*. Nothing is
## implemented today, so every entry is empty — and the test fails if an item ever claims
## `IMPLEMENTED` without files that exist. That is the guard the milestone asks for, kept even
## while the list is all future work.

const STATUS_PLANNED := "PLANNED"
const STATUS_NOT_PLANNED := "NOT PLANNED"
const STATUS_OPEN := "OPEN QUESTION"
const STATUS_IMPLEMENTED := "IMPLEMENTED"

const ITEMS := [
	{
		"title_key": "roadmap.multiplayer",
		"body_key": "roadmap.multiplayer_body",
		"status": STATUS_NOT_PLANNED,
		"source_file": "docs/GAME_VISION.md",
		"source_quote": "There is no plan for online multiplayer",
		"evidence": [],
	},
	{
		"title_key": "roadmap.notifications",
		"body_key": "roadmap.notifications_body",
		"status": STATUS_PLANNED,
		"source_file": "docs/GAME_VISION.md",
		"source_quote": "no push notifications to pull you back",
		"evidence": [],
	},
	{
		"title_key": "roadmap.mods",
		"body_key": "roadmap.mods_body",
		"status": STATUS_PLANNED,
		"source_file": "docs/GAME_VISION.md",
		"source_quote": "mods change data, never execute code",
		"evidence": [],
	},
	{
		"title_key": "roadmap.achievements",
		"body_key": "roadmap.achievements_body",
		"status": STATUS_PLANNED,
		"source_file": "GAME_DESIGN.md",
		"source_quote": "Long-horizon goals, achievements, scenario outcomes",
		"evidence": [],
	},
	{
		"title_key": "roadmap.religion",
		"body_key": "roadmap.religion_body",
		"status": STATUS_OPEN,
		"source_file": "docs/GAME_VISION.md",
		"source_quote": "Religion: model it, or keep the game neutral?",
		"evidence": [],
	},
	{
		"title_key": "roadmap.economy",
		"body_key": "roadmap.economy_body",
		"status": STATUS_PLANNED,
		"source_file": "GAME_DESIGN.md",
		"source_quote": "GDP, budget, taxation, trade, inflation, unemployment, debt",
		"evidence": [],
	},
	{
		"title_key": "roadmap.diplomacy",
		"body_key": "roadmap.diplomacy_body",
		"status": STATUS_PLANNED,
		"source_file": "GAME_DESIGN.md",
		"source_quote": "Relations, treaties, alliances, sanctions, blocs, negotiations",
		"evidence": [],
	},
	{
		"title_key": "roadmap.un",
		"body_key": "roadmap.un_body",
		"status": STATUS_PLANNED,
		"source_file": "ROADMAP.md",
		"source_quote": "UN mechanics",
		"evidence": [],
	},
]


static func statuses() -> PackedStringArray:
	var out := PackedStringArray([STATUS_PLANNED, STATUS_NOT_PLANNED, STATUS_OPEN,
			STATUS_IMPLEMENTED])
	return out
