##CENA VIBECODADA.

extends Node3D
## F6 nesta cena. 1/2/3 troca 16/32/64 inimigos; F7 mede 600 frames apos aquecimento.
@export var enemy_count: int = 16
@export var warmup_frames: int = 180
@export var sample_frames: int = 600
var game: Node3D
var director: WaveDirector
var coordinator: AttackCoordinator
var label: Label
var rebuilding: bool = false
var sampling: bool = false
var frame: int = 0
var grid_clock: float = 0.0
var rows: Array[Dictionary] = []
var spawn_ms: Array[float] = []
var result_path: String = "user://nyakuza_benchmark.json"
var automatic: bool = false
var last_spawn_ms: float = 0.0

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 30
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	canvas.add_child(label)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="):
			enemy_count = int(arg.get_slice("=", 1))
		elif arg.begins_with("--result="):
			result_path = arg.trim_prefix("--result=")
		elif arg == "--auto":
			automatic = true
	Performance.add_custom_monitor("Nyakuza/Spawn_ms", func() -> float: return last_spawn_ms)
	Performance.add_custom_monitor("Nyakuza/Alive", func() -> int: return director.alive.size() if is_instance_valid(director) else 0)
	_setup.call_deferred()

func _exit_tree() -> void:
	for id in ["Nyakuza/Spawn_ms", "Nyakuza/Alive"]:
		if Performance.has_custom_monitor(id):
			Performance.remove_custom_monitor(id)

func _setup() -> void:
	if rebuilding:
		return
	rebuilding = true
	enemy_count = clampi(enemy_count, 1, 128)
	sample_frames = maxi(sample_frames, 1)
	warmup_frames = maxi(warmup_frames, 0)
	sampling = false
	if is_instance_valid(game):
		game.queue_free()
		await get_tree().process_frame
	seed(1977)
	game = load("res://TesteRefatorado/Scene/CombatScene.tscn").instantiate()
	director = game.get_node("WaveDirector") as WaveDirector
	director.auto_start = false
	(game.get_node("Player/PlayerCombat") as PlayerCombat).god_mode = true
	add_child(game)
	game.get_node("CombatHUD").hide()
	coordinator = game.get_node("AttackCoordinator") as AttackCoordinator
	spawn_ms.clear()
	var scenes: Array[PackedScene] = [director.penguin_scene, director.fox_scene, director.red_panda_scene]
	for i in enemy_count:
		var begin: int = Time.get_ticks_usec()
		var enemy := scenes[i % 3].instantiate() as Enemy
		var angle: float = TAU * float(i) / enemy_count
		var radius: float = 4.0 + (i % 4) * 1.5
		enemy.position = Vector3(cos(angle) * radius, 0.55, sin(angle) * radius)
		game.add_child(enemy)
		director.register_enemy(enemy)
		last_spawn_ms = (Time.get_ticks_usec() - begin) / 1000.0
		spawn_ms.append(last_spawn_ms)
		await get_tree().physics_frame
	rebuilding = false
	_start_capture()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or rebuilding:
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3:
			enemy_count = 16 if event.keycode == KEY_1 else (32 if event.keycode == KEY_2 else 64)
			_setup()
		KEY_F7:
			_start_capture()

func _start_capture() -> void:
	rows.clear()
	frame = 0
	sampling = true

func _physics_process(delta: float) -> void:
	if rebuilding or not is_instance_valid(director):
		return
	# Ondas ficam paradas; mantem o mesmo servico de separacao do jogo normal.
	grid_clock -= delta
	if grid_clock <= 0.0:
		grid_clock = director.separation_interval
		director._rebuild_grid()

func _process(_delta: float) -> void:
	if rebuilding:
		label.text = "Preparando %d inimigos..." % enemy_count
		return
	if not sampling:
		return
	frame += 1
	label.text = "BENCHMARK %d inimigos | 1:16  2:32  3:64 | F7 repetir\n%s %d / %d | slots %d\nInvencivel; ondas desligadas; mantenha-se parado para comparar." % [enemy_count, "Aquecimento" if frame <= warmup_frames else "Captura", mini(frame, warmup_frames) if frame <= warmup_frames else frame - warmup_frames, warmup_frames if frame <= warmup_frames else sample_frames, coordinator.active_count()]
	if frame <= warmup_frames:
		return
	rows.append({"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, "physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "memory_mib": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "attackers": coordinator.active_count()})
	if rows.size() >= sample_frames:
		_finish_capture()

func _summary(values: Array[float]) -> Dictionary:
	values.sort()
	var sum: float = 0.0
	for value in values:
		sum += value
	return {"mean": sum / maxi(values.size(), 1), "p95": values[mini(floori(values.size() * 0.95), values.size() - 1)], "max": values.back()}

func _finish_capture() -> void:
	sampling = false
	var report: Dictionary = {"engine": Engine.get_version_info().string, "headless": DisplayServer.get_name() == "headless", "enemy_count": enemy_count, "warmup_frames": warmup_frames, "sample_frames": sample_frames, "seed": 1977, "measurement_note": "Performance monitors may update at roughly 1 second intervals; sample percentiles are not per-frame CPU percentiles. Run capped at 60 FPS without --fixed-fps for measurements.", "scenario": "stationary invincible player, mixed enemy AI, no player attacks", "spawn_ms": _summary(spawn_ms.duplicate()), "samples": rows}
	for key in ["process_ms", "physics_ms", "nodes", "memory_mib", "draw_calls", "attackers"]:
		var values: Array[float] = []
		for row in rows:
			values.append(float(row[key]))
		report[key] = _summary(values)
	var file := FileAccess.open(result_path, FileAccess.WRITE)
	if file == null:
		push_error("Nao foi possivel gravar " + result_path)
		if automatic:
			get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	label.text = "Captura concluida: " + result_path + "\n1/2/3 muda carga; F7 repete. Detalhes no Debugger/Profiler."
	print("BENCH_RESULT ", enemy_count, " process_ms=", report.process_ms, " physics_ms=", report.physics_ms, " spawn_ms=", report.spawn_ms)
	if automatic:
		get_tree().quit()
