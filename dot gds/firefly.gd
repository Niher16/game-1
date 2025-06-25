extends Node3D

# Firefly: floats randomly within room bounds and flickers light
@export var move_radius: float = 3.0
@export var move_speed: float = 1.5
@export var light_flicker_intensity: float = 0.05
@export var light_flicker_speed: float = 1.0
@export var room_bounds: AABB # Set this in the editor to define the room

var _target_pos: Vector3
var _origin: Vector3
var _light: OmniLight3D
var _velocity: Vector3 = Vector3.ZERO
var _wait_timer: float = 0.0

func _ready():
	_origin = global_transform.origin
	if room_bounds:
		# Clamp origin to room center if needed
		_origin = room_bounds.position + room_bounds.size * 0.5
	_target_pos = _get_new_target()
	_light = $OmniLight3D
	if _light:
		_light.light_energy = 0.7
		_light.light_color = Color(1.0, 0.95, 0.7)

func _process(delta):
	var pos = global_transform.origin
	if _wait_timer > 0.0:
		_wait_timer -= delta
		return

	var dir = (_target_pos - pos)
	if dir.length() < 0.2:
		_wait_timer = randf_range(0.1, 0.5)
		_target_pos = _get_new_target()
	else:
		_velocity = dir.normalized() * move_speed
		pos += _velocity * delta
		# Animate up/down for flying effect
		pos.y = _origin.y + sin(Time.get_ticks_msec() / 400.0 + hash(self)) * 0.2
		# Clamp to room bounds if set
		if room_bounds:
			for axis in [0, 1, 2]:
				pos[axis] = clamp(pos[axis], room_bounds.position[axis], room_bounds.position[axis] + room_bounds.size[axis])
		global_transform.origin = pos

	# Flicker light
	if _light:
		var t = Time.get_ticks_msec() / 1000.0
		var base = sin(t * light_flicker_speed)
		var subtle = sin(t * (light_flicker_speed * 0.5)) * 0.5
		var flicker = (base + subtle) * light_flicker_intensity
		_light.light_energy = 0.7 + flicker

func _get_new_target() -> Vector3:
	if room_bounds:
		return Vector3(
			randf_range(room_bounds.position.x, room_bounds.position.x + room_bounds.size.x),
			randf_range(room_bounds.position.y, room_bounds.position.y + room_bounds.size.y),
			randf_range(room_bounds.position.z, room_bounds.position.z + room_bounds.size.z)
		)
	else:
		return _origin + Vector3(
			randf_range(-move_radius, move_radius),
			randf_range(-move_radius * 0.5, move_radius * 0.5),
			randf_range(-move_radius, move_radius)
		)
