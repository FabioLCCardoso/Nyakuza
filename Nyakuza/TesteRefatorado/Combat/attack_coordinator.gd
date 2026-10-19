extends Node
class_name AttackCoordinator
## Vagas incluem windup, active e recover. Fila de espera sem referencias fortes.
@export_range(1, 16) var max_attackers: int = 2
@export_range(1, 8) var max_area_attackers: int = 1
@export_range(0.0, 1.0) var start_spacing: float = 0.18
@export var enabled: bool = true
var holders: Dictionary = {}
var waiting: Array[WeakRef] = []
var spacing_left: float = 0.0

func _ready() -> void:
	add_to_group("attack_coordinator")
	Performance.add_custom_monitor("Nyakuza/Attacking", active_count)

func _exit_tree() -> void:
	if Performance.has_custom_monitor("Nyakuza/Attacking"):
		Performance.remove_custom_monitor("Nyakuza/Attacking")

func _physics_process(delta: float) -> void:
	spacing_left = maxf(spacing_left - delta, 0.0)
	for id in holders.keys():
		var enemy: Enemy = holders[id].get_ref() as Enemy
		if enemy == null or not enemy.is_inside_tree() or not enemy.state in [Enemy.State.ATTACK_WINDUP, Enemy.State.ATTACK_ACTIVE, Enemy.State.ATTACK_RECOVER]:
			holders.erase(id)

func active_count() -> int:
	return holders.size()

func _eligible(enemy: Enemy) -> bool:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.is_dead():
		return false
	if not enemy.state in [Enemy.State.IDLE, Enemy.State.CHASE]:
		return false
	var target: Node3D = enemy._get_target()
	if not is_instance_valid(target) or target.is_in_group("air_combo"):
		return false
	return absf(target.global_position.y - enemy.global_position.y) < 1.8 and enemy._flat_distance(target) <= enemy.attack_range + 0.15

func request_attack(enemy: Enemy) -> bool:
	if not enabled:
		return true
	if not _eligible(enemy):
		return false
	var id: int = enemy.get_instance_id()
	if holders.has(id):
		return true
	var found: bool = false
	for reference in waiting:
		if reference.get_ref() == enemy:
			found = true
	if not found:
		waiting.append(weakref(enemy))
	# Evita fila de mortos/fora de alcance mesmo quando todas as vagas estao ocupadas.
	for i in range(waiting.size() - 1, -1, -1):
		if not _eligible(waiting[i].get_ref() as Enemy):
			waiting.remove_at(i)
	if holders.size() >= max_attackers or spacing_left > 0.0:
		return false
	var area_count: int = 0
	for reference in holders.values():
		var holder := reference.get_ref() as Enemy
		if is_instance_valid(holder) and holder.area_attack_radius > 0.0:
			area_count += 1
	for i in waiting.size():
		var candidate := waiting[i].get_ref() as Enemy
		if candidate.area_attack_radius > 0.0 and area_count >= max_area_attackers:
			continue
		if candidate != enemy:
			return false
		waiting.remove_at(i)
		holders[id] = weakref(enemy)
		spacing_left = start_spacing
		return true
	return false

func release(enemy: Enemy) -> void:
	holders.erase(enemy.get_instance_id())
	for i in range(waiting.size() - 1, -1, -1):
		if waiting[i].get_ref() == null or waiting[i].get_ref() == enemy:
			waiting.remove_at(i)
