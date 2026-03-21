# rectangle_shape.gd — Default rectangular arena (vanilla behavior).
#
# This is the no-op shape: when selected, the game plays identically to
# unmodded Brotato. All methods delegate to standard rectangular math.
# Serves as the fallback when shape_id is 0 or unrecognized.

extends "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd"


func get_shape_id() -> int:
	return SHAPE_RECTANGLE


# Standard rectangular containment — point must be within [0, width] x [0, height]
func contains_point(point: Vector2) -> bool:
	return (
		point.x >= 0.0 and point.x <= width_px
		and point.y >= 0.0 and point.y <= height_px
	)


# Per-axis clamp to arena bounds
func clamp_position(point: Vector2) -> Vector2:
	return Vector2(
		clamp(point.x, 0.0, width_px),
		clamp(point.y, 0.0, height_px)
	)


# Random position with `edge` pixel margin from each side.
# min/max clamped to guarantee valid range even with extreme edge values.
func get_rand_pos(edge: float) -> Vector2:
	var min_x = min(edge, half_width - 1.0)
	var max_x = max(width_px - edge, half_width + 1.0)
	var min_y = min(edge, half_height - 1.0)
	var max_y = max(height_px - edge, half_height + 1.0)
	return Vector2(rand_range(min_x, max_x), rand_range(min_y, max_y))


# Random position on one of the 4 edges, `dist` pixels inward
func get_rand_edge_pos(dist: float) -> Vector2:
	var side = randi() % 4
	match side:
		0: # top
			return Vector2(rand_range(0.0, width_px), dist)
		1: # right
			return Vector2(width_px - dist, rand_range(0.0, height_px))
		2: # bottom
			return Vector2(rand_range(0.0, width_px), height_px - dist)
		_: # left
			return Vector2(dist, rand_range(0.0, height_px))


# 4-corner rectangle for collision walls
func get_collision_points(_num_segments: int = 32) -> PoolVector2Array:
	return PoolVector2Array([
		Vector2(0, 0),
		Vector2(width_px, 0),
		Vector2(width_px, height_px),
		Vector2(0, height_px),
	])


# All tiles are playable in a rectangle
func should_fill_tile(tile_x: int, tile_y: int, tile_size: int) -> bool:
	return true


# Closed loop outline (5 points — last == first)
func get_outline_points() -> PoolVector2Array:
	var pts = get_collision_points()
	pts.append(pts[0])
	return pts
