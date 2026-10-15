extends Node
class_name PlayerCombat
## Cola do lado do player: recebe dano (HurtBox + HealthComponent), empurrao, morte e "aim assist".
## Nao mexe no MovementController / SkillsContainer: so le e (no aim assist) escreve em movement_controller.direction.

signal player_hit(hit : HitData)
signal player_died

@export var player : Player
@export var health : HealthComponent
@export var hurt_box : CombatHurtBox
@export var movement_controller : MovementController

@export_category("Hurt")
## Tempo de invulnerabilidade depois de apanhar (evita ser "derretido" por varios inimigos).
@export var invulnerability_time : float = 0.5
@export var hurt_knockback_scale : float = 1.0

@export_category("Aim Assist")
## Ao atacar, o player vira para o inimigo mais proximo dentro desse raio (0 = desligado).
@export var aim_assist_range : float = 4.5

@export_category("Debug")
## Para gravar o teaser sem morrer. Tambem alternavel com F1 em jogo.
@export var god_mode : bool = false

var invuln_left : float = 0.0

func _ready():
	if player == null:
		player = get_parent() as Player
	player.add_to_group("player")   # os inimigos procuram o player por esse grupo
	health.invincible = god_mode
	hurt_box.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)

func _physics_process(delta):
	invuln_left = maxf(invuln_left - delta, 0.0)

# Filhos recebem _input ANTES do pai (Player), entao isso roda antes do Player emitir pressed_primary_fire.
func _input(event):
	if event.is_action_pressed("primary_fire"):
		_aim_assist()

func _aim_assist() -> void:
	if aim_assist_range <= 0.0 or movement_controller == null or health.is_dead or player.is_attacking:
		return
	var facing : Vector3 = movement_controller.mesh_root.global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized()

	var best : Node3D = null
	var best_dist : float = aim_assist_range
	for e in get_tree().get_nodes_in_group("enemies"):
		var to : Vector3 = e.global_position - player.global_position
		to.y = 0.0
		var d := to.length()
		if d < 0.01 or d > best_dist:
			continue
		if facing.dot(to / d) < -0.35:   # ignora quem esta bem atras
			continue
		best = e
		best_dist = d
	if best != null:
		var dir : Vector3 = best.global_position - player.global_position
		dir.y = 0.0
		movement_controller.direction = dir.normalized()

func _on_hit_received(hit : HitData) -> void:
	if health.is_dead or invuln_left > 0.0:
		return
	health.take_damage(hit.damage)
	invuln_left = invulnerability_time
	player.velocity += hit.direction * hit.knockback * hurt_knockback_scale
	DamagePopup.spawn(get_tree(), player.global_position + Vector3(0.0, 2.6, 0.0), str(int(hit.damage)), Color(1.0, 0.3, 0.3))
	player_hit.emit(hit)

func _on_died() -> void:
	player.remove_from_group("player")   # inimigos perdem o alvo e voltam a ficar parados
	player.set_process_input(false)
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	if movement_controller != null:
		movement_controller.set_physics_process(false)
		# Cai para tras.
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(movement_controller.mesh_root, "rotation:x", -PI * 0.5, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(movement_controller.mesh_root, "position:y", 0.7, 0.5)
	player_died.emit()
