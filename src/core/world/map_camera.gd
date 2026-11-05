class_name MapCamera
extends RefCounted
## Camera state for the world map: which part of the projected world is on
## screen and at what scale.
##
## Kept free of Control/Node types so it can be unit-tested directly: the only
## outside input is a viewport size. Every mutation clamps the state, which is
## what guarantees the map can never be dragged out of view.

signal changed

## Zoom is expressed in screen pixels per degree of longitude.
const MAX_ZOOM := 96.0
const MIN_ZOOM := 0.25
## A drag shorter than this (in pixels) counts as a tap, not a pan.
const TAP_SLOP := 5.0
const ZOOM_STEP := 1.35

var view_size := Vector2(1280.0, 720.0)
var center := Vector2.ZERO
var zoom := 2.0

var _has_view := false


func has_valid_state() -> bool:
	return _has_view and view_size.x > 0.0 and view_size.y > 0.0


## Reports a new viewport size, refitting when the map was never initialised and
## otherwise keeping the same centre and zoom inside the new bounds.
func set_view_size(size: Vector2) -> void:
	if size == view_size:
		return
	view_size = Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0))
	if not _has_view:
		reset()
	else:
		_clamp()
	changed.emit()


## Zoom at which the whole world exactly fits the current viewport.
func fit_zoom() -> float:
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return MIN_ZOOM
	var horizontal := view_size.x / MapProjection.WORLD_SIZE.x
	var vertical := view_size.y / MapProjection.WORLD_SIZE.y
	return maxf(minf(horizontal, vertical), MIN_ZOOM)


func reset() -> void:
	center = Vector2.ZERO
	zoom = fit_zoom()
	_has_view = true
	_clamp()
	changed.emit()


## Transforms projected world coordinates (degrees) into screen pixels.
func transform() -> Transform2D:
	# Screen y grows downwards while latitude grows upwards, hence the flip.
	return Transform2D(
		Vector2(zoom, 0.0),
		Vector2(0.0, -zoom),
		Vector2(view_size.x * 0.5 - center.x * zoom,
				view_size.y * 0.5 + center.y * zoom))


func world_to_screen(lon_lat: Vector2) -> Vector2:
	return transform() * MapProjection.project(lon_lat)


func screen_to_world(screen_position: Vector2) -> Vector2:
	return MapProjection.unproject(transform().affine_inverse() * screen_position)


## Zooms by `factor` while keeping the world point under `screen_position`
## fixed. Falls back to a centre-anchored zoom when the pointer is outside.
func zoom_at(screen_position: Vector2, factor: float) -> void:
	if factor <= 0.0:
		return
	var anchor := screen_to_world(screen_position)
	var new_zoom := clampf(zoom * factor, fit_zoom(), MAX_ZOOM)
	if is_equal_approx(new_zoom, zoom):
		return
	zoom = new_zoom
	# Solve center so that `anchor` maps back to `screen_position`.
	center = Vector2(
		anchor.x - (screen_position.x - view_size.x * 0.5) / zoom,
		anchor.y + (screen_position.y - view_size.y * 0.5) / zoom)
	_clamp()
	changed.emit()


## Centre-anchored zoom for the on-screen ± buttons and the keyboard.
func zoom_by(factor: float) -> void:
	zoom_at(view_size * 0.5, factor)


func zoom_in() -> void:
	zoom_by(ZOOM_STEP)


func zoom_out() -> void:
	zoom_by(1.0 / ZOOM_STEP)


## Drags the map by a screen-space delta (pixels). Positive x moves the world
## right, which is what a finger does when it drags right.
func pan_by_pixels(delta: Vector2) -> void:
	if not has_valid_state() or delta == Vector2.ZERO:
		return
	center = Vector2(center.x - delta.x / zoom, center.y + delta.y / zoom)
	_clamp()
	changed.emit()


## Centres and zooms so `lon_lat_rect` fills the viewport with `padding` pixels
## of breathing room. Used when a search result or a selection is focused.
func focus_rect(lon_lat_rect: Rect2, padding: float = 48.0) -> void:
	if not has_valid_state():
		return
	var usable := Vector2(maxf(view_size.x - padding * 2.0, 32.0),
			maxf(view_size.y - padding * 2.0, 32.0))
	var width := maxf(lon_lat_rect.size.x, 0.5)
	var height := maxf(lon_lat_rect.size.y, 0.5)
	var target := minf(usable.x / width, usable.y / height)
	zoom = clampf(target, fit_zoom(), MAX_ZOOM)
	center = lon_lat_rect.get_center()
	_clamp()
	changed.emit()


## Zoom relative to the whole-world view, for the on-screen readout.
func zoom_ratio() -> float:
	var base := fit_zoom()
	return zoom / base if base > 0.0 else 1.0


func is_zoomed() -> bool:
	return zoom > fit_zoom() * 1.001


## The projected rectangle currently visible, used to cull shapes.
func visible_rect(margin: float = 0.0) -> Rect2:
	var top_left := screen_to_world(Vector2(-margin, -margin))
	var bottom_right := screen_to_world(view_size + Vector2(margin, margin))
	return Rect2(top_left, bottom_right - top_left)


func _clamp() -> void:
	var minimum_zoom := fit_zoom()
	zoom = clampf(zoom, minimum_zoom, MAX_ZOOM)
	var half := view_size * 0.5 / zoom
	if half.x * 2.0 >= MapProjection.WORLD_SIZE.x:
		center.x = 0.0
	else:
		center.x = clampf(center.x, MapProjection.MIN_LON + half.x,
				MapProjection.MAX_LON - half.x)
	if half.y * 2.0 >= MapProjection.WORLD_SIZE.y:
		center.y = 0.0
	else:
		center.y = clampf(center.y, MapProjection.MIN_LAT + half.y,
				MapProjection.MAX_LAT - half.y)
	if not is_finite(center.x) or not is_finite(center.y):
		center = Vector2.ZERO
