extends Node

var rng = RandomNumberGenerator.new()
var materials = [
	"res://Kyle's Rock Pack/Kyle Fuji/Materials/M_arid_rocks_1.tres", 
	"res://Kyle's Rock Pack/Kyle Fuji/Materials/M_arid_rocks_2.tres",
	"res://Kyle's Rock Pack/Kyle Fuji/Materials/M_arid_rocks_3.tres",
	"res://Kyle's Rock Pack/Kyle Fuji/Materials/M_mossy_rocks_1.tres", 
	"res://Kyle's Rock Pack/Kyle Fuji/Materials/M_mossy_rocks_2.tres", 
	"res://Kyle's Rock Pack/Kyle Fuji/Materials/M_sand_stone_rocks.tres",
	"res://Kyle's Rock Pack/Kyle Fuji/Materials/M_snow_rocks_1.tres", 
	"res://Kyle's Rock Pack/Kyle Fuji/Materials/M_snow_rocks_2.tres", 
	"res://Kyle's Rock Pack/Kyle Fuji/Materials/M_snow_rocks_3.tres"
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	rng.randomize()
	var my_random_number = rng.randi_range(0, len(materials) - 1)

	var NEW_MATERIAL = load(materials[my_random_number])
	var nodes = get_tree().get_nodes_in_group("change_material")
	for node in nodes:
		for child in node.get_children():
			if child is MeshInstance3D:
				child.material_override = NEW_MATERIAL
