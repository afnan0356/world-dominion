extends TestCase
## The performance page, and the honesty rules around numbers (Milestone 09, Task 10).
##
## `docs/PERFORMANCE.md` reports measured CPU work and data volume, and labels everything a
## display server would be needed to measure as unverified. These tests keep it that way:
## the size table is generated and must match the committed files byte for byte, every
## figure table says what machine produced it, and the page never presents a guess as a
## measurement.

const DOC := "res://docs/PERFORMANCE.md"
const WORLD := "res://data/world"
const START := "<!-- data-sizes:start -->"
const END := "<!-- data-sizes:end -->"

## The files the game loads at startup. The page's table must list exactly these.
const RUNTIME := ["countries.json", "geometry.json", "coast.json", "manifest.json",
		"statistics.json", "currency.json"]


func _doc() -> String:
	return FileAccess.get_file_as_string(DOC)


func _block() -> PackedStringArray:
	var text := _doc()
	var start := text.find(START)
	var end := text.find(END)
	if start < 0 or end < start:
		return PackedStringArray()
	return text.substr(start, end - start + END.length()).split("\n")


## `{"countries.json": {"bytes": 116529, "size": "114 KiB"}}` from the page's table.
func _rows() -> Dictionary:
	var rows := {}
	for line: String in _block():
		if not line.begins_with("| `data/world/"):
			continue
		var cells := line.split("|")
		if cells.size() < 5:
			continue
		var name := cells[1].strip_edges().trim_prefix("`data/world/").trim_suffix("`")
		rows[name] = {"bytes": int(cells[2].strip_edges().replace(",", "")),
				"size": cells[3].strip_edges()}
	return rows


func test_the_size_table_is_generated_and_present() -> void:
	var text := _doc()
	check_true(text.contains(START), "the page carries the generated block's opening marker")
	check_true(text.contains(END), "and its closing marker")
	check_true(text.contains("tools/data_sizes.py"),
			"the page names the tool that generates the table")
	var rows := _rows()
	check_gte(float(rows.size()), 10.0, "the table lists the pack files")


func test_every_runtime_file_is_listed_with_its_real_size() -> void:
	var rows := _rows()
	var seen := 0
	for name: String in RUNTIME:
		check_true(rows.has(name), "the table lists %s" % name)
		if not rows.has(name):
			continue
		var path := "%s/%s" % [WORLD, name]
		var actual := FileAccess.get_file_as_string(path).to_utf8_buffer().size()
		var listed := int(rows[name]["bytes"])
		check_eq(listed, actual, "%s's size on the page is the file's size" % name)
		check_eq(str(rows[name]["size"]).contains("KiB") or str(rows[name]["size"]).ends_with(" B"),
				true, "%s's size has a unit" % name)
		seen += 1
	check_eq(seen, RUNTIME.size(), "every runtime file was checked")


func test_the_totals_are_the_sum_of_the_rows() -> void:
	var rows := _rows()
	var runtime_total := 0
	for name: String in RUNTIME:
		if rows.has(name):
			runtime_total += int(rows[name]["bytes"])
	var text := _doc()
	check_true(text.contains("Runtime pack total"), "the table has a runtime total")
	check_true(text.contains(_comma(runtime_total)),
			"the runtime total is the sum of the rows (%d bytes)" % runtime_total)


## `1472353` as `1,472,353`, the way the table writes exact byte counts.
static func _comma(value: int) -> String:
	var digits := str(value)
	var out := ""
	var counted := 0
	for index in range(digits.length() - 1, -1, -1):
		out = digits[index] + out
		counted += 1
		if counted % 3 == 0 and index > 0:
			out = "," + out
	return out


func test_the_page_says_what_it_could_not_measure() -> void:
	var text := _doc()
	for needle: String in ["no GPU", "no display server", "headless", "UNVERIFIED"]:
		check_true(text.to_upper().contains(needle.to_upper()),
				"the page says \"%s\"" % needle)
	check_true(text.contains("Frame time on real hardware is *not* measured here"),
			"frame time is explicitly not claimed")


func test_every_figure_table_names_the_conditions_it_was_measured_under() -> void:
	var text := _doc()
	var headings := 0
	for line: String in text.split("\n"):
		if line.begins_with("## "):
			headings += 1
	check_gte(float(headings), 4.0, "the page has its sections")
	# A timing table without a stated machine is a number nobody can check. The page states
	# them once, at the top, and this test pins that they stay there.
	check_true(text.contains("compiled from the official 4.6.3-stable source tag"),
			"the engine build the numbers came from is named")
	check_true(text.contains("godot --headless --path . res://tools/sim_benchmark.tscn"),
			"the benchmark can be reproduced from the page")
	check_true(text.contains("godot --headless --path . res://tools/atlas_benchmark.tscn"),
			"and so can the atlas benchmark")


func test_the_documented_benchmarks_exist_and_report_their_own_verdict() -> void:
	for path: String in ["res://tools/atlas_benchmark.gd", "res://tools/sim_benchmark.gd",
			"res://tools/sim_benchmark.tscn", "res://tools/atlas_benchmark.tscn"]:
		check_true(FileAccess.file_exists(path), "%s exists" % path.get_file())
	var simulation := FileAccess.get_file_as_string("res://tools/sim_benchmark.gd")
	check_true(simulation.contains("Performance.MEMORY_STATIC"),
			"the benchmark measures memory, not just time")
	check_true(simulation.to_upper().contains("BENCHMARK OK"),
			"and it prints a verdict CI can check")
	check_true(simulation.contains("Time.get_ticks_usec()"),
			"its figures are timed on the machine that runs them")


func test_the_currency_pack_is_documented_without_a_claim_about_its_cost() -> void:
	var text := _doc()
	check_true(text.contains("currency.json"),
			"the page mentions the currency pack it now loads")
	check_true(text.contains("not separately measured") or text.contains("has **not** been timed"),
			"it does not claim a cost that was never measured")
