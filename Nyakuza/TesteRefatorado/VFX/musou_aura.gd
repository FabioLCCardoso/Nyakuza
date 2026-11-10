extends Node3D
var age: float = 0.0
var material: ShaderMaterial
func _ready() -> void:
	name = "MusouAura"
	add_to_group("musou_auras")
	position.y = 1.05
	var shell := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.85
	sphere.height = 2.65
	sphere.radial_segments = 24
	sphere.rings = 12
	shell.mesh = sphere
	material = ShaderMaterial.new()
	material.shader = preload("res://TesteRefatorado/VFX/musou_aura.gdshader")
	shell.material_override = material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell)
func _process(delta: float) -> void:
	age += delta
	material.set_shader_parameter("phase", age)
