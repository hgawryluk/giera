class_name FogOfWarSystem
extends Node3D

var _grid: GridManager
var _fog_instances: MultiMeshInstance3D
var _visible_cells: Dictionary[Vector2i, bool] = {}
var _active_team_id: int = -1

func setup(grid: GridManager) -> void:
	_grid = grid
	_create_fog_mesh()

func update_for_team(team_id: int) -> void:
	if _grid == null:
		return
	_active_team_id = team_id
	_visible_cells.clear()
	var units := _grid.get_units()
	for unit: TacticalUnit in units:
		if unit != null and not unit.is_dead() and unit.team_id == team_id:
			_add_unit_vision(unit)
	_rebuild_fog()
	_update_unit_visibility(units)
	_update_environment_visibility()

func is_cell_visible(cell: Vector2i) -> bool:
	return _visible_cells.has(cell)

func _add_unit_vision(unit: TacticalUnit) -> void:
	var radius: int = unit.get_sight_range()
	var origin := unit.grid_position
	for dz: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			var target := origin + Vector2i(dx, dz)
			if not _grid.is_inside_grid(target):
				continue
			if Vector2(float(dx), float(dz)).length() <= float(radius) and _has_line_of_sight(origin, target):
				_visible_cells[target] = true

func _has_line_of_sight(origin: Vector2i, target: Vector2i) -> bool:
	var x0 := origin.x
	var y0 := origin.y
	var x1 := target.x
	var y1 := target.y
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var error := dx + dy
	while true:
		var cell := Vector2i(x0, y0)
		if cell != origin and cell != target and _grid.blocks_vision(cell):
			return false
		if x0 == x1 and y0 == y1:
			return true
		var doubled_error := error * 2
		if doubled_error >= dy:
			error += dy
			x0 += sx
		if doubled_error <= dx:
			error += dx
			y0 += sy
	return true

func _create_fog_mesh() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.03, 3.2, 1.03)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.008, 0.012, 0.025, 0.985)
	material.emission_enabled = true
	material.emission = Color(0.003, 0.006, 0.016)
	material.emission_energy_multiplier = 0.35
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	_fog_instances = MultiMeshInstance3D.new()
	_fog_instances.name = "FogOfWarCells"
	_fog_instances.multimesh = multimesh
	_fog_instances.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fog_instances)

func _rebuild_fog() -> void:
	var rect := _grid.get_arena_rect()
	var hidden_transforms: Array[Transform3D] = []
	for z: int in range(rect.position.y + 1, rect.end.y - 1):
		for x: int in range(rect.position.x + 1, rect.end.x - 1):
			var cell := Vector2i(x, z)
			if _visible_cells.has(cell):
				continue
			var height := _grid.terrain_height(float(x), float(z))
			hidden_transforms.append(Transform3D(Basis.IDENTITY, Vector3(float(x), height + 1.5, float(z))))
	var multimesh := _fog_instances.multimesh
	multimesh.instance_count = hidden_transforms.size()
	for index: int in range(hidden_transforms.size()):
		multimesh.set_instance_transform(index, hidden_transforms[index])
	multimesh.visible_instance_count = hidden_transforms.size()

func _update_environment_visibility() -> void:
	for node: Node in get_tree().get_nodes_in_group("fog_cullable_environment"):
		if not is_instance_valid(node) or not node.has_meta("fog_cell"):
			continue
		var cell: Vector2i = node.get_meta("fog_cell") as Vector2i
		(node as Node3D).visible = _visible_cells.has(cell)


func _update_unit_visibility(units: Array[TacticalUnit]) -> void:
	for unit: TacticalUnit in units:
		if unit != null and is_instance_valid(unit):
			unit.visible = unit.team_id == _active_team_id or _visible_cells.has(unit.grid_position)
