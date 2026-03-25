# arena_shape.gd — Abstract base class for all arena shapes.
#
# Every arena shape subclass overrides these methods to define its boundary,
# containment, spawning, collision, tile fill, and visual outline. Game systems
# (tile map, collision walls, entity spawner, etc.) delegate to the active shape
# instance so they stay shape-agnostic.
#
# Shape ID constants (0-7) map to the OptionButton index in the run options UI
# and are stored in ProgressData for save/resume persistence.
#
# The static create_shape() factory at the bottom instantiates the correct
# subclass from a shape ID — all other code uses this to avoid hardcoding paths.

extends Reference

# Shape ID constants — indices match the UI dropdown and config schema
const SHAPE_RECTANGLE = 0
const SHAPE_CIRCLE = 1
const SHAPE_HEXAGON = 2
const SHAPE_CURSE_RUN = 3
const SHAPE_SHRINKING = 4
const SHAPE_MAZE = 5
const SHAPE_MULTIROOM = 6
const SHAPE_HAZARD = 7
const SHAPE_RANDOM = 8

# Arena dimensions in pixels, set by setup()
var center := Vector2.ZERO
var half_width := 0.0
var half_height := 0.0
var width_px := 0.0
var height_px := 0.0


# Initialize the shape from the zone's pixel dimensions.
# Called once per wave after ZoneService.set_current_zone() resolves the zone size.
func setup(p_width_px: float, p_height_px: float) -> void:
	width_px = p_width_px
	height_px = p_height_px
	center = Vector2(p_width_px / 2.0, p_height_px / 2.0)
	half_width = p_width_px / 2.0
	half_height = p_height_px / 2.0


# Return this shape's constant ID (SHAPE_RECTANGLE, SHAPE_CIRCLE, etc.).
# Used by extensions to branch on shape type without isinstance checks.
func get_shape_id() -> int:
	return SHAPE_RECTANGLE


# Is the given world-space point inside the playable arena boundary?
# Base returns true (rectangle fills the whole zone).
func contains_point(point: Vector2) -> bool:
	return true


# Return the nearest point inside the arena boundary.
# Used by zone_service to keep spawned positions in-bounds.
func clamp_position(point: Vector2) -> Vector2:
	return point


# Return a random position inside the arena, at least `edge` pixels from the boundary.
# Used for item drops, consumable spawns, and fallback enemy positioning.
func get_rand_pos(edge: float) -> Vector2:
	return center


# Return a random position on or near the arena edge, `dist` pixels inward.
# Used for edge-of-map enemy spawns.
func get_rand_edge_pos(dist: float) -> Vector2:
	return center


# Return vertices of the collision polygon used to build physics walls.
# `num_segments` controls resolution for curved shapes (circle uses 32).
# Polygon is assumed clockwise in screen coords (Y-down).
func get_collision_points(num_segments: int = 32) -> PoolVector2Array:
	return PoolVector2Array()


# Should this tile (in tile coords) be filled with a floor sprite?
# Maze/MultiRoom return false for wall tiles; circle/hex return false outside boundary.
func should_fill_tile(tile_x: int, tile_y: int, tile_size: int) -> bool:
	return true


# Return points for the visible arena outline (Line2D).
# Defaults to collision points; shapes can override for higher resolution
# (e.g., circle uses 48 segments for smoother visual).
func get_outline_points() -> PoolVector2Array:
	return get_collision_points()


# Per-frame update called during a wave. `time_ratio` is 0.0 at wave start, 1.0 at end.
# Only shrinking and curse_run shapes use this to animate their boundaries.
func update(_time_ratio: float) -> void:
	pass


# Does this shape shrink over time? Used to gate shrinking-specific logic
# (outline drawing, fog overlay, damage ticks) in main.gd and my_tile_map.gd.
func is_shrinking() -> bool:
	return false


# Return an array of internal wall dicts: {"pos": Vector2, "extents": Vector2}.
# Only maze and multiroom return walls; used by my_tile_map_limits for collision
# and my_tile_map for projectile-blocking Area2D.
func get_internal_walls() -> Array:
	return []


# Return an array of hazard zone dicts: {"center": Vector2, "radius": float}.
# Only hazard_shape populates this; used by my_tile_map for overlay rendering
# and damage application.
func get_hazard_zones() -> Array:
	return []


# Is the given position inside any hazard zone?
# Only hazard_shape overrides this with actual distance checks.
func is_in_hazard(_pos: Vector2) -> bool:
	return false


# Factory: instantiate the correct shape subclass from a shape ID constant.
# Returns a new Reference-based shape instance ready for setup().
static func create_shape(shape_id: int):
	var shape_script: GDScript
	var base_path = "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/"
	# Default (SHAPE_RECTANGLE / 0) returns null — all extensions already
	# check `shape == null` and fall through to base-game vanilla logic.
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
			return null
	return shape_script.new()
