extends Node
class_name CombatTimeEffects
## Um unico dono do time_scale: hit-stop e parry nao cancelam um ao outro.
var effects: Array[Vector2] = [] # (fim em segundos reais, escala)
var base_scale: float = 1.0

static func request(tree: SceneTree, duration: float, scale_value: float) -> void:
	if duration <= 0.0 or tree.current_scene == null:
		return
	var controller := tree.current_scene.get_node_or_null("CombatTimeEffects") as CombatTimeEffects
	if controller == null:
		controller = CombatTimeEffects.new()
		controller.name = "CombatTimeEffects"
		tree.current_scene.add_child(controller)
	if controller.effects.is_empty():
		controller.base_scale = Engine.time_scale
	controller.effects.append(Vector2(Time.get_ticks_msec() / 1000.0 + duration, clampf(scale_value, 0.01, 1.0)))
	controller._update_scale()

func _process(_delta: float) -> void:
	_update_scale()

func _update_scale() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	var result: float = base_scale
	for i in range(effects.size() - 1, -1, -1):
		if effects[i].x <= now:
			effects.remove_at(i)
		else:
			result = minf(result, effects[i].y)
	Engine.time_scale = result

func _exit_tree() -> void:
	Engine.time_scale = base_scale
