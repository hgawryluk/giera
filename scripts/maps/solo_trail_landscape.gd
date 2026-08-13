class_name SoloTrailLandscape
extends Node3D

const ROCK_SCENES: Array[PackedScene] = [
	preload("res://assets/environment/kyles_rock_pack/Kyle Fuji/Models/boulder_1_bl.glb"),
	preload("res://assets/environment/kyles_rock_pack/Kyle Fuji/Models/boulder_3_tr.glb"),
	preload("res://assets/environment/kyles_rock_pack/Kyle Fuji/Models/boulder_5_br.glb"),
	preload("res://assets/environment/kyles_rock_pack/Kyle Fuji/Models/boulder_7_tl.glb"),
	preload("res://assets/environment/kyles_rock_pack/Kyle Fuji/Models/boulder_8_bl.glb"),
]
const ROCK_TEXTURE: Texture2D = preload("res://assets/textures/terrain/rock_stone_albedo.jpg")

var _grid_manager: GridManager
var _rock_material: StandardMaterial3D


func setup(grid_manager: GridManager) -> void:
	_grid_manager = grid_manager
	_rock_material = _create_rock_material()
	_create_river()
	_scatter_rocks()


func _create_river() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	const STEP := 4.0
	const HALF_WIDTH := 4.2
	for index: int in range(64):
		var x0 := float(index) * STEP
		var x1 := float(index + 1) * STEP
		var z0 := _river_center(x0)
		var z1 := _river_center(x1)
		_append_water_vertex(vertices, normals, uvs, Vector3(x0, -2.15, z0 - HALF_WIDTH), Vector2(x0 / 16.0, 0.0))
		_append_water_vertex(vertices, normals, uvs, Vector3(x1, -2.15, z1 - HALF_WIDTH), Vector2(x1 / 16.0, 0.0))
		_append_water_vertex(vertices, normals, uvs, Vector3(x1, -2.15, z1 + HALF_WIDTH), Vector2(x1 / 16.0, 1.0))
		_append_water_vertex(vertices, normals, uvs, Vector3(x0, -2.15, z0 - HALF_WIDTH), Vector2(x0 / 16.0, 0.0))
		_append_water_vertex(vertices, normals, uvs, Vector3(x1, -2.15, z1 + HALF_WIDTH), Vector2(x1 / 16.0, 1.0))
		_append_water_vertex(vertices, normals, uvs, Vector3(x0, -2.15, z0 + HALF_WIDTH), Vector2(x0 / 16.0, 1.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var river := MeshInstance3D.new()
	river.name = "MountainRiver"
	river.mesh = mesh
	river.material_override = _create_water_material()
	river.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(river)


func _append_water_vertex(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, point: Vector3, uv: Vector2) -> void:
	vertices.append(point)
	normals.append(Vector3.UP)
	uvs.append(uv)


func _scatter_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9_714_203
	var placed: int = 0
	var attempts: int = 0
	while placed < 92 and attempts < 900:
		attempts += 1
		var x := rng.randf_range(7.0, 249.0)
		var z := rng.randf_range(7.0, 249.0)
		var point := Vector2(x, z)
		if point.distance_to(Vector2(130.0, 150.0)) < 26.0:
			continue
		var river_distance := absf(z - _river_center(x))
		var height := _grid_manager.terrain_height(x, z)
		var slope := _estimate_slope(x, z)
		var ravine_distance := absf(x - (72.0 + sin(z * 0.052) * 5.0))
		var suitable := slope > 0.22 or height > 14.0 or river_distance < 12.0 or (z > 112.0 and ravine_distance < 11.0)
		if not suitable or river_distance < 4.8:
			continue
		var rock := ROCK_SCENES[rng.randi_range(0, ROCK_SCENES.size() - 1)].instantiate() as Node3D
		rock.name = "Rock_%03d" % placed
		rock.position = Vector3(x, height - rng.randf_range(0.03, 0.22), z)
		rock.rotation = Vector3(rng.randf_range(-0.10, 0.10), rng.randf_range(0.0, TAU), rng.randf_range(-0.08, 0.08))
		var scale_value := rng.randf_range(0.55, 1.65)
		if height > 18.0 or slope > 0.48:
			scale_value *= rng.randf_range(1.4, 2.6)
		rock.scale = Vector3(scale_value, scale_value * rng.randf_range(0.75, 1.25), scale_value)
		_apply_rock_material(rock)
		add_child(rock)
		placed += 1


func _estimate_slope(x: float, z: float) -> float:
	var dx := _grid_manager.terrain_height(x + 1.0, z) - _grid_manager.terrain_height(x - 1.0, z)
	var dz := _grid_manager.terrain_height(x, z + 1.0) - _grid_manager.terrain_height(x, z - 1.0)
	return Vector2(dx, dz).length() * 0.5


func _apply_rock_material(root: Node) -> void:
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		mesh_instance.material_override = _rock_material
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _create_rock_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = ROCK_TEXTURE
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_scale = Vector3(1.8, 1.8, 1.8)
	material.albedo_color = Color(0.78, 0.76, 0.71)
	material.roughness = 0.88
	return material


func _create_water_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.08, 0.34, 0.52, 0.78)
	material.metallic = 0.18
	material.roughness = 0.16
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _river_center(x: float) -> float:
	return 101.0 + sin(x * 0.045) * 11.0 + sin(x * 0.013 + 1.7) * 5.0
