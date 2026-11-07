extends TestCase
## The research notes (Milestone 09, Task 11).
##
## A research note is allowed to say "we do not know". It is not allowed to say a figure, or
## to describe a source's licence or coverage, without having consulted it. These tests hold
## that line: every candidate source carries one of the three status words, nothing is marked
## `CONSULTED` without a URL, licence and retrieval date, and every note says out loud that
## nothing in it is implemented.

const FOLDER := "res://docs/research"
const NOTES := ["README.md", "RESOURCES.md", "POLITICS.md"]
const STATUSES := ["`CONSULTED`", "`UNVERIFIED`", "`NOT AVAILABLE`"]

## Words that mark a table row as a candidate source.


func _note(name: String) -> String:
	return FileAccess.get_file_as_string(FOLDER.path_join(name))


func _source_rows(text: String) -> Array[String]:
	var rows: Array[String] = []
	for line: String in text.split("\n"):
		if not line.begins_with("| "):
			continue
		for status: String in STATUSES:
			if line.contains(status):
				rows.append(line)
				break
	return rows


func test_every_note_exists_and_is_indexed() -> void:
	var index := FileAccess.get_file_as_string("res://docs/INDEX.md")
	for name: String in NOTES:
		check_true(FileAccess.file_exists(FOLDER.path_join(name)), "%s exists" % name)
		check_true(index.contains("research/%s" % name), "the index lists %s" % name)
	var method := _note("README.md")
	for status: String in STATUSES:
		check_true(method.contains(status), "the method note defines %s" % status)


func test_every_candidate_source_carries_exactly_one_status() -> void:
	for name: String in ["RESOURCES.md", "POLITICS.md"]:
		var rows := _source_rows(_note(name))
		check_gte(float(rows.size()), 3.0, "%s lists candidate sources" % name)
		for row: String in rows:
			var count := 0
			for status: String in STATUSES:
				if row.contains(status):
					count += 1
			check_eq(count, 1, "one status per source row: %s" % row.substr(0, 60))


func test_no_source_is_called_consulted_without_its_provenance() -> void:
	for name: String in ["RESOURCES.md", "POLITICS.md"]:
		var text := _note(name)
		for row: String in _source_rows(text):
			if not row.contains("`CONSULTED`"):
				continue
			check_true(row.contains("http"), "a consulted source names its URL: %s"
					% row.substr(0, 60))
			check_true(row.to_lower().contains("licence"),
					"a consulted source states its licence: %s" % row.substr(0, 60))


func test_the_notes_say_that_nothing_here_is_implemented() -> void:
	for name: String in ["RESOURCES.md", "POLITICS.md"]:
		var text := _note(name).to_lower()
		check_true(text.contains("nothing here is implemented")
				or text.contains("nothing in it is implemented"),
				"%s states that it is research, not a feature" % name)
		check_true(text.contains("not known") or text.contains("unknown")
				or text.contains("deliberately not written"),
				"%s names what it does not know" % name)


func test_the_notes_do_not_pretend_to_hold_numbers() -> void:
	# A research note may quote no figure for a country: that would be a data claim without
	# a downloaded file behind it. Currency codes and years in prose are fine; a percentage
	# or a per-country quantity is not.
	for name: String in ["RESOURCES.md", "POLITICS.md"]:
		for line: String in _note(name).split("\n"):
			if line.contains("| `UNVERIFIED`") or line.contains("| `CONSULTED`"):
				continue
			check_false(line.contains("% of") or line.contains("tonnes per"),
					"no per-country quantity is asserted: %s" % line.substr(0, 60))


func test_the_political_note_keeps_the_sovereignty_rule() -> void:
	var text := _note("POLITICS.md")
	check_true(text.contains("DISPUTED_TERRITORIES.md"),
			"it points at the page that records the dataset's disputed units")
	check_true(text.to_lower().contains("takes no position")
			or text.to_lower().contains("no stance")
			or text.to_lower().contains("takes the position"),
			"it restates the no-stance rule")
	check_true(text.contains("open"), "and leaves the design question open rather than decided")


func test_the_roadmap_marks_the_task_done_and_keeps_the_rest_planned() -> void:
	var roadmap := FileAccess.get_file_as_string("res://ROADMAP.md")
	check_true(roadmap.contains("docs/research/"),
			"the roadmap points at the research notes")
	var design := FileAccess.get_file_as_string("res://docs/OPEN_ENDED_DESIGN.md")
	check_true(design.contains("PLANNED"),
			"the open-ended design page still labels itself planned")
