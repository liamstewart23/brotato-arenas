# entity_spawner.gd — Shape-aware enemy and entity spawning.
#
# Overrides get_spawn_pos_in_area to delegate spawn position calculation to
# the active arena shape. Handles special cases:
#   - Rectangle/null, shrinking, hazard: fall through to vanilla spawning
#   - Curse Run: ALL enemies spawn from the right edge (facing the player)
#   - Circle/Hexagon/Maze/MultiRoom: use shape's get_rand_pos or get_rand_edge_pos
#   - If a vanilla-generated position lands in a wall, falls back to shape's
#     get_rand_pos to find a walkable tile

extends "res://global/entity_spawner.gd"

const ArenaShapeClass = preload("res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd")


func get_spawn_pos_in_area(base_pos: Vector2, area: int, spawn_dist_from_edges: int = 0, spawn_edge_of_map: bool = false) -> Vector2:
	var shape = ZoneService.arena_shape

	# Shapes that use vanilla rectangular spawning logic
	var sid = shape.get_shape_id() if shape != null else ArenaShapeClass.SHAPE_RECTANGLE
	if shape == null or sid == ArenaShapeClass.SHAPE_RECTANGLE or (shape.is_shrinking() and sid != ArenaShapeClass.SHAPE_CURSE_RUN) or sid == ArenaShapeClass.SHAPE_HAZARD or sid == ArenaShapeClass.SHAPE_ROAMING_HAZARD or sid == ArenaShapeClass.SHAPE_METEOR or sid == ArenaShapeClass.SHAPE_SAFE_ZONE:
		return .get_spawn_pos_in_area(base_pos, area, spawn_dist_from_edges, spawn_edge_of_map)

	# Curse Run: ALL enemies spawn from the right edge
	if sid == ArenaShapeClass.SHAPE_CURSE_RUN:
		return shape.get_rand_edge_pos(float(Utils.EDGE_MAP_DIST))

	var d = spawn_dist_from_edges

	# Maze/MultiRoom: always use get_rand_pos for walkable tile centers.
	# The get_rand_pos_in_area path can place entities in or overlapping wall
	# tiles because clamp_position is a no-op for these shapes and contains_point
	# only checks the exact tile (no sprite clearance from adjacent walls).
	if sid == ArenaShapeClass.SHAPE_MAZE or sid == ArenaShapeClass.SHAPE_MULTIROOM:
		if spawn_edge_of_map:
			return shape.get_rand_edge_pos(float(Utils.EDGE_MAP_DIST))
		return shape.get_rand_pos(float(d))

	if spawn_edge_of_map:
		return shape.get_rand_edge_pos(float(Utils.EDGE_MAP_DIST))
	elif area == -1:
		return shape.get_rand_pos(float(d))
	else:
		var pos = ZoneService.get_rand_pos_in_area(base_pos, area)
		if not shape.contains_point(pos):
			# Position is in a wall — find a walkable spot instead
			pos = shape.get_rand_pos(float(d))
		return pos
