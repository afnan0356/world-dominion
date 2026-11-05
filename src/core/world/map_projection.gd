class_name MapProjection
extends RefCounted
## The atlas projection, in one place so it can be replaced deliberately.
##
## WORLD DOMINION draws an **equirectangular (plate carrée)** map: longitude maps
## linearly to x and latitude linearly to y, over a 2:1 world rectangle. Reasons:
##   * the stored geometry is already lon/lat, so nothing is re-projected at
##     load time and hit-testing uses the same numbers the renderer draws;
##   * the whole world fits a landscape screen without the polar exaggeration of
##     a Mercator projection, which would devote most of the height to Antarctica;
##   * a future switch (Miller, Robinson…) only has to change `project()` and
##     `unproject()` — no data regeneration, no UI changes.
## The trade-off is accepted and documented: high latitudes are stretched
## horizontally compared with an equal-area projection.

const MIN_LON := -180.0
const MAX_LON := 180.0
const MIN_LAT := -90.0
const MAX_LAT := 90.0
## Width:height of the projected world. Equirectangular is exactly 2:1.
const WORLD_SIZE := Vector2(360.0, 180.0)
const GRATICULE_STEP := 30.0


static func display_name() -> String:
	return "Equirectangular (plate carrée)"


static func description() -> String:
	return ("Longitude and latitude map linearly to the map rectangle. Chosen for "
			+ "stable shapes, cheap hit-testing and an undistorted reading of the "
			+ "inhabited world; high latitudes are stretched horizontally.")


## Longitude/latitude to projected map space. Identity for this projection.
static func project(lon_lat: Vector2) -> Vector2:
	return lon_lat


static func unproject(projected: Vector2) -> Vector2:
	return projected


## Projected space to a 0..1 rectangle of the world, used for labels and tests.
static func normalise(lon_lat: Vector2) -> Vector2:
	return Vector2(
		(lon_lat.x - MIN_LON) / WORLD_SIZE.x,
		(MAX_LAT - lon_lat.y) / WORLD_SIZE.y)


static func is_inside_world(lon_lat: Vector2) -> bool:
	return (lon_lat.x >= MIN_LON and lon_lat.x <= MAX_LON
			and lon_lat.y >= MIN_LAT and lon_lat.y <= MAX_LAT)


static func clamp_to_world(lon_lat: Vector2) -> Vector2:
	return Vector2(
		clampf(lon_lat.x, MIN_LON, MAX_LON),
		clampf(lon_lat.y, MIN_LAT, MAX_LAT))


## True when a projected rectangle overlaps the world rectangle at all.
static func overlaps_world(rect: Rect2) -> bool:
	return rect.intersects(Rect2(Vector2(MIN_LON, MIN_LAT), WORLD_SIZE))
