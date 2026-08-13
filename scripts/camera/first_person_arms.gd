class_name FirstPersonArms
extends Node3D

var _left_arm: Node3D
var _right_arm: Node3D
var _movement_speed: float = 0.0
var _movement_phase: float = 0.0
var _rest_position: Vector3 = Vector3(0.0, -0.58, -0.88)


func setup(unit: TacticalUnit) -> void:
	_build_viewmodel(unit.get_first_person_skin_color(), unit.character_id == &"ogre")


func set_movement(speed: float, phase: float) -> void:
	_movement_speed = speed
	_movement_phase = phase


func _process(delta: float) -> void:
	var movement_weight: float = clampf(_movement_speed / 4.5, 0.0, 1.0)
	var idle_time: float = float(Time.get_ticks_msec()) * 0.001
	var breathing: float = sin(idle_time * 1.65) * 0.008
	var step_lift: float = absf(sin(_movement_phase)) * 0.035 * movement_weight
	position = position.lerp(
		_rest_position + Vector3(0.0, breathing + step_lift, 0.0),
		minf(1.0, delta * 10.0)
	)
	if _left_arm != null:
		_left_arm.rotation.z = deg_to_rad(-7.0) + sin(_movement_phase) * 0.055 * movement_weight
	if _right_arm != null:
		_right_arm.rotation.z = deg_to_rad(7.0) - sin(_movement_phase) * 0.055 * movement_weight


func _build_viewmodel(skin_color: Color, massive: bool) -> void:
	position = _rest_position
	_left_arm = _create_arm("LeftArm", -1.0, skin_color, massive)
	_right_arm = _create_arm("RightArm", 1.0, skin_color, massive)
	add_child(_left_arm)
	add_child(_right_arm)


func _create_arm(node_name: String, side: float, skin_color: Color, massive: bool) -> Node3D:
	var arm := Node3D.new()
	arm.name = node_name
	var width: float = 0.135 if massive else 0.095
	arm.position = Vector3(side * (0.37 if massive else 0.31), 0.0, 0.0)
	arm.rotation = Vector3(deg_to_rad(-58.0), side * deg_to_rad(-7.0), side * deg_to_rad(7.0))

	var forearm_mesh := CapsuleMesh.new()
	forearm_mesh.radius = width
	forearm_mesh.height = 0.62 if massive else 0.52
	forearm_mesh.radial_segments = 16
	forearm_mesh.rings = 6
	var forearm := MeshInstance3D.new()
	forearm.name = "Forearm"
	forearm.mesh = forearm_mesh
	forearm.material_override = _make_material(skin_color.darkened(0.08))
	arm.add_child(forearm)

	var wrist_mesh := CylinderMesh.new()
	wrist_mesh.top_radius = width * 1.12
	wrist_mesh.bottom_radius = width * 1.18
	wrist_mesh.height = 0.13
	wrist_mesh.radial_segments = 16
	var wrist := MeshInstance3D.new()
	wrist.name = "LeatherWristband"
	wrist.position.y = 0.25
	wrist.mesh = wrist_mesh
	wrist.material_override = _make_material(Color(0.16, 0.09, 0.045))
	arm.add_child(wrist)

	var hand_mesh := SphereMesh.new()
	hand_mesh.radius = width * 1.24
	hand_mesh.height = width * 2.15
	hand_mesh.radial_segments = 16
	hand_mesh.rings = 8
	var hand := MeshInstance3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0.0, 0.35, -0.035)
	hand.scale = Vector3(1.08, 0.82, 1.2)
	hand.mesh = hand_mesh
	hand.material_override = _make_material(skin_color)
	arm.add_child(hand)
	return arm


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	material.metallic = 0.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.render_priority = 10
	return material
