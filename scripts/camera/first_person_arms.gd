class_name FirstPersonArms
extends Node3D

const ARM_BONE_FRAGMENTS: Array[String] = ["Shoulder", "Arm", "ForeArm", "Hand"]

var _model: Node3D
var _animation_player: AnimationPlayer
var _movement_speed: float = 0.0
var _movement_phase: float = 0.0
var _rest_position := Vector3(0.0, 0.0, 0.10)


func setup(unit: TacticalUnit) -> void:
	_model = unit.create_first_person_visual()
	if _model == null:
		return
	add_child(_model)
	_model.position = Vector3(0.0, -unit.get_first_person_eye_height(), 0.10)
	_filter_model_to_real_arms(_model)
	_animation_player = _find_animation_player(_model)
	if _animation_player != null:
		var animation_name := _first_animation(_animation_player)
		if not animation_name.is_empty():
			_animation_player.play(animation_name)
			_animation_player.speed_scale = 0.18
	position = _rest_position


func set_movement(speed: float, phase: float) -> void:
	_movement_speed = speed
	_movement_phase = phase
	if _animation_player != null:
		_animation_player.speed_scale = lerpf(0.18, 0.85, clampf(speed / 6.0, 0.0, 1.0))


func _process(delta: float) -> void:
	var movement_weight := clampf(_movement_speed / 4.5, 0.0, 1.0)
	var breathing := sin(float(Time.get_ticks_msec()) * 0.00165) * 0.006
	var step := absf(sin(_movement_phase)) * 0.022 * movement_weight
	position = position.lerp(_rest_position + Vector3(0.0, breathing + step, 0.0), minf(1.0, delta * 10.0))


func _filter_model_to_real_arms(root: Node) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or mesh_instance.skin == null:
			mesh_instance.visible = false
			continue
		var arm_binds := _arm_bind_indices(mesh_instance.skin)
		var filtered := _filter_skinned_mesh(mesh_instance.mesh, arm_binds)
		if filtered.get_surface_count() == 0:
			mesh_instance.visible = false
		else:
			mesh_instance.mesh = filtered
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh_instance.extra_cull_margin = 4.0


func _arm_bind_indices(skin: Skin) -> Dictionary:
	var result: Dictionary = {}
	for bind_index: int in range(skin.get_bind_count()):
		var bone_name := str(skin.get_bind_name(bind_index))
		for fragment: String in ARM_BONE_FRAGMENTS:
			if bone_name.contains(fragment):
				result[bind_index] = true
				break
	return result


func _filter_skinned_mesh(source: Mesh, arm_binds: Dictionary) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface_index: int in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var bones := arrays[Mesh.ARRAY_BONES] as PackedInt32Array
		var weights := arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
		if vertices.is_empty() or bones.is_empty() or weights.is_empty():
			continue
		var source_indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		if source_indices.is_empty():
			source_indices.resize(vertices.size())
			for index: int in range(vertices.size()):
				source_indices[index] = index
		var influences_per_vertex := bones.size() / vertices.size()
		var filtered_indices := PackedInt32Array()
		for triangle_start: int in range(0, source_indices.size() - 2, 3):
			var arm_vertices := 0
			for corner: int in range(3):
				var vertex_index := source_indices[triangle_start + corner]
				var arm_weight := 0.0
				for influence: int in range(influences_per_vertex):
					var influence_index := vertex_index * influences_per_vertex + influence
					if arm_binds.has(bones[influence_index]):
						arm_weight += weights[influence_index]
				if arm_weight >= 0.38:
					arm_vertices += 1
			if arm_vertices >= 2:
				filtered_indices.append(source_indices[triangle_start])
				filtered_indices.append(source_indices[triangle_start + 1])
				filtered_indices.append(source_indices[triangle_start + 2])
		if filtered_indices.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = filtered_indices
		result.add_surface_from_arrays(source.surface_get_primitive_type(surface_index), arrays)
		result.surface_set_material(result.get_surface_count() - 1, source.surface_get_material(surface_index))
	return result


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child: Node in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _first_animation(player: AnimationPlayer) -> StringName:
	for animation_name: StringName in player.get_animation_list():
		if animation_name != &"RESET":
			return animation_name
	return &""
