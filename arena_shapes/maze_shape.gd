# maze_shape.gd — Procedural maze generated via recursive backtracker.
#
# Divides the arena into a grid of CELL_SIZE x CELL_SIZE tile cells, then
# carves a perfect maze (every cell reachable from every other cell) using the
# recursive backtracker algorithm (randomized DFS). Each cell tracks which
# passages are open via a 4-bit bitmask: N=1, E=2, S=4, W=8.
#
# After generation, the center cell is fully opened (all 4 passages carved) and
# a 3x3 area of wall tiles around the spawn point is cleared to guarantee the
# player never spawns inside a wall.
#
# Wall tiles are stored in a dictionary for O(1) lookup by tile coordinate.
# A corner cleanup pass fills isolated single-tile gaps surrounded by 3+ walls
# to prevent entities from snagging on diagonal corners.
#
# Navigation (AStar2D pathfinding for enemies/pets) is handled by my_tile_map.gd,
# not here — this shape only defines the wall layout.

extends "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd"

# Maze grid: each cell is CELL_SIZE x CELL_SIZE tiles
const CELL_SIZE := 6
const WALL_THICKNESS := 1  # wall thickness in tiles

var grid_w: int = 0              # number of cells horizontally
var grid_h: int = 0              # number of cells vertically
var _cells: Array = []           # 2D array [x][y] of bitmask (N=1, E=2, S=4, W=8)
var _wall_tiles: Dictionary = {} # {Vector2(tx, ty): true} for wall tile positions
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func get_shape_id() -> int:
	return SHAPE_MAZE


func setup(p_width_px: float, p_height_px: float) -> void:
	.setup(p_width_px, p_height_px)

	# Calculate grid dimensions from arena size and cell size.
	# Ceiling division ensures the maze grid spans the full tile area
	# so outer walls land on the map edge with no gap beyond them.
	var tile_w = int(p_width_px / Utils.TILE_SIZE)
	var tile_h = int(p_height_px / Utils.TILE_SIZE)
	grid_w = max(2, (tile_w + CELL_SIZE - 1) / CELL_SIZE)
	grid_h = max(2, (tile_h + CELL_SIZE - 1) / CELL_SIZE)

	_rng.randomize()  # unique maze layout every run
	_generate_maze()
	_clear_center_cell()
	_build_wall_tiles(tile_w, tile_h)
	_widen_narrow_passages(tile_w, tile_h)
	_cleanup_corners(tile_w, tile_h)
	_chamfer_inner_corners(tile_w, tile_h)
	_clear_center_tiles(tile_w, tile_h)


# Open all 4 passages from the grid cell containing the map center.
# This guarantees the player spawn area has room to move in every direction.
func _clear_center_cell() -> void:
	var center_gx = int(grid_w / 2)
	var center_gy = int(grid_h / 2)
	center_gx = clamp(center_gx, 0, grid_w - 1)
	center_gy = clamp(center_gy, 0, grid_h - 1)

	# Open all 4 passages from center cell (and matching passages on neighbors)
	if center_gy > 0:  # North
		_cells[center_gx][center_gy] |= 1
		_cells[center_gx][center_gy - 1] |= 4
	if center_gx < grid_w - 1:  # East
		_cells[center_gx][center_gy] |= 2
		_cells[center_gx + 1][center_gy] |= 8
	if center_gy < grid_h - 1:  # South
		_cells[center_gx][center_gy] |= 4
		_cells[center_gx][center_gy + 1] |= 1
	if center_gx > 0:  # West
		_cells[center_gx][center_gy] |= 8
		_cells[center_gx - 1][center_gy] |= 2


# Remove any wall tiles in a 3x3 area around the exact pixel-center spawn point.
# This is a safety net in case the cell-level clearing wasn't enough.
func _clear_center_tiles(tile_w: int, tile_h: int) -> void:
	var cx = int(tile_w / 2)
	var cy = int(tile_h / 2)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			_wall_tiles.erase(Vector2(cx + dx, cy + dy))


# Generate a perfect maze using recursive backtracker (randomized DFS).
# Starting from cell (0,0), visit random unvisited neighbors and carve
# passages between them. Backtrack when stuck. Produces a maze where every
# cell is reachable from every other cell (spanning tree of the grid graph).
func _generate_maze() -> void:
	# Initialize grid with no passages (all walls closed)
	_cells.clear()
	for x in grid_w:
		var col = []
		for _y in grid_h:
			col.append(0)
		_cells.append(col)

	# Recursive backtracker using an explicit stack
	var stack = []
	var visited = {}
	var start = Vector2(0, 0)
	visited[start] = true
	stack.push_back(start)

	while stack.size() > 0:
		var current = stack.back()
		var cx = int(current.x)
		var cy = int(current.y)
		var neighbors = _get_unvisited_neighbors(cx, cy, visited)

		if neighbors.empty():
			# Dead end — backtrack
			stack.pop_back()
		else:
			# Pick a random unvisited neighbor and carve a passage to it
			var next = neighbors[_rng.randi() % neighbors.size()]
			var nx = int(next.x)
			var ny = int(next.y)

			# Carve passage by setting bits on both sides of the wall
			if nx == cx + 1:  # East
				_cells[cx][cy] |= 2
				_cells[nx][ny] |= 8
			elif nx == cx - 1:  # West
				_cells[cx][cy] |= 8
				_cells[nx][ny] |= 2
			elif ny == cy + 1:  # South
				_cells[cx][cy] |= 4
				_cells[nx][ny] |= 1
			elif ny == cy - 1:  # North
				_cells[cx][cy] |= 1
				_cells[nx][ny] |= 4

			visited[next] = true
			stack.push_back(next)


# Return all unvisited orthogonal neighbors of cell (cx, cy)
func _get_unvisited_neighbors(cx: int, cy: int, visited: Dictionary) -> Array:
	var result = []
	if cx > 0 and not visited.has(Vector2(cx - 1, cy)):
		result.append(Vector2(cx - 1, cy))
	if cx < grid_w - 1 and not visited.has(Vector2(cx + 1, cy)):
		result.append(Vector2(cx + 1, cy))
	if cy > 0 and not visited.has(Vector2(cx, cy - 1)):
		result.append(Vector2(cx, cy - 1))
	if cy < grid_h - 1 and not visited.has(Vector2(cx, cy + 1)):
		result.append(Vector2(cx, cy + 1))
	return result


# Convert the cell bitmask grid into individual wall tiles.
# For each cell, if the South or East passage is closed, place wall tiles
# along that edge. (North and West walls are implicitly handled by the
# neighboring cell's South and East walls respectively.)
func _build_wall_tiles(tile_w: int, tile_h: int) -> void:
	_wall_tiles.clear()

	for gx in grid_w:
		for gy in grid_h:
			var bx = gx * CELL_SIZE
			var by = gy * CELL_SIZE

			# South wall: place WALL_THICKNESS rows of tiles at cell's bottom edge
			if not (_cells[gx][gy] & 4):
				for wt in WALL_THICKNESS:
					var wy = by + CELL_SIZE - WALL_THICKNESS + wt
					if wy < tile_h:
						for wx in range(bx, min(bx + CELL_SIZE, tile_w)):
							_wall_tiles[Vector2(wx, wy)] = true

			# East wall: place WALL_THICKNESS columns of tiles at cell's right edge
			if not (_cells[gx][gy] & 2):
				for wt in WALL_THICKNESS:
					var wx = bx + CELL_SIZE - WALL_THICKNESS + wt
					if wx < tile_w:
						for wy in range(by, min(by + CELL_SIZE, tile_h)):
							_wall_tiles[Vector2(wx, wy)] = true

	# Place solid walls along all 4 outer edges so the maze boundary
	# sits exactly on the map edge (prevents mobs spawning in gaps).
	_build_border_walls(tile_w, tile_h)


# Place solid wall tiles along all 4 outer edges of the tile map so the maze
# boundary always sits on the map edge with no walkable gap beyond it.
func _build_border_walls(tile_w: int, tile_h: int) -> void:
	for x in tile_w:
		_wall_tiles[Vector2(x, 0)] = true              # Top edge
		_wall_tiles[Vector2(x, tile_h - 1)] = true     # Bottom edge
	for y in tile_h:
		_wall_tiles[Vector2(0, y)] = true              # Left edge
		_wall_tiles[Vector2(tile_w - 1, y)] = true     # Right edge


# Ensure no passage is only 1 tile wide. Any floor tile with walls on both
# opposite sides (N+S or E+W) is a single-tile corridor — widen it by removing
# one of those wall tiles (preferring south/east, skipping border tiles).
# Runs iteratively since widening can expose new single-tile pinch points.
func _widen_narrow_passages(tile_w: int, tile_h: int) -> void:
	var changed = true
	while changed:
		changed = false
		var to_remove = []
		for x in range(1, tile_w - 1):
			for y in range(1, tile_h - 1):
				if _wall_tiles.has(Vector2(x, y)):
					continue
				var wall_n = _wall_tiles.has(Vector2(x, y - 1))
				var wall_s = _wall_tiles.has(Vector2(x, y + 1))
				var wall_e = _wall_tiles.has(Vector2(x + 1, y))
				var wall_w = _wall_tiles.has(Vector2(x - 1, y))

				# 1-tile-tall horizontal passage (walls north + south)
				if wall_n and wall_s:
					if y + 1 < tile_h - 1:
						to_remove.append(Vector2(x, y + 1))
					elif y - 1 > 0:
						to_remove.append(Vector2(x, y - 1))

				# 1-tile-wide vertical passage (walls east + west)
				if wall_e and wall_w:
					if x + 1 < tile_w - 1:
						to_remove.append(Vector2(x + 1, y))
					elif x - 1 > 0:
						to_remove.append(Vector2(x - 1, y))

		for pos in to_remove:
			if _wall_tiles.has(pos):
				_wall_tiles.erase(pos)
				changed = true


# Close diagonal gaps where two walls touch only at a corner. In each 2x2
# block, if walls sit on one diagonal and floor on the other (checkerboard),
# mobs try to squeeze through and get stuck. Fill one floor tile to seal it.
# Also fills any floor tile surrounded by 3+ orthogonal walls (dead-end pockets).
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
				# Diagonal: TL + BR are walls, TR + BL are floor — fill one
				to_fill[_pick_fill_target(x + 1, y, x, y + 1, tile_w, tile_h)] = true
			elif tr and bl and not tl and not br:
				# Diagonal: TR + BL are walls, TL + BR are floor — fill one
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


# Pick which of two floor tiles to fill when sealing a diagonal gap.
# Prefers the tile with more orthogonal wall neighbors (more "wall-like").
# Avoids border tiles so outer walls stay intact.
func _pick_fill_target(ax: int, ay: int, bx: int, by: int, tile_w: int, tile_h: int) -> Vector2:
	var a = Vector2(ax, ay)
	var b = Vector2(bx, by)
	# Don't fill border tiles
	var a_border = ax <= 0 or ax >= tile_w - 1 or ay <= 0 or ay >= tile_h - 1
	var b_border = bx <= 0 or bx >= tile_w - 1 or by <= 0 or by >= tile_h - 1
	if a_border and not b_border:
		return b
	if b_border and not a_border:
		return a
	# Count orthogonal wall neighbors — fill whichever is more wall-surrounded
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


# Bevel inner right-angle wall corners so mobs don't clip them when turning.
# An inner corner is a wall tile with exactly 2 adjacent orthogonal wall
# neighbors (forming an L), floor on the other 2 sides, and a solid diagonal
# behind the L. Removing it creates a smooth 45-degree cut at every junction.
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

			# NE inner corner: wall N+E, floor S+W, solid diagonal NE
			if n and e and not s and not w and _wall_tiles.has(Vector2(x + 1, y - 1)):
				to_remove.append(Vector2(x, y))
			# NW inner corner: wall N+W, floor S+E, solid diagonal NW
			elif n and w and not s and not e and _wall_tiles.has(Vector2(x - 1, y - 1)):
				to_remove.append(Vector2(x, y))
			# SE inner corner: wall S+E, floor N+W, solid diagonal SE
			elif s and e and not n and not w and _wall_tiles.has(Vector2(x + 1, y + 1)):
				to_remove.append(Vector2(x, y))
			# SW inner corner: wall S+W, floor N+E, solid diagonal SW
			elif s and w and not n and not e and _wall_tiles.has(Vector2(x - 1, y + 1)):
				to_remove.append(Vector2(x, y))

	for pos in to_remove:
		_wall_tiles.erase(pos)


# A tile is walkable (should be filled with floor) if it's NOT a wall tile
func should_fill_tile(tile_x: int, tile_y: int, _tile_size: int) -> bool:
	return not _wall_tiles.has(Vector2(tile_x, tile_y))


# Point containment: convert pixel position to tile coords and check wall dict
func contains_point(point: Vector2) -> bool:
	var tx = int(point.x / Utils.TILE_SIZE)
	var ty = int(point.y / Utils.TILE_SIZE)
	return not _wall_tiles.has(Vector2(tx, ty))


# No meaningful clamping for maze — entities stuck in walls are handled
# by the navigation system's anti-stuck detection instead
func clamp_position(point: Vector2) -> Vector2:
	return point


# Pick a random walkable (non-wall) tile via rejection sampling.
# Up to 50 attempts before falling back to center.
func get_rand_pos(edge: float) -> Vector2:
	var tile_w = int(width_px / Utils.TILE_SIZE)
	var tile_h = int(height_px / Utils.TILE_SIZE)
	for _attempt in 50:
		var tx = _rng.randi_range(0, tile_w - 1)
		var ty = _rng.randi_range(0, tile_h - 1)
		if not _wall_tiles.has(Vector2(tx, ty)):
			# Return the center of the tile in pixel coords
			return Vector2(
				tx * Utils.TILE_SIZE + Utils.TILE_SIZE / 2.0,
				ty * Utils.TILE_SIZE + Utils.TILE_SIZE / 2.0
			)
	return center


# Edge spawning delegates to random position — maze has no meaningful "edge"
func get_rand_edge_pos(dist: float) -> Vector2:
	return get_rand_pos(dist)


# Outer rectangle collision (maze uses internal walls for actual boundaries)
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


# Convert wall tile positions to collision data for my_tile_map_limits.gd.
# Each wall tile becomes a dict with center position and half-extents.
func get_internal_walls() -> Array:
	var walls = []
	var ts = Utils.TILE_SIZE
	for wall_pos in _wall_tiles:
		walls.append({
			"pos": Vector2(wall_pos.x * ts + ts / 2.0, wall_pos.y * ts + ts / 2.0),
			"extents": Vector2(ts / 2.0, ts / 2.0)
		})
	return walls
