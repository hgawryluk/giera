extends CharacterBody3D

# How fast the player moves in meters per second.
@export var speed = 14
# The downward acceleration when in the air, in meters per second squared.
@export var fall_acceleration = 75
@export var mouse_sensitivity = 0.002
const JUMP_VELOCITY = 25

var target_velocity = Vector3.ZERO
# Reference to your camera pivot or camera
@onready var pivot = $Pivot

func _ready():
	# Captures the mouse cursor so it stays in the game window
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		pivot.rotate_x(-event.relative.y * mouse_sensitivity)
		pivot.rotation.x = clamp(pivot.rotation.x, deg_to_rad(-60), deg_to_rad(60))
		
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	var direction = Vector3.ZERO

	# need to map to WASD to make it work with WASD
	if Input.is_action_pressed("ui_right"):
		direction.x += 1
	if Input.is_action_pressed("ui_left"):
		direction.x -= 1
	if Input.is_action_pressed("ui_down"):
		direction.z += 1
	if Input.is_action_pressed("ui_up"):
		direction.z -= 1

	if direction != Vector3.ZERO:
		direction = direction.normalized()
		direction = (transform.basis * direction).normalized()

	# Ground Velocity
	target_velocity.x = direction.x * speed
	target_velocity.z = direction.z * speed

	# Vertical Velocity
	if not is_on_floor(): # If in the air, fall towards the floor. Literally gravity
		target_velocity.y = target_velocity.y - (fall_acceleration * delta)
		
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		target_velocity.y = JUMP_VELOCITY

	# Moving the Character
	velocity = target_velocity
	move_and_slide()
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collided_object = collision.get_collider()
		if collided_object.is_in_group("flag_group"):
			$win_label.set_text("You Win!")
