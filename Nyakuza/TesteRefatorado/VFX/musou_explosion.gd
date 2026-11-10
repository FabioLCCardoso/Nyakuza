extends Node3D
var radius: float = 6.0
var age: float = 0.0
var material: StandardMaterial3D
func _ready() -> void:
	add_to_group("musou_explosions")
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 32
	sphere.rings = 16
	mesh.mesh = sphere
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.1, 0.6, 1, 0.6)
	material.emission_enabled = true
	material.emission = Color(0.02, 0.25, 0.8)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	scale = Vector3.ONE * 0.1
func _process(delta: float) -> void:
	age += delta
	var progress := clampf(age / 0.45, 0, 1)
	scale = Vector3.ONE * maxf(0.1, radius * (1.0 - pow(1.0 - progress, 3)))
	material.albedo_color.a = (1 - progress) * 0.6
	if progress >= 1: queue_free()
