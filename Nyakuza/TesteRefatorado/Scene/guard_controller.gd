extends Node
class_name GuardController
## DEFESA simples. Segure o botao de guarda (F / LB do controle; acao "guard").
## - Cancela o combo na hora (como o dash).
## - Parado e virado automaticamente pro inimigo mais perto.
## - Golpe vindo de frente: dano reduzido + empurrao reduzido (BLOQUEADO).
## - PERFECT GUARD: golpe que chega nos primeiros 'perfect_window' segundos = zero dano, o atacante fica atordoado
##   e o tempo da uma desacelerada (slow-mo).
## - Apertar atacar enquanto defende = contra-ataque (a guarda solta e o golpe sai).
## A pose vem de um frame de uma animacao que ja existe (pose_animation / pose_time). Troque quando tiver a animacao propria.

signal guard_started
signal guard_ended
signal blocked(hit : HitData, perfect : bool)

enum Result { NONE, BLOCKED, PERFECT }

@export_category("Guard")
## 0.8 = a guarda segura 80% do dano.
@export_range(0.0, 1.0) var damage_reduction : float = 0.8
## Quanto do empurrao do golpe ainda chega no player.
@export var knockback_scale : float = 0.25
## Arco protegido: 0 = tudo que vem da metade da frente. 1 = so em cima do nariz, -1 = 360 graus.
@export_range(-1.0, 1.0) var guard_arc : float = 0.0
## Inimigos mais perto que isso (m) sao usados para virar o player durante a guarda.
@export var auto_face_range : float = 10.0

@export_category("Perfect Guard")
@export var perfect_window : float = 0.2
## Tempo (s) soltando a guarda antes de poder ganhar outro perfect (impede apertar o botao sem parar).
@export var perfect_cooldown : float = 0.5
@export var parry_stun : float = 1.3
@export_range(0.05, 1.0) var parry_time_scale : float = 0.3
@export var parry_slowmo_time : float = 0.25

@export_category("Pose (frame de uma animacao existente)")
@export var pose_animation : StringName = &"Attack"
@export var pose_time : float = 0.22

@export_category("Shield")
@export var shield_color : Color = Color(0.25, 0.65, 1.0)

var is_guarding : bool = false
var guard_time : float = 0.0
var released_time : float = 99.0
var perfect_eligible : bool = true

var player : Player
var movement_controller : MovementController
var skill_controller : ActiveSkillController
var skills_container : SkillsContainer
var camera_controller : CameraController
var air_combo : AirComboController
var shield : MeshInstance3D
var shield_mat : ShaderMaterial
var flash_tween : Tween

const SHIELD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform float strength = 0.85;
uniform float flash = 0.0;
void fragment() {
	// So a borda do escudo aparece (fresnel); o centro fica transparente e o personagem continua visivel.
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	ALBEDO = mix(color.rgb, vec3(1.0), flash * 0.7);
	ALPHA = clamp(fres * strength + flash * (0.15 + 0.5 * fres), 0.0, 0.95);
}
"""

func _ready():
	player = get_parent() as Player
	movement_controller = player.find_child("MovementController", false, false) as MovementController
	skill_controller = player.find_child("ActiveSkillController", false, false) as ActiveSkillController
	camera_controller = player.find_child("CamRoot", false, false) as CameraController
	air_combo = player.find_child("AirComboController", false, false) as AirComboController
	skills_container = skill_controller.skills_container
	_ensure_input_action()
	_build_shield()

func _ensure_input_action() -> void:
	if InputMap.has_action("guard"):
		return
	InputMap.add_action("guard", 0.2)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	InputMap.action_add_event("guard", key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_LEFT_SHOULDER
	InputMap.action_add_event("guard", pad)

func _build_shield() -> void:
	var shader := Shader.new()
	shader.code = SHIELD_SHADER
	shield_mat = ShaderMaterial.new()
	shield_mat.shader = shader
	shield_mat.set_shader_parameter("color", shield_color)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	shield = MeshInstance3D.new()
	shield.mesh = sphere
	shield.material_override = shield_mat
	shield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shield.position = Vector3(0.0, 1.1, 0.35)
	shield.hide()
	movement_controller.mesh_root.add_child.call_deferred(shield)

func _physics_process(delta):
	if not player.is_physics_processing():   # player morto
		return
	if is_guarding:
		guard_time += delta
		_face_nearest_enemy()
		if not Input.is_action_pressed("guard"):
			stop_guard()
	else:
		released_time += delta
		if Input.is_action_just_pressed("guard"):
			start_guard()

# ------------------------------------------------------------------ estados
func start_guard() -> void:
	if is_guarding:
		return
	# cancela combo de chao ou aereo
	if air_combo != null and air_combo.is_active():
		air_combo.end_air_combo()
	skill_controller.cancel_attack()
	movement_controller.cancel_dash()
	movement_controller.evading = false

	is_guarding = true
	guard_time = 0.0
	perfect_eligible = released_time >= perfect_cooldown
	player.is_attacking = true            # trava movimento; quem vira o corpo e _face_nearest_enemy
	skills_container.hold_pose(pose_animation, pose_time)
	shield_mat.set_shader_parameter("flash", 0.0)
	shield.show()
	guard_started.emit()

## O jogador soltou a guarda: devolve o controle.
func stop_guard() -> void:
	if not is_guarding:
		return
	is_guarding = false
	released_time = 0.0
	shield.hide()
	player.is_attacking = false
	skills_container.release_pose()
	var last := skill_controller.last_movement_state
	if last != null:
		movement_controller._on_set_movement_state(last)
		camera_controller.set_fov(last.camera_fov)
	guard_ended.emit()

## Usado quando um ATAQUE comeca no meio da guarda (contra-ataque): so desliga a guarda, o golpe assume o resto.
func interrupt() -> void:
	if not is_guarding:
		return
	is_guarding = false
	released_time = 0.0
	shield.hide()
	guard_ended.emit()

func _face_nearest_enemy() -> void:
	var best : Node3D = null
	var best_d : float = auto_face_range
	for e in get_tree().get_nodes_in_group("enemies"):
		var to : Vector3 = e.global_position - player.global_position
		to.y = 0.0
		var d := to.length()
		if d > 0.01 and d < best_d:
			best = e
			best_d = d
	if best != null:
		var dir : Vector3 = best.global_position - player.global_position
		dir.y = 0.0
		movement_controller.direction = dir.normalized()

# ------------------------------------------------------------------ resposta a golpes (chamado pelo PlayerCombat)
func evaluate_hit(hit : HitData) -> Result:
	if not is_guarding or hit.unblockable or not is_instance_valid(hit.attacker):
		return Result.NONE
	var facing : Vector3 = movement_controller.mesh_root.global_transform.basis.z
	facing.y = 0.0
	var to_attacker : Vector3 = hit.attacker.global_position - player.global_position
	to_attacker.y = 0.0
	if to_attacker.length_squared() > 0.0001 and facing.normalized().dot(to_attacker.normalized()) < guard_arc:
		return Result.NONE   # golpe pelas costas
	if perfect_eligible and guard_time <= perfect_window:
		return Result.PERFECT
	return Result.BLOCKED

func on_block(hit : HitData) -> void:
	_flash_shield(0.7, 0.2)
	DamagePopup.spawn(get_tree(), player.global_position + Vector3(0.0, 2.6, 0.0), "BLOQUEOU", Color(0.55, 0.85, 1.0), 0.8)
	blocked.emit(hit, false)

func on_perfect(hit : HitData) -> void:
	_flash_shield(1.0, 0.35)
	DamagePopup.spawn(get_tree(), player.global_position + Vector3(0.0, 2.6, 0.0), "PERFEITO!", Color(1.0, 0.95, 0.4), 1.2)
	if is_instance_valid(hit.attacker) and hit.attacker.has_method("on_parried"):
		hit.attacker.on_parried(parry_stun)
	_slow_motion()
	blocked.emit(hit, true)

func _flash_shield(amount : float, time : float) -> void:
	if flash_tween != null:
		flash_tween.kill()
	shield_mat.set_shader_parameter("flash", amount)
	flash_tween = create_tween()
	flash_tween.tween_property(shield_mat, "shader_parameter/flash", 0.0, time)

func _slow_motion() -> void:
	CombatTimeEffects.request(get_tree(), parry_slowmo_time, parry_time_scale)
