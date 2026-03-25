# multiroom_shape.gd — Organic cave system via cellular automata.
#
# Uses the classic roguelike cave generation algorithm:
# 1. Seed the map with ~45% random walls
# 2. Run 5 cellular automata iterations (B5678/S5678 rule)
# 3. Keep only the largest connected region (flood fill)
# 4. Validate connectivity from center as a safety net
#
# This produces natural-looking cave systems with varied chamber sizes,
# winding passages, irregular walls, and organic features — no rectangular
# rooms or straight corridors.
#
# Wall tiles are stored in a dictionary for O(1) lookup, same as maze_shape.gd.

extends "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd"

# Layout constants
const WALL_THICKNESS := 1          # border wall ring (1 tile; outline covers the visual gap)
const CENTER_CLEAR_RADIUS := 3     # diamond-shaped spawn safety zone
const CENTER_SEED_RADIUS := 5      # pre-CA center clear (survives smoothing)

# Cellular automata parameters
const INITIAL_WALL_CHANCE := 0.48  # probability each interior tile starts as wall
const CA_ITERATIONS := 5           # number of smoothing passes
const CA_WALL_THRESHOLD := 5       # neighbors needed to become/stay wall (out of 8)
const CA_BORDER := 1               # border tiles always remain walls during CA

# Detail pass: scatter wall pillars in large open areas
const PILLAR_MIN_OPEN := 5         # min open radius around a tile to place a pillar
const PILLAR_CHANCE := 0.04        # chance per eligible tile to become a pillar seed

# Emergency connectivity repair
const TUNNEL_WIDTH := 3            # width of tunnels carved during repair

var _wall_tiles: Dictionary = {}   # {Vector2(tx, ty): true} for wall positions
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func get_shape_id() -> int:
	return SHAPE_MULTIROOM


func setup(p_width_px: float, p_height_px: float) -> void:
	.setup(p_width_px, p_height_px)
	_rng.randomize()

	var tile_w = int(p_width_px / Utils.TILE_SIZE)
	var tile_h = int(p_height_px / Utils.TILE_SIZE)

	_random_fill(tile_w, tile_h)
	_cave_smooth(tile_w, tile_h)
	_keep_largest_region(tile_w, tile_h)
	_scatter_pillars(tile_w, tile_h)
	_cleanup_corners(tile_w, tile_h)
	_chamfer_inner_corners(tile_w, tile_h)
	_clear_center_tiles(tile_w, tile_h)
	_validate_connectivity(tile_w, tile_h)


# Seed the map: border tiles are always walls, interior tiles are walls with
# INITIAL_WALL_CHANCE probability. A circle around the center is forced to
# floor so the spawn area survives CA smoothing.
func _random_fill(tile_w: int, tile_h: int) -> void:
	_wall_tiles.clear()

	var cx = int(tile_w / 2)
	var cy = int(tile_h / 2)

	for x in tile_w:
		for y in tile_h:
			# Border ring is always wall
			if x < WALL_THICKNESS or x >= tile_w - WALL_THICKNESS \
					or y < WALL_THICKNESS or y >= tile_h - WALL_THICKNESS:
				_wall_tiles[Vector2(x, y)] = true
				continue

			# Seed center area as floor so spawn survives CA
			var dx = x - cx
			var dy = y - cy
			if dx * dx + dy * dy <= CENTER_SEED_RADIUS * CENTER_SEED_RADIUS:
				continue

			# Random wall/floor
			if _rng.randf() < INITIAL_WALL_CHANCE:
				_wall_tiles[Vector2(x, y)] = true


# Cellular automata smoothing — the core cave generation step.
# Each tile checks its 8 neighbors. Walls with few wall neighbors erode to
# floor; floor tiles surrounded by walls fill in. After several iterations,
# random noise consolidates into smooth organic cave chambers and passages.
func _cave_smooth(tile_w: int, tile_h: int) -> void:
	for _iteration in CA_ITERATIONS:
		var to_carve = []
		var to_fill = []

		for x in range(CA_BORDER, tile_w - CA_BORDER):
			for y in range(CA_BORDER, tile_h - CA_BORDER):
				var wall_neighbors = 0
				for ndx in range(-1, 2):
					for ndy in range(-1, 2):
						if ndx == 0 and ndy == 0:
							continue
						if _wall_tiles.has(Vector2(x + ndx, y + ndy)):
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


# Flood fill to find all connected floor regions. Keep the region that contains
# the center tile (spawn point). If that region is not the largest, also keep
# the largest and carve a tunnel to merge them. Fill all other regions with walls.
func _keep_largest_region(tile_w: int, tile_h: int) -> void:
	var cx = int(tile_w / 2)
	var cy = int(tile_h / 2)
	var center_vec = Vector2(cx, cy)

	# Build set of all floor tiles
	var all_floor = {}
	for x in range(WALL_THICKNESS, tile_w - WALL_THICKNESS):
		for y in range(WALL_THICKNESS, tile_h - WALL_THICKNESS):
			var v = Vector2(x, y)
			if not _wall_tiles.has(v):
				all_floor[v] = true

	# Flood fill to find connected regions
	var regions = []
	var assigned = {}

	for tile in all_floor:
		if assigned.has(tile):
			continue
		# BFS from this tile
		var region = []
		var queue = [tile]
		assigned[tile] = regions.size()
		while queue.size() > 0:
			var cur = queue.pop_front()
			region.append(cur)
			for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				var next = cur + dir
				if all_floor.has(next) and not assigned.has(next):
					assigned[next] = regions.size()
					queue.append(next)
		regions.append(region)

	if regions.size() == 0:
		return

	# Find which region contains center and which is largest
	var center_region_idx = -1
	var largest_region_idx = 0
	for i in regions.size():
		if regions[i].size() > regions[largest_region_idx].size():
			largest_region_idx = i

	if assigned.has(center_vec):
		center_region_idx = assigned[center_vec]

	# Decide which regions to keep
	var keep = {}
	keep[largest_region_idx] = true
	if center_region_idx >= 0:
		keep[center_region_idx] = true

	# Fill all non-kept regions with walls
	for i in regions.size():
		if keep.has(i):
			continue
		for tile in regions[i]:
			_wall_tiles[tile] = true

	# If center region differs from largest, carve a tunnel to merge them
	if center_region_idx >= 0 and center_region_idx != largest_region_idx:
		_carve_tunnel_between_regions(regions[center_region_idx], regions[largest_region_idx])


# Carve a straight tunnel between the two closest tiles of two regions.
func _carve_tunnel_between_regions(region_a: Array, region_b: Array) -> void:
	# Find the closest pair of tiles between the two regions
	# Sample up to 200 tiles from each to keep it fast
	var sample_a = region_a
	if sample_a.size() > 200:
		sample_a = []
		for _i in 200:
			sample_a.append(region_a[_rng.randi() % region_a.size()])

	var sample_b = region_b
	if sample_b.size() > 200:
		sample_b = []
		for _i in 200:
			sample_b.append(region_b[_rng.randi() % region_b.size()])

	var best_a = sample_a[0]
	var best_b = sample_b[0]
	var best_dist = best_a.distance_to(best_b)

	for a in sample_a:
		for b in sample_b:
			var d = a.distance_to(b)
			if d < best_dist:
				best_dist = d
				best_a = a
				best_b = b

	_carve_tunnel(best_a, best_b)


# Carve a tunnel from point A to point B using Bresenham-like stepping.
# Width is TUNNEL_WIDTH tiles (±half_w from center line).
func _carve_tunnel(from: Vector2, to: Vector2) -> void:
	var half_w = int(TUNNEL_WIDTH / 2)
	var x0 = int(from.x)
	var y0 = int(from.y)
	var x1 = int(to.x)
	var y1 = int(to.y)

	# Step along the longer axis
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy

	while true:
		# Carve a circle of radius half_w at current position
		for ox in range(-half_w, half_w + 1):
			for oy in range(-half_w, half_w + 1):
				_wall_tiles.erase(Vector2(x0 + ox, y0 + oy))

		if x0 == x1 and y0 == y1:
			break

		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy


# Scatter small wall pillar clusters in large open areas for cover and depth.
# Only places pillars where the surrounding area is wide open (no nearby walls),
# so tight passages and small chambers stay clear. Pillars are 2x2 blocks that
# break up large featureless chambers and give enemies/players tactical cover.
func _scatter_pillars(tile_w: int, tile_h: int) -> void:
	var pillars = []
	var cx = int(tile_w / 2)
	var cy = int(tile_h / 2)

	for x in range(WALL_THICKNESS + 2, tile_w - WALL_THICKNESS - 2):
		for y in range(WALL_THICKNESS + 2, tile_h - WALL_THICKNESS - 2):
			if _wall_tiles.has(Vector2(x, y)):
				continue
			# Skip near center spawn
			if abs(x - cx) <= CENTER_SEED_RADIUS and abs(y - cy) <= CENTER_SEED_RADIUS:
				continue
			if _rng.randf() >= PILLAR_CHANCE:
				continue
			# Check that surrounding area is wide open
			var open = true
			for dx in range(-PILLAR_MIN_OPEN, PILLAR_MIN_OPEN + 1):
				for dy in range(-PILLAR_MIN_OPEN, PILLAR_MIN_OPEN + 1):
					if _wall_tiles.has(Vector2(x + dx, y + dy)):
						open = false
						break
				if not open:
					break
			if open:
				pillars.append(Vector2(x, y))

	# Place 2x2 pillar blocks
	for pos in pillars:
		for dx in 2:
			for dy in 2:
				_wall_tiles[Vector2(pos.x + dx, pos.y + dy)] = true


# Close diagonal gaps where two walls touch only at a corner, and fill
# dead-end pockets. Same logic as maze_shape.gd — prevents mobs getting
# stuck on diagonal wall corners.
func _cleanup_corners(tile_w: int, tile_h: int) -> void:
	var to_fill = {}

	# Pass 1: seal diagonal wall pairs (checkerboard in any 2x2 block)
	for x in range(0, tile_w - 1):
		for y in range(0, tile_h - 1):
			var tl = _wall_tiles.has(Vector2(x, y))
			var tr = _wall_tiles.has(Vector2(x + 1, y))
			var bl = _wall_tiles.has(Vector2(x, y + 1))
			var br = _wall_tiles.has(Vector2(x + 1, y + 1))

			if tl and br and not tr and not bl:
				to_fill[_pick_fill_target(x + 1, y, x, y + 1, tile_w, tile_h)] = true
			elif tr and bl and not tl and not br:
				to_fill[_pick_fill_target(x, y, x + 1, y + 1, tile_w, tile_h)] = true

	# Pass 2: fill floor tiles with 3+ orthogonal wall neighbors (dead pockets)
	for x in range(1, tile_w - 1):
		for y in range(1, tile_h - 1):
			if _wall_tiles.has(Vector2(x, y)) or to_fill.has(Vector2(x, y)):
				continue
			var wall_count = 0
			if _wall_tiles.has(Vector2(x, y - 1)) or to_fill.has(Vector2(x, y - 1)):
				wall_count += 1
			if _wall_tiles.has(Vector2(x, y + 1)) or to_fill.has(Vector2(x, y + 1)):
				wall_count += 1
			if _wall_tiles.has(Vector2(x + 1, y)) or to_fill.has(Vector2(x + 1, y)):
				wall_count += 1
			if _wall_tiles.has(Vector2(x - 1, y)) or to_fill.has(Vector2(x - 1, y)):
				wall_count += 1
			if wall_count >= 3:
				to_fill[Vector2(x, y)] = true

	for pos in to_fill:
		_wall_tiles[pos] = true


func _pick_fill_target(ax: int, ay: int, bx: int, by: int, tile_w: int, tile_h: int) -> Vector2:
	var a = Vector2(ax, ay)
	var b = Vector2(bx, by)
	var a_border = ax <= 0 or ax >= tile_w - 1 or ay <= 0 or ay >= tile_h - 1
	var b_border = bx <= 0 or bx >= tile_w - 1 or by <= 0 or by >= tile_h - 1
	if a_border and not b_border:
		return b
	if b_border and not a_border:
		return a
	var a_walls = _count_ortho_walls(ax, ay)
	var b_walls = _count_ortho_walls(bx, by)
	return a if a_walls >= b_walls else b


func _count_ortho_walls(x: int, y: int) -> int:
	var count = 0
	if _wall_tiles.has(Vector2(x, y - 1)): count += 1
	if _wall_tiles.has(Vector2(x, y + 1)): count += 1
	if _wall_tiles.has(Vector2(x + 1, y)): count += 1
	if _wall_tiles.has(Vector2(x - 1, y)): count += 1
	return count


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


# Safety net: BFS from center, check that all floor tiles are reachable.
# If any disconnected floor tiles remain (shouldn't happen after
# _keep_largest_region, but defensive), carve a tunnel to reconnect.
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

	# Check for any unreachable floor tiles and carve to them
	for x in range(WALL_THICKNESS, tile_w - WALL_THICKNESS):
		for y in range(WALL_THICKNESS, tile_h - WALL_THICKNESS):
			var v = Vector2(x, y)
			if not _wall_tiles.has(v) and not visited.has(v):
				# Found unreachable floor — carve tunnel to nearest reachable tile
				var nearest = _find_nearest_visited(v, visited, tile_w, tile_h)
				if nearest != Vector2(-1, -1):
					_carve_tunnel(v, nearest)
					# Re-validate after repair
					_validate_connectivity(tile_w, tile_h)
					return


# Find the visited tile closest to `pos` (brute force — called rarely)
func _find_nearest_visited(pos: Vector2, visited: Dictionary, _tile_w: int, _tile_h: int) -> Vector2:
	var best = Vector2(-1, -1)
	var best_dist = INF
	for v in visited:
		var d = pos.distance_to(v)
		if d < best_dist:
			best_dist = d
			best = v
	return best


# --- Public API (unchanged — all depend only on _wall_tiles) ---


# Bevel inner right-angle wall corners so mobs don't clip them when turning.
func _chamfer_inner_corners(tile_w: int, tile_h: int) -> void:
	var to_remove = []
	for x in range(1, tile_w - 1):
		for y in range(1, tile_h - 1):
			if not _wall_tiles.has(Vector2(x, y)):
				continue

			var n = _wall_tiles.has(Vector2(x, y - 1))
			var s = _wall_tiles.has(Vector2(x, y + 1))
			var e = _wall_tiles.has(Vector2(x + 1, y))
			var w = _wall_tiles.has(Vector2(x - 1, y))

			if n and e and not s and not w and _wall_tiles.has(Vector2(x + 1, y - 1)):
				to_remove.append(Vector2(x, y))
			elif n and w and not s and not e and _wall_tiles.has(Vector2(x - 1, y - 1)):
				to_remove.append(Vector2(x, y))
			elif s and e and not n and not w and _wall_tiles.has(Vector2(x + 1, y + 1)):
				to_remove.append(Vector2(x, y))
			elif s and w and not n and not e and _wall_tiles.has(Vector2(x - 1, y + 1)):
				to_remove.append(Vector2(x, y))

	for pos in to_remove:
		_wall_tiles.erase(pos)


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


# Edge spawning delegates to random position — caves have no meaningful "edge"
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
