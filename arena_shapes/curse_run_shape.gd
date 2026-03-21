extends "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd"

# Treadmill drift: player gets pushed left and must run right to survive
var drift_speed: float = 0.0
const DRIFT_BASE := 150.0
const DRIFT_MAX := 270.0


func setup(p_width_px: float, p_height_px: float) -> void:
	.setup(p_width_px, p_height_px)
	drift_speed = DRIFT_BASE


func get_shape_id() -> int:
	return SHAPE_CURSE_RUN


func is_shrinking() -> bool:
	return false


func update(time_ratio: float) -> void:
	# Escalate drift speed over the wave
	drift_speed = DRIFT_BASE + (DRIFT_MAX - DRIFT_BASE) * time_ratio


func contains_point(point: Vector2) -> bool:
	return point.x >= 0 and point.x <= width_px and point.y >= 0 and point.y <= height_px


func clamp_position(point: Vector2) -> Vector2:
	return Vector2(clamp(point.x, 0, width_px), clamp(point.y, 0, height_px))


func get_rand_pos(edge: float) -> Vector2:
	return Vector2(
		rand_range(edge, width_px - edge),
		rand_range(edge, height_px - edge)
	)


func get_rand_edge_pos(dist: float) -> Vector2:
	# Enemies always spawn from the right edge
	return Vector2(width_px - dist, rand_range(dist, height_px - dist))


func should_fill_tile(_tile_x: int, _tile_y: int, _tile_size: int) -> bool:
	return true


func get_collision_points(_num_segments: int = 32) -> PoolVector2Array:
	# Normal rectangle walls on all 4 sides
	return PoolVector2Array([
		Vector2(0, 0),
		Vector2(width_px, 0),
		Vector2(width_px, height_px),
		Vector2(0, height_px),
	])


func get_outline_points() -> PoolVector2Array:
	return PoolVector2Array()
