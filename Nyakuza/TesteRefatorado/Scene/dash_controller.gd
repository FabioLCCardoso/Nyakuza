extends Node
class_name DashController
## Esquiva/dash estilo Senran Kagura: impulso curto na direcao do input (sem input = pulo pra tras),
## com invulnerabilidade. Cancela o golpe atual e zera o combo.
## Tecla: action "dash" (se nao existir no Input Map, e criada sozinha com Q / botao B do controle).

signal dash_started(direction : Vector3)
signal dash_ended

@export_category("Dash")
@export var dash_speed : float = 20.0
@export var dash_duration : float = 0.22
@export var cooldown : float = 0.5
## Invulnerabilidade a partir do inicio do dash.
@export var invulnerable_time : float = 0.3
## Quanto o FOV da camera abre durante o dash.
@export var camera_fov_kick : float = 8.0

@export_category("Animation")
## Nome de um OneShot no AnimationTree (parameters/<nome>/request). Se o no nao existir, e ignorado.
@export var animation_oneshot : StringName = &"dash"

var player : Player
var movement_controller : MovementController
var skill_controller : ActiveSkillController
var player_combat : PlayerCombat
var air_combo : AirComboController
var guard : GuardController
var camera_controller : CameraController
var cooldown_left : float = 0.0
var dash_id : int = 0

func _ready():
	player = get_parent() as Player
	for c in player.get_children():
		if c is MovementController:
			movement_controller = c
		elif c is ActiveSkillController:
			skill_controller = c
		elif c is PlayerCombat:
			player_combat = c
		elif c is CameraController:
			camera_controller = c
		elif c is AirComboController:
			air_combo = c
		elif c is GuardController:
			guard = c
	_ensure_input_action()

func _ensure_input_action():
	if InputMap.has_action("dash"):
		return
	InputMap.add_action("dash")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	InputMap.action_add_event("dash", key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_B
	InputMap.action_add_event("dash", pad)

func _physics_process(delta):
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if Input.is_action_just_pressed("dash"):
		dash()

func dash():
	if not player.is_physics_processing():   # player morto
		return
	
	# FOLLOW-UP AEREO: dash logo depois de um launcher = sobe junto com o inimigo (ignora o cooldown da esquiva)
	if air_combo != null and air_combo.try_follow_up():
		cooldown_left = 0.25
		return
	
	if cooldown_left > 0.0:
		return
	
	# Esquiva cancela o combo aereo e a guarda
	if air_combo != null and air_combo.is_active():
		air_combo.end_air_combo()
	if guard != null and guard.is_guarding:
		guard.stop_guard()
	
	cooldown_left = cooldown
	dash_id += 1
	var id : int = dash_id
	var dir : Vector3 = _get_direction()
	
	if player.is_attacking:
		skill_controller.cancel_attack()
	
	movement_controller.evade(dir * dash_speed, dash_duration)
	
	if player_combat != null:
		player_combat.invuln_left = maxf(player_combat.invuln_left, invulnerable_time)
	
	var base_fov : float = camera_controller.camera.fov
	if skill_controller.last_movement_state != null:
		base_fov = skill_controller.last_movement_state.camera_fov
	camera_controller.set_fov(base_fov + camera_fov_kick)
	
	_play_animation()
	dash_started.emit(dir)
	
	await get_tree().create_timer(dash_duration).timeout
	if id != dash_id:
		return   # veio outro dash
	if not player.is_attacking:
		camera_controller.set_fov(base_fov)
	dash_ended.emit()

func _get_direction() -> Vector3:
	var dir : Vector3
	if player.is_movement_ongoing():
		dir = player.movement_direction.rotated(Vector3.UP, movement_controller.cam_rotation)
	else:
		dir = -movement_controller.mesh_root.global_transform.basis.z   # sem input: pulo pra tras
	dir.y = 0.0
	if dir.length() < 0.01:
		return Vector3.BACK
	return dir.normalized()

func _play_animation():
	var tree : AnimationTree = skill_controller.anim_tree
	if tree == null or not (tree.tree_root is AnimationNodeBlendTree):
		return
	if (tree.tree_root as AnimationNodeBlendTree).has_node(animation_oneshot):
		tree["parameters/" + str(animation_oneshot) + "/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
