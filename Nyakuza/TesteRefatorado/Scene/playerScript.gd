extends CharacterBody3D
class_name Player

signal pressed_primary_fire
signal pressed_heavy_fire
signal pressed_jump(jump_state : JumpState)
signal set_movement_state(_movement_state : MovementState)
signal set_movement_direction(_movement_direction : Vector3)

@export var max_air_jump: int = 1 
@export var jump_states : Dictionary
@export var movement_states : Dictionary

@onready var movement_controller: MovementController = get_node_or_null("MovementController") as MovementController

var ignore_menu_jump := false
var air_jump_counter : int = 0
var movement_direction : Vector3
var previous_move_state := ""
var is_attacking : bool = false

func _input(event):
	var musou := get_node_or_null("MusouController") as MusouController
	if musou != null and musou.handle_input(event):
		return
	
	if event.is_action_pressed("heavy_attack"):
		pressed_heavy_fire.emit()
	if event.is_action_pressed("primary_fire"): 
		pressed_primary_fire.emit()
		
		
func refresh_movement_input(force_update: bool = true) -> void:
	var stick := Input.get_vector("right", "left", "back", "forward")
	var next := Vector3(stick.x, 0, stick.y)
	var moving := next.length_squared() > 0
	var state := "stand"
	if moving: state = "sprint" if Input.is_action_pressed("sprint") else ("walk" if Input.is_action_pressed("walk") else "run")
	if force_update or (not is_attacking and state != previous_move_state):
		set_movement_state.emit(movement_states[state])
		previous_move_state = state
	if force_update or moving or next != movement_direction:
		set_movement_direction.emit(next)
	movement_direction = next

func _ready():
	ignore_menu_jump = Input.is_action_pressed("jump") or Input.is_action_just_pressed("jump")
	set_movement_state.emit(movement_states["stand"])

func _physics_process(delta):
	refresh_movement_input(false)
	if is_on_floor():
		air_jump_counter = 0
	elif air_jump_counter == 0: 
		air_jump_counter = 1
		
	if air_jump_counter <= max_air_jump and not is_attacking and (movement_controller == null or not movement_controller.is_dashing()):
		if not ignore_menu_jump and Input.is_action_just_pressed("jump"):
			var jump_name = "ground_jump"
			
			if air_jump_counter > 0: 
				jump_name = "air_jump"
				
			pressed_jump.emit(jump_states[jump_name])
			air_jump_counter += 1

	if not Input.is_action_pressed("jump") and not Input.is_action_just_pressed("jump"):
		ignore_menu_jump = false

func is_movement_ongoing() -> bool: 
	return abs(movement_direction.x) > 0 or abs(movement_direction.z) > 0

func outgoing_damage_multiplier() -> float:
	var musou := get_node_or_null("MusouController") as MusouController
	return musou.get_damage_multiplier() if musou != null else 1.0
