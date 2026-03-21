# shrinking_shape.gd — Battle royale "Closing Storm" arena.
#
# Starts as a full-size rectangle and linearly shrinks toward the center over
# the wave duration. The shrink rate and minimum size are configurable via the
# mod's manifest config (shrinking_min_scale, shrinking_speed).
#
# The shrinking is purely logical — tiles are NOT removed. Instead, my_tile_map.gd
# draws a morphing fog overlay and fire emitters along the shrinking boundary,
# and applies damage to players outside the current bounds.
#
# current_scale goes from 1.0 -> min_scale as time_ratio goes from 0.0 -> 1.0.

extends "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd"

var current_scale := 1.0         # current shrink factor (1.0 = full size)
var min_scale := 0.4             # smallest the arena can get (configurable)
var shrink_speed := 1.0          # speed multiplier (configurable, 1.0 = normal)

var current_half_width := 0.0    # half_width * current_scale
var current_half_height := 0.0   # half_height * current_scale


func setup(p_width_px: float, p_height_px: float) -> void:
	.setup(p_width_px, p_height_px)
	current_scale = 1.0
	current_half_width = half_width
	current_half_height = half_height


func get_shape_id() -> int:
	return SHAPE_SHRINKING


func is_shrinking() -> bool:
	return true


# Lerp from full size to min_scale over the wave.
# shrink_speed > 1 makes it reach min_scale before the wave ends.
func update(time_ratio: float) -> void:
	current_scale = lerp(1.0, min_scale, clamp(time_ratio * shrink_speed, 0.0, 1.0))
	current_half_width = half_width * current_scale
	current_half_height = half_height * current_scale


# Containment uses the current (shrunk) rectangle centered on the map
func contains_point(point: Vector2) -> bool:
	return (
		point.x >= center.x - current_half_width
		and point.x <= center.x + current_half_width
		and point.y >= center.y - current_half_height
		and point.y <= center.y + current_half_height
	)


# Clamp to the current shrunk boundary
func clamp_position(point: Vector2) -> Vector2:
	return Vector2(
		clamp(point.x, center.x - current_half_width, center.x + current_half_width),
		clamp(point.y, center.y - current_half_height, center.y + current_half_height)
	)


# Random position inside the current shrunk area with edge margin.
# Falls back to a tiny range around center if edge exceeds available space.
func get_rand_pos(edge: float) -> Vector2:
	var min_x = center.x - current_half_width + edge
	var max_x = center.x + current_half_width - edge
	var min_y = center.y - current_half_height + edge
	var max_y = center.y + current_half_height - edge
	if min_x >= max_x:
		min_x = center.x - 1.0
		max_x = center.x + 1.0
	if min_y >= max_y:
		min_y = center.y - 1.0
		max_y = center.y + 1.0
	return Vector2(rand_range(min_x, max_x), rand_range(min_y, max_y))


# Random position on one of the 4 edges of the current shrunk rectangle
func get_rand_edge_pos(dist: float) -> Vector2:
	var side = randi() % 4
	var cx_min = center.x - current_half_width
	var cx_max = center.x + current_half_width
	var cy_min = center.y - current_half_height
	var cy_max = center.y + current_half_height
	match side:
		0: # top
			return Vector2(rand_range(cx_min, cx_max), cy_min + dist)
		1: # right
			return Vector2(cx_max - dist, rand_range(cy_min, cy_max))
		2: # bottom
			return Vector2(rand_range(cx_min, cx_max), cy_max - dist)
		_: # left
			return Vector2(cx_min + dist, rand_range(cy_min, cy_max))


# Collision points track the current shrunk rectangle
func get_collision_points(_num_segments: int = 32) -> PoolVector2Array:
	return PoolVector2Array([
		Vector2(center.x - current_half_width, center.y - current_half_height),
		Vector2(center.x + current_half_width, center.y - current_half_height),
		Vector2(center.x + current_half_width, center.y + current_half_height),
		Vector2(center.x - current_half_width, center.y + current_half_height),
	])


# Always fill all tiles — shrinking is visual/logical, not structural.
# The floor stays intact; the fog overlay creates the illusion of lost ground.
func should_fill_tile(tile_x: int, tile_y: int, tile_size: int) -> bool:
	return true


# Closed loop outline for Line2D
func get_outline_points() -> PoolVector2Array:
	var pts = get_collision_points()
	pts.append(pts[0])
	return pts
