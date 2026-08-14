class_name SoloTrailLandscape
extends Node3D

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
const BUSH_SCENES: Array[PackedScene] = [
	preload("res://assets/environment/bush_packs/real_bush/source/all Embed.fbx"),
	preload("res://assets/environment/bush_packs/bush_01/source/Bush.fbx"),
	preload("res://assets/environment/bush_packs/cliff_shrub/source/wallBush-01-terrainWallBush.fbx"),
]
const BUSH_COUNT: int = 190
const TREE_COUNT: int = 300
const BASE_TREE_COUNT: int = 100
const GIANT_TREE_COUNT: int = 3
const GRASS_INSTANCE_COUNT: int = 32000
const WATER_LEVEL: float = -1.7
const WATER_SHADER: Shader = preload("res://world/terrain/shaders/solo_trail_water.gdshader")
const GRASS_MESH: Mesh = preload("res://addons/simplegrasstextured/default_mesh.tres")
const GRASS_SCRIPT: Script = preload("res://addons/simplegrasstextured/grass.gd")
const GRASS_TEXTURE: Texture2D = preload("res://addons/simplegrasstextured/textures/grassbushcc008.png")
const STYLISED_ROCK_SCATTER: Script = preload("res://scripts/maps/stylised_rock_scatter.gd")

var _grid_manager: GridManager
var _tree_meshes: Array[ArrayMesh] = []
var _bush_meshes: Array[ArrayMesh] = []


func setup(grid_manager: GridManager) -> void:
	_grid_manager = grid_manager
	add_to_group("solo_trail_landscape")
	_load_tree_meshes()
	_load_bush_meshes()
	_create_river()
	_scatter_grass_multimesh()
	var stylised_rocks := STYLISED_ROCK_SCATTER.new() as Node3D
	stylised_rocks.name = "StylisedRockScatter"
	add_child(stylised_rocks)
	stylised_rocks.call("setup", _grid_manager)
	_scatter_tree_multimeshes()
	_scatter_bush_multimeshes()


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
		if _trail_distance(x, z) < 3.8:
			continue
		var water_distance := _waterway_distance(x, z)
		var meadow_factor := 1.0 - smoothstep(0.08, 0.28, slope)
		meadow_factor *= 1.0 - smoothstep(12.0, 16.5, height)
		var forest_hill_factor := 1.0 - smoothstep(38.0, 82.0, Vector2(x, z).distance_to(Vector2(208.0, 54.0)))
		# Low-frequency fields form broad meadows and natural empty pockets.
		var broad := sin(x * 0.055) * 0.32 + cos(z * 0.047) * 0.30 + sin((x + z) * 0.021) * 0.38
		var fine := sin(x * 0.31 - z * 0.27) * 0.18
		var density := clampf(0.52 + broad + fine, 0.03, 0.97) * lerpf(0.18, 1.0, meadow_factor)
		density *= lerpf(1.0, 0.18, forest_hill_factor)
		# Density fades towards water. The narrow bank band keeps only isolated,
		# slightly slimmer tufts instead of an artificial clean strip.
		var bank_tuft := water_distance < 9.0
		if bank_tuft:
			density *= lerpf(0.012, 0.085, smoothstep(4.4, 9.0, water_distance))
		else:
			density *= smoothstep(7.0, 18.0, water_distance)
		if rng.randf() > density:
			continue
		var scale_y := rng.randf_range(0.78, 1.58) * lerpf(0.92, 1.14, meadow_factor)
		var scale_xz := rng.randf_range(0.68, 1.28)
		if bank_tuft:
			scale_y *= rng.randf_range(0.88, 1.20)
			scale_xz *= rng.randf_range(0.34, 0.54)
		var blade_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale_xz, scale_y, scale_xz))
		transforms.append(Transform3D(blade_basis, Vector3(x, height + 0.025, z)))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = GRASS_MESH
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	# Use the actual plugin node. Its _ready configures the correct shader,
	# texture parameters, wind deformation and per-instance scale variation.
	var grass := GRASS_SCRIPT.new() as MultiMeshInstance3D
	grass.name = "SimpleGrassTextured_Meadows"
	grass.multimesh = multimesh
	grass.set("texture_albedo", GRASS_TEXTURE)
	# Muted straw/olive tint keeps blades in the same palette as the trees.
	grass.set("albedo", Color(0.50, 0.50, 0.31))
	# Taller than the original plugin grass, but clearly smaller than the
	# oversized previous pass. Per-instance transforms add natural variation.
	grass.set("scale_h", 1.35)
	grass.set("scale_w", 0.72)
	grass.set("scale_var", -0.16)
	grass.set("grass_strength", 0.66)
	grass.set("alpha_scissor_threshold", 0.38)
	grass.set("light_mode", 1)
	grass.set("interactive", false)
	# The plugin's distance dither discards different instances while the
	# camera moves. On this procedural MultiMesh it looked like random popping.
	grass.set("optimization_by_distance", false)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)
	grass.call_deferred("recalculate_custom_aabb")


func _scatter_tree_multimeshes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4_810_273
	var transforms_by_variant: Array[Array] = [[], []]
	var accepted_points: Array[Vector2] = []
	var placed: int = 0
	var attempts: int = 0
	while placed < TREE_COUNT and attempts < 18000:
		attempts += 1
		var is_large_forest_tree := placed >= BASE_TREE_COUNT
		var x: float
		var z: float
		if is_large_forest_tree and rng.randf() < 0.68:
			var angle := rng.randf_range(0.0, TAU)
			var radius := sqrt(rng.randf()) * rng.randf_range(18.0, 66.0)
			x = 208.0 + cos(angle) * radius * 1.08
			z = 54.0 + sin(angle) * radius * 0.78
		else:
			x = rng.randf_range(9.0, 247.0)
			z = rng.randf_range(9.0, 247.0)
		var point := Vector2(x, z)
		if x < 8.0 or x > 248.0 or z < 8.0 or z > 248.0:
			continue
		var height := _grid_manager.terrain_height(x, z)
		var slope := _estimate_slope(x, z)
		var river_distance := absf(z - _river_center(x))
		var ravine_x := 72.0 + sin(z * 0.052) * 5.0
		var max_slope := 0.52 if is_large_forest_tree else 0.34
		var max_height := 38.0 if is_large_forest_tree else 17.0
		if slope > max_slope or height > max_height or height < 0.5:
			continue
		if river_distance < 13.0 or (z > 105.0 and z < 228.0 and absf(x - ravine_x) < 13.0):
			continue
		if point.distance_to(Vector2(130.0, 150.0)) < (28.0 if is_large_forest_tree else 34.0):
			continue
		if _is_too_close_to_tree(point, accepted_points, 3.2 if is_large_forest_tree else 4.6):
			continue
		var variant := rng.randi_range(0, _tree_meshes.size() - 1)
		var mesh_bounds := _tree_meshes[variant].get_aabb()
		var source_height := maxf(mesh_bounds.size.y, 0.01)
		var target_height := rng.randf_range(7.5, 12.5)
		if is_large_forest_tree:
			target_height = rng.randf_range(25.0, 35.0)
		elif placed < GIANT_TREE_COUNT:
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


func _scatter_bush_multimeshes() -> void:
	if _bush_meshes.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7_204_611
	var transforms_by_variant: Array[Array] = []
	for _variant: int in range(_bush_meshes.size()):
		transforms_by_variant.append([])
	var accepted_points: Array[Vector2] = []
	var attempts: int = 0
	while accepted_points.size() < BUSH_COUNT and attempts < BUSH_COUNT * 55:
		attempts += 1
		var x := rng.randf_range(7.0, 249.0)
		var z := rng.randf_range(7.0, 249.0)
		var point := Vector2(x, z)
		var height := _grid_manager.terrain_height(x, z)
		var slope := _estimate_slope(x, z)
		if height < 0.35 or height > 34.0 or slope > 0.58 or is_water_at(x, z):
			continue
		if _waterway_distance(x, z) < 7.0 or point.distance_to(Vector2(130.0, 150.0)) < 25.0:
			continue
		if _trail_distance(x, z) < 5.0:
			continue
		var forest_factor := 1.0 - smoothstep(45.0, 100.0, point.distance_to(Vector2(208.0, 54.0)))
		var sheltered_factor := clampf(0.34 + sin(x * 0.071 + z * 0.037) * 0.22 + cos(z * 0.093) * 0.18, 0.04, 0.82)
		var acceptance := lerpf(0.08, 0.62, forest_factor) * sheltered_factor
		if slope > 0.24 and height > 10.0:
			acceptance += 0.13
		if rng.randf() > acceptance:
			continue
		if _is_too_close_to_tree(point, accepted_points, rng.randf_range(1.8, 3.2)):
			continue
		# A stable 6:3:1 mix guarantees visible variety while keeping the
		# cliff shrub uncommon and tied to genuinely rocky ground.
		var mix_slot := accepted_points.size() % 10
		var variant := 0 if mix_slot < 6 else mini(1, _bush_meshes.size() - 1)
		if mix_slot == 9:
			if slope < 0.18 or height < 7.0:
				continue
			variant = mini(2, _bush_meshes.size() - 1)
		var bounds := _bush_meshes[variant].get_aabb()
		var target_height := rng.randf_range(0.85, 1.65)
		if variant == 0 and forest_factor > 0.55:
			target_height *= rng.randf_range(1.05, 1.45)
		if variant == 2:
			target_height = rng.randf_range(0.55, 1.15)
		var uniform_scale := target_height / maxf(bounds.size.y, 0.01)
		var width_variation := rng.randf_range(0.78, 1.28)
		var bush_scale := Vector3(uniform_scale * width_variation, uniform_scale * rng.randf_range(0.90, 1.12), uniform_scale * rng.randf_range(0.82, 1.22))
		var terrain_normal := _terrain_normal(x, z)
		var up := Vector3.UP.lerp(terrain_normal, 0.28 if variant == 2 else 0.08).normalized()
		var bush_basis := _basis_aligned_to_normal(up, rng.randf_range(0.0, TAU)).scaled(bush_scale)
		var burial := target_height * rng.randf_range(0.035, 0.09)
		transforms_by_variant[variant].append(Transform3D(bush_basis, Vector3(x, height - burial, z)))
		accepted_points.append(point)
	for variant: int in range(_bush_meshes.size()):
		_create_bush_batch(variant, transforms_by_variant[variant])


func _create_bush_batch(variant: int, transforms: Array) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _bush_meshes[variant]
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index] as Transform3D)
	var batch := MultiMeshInstance3D.new()
	batch.name = "BushMultiMesh_%d" % (variant + 1)
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


func _load_bush_meshes() -> void:
	_bush_meshes.clear()
	for source_scene: PackedScene in BUSH_SCENES:
		var source_root := source_scene.instantiate()
		var combined := ArrayMesh.new()
		_append_bush_surfaces(source_root, Transform3D.IDENTITY, combined)
		source_root.free()
		if combined.get_surface_count() > 0:
			_bush_meshes.append(combined)


func _append_bush_surfaces(node: Node, parent_transform: Transform3D, combined: ArrayMesh) -> void:
	var local_transform := Transform3D.IDENTITY
	if node is Node3D:
		local_transform = (node as Node3D).transform
	var accumulated := parent_transform * local_transform
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			for surface_index: int in range(mesh_instance.mesh.get_surface_count()):
				var surface := SurfaceTool.new()
				surface.append_from(mesh_instance.mesh, surface_index, accumulated)
				var override_material := mesh_instance.get_surface_override_material(surface_index)
				var material := override_material if override_material != null else mesh_instance.mesh.surface_get_material(surface_index)
				if material != null:
					surface.set_material(material)
				surface.commit(combined)
	for child: Node in node.get_children():
		_append_bush_surfaces(child, accumulated, combined)


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


func _create_water_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	return material


func _river_center(x: float) -> float:
	return 101.0 + sin(x * 0.045) * 11.0 + sin(x * 0.013 + 1.7) * 5.0


func _waterway_distance(x: float, z: float) -> float:
	var river_distance := absf(z - _river_center(x))
	if z < 106.0 or z > 234.0:
		return river_distance
	return minf(river_distance, absf(x - _ravine_center(z)))


func _trail_distance(x: float, z: float) -> float:
	# Keep synchronized with solo_path_center_x() in terrain_ground.gdshader.
	var t := clampf((246.0 - z) / 226.0, 0.0, 1.0)
	var inverse := 1.0 - t
	var center_x := inverse * inverse * inverse * 35.0 + 3.0 * inverse * inverse * t * 45.0 + 3.0 * inverse * t * t * 225.0 + t * t * t * 218.0
	return absf(x - center_x)


func _ravine_center(z: float) -> float:
	return 72.0 + sin(z * 0.052) * 5.0


func is_water_at(x: float, z: float) -> bool:
	if absf(z - _river_center(x)) <= 4.4:
		return true
	return z >= 110.0 and z <= 231.0 and absf(x - _ravine_center(z)) <= 3.4


func water_surface_height_at(x: float, z: float) -> float:
	return WATER_LEVEL if is_water_at(x, z) else -INF
