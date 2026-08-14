class_name SoloTrailStreamedSector
extends Node3D

const SIZE: float = 256.0
const CELLS: int = 64
const WATER_LEVEL: float = -1.7
const TREE_COUNT: int = 90
const GRASS_COUNT: int = 2400
const ROCK_COUNT: int = 32
const TREE_MESHES: Array[Mesh] = [
	preload("res://assets/environment/tree_packs/tree/Tree/Tree.obj"),
	preload("res://assets/environment/tree_packs/tree_02/Tree 02/Tree.obj"),
]
const GRASS_MESH: Mesh = preload("res://addons/simplegrasstextured/default_mesh.tres")
const GRASS_TEXTURE: Texture2D = preload("res://assets/environment/grass_textures/realtime/textures/Plate2.png")
const TERRAIN_MATERIAL: ShaderMaterial = preload("res://world/terrain/materials/terrain_ground_material.tres")
const WATER_SHADER: Shader = preload("res://world/terrain/shaders/solo_trail_water.gdshader")
const PROXIMITY_COLLISIONS: Script = preload("res://scripts/maps/proximity_obstacle_collisions.gd")

var coordinate := Vector2i.ZERO
var _grid_manager: GridManager


func configure(sector_coordinate: Vector2i, grid_manager: GridManager) -> void:
	coordinate = sector_coordinate
	_grid_manager = grid_manager
	position = Vector3(float(coordinate.x) * SIZE, 0.0, float(coordinate.y) * SIZE)
	name = "SoloTrailSector_%d_%d" % [coordinate.x, coordinate.y]


func _ready() -> void:
	_build_terrain()
	_build_water()
	_build_decorations()


func _build_terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := SIZE / float(CELLS)
	# Shared grid vertices reduce expensive global-height evaluations roughly sixfold.
	for vertex_z: int in range(CELLS + 1):
		for vertex_x: int in range(CELLS + 1):
			var point := _terrain_point(float(vertex_x) * step, float(vertex_z) * step)
			surface.set_uv(Vector2(point.x, point.z) / 8.0)
			surface.add_vertex(point)
	for cell_z: int in range(CELLS):
		for cell_x: int in range(CELLS):
			var top_left := cell_z * (CELLS + 1) + cell_x
			var top_right := top_left + 1
			var bottom_left := (cell_z + 1) * (CELLS + 1) + cell_x
			var bottom_right := bottom_left + 1
			for index: int in [top_left, top_right, bottom_right, top_left, bottom_right, bottom_left]:
				surface.add_index(index)
	surface.generate_normals()
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
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)
	add_child(body)


func _terrain_point(local_x: float, local_z: float) -> Vector3:
	var global_x := global_position.x + local_x
	var global_z := global_position.z + local_z
	return Vector3(local_x, _grid_manager.terrain_height(global_x, global_z), local_z)


func _build_water() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var origin_x := float(coordinate.x) * SIZE
	var origin_z := float(coordinate.y) * SIZE
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


func _build_decorations() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 71_391_117 + coordinate.x * 91_873 + coordinate.y * 31_337
	var trees: Array[Array] = [[], []]
	var grass: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var tree_collisions: Array[Dictionary] = []
	var rock_collisions: Array[Dictionary] = []
	for _index: int in range(TREE_COUNT * 4):
		if trees[0].size() + trees[1].size() >= TREE_COUNT:
			break
		var p := _random_global_point(rng)
		if not _can_decorate(p, 7.0, 0.48):
			continue
		var variant := rng.randi_range(0, 1)
		var bounds := TREE_MESHES[variant].get_aabb()
		var target_height := rng.randf_range(9.0, 18.0)
		var scale_value := target_height / maxf(bounds.size.y, 0.01)
		var local := Vector3(p.x - global_position.x, _grid_manager.terrain_height(p.x, p.y), p.y - global_position.z)
		trees[variant].append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale_value), local))
		tree_collisions.append({"position": Vector3(p.x, local.y, p.y), "radius": clampf(target_height * 0.05, 0.45, 1.0), "height": target_height * 0.7})
	for _index: int in range(GRASS_COUNT):
		var p := _random_global_point(rng)
		if not _can_decorate(p, 4.0, 0.32):
			continue
		var scale_value := rng.randf_range(0.7, 1.45)
		grass.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale_value, scale_value, scale_value)), Vector3(p.x - global_position.x, _grid_manager.terrain_height(p.x, p.y) + 0.02, p.y - global_position.z)))
	for _index: int in range(ROCK_COUNT):
		var p := _random_global_point(rng)
		if _grid_manager.solo_trail_path_distance(p.x, p.y) < 5.5:
			continue
		var scale_value := rng.randf_range(0.5, 2.3)
		var ground := _grid_manager.terrain_height(p.x, p.y)
		rocks.append(Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale_value, scale_value * 0.72, scale_value * 0.88)), Vector3(p.x - global_position.x, ground - scale_value * 0.25, p.y - global_position.z)))
		if scale_value > 1.15:
			rock_collisions.append({"position": Vector3(p.x, ground - scale_value * 0.25, p.y), "radius": scale_value * 0.7, "height": scale_value * 1.2})
	for variant: int in range(2):
		_add_multimesh("StreamedTrees_%d" % variant, TREE_MESHES[variant], trees[variant], true, null)
	var grass_material := StandardMaterial3D.new()
	grass_material.albedo_texture = GRASS_TEXTURE
	grass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	grass_material.alpha_scissor_threshold = 0.28
	grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_material.albedo_color = Color(0.73, 0.76, 0.54)
	_add_multimesh("StreamedGrass", GRASS_MESH, grass, false, grass_material)
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.75
	rock_mesh.height = 1.35
	rock_mesh.radial_segments = 8
	rock_mesh.rings = 5
	var rock_material := StandardMaterial3D.new()
	rock_material.albedo_color = Color(0.25, 0.27, 0.22)
	rock_material.roughness = 0.96
	_add_multimesh("StreamedRocks", rock_mesh, rocks, true, rock_material)
	var collision_manager := PROXIMITY_COLLISIONS.new() as Node3D
	collision_manager.name = "SectorProximityCollisions"
	add_child(collision_manager)
	collision_manager.call("setup", tree_collisions, rock_collisions)


func _random_global_point(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(global_position.x + rng.randf_range(3.0, SIZE - 3.0), global_position.z + rng.randf_range(3.0, SIZE - 3.0))


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
