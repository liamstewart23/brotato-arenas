extends "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd"

# Maze grid: each cell is CELL_SIZE x CELL_SIZE tiles
const CELL_SIZE := 6
const WALL_THICKNESS := 1  # wall thickness in tiles

var grid_w: int = 0
var grid_h: int = 0
var _cells: Array = []  # 2D array [x][y] of bitmask (N=1, E=2, S=4, W=8) for open passages
var _wall_tiles: Dictionary = {}  # {Vector2(tx, ty): true} for wall tile positions
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func get_shape_id() -> int:
	return SHAPE_MAZE


func setup(p_width_px: float, p_height_px: float) -> void:
	.setup(p_width_px, p_height_px)

	var tile_w = int(p_width_px / Utils.TILE_SIZE)
	var tile_h = int(p_height_px / Utils.TILE_SIZE)
	grid_w = max(2, tile_w / CELL_SIZE)
	grid_h = max(2, tile_h / CELL_SIZE)

	_rng.randomize()  # unique maze layout every run
	_generate_maze()
	_clear_center_cell()
	_build_wall_tiles(tile_w, tile_h)
	_clear_center_tiles(tile_w, tile_h)


func _clear_center_cell() -> void:
	# Find the grid cell that contains the map center and carve all passages
	# so the player can never spawn inside a wall
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


func _clear_center_tiles(tile_w: int, tile_h: int) -> void:
	# Remove any wall tiles in a radius around the exact spawn point
	# Player spawns at pixel center = (tile_w / 2, tile_h / 2) in tile coords
	var cx = int(tile_w / 2)
	var cy = int(tile_h / 2)
	# Clear a 3x3 area around spawn to guarantee no wall overlap
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			_wall_tiles.erase(Vector2(cx + dx, cy + dy))


func _generate_maze() -> void:
	# Initialize grid with no passages
	_cells.clear()
	for x in grid_w:
		var col = []
		for _y in grid_h:
			col.append(0)
		_cells.append(col)

	# Recursive backtracker
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
			stack.pop_back()
		else:
			var next = neighbors[_rng.randi() % neighbors.size()]
			var nx = int(next.x)
			var ny = int(next.y)

			# Carve passage
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


func _build_wall_tiles(tile_w: int, tile_h: int) -> void:
	_wall_tiles.clear()

	for gx in grid_w:
		for gy in grid_h:
			var bx = gx * CELL_SIZE
			var by = gy * CELL_SIZE

			# South wall (WALL_THICKNESS rows)
			if not (_cells[gx][gy] & 4):
				for wt in WALL_THICKNESS:
					var wy = by + CELL_SIZE - WALL_THICKNESS + wt
					if wy < tile_h:
						for wx in range(bx, min(bx + CELL_SIZE, tile_w)):
							_wall_tiles[Vector2(wx, wy)] = true

			# East wall (WALL_THICKNESS columns)
			if not (_cells[gx][gy] & 2):
				for wt in WALL_THICKNESS:
					var wx = bx + CELL_SIZE - WALL_THICKNESS + wt
					if wx < tile_w:
						for wy in range(by, min(by + CELL_SIZE, tile_h)):
							_wall_tiles[Vector2(wx, wy)] = true

	# Corner cleanup: fill diagonal gaps where two walls meet at a corner
	# to prevent single-tile snag points
	_cleanup_corners(tile_w, tile_h)


func _cleanup_corners(tile_w: int, tile_h: int) -> void:
	var to_fill = []
	for x in range(1, tile_w - 1):
		for y in range(1, tile_h - 1):
			if _wall_tiles.has(Vector2(x, y)):
				continue
			# Check if this open tile creates a diagonal snag:
			# wall above + wall left but open above-left (or similar combos)
			var n = _wall_tiles.has(Vector2(x, y - 1))
			var s = _wall_tiles.has(Vector2(x, y + 1))
			var e = _wall_tiles.has(Vector2(x + 1, y))
			var w = _wall_tiles.has(Vector2(x - 1, y))
			# If two adjacent orthogonal neighbors are walls forming a corner,
			# and the diagonal between them is open, fill this tile
			if (n and e and not _wall_tiles.has(Vector2(x + 1, y - 1))):
				continue
			if (n and w and not _wall_tiles.has(Vector2(x - 1, y - 1))):
				continue
			if (s and e and not _wall_tiles.has(Vector2(x + 1, y + 1))):
				continue
			if (s and w and not _wall_tiles.has(Vector2(x - 1, y + 1))):
				continue
			# Fill isolated single-tile gaps surrounded by 3+ walls
			var wall_count = int(n) + int(s) + int(e) + int(w)
			if wall_count >= 3:
				to_fill.append(Vector2(x, y))

	for pos in to_fill:
		_wall_tiles[pos] = true


func should_fill_tile(tile_x: int, tile_y: int, _tile_size: int) -> bool:
	return not _wall_tiles.has(Vector2(tile_x, tile_y))


func contains_point(point: Vector2) -> bool:
	var tx = int(point.x / Utils.TILE_SIZE)
	var ty = int(point.y / Utils.TILE_SIZE)
	return not _wall_tiles.has(Vector2(tx, ty))


func clamp_position(point: Vector2) -> Vector2:
	return point


func get_rand_pos(edge: float) -> Vector2:
	# Pick a random corridor tile
	var tile_w = int(width_px / Utils.TILE_SIZE)
	var tile_h = int(height_px / Utils.TILE_SIZE)
	for _attempt in 50:
		var tx = _rng.randi_range(0, tile_w - 1)
		var ty = _rng.randi_range(0, tile_h - 1)
		if not _wall_tiles.has(Vector2(tx, ty)):
			return Vector2(
				tx * Utils.TILE_SIZE + Utils.TILE_SIZE / 2.0,
				ty * Utils.TILE_SIZE + Utils.TILE_SIZE / 2.0
			)
	return center


func get_rand_edge_pos(dist: float) -> Vector2:
	return get_rand_pos(dist)


func get_collision_points(_num_segments: int = 32) -> PoolVector2Array:
	return PoolVector2Array([
		Vector2.ZERO,
		Vector2(width_px, 0),
		Vector2(width_px, height_px),
		Vector2(0, height_px),
	])


func get_outline_points() -> PoolVector2Array:
	var pts = get_collision_points()
	pts.append(pts[0])
	return pts


func get_internal_walls() -> Array:
	var walls = []
	var ts = Utils.TILE_SIZE
	for wall_pos in _wall_tiles:
		walls.append({
			"pos": Vector2(wall_pos.x * ts + ts / 2.0, wall_pos.y * ts + ts / 2.0),
			"extents": Vector2(ts / 2.0, ts / 2.0)
		})
	return walls
