extends Node3D
## Tres presets sob a mesma luz, sem ondas e sem controles de combate.
func _ready() -> void:
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color(0.10, 0.12, 0.18)
	environment.environment = sky
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -35, 0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	add_child(light)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0, 2.6, 8)
	camera.look_at(Vector3(0, 1, 0))
	camera.current = true
	var names := ["NOIR — contraste", "BALANCED — jogo", "SOFT — suave"]
	var paths := ["toon_noir.tres", "toon_balanced.tres", "toon_soft.tres"]
	for i in 3:
		var body := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.55
		mesh.height = 1.8
		body.mesh = mesh
		var material := load("res://TesteRefatorado/Visuals/" + paths[i]).duplicate() as ShaderMaterial
		material.set_shader_parameter("base_color", Color(0.9, 0.4, 0.16))
		body.material_override = material
		body.position = Vector3(float(i - 1) * 2.5, 1.1, 0)
		add_child(body)
		var label := Label3D.new()
		label.text = names[i]
		label.position = Vector3(float(i - 1) * 2.5, -0.1, 0)
		label.font_size = 42
		label.pixel_size = 0.006
		add_child(label)
