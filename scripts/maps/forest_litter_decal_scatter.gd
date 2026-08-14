class_name ForestLitterDecalScatter
extends MultiMeshInstance3D

const LITTER_ATLAS: Texture2D = preload("res://assets/environment/terrain/forest_litter/forest_litter_atlas.png")
const LITTER_SHADER: Shader = preload("res://world/terrain/shaders/forest_litter_decal.gdshader")
const WATER_LEVEL: float = -1.7

var _grid_manager: GridManager


func setup(grid_manager: GridManager, world_bounds: Rect2, instance_target: int, seed_value: int) -> void:
	_grid_manager = grid_manager
	var transforms: Array[Transform3D] = []
	var variants := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var attempts := 0
	while transforms.size() < instance_target and attempts < instance_target * 10:
		attempts += 1
		var x := rng.randf_range(world_bounds.position.x, world_bounds.end.x)
		var z := rng.randf_range(world_bounds.position.y, world_bounds.end.y)
		var height := _grid_manager.terrain_height(x, z)
		if height <= WATER_LEVEL + 0.18 or _slope(x, z) > 0.25:
			continue
		var trail_distance := _grid_manager.solo_trail_path_distance(x, z)
		if trail_distance < 6.2:
			continue
		var forest_field := _forest_field(x, z)
		var acceptance := lerpf(0.025, 0.74, smoothstep(0.38, 0.73, forest_field))
		# Sparse isolated meadow patches, never a uniform leaf carpet.
		acceptance += 0.10 * smoothstep(0.88, 0.97, _noise(x, z, 0.047, 19.0))
		if rng.randf() > acceptance:
			continue
		var size := rng.randf_range(2.2, 5.8) * lerpf(0.78, 1.18, forest_field)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(size, 1.0, size * rng.randf_range(0.78, 1.22)))
		var local_position := Vector3(x, height + 0.035, z) - global_position
		transforms.append(Transform3D(basis, local_position))
		variants.append(rng.randi_range(0, 15))
	_build_multimesh(transforms, variants)


func _build_multimesh(transforms: Array[Transform3D], variants: PackedInt32Array) -> void:
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	quad.size = Vector2.ONE
	var material := ShaderMaterial.new()
	material.shader = LITTER_SHADER
	material.set_shader_parameter("litter_atlas", LITTER_ATLAS)
	quad.material = material
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_custom_data = true
	batch.mesh = quad
	batch.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		batch.set_instance_transform(index, transforms[index])
		batch.set_instance_custom_data(index, Color(float(variants[index]) / 15.0, 0.0, 0.0, 1.0))
	multimesh = batch
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = 190.0
	visibility_range_end_margin = 28.0
	visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _forest_field(x: float, z: float) -> float:
	return _noise(x, z, 0.0105, 4.0) * 0.58 + _noise(x, z, 0.023, 31.0) * 0.42


func _noise(x: float, z: float, scale_value: float, phase: float) -> float:
	var value := sin(x * scale_value * 1.17 + z * scale_value * 0.43 + phase) * 0.50
	value += cos(z * scale_value * 1.31 - x * scale_value * 0.37 + phase * 0.73) * 0.31
	value += sin((x + z) * scale_value * 0.71 - phase * 0.41) * 0.19
	return value * 0.5 + 0.5


func _slope(x: float, z: float) -> float:
	var dx := _grid_manager.terrain_height(x - 0.5, z) - _grid_manager.terrain_height(x + 0.5, z)
	var dz := _grid_manager.terrain_height(x, z - 0.5) - _grid_manager.terrain_height(x, z + 0.5)
	return Vector2(dx, dz).length()
