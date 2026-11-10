extends Node
class_name MusouController
signal charge_changed(current: float, maximum: float)
signal activated
signal mode_ended
signal activation_rejected(reason: String)
signal field_hit(hit: HitData, hurt: CombatHurtBox)
@export_category("Charge")
@export var max_charge: float = 100.0
@export var initial_charge: float = 0.0
@export var light_gain: float = 6.0
@export var heavy_gain: float = 8.0
@export var perfect_guard_gain: float = 12.0
@export_category("Empowered Mode")
@export_range(0.1, 180.0) var mode_duration: float = 30.0
@export var bonus_health: float = 50.0
@export_range(1.0, 5.0) var damage_multiplier: float = 1.5
@export_category("Cutting Sphere - R + LMB")
@export var radius: float = 3.2
@export var duration: float = 4.0
@export var tick_interval: float = 0.25
@export var damage_per_tick: float = 8.0
@export var sphere_cooldown: float = 6.0
@export var pull_speed: float = 7.0
@export var slot_spacing: float = 1.05
@export var capture_interval: float = 0.1
@export var placement_distance: float = 3.0
@export_category("Explosion - R + RMB")
@export var explosion_radius: float = 6.0
@export_range(0.0, 1.0) var explosion_health_fraction: float = 0.4
@export var explosion_cooldown: float = 10.0
var charge: float = 0.0
var field: MusouSphere
var player: Player
var combat: PlayerCombat
var skills: ActiveSkillController
var guard: GuardController
var active: bool = false
var time_left: float = 0.0
var sphere_left: float = 0.0
var explosion_left: float = 0.0
var applied_health_bonus: float = 0.0
var aura: Node3D

func _ready() -> void:
	player = get_parent() as Player
	combat = player.get_node("PlayerCombat") as PlayerCombat
	skills = player.get_node("ActiveSkillController") as ActiveSkillController
	guard = player.get_node("GuardController") as GuardController
	max_charge = maxf(max_charge, 1.0)
	charge = clampf(initial_charge, 0.0, max_charge)
	var hitbox := player.find_child("HitBox", true, false) as CombatHitBox
	hitbox.hit_landed.connect(_on_weapon_hit)
	guard.blocked.connect(_on_guard)
	combat.player_died.connect(_on_death)

func _physics_process(delta: float) -> void:
	sphere_left = maxf(0, sphere_left - delta)
	explosion_left = maxf(0, explosion_left - delta)
	if active:
		time_left = maxf(0, time_left - delta)
		if time_left <= 0:
			end_mode()
	# Input e roteado pelo Player, antes dos sinais de ataque normal.

func handle_input(event: InputEvent) -> bool:
	if event.is_echo(): return false
	if event.is_action_pressed("musou"):
		if not active: try_activate()
		return true
	if Input.is_action_pressed("musou"):
		if event.is_action_pressed("primary_fire"):
			try_sphere()
			return true
		if event.is_action_pressed("heavy_attack"):
			try_explosion()
			return true
	return false

func add_charge(amount: float) -> void:
	if combat.health.is_dead or active: return
	charge = clampf(charge + maxf(amount, 0.0), 0.0, max_charge)
	charge_changed.emit(charge, max_charge)

func _on_weapon_hit(hit: HitData, hurt: CombatHurtBox) -> void:
	if hit.attacker == player and hit.grants_musou and hurt.team == CombatHurtBox.Team.ENEMY:
		add_charge(heavy_gain if hit.is_heavy else light_gain)

func _on_guard(_hit: HitData, perfect: bool) -> void:
	if perfect: add_charge(perfect_guard_gain)

func try_activate() -> bool:
	if combat.health.is_dead or not player.is_physics_processing() or get_tree().paused: return false
	if active: return _reject("MUSOU JÁ ATIVA")
	if charge < max_charge: return _reject("MUSOU: CARGA INSUFICIENTE")
	if not player.is_on_floor() or player.is_in_group("air_combo"):
		return _reject("MUSOU: ATIVE NO CHÃO")
	_cancel_attack()
	active = true
	time_left = maxf(mode_duration, 0.1)
	sphere_left = 0
	explosion_left = 0
	charge = 0
	applied_health_bonus = maxf(bonus_health, 0)
	combat.health.max_health += applied_health_bonus
	combat.health.current_health = minf(combat.health.current_health + applied_health_bonus, combat.health.max_health)
	combat.health.health_changed.emit(combat.health.current_health, combat.health.max_health)
	aura = preload("res://TesteRefatorado/VFX/musou_aura.gd").new()
	player.add_child(aura)
	charge_changed.emit(charge, max_charge)
	activated.emit()
	return true

func _can_special() -> bool:
	if combat.health.is_dead or not player.is_physics_processing() or get_tree().paused: return false
	if not active: return _reject("ATIVE A MUSOU COM R PRIMEIRO")
	return true

func try_sphere() -> bool:
	if not _can_special(): return false
	if sphere_left > 0 or is_instance_valid(field): return _reject("ESFERA RECARREGANDO")
	var movement := player.movement_controller
	var forward := movement.mesh_root.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var origin := player.global_position + Vector3.UP * 1.1
	var center := origin + forward * maxf(placement_distance, 0)
	var space := player.get_world_3d().direct_space_state
	var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, center, 1, [player.get_rid()]))
	if not wall.is_empty(): center = wall.position - forward * 0.3
	var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(center + Vector3.UP * 2, center - Vector3.UP * 4, 1, [player.get_rid()]))
	if ground.is_empty(): return _reject("ESFERA: SEM CHÃO À FRENTE")
	center.y = ground.position.y + 1.1
	_cancel_attack()
	field = MusouSphere.new()
	field.caster = player
	field.radius = radius
	field.duration = minf(duration, time_left)
	field.tick_interval = tick_interval
	field.damage_per_tick = damage_per_tick * get_damage_multiplier()
	field.pull_speed = pull_speed
	field.slot_spacing = slot_spacing
	field.capture_interval = capture_interval
	field.hit_landed.connect(func(hit: HitData, hurt: CombatHurtBox): field_hit.emit(hit, hurt))
	player.get_parent().add_child(field)
	field.global_position = center
	sphere_left = maxf(sphere_cooldown, 0.1)
	return true

func try_explosion() -> bool:
	if not _can_special(): return false
	if explosion_left > 0: return _reject("EXPLOSÃO RECARREGANDO")
	_cancel_attack()
	explosion_left = maxf(explosion_cooldown, 0.1)
	var origin := player.global_position + Vector3.UP
	var visual := preload("res://TesteRefatorado/VFX/musou_explosion.gd").new()
	visual.radius = explosion_radius
	player.get_parent().add_child(visual)
	visual.global_position = origin
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or not enemy.hurt_box.can_receive_hits: continue
		var center := enemy.global_position + Vector3.UP
		if center.distance_squared_to(origin) > explosion_radius * explosion_radius: continue
		if not player.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, center, 1, [player.get_rid()])).is_empty(): continue
		var hit := HitData.new()
		hit.attacker = player
		# Percentual exato do HP MAXIMO; nao recebe o multiplicador de ataques comuns.
		hit.damage = enemy.health.max_health * clampf(explosion_health_fraction, 0, 1)
		hit.knockback = 0
		hit.affects_air_reaction = false
		hit.stagger_duration = 0.5
		hit.direction = (center - origin).normalized()
		enemy.hurt_box.receive_hit(hit)
		field_hit.emit(hit, enemy.hurt_box)
	return true

func get_damage_multiplier() -> float:
	return maxf(damage_multiplier, 1.0) if active else 1.0

func _cancel_attack() -> void:
	guard.stop_guard()
	skills.cancel_attack()
	player.movement_controller.evading = false

func _reject(reason: String) -> bool:
	activation_rejected.emit(reason)
	return false

func end_mode() -> void:
	if not active: return
	active = false
	time_left = 0
	combat.health.max_health = maxf(1, combat.health.max_health - applied_health_bonus)
	applied_health_bonus = 0
	combat.health.current_health = minf(combat.health.current_health, combat.health.max_health)
	combat.health.health_changed.emit(combat.health.current_health, combat.health.max_health)
	if is_instance_valid(aura): aura.queue_free()
	if is_instance_valid(field):
		field._release_all()
		field.queue_free()
	mode_ended.emit()
	charge_changed.emit(charge, max_charge)

func _on_death() -> void:
	end_mode()
	charge = 0
	charge_changed.emit(charge, max_charge)
