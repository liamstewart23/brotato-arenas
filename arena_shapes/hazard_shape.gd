extends "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd"

var _hazard_zones: Array = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func get_shape_id() -> int:
	return SHAPE_HAZARD


func setup(p_width_px: float, p_height_px: float) -> void:
	.setup(p_width_px, p_height_px)
	_generate_hazards()


func _generate_hazards() -> void:
	_hazard_zones.clear()
	_rng.randomize()  # unique hazard layout every run

	# Scale hazard count and size with the player's map_size stat
	var map_size_coef = 1.0 + (RunData.sum_all_player_effects(Keys.map_size_hash) / 100.0)
	map_size_coef = max(map_size_coef, 0.5)

	# Zone count scales with map area (coef squared) to keep density constant
	var area_coef = map_size_coef * map_size_coef
	var num_zones = _rng.randi_range(
		int(round(6 * area_coef)),
		int(round(10 * area_coef))
	)

	# Radius scales linearly with map size
	var min_radius = 50.0 * map_size_coef
	var max_radius = 150.0 * map_size_coef

	# Safety zone and margin scale linearly with map dimensions
	var margin = 100.0 * map_size_coef
	margin = min(margin, min(width_px, height_px) * 0.4)
	var safe_center_radius = 200.0 * map_size_coef

	for _i in num_zones:
		var attempts = 0
		while attempts < 20:
			var cx = _rng.randf_range(margin, width_px - margin)
			var cy = _rng.randf_range(margin, height_px - margin)
			var pos = Vector2(cx, cy)
			var radius = _rng.randf_range(min_radius, max_radius)

			# Don't let the zone overlap the player spawn (center of map)
			if pos.distance_to(center) < safe_center_radius + radius:
				attempts += 1
				continue

			_hazard_zones.append({"center": pos, "radius": radius})
			break

		attempts += 1


func contains_point(point: Vector2) -> bool:
	return true


func clamp_position(point: Vector2) -> Vector2:
	return point


func get_rand_pos(edge: float) -> Vector2:
	return Vector2(
		rand_range(edge, width_px - edge),
		rand_range(edge, height_px - edge)
	)


func get_rand_edge_pos(dist: float) -> Vector2:
	var side = randi() % 4
	match side:
		0: return Vector2(rand_range(0, width_px), dist)
		1: return Vector2(width_px - dist, rand_range(0, height_px))
		2: return Vector2(rand_range(0, width_px), height_px - dist)
		_: return Vector2(dist, rand_range(0, height_px))


func should_fill_tile(_tile_x: int, _tile_y: int, _tile_size: int) -> bool:
	return true


func get_hazard_zones() -> Array:
	return _hazard_zones


func is_in_hazard(pos: Vector2) -> bool:
	for zone in _hazard_zones:
		if pos.distance_to(zone.center) <= zone.radius:
			return true
	return false


func get_hazard_zones_containing(pos: Vector2) -> Array:
	var result = []
	for i in _hazard_zones.size():
		if pos.distance_to(_hazard_zones[i].center) <= _hazard_zones[i].radius:
			result.append(i)
	return result
