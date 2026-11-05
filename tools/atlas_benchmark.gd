extends Node
## Headless measurement of the world atlas.
##
##   godot --headless --path . res://tools/atlas_benchmark.tscn --quit-after 2
##
## Prints the numbers quoted in docs/PERFORMANCE.md: data sizes, parse and index
## times, mesh construction and query throughput. It measures CPU work only —
## there is no GPU in the headless renderer, so frame time is *not* measured here
## and the documentation says so.

const ITERATIONS_HIT := 5000
const ITERATIONS_SEARCH := 2000


func _ready() -> void:
	print("")
	print("WORLD DOMINION · world atlas benchmark")
	print("-------------------------------------")
	_report_files()
	var registry_start := Time.get_ticks_usec()
	var registry := CountryRegistry.from_file()
	var registry_ms := float(Time.get_ticks_usec() - registry_start) / 1000.0
	var geometry_start := Time.get_ticks_usec()
	var geometry := WorldGeometry.from_file()
	var geometry_ms := float(Time.get_ticks_usec() - geometry_start) / 1000.0
	var lookup_start := Time.get_ticks_usec()
	var lookup := CountryLookup.new(geometry)
	var lookup_ms := float(Time.get_ticks_usec() - lookup_start) / 1000.0
	print("countries              %d" % registry.count())
	print("polygons               %d" % geometry.polygon_count())
	print("rings                  %d" % geometry.ring_count())
	print("vertices               %d" % geometry.vertex_count())
	print("registry parse         %.2f ms" % registry_ms)
	print("geometry parse         %.2f ms" % geometry_ms)
	print("spatial index build    %.2f ms" % lookup_ms)
	print("total load             %.2f ms" % (registry_ms + geometry_ms + lookup_ms))

	var atlas := WorldAtlas.load_default()
	var map: WorldMapView = load("res://src/ui/map/world_map_view.tscn").instantiate()
	add_child(map)
	map.size = Vector2(1280, 720)
	await get_tree().process_frame
	map.set_atlas(atlas)
	await get_tree().process_frame
	var mesh_start := Time.get_ticks_usec()
	var vertices := map.build_meshes_for(geometry.country_ids())
	var mesh_ms := float(Time.get_ticks_usec() - mesh_start) / 1000.0
	print("mesh build (all)       %.2f ms  (%d mesh vertices)" % [mesh_ms, vertices])

	var hit_start := Time.get_ticks_usec()
	var hits := 0
	for index in ITERATIONS_HIT:
		var lon := -170.0 + float(index % 340)
		var lat := -60.0 + float(index % 120) * 0.75
		if not lookup.country_at(Vector2(lon, lat)).is_empty():
			hits += 1
	var hit_us := float(Time.get_ticks_usec() - hit_start) / float(ITERATIONS_HIT)
	print("hit test               %.2f us/query (%d of %d points on land)"
			% [hit_us, hits, ITERATIONS_HIT])

	var search_start := Time.get_ticks_usec()
	for index in ITERATIONS_SEARCH:
		registry.search("a" if index % 2 == 0 else "bang")
	var search_us := float(Time.get_ticks_usec() - search_start) / float(ITERATIONS_SEARCH)
	print("search                 %.2f us/query (%d queries)" % [search_us, ITERATIONS_SEARCH])
	print("static memory          %.1f MiB" % (OS.get_static_memory_usage() / 1048576.0))
	print("engine                 %s" % Engine.get_version_info().get("string", "unknown"))
	print("-------------------------------------")
	get_tree().quit(0)


func _report_files() -> void:
	for path: String in ["res://data/world/countries.json", "res://data/world/geometry.json",
			"res://data/world/manifest.json"]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			print("%s: missing" % path)
			continue
		print("%-38s %.1f KiB" % [path.get_file(), float(file.get_length()) / 1024.0])
		file.close()
