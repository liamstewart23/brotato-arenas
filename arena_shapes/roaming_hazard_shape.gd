# roaming_hazard_shape.gd — Hazard clouds that drift around the arena.
#
# Same curse clouds as hazard_shape, but each zone has a velocity and wanders,
# bouncing off the arena bounds. Reuses the shared Hazard render/damage path in
# my_tile_map.gd (overlays, ring morph, escalating damage); the only additions
# are per-zone velocities and an update() that moves the centers. my_tile_map.gd
# calls update() each frame and repositions the fire emitters to follow.
#
# Velocities are expressed as pixels-per-full-wave and advanced by the change in
# the wave's time_ratio, so travel speed is independent of frame rate and wave
# length.

extends "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/hazard_shape.gd"

var _velocities: Array = []     # parallel to _hazard_zones; Vector2 px-per-wave
var _prev_ratio: float = 0.0


func get_shape_id() -> int:
	return SHAPE_ROAMING_HAZARD


func setup(p_width_px: float, p_height_px: float) -> void:
	.setup(p_width_px, p_height_px)  # hazard_shape generates the zones
	_prev_ratio = 0.0
	_velocities.clear()

	# Each cloud crosses the arena a couple of times over a wave, in a random dir.
	var diag = Vector2(width_px, height_px).length()
	for _i in _hazard_zones.size():
		var angle = _rng.randf_range(0.0, TAU)
		var speed = diag * _rng.randf_range(1.5, 2.8)  # px per full wave
		_velocities.append(Vector2(cos(angle), sin(angle)) * speed)


# Advance each cloud by velocity * (change in wave progress), bouncing off the
# arena bounds so clouds stay fully on-screen.
func update(time_ratio: float) -> void:
	var d = time_ratio - _prev_ratio
	_prev_ratio = time_ratio
	if d <= 0.0:
		return

	for i in _hazard_zones.size():
		var zone = _hazard_zones[i]
		var vel = _velocities[i]
		var pos = zone.center + vel * d
		var r = zone.radius

		# Bounce off each bound, keeping the whole cloud inside.
		if pos.x < r:
			pos.x = r
			vel.x = abs(vel.x)
		elif pos.x > width_px - r:
			pos.x = width_px - r
			vel.x = -abs(vel.x)
		if pos.y < r:
			pos.y = r
			vel.y = abs(vel.y)
		elif pos.y > height_px - r:
			pos.y = height_px - r
			vel.y = -abs(vel.y)

		zone.center = pos
		_velocities[i] = vel
