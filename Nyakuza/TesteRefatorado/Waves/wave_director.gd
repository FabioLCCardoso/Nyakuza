extends Node3D
class_name WaveDirector
## Ondas finitas, KOs por morte e grade espacial para separacao de multidoes.
signal stats_changed
signal wave_started(number: int, title: String)
signal encounter_finished

enum Phase { WAITING, SPAWNING, FIGHTING, COMPLETE, DEFEAT, ERROR }
@export var waves: Array[WaveDefinition] = []
@export var penguin_scene: PackedScene
@export var fox_scene: PackedScene
@export var red_panda_scene: PackedScene
@export var spawn_points: Node3D
@export var player: Player
@export_range(1, 100) var max_alive: int = 16
@export_range(0.0, 20.0) var initial_delay: float = 2.0
@export_range(0.0, 20.0) var min_player_distance: float = 5.0
@export_range(0.0, 5.0) var spawn_jitter: float = 1.8
@export_range(0.05, 1.0) var separation_interval: float = 0.12
@export var auto_start: bool = true

var phase: Phase = Phase.WAITING
var wave_index: int = -1
var kos: int = 0
var countdown: float = 0.0
var status_message: String = ""
var pending: Array[PackedScene] = []
var alive: Dictionary = {}
var points: Array[Marker3D] = []
var cells: Dictionary = {}
var grid_left: float = 0.0
var spawn_left: float = 0.0
var spawn_cursor: int = 0
var clearance_shape: CapsuleShape3D
const CELL_SIZE: float = 1.6

func _ready() -> void:
	add_to_group("wave_director")
	clearance_shape = CapsuleShape3D.new()
	clearance_shape.radius = 0.48
	clearance_shape.height = 1.9
	if spawn_points != null:
		for child in spawn_points.get_children():
			if child is Marker3D:
				points.append(child)
	if not _validate_configuration():
		return
	var health := player.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		health.died.connect(_on_player_died)
	# Tambem acompanha inimigos colocados manualmente, sem contar queue_free como KO.
	for node in get_tree().get_nodes_in_group("enemies"):
		register_enemy(node as Enemy)
	get_tree().node_added.connect(_on_node_added)
	countdown = initial_delay
	set_physics_process(auto_start)

func _validate_configuration() -> bool:
	if player == null or points.is_empty() or waves.is_empty():
		_fail("Configure Player, Spawn Points (com Marker3D) e Waves.")
		return false
	if penguin_scene == null or fox_scene == null or red_panda_scene == null:
		_fail("Configure as tres cenas de inimigos.")
		return false
	for wave in waves:
		if wave == null or wave.get_total() <= 0:
			_fail("Cada onda precisa de pelo menos um inimigo.")
			return false
	return true

func _fail(message: String) -> void:
	phase = Phase.ERROR
	status_message = message
	push_error("WaveDirector: " + message)
	set_physics_process(false)
	stats_changed.emit()

func _physics_process(delta: float) -> void:
	if phase in [Phase.COMPLETE, Phase.DEFEAT, Phase.ERROR]:
		return
	grid_left -= delta
	if grid_left <= 0.0:
		grid_left = separation_interval
		_rebuild_grid()
	if phase == Phase.WAITING:
		countdown = maxf(countdown - delta, 0.0)
		if countdown <= 0.0:
			_begin_next_wave()
		return
	if phase == Phase.SPAWNING:
		spawn_left -= delta
		if spawn_left <= 0.0 and alive.size() < max_alive:
			spawn_left = maxf(waves[wave_index].spawn_interval, 0.05)
			_try_spawn()
	if pending.is_empty() and alive.is_empty():
		_finish_wave()

func _begin_next_wave() -> void:
	wave_index += 1
	if wave_index >= waves.size():
		phase = Phase.COMPLETE
		stats_changed.emit()
		encounter_finished.emit()
		return
	var wave: WaveDefinition = waves[wave_index]
	pending.clear()
	for i in wave.penguins:
		pending.append(penguin_scene)
	for i in wave.foxes:
		pending.append(fox_scene)
	for i in wave.red_pandas:
		pending.append(red_panda_scene)
	pending.shuffle()
	phase = Phase.SPAWNING
	spawn_left = 0.0
	status_message = ""
	wave_started.emit(wave_index + 1, wave.title)
	stats_changed.emit()

func _try_spawn() -> void:
	if pending.is_empty():
		phase = Phase.FIGHTING
		return
	var location: Variant = _find_spawn_position()
	if location == null:
		status_message = "Afaste-se dos pontos de chegada"
		stats_changed.emit()
		return # nao perde inimigos da fila, nem cria dentro de paredes/jogador
	var instance: Node = pending.back().instantiate()
	var enemy := instance as Enemy
	if enemy == null:
		instance.free()
		_fail("A raiz das cenas de inimigos precisa usar Enemy.")
		return
	enemy.position = to_local(location)
	add_child(enemy)
	register_enemy(enemy)
	pending.pop_back()
	status_message = ""
	if pending.is_empty():
		phase = Phase.FIGHTING
	stats_changed.emit()

func _find_spawn_position() -> Variant:
	if not is_instance_valid(player):
		return null
	var space := get_world_3d().direct_space_state
	for attempt in points.size():
		var marker: Marker3D = points[spawn_cursor % points.size()]
		spawn_cursor += 1
		var pos := marker.global_position + Vector3(randf_range(-spawn_jitter, spawn_jitter), 0, randf_range(-spawn_jitter, spawn_jitter))
		var flat := pos - player.global_position
		flat.y = 0.0
		if flat.length_squared() < min_player_distance * min_player_distance:
			continue
		var ray := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 5.0, pos + Vector3.DOWN * 10.0, 1)
		var ground := space.intersect_ray(ray)
		if ground.is_empty() or (ground["normal"] as Vector3).y < 0.7:
			continue
		pos = ground["position"] + Vector3.UP * 0.05
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = clearance_shape
		query.transform = Transform3D(Basis.IDENTITY, pos + Vector3.UP)
		query.collision_mask = 7 # mundo, jogador, corpos dos inimigos
		if not space.intersect_shape(query, 1).is_empty():
			continue
		return pos
	return null

func _finish_wave() -> void:
	if wave_index == waves.size() - 1:
		phase = Phase.COMPLETE
		encounter_finished.emit()
	else:
		phase = Phase.WAITING
		countdown = maxf(waves[wave_index].rest_time, 0.0)
	stats_changed.emit()

func _on_node_added(node: Node) -> void:
	if node is Enemy:
		register_enemy.call_deferred(node)

func register_enemy(enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead():
		return
	var id: int = enemy.get_instance_id()
	if alive.has(id):
		return
	alive[id] = enemy
	enemy.crowd_director = self
	enemy.died.connect(_on_enemy_died)
	enemy.tree_exiting.connect(_on_enemy_removed.bind(id), CONNECT_ONE_SHOT)
	stats_changed.emit()

func _on_enemy_died(enemy: Enemy) -> void:
	var id: int = enemy.get_instance_id()
	if not alive.has(id):
		return
	alive.erase(id)
	if phase != Phase.DEFEAT:
		kos += 1
	stats_changed.emit()

func _on_enemy_removed(id: int) -> void:
	if alive.erase(id):
		stats_changed.emit()

func _on_player_died() -> void:
	phase = Phase.DEFEAT
	pending.clear()
	status_message = ""
	stats_changed.emit()

func _rebuild_grid() -> void:
	cells.clear()
	for value in alive.values():
		var enemy := value as Enemy
		if not is_instance_valid(enemy) or enemy.is_dead():
			continue
		var cell := _cell(enemy.global_position)
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(enemy)

func _cell(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CELL_SIZE), floori(pos.z / CELL_SIZE))

func get_separation(enemy: Enemy) -> Vector3:
	var origin := _cell(enemy.global_position)
	var push := Vector3.ZERO
	for x in range(-1, 2):
		for z in range(-1, 2):
			var neighbors: Array = cells.get(origin + Vector2i(x, z), [])
			for other in neighbors:
				if not is_instance_valid(other) or other == enemy or other.is_dead():
					continue
				var offset: Vector3 = enemy.global_position - other.global_position
				if absf(offset.y) > 2.0:
					continue
				offset.y = 0.0
				var d2: float = offset.length_squared()
				if d2 > 0.000001 and d2 < 1.96:
					var d: float = sqrt(d2)
					push += offset / d * (1.4 - d)
	return push
