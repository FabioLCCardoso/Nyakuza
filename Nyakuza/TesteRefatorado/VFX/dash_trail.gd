extends MeshInstance3D
## Uma malha limitada por dash, amostrada no mundo e descartada apos dissipar.
var source: Node3D
var emit_duration: float = 0.22
var lifetime: float = 0.22
var width: float = 0.65
var age: float = 0.0
var points: Array[Vector3] = []
var ages: Array[float] = []
var ribbon := ImmediateMesh.new()
func _ready() -> void:
	add_to_group("dash_trails")
	mesh = ribbon
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = mat
func _physics_process(delta: float) -> void:
	age += delta
	if is_instance_valid(source) and source.is_physics_processing() and age <= emit_duration:
		points.append(source.global_position + Vector3.UP)
		ages.append(age)
	while not ages.is_empty() and (age - ages[0] > lifetime or ages.size() > 24):
		ages.pop_front()
		points.pop_front()
	ribbon.clear_surfaces()
	if points.size() >= 2:
		ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(points.size() - 1):
			var a := to_local(points[i])
			var b := to_local(points[i + 1])
			for offset in [Vector3.UP * width, Vector3.RIGHT * width * 0.5]:
				for vertex in [a - offset, a + offset, b + offset, a - offset, b + offset, b - offset]:
					ribbon.surface_set_color(Color(0.15, 0.7, 1, clampf(1 - (age - ages[i]) / lifetime, 0, 1) * 0.7))
					ribbon.surface_add_vertex(vertex)
		ribbon.surface_end()
	if age > emit_duration + lifetime: queue_free()
