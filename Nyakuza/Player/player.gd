extends CharacterBody3D

@onready var camera: Camera3D = $SpringArmPivot/Camera3D
@onready var animationPlayer = $AnimationPlayer
@onready var playerMesh = $Armature

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var angular_acceleration = 10.
var mouse_sensitivity := 0.1
var rotation_x := 0.0
var rotation_y := 0.0
var isAttacking = false

var lastDirection := Vector3.FORWARD

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	#var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	var direction := Vector3(input_dir.x, 0, input_dir.y).normalized()
	
	direction = direction.rotated(Vector3.UP, camera.global_rotation.y)
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		lastDirection = direction
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	
	## MESH ROTATION!!!!
	playerMesh.rotation.y = lerp(playerMesh.rotation.y, atan2(lastDirection.x, lastDirection.z), delta * angular_acceleration)
	_set_animation(direction)
	
	
	move_and_slide()
	
func _set_animation(direction): 
	if isAttacking: return
	
	if Input.is_action_just_pressed("attack"):
		isAttacking = true
		animationPlayer.play("ComboAtk")
		
	elif velocity.x != 0 || velocity.y != 0:
		animationPlayer.play("Walk")


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if "ComboAtk" in anim_name:
		isAttacking = false 
