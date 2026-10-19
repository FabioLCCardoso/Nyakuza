extends SceneTree
var failures: int = 0
var checks: int = 0
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
func frames(n: int) -> void:
	for i in n:
		await physics_frame
	await process_frame
func _run() -> void:
	var game: Node3D = load("res://TesteRefatorado/Scene/CombatScene.tscn").instantiate()
	var director: WaveDirector = game.get_node("WaveDirector")
	director.auto_start = false
	(game.get_node("Player/PlayerCombat") as PlayerCombat).god_mode = true
	root.add_child(game)
	current_scene = game
	var player: Player = game.get_node("Player")
	var controller: ActiveSkillController = player.get_node("ActiveSkillController")
	var skills: SkillsContainer = controller.skills_container
	var air: AirComboController = player.get_node("AirComboController")
	var camera: CameraController = player.get_node("CamRoot")
	var coordinator: AttackCoordinator = game.get_node("AttackCoordinator")
	var hitbox: CombatHitBox = player.find_child("HitBox", true, false)
	hitbox.use_hit_stop = false
	await frames(12)
	check(InputMap.has_action("heavy_attack") and InputMap.has_action("guard"), "Acoes pesado/guarda persistem no Input Map")
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	rmb.pressed = true
	check(rmb.is_action("heavy_attack") and not rmb.is_action("guard"), "RMB nao ativa guarda junto com pesado")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	check(key.is_action("guard"), "F mapeado para guarda")
	check(skills.heavy_ground_skill.knockup > 0.0 and skills.heavy_air_skill.slam, "Pesado tem launcher e slam dedicados")
	check(skills.active_skills[2].knockup == 0.0, "Leve final nao duplica funcao do launcher")
	var total: float = 0.0
	for skill in skills.active_skills:
		total += skill.windup_duration + skill.delivery_duration + skill.recovery_duration
		check(skill.hit_delay < skill.delivery_duration, "Janela de dano valida: " + skill.name)
	check(total < 1.5, "Combo terrestre menor que 1.5s sem hit-stop")
	var enemy: Enemy = director.red_panda_scene.instantiate()
	game.add_child(enemy)
	enemy.global_position = player.global_position + Vector3(0, 0.5, 1.5)
	enemy.attack_cd = 100.0
	controller.movement_controller.direction = Vector3.BACK
	controller.movement_controller.mesh_root.rotation.y = 0.0
	await frames(3)
	var hp: float = enemy.health.current_health
	Input.parse_input_event(rmb)
	await frames(20)
	check(skills.current_active_skill == skills.heavy_ground_skill, "Input RMB dispara HeavyLauncher")
	check(enemy.health.current_health < hp and enemy.is_juggleable(), "Hitbox real do pesado causa dano e lanca")
	check(air.try_follow_up(), "Q pode seguir o launcher dedicado")
	for i in 45:
		await frames(1)
		if air.state == AirComboController.State.HOVER:
			break
	check(air.state == AirComboController.State.HOVER and camera.in_air, "Hover ativa camera aerea")
	await frames(20)
	check(camera.spring_arm.spring_length > camera.base_distance + 0.5, "Camera afasta no combo aereo")
	check(camera.position.distance_to(camera.base_position) <= camera.max_focus_offset + 0.01, "Deslocamento de foco limitado")
	var fov_before: float = camera.desired_fov
	camera.set_fov(50.0, true)
	check(is_equal_approx(camera.desired_fov, fov_before), "Ataque nao gera pulsacao de FOV")
	controller.heavy_left = 0.0
	controller.start_attack(true)
	await frames(14)
	check(camera.slamming and skills.current_active_skill == skills.heavy_air_skill, "Pesado aereo inicia slam e camera de descida")
	await frames(80)
	check(not air.is_active() and not camera.in_air, "Slam conclui combo e libera camera")
	await frames(50)
	check(camera.position.distance_to(camera.base_position) < 0.05 and absf(camera.spring_arm.spring_length - camera.base_distance) < 0.05, "Camera retorna suavemente a base")
	# Expiracao de buffer e cancelamento de pesado antes do impacto.
	controller.start_attack()
	controller._queue_attack(true)
	controller.buffer_left = 0.001
	await frames(2)
	check(not controller.attack_buffered, "Buffer antigo expira")
	controller.cancel_attack()
	controller.heavy_left = 0.0
	enemy.set_physics_process(false)
	enemy.global_position = player.global_position + Vector3(0, 0.5, 1.5)
	controller.start_attack(true)
	controller.cancel_attack()
	hp = enemy.health.current_health
	await frames(25)
	check(is_equal_approx(hp, enemy.health.current_health), "Pesado cancelado nao gera golpe atrasado")
	# Coordenacao deterministica: solicitar todos no mesmo frame.
	enemy.queue_free()
	await frames(2)
	var crowd: Array[Enemy] = []
	coordinator.start_spacing = 0.0
	for i in 6:
		var e: Enemy = director.fox_scene.instantiate()
		game.add_child(e)
		e.set_physics_process(false)
		e.global_position = player.global_position + Vector3(0, 0.5, 1.2)
		crowd.append(e)
	for e in crowd:
		e._start_attack()
	check(coordinator.active_count() == 2, "Seis solicitacoes respeitam duas vagas")
	check(crowd[2].state != Enemy.State.ATTACK_WINDUP, "Terceiro inimigo espera")
	crowd[0].on_parried(1.0)
	check(coordinator.active_count() == 1, "Parry libera vaga imediatamente")
	crowd[2]._start_attack()
	check(crowd[2].state == Enemy.State.ATTACK_WINDUP, "Fila entrega vaga ao proximo elegivel")
	crowd[1].queue_free()
	await frames(2)
	check(coordinator.active_count() == 1, "Remocao libera vaga")
	var hit := HitData.new()
	hit.damage = 9999.0
	crowd[2].hurt_box.receive_hit(hit)
	check(coordinator.active_count() == 0, "Morte libera vaga")
	for e in crowd:
		if is_instance_valid(e):
			e.queue_free()
	await frames(2)
	coordinator.waiting.clear()
	var p1: Enemy = director.penguin_scene.instantiate()
	var p2: Enemy = director.penguin_scene.instantiate()
	for e in [p1, p2]:
		game.add_child(e)
		e.set_physics_process(false)
		e.global_position = player.global_position + Vector3(0, 0.5, 1.2)
		e._start_attack()
	check(coordinator.active_count() == 1 and p2.state != Enemy.State.ATTACK_WINDUP, "Somente um AOE simultaneo")
	p1._enter(Enemy.State.IDLE)
	p2._enter(Enemy.State.IDLE)
	coordinator.start_spacing = 0.2
	coordinator.spacing_left = 0.0
	p1._start_attack()
	var fox: Enemy = director.fox_scene.instantiate()
	game.add_child(fox)
	fox.set_physics_process(false)
	fox.global_position = player.global_position + Vector3(0, 0.5, 1.2)
	fox._start_attack()
	check(coordinator.active_count() == 1, "Intervalo evita inicios simultaneos")
	await frames(15)
	fox._start_attack()
	check(coordinator.active_count() == 2, "Intervalo libera novo ataque apos espera")
	player.add_to_group("air_combo")
	p1._process_attack_windup(0.016)
	check(p1.state == Enemy.State.CHASE and coordinator.active_count() == 1, "Subida aerea cancela preparacao inimiga")
	player.remove_from_group("air_combo")
	camera.begin_air(fox)
	fox.queue_free()
	await frames(3)
	camera.end_air(true)
	await frames(60)
	check(camera.air_target == null and camera.position.distance_to(camera.base_position) < 0.05, "Alvo removido nao trava camera")
	game.queue_free()
	await frames(3)
	check(not Performance.has_custom_monitor("Nyakuza/Attacking"), "Monitor de ataques e removido ao fechar cena")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
