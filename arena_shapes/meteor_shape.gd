# meteor_shape.gd — Meteors rain down on telegraphed spots, hurting everything.
#
# The arena is a plain rectangle. Meteors are managed as a FIXED array of slots
# (stable indices, so my_tile_map.gd can keep a 1:1 overlay pool). Each slot
# cycles: TELEGRAPH (a warning marker appears on the target spot, no damage) ->
# IMPACT (the hit lands, damage dealt ONCE to everything in radius) -> FADE ->
# inactive, then is reused for the next meteor.
#
# Timing is driven by real seconds (my_tile_map calls tick(delta) with the
# physics delta), not the wave's time_ratio, so cadence is exact. meteor_interval
# and meteor_max_active come from the manifest config via zone_service.gd.
#
# Damage application (players + enemies + bosses) lives in my_tile_map.gd; this
# shape just reports which meteors entered IMPACT this frame.

extends "res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd"

const STATE_INACTIVE := 0
const STATE_TELEGRAPH := 1
const STATE_IMPACT := 2
const STATE_FADE := 3

const TELEGRAPH_MIN := 0.85   # small meteors warn briefly
const TELEGRAPH_MAX := 1.5    # large meteors warn longer (bigger threat)
const IMPACT_TIME := 0.18     # bright impact flash (seconds)
const FADE_TIME := 0.5        # scorch fade-out (seconds)
const HEADROOM := 5           # extra slots so impacting/fading meteors don't block spawns

# Set by zone_service.gd from the manifest config
var meteor_interval := 1.4
var meteor_max_active := 3

# Meteors come in three sizes; base radii (before map_size scaling).
const SMALL_RADIUS := 55.0
const MEDIUM_RADIUS := 105.0
const LARGE_RADIUS := 165.0
# How much the spawn interval tightens by the end of the wave (storm builds up).
const END_INTERVAL_FACTOR := 0.5

var _meteors: Array = []      # fixed-size slots of dicts
var _slot_count := 0
var _spawn_accum := 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _size_coef := 1.0
var _margin := 80.0


func get_shape_id() -> int:
	return SHAPE_METEOR


func setup(p_width_px: float, p_height_px: float) -> void:
	.setup(p_width_px, p_height_px)
	_rng.randomize()

	_size_coef = max(1.0 + (RunData.sum_all_player_effects(Keys.map_size_hash) / 100.0), 0.5)
	_margin = min(80.0 * _size_coef, min(width_px, height_px) * 0.3)

	_slot_count = int(meteor_max_active) + HEADROOM
	_meteors.clear()
	for _i in _slot_count:
		_meteors.append({
			"active": false,
			"center": Vector2.ZERO,
			"radius": 0.0,
			"state": STATE_INACTIVE,
			"timer": 0.0,
			"progress": 0.0,
			"telegraph": TELEGRAPH_MIN,
		})
	_spawn_accum = meteor_interval  # drop the first meteor almost immediately


# Rectangle geometry — no boundary changes.
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


# --- Meteor lifecycle (called by my_tile_map.gd) ---

func get_slot_count() -> int:
	return _slot_count


func get_meteors() -> Array:
	return _meteors


# Advance all meteors by `delta` seconds and spawn new ones on cadence.
# `time_ratio` (0 at wave start, 1 at end) tightens the spawn interval so the
# storm intensifies toward the end of the round.
# Returns an array of {"center", "radius"} for meteors that JUST hit this frame
# (so the caller deals impact damage exactly once).
func tick(delta: float, time_ratio: float = 0.0) -> Array:
	var impacts = []

	# Effective interval shrinks toward the end of the wave (more frequent)
	var interval = meteor_interval * lerp(1.0, END_INTERVAL_FACTOR, clamp(time_ratio, 0.0, 1.0))

	# Spawn on cadence, capped by how many are currently telegraphing
	_spawn_accum += delta
	if _spawn_accum >= interval:
		if _count_telegraphing() < int(meteor_max_active) and _spawn_meteor():
			_spawn_accum = 0.0
		else:
			_spawn_accum = interval  # try again next frame

	for m in _meteors:
		if not m.active:
			continue
		m.timer -= delta
		match m.state:
			STATE_TELEGRAPH:
				m.progress = clamp(1.0 - m.timer / m.telegraph, 0.0, 1.0)
				if m.timer <= 0.0:
					m.state = STATE_IMPACT
					m.timer = IMPACT_TIME
					m.progress = 0.0
					impacts.append({"center": m.center, "radius": m.radius})
			STATE_IMPACT:
				if m.timer <= 0.0:
					m.state = STATE_FADE
					m.timer = FADE_TIME
			STATE_FADE:
				m.progress = clamp(m.timer / FADE_TIME, 0.0, 1.0)
				if m.timer <= 0.0:
					m.active = false
					m.state = STATE_INACTIVE

	return impacts


func _count_telegraphing() -> int:
	var c = 0
	for m in _meteors:
		if m.active and m.state == STATE_TELEGRAPH:
			c += 1
	return c


func _spawn_meteor() -> bool:
	for m in _meteors:
		if not m.active:
			m.active = true
			m.state = STATE_TELEGRAPH
			m.radius = _roll_radius()
			# Bigger meteors warn longer (more lead time for a bigger threat)
			var norm = clamp((m.radius / _size_coef - SMALL_RADIUS) / (LARGE_RADIUS - SMALL_RADIUS), 0.0, 1.0)
			m.telegraph = lerp(TELEGRAPH_MIN, TELEGRAPH_MAX, norm)
			m.timer = m.telegraph
			m.progress = 0.0
			m.center = Vector2(
				_rng.randf_range(_margin, width_px - _margin),
				_rng.randf_range(_margin, height_px - _margin)
			)
			return true
	return false


# Pick a size tier: ~40% small, ~40% medium, ~20% large, with a little jitter.
func _roll_radius() -> float:
	var roll = _rng.randf()
	var base
	if roll < 0.4:
		base = SMALL_RADIUS
	elif roll < 0.8:
		base = MEDIUM_RADIUS
	else:
		base = LARGE_RADIUS
	return base * _size_coef * _rng.randf_range(0.9, 1.1)
