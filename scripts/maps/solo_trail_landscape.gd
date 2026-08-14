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
const BUSH_DEFINITIONS: Array[Dictionary] = [
	{"scene": preload("res://assets/environment/bush_packs/real_bush/source/all Embed.fbx"), "albedo": preload("res://assets/environment/bush_packs/real_bush/textures/Color_Green.png"), "normal": preload("res://assets/environment/bush_packs/real_bush/textures/Normal.png"), "roughness": preload("res://assets/environment/bush_packs/real_bush/textures/Roughness.png")},
	{"scene": preload("res://assets/environment/bush_packs/bush_01/source/Bush.fbx"), "albedo": preload("res://assets/environment/bush_packs/bush_01/textures/leaves_01_alb.png"), "normal": preload("res://assets/environment/bush_packs/bush_01/textures/leaves_01_nrm.jpeg")},
	{"scene": preload("res://assets/environment/bush_packs/cliff_shrub/source/wallBush-01-terrainWallBush.fbx"), "albedo": preload("res://assets/environment/bush_packs/cliff_shrub/textures/oooo_diffuseOriginal.png"), "normal": preload("res://assets/environment/bush_packs/cliff_shrub/textures/oooo_normal.png")},
]
# Dense enough to read as woodland understorey, but still conservative for the
# imported multi-surface FBX meshes. Spatial chunks keep the draw workload local.
const BUSH_COUNT: int = 1350
const TREE_COUNT: int = 300
const BASE_TREE_COUNT: int = 100
const GIANT_TREE_COUNT: int = 3
const GRASS_INSTANCE_COUNT: int = 68000
const VEGETATION_CHUNK_SIZE: float = 32.0
const VEGETATION_CHUNKS_PER_AXIS: int = 8
const VEGETATION_CHUNK_COUNT: int = VEGETATION_CHUNKS_PER_AXIS * VEGETATION_CHUNKS_PER_AXIS
const WATER_LEVEL: float = -1.7
const WATER_SHADER: Shader = preload("res://world/terrain/shaders/solo_trail_water.gdshader")
const GRASS_MESH: Mesh = preload("res://addons/simplegrasstextured/default_mesh.tres")
const GRASS_SCRIPT: Script = preload("res://addons/simplegrasstextured/grass.gd")
const GRASS_TEXTURES: Array[Texture2D] = [
	preload("res://assets/environment/grass_textures/realtime/textures/Plate1.png"),
	preload("res://assets/environment/grass_textures/realtime/textures/Plate2.png"),
	preload("res://assets/environment/grass_textures/realtime/textures/Plate3.png"),
]
const STYLISED_ROCK_SCATTER: Script = preload("res://scripts/maps/stylised_rock_scatter.gd")

var _grid_manager: GridManager
var _tree_meshes: Array[ArrayMesh] = []
var _bush_meshes: Array[ArrayMesh] = []
var _rock_grass_clearance_grid: Dictionary = {}


func setup(grid_manager: GridManager) -> void:
	_grid_manager = grid_manager
	add_to_group("solo_trail_landscape")
	_load_tree_meshes()
	_load_bush_meshes()
	_create_river()
	var stylised_rocks := STYLISED_ROCK_SCATTER.new() as Node3D
	stylised_rocks.name = "StylisedRockScatter"
	add_child(stylised_rocks)
	stylised_rocks.call("setup", _grid_manager)
	_cache_rock_grass_clearances(stylised_rocks.call("get_grass_clearances") as Array)
	_scatter_grass_multimesh()
	_scatter_tree_multimeshes()
	_scatter_bush_multimeshes()


func _create_river() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	const STEP := 2.0
	const HALF_WIDTH := 7.0
	var main_centers := PackedVector3Array()
	for index: int in range(129):
		var x := float(index) * STEP
		main_centers.append(Vector3(x, WATER_LEVEL, _river_center(x)))
	_append_water_strip(vertices, normals, uvs, main_centers, 15.5, true)
	# The former dry ravine is now the river's flooded northern branch.
	const BRANCH_STEP := 2.0
	var branch_centers := PackedVector3Array()
	for index: int in range(62):
		var z := 110.0 + float(index) * BRANCH_STEP
		branch_centers.append(Vector3(_ravine_center(z), WATER_LEVEL + 0.002, z))
	_append_water_strip(vertices, normals, uvs, branch_centers, 12.8, false)
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


func _append_water_strip(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, centers: PackedVector3Array, max_bank_distance: float, runs_along_x: bool) -> void:
	# The terrain river masks measure main-channel width along Z and branch width
	# along X. Building the ribbon with those same axes makes the water meet the
	# carved banks exactly. Reusing each calculated edge for adjacent triangles
	# also eliminates cracks and sheared joins at bends.
	if centers.size() < 2:
		return
	var left_edges := PackedVector3Array()
	var right_edges := PackedVector3Array()
	for center: Vector3 in centers:
		var negative_axis := Vector3(0.0, 0.0, -1.0) if runs_along_x else Vector3(-1.0, 0.0, 0.0)
		var positive_axis := -negative_axis
		var negative_distance := _find_water_bank_distance(center, negative_axis, max_bank_distance)
		var positive_distance := _find_water_bank_distance(center, positive_axis, max_bank_distance)
		left_edges.append(center + negative_axis * negative_distance)
		right_edges.append(center + positive_axis * positive_distance)
	var traveled := 0.0
	for index: int in range(centers.size() - 1):
		var next_traveled := traveled + centers[index].distance_to(centers[index + 1])
		var uv_start := traveled / 16.0
		var uv_finish := next_traveled / 16.0
		_append_water_vertex(vertices, normals, uvs, left_edges[index], Vector2(uv_start, 0.0))
		_append_water_vertex(vertices, normals, uvs, left_edges[index + 1], Vector2(uv_finish, 0.0))
		_append_water_vertex(vertices, normals, uvs, right_edges[index + 1], Vector2(uv_finish, 1.0))
		_append_water_vertex(vertices, normals, uvs, left_edges[index], Vector2(uv_start, 0.0))
		_append_water_vertex(vertices, normals, uvs, right_edges[index + 1], Vector2(uv_finish, 1.0))
		_append_water_vertex(vertices, normals, uvs, right_edges[index], Vector2(uv_start, 1.0))
		traveled = next_traveled


func _find_water_bank_distance(center: Vector3, direction: Vector3, max_distance: float) -> float:
	# Find the actual terrain/water intersection for every cross-section. This
	# keeps the ribbon attached to irregular banks instead of assuming that the
	# submerged shelf width is also the shoreline width.
	var low := 0.0
	var high := max_distance
	var high_point := center + direction * high
	if _grid_manager.terrain_height(high_point.x, high_point.z) < WATER_LEVEL:
		return max_distance - 0.01
	for _iteration: int in range(10):
		var middle := (low + high) * 0.5
		var sample := center + direction * middle
		if _grid_manager.terrain_height(sample.x, sample.z) < WATER_LEVEL:
			low = middle
		else:
			high = middle
	# Keep only a centimetre of overlap: enough to hide a numerical hairline,
	# without visibly floating the water above a steep bank.
	return maxf(0.25, (low + high) * 0.5 - 0.01)


func _append_water_vertex(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, point: Vector3, uv: Vector2) -> void:
	vertices.append(point)
	normals.append(Vector3.UP)
	uvs.append(uv)


func _scatter_grass_multimesh() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6_601_419
	var transforms_by_chunk: Array[Array] = []
	transforms_by_chunk.resize(GRASS_TEXTURES.size() * VEGETATION_CHUNK_COUNT)
	for batch_index: int in range(transforms_by_chunk.size()):
		transforms_by_chunk[batch_index] = []
	var placed_count := 0
	var attempts: int = 0
	while placed_count < GRASS_INSTANCE_COUNT and attempts < GRASS_INSTANCE_COUNT * 9:
		attempts += 1
		var x := rng.randf_range(4.0, 252.0)
		var z := rng.randf_range(4.0, 252.0)
		var height := _grid_manager.terrain_height(x, z)
		var slope := _estimate_slope(x, z)
		if height < 0.15 or height > 16.5 or slope > 0.28 or is_water_at(x, z):
			continue
		var trail_distance := _trail_distance(x, z)
		# The paving material reaches roughly three metres from the authored
		# centreline. Keep the entire road physically clear of grass cards.
		if trail_distance < 3.35:
			continue
		if _is_inside_rock_grass_clearance(x, z):
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
		# A noisy probability ramp replaces the former ruler-straight exclusion.
		# Individual tufts become both rarer and smaller towards the path, while
		# occasional pockets naturally reach closer to its edge.
		var trail_edge_noise := sin(x * 0.73 + z * 0.41) * 0.70 + cos(x * 0.29 - z * 0.61) * 0.45
		var effective_trail_distance := trail_distance + trail_edge_noise
		var trail_density_factor := smoothstep(3.35, 10.5, effective_trail_distance)
		density *= lerpf(0.02, 1.0, trail_density_factor)
		# Meadows and the softer forest floor carry the richest cover. This is a
		# broad field, so it does not form a visible ring parallel to the road.
		var meadow_or_forest_cover := maxf(meadow_factor, forest_hill_factor * 0.78)
		density *= lerpf(0.72, 1.18, meadow_or_forest_cover)
		# Density fades towards water. The narrow bank band keeps only isolated,
		# slightly slimmer tufts instead of an artificial clean strip.
		var bank_tuft := water_distance < 9.0
		if bank_tuft:
			density *= lerpf(0.012, 0.085, smoothstep(4.4, 9.0, water_distance))
		else:
			density *= smoothstep(7.0, 18.0, water_distance)
		if rng.randf() > density:
			continue
		# The blade-card texture still reads as grass, but the world-space tuft
		# is deliberately twice the previous size for stronger FPP coverage.
		var scale_y := rng.randf_range(0.80, 1.56) * lerpf(0.92, 1.08, meadow_factor)
		var scale_xz := rng.randf_range(0.48, 1.04)
		var trail_scale_factor := lerpf(0.34, 1.0, smoothstep(3.35, 9.0, effective_trail_distance))
		scale_y *= trail_scale_factor
		scale_xz *= lerpf(0.55, 1.0, trail_scale_factor)
		if bank_tuft:
			scale_y *= rng.randf_range(0.82, 1.08)
			scale_xz *= rng.randf_range(0.50, 0.75)
		var blade_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale_xz, scale_y, scale_xz))
		var variant := rng.randi_range(0, GRASS_TEXTURES.size() - 1)
		var chunk_index := _vegetation_chunk_index(x, z)
		transforms_by_chunk[variant * VEGETATION_CHUNK_COUNT + chunk_index].append(Transform3D(blade_basis, Vector3(x, height + 0.012, z)))
		placed_count += 1
	for variant: int in range(GRASS_TEXTURES.size()):
		for chunk_index: int in range(VEGETATION_CHUNK_COUNT):
			_create_grass_batch(variant, chunk_index, transforms_by_chunk[variant * VEGETATION_CHUNK_COUNT + chunk_index])


func _create_grass_batch(variant: int, chunk_index: int, transforms: Array) -> void:
	if transforms.is_empty():
		return
	var chunk_center := _vegetation_chunk_center(chunk_index)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = GRASS_MESH
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		var local_transform := transforms[index] as Transform3D
		local_transform.origin -= chunk_center
		multimesh.set_instance_transform(index, local_transform)
	# Use the actual plugin node. Its _ready configures the correct shader,
	# texture parameters, wind deformation and per-instance scale variation.
	var grass := GRASS_SCRIPT.new() as MultiMeshInstance3D
	grass.name = "SimpleGrassTextured_Meadows_%d_%02d" % [variant + 1, chunk_index]
	grass.position = chunk_center
	grass.multimesh = multimesh
	# Official plugin workflow: Texture Albedo defines the visible plant.
	# These alpha textures contain thin, muted blades instead of the default
	# bright bush silhouette.
	grass.set("texture_albedo", GRASS_TEXTURES[variant])
	grass.set("albedo", Color.WHITE)
	grass.set("grass_tint", Color(0.82, 0.84, 0.66))
	grass.set("color_variation_strength", 0.20)
	grass.set("dry_tint", Color(0.78, 0.69, 0.43))
	grass.set("fresh_tint", Color(0.58, 0.70, 0.38))
	grass.set("variation_scale", 22.0)
	grass.set("scale_h", 1.0)
	grass.set("scale_w", 0.82)
	grass.set("scale_var", -0.22)
	grass.set("grass_strength", 0.48)
	grass.set("alpha_scissor_threshold", 0.30)
	grass.set("light_mode", 1)
	grass.set("interactive", false)
	# The plugin's distance dither discards different instances while the
	# camera moves. On this procedural MultiMesh it looked like random popping.
	grass.set("optimization_by_distance", false)
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.visibility_range_end = 105.0
	grass.visibility_range_end_margin = 18.0
	grass.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
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
	var transforms_by_chunk: Array[Array] = []
	transforms_by_chunk.resize(_bush_meshes.size() * VEGETATION_CHUNK_COUNT)
	for batch_index: int in range(transforms_by_chunk.size()):
		transforms_by_chunk[batch_index] = []
	var accepted_points: Array[Vector2] = []
	var attempts: int = 0
	while accepted_points.size() < BUSH_COUNT and attempts < BUSH_COUNT * 72:
		attempts += 1
		var x := rng.randf_range(7.0, 249.0)
		var z := rng.randf_range(7.0, 249.0)
		var point := Vector2(x, z)
		var height := _grid_manager.terrain_height(x, z)
		var slope := _estimate_slope(x, z)
		if height < 0.35 or height > 34.0 or slope > 0.58 or is_water_at(x, z):
			continue
		var water_distance := _waterway_distance(x, z)
		var beach_bush := water_distance >= 7.35 and water_distance < 12.5 and height < 3.4 and rng.randf() < 0.18
		if water_distance < 7.35 or point.distance_to(Vector2(130.0, 150.0)) < 25.0:
			continue
		if _trail_distance(x, z) < (3.3 if beach_bush else 5.0):
			continue
		var forest_factor := 1.0 - smoothstep(45.0, 100.0, point.distance_to(Vector2(208.0, 54.0)))
		var sheltered_factor := clampf(0.34 + sin(x * 0.071 + z * 0.037) * 0.22 + cos(z * 0.093) * 0.18, 0.04, 0.82)
		# Dense understorey belongs chiefly between the trees. Meadow shrubs stay
		# sparse, while sheltered forest pockets can accept most candidates.
		var acceptance := lerpf(0.10, 0.93, forest_factor) * lerpf(0.58, 1.0, sheltered_factor)
		if beach_bush:
			acceptance = maxf(acceptance, 0.72)
		if slope > 0.24 and height > 10.0:
			acceptance += 0.13
		if rng.randf() > acceptance:
			continue
		if _is_too_close_to_tree(point, accepted_points, rng.randf_range(0.82, 1.75) if not beach_bush else rng.randf_range(2.4, 4.2)):
			continue
		# Stable 5:3:2 distribution guarantees that all three imported shrub
		# variants occur. The cliff shrub remains confined to suitable terrain.
		var mix_slot := accepted_points.size() % 10
		var variant := 0 if mix_slot < 5 else mini(1, _bush_meshes.size() - 1)
		if mix_slot >= 8:
			if slope < 0.14 or height < 5.5:
				continue
			variant = mini(2, _bush_meshes.size() - 1)
		var bounds := _bush_meshes[variant].get_aabb()
		# Shrubs form a readable middle storey: taller than grass, but clearly
		# below the 7.5--12.5 m ordinary trees.
		var target_height := rng.randf_range(1.8, 4.2)
		if variant == 0 and forest_factor > 0.55:
			target_height *= rng.randf_range(1.08, 1.28)
		if variant == 2:
			target_height = rng.randf_range(1.45, 3.1)
		if beach_bush:
			target_height *= rng.randf_range(0.72, 0.94)
		var uniform_scale := target_height / maxf(bounds.size.y, 0.01)
		var width_variation := rng.randf_range(0.78, 1.28)
		var bush_scale := Vector3(uniform_scale * width_variation, uniform_scale * rng.randf_range(0.90, 1.12), uniform_scale * rng.randf_range(0.82, 1.22))
		var terrain_normal := _terrain_normal(x, z)
		var up := Vector3.UP.lerp(terrain_normal, 0.28 if variant == 2 else 0.08).normalized()
		var bush_basis := _basis_aligned_to_normal(up, rng.randf_range(0.0, TAU)).scaled(bush_scale)
		var burial := target_height * rng.randf_range(0.035, 0.09)
		var chunk_index := _vegetation_chunk_index(x, z)
		transforms_by_chunk[variant * VEGETATION_CHUNK_COUNT + chunk_index].append(Transform3D(bush_basis, Vector3(x, height - burial, z)))
		accepted_points.append(point)
	for variant: int in range(_bush_meshes.size()):
		for chunk_index: int in range(VEGETATION_CHUNK_COUNT):
			_create_bush_batch(variant, chunk_index, transforms_by_chunk[variant * VEGETATION_CHUNK_COUNT + chunk_index])


func _create_bush_batch(variant: int, chunk_index: int, transforms: Array) -> void:
	if transforms.is_empty():
		return
	var chunk_center := _vegetation_chunk_center(chunk_index)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _bush_meshes[variant]
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		var local_transform := transforms[index] as Transform3D
		local_transform.origin -= chunk_center
		multimesh.set_instance_transform(index, local_transform)
	var batch := MultiMeshInstance3D.new()
	batch.name = "BushMultiMesh_%d_%02d" % [variant + 1, chunk_index]
	batch.position = chunk_center
	batch.multimesh = multimesh
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	batch.visibility_range_end = 145.0
	batch.visibility_range_end_margin = 22.0
	batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(batch)


func _vegetation_chunk_index(x: float, z: float) -> int:
	var chunk_x := clampi(int(floor(x / VEGETATION_CHUNK_SIZE)), 0, VEGETATION_CHUNKS_PER_AXIS - 1)
	var chunk_z := clampi(int(floor(z / VEGETATION_CHUNK_SIZE)), 0, VEGETATION_CHUNKS_PER_AXIS - 1)
	return chunk_z * VEGETATION_CHUNKS_PER_AXIS + chunk_x


func _vegetation_chunk_center(chunk_index: int) -> Vector3:
	var chunk_x := chunk_index % VEGETATION_CHUNKS_PER_AXIS
	var chunk_z := chunk_index / VEGETATION_CHUNKS_PER_AXIS
	return Vector3((float(chunk_x) + 0.5) * VEGETATION_CHUNK_SIZE, 0.0, (float(chunk_z) + 0.5) * VEGETATION_CHUNK_SIZE)


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
	for definition: Dictionary in BUSH_DEFINITIONS:
		var source_scene := definition["scene"] as PackedScene
		var source_root := source_scene.instantiate()
		var combined := ArrayMesh.new()
		var fallback_material := _create_bush_material(definition)
		_append_bush_surfaces(source_root, Transform3D.IDENTITY, combined, fallback_material)
		source_root.free()
		if combined.get_surface_count() > 0:
			_bush_meshes.append(combined)


func _append_bush_surfaces(node: Node, parent_transform: Transform3D, combined: ArrayMesh, fallback_material: Material) -> void:
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
				# The FBX packs contain inconsistent or unresolved embedded material
				# references. Each variant has a verified PBR fallback, so applying it
				# unconditionally prevents even partially gray MultiMesh surfaces.
				surface.set_material(fallback_material)
				surface.commit(combined)
	for child: Node in node.get_children():
		_append_bush_surfaces(child, accumulated, combined, fallback_material)


func _create_bush_material(definition: Dictionary) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = definition["albedo"] as Texture2D
	material.albedo_color = Color(0.78, 0.80, 0.67)
	material.roughness = 0.92
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.38
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if definition.has("normal"):
		material.normal_enabled = true
		material.normal_texture = definition["normal"] as Texture2D
	if definition.has("roughness"):
		material.roughness_texture = definition["roughness"] as Texture2D
	return material


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


func _cache_rock_grass_clearances(clearances: Array) -> void:
	_rock_grass_clearance_grid.clear()
	for value: Variant in clearances:
		var clearance := value as Vector3
		var cell := Vector2i(floori(clearance.x / 12.0), floori(clearance.y / 12.0))
		if not _rock_grass_clearance_grid.has(cell):
			_rock_grass_clearance_grid[cell] = []
		(_rock_grass_clearance_grid[cell] as Array).append(clearance)


func _is_inside_rock_grass_clearance(x: float, z: float) -> bool:
	var center_cell := Vector2i(floori(x / 12.0), floori(z / 12.0))
	for offset_z: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			var cell := center_cell + Vector2i(offset_x, offset_z)
			if not _rock_grass_clearance_grid.has(cell):
				continue
			for clearance_value: Variant in _rock_grass_clearance_grid[cell] as Array:
				var clearance := clearance_value as Vector3
				if Vector2(x - clearance.x, z - clearance.y).length_squared() < clearance.z * clearance.z:
					return true
	return false


func _ravine_center(z: float) -> float:
	return 72.0 + sin(z * 0.052) * 5.0


func is_water_at(x: float, z: float) -> bool:
	if absf(z - _river_center(x)) <= 7.0:
		return true
	return z >= 110.0 and z <= 231.0 and absf(x - _ravine_center(z)) <= 5.0


func water_surface_height_at(x: float, z: float) -> float:
	return WATER_LEVEL if is_water_at(x, z) else -INF
