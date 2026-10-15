extends Node
class_name ActiveSkillController

@export var player : Player
@export var anim_tree : AnimationTree
@export var skills_container : SkillsContainer 
@export var movement_controller : MovementController
@export var camera_controller : CameraController

var last_movement_state : MovementState
## clique dado no meio de um golpe: vira o proximo golpe do combo assim que a recuperacao comeca.
var attack_buffered : bool = false
var player_combat : PlayerCombat

func _ready():
	skills_container.setup(anim_tree)
	skills_container.completed_recovery.connect(_on_completed_recovery)
	player_combat = player.find_child("PlayerCombat", false, false) as PlayerCombat

func _physics_process(_delta):
	if not attack_buffered:
		return
	if not player.is_physics_processing():   # player morto
		attack_buffered = false
		return
	var state := skills_container.attack_state
	if state == ActiveSkill.State.RECOVERING or state == ActiveSkill.State.READY:
		start_attack()

func _on_pressed_primary_fire(): 
	if is_skill_active():
		attack_buffered = true
		return
	start_attack()

func start_attack():
	attack_buffered = false
	player.is_attacking = true
	
	# cada golpe do combo sai na direcao do input atual e gruda no inimigo mais perto
	if player.is_movement_ongoing():
		movement_controller.direction = player.movement_direction.rotated(Vector3.UP, movement_controller.cam_rotation)
	if player_combat != null:
		player_combat.aim_assist()
	
	var current_skill : ActiveSkill = skills_container.get_current_skill()
	movement_controller.acceleration = current_skill.acceleration
	movement_controller.dash(current_skill.dash_velocity, current_skill.dash_duration, current_skill.dash_delay)
	
	camera_controller.set_fov(current_skill.camera_fov)
	
	skills_container.start_attack()

## Corta o golpe e devolve o controle (usado pelo dash).
func cancel_attack():
	attack_buffered = false
	skills_container.cancel_attack()
	player.is_attacking = false
	if last_movement_state != null:
		movement_controller._on_set_movement_state(last_movement_state)
		camera_controller.set_fov(last_movement_state.camera_fov)
	
func is_skill_active() -> bool: 
	return skills_container.attack_state != ActiveSkill.State.READY

func _on_completed_recovery(): 
	player.is_attacking = false
	movement_controller._on_set_movement_state(last_movement_state)
	camera_controller.set_fov(last_movement_state.camera_fov)
	
func _on_changed_movement_state(_movement_state : MovementState): 
	last_movement_state = _movement_state
