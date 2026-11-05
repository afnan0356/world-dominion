extends Node
## Holds the campaign that is currently being played, and the world atlas.
##
## Why an autoload rather than a field on a screen: the pause menu can open
## Settings, the Load screen and the game screen itself, and each of those is a
## separate scene. If the campaign lived in a screen, visiting Settings would
## destroy it mid-campaign. One explicit holder also makes "leaving the campaign"
## a single, testable operation (`close()`), which is what keeps repeated
## enter/leave cycles from leaking state.
##
## It holds no save data on disk of its own: `store` is a `SaveStore` pointed at
## the game's save folder, and every write goes through it.

var atlas: WorldAtlas
var session: GameSession
var store := SaveStore.new()


## Loads the world atlas once and shares it. Starting a campaign and opening the
## Load screen both need it, and loading it twice would cost ~60 ms for nothing.
func get_atlas() -> WorldAtlas:
	if atlas == null:
		atlas = WorldAtlas.load_default()
	return atlas


func has_session() -> bool:
	return session != null


func current_session() -> GameSession:
	return session


## Starts a new campaign from a validated configuration.
func start(config: CampaignConfig, seed_value: int = -1) -> GameSession:
	close()
	session = GameSession.start_new(config, get_atlas(), store, seed_value)
	return session


## Loads `slot` and makes it the active campaign. Returns the save layer's result
## so the caller can show the precise reason a save was refused.
func resume(slot: String) -> Dictionary:
	var result := GameSession.resume(slot, get_atlas(), store)
	if bool(result["ok"]):
		session = result["session"]
	return result


## Ends the active campaign. Nothing is written here: the caller decides whether to
## autosave first, because "quit and lose progress" must stay a visible choice.
func close() -> void:
	session = null


func has_valid_save() -> bool:
	return store.has_any_valid(get_atlas().registry)


func latest_slot() -> String:
	return store.latest_valid_slot(get_atlas().registry)


func slot_entries() -> Array:
	return store.list_slots(get_atlas().registry)
