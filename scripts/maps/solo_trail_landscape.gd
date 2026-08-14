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
const TREE_DEFINITIONS: Array[Dictionary] = [
	{
		"obj": "res://assets/environment/tree_packs/tree/Tree/Tree.obj",
		"bark": "res://assets/environment/tree_packs/tree/Tree/bark_0021.jpg",
		"leaves": "res://assets/environment/tree_packs/tree/Tree/DB2X2_L01.png",
	},
	{
		"obj": "res://assets/environment/tree_packs/tree_02/Tree 02/Tree.obj",
		"bark": "res://assets/environment/tree_packs/tree_02/Tree 02/bark_0004.jpg",
		"leaves": "res://assets/environment/tree_packs/tree_02/Tree 02/DB2X2_L01.png",
	},
]
const TREE_COUNT: int = 100
const GIANT_TREE_COUNT: int = 3
const GRASS_INSTANCE_COUNT: int = 14500
const WATER_LEVEL: float = -1.7
const WATER_SHADER: Shader = preload("res://world/terrain/shaders/solo_trail_water.gdshader")
const GRASS_MESH: Mesh = preload("res://addons/simplegrasstextured/default_mesh.tres")
const GRASS_MATERIAL: ShaderMaterial = preload("res://addons/simplegrasstextured/materials/grass.tres")

var _grid_manager: GridManager
var _rock_material: StandardMaterial3D
var _tree_meshes: Array[ArrayMesh] = []


func setup(grid_manager: GridManager) -> void:
	_grid_manager = grid_manager
	add_to_group("solo_trail_landscape")
	_rock_material = _create_rock_material()
	_load_tree_meshes()
	_create_river()
	_scatter_grass_multimesh()
	_scatter_rocks()
	_scatter_tree_multimeshes()


func _create_river() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	const STEP := 2.0
	const HALF_WIDTH := 4.2
	for index: int in range(128):
		var x0 := float(index) * STEP
		var x1 := float(index + 1) * STEP
		var z0 := _river_center(x0)
		var z1 := _river_center(x1)
		_append_water_quad(vertices, normals, uvs, Vector3(x0, WATER_LEVEL, z0), Vector3(x1, WATER_LEVEL, z1), HALF_WIDTH, x0 / 16.0, x1 / 16.0)
	# The former dry ravine is now the river's flooded northern branch.
	const BRANCH_STEP := 2.0
	for index: int in range(59):
		var z0 := 112.0 + float(index) * BRANCH_STEP
		var z1 := z0 + BRANCH_STEP
		var x0 := _ravine_center(z0)
		var x1 := _ravine_center(z1)
		_append_water_quad(vertices, normals, uvs, Vector3(x0, WATER_LEVEL, z0), Vector3(x1, WATER_LEVEL, z1), 3.15, z0 / 16.0, z1 / 16.0)
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


func _append_water_quad(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, start: Vector3, finish: Vector3, half_width: float, uv_start: float, uv_finish: float) -> void:
	var sideways := Vector3(-(finish.z - start.z), 0.0, finish.x - start.x).normalized() * half_width
	_append_water_vertex(vertices, normals, uvs, start - sideways, Vector2(uv_start, 0.0))
	_append_water_vertex(vertices, normals, uvs, finish - sideways, Vector2(uv_finish, 0.0))
	_append_water_vertex(vertices, normals, uvs, finish + sideways, Vector2(uv_finish, 1.0))
	_append_water_vertex(vertices, normals, uvs, start - sideways, Vector2(uv_start, 0.0))
	_append_water_vertex(vertices, normals, uvs, finish + sideways, Vector2(uv_finish, 1.0))
	_append_water_vertex(vertices, normals, uvs, start + sideways, Vector2(uv_start, 1.0))


func _append_water_vertex(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, point: Vector3, uv: Vector2) -> void:
	vertices.append(point)
	normals.append(Vector3.UP)
	uvs.append(uv)


func _scatter_grass_multimesh() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6_601_419
	var transforms: Array[Transform3D] = []
	var attempts: int = 0
	while transforms.size() < GRASS_INSTANCE_COUNT and attempts < GRASS_INSTANCE_COUNT * 7:
		attempts += 1
		var x := rng.randf_range(4.0, 252.0)
		var z := rng.randf_range(4.0, 252.0)
		var height := _grid_manager.terrain_height(x, z)
		var slope := _estimate_slope(x, z)
		if height < 0.15 or height > 16.5 or slope > 0.28 or is_water_at(x, z):
			continue
		# Low-frequency fields form broad meadows, holes and isolated fringe blades.
		var broad := sin(x * 0.055) * 0.32 + cos(z * 0.047) * 0.30 + sin((x + z) * 0.021) * 0.38
		var fine := sin(x * 0.31 - z * 0.27) * 0.18
		var density := clampf(0.48 + broad + fine, 0.04, 0.96)
		if rng.randf() > density:
			continue
		var scale_y := rng.randf_range(0.62, 1.34) * lerpf(0.78, 1.12, density)
		var scale_xz := rng.randf_range(0.72, 1.22)
		var blade_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale_xz, scale_y, scale_xz))
		transforms.append(Transform3D(blade_basis, Vector3(x, height + 0.025, z)))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = GRASS_MESH
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var grass := MultiMeshInstance3D.new()
	grass.name = "SimpleGrassTextured_Meadows"
	grass.multimesh = multimesh
	grass.material_override = GRASS_MATERIAL.duplicate(true) as ShaderMaterial
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.visibility_range_end = 78.0
	grass.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(grass)


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
		var scale_value := rng.randf_range(0.55, 1.65)
		if height > 18.0 or slope > 0.48:
			scale_value *= rng.randf_range(1.4, 2.6)
		var vertical_scale := scale_value * rng.randf_range(0.75, 1.25)
		rock.scale = Vector3(scale_value, vertical_scale, scale_value)
		var terrain_normal := _terrain_normal(x, z)
		var yaw := rng.randf_range(0.0, TAU)
		rock.basis = _basis_aligned_to_normal(terrain_normal, yaw).scaled(rock.scale)
		# Boulders look grounded when their lower silhouette crosses the terrain.
		# The burial amount grows with size and slope, preventing downhill edges from floating.
		var burial := vertical_scale * (0.13 + clampf(slope, 0.0, 1.4) * 0.09)
		rock.position = Vector3(x, height - burial, z)
		_apply_rock_material(rock)
		add_child(rock)
		placed += 1


func _scatter_tree_multimeshes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4_810_273
	var transforms_by_variant: Array[Array] = [[], []]
	var accepted_points: Array[Vector2] = []
	var placed: int = 0
	var attempts: int = 0
	while placed < TREE_COUNT and attempts < 5000:
		attempts += 1
		var x := rng.randf_range(9.0, 247.0)
		var z := rng.randf_range(9.0, 247.0)
		var point := Vector2(x, z)
		var height := _grid_manager.terrain_height(x, z)
		var slope := _estimate_slope(x, z)
		var river_distance := absf(z - _river_center(x))
		var ravine_x := 72.0 + sin(z * 0.052) * 5.0
		if slope > 0.34 or height > 17.0 or height < 0.5:
			continue
		if river_distance < 13.0 or (z > 105.0 and z < 228.0 and absf(x - ravine_x) < 13.0):
			continue
		if point.distance_to(Vector2(130.0, 150.0)) < 34.0:
			continue
		if _is_too_close_to_tree(point, accepted_points, 4.6):
			continue
		var variant := rng.randi_range(0, _tree_meshes.size() - 1)
		var mesh_bounds := _tree_meshes[variant].get_aabb()
		var source_height := maxf(mesh_bounds.size.y, 0.01)
		var target_height := rng.randf_range(7.5, 12.5)
		if placed < GIANT_TREE_COUNT:
			target_height = 25.0
		var uniform_scale := target_height / source_height
		var width_variation := rng.randf_range(0.88, 1.14)
		var tree_scale := Vector3(uniform_scale * width_variation, uniform_scale, uniform_scale * width_variation)
		var yaw := rng.randf_range(0.0, TAU)
		var slight_tilt := rng.randf_range(-0.025, 0.025)
		var tree_basis := Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, slight_tilt)
		tree_basis = tree_basis.scaled(tree_scale)
		var root_burial := clampf(target_height * 0.012, 0.10, 0.28)
		var tree_transform := Transform3D(tree_basis, Vector3(x, height - root_burial, z))
		transforms_by_variant[variant].append(tree_transform)
		accepted_points.append(point)
		placed += 1
	for variant: int in range(_tree_meshes.size()):
		_create_tree_batch(variant, transforms_by_variant[variant])


func _create_tree_batch(variant: int, transforms: Array) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = false
	multimesh.use_custom_data = false
	multimesh.mesh = _tree_meshes[variant]
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index] as Transform3D)
	var batch := MultiMeshInstance3D.new()
	batch.name = "TreeMultiMesh_%d" % (variant + 1)
	batch.multimesh = multimesh
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	add_child(batch)


func _is_too_close_to_tree(point: Vector2, accepted_points: Array[Vector2], minimum_distance: float) -> bool:
	for accepted: Vector2 in accepted_points:
		if point.distance_squared_to(accepted) < minimum_distance * minimum_distance:
			return true
	return false


func _load_tree_meshes() -> void:
	_tree_meshes.clear()
	for definition: Dictionary in TREE_DEFINITIONS:
		_tree_meshes.append(_load_obj_mesh(definition))


func _load_obj_mesh(definition: Dictionary) -> ArrayMesh:
	var file := FileAccess.open(str(definition["obj"]), FileAccess.READ)
	var vertices: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var texcoords: Array[Vector2] = []
	var surfaces: Dictionary[String, SurfaceTool] = {}
	var current_material := "bark"
	while file != null and not file.eof_reached():
		var line := file.get_line().strip_edges()
		var parts := line.split(" ", false)
		if parts.is_empty():
			continue
		match parts[0]:
			"v":
				if parts.size() >= 4:
					vertices.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])))
			"vn":
				if parts.size() >= 4:
					normals.append(Vector3(float(parts[1]), float(parts[2]), float(parts[3])).normalized())
			"vt":
				if parts.size() >= 3:
					texcoords.append(Vector2(float(parts[1]), 1.0 - float(parts[2])))
			"usemtl":
				current_material = "leaves" if parts.size() > 1 and not str(parts[1]).to_lower().contains("bark") else "bark"
			"f":
				if parts.size() >= 4:
					var surface := _get_obj_surface(surfaces, current_material)
					for triangle_index: int in range(1, parts.size() - 2):
						_append_obj_corner(surface, parts[1], vertices, texcoords, normals)
						_append_obj_corner(surface, parts[triangle_index + 1], vertices, texcoords, normals)
						_append_obj_corner(surface, parts[triangle_index + 2], vertices, texcoords, normals)
	var mesh := ArrayMesh.new()
	for material_name: String in ["bark", "leaves"]:
		if not surfaces.has(material_name):
			continue
		var surface: SurfaceTool = surfaces[material_name]
		surface.generate_tangents()
		surface.set_material(_create_tree_material(str(definition[material_name]), material_name == "leaves"))
		surface.commit(mesh)
	return mesh


func _get_obj_surface(surfaces: Dictionary[String, SurfaceTool], material_name: String) -> SurfaceTool:
	if not surfaces.has(material_name):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[material_name] = surface
	return surfaces[material_name] as SurfaceTool


func _append_obj_corner(surface: SurfaceTool, token: String, vertices: Array[Vector3], texcoords: Array[Vector2], normals: Array[Vector3]) -> void:
	var indices := token.split("/", true)
	var vertex_index := int(indices[0]) - 1
	var uv_index := int(indices[1]) - 1 if indices.size() > 1 and not indices[1].is_empty() else -1
	var normal_index := int(indices[2]) - 1 if indices.size() > 2 and not indices[2].is_empty() else -1
	if uv_index >= 0 and uv_index < texcoords.size():
		surface.set_uv(texcoords[uv_index])
	if normal_index >= 0 and normal_index < normals.size():
		surface.set_normal(normals[normal_index])
	if vertex_index >= 0 and vertex_index < vertices.size():
		surface.add_vertex(vertices[vertex_index])


func _create_tree_material(texture_path: String, transparent: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(texture_path) as Texture2D
	material.roughness = 0.86
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.42
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _estimate_slope(x: float, z: float) -> float:
	var dx := _grid_manager.terrain_height(x + 1.0, z) - _grid_manager.terrain_height(x - 1.0, z)
	var dz := _grid_manager.terrain_height(x, z + 1.0) - _grid_manager.terrain_height(x, z - 1.0)
	return Vector2(dx, dz).length() * 0.5


func _terrain_normal(x: float, z: float) -> Vector3:
	var sample_radius := 1.15
	var left := _grid_manager.terrain_height(x - sample_radius, z)
	var right := _grid_manager.terrain_height(x + sample_radius, z)
	var back := _grid_manager.terrain_height(x, z - sample_radius)
	var forward := _grid_manager.terrain_height(x, z + sample_radius)
	return Vector3(left - right, sample_radius * 2.0, back - forward).normalized()


func _basis_aligned_to_normal(normal: Vector3, yaw: float) -> Basis:
	var tangent := Vector3.FORWARD.cross(normal).normalized()
	if tangent.length_squared() < 0.001:
		tangent = Vector3.RIGHT
	var forward := normal.cross(tangent).normalized()
	var aligned := Basis(tangent, normal, forward).orthonormalized()
	return Basis(normal, yaw) * aligned


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


func _create_water_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	return material


func _river_center(x: float) -> float:
	return 101.0 + sin(x * 0.045) * 11.0 + sin(x * 0.013 + 1.7) * 5.0


func _ravine_center(z: float) -> float:
	return 72.0 + sin(z * 0.052) * 5.0


func is_water_at(x: float, z: float) -> bool:
	if absf(z - _river_center(x)) <= 4.4:
		return true
	return z >= 110.0 and z <= 231.0 and absf(x - _ravine_center(z)) <= 3.4


func water_surface_height_at(x: float, z: float) -> float:
	return WATER_LEVEL if is_water_at(x, z) else -INF
