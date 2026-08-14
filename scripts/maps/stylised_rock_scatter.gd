class_name StylisedRockScatter
extends Node3D

const ROCK_COLLECTION: PackedScene = preload("res://assets/environment/stylised_rocks/source/Stylised_Rock_Collection.fbx")
const ROCK_ALBEDO: Texture2D = preload("res://assets/environment/stylised_rocks/textures/M_Mossy_Rock_BaseColour.png")
const ROCK_NORMAL: Texture2D = preload("res://assets/environment/stylised_rocks/textures/M_Mossy_Rock_NormalOpenGL.png")
const ROCK_ROUGHNESS: Texture2D = preload("res://assets/environment/stylised_rocks/textures/M_Mossy_Rock_Roughness.png")

const TRAIL_ROCK_COUNT: int = 54
const HILL_ROCK_COUNT: int = 60
const WILD_ROCK_COUNT: int = 18
const LANDMARK_ROCK_COUNT: int = 4
const RIVERSIDE_ROCK_COUNT: int = 90
const WATER_LEVEL: float = -1.7

var _grid_manager: GridManager
var _meshes: Array[Mesh] = []
var _grass_clearances: Array[Vector3] = []
var _collision_candidates: Array[Dictionary] = []


func setup(grid_manager: GridManager) -> void:
	_grid_manager = grid_manager
	_grass_clearances.clear()
	_collision_candidates.clear()
	_load_collection_meshes()
	if _meshes.is_empty():
		push_warning("StylisedRockScatter: imported collection contains no usable meshes")
		return
	var transforms_by_mesh: Array[Array] = []
	transforms_by_mesh.resize(_meshes.size())
	for index: int in range(transforms_by_mesh.size()):
		transforms_by_mesh[index] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 8_140_426
	_scatter_trail_edges(rng, transforms_by_mesh)
	_scatter_riverbanks(rng, transforms_by_mesh)
	_scatter_hill(rng, transforms_by_mesh)
	_scatter_wild(rng, transforms_by_mesh)
	_scatter_landmarks(rng, transforms_by_mesh)
	for mesh_index: int in range(_meshes.size()):
		_create_batch(mesh_index, transforms_by_mesh[mesh_index])


func _load_collection_meshes() -> void:
	_meshes.clear()
	var collection := ROCK_COLLECTION.instantiate()
	var material := _create_rock_material()
	var candidates: Array[Mesh] = []
	for child: Node in collection.find_children("*", "MeshInstance3D", true, false):
		var source := child as MeshInstance3D
		if source.mesh == null or source.mesh.get_surface_count() == 0:
			continue
		candidates.append(source.mesh)
	# The pack contains hundreds of separate pieces. A curated, evenly-spaced
	# sample preserves silhouette variety without creating a draw-call-sized
	# MultiMesh batch for nearly every individual rock.
	var variant_count := mini(8, candidates.size())
	for variant_index: int in range(variant_count):
		var source_index := 0 if variant_count == 1 else roundi(float(variant_index) * float(candidates.size() - 1) / float(variant_count - 1))
		var mesh_copy := candidates[source_index].duplicate(true) as Mesh
		for surface_index: int in range(mesh_copy.get_surface_count()):
			mesh_copy.surface_set_material(surface_index, material)
		_meshes.append(mesh_copy)
	collection.queue_free()


func _scatter_trail_edges(rng: RandomNumberGenerator, batches: Array[Array]) -> void:
	var placed: int = 0
	var attempts: int = 0
	while placed < TRAIL_ROCK_COUNT and attempts < 4000:
		attempts += 1
		var z := rng.randf_range(18.0, 242.0)
		var center_x := _trail_center_x(z)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var x := center_x + side * rng.randf_range(4.0, 9.0)
		if not _can_place(x, z, 0.46, 1.2):
			continue
		_append_rock(rng, batches, x, z, rng.randf_range(0.65, 2.15), rng.randf_range(0.64, 1.12))
		placed += 1


func _scatter_riverbanks(rng: RandomNumberGenerator, batches: Array[Array]) -> void:
	var placed: int = 0
	var attempts: int = 0
	while placed < RIVERSIDE_ROCK_COUNT and attempts < RIVERSIDE_ROCK_COUNT * 30:
		attempts += 1
		var use_branch := rng.randf() < 0.38
		var x: float
		var z: float
		var semi_submerged := rng.randf() < 0.28
		if use_branch:
			z = rng.randf_range(114.0, 226.0)
			var branch_side := -1.0 if rng.randf() < 0.5 else 1.0
			x = _ravine_center(z) + branch_side * (rng.randf_range(4.2, 5.1) if semi_submerged else rng.randf_range(7.2, 11.8))
		else:
			x = rng.randf_range(7.0, 249.0)
			var river_side := -1.0 if rng.randf() < 0.5 else 1.0
			z = _river_center(x) + river_side * (rng.randf_range(5.8, 7.1) if semi_submerged else rng.randf_range(9.0, 14.2))
		# Keep the ford readable and traversable instead of building a rock wall
		# across the authored route.
		if _trail_distance(x, z) < 5.8:
			continue
		if not semi_submerged and not _can_place(x, z, 0.72, 0.08):
			continue
		var target_height := rng.randf_range(3.1, 5.6) if semi_submerged else rng.randf_range(0.38, 1.35)
		if not semi_submerged and rng.randf() < 0.16:
			target_height = rng.randf_range(1.35, 2.35)
		# Water rocks always use the actual bed height. Their size, not a floating
		# origin at the waterline, determines how much remains above the surface.
		_append_rock(rng, batches, x, z, target_height, rng.randf_range(0.70, 1.26))
		placed += 1


func _scatter_hill(rng: RandomNumberGenerator, batches: Array[Array]) -> void:
	var placed: int = 0
	var attempts: int = 0
	while placed < HILL_ROCK_COUNT and attempts < 2500:
		attempts += 1
		var angle := rng.randf_range(0.0, TAU)
		var radius := sqrt(rng.randf()) * rng.randf_range(18.0, 62.0)
		var x := 208.0 + cos(angle) * radius
		var z := 54.0 + sin(angle) * radius * 0.72
		if not _can_place(x, z, 0.72, 2.4):
			continue
		_append_rock(rng, batches, x, z, rng.randf_range(1.1, 3.4), rng.randf_range(0.72, 1.20))
		placed += 1


func _scatter_wild(rng: RandomNumberGenerator, batches: Array[Array]) -> void:
	var placed: int = 0
	var attempts: int = 0
	while placed < WILD_ROCK_COUNT and attempts < 1800:
		attempts += 1
		var x := rng.randf_range(10.0, 246.0)
		var z := rng.randf_range(10.0, 246.0)
		if _trail_distance(x, z) < 12.0 or not _can_place(x, z, 0.60, 2.0):
			continue
		_append_rock(rng, batches, x, z, rng.randf_range(0.9, 2.7), rng.randf_range(0.68, 1.18))
		placed += 1


func _scatter_landmarks(rng: RandomNumberGenerator, batches: Array[Array]) -> void:
	var points: Array[Vector2] = [Vector2(24.0, 46.0), Vector2(226.0, 38.0), Vector2(205.0, 196.0), Vector2(48.0, 218.0)]
	for point: Vector2 in points:
		var x := point.x + rng.randf_range(-4.0, 4.0)
		var z := point.y + rng.randf_range(-4.0, 4.0)
		_append_rock(rng, batches, x, z, rng.randf_range(5.8, 8.2), rng.randf_range(0.82, 1.18))


func _append_rock(rng: RandomNumberGenerator, batches: Array[Array], x: float, z: float, target_height: float, width_ratio: float, height_override: float = NAN) -> void:
	var mesh_index := rng.randi_range(0, _meshes.size() - 1)
	var bounds := _meshes[mesh_index].get_aabb()
	var uniform_scale := target_height / maxf(bounds.size.y, 0.01)
	var rock_scale := Vector3(uniform_scale * width_ratio, uniform_scale, uniform_scale * rng.randf_range(0.82, 1.16))
	var slope := _estimate_slope(x, z)
	var rock_basis := _basis_aligned_to_normal(_terrain_normal(x, z), rng.randf_range(0.0, TAU)).scaled(rock_scale)
	var burial := target_height * (0.12 + clampf(slope, 0.0, 1.0) * 0.10)
	var height := _grid_manager.terrain_height(x, z) if is_nan(height_override) else height_override
	batches[mesh_index].append(Transform3D(rock_basis, Vector3(x, height - burial, z)))
	if target_height >= 1.35:
		_collision_candidates.append({
			"position": Vector3(x, height - burial, z),
			"radius": maxf(0.55, target_height * width_ratio * 0.46),
			"height": target_height * 0.82,
		})
	# Grass cards intersecting an opaque boulder look as if they were rendered
	# through it. Keep the meadow dense, but reserve only the actual footprint
	# (plus a very small natural margin) of every generated rock.
	var footprint_x := bounds.size.x * rock_scale.x * 0.5
	var footprint_z := bounds.size.z * rock_scale.z * 0.5
	var clearance := maxf(0.42, maxf(footprint_x, footprint_z) + minf(target_height * 0.10, 0.45))
	_grass_clearances.append(Vector3(x, z, clearance))


func _create_batch(mesh_index: int, transforms: Array) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _meshes[mesh_index]
	multimesh.instance_count = transforms.size()
	for instance_index: int in range(transforms.size()):
		multimesh.set_instance_transform(instance_index, transforms[instance_index] as Transform3D)
	var batch := MultiMeshInstance3D.new()
	batch.name = "StylisedRocks_%02d" % (mesh_index + 1)
	batch.multimesh = multimesh
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	batch.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	# Rocks are never an LOD/fade object. Explicitly disable range fading so a
	# parent/environment default cannot turn them translucent near the camera.
	batch.visibility_range_begin = 0.0
	batch.visibility_range_end = 0.0
	batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	add_child(batch)


func get_grass_clearances() -> Array[Vector3]:
	return _grass_clearances.duplicate()


func get_collision_candidates() -> Array[Dictionary]:
	return _collision_candidates.duplicate(true)


func _can_place(x: float, z: float, max_slope: float, water_margin: float) -> bool:
	if x < 7.0 or x > 249.0 or z < 7.0 or z > 249.0:
		return false
	var height := _grid_manager.terrain_height(x, z)
	return height > WATER_LEVEL + water_margin and _estimate_slope(x, z) <= max_slope and not _is_water_at(x, z)


func _trail_center_x(z: float) -> float:
	# Keep synchronized with the cubic Bezier trail mask in terrain_ground.gdshader.
	var t := clampf((246.0 - z) / 226.0, 0.0, 1.0)
	var inverse := 1.0 - t
	return inverse * inverse * inverse * 35.0 + 3.0 * inverse * inverse * t * 45.0 + 3.0 * inverse * t * t * 225.0 + t * t * t * 218.0


func _trail_distance(x: float, z: float) -> float:
	return absf(x - _trail_center_x(z))


func _river_center(x: float) -> float:
	return 101.0 + sin(x * 0.045) * 11.0 + sin(x * 0.013 + 1.7) * 5.0


func _ravine_center(z: float) -> float:
	return 72.0 + sin(z * 0.052) * 5.0


func _is_water_at(x: float, z: float) -> bool:
	if absf(z - _river_center(x)) <= 7.0:
		return true
	return z >= 110.0 and z <= 231.0 and absf(x - _ravine_center(z)) <= 5.0


func _estimate_slope(x: float, z: float) -> float:
	var dx := _grid_manager.terrain_height(x + 1.0, z) - _grid_manager.terrain_height(x - 1.0, z)
	var dz := _grid_manager.terrain_height(x, z + 1.0) - _grid_manager.terrain_height(x, z - 1.0)
	return Vector2(dx, dz).length() * 0.5


func _terrain_normal(x: float, z: float) -> Vector3:
	var radius := 1.15
	var left := _grid_manager.terrain_height(x - radius, z)
	var right := _grid_manager.terrain_height(x + radius, z)
	var back := _grid_manager.terrain_height(x, z - radius)
	var forward := _grid_manager.terrain_height(x, z + radius)
	return Vector3(left - right, radius * 2.0, back - forward).normalized()


func _basis_aligned_to_normal(normal: Vector3, yaw: float) -> Basis:
	var tangent := Vector3.FORWARD.cross(normal).normalized()
	if tangent.length_squared() < 0.001:
		tangent = Vector3.RIGHT
	var forward := normal.cross(tangent).normalized()
	var aligned := Basis(tangent, normal, forward).orthonormalized()
	return Basis(normal, yaw) * aligned


func _create_rock_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = ROCK_ALBEDO
	material.normal_enabled = true
	material.normal_texture = ROCK_NORMAL
	material.roughness_texture = ROCK_ROUGHNESS
	material.roughness = 0.92
	material.albedo_color = Color(0.84, 0.82, 0.72)
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material
