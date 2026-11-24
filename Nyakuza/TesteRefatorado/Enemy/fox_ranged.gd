extends Enemy
class_name FoxRanged
@export var preferred_distance: float = 7.0
@export var retreat_distance: float = 4.0
@export var bullet_speed: float = 14.0
@export var aim_lock_time: float = 0.25
@export var dodge_cooldown: float = 4.0
@export var dodge_duration: float = 0.22
@export var dodge_speed: float = 7.0
var dodge_left: float = 0.0
var dodge_cd: float = 0.0
var dodge_direction: Vector3
var aim_point: Vector3
var aim_line: MeshInstance3D

func _ready() -> void:
	super._ready()
	if attack_coordinator == null:
		attack_coordinator = AttackCoordinator.new()
		get_parent().add_child(attack_coordinator)
	# Grip calculado na pose de mira importada; a arma segue o osso em todos os clipes.
	anim.play("Aim_Hold"); anim.seek(0, true)
	var sk := model.find_child("Skeleton3D", true, false) as Skeleton3D
	sk.force_update_all_bone_transforms()
	var hand := sk.get_bone_global_pose(sk.find_bone("mixamorig_RightHand"))
	weapon.basis = hand.basis.inverse().orthonormalized()
	weapon.position = Vector3(0, 0.045, 0)
	_play(ANIM_IDLE, 1, 0, true)
	aim_line = MeshInstance3D.new()
	var line := BoxMesh.new(); line.size = Vector3(.025, .025, 1)
	aim_line.mesh = line
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, .12, .22); aim_line.material_override = mat
	aim_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(aim_line); aim_line.top_level = true; aim_line.hide()

func _physics_process(delta):
	dodge_cd = maxf(0, dodge_cd - delta)
	dodge_left = maxf(0, dodge_left - delta)
	super._physics_process(delta)
	if aim_line != null: aim_line.visible = state == State.ATTACK_WINDUP and not is_musou_captured()

func _sample_weapon_hits() -> void:
	pass # Glock só causa dano pelo projétil, nunca pela hitbox herdada de espada.

func _clear_shot(victim: Node3D) -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.25, victim.global_position + Vector3.UP, 1)).is_empty()

func _process_chase(delta: float) -> void:
	var victim := _get_target()
	if victim == null:
		_enter(State.IDLE); return
	var inward := _flat_to(victim).normalized()
	var distance := _flat_distance(victim)
	if distance > lose_range:
		_enter(State.IDLE); return
	_face(inward, delta)
	if dodge_left > 0:
		_set_horizontal(dodge_direction * dodge_speed); return
	if distance < retreat_distance and dodge_cd <= 0 and is_on_floor():
		dodge_direction = (-inward + Vector3(-inward.z,0,inward.x) * flank_side * .65).normalized()
		if not test_move(global_transform, dodge_direction * dodge_speed * dodge_duration):
			dodge_left = dodge_duration; dodge_cd = dodge_cooldown
			_set_horizontal(dodge_direction * dodge_speed)
			_play("Walk_Backward_While_Shooting_inplace", 1.6); return
	if distance <= attack_range and distance >= retreat_distance and attack_cd <= 0 and _clear_shot(victim):
		_start_attack()
		if state == State.ATTACK_WINDUP: return
	var tangent := Vector3(-inward.z,0,inward.x) * flank_side
	var radial := clampf((distance - preferred_distance) * .5, -1, 1)
	var direction := (inward * radial + tangent * .35 + _separation() * .7).normalized()
	if test_move(global_transform, direction * .5):
		flank_side *= -1; direction = -tangent
	_set_horizontal(direction * move_speed * .65)
	_play("Walk_Backward_While_Shooting_inplace" if radial < -.2 else "Walk_Left_with_Gun_inplace")

func _start_attack() -> void:
	var victim := _get_target()
	if victim == null or is_musou_captured() or not _clear_shot(victim): return
	if not attack_coordinator.request_shot(self): return
	aim_point = victim.global_position + Vector3.UP
	_enter(State.ATTACK_WINDUP, attack_windup)
	_set_horizontal(Vector3.ZERO)
	_play("Aim_Hold", 1, .10, true)

func _process_attack_windup(delta: float) -> void:
	_set_horizontal(Vector3.ZERO)
	var victim := _get_target()
	if victim == null or not _clear_shot(victim):
		attack_cd = .4; _enter(State.CHASE); return
	if state_timer > aim_lock_time:
		aim_point = victim.global_position + Vector3.UP
		_face(_flat_to(victim).normalized(), delta)
	var muzzle := weapon.get_node("Muzzle") as Marker3D
	var origin := muzzle.global_position
	var offset := aim_point-origin
	if offset.length_squared() > .01:
		aim_line.global_position = (origin+aim_point)*.5
		aim_line.look_at(aim_point, Vector3.UP)
		aim_line.scale = Vector3(1,1,offset.length())
	if state_timer <= 0:
		_enter(State.ATTACK_ACTIVE, attack_active)
		_play("Run_and_Shoot", 1, .04, true)

func _process_attack_active() -> void:
	_set_horizontal(Vector3.ZERO)
	if not attack_hit_done:
		attack_hit_done = true
		var bullet := preload("res://TesteRefatorado/Enemy/ranged_bullet.gd").new()
		bullet.shooter = self; bullet.damage = attack_damage; bullet.speed = bullet_speed
		get_parent().add_child(bullet)
		bullet.global_position = weapon.get_node("Muzzle").global_position
		bullet.direction = (aim_point-bullet.global_position).normalized()
	if state_timer <= 0:
		_enter(State.ATTACK_RECOVER, attack_recover)
		_play("Standing_Reload", anim.get_animation("Standing_Reload").length / attack_recover, .12, true)

func _enter(new_state: State, duration: float = 0) -> void:
	if new_state != State.CHASE: dodge_left = 0
	if not new_state in [State.ATTACK_WINDUP, State.ATTACK_ACTIVE] and is_instance_valid(attack_coordinator):
		attack_coordinator.release_shot(self)
	super._enter(new_state, duration)
