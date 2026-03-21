# circle_shape.gd — Circular arena inscribed in the zone bounding box.
#
# The playable area is a circle centered on the map with radius equal to the
# smaller of half_width and half_height. An inflated `outer_radius` (padded by
# half a tile) is used for collision walls and the visual outline so they align
# with the outermost filled tiles rather than cutting through them.

extends "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd"

var radius := 0.0       # inscribed circle radius (playable boundary)
var radius_sq := 0.0    # precomputed radius^2 for fast distance checks
var outer_radius := 0.0 # inflated radius for walls/outline (+ half tile padding)


func setup(p_width_px: float, p_height_px: float) -> void:
	.setup(p_width_px, p_height_px)
	radius = min(half_width, half_height)
	radius_sq = radius * radius
	# Inflate by half a tile width so walls/outline align with filled tile edges
	outer_radius = radius + Utils.TILE_SIZE * 0.5


func get_shape_id() -> int:
	return SHAPE_CIRCLE


# Distance-squared check — avoids sqrt for performance
func contains_point(point: Vector2) -> bool:
	return (point - center).length_squared() <= radius_sq


# Project point onto circle edge if outside; return as-is if inside
func clamp_position(point: Vector2) -> Vector2:
	var offset = point - center
	if offset.length_squared() <= radius_sq:
		return point
	return center + offset.normalized() * radius


# Uniform random point inside circle using polar coordinates.
# sqrt(randf()) ensures uniform area distribution — without it, points
# would cluster near the center because area grows with r^2.
func get_rand_pos(edge: float) -> Vector2:
	var inner_radius = max(1.0, radius - edge)
	var angle = rand_range(0.0, TAU)
	var r = inner_radius * sqrt(randf())
	return center + Vector2(cos(angle), sin(angle)) * r


# Random point on the circle perimeter, `dist` pixels inward
func get_rand_edge_pos(dist: float) -> Vector2:
	var angle = rand_range(0.0, TAU)
	var r = max(0.0, radius - dist)
	return center + Vector2(cos(angle), sin(angle)) * r


# Generate collision polygon vertices around the inflated outer_radius.
# 32 segments by default — enough for smooth physics interaction.
func get_collision_points(num_segments: int = 32) -> PoolVector2Array:
	var points = PoolVector2Array()
	for i in num_segments:
		var angle = TAU * i / float(num_segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * outer_radius)
	return points


# Check if a tile's center is within (radius + half tile) of the arena center.
# The half-tile padding ensures edge tiles that partially overlap the circle
# still get floor sprites, preventing visual gaps at the boundary.
func should_fill_tile(tile_x: int, tile_y: int, tile_size: int) -> bool:
	var tile_center = Vector2(
		(tile_x + 0.5) * tile_size,
		(tile_y + 0.5) * tile_size
	)
	var padded_radius = radius + tile_size * 0.5
	return (tile_center - center).length_squared() <= padded_radius * padded_radius


# 48-segment outline for smoother visual than the 32-segment collision polygon.
# Closed loop (last point == first point) for Line2D rendering.
func get_outline_points() -> PoolVector2Array:
	var pts = PoolVector2Array()
	for i in 48:
		var angle = TAU * i / 48.0
		pts.append(center + Vector2(cos(angle), sin(angle)) * outer_radius)
	pts.append(pts[0])
	return pts
