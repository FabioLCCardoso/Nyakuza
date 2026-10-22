extends SceneTree
## Execute: godot --headless --path . --script res://TesteRefatorado/Tests/combat_regression.gd
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame

func strike(enemy: Enemy, damage: float, launch: float = 0.0, slam: bool = false) -> void:
	var hit := HitData.new()
	hit.damage = damage
	hit.knockup = launch
	hit.slam = slam
	hit.attacker = current_scene.get_node("Player")
	enemy.hurt_box.receive_hit(hit)

func _run() -> void:
	var scene := load("res://TesteRefatorado/Scene/CombatScene.tscn") as PackedScene
	check(scene != null, "Cena principal carrega")
	var game := scene.instantiate()
	root.add_child(game)
	current_scene = game
	var director := game.get_node("WaveDirector") as WaveDirector
	var player := game.get_node("Player") as Player
	var health := player.get_node("HealthComponent") as HealthComponent
	var skills := player.find_child("SkillsContainer", true, false) as SkillsContainer
	var skill_controller := player.get_node("ActiveSkillController") as ActiveSkillController
	var movement := player.get_node("MovementController") as MovementController
	var air := player.get_node("AirComboController") as AirComboController
	var guard := player.get_node("GuardController") as GuardController
	health.invincible = true
	director.countdown = 0.05
	director.max_alive = 3
	for wave in director.waves:
		wave.spawn_interval = 0.05
		wave.rest_time = 0.05
	await frames(90)
	check(director.alive.size() == 3 and director.pending.size() == 5, "Limite de 3 vivos preserva fila da primeira onda")
	var first := director.alive.values()[0] as Enemy
	var before: int = director.kos
	strike(first, 9999)
	strike(first, 9999)
	check(director.kos == before + 1, "Morte repetida gera exatamente um KO")
	check(not first.hurt_box.can_receive_hits, "Cadaver deixa de receber acertos imediatamente")
	await frames(12)
	check(director.alive.size() == 3, "Spawner repoe uma vaga enquanto ainda ha fila")
	var removed := director.alive.values()[0] as Enemy
	before = director.kos
	removed.queue_free()
	await frames(3)
	check(director.kos == before, "Remocao sem morte nao concede KO")
	# Bloqueio de spawn nunca consome a fila.
	director.min_player_distance = 1000.0
	var remaining: int = director.pending.size()
	for value in director.alive.values():
		strike(value as Enemy, 9999)
	await frames(20)
	check(director.pending.size() == remaining and not director.pending.is_empty(), "Pontos bloqueados mantem inimigos pendentes")
	director.min_player_distance = 5.0
	# Let complete waves spawn naturally; remove enemies with damage only.
	var max_observed: int = 0
	for i in range(1500):
		await frames(1)
		max_observed = maxi(max_observed, director.alive.size())
		if i % 6 == 0:
			for value in director.alive.values():
				strike(value as Enemy, 9999)
		if director.phase == WaveDirector.Phase.COMPLETE:
			break
	check(director.phase == WaveDirector.Phase.COMPLETE, "Quatro ondas chegam a vitoria")
	check(director.kos == 61, "62 inimigos: 61 KOs + 1 removido sem KO")
	check(max_observed <= 3, "Nenhuma onda ultrapassa o limite configurado")
	check(director.pending.is_empty() and director.alive.is_empty(), "Vitoria apenas com fila e vivos vazios")
	# Exercise all real enemy prefabs and their attack/reaction differences.
	var tank := director.red_panda_scene.instantiate() as Enemy
	game.add_child(tank)
	tank.global_position = player.global_position + Vector3(0, 0.5, 1.6)
	await frames(2)
	check(tank.max_health == 160.0 and tank.stagger_scale < 1.0, "Panda resistente com stagger reduzido")
	var fox := director.fox_scene.instantiate() as Enemy
	game.add_child(fox)
	fox.global_position = player.global_position + Vector3(12, 0.5, 10)
	check(fox.move_speed == 4.8 and fox.attack_windup < 0.4, "Raposa rapida aplica perfil")
	var penguin := director.penguin_scene.instantiate() as Enemy
	game.add_child(penguin)
	penguin.global_position = player.global_position + Vector3(0, 0.5, 2.0)
	await frames(2)
	check(penguin.area_attack_radius == 2.7 and penguin.area_indicator != null, "Pinguim tem AOE e indicador")
	penguin._start_attack()
	check(penguin.area_indicator.visible, "AOE avisa durante preparacao")
	strike(penguin, 1)
	check(not penguin.area_indicator.visible and penguin.state == Enemy.State.STAGGER, "Golpe interrompe AOE e aviso")
	# Disable ordinary attacks while testing player control.
	for enemy in [tank, fox, penguin]:
		enemy.attack_cd = 100.0
	# Etapa 3: teste aereo parte da postura quebrada; quebra real tem suite propria.
	tank.posture = 0.0
	tank.posture_break_left = 6.0
	strike(tank, 1, 9.0)
	await frames(10)
	check(tank.is_juggleable(), "Launcher funciona no tank com postura quebrada")
	check(air.try_follow_up(), "Dash encontra e segue alvo lancado")
	for i in range(60):
		await frames(1)
		if air.state == AirComboController.State.HOVER:
			break
	check(air.state == AirComboController.State.HOVER, "Subida alcanca hover")
	check(skills.air_mode and movement.forced, "Combo aereo troca skills e suspende jogador")
	strike(tank, 1, 0.0, true)
	check(tank.slamming, "Finisher ativa slam")
	await frames(75)
	check(not tank.slamming, "Slam chega ao chao e conclui impacto")
	air.end_air_combo()
	check(not movement.forced and not skills.air_mode, "Fim aereo devolve gravidade e combo de chao")
	# Canceled delayed motion must not reappear inside guard.
	skill_controller.start_attack()
	guard.start_guard()
	await frames(18)
	check(not movement.is_dashing() and skills.attack_state == ActiveSkill.State.READY, "Guarda cancela hitbox e dash atrasado do golpe")
	guard.stop_guard()
	check(skills.end_timer.one_shot, "Temporizador de fim do combo nao repete")
	# Real hit volume: overlapping weapon and reach box must not duplicate damage.
	for enemy in [tank, fox, penguin]:
		enemy.set_physics_process(false)
		enemy.global_position = Vector3(50, 0.5, 50)
	var dummy := director.red_panda_scene.instantiate() as Enemy
	game.add_child(dummy)
	dummy.set_physics_process(false)
	dummy.global_position = player.global_position + Vector3(0, 0.5, 1.5)
	movement.direction = Vector3.BACK
	movement.mesh_root.rotation.y = 0.0
	var hitbox := player.find_child("HitBox", true, false) as CombatHitBox
	hitbox.use_hit_stop = false
	await frames(4)
	var initial_hp: float = dummy.health.current_health
	skill_controller.start_attack()
	await frames(24)
	check(is_equal_approx(initial_hp - dummy.health.current_health, skills.active_skills[0].damage), "Volume real aplica um dano por swing, sem duplicar lamina e alcance")
	skill_controller.cancel_attack()
	var after_cancel: float = dummy.health.current_health
	await frames(20)
	check(is_equal_approx(dummy.health.current_health, after_cancel), "Cancelamento fecha a janela de dano")
	# Enemy attacks really reach the player; immunity suppresses subsequent hits.
	health.invincible = false
	var player_combat := player.get_node("PlayerCombat") as PlayerCombat
	player_combat.invuln_left = 0.0
	penguin.global_position = player.global_position + Vector3(0, 0.5, 2)
	var hp_before: float = health.current_health
	penguin._deliver_area_attack()
	check(health.current_health < hp_before, "AOE do pinguim causa dano dentro do raio")
	var hp_after: float = health.current_health
	penguin._deliver_area_attack()
	check(is_equal_approx(health.current_health, hp_after), "Invulnerabilidade protege de hits simultaneos")
	player_combat.invuln_left = 0.0
	penguin.global_position += Vector3.UP * 6.0
	penguin._deliver_area_attack()
	check(is_equal_approx(health.current_health, hp_after), "AOE nao atinge jogador em outra altura")
	health.invincible = true
	# Perfect guard and hit-stop share time scaling without early restoration.
	penguin.global_position = player.global_position + Vector3(0, 0.5, 2.0)
	player_combat.invuln_left = 0.0
	guard.released_time = 99.0
	guard.start_guard()
	penguin._deliver_area_attack()
	check(penguin.state == Enemy.State.STAGGER and is_equal_approx(health.current_health, hp_after), "Perfect guard anula dano e atordoa atacante")
	guard.stop_guard()
	CombatTimeEffects.request(self, 0.02, 0.05)
	check(is_equal_approx(Engine.time_scale, 0.05), "Hit-stop prevalece sobre slow-motion do parry")
	var real_deadline: int = Time.get_ticks_msec() + 60
	while Time.get_ticks_msec() < real_deadline:
		await process_frame
	check(is_equal_approx(Engine.time_scale, guard.parry_time_scale), "Fim do hit-stop preserva parry ainda ativo")
	# Player death clears attack, buffered input and pending wave spawns.
	director.phase = WaveDirector.Phase.SPAWNING
	director.pending.append(director.penguin_scene)
	skill_controller.start_attack()
	health.invincible = false
	health.take_damage(9999)
	await frames(12)
	check(director.phase == WaveDirector.Phase.DEFEAT and director.pending.is_empty(), "Morte interrompe ondas")
	check(skills.attack_state == ActiveSkill.State.READY and not player.is_physics_processing(), "Morte cancela ataque e movimento")
	check(not movement.forced, "Morte nao deixa movimento aereo travado")
	game.queue_free()
	await frames(3)
	check(is_equal_approx(Engine.time_scale, 1.0), "Encerramento restaura time_scale")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
