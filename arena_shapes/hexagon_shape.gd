# hexagon_shape.gd — Regular hexagon arena using half-plane containment.
#
# A flat-top regular hexagon inscribed in the zone's bounding circle (radius =
# min(half_width, half_height)). The 6 vertices are offset by -PI/6 so the
# hexagon has flat edges on the top and bottom rather than pointed vertices.
#
# Containment uses 6 precomputed half-plane tests (one per edge) — a point is
# inside if it's on the inward side of all 6 edge normals. This is O(1) and
# avoids the overhead of a general polygon test.
#
# An inflated set of outer_vertices (padded by half a tile / cos(PI/6)) is used
# for collision walls and the visual outline, ensuring alignment with filled tiles.
#
# The zone gets a 30% size boost (applied in zone_service.gd) to compensate for
# the hexagon having ~87% the area of its bounding rectangle.

extends "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd"

var radius := 0.0                         # inscribed circle radius
var vertices := PoolVector2Array()        # 6 hexagon vertices (playable boundary)
var outer_vertices := PoolVector2Array()  # 6 inflated vertices (walls/outline)
var normals := []                         # 6 inward-facing edge normals
var edge_distances := []                  # dot(normal, vertex) for each edge


func setup(p_width_px: float, p_height_px: float) -> void:
	.setup(p_width_px, p_height_px)
	radius = min(half_width, half_height)
	_compute_vertices()
	_compute_half_planes()
	_compute_outer_vertices()


# Compute the 6 hexagon vertices. The -PI/6 offset rotates the hexagon so
# flat edges are on top/bottom (flat-top orientation) rather than pointy-top.
func _compute_vertices() -> void:
	vertices = PoolVector2Array()
	for i in 6:
		var angle = TAU * i / 6.0 - PI / 6.0
		vertices.append(center + Vector2(cos(angle), sin(angle)) * radius)


# Precompute half-plane representation for each edge.
# For edge (A -> B), the inward normal is perpendicular to the edge direction.
# A point P is inside if dot(normal, P) <= dot(normal, A) for all 6 edges.
func _compute_half_planes() -> void:
	normals = []
	edge_distances = []
	for i in 6:
		var a = vertices[i]
		var b = vertices[(i + 1) % 6]
		var edge = b - a
		# Inward-pointing normal (rotated 90 degrees clockwise in screen coords)
		var n = Vector2(edge.y, -edge.x).normalized()
		normals.append(n)
		edge_distances.append(n.dot(a))


# Inflate vertices outward for collision walls and visual outline.
# The padding is divided by cos(PI/6) to account for the hexagonal geometry —
# this ensures the inflated polygon is a uniform distance from the inner polygon
# measured perpendicular to each edge, not just radially.
func _compute_outer_vertices() -> void:
	var pad = Utils.TILE_SIZE * 0.5
	var outer_radius = radius + pad / cos(PI / 6.0)
	outer_vertices = PoolVector2Array()
	for i in 6:
		var angle = TAU * i / 6.0 - PI / 6.0
		outer_vertices.append(center + Vector2(cos(angle), sin(angle)) * outer_radius)


func get_shape_id() -> int:
	return SHAPE_HEXAGON


# Half-plane containment: point is inside iff it's on the inward side of all 6 edges.
# The +0.01 epsilon prevents floating-point edge cases at exact boundary positions.
func contains_point(point: Vector2) -> bool:
	for i in 6:
		if normals[i].dot(point) > edge_distances[i] + 0.01:
			return false
	return true


# Find the closest point on the hexagon boundary by testing all 6 edge segments.
# Returns the input point if already inside.
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


# Project point P onto line segment AB, clamping parameter t to [0, 1].
# Returns the closest point on the segment to P.
func _closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab = b - a
	var t = clamp((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return a + ab * t


# Random position inside the hexagon with edge margin.
# Uses rejection sampling: pick a random point in the inscribed circle,
# then check if it's inside the hexagon. Up to 100 attempts before fallback.
func get_rand_pos(edge: float) -> Vector2:
	for _attempt in 100:
		var angle = rand_range(0.0, TAU)
		var r = (radius - edge) * sqrt(randf())
		var pos = center + Vector2(cos(angle), sin(angle)) * r
		if contains_point(pos):
			return pos
	return center


# Pick a random point along one of the 6 edges, then offset inward by `dist`
func get_rand_edge_pos(dist: float) -> Vector2:
	var edge_idx = randi() % 6
	var a = vertices[edge_idx]
	var b = vertices[(edge_idx + 1) % 6]
	var t = randf()
	var edge_pos = a.linear_interpolate(b, t)
	var inward = (center - edge_pos).normalized() * dist
	return edge_pos + inward


# Use inflated outer_vertices for collision walls
func get_collision_points(_num_segments: int = 32) -> PoolVector2Array:
	return outer_vertices


# Tile fill uses half-plane test with padding so edge tiles that partially
# overlap the hexagon still get floor sprites (prevents visual gaps).
func should_fill_tile(tile_x: int, tile_y: int, tile_size: int) -> bool:
	var tile_center = Vector2(
		(tile_x + 0.5) * tile_size,
		(tile_y + 0.5) * tile_size
	)
	var pad = tile_size * 0.5
	for i in 6:
		if normals[i].dot(tile_center) > edge_distances[i] + pad:
			return false
	return true


# Closed loop outline using inflated vertices
func get_outline_points() -> PoolVector2Array:
	var pts = PoolVector2Array()
	for v in outer_vertices:
		pts.append(v)
	pts.append(outer_vertices[0])
	return pts
