class_name MapStressTest
extends RefCounted
## A repeatable "is this device fast enough for the map?" run.
##
## The test walks the camera through a fixed path for 30 seconds: one west-to-east
## sweep of the world while the zoom cycles several times between the whole-world
## view and a close regional view. The path is a pure function of elapsed time, so
## two runs on two devices — and a run in a test — follow exactly the same route,
## and the numbers are comparable.
##
## It measures the frame delta the engine actually produced (not a simulation of
## it), keeps every sample, and compares the 95th-percentile frame time against the
## budgets in docs/PERFORMANCE.md. Nothing here is stored, sent or logged anywhere:
## the summary is shown on screen and discarded when the run ends.

const DURATION_SECONDS := 30.0
const MAX_SAMPLES := 6000
## Budgets. A 60 fps frame is 16.67 ms; a 30 fps frame is 33.33 ms. The mobile
## class this project targets (a Snapdragon 680 handset, 6 GB RAM) is expected to
## hold 60 fps on the map, so "smooth" means the 95th percentile still fits in a
## 60 fps frame, and "acceptable" means it still fits in a 30 fps frame.
const BUDGET_SMOOTH_MS := 16.7
const BUDGET_ACCEPTABLE_MS := 33.4
## Frame deltas above this are treated as a stall (window drag, app paused) and
## excluded from the timings, but counted so the summary can say it happened.
const STALL_MS := 250.0

const VERDICT_SMOOTH := "smooth"
const VERDICT_ACCEPTABLE := "acceptable"
const VERDICT_SLOW := "too slow"
const VERDICT_INCOMPLETE := "not enough samples"

var duration := DURATION_SECONDS
var elapsed := 0.0
var running := false
var samples: PackedFloat32Array = []
var stalls := 0


func start() -> void:
	elapsed = 0.0
	running = true
	samples = PackedFloat32Array()


func stop() -> void:
	running = false


func progress() -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(elapsed / duration, 0.0, 1.0)


## Adds one frame, ignoring stalls. Returns true while the run continues.
func advance(delta: float) -> bool:
	if not running:
		return false
	elapsed += maxf(delta, 0.0)
	var delta_ms := delta * 1000.0
	if delta_ms <= STALL_MS:
		if samples.size() < MAX_SAMPLES:
			samples.append(delta_ms)
	else:
		stalls += 1
	if elapsed >= duration:
		running = false
	return running


## Camera state for the current moment: `frac` in [0, 1] sets a deterministic
## position on the path, which is what makes the run repeatable.
func camera_state() -> Dictionary:
	var fraction := progress()
	var longitude := -170.0 + 340.0 * fraction
	var latitude := 48.0 * sin(fraction * TAU)
	# Three zoom cycles, from the whole world to a regional view and back.
	var zoom_phase := 0.5 - 0.5 * cos(fraction * TAU * 3.0)
	return {
		"center": Vector2(longitude, latitude),
		"zoom_factor": 1.0 + 7.0 * zoom_phase,
		"fraction": fraction,
	}


## Average, 95th percentile and worst frame time in milliseconds. `count` is the
## number of usable samples; a run with no samples reports zeros rather than NaN.
func summary() -> Dictionary:
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for value: float in samples:
		total += value
	var average := 0.0 if samples.is_empty() else total / float(samples.size())
	return {
		"count": samples.size(),
		"average_ms": average,
		"p95_ms": percentile(sorted, 0.95),
		"worst_ms": 0.0 if sorted.is_empty() else float(sorted[sorted.size() - 1]),
		"stalls": stalls,
		"seconds": elapsed,
	}


static func percentile(sorted_values: PackedFloat32Array, fraction: float) -> float:
	if sorted_values.is_empty():
		return 0.0
	var index := int(ceil(clampf(fraction, 0.0, 1.0) * float(sorted_values.size()))) - 1
	return float(sorted_values[clampi(index, 0, sorted_values.size() - 1)])


## Turns timings into a plain-English verdict against the documented budgets.
## Kept static and free of engine calls so the thresholds are testable directly.
static func evaluate(p95_ms: float, sample_count: int) -> Dictionary:
	if sample_count < 10 or p95_ms <= 0.0:
		return {
			"verdict": VERDICT_INCOMPLETE,
			"headline": "Not enough frames measured",
			"detail": "Run the test for the full 30 seconds with the window focused.",
		}
	if p95_ms <= BUDGET_SMOOTH_MS:
		return {
			"verdict": VERDICT_SMOOTH,
			"headline": "Smooth",
			"detail": ("95%% of frames arrived within %.1f ms, so the map holds 60 fps "
					+ "on this device (budget %.1f ms).") % [p95_ms, BUDGET_SMOOTH_MS],
		}
	if p95_ms <= BUDGET_ACCEPTABLE_MS:
		return {
			"verdict": VERDICT_ACCEPTABLE,
			"headline": "Acceptable",
			"detail": ("95%% of frames arrived within %.1f ms: playable, but below 60 fps "
					+ "(budgets %.1f / %.1f ms).")
					% [p95_ms, BUDGET_SMOOTH_MS, BUDGET_ACCEPTABLE_MS],
		}
	return {
		"verdict": VERDICT_SLOW,
		"headline": "Too slow",
		"detail": ("95%% of frames took up to %.1f ms, beyond the %.1f ms budget. "
				+ "Try Settings → Reduced map detail and run the test again.")
				% [p95_ms, BUDGET_ACCEPTABLE_MS],
	}


## One-line summary for the on-screen panel.
func summary_lines() -> PackedStringArray:
	var stats := summary()
	var verdict := evaluate(float(stats["p95_ms"]), int(stats["count"]))
	var lines := PackedStringArray()
	lines.append("%s — %s" % [verdict["headline"], verdict["detail"]])
	lines.append("average %.1f ms · p95 %.1f ms · worst %.1f ms · %d frames%s" % [
			float(stats["average_ms"]), float(stats["p95_ms"]), float(stats["worst_ms"]),
			int(stats["count"]),
			" · %d stalls ignored" % int(stats["stalls"]) if int(stats["stalls"]) > 0 else ""])
	lines.append("Measured on this device only. Nothing is saved or sent.")
	return lines
