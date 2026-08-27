@tool
class_name TerrainTestPrototype
extends Node3D

const TERRAIN_SIZE: int = 256
const TEXTURE_WORLD_SIZE: float = 2.5
const NEUTRAL_NORMAL_ROUGHNESS_PATH := "res://assets/textures/terrain/paint/flat_normal_roughness_1024.png"
const TEXTURE_DEFINITIONS: Array[Dictionary] = [
	{"name": "Grass", "path": "res://assets/textures/terrain/grass/grass_albedo.png", "roughness": 0.88},
	{"name": "Dry Grass", "path": "res://assets/textures/terrain/dry_grass/dry_grass_albedo.png", "roughness": 0.9},
	{"name": "Dirt", "path": "res://assets/textures/terrain/dirt/dirt_albedo.png", "roughness": 0.94},
]

@export_range(0.5, 8.0, 0.1) var texture_world_size: float = TEXTURE_WORLD_SIZE
@export_range(10.0, 160.0, 1.0) var macro_world_size: float = 55.0
@export_range(0.0, 0.25, 0.005) var macro_variation_strength: float = 0.075
@export_range(0.0, 2.0, 0.01) var blend_noise_strength: float = 0.72

@onready var terrain: Terrain3D = $Terrain3D

func _ready() -> void:
	_configure_assets()
	if Engine.is_editor_hint():
		return
	await get_tree().process_frame
	var region := terrain.data.get_region(Vector2i.ZERO)
	if region == null:
		region = terrain.data.add_region_blank(Vector2i.ZERO, false)
		_build_meadow()
	terrain.material.show_colormap = false
	terrain.material.update()
	$GroundClutter.setup(self)

func _configure_assets() -> void:
	var texture_assets: Array[Terrain3DTextureAsset] = []
	var neutral_normal_roughness := load(NEUTRAL_NORMAL_ROUGHNESS_PATH) as Texture2D
	for texture_id: int in range(TEXTURE_DEFINITIONS.size()):
		var definition: Dictionary = TEXTURE_DEFINITIONS[texture_id]
		var asset := Terrain3DTextureAsset.new()
		asset.id = texture_id
		asset.name = str(definition["name"])
		asset.albedo_texture = load(str(definition["path"])) as Texture2D
		asset.normal_texture = neutral_normal_roughness
		asset.uv_scale = 1.0 / texture_world_size
		asset.roughness = float(definition["roughness"])
		texture_assets.append(asset)
	terrain.assets.set_texture_list(texture_assets)
	terrain.assets.update_texture_list()

func _build_meadow() -> void:
	for z: int in range(TERRAIN_SIZE):
		for x: int in range(TERRAIN_SIZE):
			var point := Vector3(float(x), 0.0, float(z))
			terrain.data.set_height(point, _meadow_height(float(x), float(z)))
			var local_slope := _terrain_slope(float(x), float(z))
			var dry_field := _value_noise(Vector2(float(x), float(z)) / 31.0 + Vector2(7.1, 19.4))
			var dirt_field := _value_noise(Vector2(float(x), float(z)) / 43.0 + Vector2(22.8, 3.6))
			var path_center := 128.0 + sin(float(z) * 0.037) * 24.0 + sin(float(z) * 0.091) * 7.0
			var edge_noise := (_value_noise(Vector2(float(x), float(z)) / 4.2) - 0.5) * blend_noise_strength * 3.0
			var path_blend := 1.0 - smoothstep(2.2 + edge_noise, 5.2 + edge_noise, absf(float(x) - path_center))
			if local_slope > 0.48:
				var rock_blend := smoothstep(0.48, 1.35, local_slope)
				terrain.data.set_control_base_id(point, 2)
				terrain.data.set_control_overlay_id(point, 1)
				terrain.data.set_control_blend(point, 0.18 * (1.0 - rock_blend))
			elif path_blend > 0.05:
				terrain.data.set_control_base_id(point, 1)
				terrain.data.set_control_overlay_id(point, 2)
				terrain.data.set_control_blend(point, path_blend)
			elif dirt_field > 0.77:
				terrain.data.set_control_base_id(point, 0)
				terrain.data.set_control_overlay_id(point, 2)
				terrain.data.set_control_blend(point, smoothstep(0.72, 0.88, dirt_field))
			elif dry_field > 0.58:
				terrain.data.set_control_base_id(point, 0)
				terrain.data.set_control_overlay_id(point, 1)
				terrain.data.set_control_blend(point, smoothstep(0.52, 0.78, dry_field))
			else:
				terrain.data.set_control_base_id(point, 0)
				terrain.data.set_control_overlay_id(point, 0)
				terrain.data.set_control_blend(point, 0.0)
			terrain.data.set_control_auto(point, false)
	var region := terrain.data.get_region(Vector2i.ZERO)
	if region != null:
		region.calc_height_range()
	terrain.data.update_maps(Terrain3DRegion.TYPE_HEIGHT, false, false)
	terrain.data.update_maps(Terrain3DRegion.TYPE_CONTROL, false, false)

func _meadow_height(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var rolling_ground := sin(x * 0.029) * 1.4 + cos(z * 0.025) * 1.05
	var erosion := (_value_noise(point / 20.0) - 0.5) * 3.0
	var ridge_west := _rocky_ridge(point, Vector2(48.0, 76.0), Vector2(25.0, 57.0), 21.0)
	var ridge_east := _rocky_ridge(point, Vector2(208.0, 165.0), Vector2(37.0, 68.0), 29.0)
	var outcrop := _rocky_ridge(point, Vector2(194.0, 43.0), Vector2(20.0, 35.0), 14.0)
	return rolling_ground + erosion + ridge_west + ridge_east + outcrop

func _rocky_ridge(point: Vector2, center: Vector2, radius: Vector2, height: float) -> float:
	var delta := (point - center) / radius
	var falloff := smoothstep(1.0, 0.0, delta.length())
	var crags := 0.68 + _value_noise(point / 8.0 + center * 0.17) * 0.32
	var strata := 0.93 + sin((point.x + point.y) * 0.25) * 0.07
	return height * falloff * falloff * crags * strata

func _terrain_slope(x: float, z: float) -> float:
	var left := _meadow_height(maxf(0.0, x - 1.0), z)
	var right := _meadow_height(minf(float(TERRAIN_SIZE - 1), x + 1.0), z)
	var back := _meadow_height(x, maxf(0.0, z - 1.0))
	var front := _meadow_height(x, minf(float(TERRAIN_SIZE - 1), z + 1.0))
	return Vector2(right - left, front - back).length() * 0.5

func get_surface_weights(x: float, z: float) -> Vector3:
	var point := Vector2(x, z)
	var boundary_noise := (_value_noise(point / 4.8) - 0.5) * blend_noise_strength
	var dry_field := _value_noise(point / 31.0 + Vector2(7.1, 19.4))
	var dirt_field := _value_noise(point / 43.0 + Vector2(22.8, 3.6))
	var dry_weight := smoothstep(0.52, 0.78, dry_field + boundary_noise * 0.12)
	var dirt_weight := smoothstep(0.72, 0.88, dirt_field + boundary_noise * 0.1) * 0.72
	var path_center := 128.0 + sin(z * 0.037) * 24.0 + sin(z * 0.091) * 7.0
	var path_edge := (_value_noise(point / 4.2) - 0.5) * blend_noise_strength * 3.0
	var path_weight := 1.0 - smoothstep(2.2 + path_edge, 5.2 + path_edge, absf(x - path_center))
	dirt_weight = maxf(dirt_weight, path_weight)
	var grass_weight := maxf(0.0, 1.0 - maxf(dry_weight, dirt_weight))
	var total := maxf(grass_weight + dry_weight + dirt_weight, 0.001)
	return Vector3(grass_weight, dry_weight, dirt_weight) / total

func _value_noise(point: Vector2) -> float:
	var cell := Vector2(floorf(point.x), floorf(point.y))
	var local := Vector2(point.x - floorf(point.x), point.y - floorf(point.y))
	local = local * local * (Vector2.ONE * 3.0 - local * 2.0)
	var a := _hash(cell)
	var b := _hash(cell + Vector2.RIGHT)
	var c := _hash(cell + Vector2.DOWN)
	var d := _hash(cell + Vector2.ONE)
	return lerpf(lerpf(a, b, local.x), lerpf(c, d, local.x), local.y)

func _hash(point: Vector2) -> float:
	var value := sin(point.dot(Vector2(127.1, 311.7))) * 43758.5453
	return value - floorf(value)
