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

var current_skill : ActiveSkill
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

	if skills_container != null:
		skills_container.delivery_started.connect(activate)
		skills_container.delivery_ended.connect(deactivate)
	else:
		push_warning("CombatHitBox: SkillsContainer nao encontrado, a hitbox nunca vai ligar.")

func _exit_tree():
	Engine.time_scale = 1.0

func activate(skill : ActiveSkill) -> void:
	current_skill = skill
	already_hit.clear()
	set_deferred("monitoring", true)

func deactivate() -> void:
	set_deferred("monitoring", false)

func _physics_process(_delta):
	if not monitoring:
		return
	for area in get_overlapping_areas():
		if area is CombatHurtBox:
			_try_hit(area)

func _try_hit(hurt_box : CombatHurtBox) -> void:
	if hurt_box in already_hit:
		return
	already_hit.append(hurt_box)

	var hit := HitData.new()
	hit.attacker = attacker
	if current_skill != null:
		hit.damage = current_skill.damage
		hit.knockback = current_skill.knockback
		hit.knockup = current_skill.knockup
		hit.stagger_duration = current_skill.stagger_duration
		hit.hit_stop = current_skill.hit_stop

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
	Engine.time_scale = 0.05
	# 4o parametro = ignore_time_scale: o timer ignora o slow-mo que nos mesmos criamos.
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	hit_stop_running = false
