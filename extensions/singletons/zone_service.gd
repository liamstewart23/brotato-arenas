# zone_service.gd — Extends ZoneService for shape-aware positioning.
#
# Responsibilities:
#   1. Create and configure the arena shape instance when a zone is loaded
#   2. Apply size boosts for shapes that need more space (hexagon gets +30%)
#   3. Restore the selected shape from ProgressData (persists across save/resume)
#   4. Override get_rand_pos / get_rand_pos_in_area to delegate to the shape
#
# The arena_shape instance is stored here as a singleton-accessible property
# so all other extensions (tile map, spawner, etc.) can read it via
# ZoneService.arena_shape. When null, all extensions fall through to vanilla.

extends "res://singletons/zone_service.gd"

const ArenaShapeClass = preload("res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd")

var arena_shape_id = 0                # currently selected shape (0-7)
var arena_shape = null                # active ArenaShape instance (null = vanilla rectangle)
var arena_shrinking_min_scale = 0.4   # configurable via manifest
var arena_shrinking_speed = 1.0       # configurable via manifest


# Override set_current_zone to inject shape setup after the parent resolves
# zone dimensions. Hexagon gets a 30% size boost because a hexagon inscribed
# in a rectangle only covers ~87% of the area — the boost compensates.
func set_current_zone(p_current_zone: ZoneData) -> void:
	if ProgressData.settings.has("arena_shape_selected"):
		var shape_id = int(clamp(ProgressData.settings.arena_shape_selected, 0, 7))
		if shape_id == ArenaShapeClass.SHAPE_HEXAGON:
			var boost = 1.3
			p_current_zone.width = max(p_current_zone.width, int(p_current_zone.width * boost))
			p_current_zone.height = max(p_current_zone.height, int(p_current_zone.height * boost))
	.set_current_zone(p_current_zone)
	_setup_arena_shape()


# Instantiate the correct shape subclass and configure it with zone dimensions.
# Reads the persisted selection from ProgressData so the shape survives save/load.
# Returns null for rectangle (shape_id 0) — all extensions check for null.
func _setup_arena_shape() -> void:
	# Restore selection from ProgressData (persists across save/resume)
	if ProgressData.settings.has("arena_shape_selected"):
		arena_shape_id = int(clamp(ProgressData.settings.arena_shape_selected, 0, 7))

	var shape = ArenaShapeClass.create_shape(arena_shape_id)

	if shape != null:
		shape.setup(current_zone_max_position.x, current_zone_max_position.y)

		if shape.is_shrinking():
			shape.min_scale = arena_shrinking_min_scale
			shape.shrink_speed = arena_shrinking_speed

	arena_shape = shape


# Override: delegate random position generation to the arena shape.
# Falls through to vanilla when shape is null (rectangle).
func get_rand_pos(edge: int = Utils.EDGE_MAP_DIST) -> Vector2:
	if arena_shape == null or arena_shape.get_shape_id() == ArenaShapeClass.SHAPE_RECTANGLE:
		return .get_rand_pos(edge)

	edge = _limit_dist_to_edge(edge)
	return arena_shape.get_rand_pos(float(edge))


# Override: generate a position within an area, then clamp to shape boundary.
# This ensures items/entities spawned near shape edges don't end up outside.
func get_rand_pos_in_area(base_pos: Vector2, area: float, edge: int = Utils.EDGE_MAP_DIST) -> Vector2:
	var pos = .get_rand_pos_in_area(base_pos, area, edge)

	if arena_shape != null and arena_shape.get_shape_id() != ArenaShapeClass.SHAPE_RECTANGLE:
		if not arena_shape.contains_point(pos):
			pos = arena_shape.clamp_position(pos)

	return pos
