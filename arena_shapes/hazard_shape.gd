# hazard_shape.gd — Random curse cloud zones scattered on a standard rectangular arena.
#
# The arena itself is a normal rectangle, but 6-10 circular "hazard zones" are
# randomly placed across it. Each zone has a center and radius. Players inside
# a hazard zone take escalating damage (handled by my_tile_map.gd).
#
# Zone count and radius scale with the player's map_size stat:
#   - Count scales with area (map_size_coef^2) to keep density constant
#   - Radius scales linearly with map_size_coef
#
# A safe zone around the map center prevents hazards from overlapping spawn.
# Zone placement uses rejection sampling (up to 20 attempts per zone).

extends "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd"

var _hazard_zones: Array = []  # Array of {"center": Vector2, "radius": float}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func get_shape_id() -> int:
	return SHAPE_HAZARD


func setup(p_width_px: float, p_height_px: float) -> void:
	.setup(p_width_px, p_height_px)
	_generate_hazards()


# Generate random hazard zones with map_size-aware scaling.
func _generate_hazards() -> void:
	_hazard_zones.clear()
	_rng.randomize()  # unique hazard layout every run

	# Calculate the map_size coefficient from player stats.
	# map_size stat is a percentage (e.g., +50 means 1.5x), floored at 0.5x.
	var map_size_coef = 1.0 + (RunData.sum_all_player_effects(Keys.map_size_hash) / 100.0)
	map_size_coef = max(map_size_coef, 0.5)

	# Zone count scales with map AREA (coef^2) so larger maps don't feel empty
	var area_coef = map_size_coef * map_size_coef
	var num_zones = _rng.randi_range(
		int(round(6 * area_coef)),
		int(round(10 * area_coef))
	)

	# Individual zone radius scales linearly with map size
	var min_radius = 50.0 * map_size_coef
	var max_radius = 150.0 * map_size_coef

	# Keep zones away from arena edges and player spawn point
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

			# Reject zones that would overlap the player spawn (center of map)
			if pos.distance_to(center) < safe_center_radius + radius:
				attempts += 1
				continue

			_hazard_zones.append({"center": pos, "radius": radius})
			break

		attempts += 1


# Standard rectangular containment — hazard zones don't change the walkable area
func contains_point(point: Vector2) -> bool:
	return true


func clamp_position(point: Vector2) -> Vector2:
	return point


# Random position within the full rectangle with edge margin
func get_rand_pos(edge: float) -> Vector2:
	return Vector2(
		rand_range(edge, width_px - edge),
		rand_range(edge, height_px - edge)
	)


# Random position on one of the 4 rectangle edges
func get_rand_edge_pos(dist: float) -> Vector2:
	var side = randi() % 4
	match side:
		0: return Vector2(rand_range(0, width_px), dist)
		1: return Vector2(width_px - dist, rand_range(0, height_px))
		2: return Vector2(rand_range(0, width_px), height_px - dist)
		_: return Vector2(dist, rand_range(0, height_px))


# All tiles are walkable — hazard zones are overlays, not physical obstacles
func should_fill_tile(_tile_x: int, _tile_y: int, _tile_size: int) -> bool:
	return true


# Expose zone data for my_tile_map.gd to create visual overlays and damage logic
func get_hazard_zones() -> Array:
	return _hazard_zones


# Check if a position is inside ANY hazard zone (simple distance check)
func is_in_hazard(pos: Vector2) -> bool:
	for zone in _hazard_zones:
		if pos.distance_to(zone.center) <= zone.radius:
			return true
	return false


# Return indices of all hazard zones containing the given position.
# Used by my_tile_map.gd for entry detection — when a player enters a NEW zone
# (index not in previous frame's list), they take instant damage.
func get_hazard_zones_containing(pos: Vector2) -> Array:
	var result = []
	for i in _hazard_zones.size():
		if pos.distance_to(_hazard_zones[i].center) <= _hazard_zones[i].radius:
			result.append(i)
	return result
