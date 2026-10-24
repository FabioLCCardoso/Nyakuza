extends Node
class_name MovementController

@export var player : CharacterBody3D
@export var mesh_root : Node3D
@export var rotation_speed : float = 8 
@export var fall_gravity = 45

@onready var jump_gravity : float = fall_gravity
var direction : Vector3
var velocity: Vector3
var acceleration : float
var speed : float
var cam_rotation: float = 0
var player_init_rotation : float
var dash_timer: Timer
var dash_velocity: Vector3
var tween: Tween
var dash_token: int = 0
var evading: bool = false
## Controle externo (combo aereo): enquanto forced = true o player usa forced_velocity direto
## (sem input, sem gravidade, sem inercia). Quem liga/desliga e o AirComboController.
var forced : bool = false
var forced_velocity : Vector3 = Vector3.ZERO

func _ready(): 
	dash_timer = Timer.new()
	dash_timer.one_shot = true
	add_child(dash_timer)

func _physics_process(delta):
	if forced:
		player.velocity = forced_velocity
		player.move_and_slide()
		# continua virando o corpo para 'direction' (o AirComboController aponta pro alvo)
		var forced_rotation = atan2(direction.x, direction.z) - player.rotation.y
		mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, forced_rotation, rotation_speed * delta)
		return
	
	velocity.x = speed * direction.normalized().x
	velocity.z = speed * direction.normalized().z
	
	if evading and not is_dashing():
		evading = false
		player.velocity.x = velocity.x   # fim da esquiva: corta o deslize
		player.velocity.z = velocity.z
	
	if is_dashing(): 
		velocity.x = dash_velocity.x
		velocity.z = dash_velocity.z
	elif player.is_attacking: 
		velocity.x = 0
		velocity.z = 0
	else :
		var target_rotation = atan2(direction.x, direction.z) - player_init_rotation
		mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, target_rotation, rotation_speed * delta)
	
	if not player.is_on_floor():
		if velocity.y >= 0:
			velocity.y -= jump_gravity * delta
		else:
			velocity.y -= fall_gravity * delta
	
	if player.is_on_floor() and velocity.y < 0.0:
		velocity.y = -0.5
	player.velocity = player.velocity.lerp(velocity, clampf(acceleration * delta, 0.0, 1.0))
	player.velocity.y = velocity.y
	player.move_and_slide()
	
	var target_rotation = atan2(direction.x, direction.z) - player.rotation.y
	mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, target_rotation, rotation_speed * delta)
	

func _jump(jump_state : JumpState):
	
	if is_dashing(): 
		return
		
	if player.is_attacking : 
		return
	
	velocity.y = 2 * jump_state.jump_height / jump_state.apex_duration
	jump_gravity = velocity.y / jump_state.apex_duration

func _on_set_movement_state(_movement_state : MovementState):
	
	if player.is_attacking:
		return
	
	speed = _movement_state.movement_speed
	acceleration = _movement_state.acceleration
	

func _on_set_movement_direction(_movement_direction : Vector3):
	
	if player.is_attacking: 
		return
	
	direction = _movement_direction.rotated(Vector3.UP, cam_rotation)

func _on_set_cam_rotation(_cam_rotation: float): 
	cam_rotation = _cam_rotation
	
func dash(_velocity: Vector3, duration: float, delay: float): 
	force_rotate_mesh()
	dash_token += 1
	var token : int = dash_token
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if token != dash_token:
		return   # esse dash foi cancelado/trocado (outro golpe ou esquiva) durante o delay
	evading = false
	dash_timer.start(duration)
	var rotation: float = atan2(direction.x, direction.z)
	dash_velocity = _velocity.rotated(Vector3.UP, rotation)

## Esquiva: impulso instantaneo e fixo, ignora input e o dash do golpe que estava pendente.
func evade(_velocity: Vector3, duration: float):
	dash_token += 1
	if tween:
		tween.kill()
	dash_velocity = _velocity
	evading = true
	player.velocity.x = _velocity.x   # arranque instantaneo (so a aceleracao deixaria o dash mole)
	player.velocity.z = _velocity.z
	dash_timer.start(duration)

## Sai do modo forced e devolve a fisica normal (a gravidade continua de onde a velocidade vertical parou).
func release_forced():
	forced = false
	forced_velocity = Vector3.ZERO
	velocity.y = player.velocity.y
	jump_gravity = fall_gravity
	dash_timer.stop()
	evading = false

func cancel_dash() -> void:
	dash_token += 1
	dash_timer.stop()
	evading = false
	dash_velocity = Vector3.ZERO
	if tween:
		tween.kill()

func is_dashing(): 
	return dash_timer.time_left > 0
	
func force_rotate_mesh(): 
	if tween:
		tween.kill()
	
	var target_rotation : Vector3 = mesh_root.rotation
	target_rotation.y = lerp_angle(mesh_root.rotation.y, atan2(direction.x, direction.z) - player_init_rotation, 1)
	
	tween = create_tween()
	tween.tween_property(mesh_root, "rotation", target_rotation, 0.1)
