extends SceneTree
var checks: int = 0
var failures: int = 0
var normal_inputs: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func key(down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_R
	event.pressed = down
	Input.parse_input_event(event)
func mouse(button: MouseButton, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = down
	Input.parse_input_event(event)
func run() -> void:
	var game := load("res://TesteRefatorado/Campaign/Campaign.tscn").instantiate() as CityCampaign
	root.add_child(game)
	current_scene = game
	game.director.set_physics_process(false)
	var player := game.player
	var health := player.get_node("HealthComponent") as HealthComponent
	var mode := player.get_node("MusouController") as MusouController
	var hitbox := player.find_child("HitBox", true, false) as CombatHitBox
	var dash := player.get_node("DashController") as DashController
	health.invincible = true
	await frames(30)
	check(get_nodes_in_group("breakable_crates").size() == 8, "Duas caixas em cada distrito")
	var crate := get_nodes_in_group("breakable_crates")[0] as BreakableCrate
	var pickup_position := crate.global_position
	var skill := ActiveSkill.new()
	skill.damage = 25
	hitbox.current_skill = skill
	hitbox.already_hit.clear()
	hitbox.use_hit_stop = false
	hitbox._try_hit(crate.hurt_box)
	hitbox._try_hit(crate.hurt_box)
	await frames(2)
	check(not is_instance_valid(crate), "Ataque da arma quebra caixa")
	check(get_nodes_in_group("healing_pickups").size() == 1, "Uma caixa gera somente um item")
	check(game.director.kos == 0 and mode.charge == 0, "Caixas nao dao KO nem carga")
	var pickup := get_nodes_in_group("healing_pickups")[0] as HealingPickup
	check(not pickup.try_collect(player) and not pickup.consumed, "HP cheio preserva item")
	health.current_health = 85
	player.global_position = pickup_position
	await frames(12)
	check(health.current_health == 100 and not is_instance_valid(pickup), "Passar sobre item cura e limita ao maximo")
	pickup = load("res://TesteRefatorado/Pickups/HealingPickup.tscn").instantiate() as HealingPickup
	game.add_child(pickup)
	pickup.position = Vector3(0, 0.5, 0)
	health.current_health = 20
	check(pickup.try_collect(player) and health.current_health == 50, "Cura configurada de 30 HP")
	check(not pickup.try_collect(player) and health.current_health == 50, "Coleta nao duplica cura")
	player.global_position = Vector3(0, 0.55, 0)
	await frames(60)
	check(not mode.try_activate(), "Sem carga nao ativa modo")
	mode.add_charge(1000)
	check(mode.charge == mode.max_charge, "Carga limitada")
	player.pressed_primary_fire.connect(func(): normal_inputs += 1)
	player.pressed_heavy_fire.connect(func(): normal_inputs += 1)
	key(true)
	await frames(2)
	check(mode.active and mode.charge == 0 and mode.time_left <= 30, "R ativa modo de 30s e consome barra")
	check(not is_instance_valid(mode.field), "Ativacao sozinha nao dispara esfera")
	check(health.max_health == 150 and health.current_health == 100, "Ativacao concede mais 50 HP atual e maximo")
	check(get_nodes_in_group("musou_auras").size() == 1, "Aura azul criada")
	check(not mode.try_activate() and health.max_health == 150, "Nao acumula bonus reativando")
	mode.add_charge(100)
	check(mode.charge == 0, "Modo ativo nao recarrega barra")
	mouse(MOUSE_BUTTON_LEFT, true)
	await frames(2)
	mouse(MOUSE_BUTTON_LEFT, false)
	await frames(1)
	check(is_instance_valid(mode.field) and normal_inputs == 0, "R + LMB dispara esfera sem ataque comum")
	check(mode.field.damage_per_tick == 12, "Esfera recebe bonus de dano")
	check(not mode.try_sphere(), "Esfera respeita recarga e limite de um campo")
	mode.field.queue_free()
	await frames(2)
	var enemy := game.director.penguin_scene.instantiate() as Enemy
	game.add_child(enemy)
	enemy.position = player.position + Vector3(2, 0, 0)
	enemy.set_physics_process(false)
	enemy.health.current_health = 30
	mouse(MOUSE_BUTTON_RIGHT, true)
	await frames(2)
	mouse(MOUSE_BUTTON_RIGHT, false)
	key(false)
	await frames(1)
	check(is_equal_approx(enemy.health.current_health, 6), "Explosao causa 40% de HP maximo (24 de 60)")
	check(normal_inputs == 0, "R + RMB nao dispara ataque pesado")
	check(not mode.try_explosion() and enemy.health.current_health == 6, "Explosao tem recarga")
	var outside := game.director.penguin_scene.instantiate() as Enemy
	game.add_child(outside)
	outside.position = player.position + Vector3(15, 0, 0)
	outside.set_physics_process(false)
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 4, 4)
	shape.shape = box
	wall.add_child(shape)
	wall.position = player.position + Vector3(1, 1, 0)
	game.add_child(wall)
	await frames(2)
	mode.explosion_left = 0
	mode.try_explosion()
	check(enemy.health.current_health == 6 and outside.health.current_health == 60, "Parede e distancia bloqueiam explosao")
	wall.free()
	enemy.health.current_health = 60
	hitbox.already_hit.clear()
	skill.damage = 10
	hitbox._try_hit(enemy.hurt_box)
	check(enemy.health.current_health == 45 and skill.damage == 10, "Arma tem +50% sem modificar Resource compartilhado")
	enemy.health.current_health = 1
	mode.explosion_left = 0
	var before_kos := game.director.kos
	mode.try_explosion()
	check(enemy.is_dead() and game.director.kos == before_kos + 1, "Explosao letal registra KO")
	mode.explosion_left = 0
	mode.try_explosion()
	check(game.director.kos == before_kos + 1, "Explosao nao conta cadaver novamente")
	var saved_time := mode.time_left
	var saved_cooldown := mode.explosion_left
	paused = true
	await frames(20)
	check(mode.time_left == saved_time and mode.explosion_left == saved_cooldown, "Pausa congela modo e recarga")
	paused = false
	health.current_health = 145
	mode._physics_process(31)
	await frames(2)
	check(not mode.active and health.max_health == 100 and health.current_health == 100, "Fim restaura limite e limita HP excedente")
	check(get_nodes_in_group("musou_auras").is_empty() and get_nodes_in_group("musou_fields").is_empty(), "Fim remove aura e campo")
	check(mode.get_damage_multiplier() == 1 and not mode.try_explosion(), "Fim remove dano extra e bloqueia especiais")
	dash.dash()
	await frames(5)
	check(get_nodes_in_group("dash_trails").size() == 1, "Dash cria rastro")
	var trail = get_nodes_in_group("dash_trails")[0]
	check(trail.points.size() >= 2 and trail.mesh.get_surface_count() == 1, "Rastro registra deslocamento em malha")
	await frames(40)
	check(get_nodes_in_group("dash_trails").is_empty(), "Rastro desaparece e libera malha")
	await frames(20)
	mode.add_charge(100)
	check(mode.try_activate(), "Pode recarregar e reativar")
	health.invincible = false
	health.take_damage(9999)
	await frames(2)
	check(not mode.active and health.max_health == 100 and health.current_health == 0, "Morte remove bonus sem reviver")
	pickup = load("res://TesteRefatorado/Pickups/HealingPickup.tscn").instantiate() as HealingPickup
	game.add_child(pickup)
	check(not pickup.try_collect(player), "Item nao revive morto")
	paused = false
	game.free()
	skill.free()
	await frames(4)
	check(get_nodes_in_group("healing_pickups").is_empty() and get_nodes_in_group("dash_trails").is_empty() and get_nodes_in_group("musou_auras").is_empty(), "Trocar cena limpa itens e efeitos")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
