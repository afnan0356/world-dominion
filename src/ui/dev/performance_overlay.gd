class_name PerformanceOverlay
extends PanelContainer
## Developer frame-time readout.
##
## Off by default, toggled with **F3** or from Settings → Advanced / Developer, and
## persisted like any other setting. It reads engine counters and its own rolling
## frame samples; it never writes a file, never logs a metric to disk and never
## talks to a network (the game has no network code at all).
##
## It is a diagnostic, not gameplay: it draws a panel in the corner, ignores the
## mouse, and does not touch the map, the camera or the selection.

const SAMPLE_WINDOW := 180
const REFRESH_SECONDS := 0.25

var _samples: PackedFloat32Array = PackedFloat32Array()
var _since_refresh := 0.0
var _lines: Label
var _counts: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	theme_type_variation = &"PanelCard"
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(body)
	_lines = Label.new()
	_lines.theme_type_variation = &"Mono"
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_lines)
	visible = Settings.get_show_performance_overlay()
	Settings.changed.connect(_on_setting_changed)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(12.0, 12.0)
	_reset_samples()


func _process(delta: float) -> void:
	if not visible:
		return
	var delta_ms := delta * 1000.0
	if delta_ms > 0.0 and delta_ms < MapStressTest.STALL_MS:
		_samples.append(delta_ms)
		if _samples.size() > SAMPLE_WINDOW:
			_samples.remove_at(0)
	_since_refresh += delta
	if _since_refresh < REFRESH_SECONDS:
		return
	_since_refresh = 0.0
	_refresh_text()


## Rolling statistics over the last `SAMPLE_WINDOW` frames.
func stats() -> Dictionary:
	var sorted := _samples.duplicate()
	sorted.sort()
	var total := 0.0
	for value: float in _samples:
		total += value
	return {
		"count": _samples.size(),
		"average_ms": 0.0 if _samples.is_empty() else total / float(_samples.size()),
		"p95_ms": MapStressTest.percentile(sorted, 0.95),
		"worst_ms": 0.0 if sorted.is_empty() else float(sorted[sorted.size() - 1]),
	}


## Counts handed in by the screen that owns the map, if it has any to give.
func set_map_counts(text: String) -> void:
	_counts = text


func _refresh_text() -> void:
	var entry := stats()
	var fps := Engine.get_frames_per_second()
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var text := "FPS %d\nframe avg %.1f ms · p95 %.1f ms · worst %.1f ms\ndraw calls %d" % [
			fps, float(entry["average_ms"]), float(entry["p95_ms"]), float(entry["worst_ms"]),
			draw_calls]
	if not _counts.is_empty():
		text += "\n%s" % _counts
	_lines.text = text


func _reset_samples() -> void:
	_samples = PackedFloat32Array()


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key != SettingsSchema.KEY_PERF_OVERLAY:
		return
	visible = Settings.get_show_performance_overlay()
	_reset_samples()
