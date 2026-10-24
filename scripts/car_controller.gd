extends RigidBody3D

const BASE_TOP_SPEED := 74.0 # m/s, approximately 266 km/h
const NITRO_TOP_SPEED := 86.0
const WHEEL_RADIUS := 0.34

var _throttle := 0.0
var _brake := 0.0
var _steering := 0.0
var _nitro_active := false
var _wheel_pivots: Array[Node3D] = []
var _front_wheels: Array[Node3D] = []

func _ready() -> void:
	mass = 1150.0
	can_sleep = false
	continuous_cd = true
	linear_damp = 0.025
	angular_damp = 2.4
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 1.0
	physics_material_override.bounce = 0.0

func set_controls(throttle: float, brake: float, steering: float, nitro_active: bool) -> void:
	_throttle = clampf(throttle, 0.0, 1.0)
	_brake = clampf(brake, 0.0, 1.0)
	_steering = clampf(steering, -1.0, 1.0)
	_nitro_active = nitro_active

func set_wheel_visuals(wheel_pivots: Array[Node3D], front_wheels: Array[Node3D]) -> void:
	_wheel_pivots = wheel_pivots
	_front_wheels = front_wheels

func _physics_process(delta: float) -> void:
	var forward: Vector3 = -global_transform.basis.z
	var right: Vector3 = global_transform.basis.x
	var forward_speed: float = linear_velocity.dot(forward)
	var lateral_speed: float = linear_velocity.dot(right)

	var top_speed := NITRO_TOP_SPEED if _nitro_active else BASE_TOP_SPEED
	var acceleration := 6.2 + (4.3 if _nitro_active else 0.0)
	if _throttle > 0.0 and forward_speed < top_speed:
		apply_central_force(forward * _throttle * mass * acceleration)

	if _brake > 0.0:
		if absf(forward_speed) > 1.3:
			apply_central_force(forward * -signf(forward_speed) * mass * 13.5 * _brake)
		else:
			# Once stopped, the brake control also allows a slow reverse.
			apply_central_force(-forward * mass * 3.5 * _brake)

	# Arcade suspension-free prototype: counter lateral slip while allowing a controlled drift.
	var grip := lerpf(4.8, 3.0, absf(_steering))
	apply_central_force(-right * lateral_speed * mass * grip)

	# Aerodynamic drag grows with speed.
	apply_central_force(-linear_velocity * mass * (0.012 + linear_velocity.length() * 0.000045))

	# Steering response builds with speed, avoiding instant spins at low velocity.
	var speed_factor := clampf(absf(forward_speed) / 7.0, 0.0, 1.0)
	var travel_direction := 1.0 if forward_speed >= 0.0 else -1.0
	var target_yaw_rate := -_steering * 0.78 * speed_factor * travel_direction
	angular_velocity.y = lerpf(angular_velocity.y, target_yaw_rate, minf(delta * 2.8, 1.0))
	angular_velocity.x = lerpf(angular_velocity.x, 0.0, minf(delta * 2.2, 1.0))
	angular_velocity.z = lerpf(angular_velocity.z, 0.0, minf(delta * 3.0, 1.0))

func _process(delta: float) -> void:
	var forward_speed := linear_velocity.dot(-global_transform.basis.z)
	for wheel in _front_wheels:
		if is_instance_valid(wheel):
			wheel.rotation.y = lerpf(wheel.rotation.y, -_steering * 0.38, minf(delta * 7.0, 1.0))
	for wheel in _wheel_pivots:
		if is_instance_valid(wheel):
			wheel.rotate_object_local(Vector3.RIGHT, -forward_speed * delta / WHEEL_RADIUS)
