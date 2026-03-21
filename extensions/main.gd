# main.gd — Extends the main game scene for Closing Storm shrinking outline.
#
# When the active arena shape is shrinking (Closing Storm), this extension
# creates a Line2D boundary outline and a pool of CPUParticles2D fire emitters
# that track the shrinking rectangle's edges each physics frame.
#
# This runs IN ADDITION to the shrinking logic in my_tile_map.gd (which handles
# the fog overlay, morphing wobble, and damage). This extension specifically
# handles the main scene's outline layer because main.gd has access to
# _wave_timer for computing the time ratio.

extends "res://main.gd"

const ArenaShapeClass = preload("res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd")

var _shrinking_outline_node: Node2D = null
var _shrinking_line: Line2D = null
var _fire_emitters: Array = []
const FIRE_SPACING := 80.0        # pixels between fire emitters along edges
const MAX_FIRE_EMITTERS := 60     # total emitter pool size


func _ready() -> void:
	._ready()

	var shape = ZoneService.arena_shape
	if shape != null and shape.is_shrinking():
		_create_shrinking_outline()



# Update the shrinking shape each physics frame and reposition the outline.
# time_ratio = how far through the wave we are (0.0 -> 1.0).
func _physics_process(delta: float) -> void:
	._physics_process(delta)

	var shape = ZoneService.arena_shape
	if shape == null or not shape.is_shrinking():
		return

	if _wave_timer.is_stopped() or _wave_timer.wait_time <= 0:
		return

	var elapsed = _wave_timer.wait_time - _wave_timer.time_left
	var time_ratio = elapsed / _wave_timer.wait_time
	shape.update(time_ratio)

	_update_shrinking_outline(shape)


# Create the visual outline: a purple Line2D plus a pool of fire particle
# emitters that will be positioned along the boundary edges each frame.
func _create_shrinking_outline() -> void:
	_shrinking_outline_node = Node2D.new()
	_shrinking_outline_node.z_index = 15
	_tile_map.add_child(_shrinking_outline_node)

	# Boundary line — thin purple, matches the storm theme
	_shrinking_line = Line2D.new()
	_shrinking_line.width = 3.0
	_shrinking_line.default_color = Color(0.6, 0.1, 0.9, 0.9)
	_shrinking_line.antialiased = true
	_shrinking_outline_node.add_child(_shrinking_line)

	# Fire emitter pool — pre-created and repositioned each frame.
	# Gradient goes from bright purple (near boundary) to transparent (fading out).
	var fire_gradient = Gradient.new()
	fire_gradient.colors = PoolColorArray([
		Color(0.8, 0.2, 1.0, 0.9),   # bright purple
		Color(0.6, 0.1, 0.9, 0.8),   # medium purple
		Color(0.4, 0.0, 0.7, 0.6),   # dark purple
		Color(0.2, 0.0, 0.3, 0.0),   # fade out
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

		# Additive blend for a glowing fire effect
		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		emitter.material = mat

		_shrinking_outline_node.add_child(emitter)
		_fire_emitters.append(emitter)


# Reposition the boundary line and distribute fire emitters evenly along
# the 4 edges of the current shrunk rectangle.
func _update_shrinking_outline(shape) -> void:
	if _shrinking_outline_node == null:
		return

	# Update the boundary line to match current shape outline
	_shrinking_line.points = shape.get_outline_points()

	# Distribute fire emitters evenly along the 4 rectangle edges
	var pts = shape.get_collision_points()
	if pts.size() < 4:
		return

	var edge_positions = []
	for i in 4:
		var a = pts[i]
		var b = pts[(i + 1) % 4]
		var edge = b - a
		var edge_length = edge.length()
		# Place emitters at regular intervals along each edge
		var num_on_edge = max(1, int(edge_length / FIRE_SPACING))
		for j in num_on_edge:
			var t = (j + 0.5) / float(num_on_edge)
			edge_positions.append(a.linear_interpolate(b, t))

	# Assign positions to emitters; disable any extras beyond what we need
	for i in _fire_emitters.size():
		if i < edge_positions.size():
			_fire_emitters[i].global_position = edge_positions[i]
			_fire_emitters[i].emitting = true
		else:
			_fire_emitters[i].emitting = false
