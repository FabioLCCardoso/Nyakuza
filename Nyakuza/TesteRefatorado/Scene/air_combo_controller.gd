extends Node
class_name AirComboController
## COMBO AEREO estilo Senran Kagura.
## Fluxo: launcher (golpe com knockup) -> DASH enquanto o inimigo esta no ar -> o player "sobe" ate ele (RISING)
## -> fica suspenso do lado dele (HOVER) -> ataques usam skills_container.air_skills (o ultimo, com slam = true,
## derruba todo mundo: FINISHING) -> volta ao normal.
## Sai do combo aereo: sem atacar por 'air_idle_time', dash (esquiva), guarda, levar dano, ou o finisher terminar.

signal air_combo_started
signal air_combo_ended
signal air_hit(count : int)

enum State { NONE, RISING, HOVER, FINISHING }

@export_category("Follow-up (a subida)")
## Distancia maxima (m) do inimigo no ar para o dash virar "subida".
@export var follow_up_range : float = 12.0
@export var rise_speed : float = 34.0
## Se nao chegar no alvo em ate esse tempo (s), desiste e volta ao normal.
@export var rise_max_time : float = 0.5
## Distancia horizontal (m) que o player fica do inimigo.
@export var attach_distance : float = 1.5

@export_category("Combo aereo")
## Sem atacar por esse tempo (s) o combo aereo acaba e todo mundo cai.
@export var air_idle_time : float = 1.3
## O player "gruda" no alvo: velocidade = distancia * follow_gain, limitada a follow_max_speed.
@export var follow_gain : float = 10.0
@export var follow_max_speed : float = 14.0
## Quanto tempo (s) os inimigos ficam suspensos depois da subida (renovado a cada acerto).
@export var enemy_hang_time : float = 1.4

@export_category("Poses (frames de animacoes que ja existem)")
@export var rise_pose_animation : StringName = &"Charged_Upward_Slash"
@export var rise_pose_time : float = 1.1
@export var hover_pose_animation : StringName = &"Attack"
@export var hover_pose_time : float = 0.22

@export_category("Feel")
## Compatibilidade: o FOV aereo agora e configurado no CamRoot.
@export var fov_kick : float = 0.0
@export var afterimages : bool = true
@export var afterimage_interval : float = 0.04
@export var afterimage_color : Color = Color(0.55, 0.85, 1.0, 0.5)

var state : State = State.NONE
var player : Player
var movement_controller : MovementController
var skill_controller : ActiveSkillController
var skills_container : SkillsContainer
var player_combat : PlayerCombat
var camera_controller : CameraController
var hit_box : CombatHitBox

var target : Enemy
var rise_time : float = 0.0
var air_timer : float = 0.0
var hit_count : int = 0
var player_floor_y : float = 0.0
var y_offset : float = -0.5      # altura do origin do player em relacao ao do inimigo quando os dois estao no chao
var ghost_timer : float = 0.0
var ghost_sources : Array[MeshInstance3D] = []

func _ready():
	player = get_parent() as Player
	movement_controller = player.find_child("MovementController", false, false) as MovementController
	skill_controller = player.find_child("ActiveSkillController", false, false) as ActiveSkillController
	player_combat = player.find_child("PlayerCombat", false, false) as PlayerCombat
	camera_controller = player.find_child("CamRoot", false, false) as CameraController
	skills_container = skill_controller.skills_container
	hit_box = player.find_child("HitBox", true, false) as CombatHitBox
	player_floor_y = player.global_position.y

	skills_container.delivery_started.connect(_on_delivery_started)
	skills_container.completed_recovery.connect(_on_completed_recovery)
	if hit_box != null:
		hit_box.hit_landed.connect(_on_hit_landed)
	if player_combat != null:
		player_combat.player_hit.connect(_on_player_hit)
		player_combat.player_died.connect(end_air_combo)
	for m in movement_controller.mesh_root.find_children("*", "MeshInstance3D", true, false):
		ghost_sources.append(m as MeshInstance3D)

func is_active() -> bool:
	return state != State.NONE

# ------------------------------------------------------------------ entrada (chamado pelo DashController)
## Retorna true se o dash foi "consumido" como subida.
func try_follow_up() -> bool:
	if state != State.NONE or player_combat.health.is_dead:
		return false
	var t := _find_target(follow_up_range)
	if t == null:
		return false
	_start_rise(t)
	return true

func _find_target(max_range : float) -> Enemy:
	var best : Enemy = null
	var best_dist : float = max_range
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy == null or not enemy.is_juggleable():
			continue
		var d : float = enemy.global_position.distance_to(player.global_position)
		if d < best_dist:
			best = enemy
			best_dist = d
	return best

func _start_rise(t : Enemy) -> void:
	skill_controller.cancel_attack()          # corta o recovery do launcher (zera o combo de chao)
	var guard := player.find_child("GuardController", false, false) as GuardController
	if guard != null and guard.is_guarding:
		guard.stop_guard()

	target = t
	state = State.RISING
	rise_time = 0.0
	ghost_timer = 0.0
	hit_count = 0
	y_offset = player_floor_y - target.ground_y
	player.is_attacking = true                # trava input de movimento/pulo
	player.add_to_group("air_combo")          # os inimigos de baixo param de atacar o player
	movement_controller.cancel_dash()
	movement_controller.evading = false
	movement_controller.forced = true
	skills_container.set_air_mode(true)
	player_combat.grant_invulnerability(rise_max_time + 0.2)

	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy != null and enemy.is_juggleable() and enemy.global_position.distance_to(player.global_position) <= follow_up_range:
			enemy.hold_in_air(rise_max_time + enemy_hang_time)

	skills_container.hold_pose(rise_pose_animation, rise_pose_time)
	camera_controller.begin_air(target)
	air_combo_started.emit()

func _enter_hover() -> void:
	state = State.HOVER
	air_timer = air_idle_time
	movement_controller.forced_velocity = Vector3.ZERO
	skills_container.hold_pose(hover_pose_animation, hover_pose_time)
	var last := skill_controller.last_movement_state
	camera_controller.set_fov(last.camera_fov if last != null else 75.0)

## Sai do combo aereo: todo mundo cai (inclusive o player).
func end_air_combo() -> void:
	camera_controller.end_air(player_combat.health.is_dead)
	if state == State.NONE:
		return
	state = State.NONE
	target = null
	player.remove_from_group("air_combo")
	skills_container.set_air_mode(false)
	movement_controller.release_forced()
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy != null:
			enemy.release_hang()
	if skills_container.attack_state == ActiveSkill.State.READY:
		# so devolve o controle se nao estiver no meio de um golpe (o recovery devolve sozinho)
		skills_container.release_pose()
		player.is_attacking = false
		var last := skill_controller.last_movement_state
		if last != null:
			movement_controller._on_set_movement_state(last)
			camera_controller.set_fov(last.camera_fov)
	air_combo_ended.emit()

# ------------------------------------------------------------------ loop
func _physics_process(delta):
	if player.is_on_floor():
		player_floor_y = player.global_position.y
	match state:
		State.RISING:
			_process_rise(delta)
		State.HOVER, State.FINISHING:
			_process_hover(delta)

func _target_valid() -> bool:
	return is_instance_valid(target) and target.is_juggleable()

func _goal_position() -> Vector3:
	var tp := target.global_position
	var away := player.global_position - tp
	away.y = 0.0
	if away.length() < 0.1:
		away = -movement_controller.mesh_root.global_transform.basis.z
		away.y = 0.0
	away = away.normalized()
	return Vector3(tp.x + away.x * attach_distance, tp.y + y_offset, tp.z + away.z * attach_distance)

func _face_target() -> void:
	camera_controller.set_air_target(target)
	var to := target.global_position - player.global_position
	to.y = 0.0
	if to.length() > 0.05:
		movement_controller.direction = to.normalized()

func _process_rise(delta : float) -> void:
	rise_time += delta
	if not _target_valid():
		target = _find_target(follow_up_range)
		if target == null:
			end_air_combo()
			return
	_face_target()
	var to := _goal_position() - player.global_position
	var flat := Vector2(to.x, to.z).length()
	if flat < 0.4 and absf(to.y) < 0.5:
		_enter_hover()
		return
	if rise_time >= rise_max_time:
		if flat < 3.0:
			_enter_hover()   # quase la: segue o combo assim mesmo
		else:
			end_air_combo()  # nao alcancou o alvo
		return
	var v := to.normalized() * rise_speed
	if to.length() < rise_speed * delta:
		v = to / delta   # nao passa do ponto
	movement_controller.forced_velocity = v
	if afterimages:
		ghost_timer += delta
		if ghost_timer >= afterimage_interval:
			ghost_timer = 0.0
			AfterImage.spawn(get_tree(), ghost_sources, afterimage_color, 0.3)

func _process_hover(delta : float) -> void:
	# O relogio de "sem atacar" so corre entre golpes.
	if state == State.HOVER and skills_container.attack_state == ActiveSkill.State.READY:
		air_timer -= delta
		if air_timer <= 0.0:
			end_air_combo()
			return
	if not _target_valid():
		target = _find_target(8.0)
		if target == null:
			# ninguem mais no ar: o combo acaba (se o finisher esta saindo, deixa terminar o golpe)
			if state == State.HOVER:
				end_air_combo()
			else:
				movement_controller.forced_velocity = Vector3.ZERO
			return
	_face_target()
	var v : Vector3 = (_goal_position() - player.global_position) * follow_gain
	movement_controller.forced_velocity = v.limit_length(follow_max_speed)

# ------------------------------------------------------------------ eventos
func _on_delivery_started(skill : ActiveSkill) -> void:
	if state == State.NONE:
		return
	air_timer = air_idle_time
	if skill.slam:
		state = State.FINISHING
		camera_controller.begin_slam(target)
	for e in get_tree().get_nodes_in_group("enemies"):
		var enemy := e as Enemy
		if enemy != null and enemy.is_juggleable() and enemy.global_position.distance_squared_to(player.global_position) <= follow_up_range * follow_up_range:
			enemy.hold_in_air(enemy_hang_time)   # mantem a galera suspensa enquanto o combo continua

func _on_hit_landed(_hit : HitData, _hurt : CombatHurtBox) -> void:
	if state == State.NONE:
		return
	hit_count += 1
	air_timer = air_idle_time
	air_hit.emit(hit_count)

func _on_completed_recovery() -> void:
	match state:
		State.FINISHING:
			end_air_combo()
		State.HOVER:
			# depois do golpe, volta pra pose de pairar (espera o end_timer do container passar)
			await get_tree().create_timer(0.1).timeout
			if state == State.HOVER and skills_container.attack_state == ActiveSkill.State.READY:
				player.is_attacking = true
				skills_container.hold_pose(hover_pose_animation, hover_pose_time)

func _on_player_hit(_hit : HitData) -> void:
	end_air_combo()   # levou dano: cai do combo
