class_name GroundClutterSystem
extends Node3D

const PACK_ROOT := "res://assets/ground_clutter_pack/billboards_alpha/"
const TARGET_INSTANCE_COUNT: int = 9200
const DISTRIBUTION_ATTEMPTS: int = 18_000
const EDGE_MARGIN: float = 2.0

const ASSETS: Array[Dictionary] = [
	{"name": "GrassClump01", "file": "grass_clump_01.png", "size": Vector2(0.82, 0.72), "min_scale": 0.72, "max_scale": 1.28},
	{"name": "GrassClump02", "file": "grass_clump_02.png", "size": Vector2(0.94, 0.82), "min_scale": 0.68, "max_scale": 1.22},
	{"name": "DryGrass", "file": "dry_grass_clump_01.png", "size": Vector2(0.86, 0.76), "min_scale": 0.72, "max_scale": 1.24},
	{"name": "Weed01", "file": "weed_01.png", "size": Vector2(0.62, 0.82), "min_scale": 0.68, "max_scale": 1.18},
	{"name": "Weed02", "file": "weed_02.png", "size": Vector2(0.68, 0.88), "min_scale": 0.66, "max_scale": 1.16},
	{"name": "Pebbles", "file": "pebble_cluster_01.png", "size": Vector2(0.52, 0.34), "min_scale": 0.62, "max_scale": 1.18},
	{"name": "SmallRock", "file": "small_rock_01.png", "size": Vector2(0.56, 0.48), "min_scale": 0.58, "max_scale": 1.25},
	{"name": "Twigs", "file": "twig_clutter_01.png", "size": Vector2(0.72, 0.36), "min_scale": 0.62, "max_scale": 1.22},
]

var _terrain_prototype: TerrainTestPrototype

func setup(terrain_prototype: TerrainTestPrototype) -> void:
	_terrain_prototype = terrain_prototype
	_rebuild()

func _rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()
	var transforms_by_asset: Array[Array] = []
	for unused_asset: Dictionary in ASSETS:
		transforms_by_asset.append([])
	var rng := RandomNumberGenerator.new()
	rng.seed = 84_210_557
	var placed: int = 0
	for attempt: int in range(DISTRIBUTION_ATTEMPTS):
		if placed >= TARGET_INSTANCE_COUNT:
			break
		var position_2d := Vector2(
			rng.randf_range(EDGE_MARGIN, float(TerrainTestPrototype.TERRAIN_SIZE) - EDGE_MARGIN),
			rng.randf_range(EDGE_MARGIN, float(TerrainTestPrototype.TERRAIN_SIZE) - EDGE_MARGIN)
		)
		var weights := _terrain_prototype.get_surface_weights(position_2d.x, position_2d.y)
		var density := _density_for_surface(weights)
		if rng.randf() > density:
			continue
		var asset_id := _choose_asset(weights, rng)
		var definition: Dictionary = ASSETS[asset_id]
		var scale_value := rng.randf_range(float(definition["min_scale"]), float(definition["max_scale"]))
		var lateral_scale := rng.randf_range(0.86, 1.14)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(lateral_scale * scale_value, scale_value, scale_value))
		var height := _terrain_prototype.terrain.data.get_height(Vector3(position_2d.x, 0.0, position_2d.y))
		var vertical_offset := float((definition["size"] as Vector2).y) * scale_value * 0.48
		transforms_by_asset[asset_id].append(Transform3D(basis, Vector3(position_2d.x, height + vertical_offset, position_2d.y)))
		placed += 1
	for asset_id: int in range(ASSETS.size()):
		_create_multimesh(asset_id, transforms_by_asset[asset_id])

func _density_for_surface(weights: Vector3) -> float:
	var grass_density := weights.x * 0.72
	var dry_density := weights.y * 0.48
	var dirt_density := weights.z * 0.27
	return clampf(grass_density + dry_density + dirt_density, 0.12, 0.78)

func _choose_asset(weights: Vector3, rng: RandomNumberGenerator) -> int:
	var roll := rng.randf()
	if weights.z > 0.52:
		if roll < 0.34: return 5
		if roll < 0.58: return 7
		if roll < 0.78: return 6
		if roll < 0.91: return 2
		return 3
	if weights.y > 0.42:
		if roll < 0.48: return 2
		if roll < 0.66: return 3
		if roll < 0.79: return 4
		if roll < 0.9: return 5
		return rng.randi_range(0, 1)
	if roll < 0.39: return 0
	if roll < 0.74: return 1
	if roll < 0.86: return 3
	if roll < 0.95: return 4
	return 2

func _create_multimesh(asset_id: int, transforms: Array) -> void:
	if transforms.is_empty():
		return
	var definition: Dictionary = ASSETS[asset_id]
	var quad := QuadMesh.new()
	quad.size = definition["size"] as Vector2
	quad.orientation = PlaneMesh.FACE_Z
	quad.material = _create_billboard_material(PACK_ROOT + str(definition["file"]))
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index] as Transform3D)
	var instance := MultiMeshInstance3D.new()
	instance.name = str(definition["name"])
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visibility_range_end = 85.0
	instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(instance)

func _create_billboard_material(texture_path: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(texture_path) as Texture2D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.42
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.roughness = 0.92
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material
