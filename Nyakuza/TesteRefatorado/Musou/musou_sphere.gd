extends Node3D
class_name MusouSphere
## Um campo fixo. Dano usa pulsos de fisica, nao a animacao visual.
signal hit_landed(hit: HitData, hurt: CombatHurtBox)
var caster: Player
var radius: float = 3.2
var duration: float = 4.0
var tick_interval: float = 0.25
var damage_per_tick: float = 8.0
var age: float = 0.0
var next_tick: float = 0.0
var pulse_count: int = 0
var visual_material: ShaderMaterial
var rings: Array[MeshInstance3D] = []
func _ready() -> void:
	add_to_group("musou_fields")
	radius = maxf(radius, 0.1)
	duration = maxf(duration, 0.1)
	tick_interval = maxf(tick_interval, 0.05)
	_build_visuals()
func _physics_process(delta: float) -> void:
	if not is_instance_valid(caster) or not caster.is_physics_processing():
		queue_free()
		return
	age = minf(age + delta, duration)
	while next_tick < age and next_tick < duration:
		_pulse()
		next_tick += tick_interval
	if age >= duration:
		queue_free()
func _process(delta: float) -> void:
	for i in rings.size():
		rings[i].rotate_object_local(Vector3(1.0, 0.3, 0.2).normalized(), delta * (2.0 + float(i) * 0.8))
	var fade := minf(clampf(age / 0.12, 0.0, 1.0), clampf((duration - age) / 0.35, 0.0, 1.0))
	visual_material.set_shader_parameter("opacity", fade * 0.38)
func _pulse() -> void:
	pulse_count += 1
	# Uma consulta ao grupo por pulso (4 Hz), sem referencias persistentes a mortos.
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead() or not enemy.hurt_box.can_receive_hits:
			continue
		var center := enemy.global_position + Vector3.UP
		if center.distance_squared_to(global_position) > radius * radius:
			continue
		var ray := PhysicsRayQueryParameters3D.create(global_position, center, 1)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var hit := HitData.new()
		hit.attacker = caster
		hit.damage = damage_per_tick
		hit.knockback = 0.0
		hit.affects_air_reaction = false
		hit.stagger_duration = 0.12
		hit.show_damage_popup = pulse_count % 4 == 1
		# Nao quebra postura nem gera carga; nao muda launcher/slam.
		hit.direction = (center - global_position).normalized()
		enemy.hurt_box.receive_hit(hit)
		hit_landed.emit(hit, enemy.hurt_box)
func _build_visuals() -> void:
	visual_material = ShaderMaterial.new()
	visual_material.shader = preload("res://TesteRefatorado/Musou/cutting_sphere.gdshader")
	var shell := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	shell.mesh = sphere
	shell.material_override = visual_material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.45, 0.85, 1.0)
	# Tres laminas orbitais, geometria compartilhada; nenhum spawn a cada tick.
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.025
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 4
	for i in 3:
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.material_override = ring_mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		ring.rotation = Vector3(float(i) * 0.9 + 0.3, float(i), float(i) * 0.65)
		rings.append(ring)
