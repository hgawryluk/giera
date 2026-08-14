class_name SoloTrailStreamedSector
extends Node3D

signal build_completed(coordinate: Vector2i)

const SIZE: float = 256.0
# The authored center mesh samples every metre. Matching that resolution is
# required at its borders: a four-metre streamed edge only shares every fourth
# vertex and leaves visible gaps along the nonlinear height profile.
const CELLS: int = 256
const WATER_LEVEL: float = -1.7
const TREE_COUNT: int = 300
const GRASS_COUNT: int = 48000
const BUSH_COUNT: int = 1100
const ROCK_COUNT: int = 96
const VEGETATION_CHUNKS_PER_AXIS: int = 4
const VEGETATION_CHUNK_COUNT: int = 16
const VEGETATION_CHUNK_SIZE: float = SIZE / float(VEGETATION_CHUNKS_PER_AXIS)
const TREE_MESHES: Array[Mesh] = [
	preload("res://assets/environment/tree_packs/tree/Tree/Tree.obj"),
	preload("res://assets/environment/tree_packs/tree_02/Tree 02/Tree.obj"),
]
const GRASS_MESH: Mesh = preload("res://addons/simplegrasstextured/default_mesh.tres")
const GRASS_SCRIPT: Script = preload("res://addons/simplegrasstextured/grass.gd")
const GRASS_TEXTURES: Array[Texture2D] = [
	preload("res://assets/environment/grass_textures/realtime/textures/Plate1.png"),
	preload("res://assets/environment/grass_textures/realtime/textures/Plate2.png"),
	preload("res://assets/environment/grass_textures/realtime/textures/Plate3.png"),
]
const BUSH_DEFINITIONS: Array[Dictionary] = [
	{"scene": preload("res://assets/environment/bush_packs/real_bush/source/all Embed.fbx"), "albedo": preload("res://assets/environment/bush_packs/real_bush/textures/Color_Green.png"), "normal": preload("res://assets/environment/bush_packs/real_bush/textures/Normal.png"), "roughness": preload("res://assets/environment/bush_packs/real_bush/textures/Roughness.png")},
	{"scene": preload("res://assets/environment/bush_packs/bush_01/source/Bush.fbx"), "albedo": preload("res://assets/environment/bush_packs/bush_01/textures/leaves_01_alb.png"), "normal": preload("res://assets/environment/bush_packs/bush_01/textures/leaves_01_nrm.jpeg")},
	{"scene": preload("res://assets/environment/bush_packs/cliff_shrub/source/wallBush-01-terrainWallBush.fbx"), "albedo": preload("res://assets/environment/bush_packs/cliff_shrub/textures/oooo_diffuseOriginal.png"), "normal": preload("res://assets/environment/bush_packs/cliff_shrub/textures/oooo_normal.png")},
]
const ROCK_COLLECTION: PackedScene = preload("res://assets/environment/stylised_rocks/source/Stylised_Rock_Collection.fbx")
const ROCK_ALBEDO: Texture2D = preload("res://assets/environment/stylised_rocks/textures/M_Mossy_Rock_BaseColour.png")
const ROCK_NORMAL: Texture2D = preload("res://assets/environment/stylised_rocks/textures/M_Mossy_Rock_NormalOpenGL.png")
const ROCK_ROUGHNESS: Texture2D = preload("res://assets/environment/stylised_rocks/textures/M_Mossy_Rock_Roughness.png")
const TERRAIN_MATERIAL: ShaderMaterial = preload("res://world/terrain/materials/terrain_ground_material.tres")
const WATER_SHADER: Shader = preload("res://world/terrain/shaders/solo_trail_water.gdshader")
const PROXIMITY_COLLISIONS: Script = preload("res://scripts/maps/proximity_obstacle_collisions.gd")
const FOREST_LITTER_SCATTER: Script = preload("res://scripts/maps/forest_litter_decal_scatter.gd")
const TERRAIN_ROWS_PER_FRAME: int = 8

var coordinate := Vector2i.ZERO
var _grid_manager: GridManager
static var _shared_bush_meshes: Array[ArrayMesh] = []
static var _shared_rock_meshes: Array[Mesh] = []


func configure(sector_coordinate: Vector2i, grid_manager: GridManager) -> void:
	coordinate = sector_coordinate
	_grid_manager = grid_manager
	# The authored center terrain spans -0.5..255.5. Using the same half-cell
	# origin makes every streamed mesh share its boundary vertices exactly.
	position = Vector3(float(coordinate.x) * SIZE - 0.5, 0.0, float(coordinate.y) * SIZE - 0.5)
	name = "SoloTrailSector_%d_%d" % [coordinate.x, coordinate.y]


func _ready() -> void:
	# A sector used to build a 65k-triangle mesh, normals and a concave
	# trimesh in one _ready() call.  That blocked the main thread for seconds.
	# Spread CPU work over frames and use the terrain-specialised height-map
	# collider; the streamer starts this while the sector is still ahead.
	await _build_terrain_incremental()
	await get_tree().process_frame
	_build_water()
	await get_tree().process_frame
	await _build_decorations_incremental()
	var litter := FOREST_LITTER_SCATTER.new() as MultiMeshInstance3D
	litter.name = "ForestLitterDecals"
	add_child(litter)
	var world_bounds := Rect2(global_position.x, global_position.z, SIZE, SIZE)
	litter.call("setup", _grid_manager, world_bounds, 1100, 8_140_611 + coordinate.x * 92821 + coordinate.y * 68917)
	build_completed.emit(coordinate)


func _build_terrain_incremental() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := SIZE / float(CELLS)
	var height_data := PackedFloat32Array()
	height_data.resize((CELLS + 1) * (CELLS + 1))
	# Shared grid vertices reduce expensive global-height evaluations roughly sixfold.
	for vertex_z: int in range(CELLS + 1):
		for vertex_x: int in range(CELLS + 1):
			var point := _terrain_point(float(vertex_x) * step, float(vertex_z) * step)
			height_data[vertex_z * (CELLS + 1) + vertex_x] = point.y
			var global_x := global_position.x + point.x
			var global_z := global_position.z + point.z
			surface.set_normal(_terrain_normal(global_x, global_z))
			surface.set_uv(Vector2(point.x, point.z) / 8.0)
			surface.add_vertex(point)
		if vertex_z % TERRAIN_ROWS_PER_FRAME == TERRAIN_ROWS_PER_FRAME - 1:
			await get_tree().process_frame
	for cell_z: int in range(CELLS):
		for cell_x: int in range(CELLS):
			var top_left := cell_z * (CELLS + 1) + cell_x
			var top_right := top_left + 1
			var bottom_left := (cell_z + 1) * (CELLS + 1) + cell_x
			var bottom_right := bottom_left + 1
			for index: int in [top_left, top_right, bottom_right, top_left, bottom_right, bottom_left]:
				surface.add_index(index)
		if cell_z % 16 == 15:
			await get_tree().process_frame
	var mesh := surface.commit()
	var terrain := MeshInstance3D.new()
	terrain.name = "StreamedTerrain"
	terrain.mesh = mesh
	var material := TERRAIN_MATERIAL.duplicate() as ShaderMaterial
	material.set_shader_parameter("solo_trail_landscape", true)
	material.set_shader_parameter("plain_green", false)
	material.set_shader_parameter("grid_visible", false)
	terrain.material_override = material
	add_child(terrain)
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	var collision := CollisionShape3D.new()
	var height_shape := HeightMapShape3D.new()
	height_shape.map_width = CELLS + 1
	height_shape.map_depth = CELLS + 1
	height_shape.map_data = height_data
	collision.shape = height_shape
	# HeightMapShape is centred, while the rendered mesh starts at local zero.
	collision.position = Vector3(SIZE * 0.5, 0.0, SIZE * 0.5)
	body.add_child(collision)
	add_child(body)


func _terrain_point(local_x: float, local_z: float) -> Vector3:
	var global_x := global_position.x + local_x
	var global_z := global_position.z + local_z
	return Vector3(local_x, _grid_manager.terrain_height(global_x, global_z), local_z)


func _terrain_normal(global_x: float, global_z: float) -> Vector3:
	# Identical sampling to GridManager's authored center mesh prevents a
	# lighting discontinuity even though streamed vertices are indexed.
	var dx := _grid_manager.terrain_height(global_x - 0.2, global_z) - _grid_manager.terrain_height(global_x + 0.2, global_z)
	var dz := _grid_manager.terrain_height(global_x, global_z - 0.2) - _grid_manager.terrain_height(global_x, global_z + 0.2)
	return Vector3(dx, 0.4, dz).normalized()


func _build_water() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin_x := global_position.x
	var origin_z := global_position.z
	for index: int in range(128):
		var gx0 := origin_x + float(index) * 2.0
		var gx1 := gx0 + 2.0
		_append_global_water_segment(surface, Vector2(gx0, _river_center(gx0)), Vector2(gx1, _river_center(gx1)), true, origin_x, origin_z)
	for index: int in range(128):
		var gz0 := origin_z + float(index) * 2.0
		var gz1 := gz0 + 2.0
		_append_global_water_segment(surface, Vector2(_ravine_center(gz0), gz0), Vector2(_ravine_center(gz1), gz1), false, origin_x, origin_z)
	var mesh := surface.commit()
	if mesh.get_surface_count() == 0:
		return
	var water := MeshInstance3D.new()
	water.name = "StreamedWater"
	water.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _append_global_water_segment(surface: SurfaceTool, a: Vector2, b: Vector2, along_x: bool, origin_x: float, origin_z: float) -> void:
	var sector_rect := Rect2(origin_x - 18.0, origin_z - 18.0, SIZE + 36.0, SIZE + 36.0)
	if not sector_rect.has_point(a) and not sector_rect.has_point(b):
		return
	var negative := Vector2(0.0, -1.0) if along_x else Vector2(-1.0, 0.0)
	var positive := -negative
	var a_left := a + negative * _bank_distance(a, negative, 20.0)
	var a_right := a + positive * _bank_distance(a, positive, 20.0)
	var b_left := b + negative * _bank_distance(b, negative, 20.0)
	var b_right := b + positive * _bank_distance(b, positive, 20.0)
	var points: Array[Vector2] = [a_left, a_right, b_right, a_left, b_right, b_left]
	# Avoid coplanar flicker where both continuous river ribbons cross.
	var water_y := WATER_LEVEL if along_x else WATER_LEVEL + 0.002
	for point: Vector2 in points:
		surface.set_uv(point / 18.0)
		surface.add_vertex(Vector3(point.x - origin_x, water_y, point.y - origin_z))


func _bank_distance(center: Vector2, direction: Vector2, maximum: float) -> float:
	var low := 0.0
	var high := maximum
	for _iteration: int in range(10):
		var middle := (low + high) * 0.5
		var sample := center + direction * middle
		if _grid_manager.terrain_height(sample.x, sample.y) < WATER_LEVEL:
			low = middle
		else:
			high = middle
	return maxf(0.25, (low + high) * 0.5 - 0.01)


func _build_decorations_incremental() -> void:
	await _ensure_shared_assets()
	var rng := RandomNumberGenerator.new()
	rng.seed = 71_391_117 + coordinate.x * 91_873 + coordinate.y * 31_337
	var trees: Array[Array] = [[], []]
	var grass: Array[Array] = []
	var bushes: Array[Array] = []
	grass.resize(GRASS_TEXTURES.size() * VEGETATION_CHUNK_COUNT)
	bushes.resize(_shared_bush_meshes.size() * VEGETATION_CHUNK_COUNT)
	for batch: int in range(grass.size()): grass[batch] = []
	for batch: int in range(bushes.size()): bushes[batch] = []
	var rocks: Array[Array] = []
	rocks.resize(_shared_rock_meshes.size())
	for batch: int in range(rocks.size()): rocks[batch] = []
	var tree_collisions: Array[Dictionary] = []
	var rock_collisions: Array[Dictionary] = []
	for _index: int in range(TREE_COUNT * 200):
		if _index % 256 == 255:
			await get_tree().process_frame
		if trees[0].size() + trees[1].size() >= TREE_COUNT:
			break
		var p := _random_global_point(rng)
		if not _can_decorate(p, 8.5, 0.72):
			continue
		var variant := rng.randi_range(0, 1)
		var bounds := TREE_MESHES[variant].get_aabb()
		var target_height := rng.randf_range(9.0, 18.0)
		var scale_value := target_height / maxf(bounds.size.y, 0.01)
		var local := Vector3(p.x - global_position.x, _grid_manager.terrain_height(p.x, p.y), p.y - global_position.z)
		trees[variant].append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale_value), local))
		tree_collisions.append({"position": Vector3(p.x, local.y, p.y), "radius": clampf(target_height * 0.05, 0.45, 1.0), "height": target_height * 0.7})
	for _index: int in range(GRASS_COUNT):
		if _index % 128 == 127:
			await get_tree().process_frame
		var p := _random_global_point(rng)
		if not _can_decorate(p, 4.0, 0.32):
			continue
		var scale_value := rng.randf_range(0.7, 1.45)
		var local_x := p.x - global_position.x
		var local_z := p.y - global_position.z
		var chunk := _vegetation_chunk_index(local_x, local_z)
		var grass_variant := _index % GRASS_TEXTURES.size()
		grass[grass_variant * VEGETATION_CHUNK_COUNT + chunk].append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale_value), Vector3(local_x, _grid_manager.terrain_height(p.x, p.y) + 0.02, local_z)))
	var placed_bushes := 0
	for _index: int in range(BUSH_COUNT * 18):
		if _index % 128 == 127: await get_tree().process_frame
		if placed_bushes >= BUSH_COUNT: break
		var p := _random_global_point(rng)
		if not _can_decorate(p, 6.2, 0.48): continue
		var variant := placed_bushes % _shared_bush_meshes.size()
		var bounds := _shared_bush_meshes[variant].get_aabb()
		var target_height := rng.randf_range(1.7, 4.2)
		var uniform_scale := target_height / maxf(bounds.size.y, 0.01)
		var local_x := p.x - global_position.x
		var local_z := p.y - global_position.z
		var chunk := _vegetation_chunk_index(local_x, local_z)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(uniform_scale * rng.randf_range(0.82, 1.25), uniform_scale, uniform_scale * rng.randf_range(0.82, 1.25)))
		bushes[variant * VEGETATION_CHUNK_COUNT + chunk].append(Transform3D(basis, Vector3(local_x, _grid_manager.terrain_height(p.x, p.y) - target_height * 0.055, local_z)))
		placed_bushes += 1
	for _index: int in range(ROCK_COUNT):
		var p := _random_global_point(rng)
		if _grid_manager.solo_trail_path_distance(p.x, p.y) < 7.5:
			continue
		var target_size := rng.randf_range(0.7, 2.8)
		var ground := _grid_manager.terrain_height(p.x, p.y)
		var rock_variant := _index % _shared_rock_meshes.size()
		var bounds := _shared_rock_meshes[rock_variant].get_aabb()
		var source_size := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
		var scale_value := target_size / maxf(source_size, 0.01)
		rocks[rock_variant].append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale_value, scale_value * 0.72, scale_value * 0.88)), Vector3(p.x - global_position.x, ground - target_size * 0.20, p.y - global_position.z)))
		if target_size > 1.3:
			rock_collisions.append({"position": Vector3(p.x, ground - target_size * 0.20, p.y), "radius": target_size * 0.55, "height": target_size})
	for variant: int in range(2):
		_add_multimesh("StreamedTrees_%d" % variant, TREE_MESHES[variant], trees[variant], true, null)
	for variant: int in range(GRASS_TEXTURES.size()):
		for chunk: int in range(VEGETATION_CHUNK_COUNT):
			_add_grass_batch(variant, chunk, grass[variant * VEGETATION_CHUNK_COUNT + chunk])
	for variant: int in range(_shared_bush_meshes.size()):
		for chunk: int in range(VEGETATION_CHUNK_COUNT):
			_add_bush_batch(variant, chunk, bushes[variant * VEGETATION_CHUNK_COUNT + chunk])
	for variant: int in range(_shared_rock_meshes.size()):
		_add_multimesh("StreamedRocks_%d" % variant, _shared_rock_meshes[variant], rocks[variant], true, null)
	var collision_manager := PROXIMITY_COLLISIONS.new() as Node3D
	collision_manager.name = "SectorProximityCollisions"
	add_child(collision_manager)
	collision_manager.call("setup", tree_collisions, rock_collisions)


func _random_global_point(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(global_position.x + rng.randf_range(3.0, SIZE - 3.0), global_position.z + rng.randf_range(3.0, SIZE - 3.0))


func _ensure_shared_assets() -> void:
	if _shared_bush_meshes.is_empty():
		for definition: Dictionary in BUSH_DEFINITIONS:
			var source := (definition["scene"] as PackedScene).instantiate()
			var combined := ArrayMesh.new()
			_append_bush_surfaces(source, Transform3D.IDENTITY, combined, _create_bush_material(definition))
			source.free()
			if combined.get_surface_count() > 0: _shared_bush_meshes.append(combined)
			await get_tree().process_frame
	if _shared_rock_meshes.is_empty():
		var collection := ROCK_COLLECTION.instantiate()
		var candidates := collection.find_children("*", "MeshInstance3D", true, false)
		var rock_material := _create_rock_material()
		for variant: int in range(mini(4, candidates.size())):
			var source_index := roundi(float(variant) * float(candidates.size() - 1) / 3.0)
			var mesh := (candidates[source_index] as MeshInstance3D).mesh.duplicate(true) as Mesh
			for surface_index: int in range(mesh.get_surface_count()): mesh.surface_set_material(surface_index, rock_material)
			_shared_rock_meshes.append(mesh)
		collection.free()
		await get_tree().process_frame


func _append_bush_surfaces(node: Node, parent_transform: Transform3D, combined: ArrayMesh, material: Material) -> void:
	var local_transform := (node as Node3D).transform if node is Node3D else Transform3D.IDENTITY
	var accumulated := parent_transform * local_transform
	if node is MeshInstance3D:
		var source_mesh := (node as MeshInstance3D).mesh
		if source_mesh != null:
			for surface_index: int in range(source_mesh.get_surface_count()):
				var surface := SurfaceTool.new()
				surface.append_from(source_mesh, surface_index, accumulated)
				surface.set_material(material)
				surface.commit(combined)
	for child: Node in node.get_children():
		_append_bush_surfaces(child, accumulated, combined, material)


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
	if definition.has("roughness"): material.roughness_texture = definition["roughness"] as Texture2D
	return material


func _create_rock_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = ROCK_ALBEDO
	material.normal_enabled = true
	material.normal_texture = ROCK_NORMAL
	material.roughness_texture = ROCK_ROUGHNESS
	material.roughness = 0.92
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _vegetation_chunk_index(local_x: float, local_z: float) -> int:
	var chunk_x := clampi(floori(local_x / VEGETATION_CHUNK_SIZE), 0, VEGETATION_CHUNKS_PER_AXIS - 1)
	var chunk_z := clampi(floori(local_z / VEGETATION_CHUNK_SIZE), 0, VEGETATION_CHUNKS_PER_AXIS - 1)
	return chunk_z * VEGETATION_CHUNKS_PER_AXIS + chunk_x


func _vegetation_chunk_center(chunk: int) -> Vector3:
	return Vector3((float(chunk % VEGETATION_CHUNKS_PER_AXIS) + 0.5) * VEGETATION_CHUNK_SIZE, 0.0, (float(chunk / VEGETATION_CHUNKS_PER_AXIS) + 0.5) * VEGETATION_CHUNK_SIZE)


func _add_grass_batch(variant: int, chunk: int, transforms: Array) -> void:
	if transforms.is_empty(): return
	var center := _vegetation_chunk_center(chunk)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = GRASS_MESH
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		var local_transform := transforms[index] as Transform3D
		local_transform.origin -= center
		multimesh.set_instance_transform(index, local_transform)
	var renderer := GRASS_SCRIPT.new() as MultiMeshInstance3D
	renderer.name = "StreamedGrass_%d_%02d" % [variant + 1, chunk]
	renderer.position = center
	renderer.multimesh = multimesh
	renderer.set("texture_albedo", GRASS_TEXTURES[variant])
	renderer.set("albedo", Color.WHITE)
	renderer.set("grass_tint", Color(0.82, 0.84, 0.66))
	renderer.set("color_variation_strength", 0.20)
	renderer.set("dry_tint", Color(0.78, 0.69, 0.43))
	renderer.set("fresh_tint", Color(0.58, 0.70, 0.38))
	renderer.set("variation_scale", 22.0)
	renderer.set("scale_h", 1.0)
	renderer.set("scale_w", 0.82)
	renderer.set("scale_var", -0.22)
	renderer.set("grass_strength", 0.48)
	renderer.set("alpha_scissor_threshold", 0.30)
	renderer.set("roughness", 1.0)
	renderer.set("specular", 0.0)
	renderer.set("light_mode", 1)
	renderer.set("interactive", false)
	renderer.set("optimization_by_distance", false)
	renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	renderer.visibility_range_end = 76.0
	renderer.visibility_range_end_margin = 14.0
	renderer.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(renderer)
	renderer.call_deferred("recalculate_custom_aabb")


func _add_bush_batch(variant: int, chunk: int, transforms: Array) -> void:
	if transforms.is_empty(): return
	var center := _vegetation_chunk_center(chunk)
	var adjusted: Array[Transform3D] = []
	for transform_value: Transform3D in transforms:
		var adjusted_transform := transform_value
		adjusted_transform.origin -= center
		adjusted.append(adjusted_transform)
	_add_multimesh("StreamedBush_%d_%02d" % [variant + 1, chunk], _shared_bush_meshes[variant], adjusted, false, null)
	var renderer := get_node("StreamedBush_%d_%02d" % [variant + 1, chunk]) as MultiMeshInstance3D
	renderer.position = center
	renderer.visibility_range_end = 112.0
	renderer.visibility_range_end_margin = 18.0
	renderer.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


func _can_decorate(point: Vector2, path_margin: float, max_slope: float) -> bool:
	if _grid_manager.solo_trail_is_water(point.x, point.y) or _grid_manager.solo_trail_path_distance(point.x, point.y) < path_margin:
		return false
	var dx := _grid_manager.terrain_height(point.x + 1.0, point.y) - _grid_manager.terrain_height(point.x - 1.0, point.y)
	var dz := _grid_manager.terrain_height(point.x, point.y + 1.0) - _grid_manager.terrain_height(point.x, point.y - 1.0)
	return Vector2(dx, dz).length() * 0.5 <= max_slope


func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array, shadows: bool, material: Material) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index] as Transform3D)
	var renderer := MultiMeshInstance3D.new()
	renderer.name = node_name
	renderer.multimesh = multimesh
	renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if material != null:
		renderer.material_override = material
	add_child(renderer)


func _river_center(x: float) -> float:
	return 101.0 + sin(x * 0.045) * 11.0 + sin(x * 0.013 + 1.7) * 5.0


func _ravine_center(z: float) -> float:
	return 72.0 + sin(z * 0.052) * 5.0
