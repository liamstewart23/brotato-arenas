extends "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd"

var radius := 0.0
var vertices := PoolVector2Array()
var outer_vertices := PoolVector2Array()
var normals := []
var edge_distances := []


func setup(p_width_px: float, p_height_px: float) -> void:
	.setup(p_width_px, p_height_px)
	radius = min(half_width, half_height)
	_compute_vertices()
	_compute_half_planes()
	_compute_outer_vertices()


func _compute_vertices() -> void:
	vertices = PoolVector2Array()
	for i in 6:
		var angle = TAU * i / 6.0 - PI / 6.0
		vertices.append(center + Vector2(cos(angle), sin(angle)) * radius)


func _compute_half_planes() -> void:
	normals = []
	edge_distances = []
	for i in 6:
		var a = vertices[i]
		var b = vertices[(i + 1) % 6]
		var edge = b - a
		var n = Vector2(edge.y, -edge.x).normalized()
		normals.append(n)
		edge_distances.append(n.dot(a))


func _compute_outer_vertices() -> void:
	# Inflate by tile padding so walls/outline align with filled tile edges
	var pad = Utils.TILE_SIZE * 0.5
	var outer_radius = radius + pad / cos(PI / 6.0)
	outer_vertices = PoolVector2Array()
	for i in 6:
		var angle = TAU * i / 6.0 - PI / 6.0
		outer_vertices.append(center + Vector2(cos(angle), sin(angle)) * outer_radius)


func get_shape_id() -> int:
	return SHAPE_HEXAGON


func contains_point(point: Vector2) -> bool:
	for i in 6:
		if normals[i].dot(point) > edge_distances[i] + 0.01:
			return false
	return true


func clamp_position(point: Vector2) -> Vector2:
	if contains_point(point):
		return point

	var closest = vertices[0]
	var closest_dist_sq = (point - closest).length_squared()

	for i in 6:
		var a = vertices[i]
		var b = vertices[(i + 1) % 6]
		var edge_point = _closest_point_on_segment(point, a, b)
		var dist_sq = (point - edge_point).length_squared()
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest = edge_point

	return closest


func _closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab = b - a
	var t = clamp((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return a + ab * t


func get_rand_pos(edge: float) -> Vector2:
	for _attempt in 100:
		var angle = rand_range(0.0, TAU)
		var r = (radius - edge) * sqrt(randf())
		var pos = center + Vector2(cos(angle), sin(angle)) * r
		if contains_point(pos):
			return pos
	return center


func get_rand_edge_pos(dist: float) -> Vector2:
	var edge_idx = randi() % 6
	var a = vertices[edge_idx]
	var b = vertices[(edge_idx + 1) % 6]
	var t = randf()
	var edge_pos = a.linear_interpolate(b, t)
	var inward = (center - edge_pos).normalized() * dist
	return edge_pos + inward


func get_collision_points(_num_segments: int = 32) -> PoolVector2Array:
	return outer_vertices


func should_fill_tile(tile_x: int, tile_y: int, tile_size: int) -> bool:
	var tile_center = Vector2(
		(tile_x + 0.5) * tile_size,
		(tile_y + 0.5) * tile_size
	)
	# Pad by half a tile width so edge tiles that overlap the hexagon get filled
	var pad = tile_size * 0.5
	for i in 6:
		if normals[i].dot(tile_center) > edge_distances[i] + pad:
			return false
	return true


func get_outline_points() -> PoolVector2Array:
	var pts = PoolVector2Array()
	for v in outer_vertices:
		pts.append(v)
	pts.append(outer_vertices[0])
	return pts
