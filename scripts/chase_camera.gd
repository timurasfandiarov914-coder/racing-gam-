extends Camera3D

@export var target: Node3D
@export var position_smoothing := 4.2

var _initialised := false

func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return

	var speed := 0.0
	if target is RigidBody3D:
		speed = (target as RigidBody3D).linear_velocity.length()
	var speed_mix := clampf(speed / 65.0, 0.0, 1.0)

	var target_basis: Basis = target.global_transform.basis
	var follow_distance := lerpf(8.0, 11.6, speed_mix)
	var follow_height := lerpf(3.0, 4.3, speed_mix)
	var desired_position := target.global_position + target_basis.y * follow_height + target_basis.z * follow_distance

	if not _initialised:
		global_position = desired_position
		_initialised = true
	else:
		global_position = global_position.lerp(desired_position, 1.0 - exp(-position_smoothing * delta))

	var look_ahead := lerpf(4.0, 12.0, speed_mix)
	var look_point := target.global_position - target_basis.z * look_ahead + Vector3.UP * 0.7
	look_at(look_point, Vector3.UP)
	fov = lerpf(70.0, 82.0, speed_mix)
