extends StaticBody3D
class_name BreakableCrate
signal broken
@export var max_health: float = 20.0
@export var heal_amount: float = 30.0
@export var model_scene: PackedScene
@export var pickup_scene: PackedScene = preload("res://TesteRefatorado/Pickups/HealingPickup.tscn")
var health: float
var destroyed: bool = false
var hurt_box: CombatHurtBox
func _ready() -> void:
	add_to_group("breakable_crates")
	collision_layer = 1
	collision_mask = 0
	health = maxf(max_health, 1)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, 1.1, 1.1)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.55
	add_child(collision)
	var visual := Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	if model_scene != null:
		visual.add_child(model_scene.instantiate())
	else:
		for part in [Vector3(1.05, 1.05, 1.05), Vector3(1.13, 0.13, 1.13), Vector3(0.13, 1.13, 1.13)]:
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = part
			mesh.mesh = box
			mesh.position.y = 0.55
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.3, 0.12, 0.055) if is_equal_approx(part.x, 1.05) else Color(0.12, 0.8, 0.65)
			mesh.material_override = mat
			visual.add_child(mesh)
	hurt_box = CombatHurtBox.new()
	hurt_box.name = "HurtBox"
	hurt_box.team = CombatHurtBox.Team.BREAKABLE
	var hurt_shape := CollisionShape3D.new()
	hurt_shape.shape = shape
	hurt_shape.position.y = 0.55
	hurt_box.add_child(hurt_shape)
	add_child(hurt_box)
	hurt_box.hit_received.connect(_receive_hit)
func _receive_hit(hit: HitData) -> void:
	if destroyed or not hit.attacker is Player or hit.damage <= 0: return
	health = maxf(0, health - hit.damage)
	if health > 0: return
	destroyed = true
	hurt_box.can_receive_hits = false
	set_deferred("collision_layer", 0)
	broken.emit()
	_drop.call_deferred()
func _drop() -> void:
	var pickup := pickup_scene.instantiate() as HealingPickup
	if pickup != null:
		pickup.heal_amount = heal_amount
		get_parent().add_child(pickup)
		pickup.global_position = global_position
	CombatVFX.get_manager(get_tree()).burst(global_position + Vector3.UP * 0.6, Vector3.UP, 10, 0.5, Color(0.4, 0.18, 0.08), true)
	queue_free()
