extends Reference

const SHAPE_RECTANGLE = 0
const SHAPE_CIRCLE = 1
const SHAPE_HEXAGON = 2
const SHAPE_CURSE_RUN = 3
const SHAPE_SHRINKING = 4
const SHAPE_MAZE = 5
const SHAPE_MULTIROOM = 6
const SHAPE_HAZARD = 7

var center := Vector2.ZERO
var half_width := 0.0
var half_height := 0.0
var width_px := 0.0
var height_px := 0.0


func setup(p_width_px: float, p_height_px: float) -> void:
	width_px = p_width_px
	height_px = p_height_px
	center = Vector2(p_width_px / 2.0, p_height_px / 2.0)
	half_width = p_width_px / 2.0
	half_height = p_height_px / 2.0


func get_shape_id() -> int:
	return SHAPE_RECTANGLE


func contains_point(point: Vector2) -> bool:
	return true


func clamp_position(point: Vector2) -> Vector2:
	return point


func get_rand_pos(edge: float) -> Vector2:
	return center


func get_rand_edge_pos(dist: float) -> Vector2:
	return center


func get_collision_points(num_segments: int = 32) -> PoolVector2Array:
	return PoolVector2Array()


func should_fill_tile(tile_x: int, tile_y: int, tile_size: int) -> bool:
	return true


func get_outline_points() -> PoolVector2Array:
	return get_collision_points()


func update(_time_ratio: float) -> void:
	pass


func is_shrinking() -> bool:
	return false


func get_internal_walls() -> Array:
	return []


func get_hazard_zones() -> Array:
	return []


func is_in_hazard(_pos: Vector2) -> bool:
	return false


static func create_shape(shape_id: int):
	var shape_script: GDScript
	var base_path = "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/"
	match shape_id:
		SHAPE_CIRCLE:
			shape_script = load(base_path + "circle_shape.gd")
		SHAPE_HEXAGON:
			shape_script = load(base_path + "hexagon_shape.gd")
		SHAPE_CURSE_RUN:
			shape_script = load(base_path + "curse_run_shape.gd")
		SHAPE_SHRINKING:
			shape_script = load(base_path + "shrinking_shape.gd")
		SHAPE_MAZE:
			shape_script = load(base_path + "maze_shape.gd")
		SHAPE_MULTIROOM:
			shape_script = load(base_path + "multiroom_shape.gd")
		SHAPE_HAZARD:
			shape_script = load(base_path + "hazard_shape.gd")
		_:
			shape_script = load(base_path + "rectangle_shape.gd")
	return shape_script.new()
