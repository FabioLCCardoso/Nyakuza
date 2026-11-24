extends MeshInstance3D
## Faixa em espaço global: as amostras antigas não giram junto com a mão.
const LIFE := 0.13
const MAX_POINTS := 32
var blade: Node3D
var base_local: Vector3
var tip_local: Vector3
var emitting := false
var ribbon := ImmediateMesh.new()
var bases: Array[Vector3] = []
var tips: Array[Vector3] = []
var times: Array[float] = []
var clock := 0.0

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	mesh = ribbon
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	material_override = mat
	process_priority = 10
	hide()
	set_process(false)

func set_swing(active: bool) -> void:
	if active and not emitting:
		bases.clear()
		tips.clear()
		times.clear()
		clock = 0.0
	emitting = active
	if active: set_process(true)

func _process(delta: float) -> void:
	clock += delta
	while not times.is_empty() and (clock - times[0] >= LIFE or times.size() >= MAX_POINTS):
		bases.pop_front()
		tips.pop_front()
		times.pop_front()
	if emitting and is_instance_valid(blade):
		var tip := blade.to_global(tip_local)
		var base := blade.to_global(base_local)
		if tips.is_empty() or tip.distance_squared_to(tips.back()) + base.distance_squared_to(bases.back()) > 0.000004:
			bases.append(base)
			tips.append(tip)
			times.append(clock)
	ribbon.clear_surfaces()
	visible = times.size() >= 2
	if not visible:
		if times.is_empty() and not emitting: set_process(false)
		return
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in times.size():
		var fade := clampf(1.0 - (clock - times[i]) / LIFE, 0, 1)
		ribbon.surface_set_color(Color(0.7, 0.004, 0.008, fade * 0.15))
		ribbon.surface_add_vertex(bases[i])
		ribbon.surface_set_color(Color(1, 0.025, 0.012, fade * 0.95))
		ribbon.surface_add_vertex(tips[i])
	ribbon.surface_end()
