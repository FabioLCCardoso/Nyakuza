extends Node3D
## Varredura do segmento a cada frame evita atravessar paredes e hurtboxes.
var shooter: Node3D
var damage: float = 9.0
var speed: float = 14.0
var direction: Vector3 = Vector3.FORWARD
var lifetime: float = 2.0
func _ready() -> void:
	add_to_group("enemy_projectiles")
	var visual := MeshInstance3D.new()
	var shape := SphereMesh.new(); shape.radius = .085; shape.height = .17
	shape.radial_segments = 8; shape.rings = 4; visual.mesh = shape
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1,.35,.08); visual.material_override = mat
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(visual)
func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0 or not is_instance_valid(shooter) or shooter.is_queued_for_deletion():
		queue_free(); return
	var destination := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position,destination,1 | HitData.LAYER_PLAYER_HURT)
	query.collide_with_areas = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		var hurt := result.collider as CombatHurtBox
		if hurt != null:
			var hit := HitData.new(); hit.attacker=shooter; hit.damage=damage
			hit.knockback=2; hit.stagger_duration=.18; hit.direction=direction
			hurt.receive_hit(hit)
		queue_free(); return
	global_position = destination
