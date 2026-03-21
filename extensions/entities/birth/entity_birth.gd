extends "res://entities/birth/entity_birth.gd"

const ArenaShapeClass = preload("res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd")


func _physics_process(delta: float) -> void:
	_current_time_before_spawn -= 60 * delta

	if _sprite.self_modulate.a <= FLICKER_TRANSPARENCY:
		_time_invisible -= 60 * delta
		if _time_invisible <= 0:
			_sprite.self_modulate.a = 1.0
			_flicker_cd = get_flicker_cd()
	else:
		_flicker_cd -= 60 * delta
		if _flicker_cd <= 0:
			_sprite.self_modulate.a = FLICKER_TRANSPARENCY
			_time_invisible = 6

	if _current_time_before_spawn <= 0:
		# In Curse Run, never cancel enemy spawns - they must come from the right edge
		var shape = ZoneService.arena_shape
		var is_curse_run = shape != null and shape.get_shape_id() == ArenaShapeClass.SHAPE_CURSE_RUN
		if _colliding_with_player and type == EntityType.ENEMY and not is_curse_run:
			global_position = ZoneService.get_rand_pos()
			_current_time_before_spawn = time_before_spawn
		else:
			SoundManager2D.play(birth_end_sound, global_position, -15, 0.2)
			call_deferred("birth")
