extends Area3D
class_name CombatHitBox
## Hitbox da arma do player. Fica DESLIGADA o tempo todo e so liga durante a fase
## DELIVERING da skill (sinais delivery_started / delivery_ended do SkillsContainer).
## Cada inimigo so leva UM golpe por swing (lista already_hit).

signal hit_landed(hit : HitData, hurt_box : CombatHurtBox)

## Se vazio, procura um no chamado "SkillsContainer" dentro do Player.
@export var skills_container : SkillsContainer
## Quem esta batendo (usado para calcular a direcao do knockback). Se vazio, sobe a arvore ate achar o Player.
@export var attacker : Node3D
## Congela a tela por uma fracao de segundo ao acertar (valor vem de ActiveSkill.hit_stop).
@export var use_hit_stop : bool = true

@export_category("Reach Volume")
## Alem da lamina, uma caixa na frente do player tambem acerta. Garante que o golpe "conecta" mesmo que a
## animacao passe de lado ou o inimigo esteja um pouco acima/abaixo (combo aereo). false = dano so pela lamina.
@export var use_reach_volume : bool = true
@export var reach_size : Vector3 = Vector3(2.2, 2.4, 2.0)
## Centro da caixa, no espaco do MeshRoot do player (+Z = frente).
@export var reach_offset : Vector3 = Vector3(0.0, 1.0, 1.1)

var current_skill : ActiveSkill
var reach_area : Area3D
var activation_token : int = 0
var already_hit : Array[CombatHurtBox] = []
var hit_stop_running : bool = false

func _ready():
	collision_layer = 0
	collision_mask = HitData.LAYER_ENEMY_HURT
	monitorable = false
	monitoring = false

	if attacker == null:
		var n : Node = get_parent()
		while n != null and not (n is Player):
			n = n.get_parent()
		attacker = n as Node3D

	if skills_container == null and attacker != null:
		skills_container = attacker.find_child("SkillsContainer", true, false) as SkillsContainer

	if use_reach_volume and attacker != null:
		_build_reach_volume()

	if skills_container != null:
		skills_container.delivery_started.connect(activate)
		skills_container.delivery_ended.connect(deactivate)
	else:
		push_warning("CombatHitBox: SkillsContainer nao encontrado, a hitbox nunca vai ligar.")


func _build_reach_volume() -> void:
	var parent : Node = attacker.find_child("MeshRoot", true, false)
	if parent == null:
		parent = attacker
	reach_area = Area3D.new()
	reach_area.name = "ReachVolume"
	reach_area.collision_layer = 0
	reach_area.collision_mask = HitData.LAYER_ENEMY_HURT
	reach_area.monitorable = false
	reach_area.monitoring = false
	reach_area.position = reach_offset
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = reach_size
	shape.shape = box
	reach_area.add_child(shape)
	parent.add_child.call_deferred(reach_area)   # deferred: o pai ainda esta terminando o _ready

func activate(skill : ActiveSkill) -> void:
	current_skill = skill
	already_hit.clear()
	activation_token += 1
	var token := activation_token
	if skill.hit_delay > 0.0:
		await get_tree().create_timer(skill.hit_delay).timeout
		if token != activation_token:
			return   # o golpe acabou/foi cancelado antes da hitbox ligar
	set_deferred("monitoring", true)
	if reach_area != null:
		reach_area.set_deferred("monitoring", true)

func deactivate() -> void:
	activation_token += 1
	set_deferred("monitoring", false)
	if reach_area != null:
		reach_area.set_deferred("monitoring", false)

func _physics_process(_delta):
	if not monitoring:
		return
	var areas := get_overlapping_areas()
	if reach_area != null:
		areas.append_array(reach_area.get_overlapping_areas())
	for area in areas:
		if area is CombatHurtBox:
			_try_hit(area)

func _try_hit(hurt_box : CombatHurtBox) -> void:
	if not hurt_box.can_receive_hits or hurt_box in already_hit:
		return
	already_hit.append(hurt_box)

	var hit := HitData.new()
	hit.attacker = attacker
	hit.grants_musou = true
	if current_skill != null:
		hit.damage = current_skill.damage
		hit.knockback = current_skill.knockback
		hit.knockup = current_skill.knockup
		hit.stagger_duration = current_skill.stagger_duration
		hit.hit_stop = current_skill.hit_stop
		hit.slam = current_skill.slam
		hit.is_heavy = current_skill.is_heavy
		hit.posture_damage = current_skill.posture_damage

	var origin : Vector3 = attacker.global_position if attacker != null else global_position
	var flat : Vector3 = hurt_box.global_position - origin
	flat.y = 0.0
	hit.direction = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD

	hurt_box.receive_hit(hit)
	hit_landed.emit(hit, hurt_box)
	if use_hit_stop:
		_hit_stop(hit.hit_stop)

func _hit_stop(duration : float) -> void:
	if duration <= 0.0 or hit_stop_running:
		return
	hit_stop_running = true
	CombatTimeEffects.request(get_tree(), duration, 0.05)
	await get_tree().create_timer(duration, true, false, true).timeout
	hit_stop_running = false
