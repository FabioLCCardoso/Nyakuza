extends Node
class_name ActiveSkillController

@export var player : Player
@export var anim_tree : AnimationTree
@export var skills_container : SkillsContainer 
@export var movement_controller : MovementController
@export var camera_controller : CameraController

var last_movement_state : MovementState
## clique dado no meio de um golpe: vira o proximo golpe do combo assim que a recuperacao comeca.
@export var input_buffer_time: float = 0.28
@export var minimum_recovery: float = 0.035
@export var heavy_cooldown: float = 0.55
var attack_buffered : bool = false
var buffered_heavy: bool = false
var buffer_left: float = 0.0
var heavy_left: float = 0.0
var player_combat : PlayerCombat
var air_combo : AirComboController
var guard : GuardController

func _ready():
	skills_container.setup(anim_tree)
	player.pressed_heavy_fire.connect(_on_pressed_heavy_fire)
	skills_container.completed_recovery.connect(_on_completed_recovery)
	player_combat = player.find_child("PlayerCombat", false, false) as PlayerCombat
	air_combo = player.find_child("AirComboController", false, false) as AirComboController
	guard = player.find_child("GuardController", false, false) as GuardController

func _physics_process(delta: float) -> void:
	heavy_left = maxf(heavy_left - delta, 0.0)
	if not attack_buffered:
		return
	buffer_left -= delta
	if buffer_left <= 0.0 or not player.is_physics_processing():
		attack_buffered = false
		return
	if air_combo != null and air_combo.state == AirComboController.State.RISING:
		return
	var state: ActiveSkill.State = skills_container.attack_state
	var recovered: float = 0.0
	if skills_container.current_active_skill != null:
		recovered = skills_container.current_active_skill.recovery_duration - skills_container.recovery_timer.time_left
	if state == ActiveSkill.State.READY or (state == ActiveSkill.State.RECOVERING and recovered >= minimum_recovery):
		if not buffered_heavy or heavy_left <= 0.0:
			start_attack(buffered_heavy)

func _on_pressed_primary_fire() -> void:
	_queue_attack(false)

func _on_pressed_heavy_fire() -> void:
	_queue_attack(true)

func _queue_attack(heavy: bool) -> void:
	if not player.is_physics_processing():
		return
	if not is_skill_active() and (not heavy or heavy_left <= 0.0) and (air_combo == null or air_combo.state != AirComboController.State.RISING):
		start_attack(heavy)
		return
	attack_buffered = true
	buffered_heavy = heavy
	buffer_left = input_buffer_time

func start_attack(heavy: bool = false):
	attack_buffered = false
	if not player.is_physics_processing() or skills_container.get_current_skill(heavy) == null:
		return
	if heavy and heavy_left > 0.0:
		return
	if air_combo != null and air_combo.state == AirComboController.State.RISING:
		_queue_attack(heavy)
		return
	if guard != null:
		guard.interrupt()   # atacar enquanto defende = contra-ataque (a guarda so "solta", quem controla agora e o golpe)
	player.is_attacking = true
	
	# cada golpe do combo sai na direcao do input atual e gruda no inimigo mais perto
	if player.is_movement_ongoing():
		movement_controller.direction = player.movement_direction.rotated(Vector3.UP, movement_controller.cam_rotation)
	if player_combat != null:
		player_combat.aim_assist()
	
	var current_skill : ActiveSkill = skills_container.get_current_skill(heavy)
	movement_controller.acceleration = current_skill.acceleration
	movement_controller.dash(current_skill.dash_velocity, current_skill.dash_duration, current_skill.dash_delay)
	
	camera_controller.set_fov(current_skill.camera_fov, true)
	
	if heavy:
		heavy_left = heavy_cooldown
	skills_container.start_attack(heavy)

## Corta o golpe e devolve o controle (usado pelo dash).
func cancel_attack():
	attack_buffered = false
	skills_container.cancel_attack()
	movement_controller.cancel_dash()
	player.is_attacking = false
	if last_movement_state != null:
		movement_controller._on_set_movement_state(last_movement_state)
		camera_controller.set_fov(last_movement_state.camera_fov)
	
func is_skill_active() -> bool: 
	return skills_container.attack_state != ActiveSkill.State.READY

func _on_completed_recovery(): 
	if air_combo != null and air_combo.is_active():
		return   # no combo aereo quem segura o player no ar e o AirComboController
	player.is_attacking = false
	if last_movement_state != null:
		movement_controller._on_set_movement_state(last_movement_state)
		camera_controller.set_fov(last_movement_state.camera_fov)
	
func _on_changed_movement_state(_movement_state : MovementState): 
	last_movement_state = _movement_state
