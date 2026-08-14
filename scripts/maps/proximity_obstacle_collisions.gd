class_name ProximityObstacleCollisions
extends Node3D

const ACTIVATION_RADIUS: float = 20.0
const UPDATE_INTERVAL: float = 0.18
const MAX_ACTIVE_COLLIDERS: int = 36

var _candidates: Array[Dictionary] = []
var _pool: Array[StaticBody3D] = []
var _elapsed: float = INF


func setup(tree_candidates: Array, rock_candidates: Array) -> void:
	_candidates.clear()
	for candidate: Dictionary in tree_candidates:
		var entry := candidate.duplicate(true)
		entry["kind"] = &"tree"
		_candidates.append(entry)
	for candidate: Dictionary in rock_candidates:
		var entry := candidate.duplicate(true)
		entry["kind"] = &"rock"
		_candidates.append(entry)
	_build_pool()
	set_process(true)


func _build_pool() -> void:
	for index: int in range(MAX_ACTIVE_COLLIDERS):
		var body := StaticBody3D.new()
		body.name = "NearbyObstacle_%02d" % index
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		collision.name = "Shape"
		body.add_child(collision)
		body.process_mode = Node.PROCESS_MODE_DISABLED
		body.visible = false
		add_child(body)
		_pool.append(body)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < UPDATE_INTERVAL:
		return
	_elapsed = 0.0
	var player := get_tree().get_first_node_in_group("exploration_player") as Node3D
	if player == null:
		_disable_from(0)
		return
	var nearby: Array[Dictionary] = []
	var player_xz := Vector2(player.global_position.x, player.global_position.z)
	var radius_squared := ACTIVATION_RADIUS * ACTIVATION_RADIUS
	for candidate: Dictionary in _candidates:
		var obstacle_position := candidate["position"] as Vector3
		var distance_squared := player_xz.distance_squared_to(Vector2(obstacle_position.x, obstacle_position.z))
		if distance_squared <= radius_squared:
			var ranked := candidate.duplicate(false)
			ranked["distance_squared"] = distance_squared
			nearby.append(ranked)
	nearby.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance_squared"]) < float(b["distance_squared"])
	)
	var active_count := mini(nearby.size(), MAX_ACTIVE_COLLIDERS)
	for index: int in range(active_count):
		_activate(_pool[index], nearby[index])
	_disable_from(active_count)


func _activate(body: StaticBody3D, candidate: Dictionary) -> void:
	var obstacle_position := candidate["position"] as Vector3
	var radius := float(candidate["radius"])
	var obstacle_height := float(candidate["height"])
	var collision := body.get_node("Shape") as CollisionShape3D
	if candidate["kind"] == &"tree":
		var capsule := collision.shape as CapsuleShape3D
		if capsule == null:
			capsule = CapsuleShape3D.new()
			collision.shape = capsule
		capsule.radius = radius
		capsule.height = maxf(obstacle_height, radius * 2.0)
		body.global_position = obstacle_position + Vector3.UP * capsule.height * 0.5
	else:
		var sphere := collision.shape as SphereShape3D
		if sphere == null:
			sphere = SphereShape3D.new()
			collision.shape = sphere
		sphere.radius = maxf(radius, obstacle_height * 0.45)
		body.global_position = obstacle_position + Vector3.UP * sphere.radius * 0.72
	body.process_mode = Node.PROCESS_MODE_INHERIT
	body.visible = true
	collision.disabled = false


func _disable_from(first_index: int) -> void:
	for index: int in range(first_index, _pool.size()):
		var body := _pool[index]
		var collision := body.get_node("Shape") as CollisionShape3D
		collision.disabled = true
		body.process_mode = Node.PROCESS_MODE_DISABLED
		body.visible = false
