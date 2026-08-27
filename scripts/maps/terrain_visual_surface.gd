class_name TerrainVisualSurface
extends Node3D

const MATERIAL_COUNT := 4
const CHUNK_SIZE := 16
const TERRAIN_SHADER: Shader = preload("res://world/terrain/shaders/terrain_paint_pbr.gdshader")

var _terrain_surface: TerrainMapSurface
var _material: ShaderMaterial
var _chunks: Dictionary[Vector2i, MeshInstance3D] = {}

func setup(terrain_surface: TerrainMapSurface, definitions: Array[Dictionary]) -> void:
	_terrain_surface = terrain_surface
	_material = _create_material(definitions)
	rebuild()

func rebuild() -> void:
	for z: int in range(ceili(float(TerrainMapSurface.MAP_SIZE.y - 1) / CHUNK_SIZE)):
		for x: int in range(ceili(float(TerrainMapSurface.MAP_SIZE.x - 1) / CHUNK_SIZE)):
			_build_chunk(Vector2i(x, z))

func rebuild_region(center: Vector3, radius: float) -> void:
	var min_c := Vector2i(maxi(0, floori((center.x - radius - 1.0) / CHUNK_SIZE)), maxi(0, floori((center.z - radius - 1.0) / CHUNK_SIZE)))
	var max_c := Vector2i(mini(9, floori((center.x + radius + 1.0) / CHUNK_SIZE)), mini(11, floori((center.z + radius + 1.0) / CHUNK_SIZE)))
	for z: int in range(min_c.y, max_c.y + 1):
		for x: int in range(min_c.x, max_c.x + 1):
			_build_chunk(Vector2i(x, z))

func _build_chunk(chunk: Vector2i) -> void:
	var instance := _chunks.get(chunk) as MeshInstance3D
	if instance == null:
		instance = MeshInstance3D.new()
		instance.name = "TerrainChunk_%d_%d" % [chunk.x, chunk.y]
		_chunks[chunk] = instance
		add_child(instance)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var end_x := mini((chunk.x + 1) * CHUNK_SIZE, TerrainMapSurface.MAP_SIZE.x - 1)
	var end_z := mini((chunk.y + 1) * CHUNK_SIZE, TerrainMapSurface.MAP_SIZE.y - 1)
	for z: int in range(chunk.y * CHUNK_SIZE, end_z):
		for x: int in range(chunk.x * CHUNK_SIZE, end_x):
			_append_cell(vertices, normals, colors, x, z)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _material)
	instance.mesh = mesh

func _append_cell(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, x: int, z: int) -> void:
	for point: Vector3 in [_point(x, z), _point(x, z + 1), _point(x + 1, z), _point(x + 1, z), _point(x, z + 1), _point(x + 1, z + 1)]:
		vertices.append(point + Vector3.UP * 0.12)
		normals.append(_smooth_normal(roundi(point.x), roundi(point.z)))
		colors.append(_paint_weights(point))

func _point(x: int, z: int) -> Vector3:
	return Vector3(float(x), _terrain_surface.get_height(float(x), float(z)), float(z))

func _smooth_normal(x: int, z: int) -> Vector3:
	var left := _terrain_surface.get_height(float(maxi(0, x - 1)), float(z))
	var right := _terrain_surface.get_height(float(mini(TerrainMapSurface.MAP_SIZE.x - 1, x + 1)), float(z))
	var back := _terrain_surface.get_height(float(x), float(maxi(0, z - 1)))
	var forward := _terrain_surface.get_height(float(x), float(mini(TerrainMapSurface.MAP_SIZE.y - 1, z + 1)))
	return Vector3(left - right, 2.0, back - forward).normalized()

func _paint_weights(point: Vector3) -> Color:
	var base_id := clampi(_terrain_surface.terrain.data.get_control_base_id(point), 0, 3)
	var overlay_id := clampi(_terrain_surface.terrain.data.get_control_overlay_id(point), 0, 3)
	var blend := smoothstep(0.0, 1.0, clampf(_terrain_surface.terrain.data.get_control_blend(point), 0.0, 1.0))
	var weights := Vector4.ZERO
	weights[base_id] += 1.0 - blend
	weights[overlay_id] += blend
	return Color(weights.x, weights.y, weights.z, weights.w)

func _create_material(definitions: Array[Dictionary]) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TERRAIN_SHADER
	for index: int in range(MATERIAL_COUNT):
		var definition := definitions[index]
		material.set_shader_parameter("albedo_%d" % index, load(str(definition["path"])))
		material.set_shader_parameter("normal_%d" % index, load(str(definition["normal"])))
		material.set_shader_parameter("height_%d" % index, load(str(definition["height"])))
		material.set_shader_parameter("roughness_%d" % index, load(str(definition["roughness_map"])))
		material.set_shader_parameter("scale_%d" % index, float(definition["uv_scale"]))
	return material
