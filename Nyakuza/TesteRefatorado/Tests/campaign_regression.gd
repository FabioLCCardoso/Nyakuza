extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else: print("PASS: " + message)
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func escape() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
func joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
func strike(enemy: Enemy, player: Player) -> void:
	var hit := HitData.new()
	hit.damage = 99999
	hit.attacker = player
	enemy.hurt_box.receive_hit(hit)
func run() -> void:
	var packed := load("res://TesteRefatorado/Campaign/Campaign.tscn") as PackedScene
	var game := packed.instantiate() as CityCampaign
	root.add_child(game)
	current_scene = game
	var health := game.player.get_node("HealthComponent") as HealthComponent
	health.invincible = true
	await frames(8)
	check(game.route.districts.size() == 4, "Quatro distritos")
	check(game.route.gates.size() == 3, "Tres passagens")
	check(game.director.waves.size() == 3 and game.current_area == 0, "Tres ondas na area inicial")
	for i in 3:
		check(game.route.gates[i][0].collision_layer == 1, "Portao %d fechado" % i)
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 2, -25), Vector3(0, 2, -29), 1)
	check(not game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Portao bloqueia fisicamente")
	game._entered(game.player, 2)
	check(game.current_area == 0, "Nao pula distritos")
	var time := game.director.countdown
	var pos := game.player.position
	escape()
	await frames(2)
	check(paused and game.menu.screen.visible, "Esc abre pausa")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Pausa libera mouse")
	var effect := Node3D.new()
	var vfx := CombatVFX.get_manager(self)
	vfx.add_child(effect)
	vfx.register_effect(effect, false, 0.1)
	await frames(20)
	check(game.director.countdown == time and game.player.position == pos, "Pausa congela ondas e jogador")
	check(is_instance_valid(effect), "Pausa preserva tempo de vida dos efeitos")
	game.menu.show_controls(game.menu.show_pause)
	escape()
	await frames(1)
	check(paused and not game.menu.controls_visible, "Esc volta dos controles para pausa")
	game.player.movement_direction = Vector3.BACK
	escape()
	await frames(2)
	check(not paused and game.player.movement_direction == Vector3.ZERO, "Retomar sincroniza movimento")
	joy(JOY_BUTTON_B)
	await frames(1)
	check(not paused, "B do controle nao pausa o dash")
	joy(JOY_BUTTON_START)
	await frames(1)
	check(paused, "Start pausa")
	game.menu.resume_game()
	await frames(10)
	check(not is_instance_valid(effect), "Efeitos expiram depois de retomar")
	game.director.initial_delay = 0.01
	game.director.countdown = 0.01
	var expected_kos := 0
	for area in 3:
		if area > 0:
			game.player.position = game.route.center(area) + (Vector3(9, 7.5, 21) if area == 1 else Vector3(0, 0.8, 21))
			await frames(8)
			check(game.current_area == area, "Entrada inicia area %d inclusive no ar" % area)
			check(game.route.gates[area - 1][1].collision_layer == 1, "Fecha portao atras do jogador")
		for wave in game.director.waves:
			expected_kos += wave.get_total()
			wave.spawn_interval = 0.05
			wave.rest_time = 0.01
		game.player.position = game.route.center(area) + Vector3(0, 0.8, 0)
		var seen := {}
		for tick in 1200:
			await frames(1)
			seen[game.director.wave_index] = true
			for enemy in game.director.alive.values(): strike(enemy, game.player)
			if game.stage == CityCampaign.Stage.TRAVEL: break
		check(game.cleared[area] and game.stage == CityCampaign.Stage.TRAVEL, "Todas ondas liberam area %d" % area)
		check(seen.has(0) and seen.has(1) and seen.has(2), "Executou as tres ondas")
		check(game.director.kos == expected_kos, "KOs acumulados entre areas")
		await frames(2)
		check(game.route.gates[area][0].collision_layer == 0, "Saida liberada fisicamente")
		if area == 0:
			check(game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Caminho aberto sem parede invisivel")
	game.player.position = game.route.center(3) + Vector3(0, 0.8, 21)
	await frames(8)
	check(game.stage == CityCampaign.Stage.BOSS and is_instance_valid(game.boss), "Bossfight na quarta area")
	check(game.boss.health.max_health == 900 and game.boss.posture_max == 120, "Chefe tem vida e postura")
	check(game.boss_bar.visible and game.boss_bar.value == 900, "Barra de vida do chefe")
	game.boss.health.take_damage(460)
	check(game.boss.boss_phase == 2 and game.boss_bar.value == 440, "Segunda fase a metade da vida")
	game.boss._start_attack()
	check(game.boss.attack_windup == 0.95 and game.boss.attack_damage == 34, "Fase dois modifica proximo golpe")
	var ring := game.boss.area_indicator.mesh as TorusMesh
	check(is_equal_approx(ring.outer_radius * game.boss.global_basis.get_scale().x, 3.0), "Aviso circular respeita escala do chefe")
	strike(game.boss, game.player)
	await frames(190)
	check(game.stage == CityCampaign.Stage.VICTORY and game.cleared[3], "Vitoria encerra campanha")
	check(game.director.kos == expected_kos + 1, "Chefe conta um KO")
	check(paused and game.menu.result == "victory", "Resultado apos knock down")
	paused = false
	game.free()
	await frames(5)
	game = packed.instantiate() as CityCampaign
	root.add_child(game)
	current_scene = game
	await frames(5)
	game.player.get_node("HealthComponent").take_damage(9999)
	check(game.stage == CityCampaign.Stage.DEFEAT and paused and game.menu.result == "defeat", "Derrota abre menu")
	check(game.director.phase == WaveDirector.Phase.DEFEAT and not game.cleared[0], "Derrota nao libera portao")
	paused = false
	game.free()
	await frames(5)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
