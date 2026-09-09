class_name MapGrassLayer
extends Node3D

const SIMPLE_GRASS_SCRIPT := preload("res://addons/simplegrasstextured/grass.gd")
const GRASS_TEXTURE := preload("res://addons/simplegrasstextured/textures/grassbushcc008.png")
const DEFAULT_MESH := preload("res://addons/simplegrasstextured/default_mesh.tres")

var _grass: MultiMeshInstance3D

func _ready() -> void:
	_grass = SIMPLE_GRASS_SCRIPT.new() as MultiMeshInstance3D
	_grass.name = "SimpleGrassPaint"
	add_child(_grass)
	_grass.set("texture_albedo", GRASS_TEXTURE)
	_grass.set("interactive", false)
	_grass.set("light_mode", 0)
	_grass.set("optimization_by_distance", false)
	_grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED

func set_grass_color(color: Color) -> void:
	if _grass != null:
		_grass.set("grass_tint", color)
		_grass.set("albedo", color)


func rebuild(entries: Array[Dictionary], height_resolver: Callable, width: float, height: float) -> void:
	if _grass == null:
		return
	_grass.set("scale_w", width)
	_grass.set("scale_h", height)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = DEFAULT_MESH
	multi.instance_count = entries.size()
	for index: int in range(entries.size()):
		var data: Dictionary = entries[index]
		var x := float(data.get("x", 0.0))
		var z := float(data.get("z", 0.0))
		var y := float(height_resolver.call(x, z)) if height_resolver.is_valid() else 0.0
		var yaw := deg_to_rad(float(data.get("rotation", 0.0)))
		var variation := float(data.get("scale", 1.0))
		var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(Vector3(variation, variation, variation))
		multi.set_instance_transform(index, Transform3D(basis, Vector3(x, y, z)))
	_grass.multimesh = multi
	_grass.custom_aabb = AABB(Vector3(-4.0, -2.0, -4.0), Vector3(168.0, 24.0, 198.0))
