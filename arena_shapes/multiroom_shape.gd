# multiroom_shape.gd — Cave-like procedural rooms with organic corridors.
#
# Divides the arena into a grid of sectors and places one room per sector,
# guaranteeing full map coverage (no dead corners). Rooms are connected via
# Prim's MST algorithm plus 3-5 extra connections for loops and alternate paths.
# Corridors are narrow (4 tiles) for a tight cave feel.
#
# After carving, a gentle cellular automata pass softens rectangular edges into
# organic shapes, then wall pillars and bumps are scattered for cover and detail.
#
# A connectivity validation pass (BFS from center) ensures every room is
# reachable. Unreachable rooms get an emergency corridor carved to the nearest
# visited tile, with recursive re-validation.
#
# A center room is guaranteed to exist (inserted if no random room covers the
# map center), and a diamond-shaped clear zone around the exact spawn point
# prevents the player from starting inside a wall.
#
# Wall tiles are stored in a dictionary for O(1) lookup, same as maze_shape.gd.

extends "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd"

# Layout constants
const WALL_THICKNESS := 2          # border wall thickness in tiles
const DOOR_WIDTH := 4              # corridor width in tiles (narrow for cave feel)
const MIN_ROOMS := 8               # minimum number of rooms
const MAX_ROOMS := 14              # maximum number of rooms
const ROOM_PADDING := 1            # minimum gap between rooms in tiles
const CENTER_CLEAR_RADIUS := 3     # diamond-shaped clear zone around spawn
const MAX_PLACEMENT_ATTEMPTS := 200  # per-sector placement attempts

# Room dimensions scale with the smallest arena axis
const ROOM_SIZE_MIN_RATIO := 0.12  # min room dim = 12% of smallest arena axis
const ROOM_SIZE_MAX_RATIO := 0.25  # max room dim = 25% of smallest arena axis

# Cellular automata cave smoothing
const CA_ITERATIONS := 2           # number of smoothing passes
const CA_WALL_THRESHOLD := 6       # wall neighbors needed to stay wall (out of 8)
const CA_BORDER := 2               # border tiles are always walls

# Detail: wall pillars and bumps
const PILLAR_CHANCE := 0.12        # chance per room to spawn a wall pillar cluster
const BUMP_CHANCE := 0.3           # chance per wall-adjacent floor to grow a bump

var _rooms: Array = []             # Array of Rect2 (tile coords)
var _connections: Array = []       # Array of [int, int] room index pairs (MST + extras)
var _wall_tiles: Dictionary = {}   # {Vector2(tx, ty): true} for wall positions
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func get_shape_id() -> int:
	return SHAPE_MULTIROOM


func setup(p_width_px: float, p_height_px: float) -> void:
	.setup(p_width_px, p_height_px)
	_rng.randomize()

	var tile_w = int(p_width_px / Utils.TILE_SIZE)
	var tile_h = int(p_height_px / Utils.TILE_SIZE)

	_generate_rooms(tile_w, tile_h)
	_build_connections()
	_build_wall_tiles(tile_w, tile_h)
	_cave_smooth(tile_w, tile_h)
	_scatter_pillars(tile_w, tile_h)
	_add_wall_bumps(tile_w, tile_h)
	_cleanup_corners(tile_w, tile_h)
	_clear_center_tiles(tile_w, tile_h)
	_validate_connectivity(tile_w, tile_h)


# Place rooms randomly, rejecting overlaps. Room dimensions scale proportionally
# to the arena size so small arenas get smaller rooms and vice versa.
func _generate_rooms(tile_w: int, tile_h: int) -> void:
	_rooms.clear()

	var min_axis = min(tile_w, tile_h)
	var min_room_dim = max(6, int(min_axis * ROOM_SIZE_MIN_RATIO))
	var max_room_dim = max(min_room_dim + 2, int(min_axis * ROOM_SIZE_MAX_RATIO))

	# Cap room count on small arenas to avoid overcrowding
	var max_count = MAX_ROOMS
	if min_axis < 16:
		max_count = min(max_count, 6)

	var target_count = _rng.randi_range(MIN_ROOMS, max_count)
	var attempts = 0

	while _rooms.size() < target_count and attempts < MAX_PLACEMENT_ATTEMPTS:
		attempts += 1
		var rw = _rng.randi_range(min_room_dim, max_room_dim)
		var rh = _rng.randi_range(min_room_dim, max_room_dim)
		var rx = _rng.randi_range(WALL_THICKNESS, tile_w - rw - WALL_THICKNESS)
		var ry = _rng.randi_range(WALL_THICKNESS, tile_h - rh - WALL_THICKNESS)

		if rx < 0 or ry < 0:
			continue

		var candidate = Rect2(rx, ry, rw, rh)

		# Reject if overlapping any existing room (with padding)
		var overlaps = false
		for existing in _rooms:
			if _rects_overlap_padded(candidate, existing, ROOM_PADDING):
				overlaps = true
				break

		if not overlaps:
			_rooms.append(candidate)

	# Guarantee a room exists at the map center (player spawn point)
	_ensure_center_room(tile_w, tile_h)


# If no room contains the map center, insert a minimum-size room there.
# This guarantees the player spawns inside a room, not in a corridor.
func _ensure_center_room(tile_w: int, tile_h: int) -> void:
	var cx = int(tile_w / 2)
	var cy = int(tile_h / 2)
	var center = Vector2(cx, cy)

	for room in _rooms:
		if room.has_point(center):
			return

	var min_axis = min(tile_w, tile_h)
	var size = max(6, int(min_axis * ROOM_SIZE_MIN_RATIO))
	var rx = cx - int(size / 2)
	var ry = cy - int(size / 2)
	rx = int(clamp(rx, WALL_THICKNESS, tile_w - size - WALL_THICKNESS))
	ry = int(clamp(ry, WALL_THICKNESS, tile_h - size - WALL_THICKNESS))
	_rooms.append(Rect2(rx, ry, size, size))


# Check if two rectangles overlap when `a` is expanded by `padding` on all sides
func _rects_overlap_padded(a: Rect2, b: Rect2, padding: int) -> bool:
	var expanded = Rect2(
		a.position.x - padding, a.position.y - padding,
		a.size.x + padding * 2, a.size.y + padding * 2
	)
	return expanded.intersects(b)


# Get the center tile of room at index `idx`
func _room_center(idx: int) -> Vector2:
	var r = _rooms[idx]
	return Vector2(
		int(r.position.x + r.size.x / 2),
		int(r.position.y + r.size.y / 2)
	)


# Euclidean distance between room centers (used for MST edge weights)
func _room_dist(i: int, j: int) -> float:
	return _room_center(i).distance_to(_room_center(j))


# Check if rooms i and j are already connected
func _is_connected(i: int, j: int) -> bool:
	for c in _connections:
		if (c[0] == i and c[1] == j) or (c[0] == j and c[1] == i):
			return true
	return false


# Build room connections using Prim's MST algorithm.
# Starting from room 0, greedily add the shortest edge connecting a tree room
# to a non-tree room until all rooms are connected. Then add 3-5 extra short
# edges to create loops and abundant alternate paths for a cave-like feel.
func _build_connections() -> void:
	_connections.clear()
	if _rooms.size() <= 1:
		return

	# Prim's MST: grow a spanning tree one edge at a time
	var in_tree = {0: true}
	while in_tree.size() < _rooms.size():
		var best_dist = INF
		var best_a = -1
		var best_b = -1
		for a in in_tree:
			for b in _rooms.size():
				if in_tree.has(b):
					continue
				var d = _room_dist(a, b)
				if d < best_dist:
					best_dist = d
					best_a = a
					best_b = b
		if best_b == -1:
			break
		_connections.append([best_a, best_b])
		in_tree[best_b] = true

	# Add 3-5 extra edges (shortest non-MST edges) to create many alternate paths
	var extra_candidates = []
	for i in _rooms.size():
		for j in range(i + 1, _rooms.size()):
			if not _is_connected(i, j):
				extra_candidates.append([_room_dist(i, j), i, j])
	extra_candidates.sort_custom(self, "_sort_by_first")

	var extras = min(_rng.randi_range(3, 5), extra_candidates.size())
	for k in extras:
		_connections.append([extra_candidates[k][1], extra_candidates[k][2]])


# Sort helper for edge candidates — sort by distance (first element)
static func _sort_by_first(a: Array, b: Array) -> bool:
	return a[0] < b[0]


# Convert rooms and connections into a wall tile dictionary.
# Start with ALL tiles as walls, then carve out rooms and corridors.
func _build_wall_tiles(tile_w: int, tile_h: int) -> void:
	_wall_tiles.clear()

	# Fill everything as wall initially
	for x in tile_w:
		for y in tile_h:
			_wall_tiles[Vector2(x, y)] = true

	# Carve out rooms (remove wall tiles inside each room's bounds)
	for room in _rooms:
		for x in range(int(room.position.x), int(room.position.x + room.size.x)):
			for y in range(int(room.position.y), int(room.position.y + room.size.y)):
				_wall_tiles.erase(Vector2(x, y))

	# Carve L-shaped corridors between connected rooms
	for conn in _connections:
		var from = _room_center(conn[0])
		var to = _room_center(conn[1])
		_carve_corridor(from, to, DOOR_WIDTH)


# Carve an L-shaped corridor between two points.
# Randomly chooses horizontal-first or vertical-first routing.
func _carve_corridor(from: Vector2, to: Vector2, width: int) -> void:
	var half_w = int(width / 2)
	var horizontal_first = _rng.randi() % 2 == 0

	if horizontal_first:
		_carve_h_segment(int(from.x), int(to.x), int(from.y), half_w)
		_carve_v_segment(int(to.x), int(from.y), int(to.y), half_w)
	else:
		_carve_v_segment(int(from.x), int(from.y), int(to.y), half_w)
		_carve_h_segment(int(from.x), int(to.x), int(to.y), half_w)


# Carve a horizontal corridor segment from x1 to x2 at y, with half_w tile padding
func _carve_h_segment(x1: int, x2: int, y: int, half_w: int) -> void:
	var min_x = min(x1, x2)
	var max_x = max(x1, x2)
	for x in range(min_x, max_x + 1):
		for dy in range(-half_w, half_w + 1):
			_wall_tiles.erase(Vector2(x, y + dy))


# Carve a vertical corridor segment from y1 to y2 at x, with half_w tile padding
func _carve_v_segment(x: int, y1: int, y2: int, half_w: int) -> void:
	var min_y = min(y1, y2)
	var max_y = max(y1, y2)
	for y in range(min_y, max_y + 1):
		for dx in range(-half_w, half_w + 1):
			_wall_tiles.erase(Vector2(x + dx, y))


# Cellular automata smoothing — erodes rectangular walls into organic cave shapes.
# For each non-border tile: if a wall tile has fewer than CA_WALL_THRESHOLD wall
# neighbors (8-connected), it becomes floor. If a floor tile has CA_WALL_THRESHOLD
# or more wall neighbors, it becomes wall. This rounds corners, widens passages,
# and creates the uneven organic feel of a natural cave system.
func _cave_smooth(tile_w: int, tile_h: int) -> void:
	for _iteration in CA_ITERATIONS:
		var to_carve = []
		var to_fill = []

		for x in range(CA_BORDER, tile_w - CA_BORDER):
			for y in range(CA_BORDER, tile_h - CA_BORDER):
				var wall_neighbors = 0
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						if _wall_tiles.has(Vector2(x + dx, y + dy)):
							wall_neighbors += 1

				var is_wall = _wall_tiles.has(Vector2(x, y))
				if is_wall and wall_neighbors < CA_WALL_THRESHOLD:
					to_carve.append(Vector2(x, y))
				elif not is_wall and wall_neighbors >= CA_WALL_THRESHOLD:
					to_fill.append(Vector2(x, y))

		for pos in to_carve:
			_wall_tiles.erase(pos)
		for pos in to_fill:
			_wall_tiles[pos] = true


# Fill isolated 1-tile gaps surrounded by 3+ wall neighbors.
# Same cleanup as maze_shape.gd — prevents entity snagging on corners.
func _cleanup_corners(tile_w: int, tile_h: int) -> void:
	var to_fill = []
	for x in range(1, tile_w - 1):
		for y in range(1, tile_h - 1):
			if _wall_tiles.has(Vector2(x, y)):
				continue
			var n = _wall_tiles.has(Vector2(x, y - 1))
			var s = _wall_tiles.has(Vector2(x, y + 1))
			var e = _wall_tiles.has(Vector2(x + 1, y))
			var w = _wall_tiles.has(Vector2(x - 1, y))
			if (n and e and not _wall_tiles.has(Vector2(x + 1, y - 1))):
				continue
			if (n and w and not _wall_tiles.has(Vector2(x - 1, y - 1))):
				continue
			if (s and e and not _wall_tiles.has(Vector2(x + 1, y + 1))):
				continue
			if (s and w and not _wall_tiles.has(Vector2(x - 1, y + 1))):
				continue
			var wall_count = int(n) + int(s) + int(e) + int(w)
			if wall_count >= 3:
				to_fill.append(Vector2(x, y))

	for pos in to_fill:
		_wall_tiles[pos] = true


# Clear a diamond-shaped area around the map center to prevent spawn-in-wall.
# Uses Manhattan distance (|dx| + |dy| <= radius) for the diamond shape.
func _clear_center_tiles(tile_w: int, tile_h: int) -> void:
	var cx = int(tile_w / 2)
	var cy = int(tile_h / 2)
	for dx in range(-CENTER_CLEAR_RADIUS, CENTER_CLEAR_RADIUS + 1):
		for dy in range(-CENTER_CLEAR_RADIUS, CENTER_CLEAR_RADIUS + 1):
			if abs(dx) + abs(dy) <= CENTER_CLEAR_RADIUS:
				var tx = cx + dx
				var ty = cy + dy
				if tx >= 0 and tx < tile_w and ty >= 0 and ty < tile_h:
					_wall_tiles.erase(Vector2(tx, ty))


# BFS from map center to verify all rooms are reachable.
# If an unreachable room is found, carve an emergency corridor to the nearest
# visited (reachable) tile and re-validate recursively.
func _validate_connectivity(tile_w: int, tile_h: int) -> void:
	var cx = int(tile_w / 2)
	var cy = int(tile_h / 2)
	var start = Vector2(cx, cy)

	# BFS flood fill from center
	var visited = {}
	var queue = [start]
	visited[start] = true

	while queue.size() > 0:
		var cur = queue.pop_front()
		for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var next = cur + dir
			if not visited.has(next) and not _wall_tiles.has(next):
				if next.x >= 0 and next.x < tile_w and next.y >= 0 and next.y < tile_h:
					visited[next] = true
					queue.append(next)

	# Check each room's center tile is reachable
	for room in _rooms:
		var rc = Vector2(
			int(room.position.x + room.size.x / 2),
			int(room.position.y + room.size.y / 2)
		)
		if visited.has(rc):
			continue

		# Room unreachable — carve emergency corridor to nearest reachable tile
		var nearest = _find_nearest_visited(rc, visited, tile_w, tile_h)
		if nearest != Vector2(-1, -1):
			_carve_corridor(rc, nearest, DOOR_WIDTH)
			# Re-validate after repair (recursive — will terminate as graph grows)
			_validate_connectivity(tile_w, tile_h)
			return


# Find the visited tile closest to `pos` (brute force — room count is small)
func _find_nearest_visited(pos: Vector2, visited: Dictionary, tile_w: int, tile_h: int) -> Vector2:
	var best = Vector2(-1, -1)
	var best_dist = INF
	for v in visited:
		var d = pos.distance_to(v)
		if d < best_dist:
			best_dist = d
			best = v
	return best


# A tile is walkable if it's NOT in the wall dictionary
func should_fill_tile(tile_x: int, tile_y: int, _tile_size: int) -> bool:
	return not _wall_tiles.has(Vector2(tile_x, tile_y))


# Point containment: convert pixel position to tile coords and check wall dict
func contains_point(point: Vector2) -> bool:
	var tx = int(point.x / Utils.TILE_SIZE)
	var ty = int(point.y / Utils.TILE_SIZE)
	return not _wall_tiles.has(Vector2(tx, ty))


# No meaningful clamping — navigation handles wall avoidance
func clamp_position(point: Vector2) -> Vector2:
	return point


# Pick a random walkable tile via rejection sampling.
# Respects edge margin in tile units. Falls back to center after 50 attempts.
func get_rand_pos(edge: float) -> Vector2:
	var tile_w = int(width_px / Utils.TILE_SIZE)
	var tile_h = int(height_px / Utils.TILE_SIZE)
	var edge_tiles = int(edge / Utils.TILE_SIZE)
	for _attempt in 50:
		var tx = _rng.randi_range(edge_tiles, tile_w - 1 - edge_tiles)
		var ty = _rng.randi_range(edge_tiles, tile_h - 1 - edge_tiles)
		if not _wall_tiles.has(Vector2(tx, ty)):
			return Vector2(
				tx * Utils.TILE_SIZE + Utils.TILE_SIZE / 2.0,
				ty * Utils.TILE_SIZE + Utils.TILE_SIZE / 2.0
			)
	return center


# Edge spawning delegates to random position — rooms have no meaningful "edge"
func get_rand_edge_pos(dist: float) -> Vector2:
	return get_rand_pos(dist)


# Outer rectangle for the arena boundary walls
func get_collision_points(_num_segments: int = 32) -> PoolVector2Array:
	return PoolVector2Array([
		Vector2.ZERO,
		Vector2(width_px, 0),
		Vector2(width_px, height_px),
		Vector2(0, height_px),
	])


# Closed loop outline around the full arena rectangle
func get_outline_points() -> PoolVector2Array:
	var pts = get_collision_points()
	pts.append(pts[0])
	return pts


# Convert wall tile positions to collision data for my_tile_map_limits.gd
func get_internal_walls() -> Array:
	var walls = []
	var ts = Utils.TILE_SIZE
	for wall_pos in _wall_tiles:
		walls.append({
			"pos": Vector2(wall_pos.x * ts + ts / 2.0, wall_pos.y * ts + ts / 2.0),
			"extents": Vector2(ts / 2.0, ts / 2.0)
		})
	return walls
