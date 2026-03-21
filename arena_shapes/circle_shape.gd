extends "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd"

var radius := 0.0
var radius_sq := 0.0
var outer_radius := 0.0


func setup(p_width_px: float, p_height_px: float) -> void:
	.setup(p_width_px, p_height_px)
	radius = min(half_width, half_height)
	radius_sq = radius * radius
	# Inflate by half a tile width so walls/outline align with filled tile edges
	outer_radius = radius + Utils.TILE_SIZE * 0.5


func get_shape_id() -> int:
	return SHAPE_CIRCLE


func contains_point(point: Vector2) -> bool:
	return (point - center).length_squared() <= radius_sq


func clamp_position(point: Vector2) -> Vector2:
	var offset = point - center
	if offset.length_squared() <= radius_sq:
		return point
	return center + offset.normalized() * radius


func get_rand_pos(edge: float) -> Vector2:
	var inner_radius = max(1.0, radius - edge)
	var angle = rand_range(0.0, TAU)
	var r = inner_radius * sqrt(randf())
	return center + Vector2(cos(angle), sin(angle)) * r


func get_rand_edge_pos(dist: float) -> Vector2:
	var angle = rand_range(0.0, TAU)
	var r = max(0.0, radius - dist)
	return center + Vector2(cos(angle), sin(angle)) * r


func get_collision_points(num_segments: int = 32) -> PoolVector2Array:
	var points = PoolVector2Array()
	for i in num_segments:
		var angle = TAU * i / float(num_segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * outer_radius)
	return points


func should_fill_tile(tile_x: int, tile_y: int, tile_size: int) -> bool:
	var tile_center = Vector2(
		(tile_x + 0.5) * tile_size,
		(tile_y + 0.5) * tile_size
	)
	# Pad by half a tile width so edge tiles that overlap the circle get filled
	var padded_radius = radius + tile_size * 0.5
	return (tile_center - center).length_squared() <= padded_radius * padded_radius


func get_outline_points() -> PoolVector2Array:
	var pts = PoolVector2Array()
	for i in 48:
		var angle = TAU * i / 48.0
		pts.append(center + Vector2(cos(angle), sin(angle)) * outer_radius)
	pts.append(pts[0])
	return pts
