class_name PlannedPanel
extends ModalPanel
## The panel a category opens when nothing behind it is built yet (Milestone 10, Task 3).
##
## Six of the seven categories on the bottom bar — Economy, Government, Diplomacy, Military,
## Research and World — have no gameplay in this build, and this panel says so in one short
## paragraph. That is the whole feature: a button that answers honestly instead of doing
## nothing, and a screen that never shows a number it cannot source.
##
## It deliberately contains no placeholder figures, no greyed-out controls and no "coming
## soon" badge over a mock interface. A player who presses Economy learns that economy is not
## in this version, in the same words the rest of the game uses for the same fact.


func prepare(category_id: String, label: String) -> void:
	build(Strings.t("hud.category_hint", [label]))
	var body := Label.new()
	body.name = "Body"
	body.text = Strings.t("category.later_body")
	body.theme_type_variation = &"BodySmall"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content().add_child(body)
	var status := Label.new()
	status.name = "Status"
	status.text = Strings.t("planned_badge")
	status.theme_type_variation = &"Eyebrow"
	content().add_child(status)
	category = category_id
	add_action(Strings.t("panel.close"), Callable(), true)

