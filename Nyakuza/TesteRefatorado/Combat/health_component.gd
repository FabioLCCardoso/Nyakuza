extends Node
class_name HealthComponent
## Vida generica. Serve para player e inimigos.
## Nao sabe nada de animacao, stagger, etc. So controla o numero e avisa por sinais.

signal health_changed(current : float, maximum : float)
signal damaged(amount : float)
signal died

@export var max_health : float = 100.0
## Quando true, take_damage() nao faz nada (usado pelo "god mode" para gravar o teaser).
@export var invincible : bool = false

var current_health : float = -1.0
var is_dead : bool = false

# _enter_tree roda ANTES de qualquer _ready da cena, entao a HUD e os outros
# nos ja encontram current_health preenchido quando se conectarem.
func _enter_tree():
	if current_health < 0.0:
		current_health = max_health

func take_damage(amount : float) -> void:
	if is_dead or invincible or amount <= 0.0:
		return
	current_health = clampf(current_health - amount, 0.0, max_health)
	damaged.emit(amount)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		is_dead = true
		died.emit()

func heal(amount : float) -> void:
	if is_dead or amount <= 0.0:
		return
	current_health = clampf(current_health + amount, 0.0, max_health)
	health_changed.emit(current_health, max_health)

func reset() -> void:
	is_dead = false
	current_health = max_health
	health_changed.emit(current_health, max_health)

func get_ratio() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0
