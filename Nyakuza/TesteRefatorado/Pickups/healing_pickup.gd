extends Area3D
class_name HealingPickup
signal collected(player: Player, amount: float)
@export var heal_amount: float = 30.0
@export var model_scene: PackedScene
var consumed: bool = false
var visual: Node3D
var age: float = 0
var poll_left: float = 0
func _ready() -> void:
	add_to_group("healing_pickups")
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.85
	shape.shape = sphere
	shape.position.y = 0.7
	add_child(shape)
	visual = Node3D.new()
	visual.name = "Visual"
	visual.position.y = 0.65
	add_child(visual)
	if model_scene != null:
		visual.add_child(model_scene.instantiate())
	else:
		_box(Vector3(0.55, 0.65, 0.28), Vector3.ZERO, Color(0.92, 1, 0.96))
		_box(Vector3(0.11, 0.4, 0.04), Vector3(0, 0, 0.16), Color(0.05, 0.85, 0.3))
		_box(Vector3(0.35, 0.11, 0.04), Vector3(0, 0, 0.16), Color(0.05, 0.85, 0.3))
	body_entered.connect(_on_body_entered)
func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.25
	node.material_override = mat
	visual.add_child(node)
func _process(delta: float) -> void:
	age += delta
	visual.rotation.y += delta * 1.4
	visual.position.y = 0.65 + sin(age * 3) * 0.1
func _physics_process(delta: float) -> void:
	poll_left -= delta
	if poll_left > 0 or consumed: return
	poll_left = 0.1
	# Permite recolher se perder vida enquanto ja esta sobre o item.
	for body in get_overlapping_bodies(): _on_body_entered(body)
func _on_body_entered(body: Node3D) -> void:
	if body is Player: try_collect(body)
func try_collect(player: Player) -> bool:
	if consumed or get_tree().paused: return false
	var health := player.get_node_or_null("HealthComponent") as HealthComponent
	if health == null or health.is_dead or health.current_health >= health.max_health or heal_amount <= 0: return false
	consumed = true
	var before := health.current_health
	health.heal(heal_amount)
	collected.emit(player, health.current_health - before)
	DamagePopup.spawn(get_tree(), player.global_position + Vector3.UP * 2, "+%d HP" % roundi(health.current_health - before), Color(0.2, 1, 0.5))
	queue_free()
	return true
