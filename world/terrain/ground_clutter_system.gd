class_name GroundClutterSystem
extends Node3D

const PACK_ROOT := "res://assets/ground_clutter_pack/billboards_alpha/"
const TARGET_INSTANCE_COUNT: int = 9200
const DISTRIBUTION_ATTEMPTS: int = 18_000
const EDGE_MARGIN: float = 2.0
const BATTLE_SIZE := Vector2(160.0, 190.0)

const ASSETS: Array[Dictionary] = [
	{"name": "GrassClump01", "file": "grass_clump_01_cutout.png", "size": Vector2(0.82, 0.72), "min_scale": 0.48, "max_scale": 1.62},
	{"name": "GrassClump02", "file": "grass_clump_02_cutout.png", "size": Vector2(0.94, 0.82), "min_scale": 0.44, "max_scale": 1.58},
	{"name": "DryGrass", "file": "dry_grass_clump_01_cutout.png", "size": Vector2(0.86, 0.76), "min_scale": 0.5, "max_scale": 1.55},
	{"name": "Weed01", "file": "weed_01_cutout.png", "size": Vector2(0.62, 0.82), "min_scale": 0.42, "max_scale": 1.48},
	{"name": "Weed02", "file": "weed_02_cutout.png", "size": Vector2(0.68, 0.88), "min_scale": 0.4, "max_scale": 1.5},
	{"name": "Pebbles", "file": "pebble_cluster_01_cutout.png", "size": Vector2(0.76, 0.46), "min_scale": 0.48, "max_scale": 1.62},
	{"name": "SmallRock", "file": "small_rock_01_cutout.png", "size": Vector2(0.82, 0.68), "min_scale": 0.5, "max_scale": 1.72},
	{"name": "Twigs", "file": "twig_clutter_01_cutout.png", "size": Vector2(0.94, 0.46), "min_scale": 0.48, "max_scale": 1.64},
]

var _terrain_prototype: TerrainTestPrototype
var _battle_grid: Node3D
var _battle_is_arena: bool = false

func setup(terrain_prototype: TerrainTestPrototype) -> void:
	_terrain_prototype = terrain_prototype
	_rebuild()

func setup_battle(grid_manager: Node3D, is_arena: bool) -> void:
	_battle_grid = grid_manager
	_battle_is_arena = is_arena
	_rebuild_battle()

func _rebuild_battle() -> void:
	for child: Node in get_children():
		child.queue_free()
	var transforms_by_asset: Array[Array] = []
	for unused_asset: Dictionary in ASSETS:
		transforms_by_asset.append([])
	var rng := RandomNumberGenerator.new()
	rng.seed = 61_904_327 if not _battle_is_arena else 91_502_113
	var area := Rect2(Vector2.ZERO, BATTLE_SIZE)
	var arena_rect: Rect2i = _battle_grid.call("get_arena_rect")
	if _battle_is_arena and arena_rect.has_area():
		area = Rect2(Vector2(arena_rect.position), Vector2(arena_rect.size))
	var target_count := 6100 if not _battle_is_arena else clampi(roundi(area.get_area() * 0.22), 180, 720)
	if GameSession.arena_test_mode:
		target_count = 2400
	var attempts := target_count * 4
	var placed: int = 0
	for attempt: int in range(attempts):
		if placed >= target_count:
			break
		var position_2d := Vector2(
			rng.randf_range(area.position.x + 0.6, area.end.x - 0.6),
			rng.randf_range(area.position.y + 0.6, area.end.y - 0.6)
		)
		if _battle_is_arena and _battle_grid.has_method("is_arena_test_water") and bool(_battle_grid.call("is_arena_test_water", position_2d.x, position_2d.y)):
			continue
		var weights := _battle_surface_weights(position_2d)
		var arena_density := 0.86 if GameSession.arena_test_mode else 0.58
		if rng.randf() > _density_for_surface(weights) * (arena_density if _battle_is_arena else 0.82):
			continue
		var asset_id := _choose_asset(weights, rng)
		var definition: Dictionary = ASSETS[asset_id]
		var scale_value := rng.randf_range(float(definition["min_scale"]), float(definition["max_scale"]))
		var lateral_scale := rng.randf_range(0.86, 1.14)
		var instance_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(lateral_scale * scale_value, scale_value, scale_value))
		var height := float(_battle_grid.call("terrain_height", position_2d.x, position_2d.y))
		var vertical_offset := float((definition["size"] as Vector2).y) * scale_value * 0.48
		transforms_by_asset[asset_id].append(Transform3D(instance_basis, Vector3(position_2d.x, height + vertical_offset, position_2d.y)))
		placed += 1
	for asset_id: int in range(ASSETS.size()):
		_create_multimesh(asset_id, transforms_by_asset[asset_id])

func _battle_surface_weights(position_2d: Vector2) -> Vector3:
	var boundary_noise := (_value_noise(position_2d / 4.8) - 0.5) * 0.72
	var dry_field := _value_noise(position_2d / 23.0 + Vector2(4.7, 11.2))
	var dirt_field := _value_noise(position_2d / 37.0 + Vector2(19.3, 2.8))
	var dry_weight := smoothstep(0.5, 0.75, dry_field + boundary_noise * 0.18)
	var dirt_weight := smoothstep(0.66, 0.86, dirt_field + boundary_noise * 0.14) * 0.72
	if _battle_is_arena:
		dirt_weight = lerpf(0.52, 0.82, dirt_field)
		dry_weight = lerpf(0.22, 0.48, dry_field)
	else:
		var north_south_x := BATTLE_SIZE.x * 0.5 + sin(position_2d.y * 0.055) * 12.0
		var diagonal_z := 30.0 + position_2d.x * 0.72 + sin(position_2d.x * 0.09) * 6.0
		var east_west_z := 132.0 + sin(position_2d.x * 0.07) * 10.0
		var trail_distance := minf(absf(position_2d.x - north_south_x), minf(absf(position_2d.y - diagonal_z), absf(position_2d.y - east_west_z)))
		var irregular_edge := (_value_noise(position_2d / 3.1 + Vector2(8.2, 3.4)) - 0.5) * 0.72
		dirt_weight = maxf(dirt_weight, 1.0 - smoothstep(1.65 + irregular_edge, 3.0 + irregular_edge, trail_distance))
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
		var instance_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(lateral_scale * scale_value, scale_value, scale_value))
		var height := _terrain_prototype.terrain.data.get_height(Vector3(position_2d.x, 0.0, position_2d.y))
		var vertical_offset := float((definition["size"] as Vector2).y) * scale_value * 0.48
		transforms_by_asset[asset_id].append(Transform3D(instance_basis, Vector3(position_2d.x, height + vertical_offset, position_2d.y)))
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
	if weights.z > 0.32:
		if roll < 0.31: return 5
		if roll < 0.56: return 7
		if roll < 0.8: return 6
		if roll < 0.92: return 2
		return 3
	if weights.y > 0.42:
		if roll < 0.48: return 2
		if roll < 0.66: return 3
		if roll < 0.79: return 4
		if roll < 0.9: return 5
		return rng.randi_range(0, 1)
	if roll < 0.34: return 0
	if roll < 0.64: return 1
	if roll < 0.76: return 3
	if roll < 0.86: return 4
	if roll < 0.92: return 5
	if roll < 0.96: return 7
	if roll < 0.985: return 6
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

func _create_billboard_material(texture_path: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;
uniform sampler2D source_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec3 palette_tint : source_color = vec3(0.70, 0.78, 0.52);
uniform float saturation : hint_range(0.0, 1.0) = 0.66;
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;
void fragment() {
	vec4 sample_color = texture(source_texture, UV);
	if (sample_color.a < alpha_cutoff) { discard; }
	float luminance = dot(sample_color.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(luminance), sample_color.rgb, saturation) * palette_tint;
	ROUGHNESS = 0.94;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("source_texture", load(texture_path) as Texture2D)
	return material
