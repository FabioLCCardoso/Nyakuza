extends Node3D
## Aura procedural compartilhada por Spike e Cookie. Sem texturas externas.
@export var aura_color: Color = Color(.03, .35, 1.0)
@export_range(0.1, 3.0) var intensity: float = 1.0
@export_range(16, 128) var flame_count: int = 48
var age: float = 0.0
var material: ShaderMaterial
var pulse: MeshInstance3D
var pulse_material: StandardMaterial3D

func _ready() -> void:
	name = "MusouAura"
	add_to_group("musou_auras")
	material = ShaderMaterial.new()
	material.shader = preload("res://TesteRefatorado/VFX/musou_aura.gdshader")
	material.set_shader_parameter("aura_color", aura_color)
	_make_particles("HeatFlames", flame_count, .65, Vector3(.48,.68,.30), Vector2(.38,.95), true)
	_make_particles("HeatWake", 20, .35, Vector3(.35,.55,.25), Vector2(.22,.55), false)
	_make_particles("HeatSparks", 20, .8, Vector3(.48,.7,.35), Vector2(.035,.16), false)
	pulse = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = .75
	ring.outer_radius = .85
	pulse.mesh = ring
	pulse.position.y = .12
	pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pulse_material = StandardMaterial3D.new()
	pulse_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pulse_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pulse_material.emission_enabled = true
	pulse_material.emission = aura_color
	pulse_material.emission_energy_multiplier = 2.0
	pulse.material_override = pulse_material
	add_child(pulse)

func _make_particles(label: String, count: int, duration: float, box: Vector3, size: Vector2, attached: bool) -> void:
	var emitter := GPUParticles3D.new()
	emitter.name = label
	emitter.amount = count
	emitter.lifetime = duration
	emitter.local_coords = attached
	emitter.position.y = .9
	emitter.visibility_aabb = AABB(Vector3(-5,-3,-5),Vector3(10,9,10))
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = box
	process.direction = Vector3.UP
	process.spread = 18.0
	process.gravity = Vector3(0,.4,0)
	process.initial_velocity_min = .7
	process.initial_velocity_max = 1.8
	process.scale_min = .65
	process.scale_max = 1.25
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1,1,1,0))
	gradient.set_color(1, Color(1,1,1,0))
	gradient.add_point(.15, Color.WHITE)
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	emitter.process_material = process
	var quad := QuadMesh.new()
	quad.size = size
	quad.material = material
	emitter.draw_pass_1 = quad
	add_child(emitter)

func _process(delta: float) -> void:
	age += delta
	material.set_shader_parameter("phase", age)
	material.set_shader_parameter("intensity", intensity * minf(age / .18, 1.0))
	if is_instance_valid(pulse):
		var progress := clampf(age / .55, 0, 1)
		pulse.scale = Vector3.ONE * lerpf(.3, 2.1, progress)
		pulse_material.albedo_color = Color(aura_color, (1-progress)*.65)
		if progress >= 1: pulse.queue_free()
