extends "res://global/my_tile_map_limits.gd"

const ArenaShapeClass = preload("res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd")


func init(zone: ZoneData) -> void:
	var shape = ZoneService.arena_shape
	var sid = shape.get_shape_id() if shape != null else ArenaShapeClass.SHAPE_RECTANGLE

	# Rectangle, Shrinking, Hazard, Maze, MultiRoom use vanilla outer walls
	if shape == null or sid == ArenaShapeClass.SHAPE_RECTANGLE or shape.is_shrinking() or sid == ArenaShapeClass.SHAPE_HAZARD or sid == ArenaShapeClass.SHAPE_MAZE or sid == ArenaShapeClass.SHAPE_MULTIROOM or sid == ArenaShapeClass.SHAPE_CURSE_RUN:
		.init(zone)
		# Maze and MultiRoom also need internal walls
		if shape != null and (sid == ArenaShapeClass.SHAPE_MAZE or sid == ArenaShapeClass.SHAPE_MULTIROOM):
			_create_internal_walls(shape)
		return

	_create_polygon_walls()


func _create_polygon_walls() -> void:
	var shape = ZoneService.arena_shape
	var points = shape.get_collision_points()
	var num_points = points.size()
	var wall_thickness = 4.0 * Utils.TILE_SIZE

	for i in num_points:
		var a = points[i]
		var b = points[(i + 1) % num_points]
		var edge = b - a
		var edge_length = edge.length()
		var edge_angle = edge.angle()
		var edge_midpoint = (a + b) / 2.0

		# Outward normal for clockwise polygon in screen coords (Y down)
		var outward_normal = Vector2(edge.y, -edge.x).normalized()
		var wall_center = edge_midpoint + outward_normal * (wall_thickness / 2.0)

		var wall_node = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		# Slight extra length to ensure corners overlap between adjacent walls
		rect.extents = Vector2(edge_length / 2.0 + wall_thickness / 4.0, wall_thickness / 2.0)
		wall_node.shape = rect
		wall_node.rotation = edge_angle
		self.add_child(wall_node)
		wall_node.global_position = wall_center


func _create_internal_walls(shape) -> void:
	var walls = shape.get_internal_walls()
	for w in walls:
		var wall_node = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.extents = w.extents
		wall_node.shape = rect
		wall_node.position = w.pos
		self.add_child(wall_node)
