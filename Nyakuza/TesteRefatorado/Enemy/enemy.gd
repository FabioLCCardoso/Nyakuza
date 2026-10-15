extends CharacterBody3D
class_name Enemy
## Inimigo simples: parado -> persegue -> ataca. Reage a golpes com stagger / knockup e morre em 0 de vida.
## Tudo que da pra ajustar esta nos @export abaixo (aba Inspector).

signal died(enemy : Enemy)

enum State { IDLE, CHASE, ATTACK_WINDUP, ATTACK_ACTIVE, ATTACK_RECOVER, STAGGER, AIRBORNE, DEAD }

@export_category("Stats")
@export var max_health : float = 60.0
@export var move_speed : float = 3.6
@export var turn_speed : float = 10.0

@export_category("AI Ranges")
## Distancia em que o inimigo "acorda" e comeca a andar ate o player.
@export var chase_range : float = 16.0
## Se o player fugir alem disso, o inimigo desiste e volta a ficar parado.
@export var lose_range : float = 30.0
## Distancia em que ele para de andar e ataca.
@export var attack_range : float = 1.9

@export_category("Attack")
@export var attack_damage : float = 8.0
@export var attack_knockback : float = 5.0
## Tempo de preparacao (telegrafo vermelho). Da tempo do player reagir.
@export var attack_windup : float = 0.45
## Tempo em que a hitbox do inimigo fica ligada.
@export var attack_active : float = 0.2
@export var attack_recover : float = 0.6
@export var attack_cooldown : float = 0.6
@export var attack_animation : StringName = &"Punch_Jab"

@export_category("Hit Reaction")
@export var gravity : float = 26.0
@export var knockback_friction : float = 16.0
## Quanto tempo o corpo fica no chao antes de afundar e sumir.
@export var corpse_time : float = 4.0

@export_category("Look")
@export var tint : Color = Color(0.55, 0.1, 0.1)

# Nomes das animacoes DEPOIS do import do Godot (ele remove o sufixo "_Loop" dos nomes do .glb).
const ANIM_IDLE : StringName = &"Idle"
const ANIM_RUN : StringName = &"Jog_Fwd"
const ANIM_HIT : StringName = &"Hit_Chest"
const ANIM_AIR : StringName = &"Hit_Head"
const ANIM_DEATH : StringName = &"Death01"

const STYLIZED_SHADER : Shader = preload("res://shaders/stylized.gdshader")
const JUGGLE_LIFT : float = 4.0   # impulso minimo quando acerta alguem que ja esta no ar

@onready var model : Node3D = $Model
@onready var health : HealthComponent = $HealthComponent
@onready var hurt_box : CombatHurtBox = $HurtBox
@onready var attack_box : Area3D = $AttackHitBox

var anim : AnimationPlayer
var state : State = State.IDLE
var state_timer : float = 0.0
var attack_cd : float = 0.0
var knock_velocity : Vector3 = Vector3.ZERO
var target : Node3D
var speed_mult : float = 1.0
var attack_hit_done : bool = false

var flash_mat : StandardMaterial3D
var flash_tween : Tween
var bar_mat : ShaderMaterial
var bar_mesh : MeshInstance3D

func _ready():
	add_to_group("enemies")
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer

	health.max_health = max_health
	health.reset()
	hurt_box.hit_received.connect(_on_hit_received)

	attack_box.collision_layer = 0
	attack_box.collision_mask = HitData.LAYER_PLAYER_HURT
	attack_box.monitorable = false
	attack_box.monitoring = false

	speed_mult = randf_range(0.92, 1.08)
	_setup_visuals()
	_build_health_bar()

	_play(ANIM_IDLE)
	if anim != null:
		anim.seek(randf() * anim.current_animation_length, true)  # desincroniza os inimigos

func is_dead() -> bool:
	return state == State.DEAD

# ------------------------------------------------------------------ loop principal
func _physics_process(delta):
	attack_cd = maxf(attack_cd - delta, 0.0)
	state_timer -= delta

	match state:
		State.IDLE: _process_idle()
		State.CHASE: _process_chase(delta)
		State.ATTACK_WINDUP: _process_attack_windup(delta)
		State.ATTACK_ACTIVE: _process_attack_active()
		State.ATTACK_RECOVER: _process_attack_recover()
		State.STAGGER: _process_stagger(delta)
		State.AIRBORNE: _process_airborne(delta)
		State.DEAD: _process_dead(delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	move_and_slide()

func _enter(new_state : State, duration : float = 0.0) -> void:
	if state == State.ATTACK_ACTIVE:
		attack_box.set_deferred("monitoring", false)
	state = new_state
	state_timer = duration
	match new_state:
		State.ATTACK_ACTIVE:
			attack_hit_done = false
			attack_box.set_deferred("monitoring", true)
			_flash(Color(1.0, 0.3, 0.1, 0.55), 0.2)

# ------------------------------------------------------------------ estados
func _process_idle() -> void:
	_set_horizontal(Vector3.ZERO)
	_play(ANIM_IDLE)
	var t := _get_target()
	if t != null and _flat_distance(t) < chase_range:
		_enter(State.CHASE)

func _process_chase(delta : float) -> void:
	var t := _get_target()
	if t == null:
		_enter(State.IDLE)
		return
	var to := _flat_to(t)
	var dist := to.length()
	if dist > lose_range:
		_enter(State.IDLE)
		return
	var dir := to / dist if dist > 0.001 else Vector3.FORWARD
	_face(dir, delta)

	if dist <= attack_range:
		_set_horizontal(Vector3.ZERO)
		_play(ANIM_IDLE)
		var facing := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
		if attack_cd <= 0.0 and facing.dot(dir) > 0.8:
			_start_attack()
	else:
		var move_dir := (dir + _separation() * 0.8).normalized()
		_set_horizontal(move_dir * move_speed * speed_mult)
		_play(ANIM_RUN, move_speed * speed_mult / 3.6)

func _start_attack() -> void:
	_enter(State.ATTACK_WINDUP, attack_windup)
	if anim != null:
		# Estica/encolhe a animacao para ela durar windup + active + recover.
		var total := attack_windup + attack_active + attack_recover
		var length := anim.get_animation(attack_animation).length
		_play(attack_animation, length / total, 0.1, true)
	# Telegrafo: o inimigo vai ficando vermelho durante o windup.
	if flash_tween != null:
		flash_tween.kill()
	flash_mat.albedo_color = Color(1.0, 0.1, 0.05, 0.0)
	flash_tween = create_tween()
	flash_tween.tween_property(flash_mat, "albedo_color:a", 0.45, attack_windup)

func _process_attack_windup(delta : float) -> void:
	_set_horizontal(Vector3.ZERO)
	var t := _get_target()
	if t != null:
		_face(_flat_to(t).normalized(), delta * 0.5)
	if state_timer <= 0.0:
		_enter(State.ATTACK_ACTIVE, attack_active)

func _process_attack_active() -> void:
	_set_horizontal(Vector3.ZERO)
	if not attack_hit_done:
		for area in attack_box.get_overlapping_areas():
			if area is CombatHurtBox:
				attack_hit_done = true
				_deliver_hit(area)
				break
	if state_timer <= 0.0:
		_enter(State.ATTACK_RECOVER, attack_recover)

func _process_attack_recover() -> void:
	_set_horizontal(Vector3.ZERO)
	if state_timer <= 0.0:
		attack_cd = attack_cooldown * randf_range(0.8, 1.3)
		_enter(State.CHASE)

func _process_stagger(delta : float) -> void:
	_set_horizontal(knock_velocity)
	knock_velocity = knock_velocity.move_toward(Vector3.ZERO, knockback_friction * delta)
	if state_timer <= 0.0:
		attack_cd = maxf(attack_cd, 0.3)
		_enter(State.CHASE)

func _process_airborne(delta : float) -> void:
	_set_horizontal(knock_velocity)
	knock_velocity = knock_velocity.move_toward(Vector3.ZERO, knockback_friction * 0.25 * delta)
	# velocity.y <= 0 evita "pousar" no mesmo frame em que foi lancado.
	if velocity.y <= 0.0 and is_on_floor():
		knock_velocity = Vector3.ZERO
		_enter(State.STAGGER, 0.35)
		_play(ANIM_HIT, 1.0, 0.05, true)

func _process_dead(delta : float) -> void:
	_set_horizontal(knock_velocity)
	knock_velocity = knock_velocity.move_toward(Vector3.ZERO, knockback_friction * delta)

# ------------------------------------------------------------------ dano
func _deliver_hit(hurt : CombatHurtBox) -> void:
	var hit := HitData.new()
	hit.attacker = self
	hit.damage = attack_damage
	hit.knockback = attack_knockback
	var flat := hurt.global_position - global_position
	flat.y = 0.0
	hit.direction = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
	hurt.receive_hit(hit)

func _on_hit_received(hit : HitData) -> void:
	if state == State.DEAD:
		return
	health.take_damage(hit.damage)
	DamagePopup.spawn(get_tree(), global_position + Vector3(0.0, 2.2, 0.0), str(int(hit.damage)))
	_flash(Color(1.0, 1.0, 1.0, 0.9), 0.15)
	_update_health_bar()

	if health.is_dead:
		_die(hit)
		return

	knock_velocity = hit.direction * hit.knockback
	if hit.knockup > 0.0:
		# LAUNCHER: joga pro alto
		velocity.y = hit.knockup
		_enter(State.AIRBORNE)
		_play(ANIM_AIR, 1.0, 0.05, true)
	elif state == State.AIRBORNE:
		# Ja esta no ar: o golpe segura ele la em cima (juggle)
		velocity.y = maxf(velocity.y, JUGGLE_LIFT)
		_play(ANIM_AIR, 1.0, 0.05, true)
	else:
		# STAGGER: interrompe qualquer ataque e trava por stagger_duration
		_enter(State.STAGGER, hit.stagger_duration)
		var hit_len := anim.get_animation(ANIM_HIT).length if anim != null else 0.33
		_play(ANIM_HIT, hit_len / maxf(hit.stagger_duration, 0.2), 0.03, true)

func _die(hit : HitData) -> void:
	_enter(State.DEAD)
	remove_from_group("enemies")
	collision_layer = 0   # ninguem mais colide com o corpo, mas ele ainda colide com o chao (mask)
	hurt_box.set_deferred("monitorable", false)
	knock_velocity = hit.direction * hit.knockback * 0.7
	_play(ANIM_DEATH, 1.0, 0.05, true)
	if bar_mesh != null:
		bar_mesh.hide()
	died.emit(self)
	_cleanup_later()

func _cleanup_later() -> void:
	await get_tree().create_timer(corpse_time).timeout
	if not is_inside_tree():
		return
	set_physics_process(false)
	collision_mask = 0
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 1.5, 1.2)
	tw.tween_callback(queue_free)

# ------------------------------------------------------------------ helpers
func _get_target() -> Node3D:
	if is_instance_valid(target) and target.is_in_group("player"):
		return target
	target = get_tree().get_first_node_in_group("player") as Node3D
	return target

func _flat_to(t : Node3D) -> Vector3:
	var to := t.global_position - global_position
	to.y = 0.0
	return to

func _flat_distance(t : Node3D) -> float:
	return _flat_to(t).length()

func _set_horizontal(v : Vector3) -> void:
	velocity.x = v.x
	velocity.z = v.z

func _face(dir : Vector3, delta : float) -> void:
	if dir.length_squared() < 0.0001:
		return
	# O modelo olha para +Z, entao yaw = atan2(x, z) (mesma convencao do MovementController do player).
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(turn_speed * delta, 0.0, 1.0))

func _separation() -> Vector3:
	# Empurrao leve para os inimigos nao virarem uma pilha so.
	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var off : Vector3 = global_position - other.global_position
		off.y = 0.0
		var d := off.length()
		if d > 0.001 and d < 1.4:
			push += off / d * (1.4 - d)
	return push

func _play(anim_name : StringName, speed : float = 1.0, blend : float = 0.15, restart : bool = false) -> void:
	if anim == null:
		return
	if restart or anim.current_animation != String(anim_name):
		anim.play(anim_name, blend)
	anim.speed_scale = speed

# ------------------------------------------------------------------ visual
func _setup_visuals() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = STYLIZED_SHADER
	mat.set_shader_parameter("albedo_color", tint)
	mat.set_shader_parameter("albedo_affect", 0.8)
	mat.set_shader_parameter("use_stepped", true)
	mat.set_shader_parameter("steps", 3.0)
	mat.set_shader_parameter("step_smoothness", 0.3)
	mat.set_shader_parameter("shadow_tint", Color(0, 0, 0, 1))
	mat.set_shader_parameter("shadow_tint_amount", 0.4)
	mat.set_shader_parameter("use_rim", true)
	mat.set_shader_parameter("rim_color", Color(1, 1, 1, 1))
	mat.set_shader_parameter("rim_amount", 2.0)
	mat.set_shader_parameter("rim_smoothness", 0.2)

	# Overlay usado para o flash branco (acertou) e para o telegrafo vermelho (vai atacar).
	flash_mat = StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_color = Color(1, 1, 1, 0)

	for m in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.material_override = mat
		mi.material_overlay = flash_mat

func _flash(color : Color, duration : float) -> void:
	if flash_mat == null:
		return
	if flash_tween != null:
		flash_tween.kill()
	flash_mat.albedo_color = color
	flash_tween = create_tween()
	flash_tween.tween_property(flash_mat, "albedo_color:a", 0.0, duration)

func _build_health_bar() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float ratio = 1.0;
uniform vec4 fg_color : source_color = vec4(0.9, 0.12, 0.12, 1.0);
uniform vec4 bg_color : source_color = vec4(0.04, 0.04, 0.04, 0.85);
void vertex() {
	// billboard: sempre de frente para a camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	vec4 c = UV.x <= ratio ? fg_color : bg_color;
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
"""
	bar_mat = ShaderMaterial.new()
	bar_mat.shader = shader
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 0.09)
	bar_mesh = MeshInstance3D.new()
	bar_mesh.mesh = quad
	bar_mesh.material_override = bar_mat
	bar_mesh.position = Vector3(0.0, 2.05, 0.0)
	bar_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bar_mesh)
	bar_mesh.hide()   # so aparece depois do primeiro dano

func _update_health_bar() -> void:
	if bar_mesh == null:
		return
	bar_mat.set_shader_parameter("ratio", health.get_ratio())
	bar_mesh.visible = true
