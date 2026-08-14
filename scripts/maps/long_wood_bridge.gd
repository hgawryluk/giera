class_name LongWoodBridge
extends Node3D

const BRIDGE_SCENE: PackedScene = preload("res://assets/environment/bridges/long_wood_bridge/source/Long Wood Bridge.fbx")
const WOOD_ALBEDO: Texture2D = preload("res://assets/environment/bridges/long_wood_bridge/textures/BridgeWood.jpg")
const WOOD_NORMAL: Texture2D = preload("res://assets/environment/bridges/long_wood_bridge/textures/BridgeWood_Normal.jpg")
const WOOD_SPECULAR: Texture2D = preload("res://assets/environment/bridges/long_wood_bridge/textures/BridgeWood_Specular.jpg")
const WATER_LEVEL: float = -1.7
const TARGET_LENGTH: float = 25.0
const TARGET_WIDTH: float = 5.2
const DECK_COLLISION_THICKNESS: float = 0.42
const DECK_SURFACE_Y: float = 0.08

var _grid_manager: GridManager


func setup(grid_manager: GridManager) -> void:
	_grid_manager = grid_manager
	_build_bridge()


func _build_bridge() -> void:
	var model := BRIDGE_SCENE.instantiate() as Node3D
	model.name = "LongWoodBridgeModel"
	add_child(model)
	var bounds := _combined_mesh_bounds(model)
	if bounds.size.length_squared() < 0.001:
		push_warning("Long wood bridge has no renderable mesh bounds.")
		return
	_apply_wood_material(model)
	var long_axis_is_x := bounds.size.x >= bounds.size.z
	var source_length := maxf(bounds.size.x if long_axis_is_x else bounds.size.z, 0.01)
	var source_width := maxf(bounds.size.z if long_axis_is_x else bounds.size.x, 0.01)
	var uniform_height_scale := TARGET_LENGTH / source_length
	var model_scale := Vector3.ONE * uniform_height_scale
	if long_axis_is_x:
		model_scale.z = TARGET_WIDTH / source_width
	else:
		model_scale.x = TARGET_WIDTH / source_width
	model.scale = model_scale

	var crossing_z := _find_path_river_crossing()
	var crossing_x := _grid_manager.solo_trail_path_center_x(crossing_z)
	var before := Vector2(_grid_manager.solo_trail_path_center_x(crossing_z - 2.0), crossing_z - 2.0)
	var after := Vector2(_grid_manager.solo_trail_path_center_x(crossing_z + 2.0), crossing_z + 2.0)
	var direction := (after - before).normalized()
	rotation.y = atan2(-direction.y, direction.x) if long_axis_is_x else atan2(direction.x, direction.y)
	var endpoint_a := Vector2(crossing_x, crossing_z) - direction * TARGET_LENGTH * 0.47
	var endpoint_b := Vector2(crossing_x, crossing_z) + direction * TARGET_LENGTH * 0.47
	var deck_y := maxf(WATER_LEVEL + 2.15, maxf(
		_grid_manager.terrain_height(endpoint_a.x, endpoint_a.y),
		_grid_manager.terrain_height(endpoint_b.x, endpoint_b.y)
	) + 0.18)
	position = Vector3(crossing_x, deck_y, crossing_z)
	# Center the imported geometry horizontally and put its upper walking
	# surface at the same height as the physical bridge deck.
	var scaled_center := (bounds.position + bounds.size * 0.5) * model_scale
	var scaled_top := (bounds.position.y + bounds.size.y) * model_scale.y
	model.position = Vector3(-scaled_center.x, -scaled_top + 0.08, -scaled_center.z)
	_build_collision(long_axis_is_x)


func _find_path_river_crossing() -> float:
	var best_z := 101.0
	var best_error := INF
	for step: int in range(241):
		var z := 70.0 + float(step) * 0.25
		var x := _grid_manager.solo_trail_path_center_x(z)
		var river_z := 101.0 + sin(x * 0.045) * 11.0 + sin(x * 0.013 + 1.7) * 5.0
		var error := absf(z - river_z)
		if error < best_error:
			best_error = error
			best_z = z
	return best_z


func _build_collision(long_axis_is_x: bool) -> void:
	var body := StaticBody3D.new()
	body.name = "BridgeCollision"
	var shape_node := CollisionShape3D.new()
	shape_node.name = "WalkableDeck"
	var shape := BoxShape3D.new()
	# The FBX can be authored with either X or Z as its longitudinal axis.
	# Keep the physical deck on the same local axis as the scaled model so the
	# parent yaw aligns both of them with the north/south trail.
	shape.size = Vector3(
		TARGET_LENGTH if long_axis_is_x else TARGET_WIDTH,
		DECK_COLLISION_THICKNESS,
		TARGET_WIDTH if long_axis_is_x else TARGET_LENGTH
	)
	shape_node.shape = shape
	shape_node.position.y = DECK_SURFACE_Y - DECK_COLLISION_THICKNESS * 0.5
	body.add_child(shape_node)
	add_child(body)


func _combined_mesh_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var local_transform := root.global_transform.affine_inverse() * mesh_node.global_transform
		var transformed := local_transform * mesh_node.mesh.get_aabb()
		result = transformed if not initialized else result.merge(transformed)
		initialized = true
	return result


func _apply_wood_material(root: Node3D) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_texture = WOOD_ALBEDO
	material.normal_enabled = true
	material.normal_texture = WOOD_NORMAL
	material.roughness_texture = WOOD_SPECULAR
	material.roughness = 0.78
	material.metallic = 0.0
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = material
