extends Enemy
class_name CookieBoss
## Chefe Cookie integrado ao controlador da campanha.
signal phase_changed(phase: int)
@export_range(.1, .9) var phase_threshold: float = .55
@export_range(0, .9) var phase_damage_reduction: float = .35
var boss_phase: int = 1
var phase_pending: bool = false
var transforming: bool = false
var aura: Node3D
var attack_index: int = 0
var radial_skill: bool = false
func _ready() -> void:
	super._ready()
	health.health_changed.connect(_health_changed)
func _health_changed(current: float, maximum: float) -> void:
	if current > 0 and current <= maximum * phase_threshold and boss_phase == 1:
		boss_phase = 2; phase_pending = true; phase_changed.emit(2)
func _physics_process(delta):
	if phase_pending and not is_dead() and is_on_floor() and not is_musou_captured() and not state in [State.STAGGER, State.AIRBORNE]:
		phase_pending = false
		if is_instance_valid(attack_coordinator): attack_coordinator.release(self)
		_enter(State.ATTACK_RECOVER, anim.get_animation("Skill_01").length)
		transforming = true
		_flash(Color(1,.06,.1,.25), .15)
		_play("Skill_01", 1, .08, true)
		aura = preload("res://TesteRefatorado/VFX/musou_aura.gd").new()
		aura.aura_color = Color(1,.035,.06); add_child(aura)
	super._physics_process(delta)
func incoming_damage(hit: HitData) -> float:
	return hit.damage * (1.0 - phase_damage_reduction) if boss_phase == 2 else hit.damage
func _enter(new_state: State, duration: float = 0) -> void:
	if new_state != State.ATTACK_RECOVER: transforming = false
	super._enter(new_state, duration)
func _process_attack_recover() -> void:
	if transforming and state_timer > 0:
		_set_horizontal(Vector3.ZERO); return
	transforming = false
	super._process_attack_recover()
func _start_attack() -> void:
	if phase_pending or transforming: return
	var pattern := attack_index % (4 if boss_phase == 2 else 2)
	radial_skill = pattern == 3
	ground_strike = false
	match pattern:
		0:
			attack_animation = &"Right_Hand_Sword_Slash"
			attack_windup=.48; attack_active=.40; attack_recover=.42; attack_damage=20; area_attack_radius=0
		1:
			attack_animation = &"Double_Combo_Attack"
			attack_windup=.65; attack_active=1.15; attack_recover=.65; attack_damage=26; area_attack_radius=0
		2:
			attack_animation = &"Charged_Slash"
			attack_windup=.85; attack_active=.55; attack_recover=.65; attack_damage=34; area_attack_radius=0
		3:
			attack_animation = &"Skill_03"
			attack_windup=.95; attack_active=.30; attack_recover=.75; attack_damage=32; area_attack_radius=3.4
	attack_cooldown = .65 if boss_phase == 2 else 1.0
	if area_indicator != null:
		var ring := area_indicator.mesh as TorusMesh
		var radius := maxf(area_attack_radius, .2) / maxf(absf(global_basis.get_scale().x),.01)
		ring.inner_radius = maxf(.02,radius-.08); ring.outer_radius=radius
	super._start_attack()
	if state == State.ATTACK_WINDUP:
		attack_index += 1
		if area_indicator != null: area_indicator.visible = radial_skill
func _process_attack_active() -> void:
	if not radial_skill:
		super._process_attack_active(); return
	_set_horizontal(Vector3.ZERO)
	if not attack_hit_done:
		attack_hit_done = true; _deliver_area_attack()
		CombatVFX.get_manager(get_tree()).ground_impact(global_position, area_attack_radius)
	if state_timer <= 0: _enter(State.ATTACK_RECOVER, attack_recover)
func _sample_weapon_hits() -> void:
	if not radial_skill: super._sample_weapon_hits()
func _die(hit: HitData) -> void:
	phase_pending = false; transforming = false
	if is_instance_valid(aura): aura.queue_free()
	super._die(hit)

func _deliver_area_attack() -> void:
	var victim := _get_target()
	if victim == null: return
	var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP, victim.global_position+Vector3.UP, 1)
	if get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): super._deliver_area_attack()
