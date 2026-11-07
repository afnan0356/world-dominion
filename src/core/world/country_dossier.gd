class_name CountryDossier
extends RefCounted
## The readable, structured description of one country: everything the atlas
## records, split into sections, with every gap stated instead of hidden.
##
## This is deliberately *data*, not UI. The panel only walks the sections and
## renders them; a future screen (war room, diplomacy, intel) can build the same
## dossier and read the same fields. That keeps the knowledge in one place and
## makes "does the panel show only sourced values?" an assertable question.
##
## Sections that the project has not implemented yet (population, economy,
## government, military, diplomacy, resources, society) are returned by
## `planned_sections()` with `planned = true` and no fields at all. They exist so
## the panel can say "not implemented" truthfully, and so adding one later is a
## data change plus a loader — not a redesign.

## Section identifiers, in display order.
## How a code's status reads in a sentence. The wording is chosen so that a player is
## never left thinking a code is official when it is not, and never sees a gap filled in.
const CODE_STATUS_WORDS := {
	"iso-official": "officially assigned",
	"user-assigned": "widely used, but not officially assigned",
	"none": "the source has no code of its own for this unit",
}


const OVERVIEW := "overview"
const GEOGRAPHY := "geography"
const ADMINISTRATION := "administration"
## Sourced population / GDP / area. Read-only reference figures for the scenario
## start; the simulation does not read them and nothing here varies over time.
const KEY_FIGURES := "key_figures"
const SOURCES := "sources"
## What this record does and does not contain. It is a list of facts, never a score:
## a percentage would imply a completeness that no dataset can have.
const COMPLETENESS := "completeness"

const RECORDED_SECTIONS: PackedStringArray = [OVERVIEW, GEOGRAPHY, ADMINISTRATION,
		KEY_FIGURES, SOURCES, COMPLETENESS]

const KEY_FIGURES_NOTE := ("Baseline reference data for the 2026 scenario start, not live. "
		+ "Each figure shows the year its source records it for; a figure the source "
		+ "does not give stays “Not available” and is never shown as zero.")
## Source `type` values that make a record's legal status uncertain in the
## dataset. Records with these types get one neutral sentence saying that the
## status follows the source; no place is named in code.
const UNCERTAIN_STATUS_TYPES: PackedStringArray = ["Disputed", "Indeterminate"]
const SOURCE_STATUS_NOTE := ("Status and boundaries follow the pinned Natural Earth "
		+ "dataset. That is this dataset's convention, not an official position of "
		+ "this project on any sovereignty or boundary question.")

## [id, title] of the sections this milestone does not implement.
const PLANNED_SECTION_DEFS := [
	["population", "Population"],
	["economy", "National economy"],
	["government", "Government & politics"],
	["military", "Military"],
	["diplomacy", "Diplomacy"],
	["resources", "Natural resources"],
	["society", "Society"],
]

## One label/value pair. `recorded` is false when the source has no value; the
## value then says so in words and the panel styles it as a gap.
class Field extends RefCounted:
	var label := ""
	var value := ""
	var recorded := true

	static func make(field_label: String, field_value: String,
			is_recorded: bool = true) -> Field:
		var field := Field.new()
		field.label = field_label
		field.value = field_value
		field.recorded = is_recorded
		return field


## A titled group of fields. Planned sections carry no fields: an empty planned
## section is honest, invented placeholder numbers are not.
class Section extends RefCounted:
	var id := ""
	var title := ""
	var fields: Array[Field] = []
	var planned := false
	var note := ""

	static func make(section_id: String, section_title: String,
			section_fields: Array[Field] = []) -> Section:
		var section := Section.new()
		section.id = section_id
		section.title = section_title
		section.fields = section_fields
		return section

	static func planned_section(section_id: String, section_title: String) -> Section:
		var section := Section.make(section_id, section_title)
		section.planned = true
		section.note = "Not implemented: no dataset is loaded for this section yet."
		return section


var country_id := ""
var title := ""
var subtitle := ""
var sections: Array[Section] = []


## Builds a dossier for `record`. `context` may carry the atlas facts that the
## record itself does not own: `polygons`, `rings`, `vertices`, `dataset`,
## `dataset_version`, `dataset_commit`, `licence`, `retrieved`, `scale`.
static func build(record: CountryRecord, context: Dictionary = {}) -> CountryDossier:
	var dossier := CountryDossier.new()
	if record == null:
		return dossier
	dossier.country_id = record.id
	dossier.title = record.name
	dossier.subtitle = record.name_long if record.name_long != record.name else ""
	dossier.sections = [
		_overview(record, context),
		_geography(record, context),
		_administration(record),
		_key_figures(record, context),
		_sources(context),
		_completeness(record, context),
	]
	return dossier


## True when the dataset's own `type` is one whose status it leaves open. The
## check reads the type string only — there is no list of country ids anywhere.
static func has_uncertain_status(record: CountryRecord) -> bool:
	return record != null and UNCERTAIN_STATUS_TYPES.has(record.type)


static func planned_sections() -> Array[Section]:
	var out: Array[Section] = []
	for entry: Array in PLANNED_SECTION_DEFS:
		out.append(Section.planned_section(str(entry[0]), str(entry[1])))
	return out


static func _overview(record: CountryRecord, context: Dictionary = {}) -> Section:
	var fields: Array[Field] = [
		_text_field("Region", record.region),
		_text_field("Subregion", record.subregion),
		_text_field("Dataset classification", record.type),
	]
	if record.sovereignty != record.name:
		fields.append(_text_field("Source records sovereignty as", record.sovereignty))
	if not record.note.is_empty():
		fields.append(Field.make("Source note", record.note))
	var status := str(CODE_STATUS_WORDS.get(record.code_status, "not recorded"))
	fields.append(Field.make("Code status", status, record.code_status == "iso-official"))
	var catalog: CurrencyCatalog = context.get("currency") as CurrencyCatalog
	if catalog != null and catalog.is_loaded():
		fields.append(Field.make("Currency", catalog.describe(record.id),
				catalog.has(record.id)))
	var section := Section.make(OVERVIEW, "Identity", fields)
	if has_uncertain_status(record):
		section.note = SOURCE_STATUS_NOTE
	elif record.is_political_edge_case():
		section.note = ("The dataset files this unit as “%s”. Its classification is "
				+ "reproduced as recorded; this project does not decide sovereignty.") % record.type
	return section


static func _geography(record: CountryRecord, context: Dictionary) -> Section:
	var fields: Array[Field] = []
	fields.append(Field.make("Map extent", extent_label(record.bbox)))
	if context.has("polygons"):
		var polygons := int(context["polygons"])
		var rings := int(context.get("rings", polygons))
		var vertices := int(context.get("vertices", 0))
		fields.append(Field.make("Landmasses", "%d %s" % [polygons,
				"polygon" if polygons == 1 else "polygons"]))
		fields.append(Field.make("Rings", str(rings)))
		if vertices > 0:
			fields.append(Field.make("Vertices", str(vertices)))
	if context.has("scale"):
		fields.append(Field.make("Geometry resolution",
					"quantised to 1/%d° (≈%.0f m at the equator)"
					% [int(context["scale"]), 111_320.0 / float(context["scale"])]))
	if record.has_label:
		fields.append(Field.make("Label anchor", format_position(record.label)))
	var section := Section.make("geography", "Geography", fields)
	if fields.size() <= 1:
		section.note = "Geometry for this unit is not loaded."
	return section


static func _administration(record: CountryRecord) -> Section:
	var fields: Array[Field] = []
	fields.append(_text_field("ISO alpha-3", record.iso_a3))
	fields.append(_text_field("ISO alpha-2", record.iso_a2))
	fields.append(_text_field("Capital", record.capital))
	if record.has_capital_point:
		fields.append(Field.make("Capital location", format_position(record.capital_point)))
	fields.append(_text_field("Stable ID", record.id))
	return Section.make("administration", "Administrative", fields)


## The three sourced figures, with their as-of year and their source. `context`
## carries a `CountryStatistics` instance when one is loaded; without it the group
## says so instead of pretending the source has nothing.
static func _key_figures(record: CountryRecord, context: Dictionary) -> Section:
	var statistics: CountryStatistics = context.get("statistics") as CountryStatistics
	var fields: Array[Field] = []
	if statistics == null or not statistics.is_loaded():
		var section := Section.make(KEY_FIGURES, "Key figures", fields)
		section.note = "No sourced figures are loaded in this build. Nothing is estimated."
		return section
	for definition: Dictionary in statistics.definitions():
		var key := str(definition["key"])
		var has_value: bool = statistics.value(record.id, key) != null
		var label := str(definition["label"])
		if statistics.is_derived(record.id, key):
			label += " (derived)"
		fields.append(Field.make(label, statistics.describe(record.id, definition), has_value))
	var source: Dictionary = statistics.source
	var source_line := str(source.get("dataset", "the statistics source"))
	var version := str(source.get("version", ""))
	if not version.is_empty():
		source_line += " " + version
	var retrieved := str(source.get("retrieved", ""))
	if not retrieved.is_empty():
		source_line += ", retrieved " + retrieved
	fields.append(Field.make("Source", source_line))
	var figures := Section.make(KEY_FIGURES, "Key figures", fields)
	figures.note = KEY_FIGURES_NOTE
	return figures


static func _sources(context: Dictionary) -> Section:
	var fields: Array[Field] = []
	var dataset := str(context.get("dataset", "Natural Earth 1:50m Admin 0 Countries"))
	fields.append(Field.make("Dataset", dataset))
	fields.append(_text_field("Dataset version", str(context.get("dataset_version", ""))))
	if context.has("dataset_commit"):
		var commit := str(context["dataset_commit"])
		fields.append(Field.make("Source commit", commit.substr(0, 10)))
	fields.append(_text_field("Licence", str(context.get("licence", ""))))
	fields.append(_text_field("Retrieved", str(context.get("retrieved", ""))))
	var section := Section.make("sources", "Data sources", fields)
	section.note = ("Names, codes, classification and outlines come from this dataset. "
			+ "Values it does not record are listed as gaps; none are estimated.")
	return section


## The gaps in one record, in plain words. Every line is something the dataset
## either contains or does not; nothing here is inferred, averaged or scored.
static func _completeness(record: CountryRecord, context: Dictionary) -> Section:
	var fields: Array[Field] = [
		_text_field("ISO alpha-2", record.iso_a2),
		_text_field("ISO alpha-3", record.iso_a3),
		_text_field("Capital city", record.capital),
	]
	fields.append(Field.make("Capital location",
			"Recorded" if record.has_capital_point else "Not recorded in source",
			record.has_capital_point))
	fields.append(Field.make("Label position",
			"Recorded" if record.has_label else "Not recorded in source",
			record.has_label))
	if context.has("vertices"):
		var vertices := int(context["vertices"])
		fields.append(Field.make("Outline detail", "%d points" % vertices, vertices > 0))
	var section := Section.make("completeness", "Data completeness", fields)
	section.note = ("This is a list of what the dataset contains, not a score. "
			+ "Nothing here is estimated to fill a gap, and no percentage is calculated —"
			+ " the generated report in docs/DATA_COMPLETENESS.md counts the same gaps "
			+ "across all 242 records.")
	return section


## Human-readable extent, e.g. "20.7°N – 26.6°N · 88.0°E – 92.7°E".
static func extent_label(bbox: Rect2) -> String:
	if bbox.size.x <= 0.0 or bbox.size.y <= 0.0:
		return "Not recorded in source"
	return "%s – %s · %s – %s" % [
		_latitude(bbox.position.y), _latitude(bbox.end.y),
		_longitude(bbox.position.x), _longitude(bbox.end.x),
	]


static func format_position(point: Vector2) -> String:
	return "%s %s" % [_latitude(point.y), _longitude(point.x)]


static func _latitude(value: float) -> String:
	return "%.1f°%s" % [absf(value), "N" if value >= 0.0 else "S"]


static func _longitude(value: float) -> String:
	return "%.1f°%s" % [absf(value), "E" if value >= 0.0 else "W"]


## A field whose value is empty becomes an explicit gap. Nothing here substitutes
## a plausible number for a missing one.
static func _text_field(label: String, value: String) -> Field:
	if value.is_empty():
		return Field.make(label, "Not recorded in source", false)
	return Field.make(label, value)


# --- Queries used by the UI and the tests ----------------------------------

func section(section_id: String) -> Section:
	for entry: Section in sections:
		if entry.id == section_id:
			return entry
	return null


## Every field that the source does not provide, as "Section/label" strings.
func missing_fields() -> PackedStringArray:
	var out := PackedStringArray()
	for entry: Section in sections:
		for field: Field in entry.fields:
			if not field.recorded:
				out.append("%s/%s" % [entry.id, field.label])
	return out


func field_count() -> int:
	var total := 0
	for entry: Section in sections:
		total += entry.fields.size()
	return total
