class_name ArenaTestLandscape
extends Node3D

const WATER_LEVEL: float = -0.85
const RIVER_HALF_WIDTH: float = 5.2
const BRIDGE_HALF_WIDTH: float = 3.0
const FORD_X_OFFSET: float = 46.0
const FORD_HALF_WIDTH: float = 8.0
const TREE_SCENES: Array[PackedScene] = [
	preload("res://assets/models/environment/large_tree.glb"),
	preload("res://assets/environment/tree_packs/tree/Tree/Tree.fbx")
]
const BUSH_SCENE: PackedScene = preload("res://assets/models/environment/bush_grass_02.glb")
const FOREST_BUSH_SCENE: PackedScene = preload("res://assets/environment/bush_packs/bush_01/source/Bush.fbx")
const BRIDGE_SCENE: PackedScene = preload("res://assets/environment/bridges/long_wood_bridge/source/Long Wood Bridge.fbx")
const BRIDGE_ALBEDO: Texture2D = preload("res://assets/environment/bridges/long_wood_bridge/textures/BridgeWood.jpg")
const BRIDGE_NORMAL: Texture2D = preload("res://assets/environment/bridges/long_wood_bridge/textures/BridgeWood_Normal.jpg")
const GRASS_SCENES: Array[PackedScene] = [
	preload("res://assets/models/environment/grass_clump_01.glb"),
	preload("res://assets/models/environment/grass_clump_02.glb")
]
const FOREST_SOIL_TEXTURE: Texture2D = preload("res://assets/textures/terrain/paint/forest_soil_rgba.png")
const MOSSY_ROCK_ALBEDO: Texture2D = preload("res://assets/environment/kyles_rock_pack/Kyle Fuji/Textures/T_mossy_atlas_diffuse_roughness_1.png")
const MOSSY_ROCK_NORMAL: Texture2D = preload("res://assets/environment/kyles_rock_pack/Kyle Fuji/Textures/T_mossy_atlas_normal_1.png")
const MOSSY_ROCK_SCENES: Array[PackedScene] = [
	preload("res://assets/environment/kyles_rock_pack/Kyle Fuji/Models/rock_1_bl.glb"),
	preload("res://assets/environment/kyles_rock_pack/Kyle Fuji/Models/rock_2_bl.glb"),
	preload("res://assets/environment/kyles_rock_pack/Kyle Fuji/Models/rock_3_tr.glb"),
	preload("res://assets/environment/kyles_rock_pack/Kyle Fuji/Models/rock_4_br.glb"),
	preload("res://assets/environment/kyles_rock_pack/Kyle Fuji/Models/rock_5_tl.glb"),
	preload("res://assets/environment/kyles_rock_pack/Kyle Fuji/Models/rock_6_tl.glb")
]
var _grid: GridManager
var _rect: Rect2i

func setup(grid: GridManager) -> void:
	_grid = grid
	_rect = grid.get_arena_rect()
	_block_river()
	_build_water()
	_build_bridge()
	_build_bridge_torches()
	_build_earthen_ford()
	_build_edge_waterfall_and_cave()
	_build_soil_patches_and_rocks()
	_build_forest_floor_props()
	_build_rocky_ridges()
	_scatter_layered_vegetation()
	_build_outer_fog()

static func river_z(rect: Rect2i, x: float) -> float:
	var center := Vector2(rect.position) + Vector2(rect.size) * 0.5
	return center.y + sin((x - center.x) * 0.115) * 3.1 + sin((x - center.x) * 0.037 + 1.2) * 1.4

static func is_water(rect: Rect2i, x: float, z: float) -> bool:
	var center_x := float(rect.position.x) + float(rect.size.x) * 0.5
	var on_bridge := absf(x - center_x) <= BRIDGE_HALF_WIDTH
	var on_ford := absf(x - (center_x + FORD_X_OFFSET)) <= FORD_HALF_WIDTH
	return not on_bridge and not on_ford and absf(z - river_z(rect, x)) < RIVER_HALF_WIDTH

static func sample_height(rect: Rect2i, x: float, z: float) -> float:
	var center := Vector2(rect.position) + Vector2(rect.size) * 0.5
	var local := Vector2(x, z) - center
	var river_distance := absf(z - river_z(rect, x))
	var bridge_weight := 1.0 - smoothstep(BRIDGE_HALF_WIDTH - 0.6, BRIDGE_HALF_WIDTH + 0.7, absf(x - center.x))
	var ford_weight := 1.0 - smoothstep(FORD_HALF_WIDTH - 0.8, FORD_HALF_WIDTH + 1.2, absf(x - (center.x + FORD_X_OFFSET)))
	if river_distance < RIVER_HALF_WIDTH + 3.4:
		var river_height := lerpf(-2.15 + river_distance * 0.07, 0.55 + (river_distance - RIVER_HALF_WIDTH) * 0.32, smoothstep(RIVER_HALF_WIDTH - 1.0, RIVER_HALF_WIDTH + 2.4, river_distance))
		var deck := 0.78 + sin((z - center.y) / (RIVER_HALF_WIDTH * 2.0) * PI) * 0.18
		var bridge_height := lerpf(river_height, deck, bridge_weight * (1.0 - smoothstep(RIVER_HALF_WIDTH + 1.8, RIVER_HALF_WIDTH + 5.2, river_distance)))
		var ford_height := WATER_LEVEL + 0.16 + smoothstep(0.0, RIVER_HALF_WIDTH + 2.5, river_distance) * 1.05
		return lerpf(bridge_height, ford_height, ford_weight)
	# Domain-warped, multi-scale relief: broad landforms carry the silhouette,
	# finer octaves only break repetition and never dominate the playable grade.
	var warped_x := x + sin(z * 0.031) * 5.4 + sin(z * 0.083 + 1.7) * 1.8
	var warped_z := z + sin(x * 0.027 + 0.9) * 4.8 + cos(x * 0.076) * 1.6
	var broad_noise := sin(warped_x * 0.052) * 0.52 + cos(warped_z * 0.043) * 0.46
	var medium_noise := sin((warped_x + warped_z) * 0.091) * 0.24 + cos((warped_x - warped_z) * 0.117) * 0.18
	var fine_noise := sin(warped_x * 0.29 + sin(warped_z * 0.13)) * 0.07
	var ridge_noise := pow(1.0 - absf(sin(warped_x * 0.066 + warped_z * 0.039)), 2.0) * 0.34
	var height := 0.72 + broad_noise + medium_noise + fine_noise + ridge_noise
	height += _hill(local, Vector2(-27.0, -9.0), 5.8, 22.0)
	height += _hill(local, Vector2(25.0, 12.0), 4.2, 19.0)
	height += _hill(local, Vector2(9.0, -29.0), 2.8, 17.0)
	height += _hill(local, Vector2(-12.0, 25.0), -1.6, 20.0)
	var spawn_flat := maxf(1.0 - smoothstep(6.0, 13.0, z - float(rect.position.y)), 1.0 - smoothstep(6.0, 13.0, float(rect.end.y) - z))
	return lerpf(height, 1.15, spawn_flat * 0.82)

static func _hill(point: Vector2, center: Vector2, amplitude: float, radius: float) -> float:
	var d := point.distance_to(center) / radius
	if d >= 1.0:
		return 0.0
	return amplitude * pow(1.0 - d * d, 2.0)

func _block_river() -> void:
	for x: int in range(_rect.position.x + 1, _rect.end.x - 1):
		var center_z := river_z(_rect, float(x))
		for z: int in range(floori(center_z - RIVER_HALF_WIDTH), ceili(center_z + RIVER_HALF_WIDTH) + 1):
			if is_water(_rect, float(x), float(z)):
				_grid.block_cell(Vector2i(x, z))

func _build_water() -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for x: int in range(_rect.position.x + 1, _rect.end.x - 1):
		var x0 := float(x) - 0.5
		var x1 := float(x) + 0.5
		var z0 := river_z(_rect, x0)
		var z1 := river_z(_rect, x1)
		var start := vertices.size()
		vertices.append_array(PackedVector3Array([Vector3(x0, WATER_LEVEL, z0 - RIVER_HALF_WIDTH), Vector3(x1, WATER_LEVEL, z1 - RIVER_HALF_WIDTH), Vector3(x1, WATER_LEVEL, z1 + RIVER_HALF_WIDTH), Vector3(x0, WATER_LEVEL, z0 + RIVER_HALF_WIDTH)]))
		normals.append_array(PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]))
		uvs.append_array(PackedVector2Array([Vector2(x0, z0), Vector2(x1, z1), Vector2(x1, z1 + 10.0), Vector2(x0, z0 + 10.0)]))
		indices.append_array(PackedInt32Array([start, start + 1, start + 2, start, start + 2, start + 3]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var water := MeshInstance3D.new()
	water.name = "ArenaRiver"
	water.mesh = mesh
	water.material_override = _water_material()
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)

func _build_bridge() -> void:
	var center := Vector2(_rect.position) + Vector2(_rect.size) * 0.5
	var root := Node3D.new()
	root.name = "CentralWoodBridge"
	root.position = Vector3(center.x, 0.78, center.y)
	add_child(root)
	var model := BRIDGE_SCENE.instantiate() as Node3D
	if model == null:
		push_warning("Arena bridge model could not be instantiated.")
		return
	model.name = "LongWoodBridgeModel"
	root.add_child(model)
	var bounds := _model_bounds(model)
	var target_length := RIVER_HALF_WIDTH * 2.0 + 7.0
	var long_axis_is_x := bounds.size.x >= bounds.size.z
	var source_length := maxf(bounds.size.x if long_axis_is_x else bounds.size.z, 0.01)
	var source_width := maxf(bounds.size.z if long_axis_is_x else bounds.size.x, 0.01)
	var scale_value := target_length / source_length
	model.scale = Vector3.ONE * scale_value
	if long_axis_is_x:
		model.scale.z = 5.8 / source_width
		model.rotation.y = PI * 0.5
	else:
		model.scale.x = 5.8 / source_width
	var scaled_center := (bounds.position + bounds.size * 0.5) * model.scale
	model.position = Vector3(-scaled_center.x, -8.19 * model.scale.y, -scaled_center.z)
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = BRIDGE_ALBEDO
	wood.normal_enabled = true
	wood.normal_texture = BRIDGE_NORMAL
	wood.roughness = 0.72
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = wood
	var collision_body := StaticBody3D.new()
	collision_body.name = "BridgeCollision"
	collision_body.collision_layer = 1
	collision_body.collision_mask = 0
	root.add_child(collision_body)
	var segments := 12
	var segment_length := target_length / float(segments)
	for index: int in range(segments):
		var shape_node := CollisionShape3D.new()
		shape_node.name = "WalkableDeck_%02d" % index
		var shape := BoxShape3D.new()
		shape.size = Vector3(5.35, 0.38, segment_length)
		shape_node.shape = shape
		var t := (float(index) + 0.5) / float(segments)
		shape_node.position = Vector3(0.0, sin(t * PI) * 0.72 - 0.19, -target_length * 0.5 + (float(index) + 0.5) * segment_length)
		collision_body.add_child(shape_node)


func _build_bridge_torches() -> void:
	var center := Vector2(_rect.position) + Vector2(_rect.size) * 0.5
	var flame_material := StandardMaterial3D.new()
	flame_material.albedo_color = Color(1.0, 0.34, 0.04)
	flame_material.emission_enabled = true
	flame_material.emission = Color(1.0, 0.18, 0.015)
	flame_material.emission_energy_multiplier = 5.5
	flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side_x: float in [-1.0, 1.0]:
		for side_z: float in [-1.0, 1.0]:
			var torch := Node3D.new()
			torch.name = "BridgeTorch"
			torch.position = Vector3(center.x + side_x * 2.72, 1.0, center.y + side_z * (RIVER_HALF_WIDTH + 1.15))
			add_child(torch)
			_add_box(torch, Vector3(0.0, 0.55, 0.0), Vector3(0.13, 1.1, 0.13), _material(Color(0.16, 0.07, 0.025), 0.92))
			var flame := MeshInstance3D.new()
			var flame_mesh := SphereMesh.new()
			flame_mesh.radius = 0.18
			flame_mesh.height = 0.42
			flame.mesh = flame_mesh
			flame.position.y = 1.18
			flame.material_override = flame_material
			torch.add_child(flame)
			var light := OmniLight3D.new()
			light.name = "TorchLight"
			light.position.y = 1.18
			light.light_color = Color(1.0, 0.34, 0.08)
			light.light_energy = 5.2
			light.omni_range = 11.0
			light.omni_attenuation = 1.35
			light.shadow_enabled = true
			torch.add_child(light)

func _build_earthen_ford() -> void:
	var center := Vector2(_rect.position) + Vector2(_rect.size) * 0.5
	var ford_x := center.x + FORD_X_OFFSET
	var ford_z := river_z(_rect, ford_x)
	var material := StandardMaterial3D.new()
	material.albedo_texture = preload("res://assets/environment/terrain/glhf/dry_river_pebbles/dry_river_pebbles_diff_4k.jpg")
	material.normal_enabled = true
	material.normal_texture = preload("res://assets/environment/terrain/glhf/dry_river_pebbles/dry_river_pebbles_nor_gl_4k.jpg")
	material.roughness = 0.94
	var crossing := MeshInstance3D.new()
	crossing.name = "ShallowEarthenFord"
	var plane := PlaneMesh.new()
	plane.size = Vector2(FORD_HALF_WIDTH * 2.0, RIVER_HALF_WIDTH * 2.0 + 5.0)
	plane.subdivide_width = 6
	plane.subdivide_depth = 12
	plane.material = material
	crossing.mesh = plane
	crossing.position = Vector3(ford_x, WATER_LEVEL + 0.18, ford_z)
	add_child(crossing)


func _build_edge_waterfall_and_cave() -> void:
	var root := Node3D.new()
	root.name = "EdgeWaterfallCave"
	add_child(root)
	var center := Vector2(_rect.position) + Vector2(_rect.size) * 0.5
	var ford_x := center.x + FORD_X_OFFSET
	var edge_x := float(_rect.end.x) - 2.7
	var edge_z := river_z(_rect, edge_x)
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color(0.22, 0.55, 0.72, 0.72)
	water_material.emission_enabled = true
	water_material.emission = Color(0.08, 0.25, 0.38)
	water_material.emission_energy_multiplier = 0.65
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	water_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var waterfall := MeshInstance3D.new()
	waterfall.name = "PassableWaterfallCurtain"
	var fall_mesh := QuadMesh.new()
	fall_mesh.size = Vector2(RIVER_HALF_WIDTH * 2.0, 4.8)
	fall_mesh.material = water_material
	waterfall.mesh = fall_mesh
	waterfall.position = Vector3(edge_x, WATER_LEVEL + 1.45, edge_z)
	waterfall.rotation.y = PI * 0.5
	root.add_child(waterfall)

	# The ford continues behind the translucent curtain into a shallow grotto.
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_texture = preload("res://assets/environment/terrain/glhf/dry_river_pebbles/dry_river_pebbles_diff_4k.jpg")
	floor_material.normal_enabled = true
	floor_material.normal_texture = preload("res://assets/environment/terrain/glhf/dry_river_pebbles/dry_river_pebbles_nor_gl_4k.jpg")
	floor_material.roughness = 1.0
	var cave_floor := MeshInstance3D.new()
	cave_floor.name = "WalkableCaveFloor"
	var cave_plane := PlaneMesh.new()
	cave_plane.size = Vector2(maxf(edge_x - ford_x + 1.8, 3.0), 3.8)
	cave_plane.material = floor_material
	cave_floor.mesh = cave_plane
	cave_floor.position = Vector3((ford_x + edge_x) * 0.5 + 0.45, WATER_LEVEL + 0.22, edge_z)
	cave_floor.rotation.y = PI * 0.5
	root.add_child(cave_floor)
	var cave_dark := _material(Color(0.012, 0.016, 0.018), 1.0)
	cave_dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mouth := MeshInstance3D.new()
	mouth.name = "CaveInterior"
	var mouth_mesh := QuadMesh.new()
	mouth_mesh.size = Vector2(3.8, 3.0)
	mouth_mesh.material = cave_dark
	mouth.mesh = mouth_mesh
	mouth.position = Vector3(float(_rect.end.x) - 1.25, WATER_LEVEL + 1.15, edge_z)
	mouth.rotation.y = PI * 0.5
	root.add_child(mouth)
	var rng := RandomNumberGenerator.new()
	rng.seed = 8_377_211
	for index: int in range(9):
		var angle := PI * float(index) / 8.0
		var point := Vector2(float(_rect.end.x) - 1.45, edge_z + cos(angle) * 2.35)
		var rock := MOSSY_ROCK_SCENES[index % MOSSY_ROCK_SCENES.size()].instantiate() as Node3D
		if rock == null:
			continue
		rock.name = "CaveArchRock_%02d" % index
		root.add_child(rock)
		_tint_rock_materials(rock)
		var bounds := _model_bounds(rock)
		var target_height := rng.randf_range(1.0, 1.75)
		var scale_value := target_height / maxf(bounds.size.y, 0.01)
		rock.scale = Vector3.ONE * scale_value
		rock.rotation.y = rng.randf_range(0.0, TAU)
		rock.position = Vector3(point.x, WATER_LEVEL + sin(angle) * 2.25 - bounds.position.y * scale_value, point.y)


func _tint_model_materials(root: Node3D, tint: Color) -> void:
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for surface_index: int in range(mesh_node.mesh.get_surface_count()):
			var source := mesh_node.get_active_material(surface_index)
			if source is StandardMaterial3D:
				var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
				material.albedo_color *= tint
				material.roughness = maxf(material.roughness, 0.84)
				mesh_node.set_surface_override_material(surface_index, material)


func _build_rocky_ridges() -> void:
	var root := Node3D.new()
	root.name = "OpposingRockyRidges"
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9_173_405
	var arena_center := Vector2(_rect.position) + Vector2(_rect.size) * 0.5
	var ridge_centers: Array[Vector2] = [
		arena_center + Vector2(-31.0, -46.0),
		arena_center + Vector2(30.0, 45.0)
	]
	for ridge_index: int in range(ridge_centers.size()):
		for rock_index: int in range(16):
			var angle := float(rock_index) / 15.0 * PI - PI * 0.5
			var spread := Vector2(cos(angle) * 11.0, sin(angle) * 20.0)
			var point := ridge_centers[ridge_index] + spread + Vector2(rng.randf_range(-2.2, 2.2), rng.randf_range(-2.2, 2.2))
			if is_water(_rect, point.x, point.y):
				continue
			var rock := MOSSY_ROCK_SCENES[(rock_index + ridge_index) % MOSSY_ROCK_SCENES.size()].instantiate() as Node3D
			if rock == null:
				continue
			rock.name = "Ridge_%d_Rock_%02d" % [ridge_index, rock_index]
			root.add_child(rock)
			_tint_rock_materials(rock)
			var bounds := _model_bounds(rock)
			var target_height := rng.randf_range(1.4, 3.8)
			var scale_value := target_height / maxf(bounds.size.y, 0.01)
			rock.scale = Vector3(scale_value * rng.randf_range(1.0, 1.55), scale_value, scale_value * rng.randf_range(0.85, 1.25))
			rock.rotation.y = rng.randf_range(0.0, TAU)
			rock.rotation.z = rng.randf_range(-0.12, 0.12)
			rock.position = Vector3(point.x, sample_height(_rect, point.x, point.y) - bounds.position.y * scale_value - 0.25, point.y)


func _scatter_layered_vegetation() -> void:
	var root := Node3D.new()
	root.name = "LayeredNaturalVegetation"
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71_409_233
	var tree_points: Array[Vector2] = []
	for index: int in range(42):
		var point := _random_vegetation_point(rng, 7.0)
		if point == Vector2.INF:
			continue
		tree_points.append(point)
		_add_scaled_scene(root, TREE_SCENES[index % TREE_SCENES.size()], point, rng.randf_range(6.5, 11.5), rng, "Tree_%02d" % index)
	for index: int in range(96):
		var anchor := tree_points[index % tree_points.size()]
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(1.4, 5.8)
		var point := anchor + Vector2(cos(angle), sin(angle)) * radius
		if is_water(_rect, point.x, point.y):
			continue
		_add_scaled_scene(root, BUSH_SCENE, point, rng.randf_range(0.75, 1.65), rng, "UnderstoryBush_%03d" % index)
	for index: int in range(180):
		var point := _random_vegetation_point(rng, 3.0)
		if point == Vector2.INF:
			continue
		var near_tree := tree_points[index % tree_points.size()]
		point = point.lerp(near_tree + Vector2(rng.randf_range(-7.0, 7.0), rng.randf_range(-7.0, 7.0)), 0.58)
		if is_water(_rect, point.x, point.y):
			continue
		_add_scaled_scene(root, GRASS_SCENES[index % GRASS_SCENES.size()], point, rng.randf_range(0.58, 1.28), rng, "DenseGrass_%03d" % index)


func _random_vegetation_point(rng: RandomNumberGenerator, margin: float) -> Vector2:
	for attempt: int in range(24):
		var point := Vector2(
			rng.randf_range(float(_rect.position.x) + margin, float(_rect.end.x) - margin),
			rng.randf_range(float(_rect.position.y) + margin, float(_rect.end.y) - margin)
		)
		var center := Vector2(_rect.position) + Vector2(_rect.size) * 0.5
		var central_sight_corridor := absf(point.x - center.x) < 8.0
		var ford_corridor := absf(point.x - (center.x + FORD_X_OFFSET)) < 6.0
		if not is_water(_rect, point.x, point.y) and not central_sight_corridor and not ford_corridor:
			return point
	return Vector2.INF


func _add_scaled_scene(parent: Node3D, scene: PackedScene, point: Vector2, target_height: float, rng: RandomNumberGenerator, node_name: String) -> void:
	var instance := scene.instantiate() as Node3D
	if instance == null:
		return
	instance.name = node_name
	parent.add_child(instance)
	var bounds := _model_bounds(instance)
	var scale_value := target_height / maxf(bounds.size.y, 0.01)
	instance.scale = Vector3.ONE * scale_value * rng.randf_range(0.9, 1.12)
	instance.rotation.y = rng.randf_range(0.0, TAU)
	instance.position = Vector3(point.x, sample_height(_rect, point.x, point.y) - bounds.position.y * scale_value, point.y)
	instance.add_to_group("fog_cullable_environment")
	instance.set_meta("fog_cell", Vector2i(roundi(point.x), roundi(point.y)))
	if scene == FOREST_BUSH_SCENE:
		_tint_model_materials(instance, Color(0.48, 0.58, 0.36, 1.0))

func _build_soil_patches_and_rocks() -> void:
	var root := Node3D.new()
	root.name = "ForestFloorDetails"
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 48_215_770
	var patch_ratios: Array[Vector2] = [
		Vector2(0.20, 0.32), Vector2(0.80, 0.28), Vector2(0.50, 0.22),
		Vector2(0.47, 0.68), Vector2(0.32, 0.50), Vector2(0.68, 0.55),
		Vector2(0.12, 0.60), Vector2(0.88, 0.45), Vector2(0.18, 0.76),
		Vector2(0.74, 0.78), Vector2(0.84, 0.63),
		Vector2(0.27, 0.18), Vector2(0.39, 0.27), Vector2(0.61, 0.31),
		Vector2(0.73, 0.39), Vector2(0.24, 0.44), Vector2(0.56, 0.47),
		Vector2(0.42, 0.57), Vector2(0.79, 0.58), Vector2(0.29, 0.66),
		Vector2(0.58, 0.72), Vector2(0.38, 0.82), Vector2(0.69, 0.86)
	]
	var soil_material := _soil_patch_material()
	var patch_centers: Array[Vector2] = []
	for index: int in range(patch_ratios.size()):
		var center := Vector2(_rect.position) + Vector2(_rect.size) * patch_ratios[index]
		if is_water(_rect, center.x, center.y):
			continue
		patch_centers.append(center)
		var patch := MeshInstance3D.new()
		patch.name = "BlendedForestSoil_%02d" % index
		var plane := PlaneMesh.new()
		plane.size = Vector2(rng.randf_range(4.0, 7.0), rng.randf_range(3.5, 6.0))
		plane.subdivide_width = 4
		plane.subdivide_depth = 4
		plane.material = soil_material
		patch.mesh = plane
		patch.position = Vector3(center.x, sample_height(_rect, center.x, center.y) + 0.10, center.y)
		patch.rotation.y = rng.randf_range(0.0, TAU)
		root.add_child(patch)
	var rock_body := StaticBody3D.new()
	rock_body.name = "MossyRockCollisions"
	rock_body.collision_layer = 1
	rock_body.collision_mask = 0
	root.add_child(rock_body)
	for index: int in range(24):
		var near_patch := index < 17
		var center := patch_centers[index % patch_centers.size()] if near_patch else Vector2(
			rng.randf_range(float(_rect.position.x + 4), float(_rect.end.x - 4)),
			rng.randf_range(float(_rect.position.y + 8), float(_rect.end.y - 8))
		)
		var position_2d := center + Vector2(rng.randf_range(-3.2, 3.2), rng.randf_range(-2.7, 2.7))
		if is_water(_rect, position_2d.x, position_2d.y):
			continue
		var model := MOSSY_ROCK_SCENES[index % MOSSY_ROCK_SCENES.size()].instantiate() as Node3D
		if model == null:
			continue
		model.name = "MossyRock_%02d" % index
		root.add_child(model)
		_tint_rock_materials(model)
		var bounds := _model_bounds(model)
		var target_height := rng.randf_range(0.38, 1.05)
		var scale_value := target_height / maxf(bounds.size.y, 0.01)
		model.scale = Vector3.ONE * scale_value
		model.rotation.y = rng.randf_range(0.0, TAU)
		model.position = Vector3(position_2d.x, sample_height(_rect, position_2d.x, position_2d.y) - bounds.position.y * scale_value, position_2d.y)
		if target_height > 0.72:
			var cell := Vector2i(roundi(position_2d.x), roundi(position_2d.y))
			_grid.block_cell(cell)
			var collision := CollisionShape3D.new()
			collision.name = "RockHitbox_%02d" % index
			var shape := CylinderShape3D.new()
			shape.radius = target_height * 0.52
			shape.height = target_height
			collision.shape = shape
			collision.position = Vector3(position_2d.x, sample_height(_rect, position_2d.x, position_2d.y) + target_height * 0.5, position_2d.y)
			rock_body.add_child(collision)


func _build_forest_floor_props() -> void:
	var root := Node3D.new()
	root.name = "NaturalForestFloorProps"
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 62_904_117
	var bark_material := _material(Color(0.24, 0.105, 0.035), 0.96)
	var cut_material := _material(Color(0.46, 0.27, 0.105), 0.90)
	var earth_material := _material(Color(0.25, 0.145, 0.065), 1.0)

	# Small stones are visual texture, not tactical obstacles.
	for index: int in range(58):
		var point := _random_vegetation_point(rng, 4.0)
		if point == Vector2.INF:
			continue
		var rock := MOSSY_ROCK_SCENES[index % MOSSY_ROCK_SCENES.size()].instantiate() as Node3D
		if rock == null:
			continue
		rock.name = "LooseStone_%03d" % index
		root.add_child(rock)
		_tint_rock_materials(rock)
		var bounds := _model_bounds(rock)
		var target_height := rng.randf_range(0.12, 0.42)
		var scale_value := target_height / maxf(bounds.size.y, 0.01)
		rock.scale = Vector3(scale_value * rng.randf_range(0.8, 1.5), scale_value, scale_value * rng.randf_range(0.8, 1.35))
		rock.rotation = Vector3(rng.randf_range(-0.16, 0.16), rng.randf_range(0.0, TAU), rng.randf_range(-0.16, 0.16))
		rock.position = Vector3(point.x, sample_height(_rect, point.x, point.y) - bounds.position.y * scale_value - 0.03, point.y)

	# Irregular low clods make exposed soil read as actual broken ground.
	for index: int in range(34):
		var point := _random_vegetation_point(rng, 5.0)
		if point == Vector2.INF:
			continue
		var clod := MeshInstance3D.new()
		clod.name = "EarthClod_%03d" % index
		var mesh := SphereMesh.new()
		mesh.radius = rng.randf_range(0.10, 0.24)
		mesh.height = rng.randf_range(0.10, 0.25)
		mesh.radial_segments = 7
		mesh.rings = 4
		clod.mesh = mesh
		clod.material_override = earth_material
		clod.scale = Vector3(rng.randf_range(1.0, 2.2), rng.randf_range(0.42, 0.78), rng.randf_range(0.8, 1.7))
		clod.rotation.y = rng.randf_range(0.0, TAU)
		clod.position = Vector3(point.x, sample_height(_rect, point.x, point.y) + 0.035, point.y)
		root.add_child(clod)

	# Fallen logs sit near the wooded margins and remain non-blocking.
	for index: int in range(13):
		var point := _random_vegetation_point(rng, 8.0)
		if point == Vector2.INF:
			continue
		var log_root := Node3D.new()
		log_root.name = "FallenLog_%02d" % index
		log_root.position = Vector3(point.x, sample_height(_rect, point.x, point.y) + 0.22, point.y)
		log_root.rotation = Vector3(rng.randf_range(-0.10, 0.10), rng.randf_range(0.0, TAU), rng.randf_range(-0.05, 0.05))
		root.add_child(log_root)
		var log_mesh := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		var radius := rng.randf_range(0.18, 0.34)
		cylinder.top_radius = radius * rng.randf_range(0.72, 0.94)
		cylinder.bottom_radius = radius
		cylinder.height = rng.randf_range(2.1, 4.4)
		cylinder.radial_segments = 9
		cylinder.material = bark_material
		log_mesh.mesh = cylinder
		log_mesh.rotation.z = PI * 0.5
		log_root.add_child(log_mesh)
		for end_sign: float in [-1.0, 1.0]:
			var cut := MeshInstance3D.new()
			var disk := CylinderMesh.new()
			disk.top_radius = radius * 0.88
			disk.bottom_radius = radius * 0.88
			disk.height = 0.025
			disk.radial_segments = 12
			disk.material = cut_material
			cut.mesh = disk
			cut.rotation.z = PI * 0.5
			cut.position.x = end_sign * cylinder.height * 0.5
			log_root.add_child(cut)

	# A second plant silhouette prevents the understory from looking cloned.
	for index: int in range(42):
		var point := _random_vegetation_point(rng, 5.0)
		if point == Vector2.INF:
			continue
		_add_scaled_scene(root, FOREST_BUSH_SCENE, point, rng.randf_range(0.48, 1.15), rng, "GroundPlant_%03d" % index)


func _soil_patch_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;
uniform sampler2D soil_texture : source_color, filter_linear_mipmap_anisotropic;
void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radial = length(centered * vec2(0.88, 1.0));
	float irregular = sin(UV.x * 19.0) * sin(UV.y * 17.0) * 0.055;
	float edge = 1.0 - smoothstep(0.68 + irregular, 0.98 + irregular, radial);
	vec4 soil = texture(soil_texture, UV * 2.2);
	ALBEDO = soil.rgb * vec3(0.72, 0.64, 0.48);
	ROUGHNESS = 0.96;
	ALPHA = edge * mix(0.72, 0.92, soil.a);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("soil_texture", FOREST_SOIL_TEXTURE)
	return material


func _model_bounds(root: Node3D) -> AABB:
	var result := AABB()
	var initialized := false
	var inverse_root := root.global_transform.affine_inverse()
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var transformed := (inverse_root * mesh_node.global_transform) * mesh_node.mesh.get_aabb()
		result = transformed if not initialized else result.merge(transformed)
		initialized = true
	return result


func _tint_rock_materials(root: Node3D) -> void:
	for child: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := child as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for surface_index: int in range(mesh_node.mesh.get_surface_count()):
			var material := StandardMaterial3D.new()
			material.albedo_texture = MOSSY_ROCK_ALBEDO
			var variation := float(absi(hash(mesh_node.name))) / float(2_147_483_647)
			material.albedo_color = Color(0.62, 0.66, 0.52, 1.0).lerp(Color(0.88, 0.82, 0.67, 1.0), clampf(variation, 0.0, 1.0) * 0.48)
			material.uv1_triplanar = true
			material.uv1_world_triplanar = true
			material.uv1_scale = Vector3.ONE * 1.65
			material.normal_enabled = true
			material.normal_texture = MOSSY_ROCK_NORMAL
			material.roughness = 0.90
			mesh_node.set_surface_override_material(surface_index, material)


func _build_outer_fog() -> void:
	var fog := StandardMaterial3D.new()
	fog.albedo_color = Color(0.34, 0.43, 0.56, 0.46)
	fog.emission_enabled = true
	fog.emission = Color(0.22, 0.30, 0.45)
	fog.emission_energy_multiplier = 0.38
	fog.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ax := float(_rect.position.x)
	var az := float(_rect.position.y)
	var ex := float(_rect.end.x)
	var ez := float(_rect.end.y)
	var cx := (ax + ex) * 0.5
	var cz := (az + ez) * 0.5
	# A low cloud sea hides the void without becoming a vertical wall when the
	# camera rotates close to an arena edge. Its top stays below river level.
	var fog_y := WATER_LEVEL - 3.0
	var fog_depth := 4.0
	_add_box(self, Vector3(cx, fog_y, az - 28.0), Vector3(float(_rect.size.x) + 72.0, fog_depth, 56.0), fog)
	_add_box(self, Vector3(cx, fog_y, ez + 28.0), Vector3(float(_rect.size.x) + 72.0, fog_depth, 56.0), fog)
	_add_box(self, Vector3(ax - 28.0, fog_y, cz), Vector3(56.0, fog_depth, float(_rect.size.y) + 112.0), fog)
	_add_box(self, Vector3(ex + 28.0, fog_y, cz), Vector3(56.0, fog_depth, float(_rect.size.y) + 112.0), fog)

func _add_box(parent: Node3D, at: Vector3, size_value: Vector3, material: Material) -> void:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size_value
	node.mesh = box
	node.position = at
	node.material_override = material
	parent.add_child(node)

func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result

func _water_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;
void vertex(){VERTEX.y+=(sin(VERTEX.x*1.3+TIME*1.1)+cos(VERTEX.z*1.7-TIME*0.8))*0.035;}
void fragment(){float r=0.5+0.5*sin((UV.x+UV.y)*2.4+TIME*1.4);ALBEDO=mix(vec3(0.015,0.09,0.18),vec3(0.035,0.34,0.38),r*0.28);ROUGHNESS=0.12;METALLIC=0.06;SPECULAR=0.95;ALPHA=0.82;}
"""
	var result := ShaderMaterial.new()
	result.shader = shader
	return result
