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

var arena_shape_id = 0                # currently selected shape (0-8, 8 = random)
var arena_shape = null                # active ArenaShape instance (null = vanilla rectangle)
var arena_shrinking_min_scale = 0.4   # configurable via manifest
var arena_shrinking_speed = 1.0       # configurable via manifest
var arena_meteor_interval = 1.6       # configurable via manifest — seconds between meteors
var arena_meteor_max_active = 3       # configurable via manifest — max telegraphing at once
var arena_random_pool = [0, 1, 2, 3, 4, 5, 6, 7]  # shape ids eligible when Random is selected
var arena_random_per_run = true       # true = roll once per run; false = re-roll each wave
var _resolved_shape_id = 0            # resolved concrete shape for this wave


# Override set_current_zone to inject shape setup after the parent resolves
# zone dimensions. Hexagon gets a 30% size boost because a hexagon inscribed
# in a rectangle only covers ~87% of the area — the boost compensates.
func set_current_zone(p_current_zone: ZoneData) -> void:
	# Resolve shape ID for this wave (handles random pool filtering + reroll mode)
	_resolved_shape_id = _resolve_shape_id()

	if _resolved_shape_id == ArenaShapeClass.SHAPE_HEXAGON:
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
		arena_shape_id = int(clamp(ProgressData.settings.arena_shape_selected, 0, ArenaShapeClass.SHAPE_RANDOM))

	# Use the resolved ID (handles random → concrete shape per wave)
	var shape = ArenaShapeClass.create_shape(_resolved_shape_id)

	if shape != null:
		# Apply config BEFORE setup() — meteor_shape.setup() sizes its slot pool
		# from meteor_max_active, so these must be set first.
		if shape.is_shrinking():
			shape.min_scale = arena_shrinking_min_scale
			shape.shrink_speed = arena_shrinking_speed
		if _resolved_shape_id == ArenaShapeClass.SHAPE_METEOR:
			shape.meteor_interval = arena_meteor_interval
			shape.meteor_max_active = arena_meteor_max_active

		shape.setup(current_zone_max_position.x, current_zone_max_position.y)

	arena_shape = shape


# Resolve the concrete shape id (0-7) to use for this wave.
#   - A non-random selection returns itself directly.
#   - Random + per-wave  → fresh pick from the enabled pool each wave.
#   - Random + per-run   → pick once at run start, cache in ProgressData so it
#                          stays fixed across waves and survives save/resume.
func _resolve_shape_id() -> int:
	var selected = 0
	if ProgressData.settings.has("arena_shape_selected"):
		selected = int(clamp(ProgressData.settings.arena_shape_selected, 0, ArenaShapeClass.SHAPE_RANDOM))

	if selected != ArenaShapeClass.SHAPE_RANDOM:
		return selected

	# --- Random selected ---
	var pool = _get_random_pool()  # always non-empty

	var per_run = arena_random_per_run
	if ProgressData.settings.has("arena_random_per_run"):
		per_run = bool(ProgressData.settings.arena_random_per_run)

	if not per_run:
		# Per-wave: fresh pick every wave, filtered to the enabled pool.
		return pool[randi() % pool.size()]

	# Per-run: roll once and cache. Re-roll at run start (wave 1) or when no
	# valid cache exists; otherwise reuse the cached shape.
	var current_wave = 1
	if RunData and RunData.current_wave != null:
		current_wave = int(RunData.current_wave)

	var has_cache = ProgressData.settings.has("arena_random_run_resolved") \
		and int(ProgressData.settings.arena_random_run_resolved) >= 0
	var cached = -1
	if has_cache:
		cached = int(ProgressData.settings.arena_random_run_resolved)

	# Reuse a still-valid cache on later waves.
	if has_cache and current_wave > 1 and pool.has(cached):
		return cached

	var rolled = pool[randi() % pool.size()]
	ProgressData.settings["arena_random_run_resolved"] = rolled
	return rolled


# Return the random pool from ProgressData, filtered to valid concrete ids.
# Falls back to the default pool when missing (old saves) or empty (user
# unchecked everything) so Random never gets stuck with nothing to pick.
func _get_random_pool() -> Array:
	var pool = []
	if ProgressData.settings.has("arena_random_pool"):
		for v in ProgressData.settings.arena_random_pool:
			var id = int(v)
			if id >= 0 and id < ArenaShapeClass.SHAPE_CONCRETE_COUNT and not pool.has(id):
				pool.append(id)
	if pool.empty():
		pool = ArenaShapeClass.RANDOM_POOL_DEFAULT.duplicate()
	return pool


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
