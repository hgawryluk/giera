class_name WorldSectorStreamer
extends Node3D

const REGION_SCRIPT := preload("res://scripts/world/exploration_region.gd")
const SOLO_SECTOR_SCRIPT := preload("res://scripts/maps/solo_trail_streamed_sector.gd")
const SECTOR_SIZE := Vector2(float(GridManager.GRID_WIDTH), float(GridManager.GRID_HEIGHT))
const MIN_SECTOR := Vector2i(-3, -3)
const MAX_SECTOR := Vector2i(3, 3)
const PRELOAD_MARGIN := Vector2(115.0, 135.0)
const UPDATE_INTERVAL := 0.18

var _world: Dictionary = {}
var _loaded_sectors: Dictionary[Vector2i, Node3D] = {}
var _enabled := false
var _elapsed := 0.0
var _solo_trail_mode := false
var _pending_sectors: Array[Vector2i] = []

func _ready() -> void:
	add_to_group("world_sector_streamer")
	_solo_trail_mode = GameSession.selected_map_id == "builtin:solo_trail"
	_enabled = _solo_trail_mode or GameSession.selected_map_id.is_empty() or GameSession.selected_map_id == MapCatalogService.DEFAULT_ID
	if not _enabled:
		set_process(false)
		return
	_world = ExplorationWorldCatalog.load_world()
	call_deferred("_initialize_streaming")

func _initialize_streaming() -> void:
	# Sektory wokol prawdziwej planszy bitwy sa gotowe zanim gracz wejdzie do FPP.
	var sector_size := _sector_size()
	_update_loaded_sectors(Vector3(sector_size.x * 0.5, 0.0, sector_size.y * 0.5))

func _process(delta: float) -> void:
	if not _enabled: return
	_elapsed += delta
	if _elapsed < UPDATE_INTERVAL: return
	_elapsed = 0.0
	var explorer := get_tree().get_first_node_in_group("exploration_player") as Node3D
	if explorer != null: _update_loaded_sectors(explorer.global_position)
	if _solo_trail_mode and not _pending_sectors.is_empty():
		_load_sector(_pending_sectors.pop_front())

func clamp_world_position(world_position: Vector3) -> Vector3:
	if not _enabled:
		var grid_manager := get_tree().get_first_node_in_group("grid_manager") as GridManager
		var bounds := grid_manager.get_exploration_world_size() if grid_manager != null else SECTOR_SIZE
		world_position.x = clampf(world_position.x, 0.5, bounds.x - 0.5)
		world_position.z = clampf(world_position.z, 0.5, bounds.y - 0.5)
		return world_position
	var sector_size := _sector_size()
	var minimum := Vector2i(-2, -2) if _solo_trail_mode else MIN_SECTOR
	var maximum := Vector2i(2, 2) if _solo_trail_mode else MAX_SECTOR
	world_position.x = clampf(world_position.x, minimum.x * sector_size.x + 0.5, (maximum.x + 1) * sector_size.x - 0.5)
	world_position.z = clampf(world_position.z, minimum.y * sector_size.y + 0.5, (maximum.y + 1) * sector_size.y - 0.5)
	_update_loaded_sectors(world_position)
	return world_position

func get_loaded_sector_count() -> int:
	return _loaded_sectors.size() + 1

func _update_loaded_sectors(world_position: Vector3) -> void:
	var current := _world_to_sector(world_position)
	var sector_size := _sector_size()
	var local := Vector2(world_position.x - current.x * sector_size.x, world_position.z - current.y * sector_size.y)
	var x_offsets: Array[int] = [0]
	var z_offsets: Array[int] = [0]
	if _solo_trail_mode:
		x_offsets = [-1, 0, 1]
		z_offsets = [-1, 0, 1]
	else:
		if local.x < PRELOAD_MARGIN.x: x_offsets.append(-1)
		if local.x > sector_size.x - PRELOAD_MARGIN.x: x_offsets.append(1)
		if local.y < PRELOAD_MARGIN.y: z_offsets.append(-1)
		if local.y > sector_size.y - PRELOAD_MARGIN.y: z_offsets.append(1)
	var desired: Dictionary[Vector2i, bool] = {}
	for dx: int in x_offsets:
		for dz: int in z_offsets:
			var coordinate := current + Vector2i(dx, dz)
			if _is_valid_sector(coordinate): desired[coordinate] = true
	# Centralna plansza jest prawdziwym GridManagerem i BattleDecoratorem — nie duplikujemy jej.
	desired[Vector2i.ZERO] = true
	for coordinate: Vector2i in desired:
		if coordinate != Vector2i.ZERO and not _loaded_sectors.has(coordinate):
			if _solo_trail_mode:
				if not _pending_sectors.has(coordinate): _pending_sectors.append(coordinate)
			else: _load_sector(coordinate)
	if _solo_trail_mode:
		var retained_pending: Array[Vector2i] = []
		for coordinate: Vector2i in _pending_sectors:
			if desired.has(coordinate): retained_pending.append(coordinate)
		_pending_sectors = retained_pending
	var loaded_coordinates: Array[Vector2i] = []
	loaded_coordinates.assign(_loaded_sectors.keys())
	for coordinate: Vector2i in loaded_coordinates:
		if not desired.has(coordinate): _unload_sector(coordinate)

func _world_to_sector(world_position: Vector3) -> Vector2i:
	var sector_size := _sector_size()
	var minimum := Vector2i(-2, -2) if _solo_trail_mode else MIN_SECTOR
	var maximum := Vector2i(2, 2) if _solo_trail_mode else MAX_SECTOR
	return Vector2i(clampi(floori(world_position.x / sector_size.x), minimum.x, maximum.x), clampi(floori(world_position.z / sector_size.y), minimum.y, maximum.y))

func _is_valid_sector(coordinate: Vector2i) -> bool:
	if _solo_trail_mode:
		return coordinate.x >= -2 and coordinate.x <= 2 and coordinate.y >= -2 and coordinate.y <= 2
	return coordinate.x >= MIN_SECTOR.x and coordinate.x <= MAX_SECTOR.x and coordinate.y >= MIN_SECTOR.y and coordinate.y <= MAX_SECTOR.y

func _load_sector(coordinate: Vector2i) -> void:
	if _solo_trail_mode:
		var grid_manager := get_tree().get_first_node_in_group("grid_manager") as GridManager
		if grid_manager == null:
			return
		var solo_sector := SOLO_SECTOR_SCRIPT.new() as SoloTrailStreamedSector
		solo_sector.configure(coordinate, grid_manager)
		add_child(solo_sector)
		_loaded_sectors[coordinate] = solo_sector
		return
	var descriptor := ExplorationWorldCatalog.region_at(_world, coordinate)
	if descriptor.is_empty(): return
	var sector := REGION_SCRIPT.new() as ExplorationRegion
	sector.configure(descriptor, false)
	add_child(sector)
	_loaded_sectors[coordinate] = sector
	sector.call_deferred("begin_stream_fade")

func _unload_sector(coordinate: Vector2i) -> void:
	var sector := _loaded_sectors.get(coordinate) as Node3D
	if sector != null and is_instance_valid(sector): sector.queue_free()
	_loaded_sectors.erase(coordinate)


func _sector_size() -> Vector2:
	return Vector2(256.0, 256.0) if _solo_trail_mode else SECTOR_SIZE
