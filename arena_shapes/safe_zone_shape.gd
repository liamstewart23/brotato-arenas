# safe_zone_shape.gd — The whole arena is lethal except one roaming safe circle.
#
# Inverts the hazard idea: instead of dodging danger spots, the player must STAY
# inside a moving safe circle or take escalating damage (the same damage model as
# Closing Storm's "outside the boundary" ticks). The arena itself is a normal
# rectangle — enemies roam freely; only the player's positioning is constrained.
#
# The safe circle starts centered on the player spawn (so nobody starts taking
# damage) and then drifts, bouncing off the bounds. my_tile_map.gd draws an
# inverted fog that darkens everything outside the circle and applies the damage.

extends "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd"

var safe_center := Vector2.ZERO
var safe_radius := 0.0
var _vel := Vector2.ZERO
var _prev_ratio := 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func get_shape_id() -> int:
	return SHAPE_SAFE_ZONE


func setup(p_width_px: float, p_height_px: float) -> void:
	.setup(p_width_px, p_height_px)
	_rng.randomize()
	safe_radius = min(half_width, half_height) * 0.42  # roomy enough to fight in
	safe_center = center                               # start safe at the spawn
	_prev_ratio = 0.0

	var angle = _rng.randf_range(0.0, TAU)
	var diag = Vector2(width_px, height_px).length()
	_vel = Vector2(cos(angle), sin(angle)) * (diag * 1.1)  # gentle roam, px per wave


# Full rectangle is walkable — the safe zone is a damage rule, not a wall.
func contains_point(_point: Vector2) -> bool:
	return true


func clamp_position(point: Vector2) -> Vector2:
	return point


func get_rand_pos(edge: float) -> Vector2:
	return Vector2(rand_range(edge, width_px - edge), rand_range(edge, height_px - edge))


func get_rand_edge_pos(dist: float) -> Vector2:
	match randi() % 4:
		0: return Vector2(rand_range(0, width_px), dist)
		1: return Vector2(width_px - dist, rand_range(0, height_px))
		2: return Vector2(rand_range(0, width_px), height_px - dist)
		_: return Vector2(dist, rand_range(0, height_px))


func is_in_safe(pos: Vector2) -> bool:
	return pos.distance_to(safe_center) <= safe_radius


# Drift the safe circle, bouncing off the bounds so it stays fully on-screen.
func update(time_ratio: float) -> void:
	var d = time_ratio - _prev_ratio
	_prev_ratio = time_ratio
	if d <= 0.0:
		return

	var pos = safe_center + _vel * d
	var r = safe_radius
	if pos.x < r:
		pos.x = r
		_vel.x = abs(_vel.x)
	elif pos.x > width_px - r:
		pos.x = width_px - r
		_vel.x = -abs(_vel.x)
	if pos.y < r:
		pos.y = r
		_vel.y = abs(_vel.y)
	elif pos.y > height_px - r:
		pos.y = height_px - r
		_vel.y = -abs(_vel.y)
	safe_center = pos
