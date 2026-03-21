extends "res://main.gd"

const ArenaShapeClass = preload("res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd")

var _shrinking_outline_node: Node2D = null
var _shrinking_line: Line2D = null
var _fire_emitters: Array = []
const FIRE_SPACING := 80.0
const MAX_FIRE_EMITTERS := 60


func _ready() -> void:
	._ready()

	var shape = ZoneService.arena_shape
	if shape != null and shape.is_shrinking():
		_create_shrinking_outline()



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


func _create_shrinking_outline() -> void:
	_shrinking_outline_node = Node2D.new()
	_shrinking_outline_node.z_index = 15
	_tile_map.add_child(_shrinking_outline_node)

	# Create the boundary line
	_shrinking_line = Line2D.new()
	_shrinking_line.width = 3.0
	_shrinking_line.default_color = Color(0.6, 0.1, 0.9, 0.9)
	_shrinking_line.antialiased = true
	_shrinking_outline_node.add_child(_shrinking_line)

	# Create fire emitter pool
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

		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		emitter.material = mat

		_shrinking_outline_node.add_child(emitter)
		_fire_emitters.append(emitter)


func _update_shrinking_outline(shape) -> void:
	if _shrinking_outline_node == null:
		return

	# Update the boundary line
	_shrinking_line.points = shape.get_outline_points()

	# Calculate positions along the 4 edges of the shrunk rectangle
	var pts = shape.get_collision_points()
	if pts.size() < 4:
		return

	var edge_positions = []
	for i in 4:
		var a = pts[i]
		var b = pts[(i + 1) % 4]
		var edge = b - a
		var edge_length = edge.length()
		var num_on_edge = max(1, int(edge_length / FIRE_SPACING))
		for j in num_on_edge:
			var t = (j + 0.5) / float(num_on_edge)
			edge_positions.append(a.linear_interpolate(b, t))

	# Position fire emitters along the boundary
	for i in _fire_emitters.size():
		if i < edge_positions.size():
			_fire_emitters[i].global_position = edge_positions[i]
			_fire_emitters[i].emitting = true
		else:
			_fire_emitters[i].emitting = false
