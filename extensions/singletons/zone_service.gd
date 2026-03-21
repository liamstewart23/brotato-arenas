extends "res://singletons/zone_service.gd"

const ArenaShapeClass = preload("res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd")

var arena_shape_id = 0
var arena_shape = null
var arena_shrinking_min_scale = 0.4
var arena_shrinking_speed = 1.0


func set_current_zone(p_current_zone: ZoneData) -> void:
	if ProgressData.settings.has("arena_shape_selected"):
		var shape_id = int(clamp(ProgressData.settings.arena_shape_selected, 0, 7))
		if shape_id == ArenaShapeClass.SHAPE_HEXAGON:
			var boost = 1.3
			p_current_zone.width = max(p_current_zone.width, int(p_current_zone.width * boost))
			p_current_zone.height = max(p_current_zone.height, int(p_current_zone.height * boost))
	.set_current_zone(p_current_zone)
	_setup_arena_shape()


func _setup_arena_shape() -> void:
	# Restore selection from ProgressData (persists across save/resume)
	if ProgressData.settings.has("arena_shape_selected"):
		arena_shape_id = int(clamp(ProgressData.settings.arena_shape_selected, 0, 7))

	var shape = ArenaShapeClass.create_shape(arena_shape_id)
	shape.setup(current_zone_max_position.x, current_zone_max_position.y)

	if shape.is_shrinking():
		shape.min_scale = arena_shrinking_min_scale
		shape.shrink_speed = arena_shrinking_speed

	arena_shape = shape


func get_rand_pos(edge: int = Utils.EDGE_MAP_DIST) -> Vector2:
	if arena_shape == null or arena_shape.get_shape_id() == ArenaShapeClass.SHAPE_RECTANGLE:
		return .get_rand_pos(edge)

	edge = _limit_dist_to_edge(edge)
	return arena_shape.get_rand_pos(float(edge))


func get_rand_pos_in_area(base_pos: Vector2, area: float, edge: int = Utils.EDGE_MAP_DIST) -> Vector2:
	var pos = .get_rand_pos_in_area(base_pos, area, edge)

	if arena_shape != null and arena_shape.get_shape_id() != ArenaShapeClass.SHAPE_RECTANGLE:
		if not arena_shape.contains_point(pos):
			pos = arena_shape.clamp_position(pos)

	return pos
