extends Node3D

const CarControllerScript = preload("res://scripts/car_controller.gd")
const ChaseCameraScript = preload("res://scripts/chase_camera.gd")

const ROAD_LENGTH := 3200.0
const ROAD_CENTER_Z := -1580.0
const ROAD_WIDTH := 30.0

var _car: RigidBody3D
var _speed_label: Label
var _distance_label: Label
var _nitro_label: Label
var _nitro_bar: ProgressBar
var _input_debug_label: Label
var _nitro_value := 100.0
var _touch_hitboxes: Array[Dictionary] = []
var _active_touch_actions: Dictionary = {}
var _touch_debug_message := "TOUCH INPUT / READY"

func _ready() -> void:
	_ensure_input_actions()
	_build_environment()
	_build_road()
	_build_city()
	_build_player()
	_build_hud()

func _input(event: InputEvent) -> void:
	# Read raw Android touch events before GUI mouse handling. Every finger keeps
	# its own action so GAS + steering (or BRAKE + steering) work simultaneously.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var action := _action_at_screen_position(touch.position)
			if not action.is_empty():
				_active_touch_actions[touch.index] = action
				_touch_debug_message = "TOUCH INPUT / " + action.to_upper()
			else:
				_touch_debug_message = "TOUCH RECEIVED / NO BUTTON HIT"
		else:
			_active_touch_actions.erase(touch.index)
			if _active_touch_actions.is_empty():
				_touch_debug_message = "TOUCH INPUT / READY"
		_refresh_touch_visuals()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		# Also allow a finger that slides onto a control to start holding it.
		if not _active_touch_actions.has(drag.index):
			var action := _action_at_screen_position(drag.position)
			if not action.is_empty():
				_active_touch_actions[drag.index] = action
				_touch_debug_message = "TOUCH INPUT / " + action.to_upper()
		_refresh_touch_visuals()

func _process(delta: float) -> void:
	if not is_instance_valid(_car):
		return

	var throttle := _get_action_strength("accelerate")
	var brake := _get_action_strength("brake")
	var steering := _get_action_strength("steer_right") - _get_action_strength("steer_left")
	var nitro_requested := _is_action_pressed("nitro")
	var nitro_active := nitro_requested and throttle > 0.0 and _nitro_value > 0.0

	if nitro_active:
		_nitro_value = maxf(0.0, _nitro_value - 34.0 * delta)
	else:
		_nitro_value = minf(100.0, _nitro_value + 10.0 * delta)

	_car.call("set_controls", throttle, brake, steering, nitro_active)

	if _car.global_position.z < -ROAD_LENGTH + 30.0:
		_car.global_position = Vector3(2.5, 0.36, 0.0)
		_car.linear_velocity = Vector3.ZERO
		_car.angular_velocity = Vector3.ZERO

	var speed_kmh := int(round(_car.linear_velocity.length() * 3.6))
	_speed_label.text = "%03d" % speed_kmh
	_distance_label.text = "DISTANCE  /  %05d M" % int(maxf(0.0, -_car.global_position.z))
	_nitro_bar.value = _nitro_value
	_nitro_label.text = "NITRO  /  ACTIVE" if nitro_active else "NITRO  /  CHARGING" if _nitro_value < 99.0 else "NITRO  /  READY"

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.12, 0.24, 0.42)
	sky_material.sky_horizon_color = Color(0.62, 0.72, 0.80)
	sky_material.ground_bottom_color = Color(0.075, 0.085, 0.10)
	sky_material.ground_horizon_color = Color(0.43, 0.48, 0.52)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.57, 0.65, 0.72)
	environment.fog_density = 0.0008
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "AfternoonSun"
	sun.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.91, 0.78)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)

func _build_road() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "SurroundingGround"
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(240.0, ROAD_LENGTH)
	ground.mesh = ground_mesh
	ground.position = Vector3(0.0, -0.31, ROAD_CENTER_Z)
	ground.material_override = _make_material(Color(0.075, 0.09, 0.105), 0.98)
	add_child(ground)

	var road_body := StaticBody3D.new()
	road_body.name = "RoadCollision"
	var road_collision := CollisionShape3D.new()
	var road_shape := BoxShape3D.new()
	road_shape.size = Vector3(ROAD_WIDTH, 0.5, ROAD_LENGTH)
	road_collision.shape = road_shape
	road_collision.position = Vector3(0.0, -0.25, ROAD_CENTER_Z)
	road_body.add_child(road_collision)
	add_child(road_body)

	var road_visual := MeshInstance3D.new()
	road_visual.name = "Asphalt"
	var road_mesh := PlaneMesh.new()
	road_mesh.size = Vector2(ROAD_WIDTH, ROAD_LENGTH)
	road_visual.mesh = road_mesh
	road_visual.position = Vector3(0.0, 0.006, ROAD_CENTER_Z)
	road_visual.material_override = _make_material(Color(0.12, 0.135, 0.15), 0.94)
	add_child(road_visual)

	var line_material := _make_material(Color(0.84, 0.87, 0.85), 0.82)
	var yellow_material := _make_material(Color(0.95, 0.68, 0.20), 0.78)
	for x in [-0.18, 0.18]:
		_add_box(self, "CenterDivider", Vector3(0.09, 0.026, ROAD_LENGTH), Vector3(x, 0.024, ROAD_CENTER_Z), yellow_material)
	for x in [-12.5, 12.5]:
		_add_box(self, "ShoulderLine", Vector3(0.13, 0.026, ROAD_LENGTH), Vector3(x, 0.024, ROAD_CENTER_Z), line_material)

	var dash_positions: Array[Vector3] = []
	var z := 18.0
	while z > -ROAD_LENGTH:
		for x in [-9.0, -4.5, 4.5, 9.0]:
			dash_positions.append(Vector3(x, 0.026, z))
		z -= 12.0
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.12, 0.025, 5.0)
	var dash_multimesh := MultiMesh.new()
	dash_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	dash_multimesh.mesh = dash_mesh
	dash_multimesh.instance_count = dash_positions.size()
	for i in range(dash_positions.size()):
		dash_multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, dash_positions[i]))
	var dashes := MultiMeshInstance3D.new()
	dashes.name = "LaneDashes"
	dashes.multimesh = dash_multimesh
	dashes.material_override = line_material
	add_child(dashes)

	var rail_body := StaticBody3D.new()
	rail_body.name = "GuardrailCollision"
	for side in [-1.0, 1.0]:
		var rail_collision := CollisionShape3D.new()
		var rail_shape := BoxShape3D.new()
		rail_shape.size = Vector3(0.55, 1.05, ROAD_LENGTH)
		rail_collision.shape = rail_shape
		rail_collision.position = Vector3(side * 14.35, 0.48, ROAD_CENTER_Z)
		rail_body.add_child(rail_collision)
		_add_box(self, "GuardrailLower", Vector3(0.38, 0.72, ROAD_LENGTH), Vector3(side * 14.35, 0.40, ROAD_CENTER_Z), _make_material(Color(0.40, 0.46, 0.50), 0.42, 0.62))
		_add_box(self, "GuardrailTop", Vector3(0.46, 0.12, ROAD_LENGTH), Vector3(side * 14.35, 0.82, ROAD_CENTER_Z), _make_material(Color(0.66, 0.71, 0.73), 0.34, 0.72))
	add_child(rail_body)

func _build_city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 381927
	var building_transforms: Array[Transform3D] = []
	var building_colors: Array[Color] = []
	var window_transforms: Array[Transform3D] = []
	var palette: Array[Color] = [
		Color(0.25, 0.30, 0.35),
		Color(0.31, 0.35, 0.39),
		Color(0.20, 0.26, 0.32),
		Color(0.38, 0.39, 0.38),
		Color(0.28, 0.32, 0.36),
	]

	var z := -28.0
	while z > -ROAD_LENGTH + 20.0:
		for side_value in [-1.0, 1.0]:
			var side: float = side_value
			for row in range(2):
				var width := rng.randf_range(9.0, 18.0) if row == 0 else rng.randf_range(12.0, 23.0)
				var height := rng.randf_range(18.0, 58.0) if row == 0 else rng.randf_range(28.0, 78.0)
				var depth := rng.randf_range(13.0, 27.0)
				var base_x := 23.0 if row == 0 else 41.0
				var x := side * (base_x + rng.randf_range(0.0, 10.0))
				var building_z := z + rng.randf_range(-13.0, 13.0)
				var dimensions := Vector3(width, height, depth)
				building_transforms.append(Transform3D(Basis.from_scale(dimensions), Vector3(x, height * 0.5, building_z)))
				building_colors.append(palette[rng.randi_range(0, palette.size() - 1)])

				var window_y := 3.0
				while window_y < height - 1.0:
					var inner_face_x := x - side * (width * 0.5 + 0.055)
					var window_size := Vector3(0.07, 0.78, depth * 0.76)
					window_transforms.append(Transform3D(Basis.from_scale(window_size), Vector3(inner_face_x, window_y, building_z)))
					window_y += 3.6
		z -= 48.0

	var unit_box := BoxMesh.new()
	unit_box.size = Vector3.ONE
	var building_multi := MultiMesh.new()
	building_multi.transform_format = MultiMesh.TRANSFORM_3D
	building_multi.use_colors = true
	building_multi.mesh = unit_box
	building_multi.instance_count = building_transforms.size()
	for i in range(building_transforms.size()):
		building_multi.set_instance_transform(i, building_transforms[i])
		building_multi.set_instance_color(i, building_colors[i])
	var buildings := MultiMeshInstance3D.new()
	buildings.name = "ProceduralCityBlocks"
	buildings.multimesh = building_multi
	var building_material := StandardMaterial3D.new()
	building_material.vertex_color_use_as_albedo = true
	building_material.roughness = 0.91
	building_material.metallic = 0.04
	buildings.material_override = building_material
	add_child(buildings)

	var window_multi := MultiMesh.new()
	window_multi.transform_format = MultiMesh.TRANSFORM_3D
	window_multi.mesh = unit_box
	window_multi.instance_count = window_transforms.size()
	for i in range(window_transforms.size()):
		window_multi.set_instance_transform(i, window_transforms[i])
	var windows := MultiMeshInstance3D.new()
	windows.name = "FacadeGlassBands"
	windows.multimesh = window_multi
	windows.material_override = _make_material(Color(0.075, 0.12, 0.17), 0.31, 0.32)
	add_child(windows)

func _build_player() -> void:
	_car = RigidBody3D.new()
	_car.name = "PlayerCar"
	_car.set_script(CarControllerScript)
	_car.position = Vector3(2.5, 0.36, 0.0)

	var chassis_collision := CollisionShape3D.new()
	var chassis_shape := BoxShape3D.new()
	chassis_shape.size = Vector3(1.74, 0.36, 3.8)
	chassis_collision.shape = chassis_shape
	chassis_collision.position = Vector3(0.0, 0.04, 0.0)
	_car.add_child(chassis_collision)

	var paint := _make_material(Color(0.025, 0.16, 0.62), 0.22, 0.76)
	var paint_highlight := _make_material(Color(0.045, 0.26, 0.86), 0.25, 0.68)
	var glass := _make_material(Color(0.025, 0.055, 0.075), 0.18, 0.35)
	var rubber := _make_material(Color(0.018, 0.022, 0.027), 0.88, 0.0)
	var alloy := _make_material(Color(0.58, 0.64, 0.69), 0.28, 0.82)
	var headlamp := _make_material(Color(0.93, 0.91, 0.79), 0.22, 0.15)
	headlamp.emission_enabled = true
	headlamp.emission = Color(0.75, 0.73, 0.60)
	var taillamp := _make_material(Color(0.78, 0.025, 0.035), 0.24, 0.12)
	taillamp.emission_enabled = true
	taillamp.emission = Color(0.45, 0.012, 0.018)

	_add_box(_car, "MainBody", Vector3(1.92, 0.43, 4.15), Vector3(0.0, 0.02, 0.0), paint)
	_add_box(_car, "FrontHood", Vector3(1.76, 0.17, 1.10), Vector3(0.0, 0.24, -1.28), paint_highlight, Vector3(deg_to_rad(-2.0), 0.0, 0.0))
	_add_box(_car, "RearDeck", Vector3(1.72, 0.16, 0.72), Vector3(0.0, 0.22, 1.48), paint_highlight)
	_add_box(_car, "CabinGlass", Vector3(1.39, 0.40, 1.78), Vector3(0.0, 0.40, 0.20), glass, Vector3(deg_to_rad(-3.0), 0.0, 0.0))
	_add_box(_car, "Roof", Vector3(1.20, 0.11, 0.82), Vector3(0.0, 0.64, 0.28), paint)
	_add_box(_car, "FrontBumper", Vector3(1.82, 0.13, 0.16), Vector3(0.0, -0.12, -2.08), paint)
	_add_box(_car, "RearBumper", Vector3(1.82, 0.13, 0.16), Vector3(0.0, -0.12, 2.08), paint)
	_add_box(_car, "FrontSplitter", Vector3(1.76, 0.055, 0.20), Vector3(0.0, -0.18, -2.12), _make_material(Color(0.025, 0.03, 0.04), 0.7))
	_add_box(_car, "RearDiffuser", Vector3(1.55, 0.07, 0.18), Vector3(0.0, -0.18, 2.11), _make_material(Color(0.025, 0.03, 0.04), 0.7))

	for side in [-1.0, 1.0]:
		_add_box(_car, "SideSkirt", Vector3(0.12, 0.15, 2.55), Vector3(side * 0.92, -0.12, 0.05), paint)
		_add_box(_car, "Headlight", Vector3(0.42, 0.065, 0.08), Vector3(side * 0.62, 0.06, -2.09), headlamp)
		_add_box(_car, "TailLight", Vector3(0.40, 0.09, 0.08), Vector3(side * 0.62, 0.06, 2.09), taillamp)
		_add_box(_car, "SideGlass", Vector3(0.035, 0.22, 1.20), Vector3(side * 0.704, 0.42, 0.20), glass)

	var wheel_pivots: Array[Node3D] = []
	var front_wheels: Array[Node3D] = []
	for x in [-0.94, 0.94]:
		for wheel_z in [-1.27, 1.27]:
			var wheel_collision := CollisionShape3D.new()
			var wheel_shape := CylinderShape3D.new()
			wheel_shape.radius = 0.34
			wheel_shape.height = 0.25
			wheel_collision.shape = wheel_shape
			wheel_collision.position = Vector3(x, 0.0, wheel_z)
			wheel_collision.rotation.z = PI * 0.5
			_car.add_child(wheel_collision)

			var wheel_pivot := Node3D.new()
			wheel_pivot.name = "WheelPivot"
			wheel_pivot.position = Vector3(x, 0.0, wheel_z)
			_car.add_child(wheel_pivot)

			var tire_mesh := CylinderMesh.new()
			tire_mesh.top_radius = 0.34
			tire_mesh.bottom_radius = 0.34
			tire_mesh.height = 0.25
			tire_mesh.radial_segments = 20
			var tire := MeshInstance3D.new()
			tire.name = "Tire"
			tire.mesh = tire_mesh
			tire.rotation.z = PI * 0.5
			tire.material_override = rubber
			wheel_pivot.add_child(tire)

			var hub_mesh := CylinderMesh.new()
			hub_mesh.top_radius = 0.16
			hub_mesh.bottom_radius = 0.16
			hub_mesh.height = 0.035
			hub_mesh.radial_segments = 16
			var hub := MeshInstance3D.new()
			hub.name = "AlloyHub"
			hub.mesh = hub_mesh
			hub.rotation.z = PI * 0.5
			hub.position.x = 0.135 if x > 0.0 else -0.135
			hub.material_override = alloy
			wheel_pivot.add_child(hub)

			wheel_pivots.append(wheel_pivot)
			if wheel_z < 0.0:
				front_wheels.append(wheel_pivot)

	add_child(_car)
	_car.call("set_wheel_visuals", wheel_pivots, front_wheels)

	var chase_camera := Camera3D.new()
	chase_camera.name = "ChaseCamera"
	chase_camera.set_script(ChaseCameraScript)
	add_child(chase_camera)
	chase_camera.set("target", _car)
	chase_camera.current = true
	chase_camera.global_position = _car.global_position + Vector3(0.0, 3.0, 8.0)

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "RaceHUD"
	canvas.layer = 5
	add_child(canvas)

	var root := Control.new()
	root.name = "Overlay"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	var title := Label.new()
	title.text = "STREETLINE  /  OPEN ROAD"
	title.position = Vector2(30.0, 22.0)
	title.size = Vector2(430.0, 34.0)
	title.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.65))
	title.add_theme_constant_override("shadow_offset_x", 1)
	title.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "PROTOTYPE 01   /   DAYLIGHT HIGHWAY"
	subtitle.position = Vector2(32.0, 56.0)
	subtitle.size = Vector2(430.0, 24.0)
	subtitle.add_theme_color_override("font_color", Color(0.62, 0.78, 0.89))
	subtitle.add_theme_font_size_override("font_size", 13)
	root.add_child(subtitle)

	_distance_label = Label.new()
	_distance_label.text = "DISTANCE  /  00000 M"
	_distance_label.position = Vector2(32.0, 84.0)
	_distance_label.size = Vector2(300.0, 24.0)
	_distance_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.93))
	_distance_label.add_theme_font_size_override("font_size", 14)
	root.add_child(_distance_label)

	_speed_label = Label.new()
	_speed_label.text = "000"
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speed_label.anchor_left = 1.0
	_speed_label.anchor_right = 1.0
	_speed_label.anchor_top = 1.0
	_speed_label.anchor_bottom = 1.0
	_speed_label.offset_left = -405.0
	_speed_label.offset_right = -255.0
	_speed_label.offset_top = -154.0
	_speed_label.offset_bottom = -88.0
	_speed_label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0))
	_speed_label.add_theme_font_size_override("font_size", 58)
	root.add_child(_speed_label)

	var speed_unit := Label.new()
	speed_unit.text = "KM/H"
	speed_unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_unit.anchor_left = 1.0
	speed_unit.anchor_right = 1.0
	speed_unit.anchor_top = 1.0
	speed_unit.anchor_bottom = 1.0
	speed_unit.offset_left = -325.0
	speed_unit.offset_right = -255.0
	speed_unit.offset_top = -91.0
	speed_unit.offset_bottom = -65.0
	speed_unit.add_theme_color_override("font_color", Color(0.62, 0.78, 0.89))
	speed_unit.add_theme_font_size_override("font_size", 14)
	root.add_child(speed_unit)

	_nitro_label = Label.new()
	_nitro_label.text = "NITRO  /  READY"
	_nitro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_nitro_label.anchor_left = 1.0
	_nitro_label.anchor_right = 1.0
	_nitro_label.anchor_top = 1.0
	_nitro_label.anchor_bottom = 1.0
	_nitro_label.offset_left = -405.0
	_nitro_label.offset_right = -255.0
	_nitro_label.offset_top = -228.0
	_nitro_label.offset_bottom = -207.0
	_nitro_label.add_theme_color_override("font_color", Color(0.73, 0.86, 0.95))
	_nitro_label.add_theme_font_size_override("font_size", 13)
	root.add_child(_nitro_label)

	_nitro_bar = ProgressBar.new()
	_nitro_bar.min_value = 0.0
	_nitro_bar.max_value = 100.0
	_nitro_bar.value = 100.0
	_nitro_bar.show_percentage = false
	_nitro_bar.anchor_left = 1.0
	_nitro_bar.anchor_right = 1.0
	_nitro_bar.anchor_top = 1.0
	_nitro_bar.anchor_bottom = 1.0
	_nitro_bar.offset_left = -405.0
	_nitro_bar.offset_right = -255.0
	_nitro_bar.offset_top = -204.0
	_nitro_bar.offset_bottom = -190.0
	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color(0.03, 0.06, 0.09, 0.78)
	bar_background.set_corner_radius_all(3)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.12, 0.68, 0.94, 0.96)
	bar_fill.set_corner_radius_all(3)
	_nitro_bar.add_theme_stylebox_override("background", bar_background)
	_nitro_bar.add_theme_stylebox_override("fill", bar_fill)
	root.add_child(_nitro_bar)

	_make_touch_button(root, "‹", "steer_left", "left", 28.0, 32.0, 78.0, 72.0, 29)
	_make_touch_button(root, "›", "steer_right", "left", 118.0, 32.0, 78.0, 72.0, 29)
	_make_touch_button(root, "BRAKE", "brake", "right", 142.0, 32.0, 88.0, 72.0, 14)
	_make_touch_button(root, "GAS", "accelerate", "right", 32.0, 32.0, 92.0, 72.0, 19)
	_make_touch_button(root, "NITRO", "nitro", "right", 32.0, 118.0, 92.0, 48.0, 13)

	_input_debug_label = Label.new()
	_input_debug_label.name = "TouchInputDiagnostic"
	_input_debug_label.text = _touch_debug_message
	_input_debug_label.position = Vector2(32.0, 116.0)
	_input_debug_label.size = Vector2(420.0, 22.0)
	_input_debug_label.add_theme_color_override("font_color", Color(0.55, 0.78, 0.86))
	_input_debug_label.add_theme_font_size_override("font_size", 11)
	root.add_child(_input_debug_label)

func _make_touch_button(parent: Control, label_text: String, action: String, side: String, offset_x: float, bottom: float, width: float, height: float, font_size: int) -> void:
	# Buttons are visual-only. Raw screen-touch events are handled by _input().
	var button := Button.new()
	button.text = label_text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.025, 0.055, 0.085, 0.72), Color(0.43, 0.65, 0.76, 0.76)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.055, 0.16, 0.22, 0.9), Color(0.54, 0.83, 0.95, 0.95)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.08, 0.35, 0.48, 0.94), Color(0.64, 0.9, 1.0, 1.0)))

	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	if side == "right":
		button.anchor_left = 1.0
		button.anchor_right = 1.0
		button.offset_left = -(offset_x + width)
		button.offset_right = -offset_x
	else:
		button.anchor_left = 0.0
		button.anchor_right = 0.0
		button.offset_left = offset_x
		button.offset_right = offset_x + width
	button.offset_top = -(bottom + height)
	button.offset_bottom = -bottom
	parent.add_child(button)

	_touch_hitboxes.append({"visual": button, "action": action})

func _action_at_screen_position(screen_position: Vector2) -> String:
	# Use the same Control rectangles used for drawing, expanded by 12 px per side.
	for item in _touch_hitboxes:
		var visual := item["visual"] as Control
		if not is_instance_valid(visual):
			continue
		var hit_rect := visual.get_global_rect()
		hit_rect.position -= Vector2(12.0, 12.0)
		hit_rect.size += Vector2(24.0, 24.0)
		if hit_rect.has_point(screen_position):
			return String(item["action"])
	return ""

func _is_touch_action_pressed(action: String) -> bool:
	for active_action in _active_touch_actions.values():
		if String(active_action) == action:
			return true
	return false

func _is_action_pressed(action: String) -> bool:
	return Input.is_action_pressed(action) or _is_touch_action_pressed(action)

func _get_action_strength(action: String) -> float:
	return maxf(Input.get_action_strength(action), 1.0 if _is_touch_action_pressed(action) else 0.0)

func _refresh_touch_visuals() -> void:
	for item in _touch_hitboxes:
		var visual := item["visual"] as Button
		if is_instance_valid(visual):
			var pressed := _is_touch_action_pressed(String(item["action"]))
			if pressed:
				visual.add_theme_stylebox_override("normal", _button_style(Color(0.08, 0.35, 0.48, 0.94), Color(0.64, 0.9, 1.0, 1.0)))
			else:
				visual.add_theme_stylebox_override("normal", _button_style(Color(0.025, 0.055, 0.085, 0.72), Color(0.43, 0.65, 0.76, 0.76)))
	if is_instance_valid(_input_debug_label):
		var active_names: Array[String] = []
		for active_action in _active_touch_actions.values():
			var active_name := String(active_action).to_upper()
			if not active_names.has(active_name):
				active_names.append(active_name)
		_input_debug_label.text = "TOUCH INPUT / " + ", ".join(active_names) if not active_names.is_empty() else _touch_debug_message

func _ensure_input_actions() -> void:
	var bindings: Dictionary = {
		"accelerate": [KEY_W, KEY_UP],
		"brake": [KEY_S, KEY_DOWN, KEY_SPACE],
		"steer_left": [KEY_A, KEY_LEFT],
		"steer_right": [KEY_D, KEY_RIGHT],
		"nitro": [KEY_SHIFT],
	}
	for action_name in bindings:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		for keycode in bindings[action_name]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			if not InputMap.action_has_event(action_name, event):
				InputMap.action_add_event(action_name, event)

func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style

func _add_box(parent: Node3D, node_name: String, box_size: Vector3, local_position: Vector3, material: Material, local_rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = box_size
	mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = local_position
	mesh_instance.rotation = local_rotation
	parent.add_child(mesh_instance)
	return mesh_instance

func _make_material(color: Color, roughness: float = 0.78, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
