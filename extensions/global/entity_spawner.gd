extends "res://global/entity_spawner.gd"

const ArenaShapeClass = preload("res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd")


func get_spawn_pos_in_area(base_pos: Vector2, area: int, spawn_dist_from_edges: int = 0, spawn_edge_of_map: bool = false) -> Vector2:
	var shape = ZoneService.arena_shape

	var sid = shape.get_shape_id() if shape != null else ArenaShapeClass.SHAPE_RECTANGLE
	if shape == null or sid == ArenaShapeClass.SHAPE_RECTANGLE or (shape.is_shrinking() and sid != ArenaShapeClass.SHAPE_CURSE_RUN) or sid == ArenaShapeClass.SHAPE_HAZARD:
		return .get_spawn_pos_in_area(base_pos, area, spawn_dist_from_edges, spawn_edge_of_map)

	# Curse Run: ALL enemies spawn from the right edge
	if sid == ArenaShapeClass.SHAPE_CURSE_RUN:
		return shape.get_rand_edge_pos(float(Utils.EDGE_MAP_DIST))

	var d = spawn_dist_from_edges

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
