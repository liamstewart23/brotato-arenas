# my_tile_map.gd — Master extension for tile fill, visuals, damage, and navigation.
#
# This is the largest file in the mod. It handles everything that happens ON
# the tile map for all 8 arena shapes. Organized into these major systems:
#
#   INIT: Shape-specific tile fill and outline creation (init, _create_shape_outline)
#
#   SHRINKING (Closing Storm): Morphing fog overlay with layered sine-wave wobble,
#     600 fire emitters along the boundary, entry + tick damage with escalation.
#
#   CURSE RUN (Treadmill): Scrolling stripe shader, death wall with organic morph,
#     fog overlay left of wall, fire emitters, treadmill drift, instant-kill zone.
#
#   HAZARD ZONES: Animated circle overlays with sine-wave morphing, fire particle
#     emitters per zone, entry + tick damage with escalation.
#
#   MAZE / MULTIROOM: Internal wall visuals (colored rectangles), projectile-blocking
#     Area2D, AStar2D navigation graph for enemies and pets with anti-stuck detection.
#
# The _physics_process dispatches to the active system based on shape ID.

extends "res://global/my_tile_map.gd"

const ArenaShapeClass = preload("res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd")

var _arena_outline_node: Node2D = null

# --- SHRINKING (Closing Storm) visuals ---
var _shrinking_outline_node: Node2D = null
var _shrinking_line: Line2D = null
var _fire_emitters: Array = []
var _shrinking_fog: Polygon2D = null
const FIRE_SPACING := 8.0
const MAX_FIRE_EMITTERS := 600

# Shrinking morph animation (hazard-style smoky wobble)
var _shrinking_morph_time: float = 0.0
const SHRINKING_MORPH_SPEED := 1.0
const SHRINKING_MORPH_AMOUNT := 0.015
const SHRINKING_SEGS_PER_EDGE := 24
var _shrinking_morphed_poly: PoolVector2Array = PoolVector2Array()

# Shrinking damage (hazard-style escalation: 20% base, 30% if hit again within 2s)
var _shrinking_damage_timers: Dictionary = {}   # player instance_id -> float
var _shrinking_last_hit: Dictionary = {}        # player instance_id -> OS.get_ticks_msec()
var _shrinking_was_outside: Dictionary = {}     # player instance_id -> bool (entry detection)
const SHRINKING_DAMAGE_INTERVAL := 0.5
const SHRINKING_DAMAGE_BASE := 0.20
const SHRINKING_DAMAGE_ESCALATED := 0.30
const SHRINKING_ESCALATION_WINDOW := 2.0

# --- CURSE RUN (Treadmill) death wall visuals ---
var _scroller_wall_node: Node2D = null
var _scroller_wall_line: Line2D = null
var _scroller_wall_fog: Polygon2D = null
var _scroller_fire_emitters: Array = []
var _scroller_morph_time: float = 0.0
const SCROLLER_MAX_FIRE := 80
const SCROLLER_MORPH_SPEED := 1.2
const SCROLLER_MORPH_AMOUNT := 0.08
const SCROLLER_MORPH_SEGS := 32

# Wall line points for per-Y kill zone lookup
var _scroller_wall_points: PoolVector2Array = PoolVector2Array()
var _scroller_wall_y_start: float = 0.0
var _scroller_wall_y_end: float = 0.0

# Treadmill tile scroll shader
var _treadmill_shader_mat: ShaderMaterial = null
var _treadmill_scroll_offset: float = 0.0

# --- MAZE / MULTIROOM navigation (AStar2D pathfinding) ---
var _astar: AStar2D = null
var _astar_tile_w: int = 0
var _nav_shape = null
var _enemy_paths: Dictionary = {}
var _enemy_path_idx: Dictionary = {}
var _enemy_last_pos: Dictionary = {}
var _enemy_stuck_time: Dictionary = {}
var _enemy_unlock_time: Dictionary = {}
const STUCK_THRESHOLD := 0.15
const STUCK_MOVE_MIN := 5.0
const STUCK_UNLOCK_DURATION := 0.5
var _nav_update_timer: float = 0.0
const NAV_UPDATE_INTERVAL := 0.15
const NAV_WAYPOINT_REACH_DIST := 32.0

# Pet navigation (same pattern as enemies)
var _pet_paths: Dictionary = {}
var _pet_path_idx: Dictionary = {}
var _pet_last_pos: Dictionary = {}
var _pet_stuck_time: Dictionary = {}
var _pet_nav_locked: Dictionary = {}    # true when WE set _move_locked
var _pet_last_target: Dictionary = {}   # track target changes for immediate recalc
var _pet_nav_update_timer: float = 0.0


# Override init to handle shape-specific tile fill and visual setup.
# Routes to different strategies based on shape type:
#   - Rectangle/null, shrinking, hazard: vanilla tile fill + optional overlays
#   - Curse Run: vanilla tiles + death wall + treadmill shader
#   - Maze/MultiRoom: vanilla tiles + wall visuals + projectile colliders + AStar nav
#   - Circle/Hexagon: custom per-tile fill based on shape.should_fill_tile() + outline
func init(zone: ZoneData) -> void:
	var shape = ZoneService.arena_shape

	var sid = shape.get_shape_id() if shape != null else ArenaShapeClass.SHAPE_RECTANGLE

	# Shapes that use vanilla rectangular tiles
	if shape == null or sid == ArenaShapeClass.SHAPE_RECTANGLE or shape.is_shrinking() or sid == ArenaShapeClass.SHAPE_HAZARD:
		.init(zone)
		if shape != null and shape.is_shrinking():
			_create_shrinking_outline()
		if shape != null and sid == ArenaShapeClass.SHAPE_HAZARD:
			_create_hazard_overlays(shape)
		return

	# Curse Run: normal tiles + death wall on the left edge + treadmill lines
	if sid == ArenaShapeClass.SHAPE_CURSE_RUN:
		.init(zone)
		_create_scroller_wall(shape)
		_create_treadmill_scroll(shape)
		return

	# Maze and MultiRoom: vanilla init then draw solid walls + navigation
	if sid == ArenaShapeClass.SHAPE_MAZE or sid == ArenaShapeClass.SHAPE_MULTIROOM:
		.init(zone)
		_create_internal_wall_visuals(shape, zone)
		_create_outside_wall_fill(zone)
		_create_projectile_wall_colliders(shape)
		_nav_shape = shape
		_create_navigation(shape, zone)
		# Process BEFORE enemies so _move_locked direction is set first
		process_priority = -100
		return

	# Non-rectangle shapes (circle, hex)
	outline.rect_size = Vector2(Utils.TILE_SIZE * (zone.width + 2), Utils.TILE_SIZE * (zone.height + 2))
	outline.visible = false
	clear()

	for i in zone.width:
		for j in zone.height:
			if shape.should_fill_tile(i, j, Utils.TILE_SIZE):
				my_set_cell(i, j)

	_create_shape_outline(shape)


# Per-frame update dispatcher. Routes to the active shape's system:
#   - Shrinking: update scale -> morph outline -> update fog -> apply damage
#   - Curse Run: update drift -> scroll shader -> morph wall -> apply kill zone
#   - Hazard: animate ring overlays -> apply zone damage
#   - Maze/MultiRoom: steer enemies and pets along AStar paths
func _physics_process(delta: float) -> void:
	var shape = ZoneService.arena_shape
	if shape == null:
		return

	var sid = shape.get_shape_id()

	# Shrinking: update shape + visuals + damage
	if shape.is_shrinking():
		var timer = RunData.wave_timer
		if timer == null or timer.is_stopped() or timer.wait_time <= 0:
			return
		var elapsed = timer.wait_time - timer.time_left
		var time_ratio = elapsed / timer.wait_time
		shape.update(time_ratio)

		_update_shrinking_outline(shape)
		_update_shrinking_fog(shape)
		_apply_shrinking_damage(shape, delta)
		return

	# Curse Run: treadmill drift + death wall
	if sid == ArenaShapeClass.SHAPE_CURSE_RUN:
		var timer = RunData.wave_timer
		if timer == null or timer.is_stopped() or timer.wait_time <= 0:
			return
		var elapsed = timer.wait_time - timer.time_left
		var time_ratio = elapsed / timer.wait_time
		shape.update(time_ratio)
		_apply_treadmill_drift(shape, delta)
		_update_treadmill_scroll(shape, delta)
		_update_scroller_wall(shape)
		_apply_scroller_damage(shape)
		return

	# Hazard: animate rings and damage players in hazard zones
	if sid == ArenaShapeClass.SHAPE_HAZARD:
		_update_hazard_rings(shape, delta)
		_apply_hazard_damage(shape, delta)
		return

	# Maze/MultiRoom: steer enemies and pets along nav paths (only these shapes)
	if _astar != null and (sid == ArenaShapeClass.SHAPE_MAZE or sid == ArenaShapeClass.SHAPE_MULTIROOM):
		_steer_enemies_along_paths(delta, shape)
		_steer_pets_along_paths(delta, shape)


# Create a Line2D visual outline for circle/hexagon shapes.
# Uses the shape's outline points and the zone's outline color.
func _create_shape_outline(shape) -> void:
	var pts = shape.get_outline_points()
	if pts.size() < 3:
		return
	_arena_outline_node = Node2D.new()
	_arena_outline_node.z_index = 10
	add_child(_arena_outline_node)
	var line = Line2D.new()
	line.points = pts
	line.width = 2.0
	line.default_color = outline.modulate
	line.antialiased = true
	_arena_outline_node.add_child(line)


# Create a scrolling stripe shader on the tile map for Curse Run's treadmill effect.
# The shader draws faint diagonal stripes that scroll left at the drift speed,
# giving a visual cue that the ground is moving.
func _create_treadmill_scroll(shape) -> void:
	var shader = Shader.new()
	shader.code = """shader_type canvas_item;

uniform float scroll_offset = 0.0;
uniform float stripe_spacing = 96.0;
uniform float stripe_width = 3.0;
uniform float stripe_alpha = 0.12;

varying vec2 world_pos;

void vertex() {
	world_pos = VERTEX;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float wx = world_pos.x + scroll_offset;
	float pos_in_stripe = mod(wx, stripe_spacing);
	float stripe = smoothstep(0.0, 1.5, stripe_width - abs(pos_in_stripe));
	tex.rgb = mix(tex.rgb, vec3(1.0, 0.85, 1.0), stripe * stripe_alpha);
	COLOR = tex;
}
"""
	_treadmill_shader_mat = ShaderMaterial.new()
	_treadmill_shader_mat.shader = shader
	self.material = _treadmill_shader_mat


# Advance the treadmill shader's scroll offset by drift_speed * delta
func _update_treadmill_scroll(shape, delta: float) -> void:
	if _treadmill_shader_mat == null:
		return
	_treadmill_scroll_offset += shape.drift_speed * delta
	_treadmill_shader_mat.set_shader_param("scroll_offset", _treadmill_scroll_offset)


# Create the Curse Run death wall: a thick glowing line, fog overlay to its left,
# and fire emitters distributed along the wall. The wall morphs organically
# using layered sine waves (see _get_scroller_morph_offset).
func _create_scroller_wall(shape) -> void:
	_scroller_wall_node = Node2D.new()
	_scroller_wall_node.z_index = 15
	add_child(_scroller_wall_node)

	# Glowing wall line - thick and imposing
	_scroller_wall_line = Line2D.new()
	_scroller_wall_line.width = 8.0
	_scroller_wall_line.default_color = Color(0.8, 0.1, 1.0, 0.95)
	_scroller_wall_line.antialiased = true
	_scroller_wall_node.add_child(_scroller_wall_line)

	# Fog overlay to the LEFT of the wall (death zone)
	_scroller_wall_fog = Polygon2D.new()
	_scroller_wall_fog.color = Color(0.15, 0.0, 0.2, 0.6)
	_scroller_wall_fog.z_index = 5
	add_child(_scroller_wall_fog)

	# Fire emitters along the wall
	var fire_gradient = Gradient.new()
	fire_gradient.colors = PoolColorArray([
		Color(0.9, 0.2, 1.0, 0.95),
		Color(0.7, 0.1, 0.9, 0.85),
		Color(0.5, 0.0, 0.7, 0.6),
		Color(0.2, 0.0, 0.3, 0.0),
	])
	fire_gradient.offsets = PoolRealArray([0.0, 0.3, 0.7, 1.0])

	for _i in SCROLLER_MAX_FIRE:
		var emitter = CPUParticles2D.new()
		emitter.emitting = false
		emitter.amount = 5
		emitter.lifetime = 0.6
		emitter.speed_scale = 1.5
		emitter.randomness = 0.5
		emitter.direction = Vector2(1, 0)
		emitter.spread = 50.0
		emitter.gravity = Vector2(0, -80)
		emitter.initial_velocity = 70.0
		emitter.initial_velocity_random = 0.6
		emitter.scale_amount = 6.0
		emitter.scale_amount_random = 0.5
		emitter.color_ramp = fire_gradient
		emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		emitter.emission_sphere_radius = 10.0

		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		emitter.material = mat

		_scroller_wall_node.add_child(emitter)
		_scroller_fire_emitters.append(emitter)


# Layered sine waves producing organic smoky wobble along the death wall.
# Multiple frequencies and speeds create an unpredictable, alive-looking edge.
# Returns a value roughly in [-1.2, 1.2] that's scaled by SCROLLER_MORPH_AMOUNT.
func _get_scroller_morph_offset(t: float) -> float:
	var offset = sin(t * 3.0 + _scroller_morph_time * 2.3) * 0.4
	offset += sin(t * 5.0 - _scroller_morph_time * 1.7) * 0.3
	offset += sin(t * 7.0 + _scroller_morph_time * 3.1) * 0.2
	offset += sin(t * 2.0 + _scroller_morph_time * 0.9) * 0.3
	return offset


# Push all alive players leftward at the current drift speed.
# Also reduces player speed to 65% of max to make the treadmill feel challenging
# without being impossible. Uses max_stats to avoid compounding each frame.
func _apply_treadmill_drift(shape, delta: float) -> void:
	var main = Utils.get_scene_node()
	if main == null:
		return

	var players = main._players
	if players == null or players.empty():
		return

	for player in players:
		if not is_instance_valid(player) or player.dead:
			continue
		# Reduce speed to 65% of base value (use max_stats to avoid compounding)
		if player.max_stats.speed > 0:
			player.current_stats.speed = max(1, int(player.max_stats.speed * 0.65))
		player.global_position.x -= shape.drift_speed * delta


# Update the death wall's morphing position, fog polygon, and fire emitters.
# The wall is a vertical line at x=160 with organic wobble applied per-segment.
func _update_scroller_wall(shape) -> void:
	if _scroller_wall_node == null:
		return

	_scroller_morph_time += get_physics_process_delta_time() * SCROLLER_MORPH_SPEED

	var wall_x = 160.0
	var pad = 500.0
	var y_start = -pad
	var y_end = shape.height_px + pad
	var h = y_end - y_start
	var morph_max = h * SCROLLER_MORPH_AMOUNT

	# Build morphed vertical line along the wall with padding top and bottom
	var line_points = PoolVector2Array()
	for seg in SCROLLER_MORPH_SEGS + 1:
		var t = float(seg) / float(SCROLLER_MORPH_SEGS)
		var y = y_start + t * h
		var angle = t * TAU
		var wobble = _get_scroller_morph_offset(angle) * morph_max
		line_points.append(Vector2(wall_x + wobble, y))

	_scroller_wall_points = line_points
	_scroller_wall_y_start = y_start
	_scroller_wall_y_end = y_end
	_scroller_wall_line.points = line_points

	# Fog polygon covering everything left of the wall
	var fog_points = PoolVector2Array()
	fog_points.append(Vector2(wall_x - 3000, y_start))
	for pt in line_points:
		fog_points.append(pt)
	fog_points.append(Vector2(wall_x - 3000, y_end))
	_scroller_wall_fog.polygon = fog_points

	# Distribute fire emitters along the wall line
	var spacing = h / float(SCROLLER_MAX_FIRE)
	for i in _scroller_fire_emitters.size():
		if i < line_points.size():
			var idx = int(float(i) / float(SCROLLER_MAX_FIRE) * float(line_points.size() - 1))
			_scroller_fire_emitters[i].global_position = line_points[idx]
			_scroller_fire_emitters[i].emitting = true
		else:
			_scroller_fire_emitters[i].emitting = false


# Interpolate the death wall's X position at a given Y coordinate.
# Used to determine if a player is left of the wall (= instant death).
func _get_wall_x_at_y(py: float) -> float:
	var pts = _scroller_wall_points
	if pts.size() < 2:
		return 160.0
	# Clamp to wall range
	if py <= pts[0].y:
		return pts[0].x
	if py >= pts[pts.size() - 1].y:
		return pts[pts.size() - 1].x
	# Find the two points that bracket this Y and interpolate
	for i in range(pts.size() - 1):
		if py >= pts[i].y and py <= pts[i + 1].y:
			var t = (py - pts[i].y) / (pts[i + 1].y - pts[i].y)
			return lerp(pts[i].x, pts[i + 1].x, t)
	return 160.0


# Instant-kill any player whose X position is left of the morphing death wall.
# Displays "CONSUMED" floating text and triggers screen shake.
func _apply_scroller_damage(shape) -> void:
	var main = Utils.get_scene_node()
	if main == null:
		return

	var players = main._players
	if players == null or players.empty():
		return

	for player in players:
		if not is_instance_valid(player) or player.dead:
			continue
		# Find the wall x at the player's Y position by interpolating the wall line
		var wall_x_at_player = _get_wall_x_at_y(player.global_position.y)
		if player.global_position.x <= wall_x_at_player:
			player.current_stats.health = 0
			player.emit_signal("health_updated", player, 0, player.max_stats.health)

			if main._floating_text_manager:
				main._floating_text_manager.display(
					"CONSUMED",
					player.global_position + Vector2(0, -40),
					Color(0.8, 0.1, 1.0),
					null, 0.8, true, Vector2(0, -60), false
				)

			if main._screenshaker:
				main._screenshaker.shake(5.0, 0.2)

			player.die()


# Create the Closing Storm's visual layer: boundary line, inverted fog polygon
# (darkens everything OUTSIDE the shrunk area), and 600 fire emitters that
# track the morphing boundary. This is the tile_map version — main.gd has a
# simpler version with fewer emitters for the main scene layer.
func _create_shrinking_outline() -> void:
	_shrinking_outline_node = Node2D.new()
	_shrinking_outline_node.z_index = 15
	add_child(_shrinking_outline_node)

	_shrinking_line = Line2D.new()
	_shrinking_line.width = 3.0
	_shrinking_line.default_color = Color(0.6, 0.1, 0.9, 0.9)
	_shrinking_line.antialiased = true
	_shrinking_outline_node.add_child(_shrinking_line)

	# Fog overlay outside the shrinking boundary
	_shrinking_fog = Polygon2D.new()
	_shrinking_fog.color = Color(0.1, 0.0, 0.15, 0.35)
	_shrinking_fog.invert_enable = true
	_shrinking_fog.invert_border = 3000.0
	_shrinking_fog.z_index = 5
	add_child(_shrinking_fog)

	# Fire emitters (purple to match hazard style)
	var fire_gradient = Gradient.new()
	fire_gradient.colors = PoolColorArray([
		Color(0.8, 0.2, 1.0, 0.9),
		Color(0.6, 0.1, 0.9, 0.8),
		Color(0.4, 0.0, 0.7, 0.6),
		Color(0.2, 0.0, 0.3, 0.0),
	])
	fire_gradient.offsets = PoolRealArray([0.0, 0.3, 0.7, 1.0])

	for _i in MAX_FIRE_EMITTERS:
		var emitter = CPUParticles2D.new()
		emitter.emitting = false
		emitter.amount = 4
		emitter.lifetime = 0.5
		emitter.speed_scale = 1.5
		emitter.randomness = 0.5
		emitter.direction = Vector2(0, -1)
		emitter.spread = 30.0
		emitter.gravity = Vector2(0, -150)
		emitter.initial_velocity = 40.0
		emitter.initial_velocity_random = 0.5
		emitter.scale_amount = 3.0
		emitter.scale_amount_random = 0.5
		emitter.color_ramp = fire_gradient
		emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		emitter.emission_sphere_radius = 8.0

		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		emitter.material = mat

		_shrinking_outline_node.add_child(emitter)
		_fire_emitters.append(emitter)


# Layered sine waves for organic smoky wobble on the shrinking boundary.
# Same pattern as hazard zones — multiple frequencies create unpredictable motion.
func _get_morph_offset(angle: float) -> float:
	# Same layered sine waves as hazard shapes for organic smoky wobble
	var offset = sin(angle * 3.0 + _shrinking_morph_time * 2.3) * 0.4
	offset += sin(angle * 5.0 - _shrinking_morph_time * 1.7) * 0.3
	offset += sin(angle * 7.0 + _shrinking_morph_time * 3.1) * 0.2
	offset += sin(angle * 2.0 + _shrinking_morph_time * 0.9) * 0.3
	return offset


# Update the shrinking boundary's morphing outline and reposition fire emitters.
# Walks each of the 4 rectangle edges, subdivides into SHRINKING_SEGS_PER_EDGE
# segments, and displaces each segment point along the edge normal using the
# layered sine wave morph function. The result is a continuously animating,
# organic-looking boundary that flows around the full perimeter.
func _update_shrinking_outline(shape) -> void:
	if _shrinking_outline_node == null:
		return

	_shrinking_morph_time += get_physics_process_delta_time() * SHRINKING_MORPH_SPEED

	var pts = shape.get_collision_points()
	if pts.size() < 4:
		return

	# Build morphed outline with hazard-style smoky wobble along each edge
	var morphed_points = PoolVector2Array()
	for i in 4:
		var a = pts[i]
		var b = pts[(i + 1) % 4]
		var edge = b - a
		var edge_length = edge.length()
		if edge_length <= 0:
			continue
		var edge_dir = edge / edge_length
		# Normal pointing outward from the rectangle
		var normal = Vector2(-edge_dir.y, edge_dir.x)
		# Scale displacement with edge length like hazard scales with radius
		var max_displacement = edge_length * SHRINKING_MORPH_AMOUNT

		for seg in SHRINKING_SEGS_PER_EDGE:
			var t = float(seg) / float(SHRINKING_SEGS_PER_EDGE)
			var base_pos = a.linear_interpolate(b, t)
			# Use position along the full perimeter as the angle input
			# so the wave flows continuously around all 4 edges
			var perimeter_t = (float(i) + t) / 4.0
			var angle = perimeter_t * TAU
			var displacement = normal * _get_morph_offset(angle) * max_displacement
			morphed_points.append(base_pos + displacement)

	# Close the loop
	if morphed_points.size() > 0:
		morphed_points.append(morphed_points[0])

	_shrinking_morphed_poly = morphed_points
	_shrinking_line.points = morphed_points

	# Distribute fire emitters along the morphed line (not the straight edges)
	var total_morphed = morphed_points.size()
	if total_morphed < 2:
		return

	# Calculate total morphed perimeter length
	var morph_lengths = []
	var total_morph_length = 0.0
	for i in total_morphed - 1:
		var seg_len = morphed_points[i].distance_to(morphed_points[i + 1])
		morph_lengths.append(seg_len)
		total_morph_length += seg_len

	if total_morph_length <= 0:
		return

	# Place emitters evenly along the morphed perimeter
	var spacing = total_morph_length / float(MAX_FIRE_EMITTERS)
	var edge_positions = []
	var accumulated = 0.0
	var next_emit_dist = spacing * 0.5
	for i in morph_lengths.size():
		var seg_len = morph_lengths[i]
		while next_emit_dist <= accumulated + seg_len and edge_positions.size() < MAX_FIRE_EMITTERS:
			var local_t = (next_emit_dist - accumulated) / seg_len if seg_len > 0 else 0.0
			edge_positions.append(morphed_points[i].linear_interpolate(morphed_points[i + 1], local_t))
			next_emit_dist += spacing
		accumulated += seg_len

	for i in _fire_emitters.size():
		if i < edge_positions.size():
			_fire_emitters[i].global_position = edge_positions[i]
			_fire_emitters[i].emitting = true
		else:
			_fire_emitters[i].emitting = false


# Update the inverted fog polygon to match the morphed boundary.
# The fog uses invert_enable=true so it darkens everything OUTSIDE the polygon.
func _update_shrinking_fog(_shape) -> void:
	if _shrinking_fog == null:
		return
	# Fog morphs with the wavy line boundary
	if _shrinking_morphed_poly.size() > 2:
		_shrinking_fog.polygon = _shrinking_morphed_poly
	else:
		_shrinking_fog.polygon = _shape.get_collision_points()


# Ray-casting point-in-polygon test against the morphed wavy boundary.
# Uses the odd-even rule: cast a horizontal ray from point to +infinity,
# count how many polygon edges it crosses. Odd = inside, even = outside.
func _point_in_morphed_boundary(point: Vector2) -> bool:
	# Ray-casting point-in-polygon test against the morphed wavy boundary
	var poly = _shrinking_morphed_poly
	var n = poly.size()
	if n < 3:
		return true
	var inside = false
	var j = n - 1
	for i in n:
		var pi = poly[i]
		var pj = poly[j]
		if ((pi.y > point.y) != (pj.y > point.y)) and \
			(point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x):
			inside = not inside
		j = i
	return inside


# Deal percentage-based damage to a player outside the shrinking boundary.
# Uses damage escalation: 20% base, 30% if hit again within 2 seconds.
# This punishes lingering outside without being instantly lethal.
func _deal_shrinking_damage(player, main) -> void:
	var pid = player.get_instance_id()
	var now = OS.get_ticks_msec()
	var last_hit = _shrinking_last_hit.get(pid, 0)
	var elapsed_sec = (now - last_hit) / 1000.0

	var pct = SHRINKING_DAMAGE_BASE
	if last_hit > 0 and elapsed_sec < SHRINKING_ESCALATION_WINDOW:
		pct = SHRINKING_DAMAGE_ESCALATED

	_shrinking_last_hit[pid] = now

	var damage = max(1, int(player.max_stats.health * pct))
	player.current_stats.health = max(0, player.current_stats.health - damage)
	player.emit_signal("health_updated", player, player.current_stats.health, player.max_stats.health)
	player.flash()

	if main._floating_text_manager:
		main._floating_text_manager.display(
			"-" + str(damage),
			player.global_position + Vector2(0, -40),
			Color(ProgressData.settings.color_negative),
			null, 0.6, true, Vector2(0, -60), false
		)

	if main._screenshaker:
		main._screenshaker.shake(3.0, 0.1)

	if main._damage_vignette:
		main._damage_vignette.update_from_hp(
			player.current_stats.health,
			player.max_stats.health
		)

	if player.current_stats.health <= 0:
		player.die()


# Two-phase shrinking damage: entry detection (instant) + tick damage (every 0.5s).
# Entry detection fires when the morphed wave sweeps over the player, not just
# when the player walks out — this makes the wobbly boundary feel dangerous.
func _apply_shrinking_damage(_shape, delta: float) -> void:
	var main = Utils.get_scene_node()
	if main == null:
		return

	var players = main._players
	if players == null or players.empty():
		return

	# Entry detection (every frame) — instant damage when first touching danger zone
	# This also fires when the morph wave moves over the player
	for player in players:
		if not is_instance_valid(player) or player.dead:
			continue
		var pid = player.get_instance_id()
		var outside = not _point_in_morphed_boundary(player.global_position)
		var was_outside = _shrinking_was_outside.get(pid, false)

		if outside and not was_outside:
			# Just entered the danger zone — instant hit
			_deal_shrinking_damage(player, main)
			_shrinking_damage_timers[pid] = 0.0

		_shrinking_was_outside[pid] = outside

	# Tick damage (every 0.5s) for players remaining outside the morphed boundary
	for player in players:
		if not is_instance_valid(player) or player.dead:
			continue
		var pid = player.get_instance_id()
		if not _shrinking_was_outside.get(pid, false):
			_shrinking_damage_timers.erase(pid)
			continue

		_shrinking_damage_timers[pid] = _shrinking_damage_timers.get(pid, 0.0) + delta
		if _shrinking_damage_timers[pid] >= SHRINKING_DAMAGE_INTERVAL:
			_shrinking_damage_timers[pid] = 0.0
			_deal_shrinking_damage(player, main)


# --- HAZARD ZONE damage and visuals ---
var _hazard_damage_timers: Dictionary = {}  # player instance_id -> float
const HAZARD_DAMAGE_INTERVAL := 0.5
const HAZARD_DAMAGE_BASE := 0.20
const HAZARD_DAMAGE_ESCALATED := 0.30
const HAZARD_ESCALATION_WINDOW := 2.0

var _hazard_polys: Array = []
var _hazard_time: float = 0.0
const HAZARD_MORPH_SEGMENTS := 48
const HAZARD_MORPH_SPEED := 1.0
const HAZARD_MORPH_AMOUNT := 0.15

var _player_hazard_zones: Dictionary = {}
var _player_last_hazard_hit: Dictionary = {}  # player instance_id -> OS.get_ticks_msec()


# --- MAZE / MULTIROOM wall visuals and projectile colliders ---

# Replace floor tiles with colored wall rectangles for maze/multiroom internal walls.
# Cave walls use the outline's color to match the jagged edge border sprites.
# Maze walls use a darker variant.
func _create_internal_wall_visuals(shape, zone: ZoneData) -> void:
	var ts = Utils.TILE_SIZE
	var is_cave = shape.get_shape_id() == ArenaShapeClass.SHAPE_MULTIROOM

	var wall_color = Color(0.2, 0.18, 0.15, 1.0)
	if outline and outline.modulate:
		if is_cave:
			# Cave: match the outline border color so walls blend with edge sprites
			var c = outline.modulate
			wall_color = Color(c.r * 0.4, c.g * 0.4, c.b * 0.4, 1.0)
		else:
			wall_color = Color(outline.modulate.r * 0.5, outline.modulate.g * 0.5, outline.modulate.b * 0.5, 1.0)

	for i in zone.width:
		for j in zone.height:
			if not shape.should_fill_tile(i, j, ts):
				# Remove the floor tile and draw a solid colored rectangle
				set_cell(i, j, -1)
				var wall_rect = Polygon2D.new()
				var pos = map_to_world(Vector2(i, j)) - Vector2(ts, ts)
				wall_rect.polygon = PoolVector2Array([
					pos, pos + Vector2(ts, 0),
					pos + Vector2(ts, ts), pos + Vector2(0, ts)
				])
				wall_rect.color = wall_color
				wall_rect.z_index = 10
				add_child(wall_rect)



# Fill the area outside the tile grid with colored rectangles so no empty space
# is visible beyond the arena. Uses the cave wall color to blend seamlessly.
# Covers a generous border (4 tiles) around all four sides of the grid.
func _create_outside_wall_fill(zone: ZoneData) -> void:
	var ts = Utils.TILE_SIZE
	var fill_color = Color(0.2, 0.18, 0.15, 1.0)
	if outline and outline.modulate:
		var c = outline.modulate
		fill_color = Color(c.r * 0.4, c.g * 0.4, c.b * 0.4, 1.0)

	var border = 4  # tiles of fill beyond the grid edge
	var w = zone.width
	var h = zone.height

	# Draw one large rectangle per side (top, bottom, left, right) plus corners
	var rects = [
		# Top strip (including corners)
		Vector2(-border, -border), Vector2(w + border, 0),
		# Bottom strip (including corners)
		Vector2(-border, h), Vector2(w + border, h + border),
		# Left strip (between top and bottom)
		Vector2(-border, 0), Vector2(0, h),
		# Right strip (between top and bottom)
		Vector2(w, 0), Vector2(w + border, h),
	]

	for idx in range(0, rects.size(), 2):
		var from_tile = rects[idx]
		var to_tile = rects[idx + 1]
		var pixel_from = Vector2(from_tile.x * ts, from_tile.y * ts)
		var pixel_to = Vector2(to_tile.x * ts, to_tile.y * ts)
		# Use map_to_world offset to match tilemap positioning
		var offset = map_to_world(Vector2.ZERO) - Vector2(ts, ts)
		pixel_from += offset
		pixel_to += offset

		var fill_rect = Polygon2D.new()
		fill_rect.polygon = PoolVector2Array([
			pixel_from,
			Vector2(pixel_to.x, pixel_from.y),
			pixel_to,
			Vector2(pixel_from.x, pixel_to.y)
		])
		fill_rect.color = fill_color
		fill_rect.z_index = 10
		add_child(fill_rect)


# Create an Area2D with collision shapes matching wall tiles that destroys
# projectiles on contact. Without this, bullets would fly through maze walls.
# Monitors player (8), enemy (16), and pet (1024) projectile collision layers.
func _create_projectile_wall_colliders(shape) -> void:
	# Create an Area2D that detects projectiles entering wall tiles
	# and destroys them on contact
	var walls = shape.get_internal_walls()
	if walls.empty():
		return

	var wall_area = Area2D.new()
	wall_area.collision_layer = 0
	# Monitor player projectiles (8), enemy projectiles (16), pet projectiles (1024)
	wall_area.collision_mask = 8 | 16 | 1024
	wall_area.monitoring = true
	wall_area.monitorable = false

	for w in walls:
		var col = CollisionShape2D.new()
		var rect = RectangleShape2D.new()
		rect.extents = w.extents
		col.shape = rect
		col.position = w.pos
		wall_area.add_child(col)

	add_child(wall_area)
	wall_area.connect("area_entered", self, "_on_projectile_hit_wall")


# Callback when a projectile enters a wall tile's Area2D — destroy it
func _on_projectile_hit_wall(area: Area2D) -> void:
	var projectile = area.get_parent()
	if projectile != null and is_instance_valid(projectile) and projectile is Projectile:
		projectile.queue_free()


# Create visual overlays for each hazard zone: a translucent morphing polygon
# plus a CPUParticles2D emitter covering the zone's radius with purple fire.
func _create_hazard_overlays(shape) -> void:
	var zones = shape.get_hazard_zones()

	var fire_gradient = Gradient.new()
	fire_gradient.colors = PoolColorArray([
		Color(0.8, 0.2, 1.0, 0.9),   # bright purple
		Color(0.6, 0.1, 0.9, 0.8),   # medium purple
		Color(0.4, 0.0, 0.7, 0.6),   # dark purple
		Color(0.2, 0.0, 0.3, 0.0),   # fade out
	])
	fire_gradient.offsets = PoolRealArray([0.0, 0.3, 0.7, 1.0])

	for zone in zones:
		# Solid circle with morphing alien edge
		var poly = Polygon2D.new()
		var points = PoolVector2Array()
		for seg in HAZARD_MORPH_SEGMENTS:
			var angle = seg * TAU / float(HAZARD_MORPH_SEGMENTS)
			points.append(zone.center + Vector2(cos(angle), sin(angle)) * zone.radius)
		poly.polygon = points
		poly.color = Color(0.4, 0.0, 0.6, 0.25)
		poly.z_index = 2
		add_child(poly)
		_hazard_polys.append(poly)

		# Dense purple fire covering the whole zone area
		var emitter = CPUParticles2D.new()
		emitter.emitting = true
		emitter.amount = 30
		emitter.lifetime = 0.5
		emitter.speed_scale = 1.5
		emitter.randomness = 0.5
		emitter.direction = Vector2(0, -1)
		emitter.spread = 30.0
		emitter.gravity = Vector2(0, -150)
		emitter.initial_velocity = 40.0
		emitter.initial_velocity_random = 0.5
		emitter.scale_amount = 3.0
		emitter.scale_amount_random = 0.5
		emitter.color_ramp = fire_gradient
		emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		emitter.emission_sphere_radius = zone.radius
		emitter.global_position = zone.center
		emitter.z_index = 3

		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		emitter.material = mat

		add_child(emitter)


# Animate hazard zone outlines with layered sine-wave morphing.
# Each zone gets a unique phase offset (+ zone index) so they wobble independently.
func _update_hazard_rings(shape, delta: float) -> void:
	_hazard_time += delta * HAZARD_MORPH_SPEED
	var zones = shape.get_hazard_zones()
	for zi in zones.size():
		if zi >= _hazard_polys.size():
			break
		var zone = zones[zi]
		var poly = _hazard_polys[zi]
		var pts = PoolVector2Array()
		for seg in HAZARD_MORPH_SEGMENTS:
			var angle = seg * TAU / float(HAZARD_MORPH_SEGMENTS)
			# Layer multiple sine waves at different frequencies for organic wobble
			var offset = sin(angle * 3.0 + _hazard_time * 2.3) * 0.4
			offset += sin(angle * 5.0 - _hazard_time * 1.7) * 0.3
			offset += sin(angle * 7.0 + _hazard_time * 3.1) * 0.2
			offset += sin(angle * 2.0 + _hazard_time * 0.9 + float(zi)) * 0.3
			var r = zone.radius * (1.0 + offset * HAZARD_MORPH_AMOUNT)
			pts.append(zone.center + Vector2(cos(angle), sin(angle)) * r)
		poly.polygon = pts


# Deal percentage-based damage to a player inside a hazard zone.
# Same escalation mechanic as shrinking: 20% base, 30% if hit again within 2s.
func _deal_hazard_damage(player, main) -> void:
	var pid = player.get_instance_id()
	var now = OS.get_ticks_msec()
	var last_hit = _player_last_hazard_hit.get(pid, 0)
	var elapsed_sec = (now - last_hit) / 1000.0

	var pct = HAZARD_DAMAGE_BASE
	if last_hit > 0 and elapsed_sec < HAZARD_ESCALATION_WINDOW:
		pct = HAZARD_DAMAGE_ESCALATED

	_player_last_hazard_hit[pid] = now

	var damage = max(1, int(player.max_stats.health * pct))
	player.current_stats.health = max(0, player.current_stats.health - damage)
	player.emit_signal("health_updated", player, player.current_stats.health, player.max_stats.health)
	player.flash()

	if main._floating_text_manager:
		main._floating_text_manager.display(
			"-" + str(damage),
			player.global_position + Vector2(0, -40),
			Color(ProgressData.settings.color_negative),
			null, 0.6, true, Vector2(0, -60), false
		)

	if main._damage_vignette:
		main._damage_vignette.update_from_hp(
			player.current_stats.health,
			player.max_stats.health
		)

	if player.current_stats.health <= 0:
		player.die()


# Two-phase hazard damage: entry detection (instant) + tick damage (every 0.5s).
# Tracks which zone indices each player was in last frame — entering a NEW zone
# triggers instant damage, staying in any zone triggers periodic ticks.
func _apply_hazard_damage(shape, delta: float) -> void:
	var main = Utils.get_scene_node()
	if main == null:
		return

	var players = main._players
	if players == null or players.empty():
		return

	# Entry detection (every frame) — instant damage on first touch
	for player in players:
		if not is_instance_valid(player) or player.dead:
			continue
		var pid = player.get_instance_id()
		var current_zones = shape.get_hazard_zones_containing(player.global_position)
		var prev_zones = _player_hazard_zones.get(pid, [])

		for zi in current_zones:
			if not (zi in prev_zones):
				_deal_hazard_damage(player, main)
				break

		_player_hazard_zones[pid] = current_zones

	# Tick damage (every 0.5s per player) for players remaining inside zones
	for player in players:
		if not is_instance_valid(player) or player.dead:
			continue
		var pid = player.get_instance_id()
		var current_zones = _player_hazard_zones.get(pid, [])
		if current_zones.size() == 0:
			_hazard_damage_timers.erase(pid)
			continue
		_hazard_damage_timers[pid] = _hazard_damage_timers.get(pid, 0.0) + delta
		if _hazard_damage_timers[pid] >= HAZARD_DAMAGE_INTERVAL:
			_hazard_damage_timers[pid] = 0.0
			_deal_hazard_damage(player, main)


# --- MAZE / MULTIROOM AStar2D navigation ---

# Build an AStar2D navigation graph from walkable tiles.
# Each walkable tile becomes a point; adjacent walkable tiles are connected.
# Supports 4-directional + 4-diagonal movement, but diagonals are only allowed
# when BOTH orthogonal neighbors are walkable (no corner-cutting through walls).
func _create_navigation(shape, zone: ZoneData) -> void:
	_astar = AStar2D.new()
	var ts = Utils.TILE_SIZE
	_astar_tile_w = zone.width

	# Add a point for each walkable tile
	for j in zone.height:
		for i in zone.width:
			if shape.should_fill_tile(i, j, ts):
				var point_id = j * _astar_tile_w + i
				var pos = Vector2(i * ts + ts / 2.0, j * ts + ts / 2.0)
				_astar.add_point(point_id, pos)

	# Connect adjacent walkable tiles (4-directional + 4 diagonals)
	for j in zone.height:
		for i in zone.width:
			if not shape.should_fill_tile(i, j, ts):
				continue
			var point_id = j * _astar_tile_w + i

			# Orthogonal neighbors
			if i + 1 < zone.width and shape.should_fill_tile(i + 1, j, ts):
				_astar.connect_points(point_id, j * _astar_tile_w + (i + 1))
			if j + 1 < zone.height and shape.should_fill_tile(i, j + 1, ts):
				_astar.connect_points(point_id, (j + 1) * _astar_tile_w + i)

			# Diagonal neighbors (only if both orthogonal tiles are walkable — no corner cutting)
			# Down-Right
			if i + 1 < zone.width and j + 1 < zone.height:
				if shape.should_fill_tile(i + 1, j + 1, ts) and shape.should_fill_tile(i + 1, j, ts) and shape.should_fill_tile(i, j + 1, ts):
					_astar.connect_points(point_id, (j + 1) * _astar_tile_w + (i + 1))
			# Down-Left
			if i - 1 >= 0 and j + 1 < zone.height:
				if shape.should_fill_tile(i - 1, j + 1, ts) and shape.should_fill_tile(i - 1, j, ts) and shape.should_fill_tile(i, j + 1, ts):
					_astar.connect_points(point_id, (j + 1) * _astar_tile_w + (i - 1))


# Find the nearest AStar point to a world position
func _get_closest_astar_point(pos: Vector2) -> int:
	if _astar == null:
		return -1
	return _astar.get_closest_point(pos)


# Steer all enemies along AStar paths toward the closest alive player.
# Paths are recalculated every NAV_UPDATE_INTERVAL (0.15s).
# Sets enemy._move_locked = true and overrides _current_movement to follow waypoints.
#
# Anti-stuck detection: if an enemy moves less than STUCK_MOVE_MIN (5px) in
# STUCK_THRESHOLD (0.15s), it gets nudged 20px toward its waypoint and its path
# is recalculated. This handles corner cases where physics bodies get wedged.
func _steer_enemies_along_paths(delta: float, shape) -> void:
	var main = Utils.get_scene_node()
	if main == null or _astar == null:
		return

	var players = main._players
	if players == null or players.empty():
		return

	# Find closest alive player
	var target_player = null
	for p in players:
		if is_instance_valid(p) and not p.dead:
			target_player = p
			break
	if target_player == null:
		return

	var target_pos = target_player.global_position
	var target_point = _get_closest_astar_point(target_pos)
	if target_point == -1:
		return

	var entity_spawner = main._entity_spawner
	if entity_spawner == null:
		return

	# Recalculate paths periodically
	_nav_update_timer += delta
	var should_update = _nav_update_timer >= NAV_UPDATE_INTERVAL
	if should_update:
		_nav_update_timer = 0.0
		# Prune dead enemies from tracking dicts
		for eid in _enemy_last_pos.keys():
			if not _enemy_paths.has(eid):
				_enemy_last_pos.erase(eid)
				_enemy_stuck_time.erase(eid)
				_enemy_unlock_time.erase(eid)

	for enemy in entity_spawner.enemies:
		if not is_instance_valid(enemy) or enemy.sleeping or enemy.dead:
			continue

		var eid = enemy.get_instance_id()

		# Recalculate path
		if should_update or not _enemy_paths.has(eid):
			var enemy_point = _get_closest_astar_point(enemy.global_position)
			if enemy_point == -1 or enemy_point == target_point:
				enemy._move_locked = false
				continue
			var id_path = _astar.get_id_path(enemy_point, target_point)
			var point_path = PoolVector2Array()
			for pid in id_path:
				point_path.append(_astar.get_point_position(pid))
			_enemy_paths[eid] = point_path
			# Find closest waypoint in new path instead of resetting to 0
			var best_idx = 0
			var best_dist = INF
			for wi in point_path.size():
				var d = enemy.global_position.distance_to(point_path[wi])
				if d < best_dist:
					best_dist = d
					best_idx = wi
			# Start from the waypoint AFTER the closest one (we're already near it)
			_enemy_path_idx[eid] = min(best_idx + 1, point_path.size() - 1)

		var path = _enemy_paths.get(eid, PoolVector2Array())
		var idx = _enemy_path_idx.get(eid, 0)

		if path.size() == 0 or idx >= path.size():
			enemy._move_locked = false
			continue

		# Advance past reached waypoints
		while idx < path.size() and enemy.global_position.distance_to(path[idx]) < NAV_WAYPOINT_REACH_DIST:
			idx += 1
		_enemy_path_idx[eid] = idx

		if idx >= path.size():
			enemy._move_locked = false
			continue

		# Follow the immediate next waypoint
		var waypoint = path[idx]

		enemy._move_locked = true
		enemy._current_movement = waypoint - enemy.global_position

		# --- Anti-stuck detection ---
		var last_pos = _enemy_last_pos.get(eid, enemy.global_position)
		var moved = enemy.global_position.distance_to(last_pos)
		_enemy_last_pos[eid] = enemy.global_position

		if moved < STUCK_MOVE_MIN:
			_enemy_stuck_time[eid] = _enemy_stuck_time.get(eid, 0.0) + delta
		else:
			_enemy_stuck_time[eid] = 0.0

		if _enemy_stuck_time[eid] >= STUCK_THRESHOLD:
			_enemy_stuck_time[eid] = 0.0
			# Physically move enemy toward waypoint to get past the corner
			var nudge_dir = (waypoint - enemy.global_position).normalized()
			enemy.global_position += nudge_dir * 20.0
			# Recalculate path from new position
			_enemy_paths.erase(eid)
			_enemy_path_idx.erase(eid)


# Steer pets along AStar paths toward their current_target (usually an enemy).
# Same pattern as enemy steering with two key differences:
#   1. Respects existing _move_locked set by the pet itself (e.g., BonkDog jump)
#      — only overrides movement when _pet_nav_locked is true (set by us)
#   2. Targets can change mid-path — detects target_id changes and forces
#      immediate path recalculation instead of waiting for the timer
func _steer_pets_along_paths(delta: float, _shape) -> void:
	var main = Utils.get_scene_node()
	if main == null or _astar == null:
		return

	var entity_spawner = main._entity_spawner
	if entity_spawner == null:
		return

	# Timer-based path recalculation
	_pet_nav_update_timer += delta
	var should_update = _pet_nav_update_timer >= NAV_UPDATE_INTERVAL
	if should_update:
		_pet_nav_update_timer = 0.0
		# Prune dead/freed pets from tracking dicts
		for pid in _pet_last_pos.keys():
			if not _pet_paths.has(pid):
				_pet_last_pos.erase(pid)
				_pet_stuck_time.erase(pid)
				_pet_nav_locked.erase(pid)
				_pet_last_target.erase(pid)

	for pet in entity_spawner.pets:
		if not is_instance_valid(pet) or pet.dead:
			continue
		if pet._end_of_wave:
			continue

		var pid = pet.get_instance_id()

		# Respect existing _move_locked set by the pet itself (e.g. BonkDog jump)
		if pet._move_locked and not _pet_nav_locked.get(pid, false):
			continue

		# Get the pet's current target
		var target = pet.current_target
		if target == null or not is_instance_valid(target) or not (target is Node2D):
			pet._move_locked = false
			_pet_nav_locked[pid] = false
			continue

		var target_pos = target.global_position

		# Detect target changes -> force path recalculation
		var current_target_id = target.get_instance_id()
		var last_target_id = _pet_last_target.get(pid, -1)
		var target_changed = current_target_id != last_target_id
		_pet_last_target[pid] = current_target_id
		if target_changed:
			_pet_paths.erase(pid)

		# Recalculate path
		if should_update or not _pet_paths.has(pid):
			var pet_point = _get_closest_astar_point(pet.global_position)
			var target_point = _get_closest_astar_point(target_pos)
			if pet_point == -1 or target_point == -1 or pet_point == target_point:
				pet._move_locked = false
				_pet_nav_locked[pid] = false
				continue
			var id_path = _astar.get_id_path(pet_point, target_point)
			var point_path = PoolVector2Array()
			for point_id in id_path:
				point_path.append(_astar.get_point_position(point_id))
			_pet_paths[pid] = point_path
			# Find closest waypoint and start from the one after it
			var best_idx = 0
			var best_dist = INF
			for wi in point_path.size():
				var d = pet.global_position.distance_to(point_path[wi])
				if d < best_dist:
					best_dist = d
					best_idx = wi
			_pet_path_idx[pid] = min(best_idx + 1, point_path.size() - 1)

		var path = _pet_paths.get(pid, PoolVector2Array())
		var idx = _pet_path_idx.get(pid, 0)

		if path.size() == 0 or idx >= path.size():
			pet._move_locked = false
			_pet_nav_locked[pid] = false
			continue

		# Advance past reached waypoints
		while idx < path.size() and pet.global_position.distance_to(path[idx]) < NAV_WAYPOINT_REACH_DIST:
			idx += 1
		_pet_path_idx[pid] = idx

		if idx >= path.size():
			pet._move_locked = false
			_pet_nav_locked[pid] = false
			continue

		# Follow the immediate next waypoint
		var waypoint = path[idx]

		pet._move_locked = true
		pet._current_movement = waypoint - pet.global_position
		_pet_nav_locked[pid] = true

		# --- Anti-stuck detection ---
		var last_pos = _pet_last_pos.get(pid, pet.global_position)
		var moved = pet.global_position.distance_to(last_pos)
		_pet_last_pos[pid] = pet.global_position

		if moved < STUCK_MOVE_MIN:
			_pet_stuck_time[pid] = _pet_stuck_time.get(pid, 0.0) + delta
		else:
			_pet_stuck_time[pid] = 0.0

		if _pet_stuck_time[pid] >= STUCK_THRESHOLD:
			_pet_stuck_time[pid] = 0.0
			var nudge_dir = (waypoint - pet.global_position).normalized()
			pet.global_position += nudge_dir * 20.0
			_pet_paths.erase(pid)
			_pet_path_idx.erase(pid)
