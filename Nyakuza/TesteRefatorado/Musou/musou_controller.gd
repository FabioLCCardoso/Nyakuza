extends Node
class_name MusouController
signal charge_changed(current: float, maximum: float)
signal activated
signal activation_rejected(reason: String)
signal field_hit(hit: HitData, hurt: CombatHurtBox)
@export_category("Charge")
@export var max_charge: float = 100.0
@export var initial_charge: float = 0.0
@export var light_gain: float = 6.0
@export var heavy_gain: float = 8.0
@export var perfect_guard_gain: float = 12.0
@export_category("Cutting Sphere")
@export var radius: float = 3.2
@export var duration: float = 4.0
@export var tick_interval: float = 0.25
@export var damage_per_tick: float = 8.0
@export_category("Vortex Capture")
@export var pull_speed: float = 7.0
@export var slot_spacing: float = 1.05
@export var capture_interval: float = 0.1
@export var placement_distance: float = 3.0
var charge: float = 0.0
var field: MusouSphere
var player: Player
var combat: PlayerCombat
var skills: ActiveSkillController
var guard: GuardController
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
func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("musou"):
		try_activate()
func add_charge(amount: float) -> void:
	if combat.health.is_dead or is_instance_valid(field):
		return
	charge = clampf(charge + maxf(amount, 0.0), 0.0, max_charge)
	charge_changed.emit(charge, max_charge)
func _on_weapon_hit(hit: HitData, _hurt: CombatHurtBox) -> void:
	if hit.attacker == player and hit.grants_musou:
		add_charge(heavy_gain if hit.is_heavy else light_gain)
func _on_guard(_hit: HitData, perfect: bool) -> void:
	if perfect:
		add_charge(perfect_guard_gain)
func try_activate() -> bool:
	if combat.health.is_dead or not player.is_physics_processing():
		return false
	if is_instance_valid(field):
		activation_rejected.emit("MUSOU JA ATIVA")
		return false
	if charge < max_charge:
		activation_rejected.emit("MUSOU: CARGA INSUFICIENTE")
		return false
	if not player.is_on_floor() or player.is_in_group("air_combo"):
		activation_rejected.emit("MUSOU: USE NO CHAO")
		return false
	var movement := player.movement_controller
	var forward := movement.mesh_root.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var origin := player.global_position + Vector3.UP * 1.1
	var center := origin + forward * maxf(placement_distance, 0.0)
	var space := player.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(origin, center, 1, [player.get_rid()])
	var wall := space.intersect_ray(ray)
	if not wall.is_empty():
		center = wall.position - forward * 0.3
	var floor_ray := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 2.0, center - Vector3.UP * 4.0, 1, [player.get_rid()])
	var ground := space.intersect_ray(floor_ray)
	if ground.is_empty():
		activation_rejected.emit("MUSOU: SEM CHAO A FRENTE")
		return false
	center.y = ground.position.y + 1.1
	# Consome so apos validar; cancela guarda/ataque, sem invulnerabilidade.
	guard.stop_guard()
	skills.cancel_attack()
	movement.evading = false
	charge = 0.0
	charge_changed.emit(charge, max_charge)
	field = MusouSphere.new()
	field.caster = player
	field.radius = radius
	field.duration = duration
	field.tick_interval = tick_interval
	field.damage_per_tick = damage_per_tick
	field.pull_speed = pull_speed
	field.slot_spacing = slot_spacing
	field.capture_interval = capture_interval
	field.hit_landed.connect(func(hit: HitData, hurt: CombatHurtBox): field_hit.emit(hit, hurt))
	# Irmao do Player: nao acompanha movimento e desaparece junto com a partida.
	player.get_parent().add_child(field)
	field.global_position = center
	activated.emit()
	return true
func _on_death() -> void:
	charge = 0.0
	charge_changed.emit(charge, max_charge)
	if is_instance_valid(field):
		field.queue_free()
