extends ResponsiveScreen
## About the data.
##
## Every value on this screen is read from `data/world/manifest.json` — the same
## generated file the map loads — so the page cannot describe a dataset version the
## build is not shipping. The one written sentence is the neutral note about
## disputed status, and it names no country: the dataset's own classification says
## which places it leaves open, not this project.

signal back_requested()

const DISPUTED_NOTE := ("Some places are classified in the source dataset in ways that "
		+ "reflect the dataset's own editorial choices. This project follows the source "
		+ "as it is, draws no border on its own authority, and takes no position on any "
		+ "sovereignty or boundary question. Where the dataset records a status, the "
		+ "dossier shows it as a recorded value.")

var _manifest: Dictionary = {}

@onready var _header: AppHeader = %Header
@onready var _content: VBoxContainer = %Content


func _ready() -> void:
	super()
	_header.back_pressed.connect(func() -> void: back_requested.emit())
	_manifest = WorldAtlas.load_default().manifest
	_build_content()


func on_layout_changed(_mode: int, is_short: bool, view_size: Vector2) -> void:
	_header.set_compact(is_short)
	var margin := DesignTokens.screen_margin(DesignTokens.layout_mode(view_size))
	var available := view_size.x - float(margin * 2) - DesignTokens.SPACE_24
	_content.custom_minimum_size.x = clampf(available, 240.0,
			DesignTokens.CONTENT_MEASURE)


## What the screen is showing, for the tests: the values a reader can check against
## the manifest file.
func facts() -> Dictionary:
	var source: Dictionary = _manifest.get("source", {})
	var counts: Dictionary = _manifest.get("counts", {})
	return {
		"dataset": str(source.get("dataset", "")),
		"version": str(source.get("version", "")),
		"licence": str(source.get("licence", "")),
		"commit": str(source.get("commit", "")),
		"countries": int(counts.get("countries", 0)),
	}


func _build_content() -> void:
	var source: Dictionary = _manifest.get("source", {})
	var counts: Dictionary = _manifest.get("counts", {})
	_add_heading("Source")
	_add_row("Dataset", str(source.get("dataset", "Not recorded")))
	_add_row("Version", str(source.get("version", "Not recorded")))
	_add_row("Retrieved", str(source.get("retrieved", "Not recorded")))
	_add_row("Repository", str(source.get("repository", "Not recorded")))
	_add_row("Commit", str(source.get("commit", "")).substr(0, 12))
	_add_heading("Licence and attribution")
	_add_row("Licence", str(source.get("licence", "Not recorded")))
	_add_paragraph("Natural Earth is public domain. Attribution is not required by "
			+ "its terms; it is given here because a reader deserves to know where the "
			+ "lines on the map came from.")
	_add_heading("What this build contains")
	_add_row("Countries and territories", "%d records" % int(counts.get("countries", 0)))
	_add_row("Polygons", "%d" % int(counts.get("polygons", 0)))
	_add_row("Outline points", "%d" % int(counts.get("vertices", 0)))
	_add_row("Capital locations", "%d recorded" % int(counts.get("capital_points", 0)))
	_add_heading("Boundaries and status")
	_add_paragraph(DISPUTED_NOTE)
	for limitation: Variant in _manifest.get("known_limitations", []):
		_add_paragraph(str(limitation), true)


## Nothing on this page links anywhere: every value is already on it, and a link to a
## document would be a link the player cannot open inside the game.
func _add_heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Eyebrow"
	_content.add_child(label)


func _add_row(label_text: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SPACE_16)
	var key := Label.new()
	key.text = label_text
	key.theme_type_variation = &"FieldLabel"
	key.custom_minimum_size.x = 220.0
	row.add_child(key)
	var val := Label.new()
	val.text = value
	val.theme_type_variation = &"BodySmall"
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(val)
	_content.add_child(row)


func _add_paragraph(text: String, caption: bool = false) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"Caption" if caption else &"Body"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(label)
