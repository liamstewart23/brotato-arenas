extends "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd"


func get_shape_id() -> int:
	return SHAPE_RECTANGLE


func contains_point(point: Vector2) -> bool:
	return (
		point.x >= 0.0 and point.x <= width_px
		and point.y >= 0.0 and point.y <= height_px
	)


func clamp_position(point: Vector2) -> Vector2:
	return Vector2(
		clamp(point.x, 0.0, width_px),
		clamp(point.y, 0.0, height_px)
	)


func get_rand_pos(edge: float) -> Vector2:
	var min_x = min(edge, half_width - 1.0)
	var max_x = max(width_px - edge, half_width + 1.0)
	var min_y = min(edge, half_height - 1.0)
	var max_y = max(height_px - edge, half_height + 1.0)
	return Vector2(rand_range(min_x, max_x), rand_range(min_y, max_y))


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


func get_collision_points(_num_segments: int = 32) -> PoolVector2Array:
	return PoolVector2Array([
		Vector2(0, 0),
		Vector2(width_px, 0),
		Vector2(width_px, height_px),
		Vector2(0, height_px),
	])


func should_fill_tile(tile_x: int, tile_y: int, tile_size: int) -> bool:
	return true


func get_outline_points() -> PoolVector2Array:
	var pts = get_collision_points()
	pts.append(pts[0])
	return pts
