extends SceneTree
var checks: int = 0
var failures: int = 0
var game: Node3D
var player: Player
var director: WaveDirector
var musou: MusouController
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
	await process_frame
func spawn(scene: PackedScene, offset: Vector3) -> Enemy:
	var e := scene.instantiate() as Enemy
	game.add_child(e)
	e.global_position = player.global_position + offset
	e.set_physics_process(false)
	return e
func hit(e: Enemy, heavy: bool, posture_damage: float = 35.0, launch: float = 10.0) -> void:
	var h := HitData.new()
	h.attacker = player
	h.damage = 1.0
	h.is_heavy = heavy
	h.posture_damage = posture_damage
	h.knockup = launch
	e.hurt_box.receive_hit(h)
func _run() -> void:
	game = load("res://TesteRefatorado/Scene/CombatScene.tscn").instantiate()
	director = game.get_node("WaveDirector")
	director.auto_start = false
	root.add_child(game)
	current_scene = game
	player = game.get_node("Player")
	musou = player.get_node("MusouController")
	var health: HealthComponent = player.get_node("HealthComponent")
	health.invincible = true
	var controller: ActiveSkillController = player.get_node("ActiveSkillController")
	var hitbox: CombatHitBox = player.find_child("HitBox", true, false)
	hitbox.use_hit_stop = false
	await frames(12)
	var elite := spawn(director.red_panda_scene, Vector3(0, 0, 1.2))
	var normal := spawn(director.fox_scene, Vector3(10, 0, 0))
	check(elite.posture == 60.0 and normal.posture_max == 0.0, "Postura somente na classe elite configurada")
	check(elite.posture_bar != null and normal.posture_bar == null, "Barra amarela exclusiva de elites")
	hit(elite, false)
	check(elite.health.current_health == 159.0 and elite.posture == 60.0, "Leve causa dano de vida sem reduzir postura")
	check(elite.state != Enemy.State.AIRBORNE, "Postura impede launcher de hit nao pesado")
	hit(elite, true)
	check(elite.posture == 25.0 and not elite.is_juggleable(), "Primeiro pesado reduz postura mas nao lanca")
	hit(elite, true)
	check(elite.posture == 0.0 and elite.is_juggleable(), "Segundo pesado quebra e lanca no mesmo hit")
	check(not elite.has_posture_armor() and elite.posture_break_left == 6.0, "Quebra abre janela vulneravel")
	elite._tick_posture(10.0)
	check(elite.posture == 0.0, "Postura nao se restaura no ar mesmo apos prazo")
	elite._enter(Enemy.State.CHASE)
	elite.global_position = player.global_position + Vector3(8, 0, 0)
	elite.velocity = Vector3.ZERO
	elite.set_physics_process(true)
	elite.attack_cd = 100.0
	await frames(8)
	check(elite.has_posture_armor(), "Postura retorna apos prazo e aterrissagem")
	elite.set_physics_process(false)
	hit(elite, true, 20.0, 0.0)
	elite._tick_posture(1.0)
	check(elite.posture == 40.0, "Regeneracao respeita atraso")
	elite._tick_posture(3.0)
	check(elite.posture > 40.0 and elite.posture <= elite.posture_max, "Postura regenera sem ultrapassar maximo")
	elite.on_parried(1.0)
	check(elite.state == Enemy.State.STAGGER, "Parry interrompe mesmo com postura intacta")
	var second := spawn(director.red_panda_scene, Vector3(20, 0, 0))
	hit(elite, true, 20.0, 0.0)
	check(second.posture == 60.0 and second.profile.posture_max == 60.0, "Dano nao modifica perfil compartilhado")
	elite.global_position = player.global_position + Vector3(0, 0, 1.4)
	elite.posture = 60.0
	elite.posture_break_left = 0.0
	player.movement_controller.mesh_root.rotation.y = 0.0
	player.movement_controller.direction = Vector3.BACK
	controller.start_attack(true)
	await frames(26)
	check(elite.posture == 25.0, "Hitbox real transmite dano de postura do pesado")
	check(musou.charge == musou.heavy_gain, "Pesado real gera carga uma vez por vitima")
	controller.cancel_attack()
	elite.queue_free()
	second.queue_free()
	normal.queue_free()
	await frames(3)
	var coord: AttackCoordinator = game.get_node("AttackCoordinator")
	coord.start_spacing = 0.0
	var crowd: Array[Enemy] = []
	for i in 6:
		var e := spawn(director.fox_scene, Vector3(sin(float(i)), 0, cos(float(i))) * 1.2)
		e._enter(Enemy.State.CHASE)
		e.rotation.y = atan2(-e.position.x + player.position.x, -e.position.z + player.position.z)
		crowd.append(e)
	for e in crowd:
		e._process_chase(0.1)
	check(coord.active_count() == 2, "Flanqueamento preserva limite de dois atacantes")
	check(Vector2(crowd[2].velocity.x, crowd[2].velocity.z).length() > 0.1, "Inimigo aguardando vaga circula")
	var tangent: Vector3 = crowd[2].velocity.cross(crowd[2]._flat_to(player))
	check(absf(tangent.y) > 0.05, "Espera tem componente lateral")
	crowd[0].on_parried(1.0)
	crowd[2].attack_cd = 0.0
	crowd[2]._process_chase(0.1)
	check(crowd[2].state == Enemy.State.ATTACK_WINDUP, "Inimigo circulando assume vaga liberada")
	var flank := crowd[5]
	flank.global_position = player.global_position + Vector3(0, 0, 5)
	flank._process_chase(0.1)
	check(absf(flank.velocity.x) > 0.1, "Aproximacao busca flanco em vez de linha reta")
	for e in crowd:
		e.queue_free()
	await frames(3)
	musou.charge = 0.0
	check(not musou.try_activate(), "Sem carga nao cria esfera")
	musou.add_charge(1000)
	check(musou.charge == 100.0, "Carga limitada ao maximo")
	player.add_to_group("air_combo")
	check(not musou.try_activate() and musou.charge == 100.0, "Tentativa no ar nao consome carga")
	player.remove_from_group("air_combo")
	musou.charge = 0.0
	musou._on_guard(HitData.new(), false)
	check(musou.charge == 0.0, "Bloqueio comum nao gera carga")
	musou._on_guard(HitData.new(), true)
	check(musou.charge == 12.0, "Perfect guard gera carga")
	musou.add_charge(100)
	player.movement_controller.mesh_root.rotation.y = 0.0
	player.movement_controller.direction = Vector3.BACK
	var r := InputEventKey.new()
	r.physical_keycode = KEY_R
	r.pressed = true
	check(r.is_action("musou"), "R registrado no Input Map")
	Input.parse_input_event(r)
	await frames(2)
	r.pressed = false
	Input.parse_input_event(r)
	check(is_instance_valid(musou.field) and musou.charge == 0.0, "Input real R cria esfera e consome carga")
	var sphere := musou.field
	if not is_instance_valid(sphere):
		quit(1)
		return
	sphere.set_physics_process(false)
	var fixed := sphere.global_position
	player.global_position.x += 1.0
	await frames(2)
	check(sphere.global_position.is_equal_approx(fixed), "Esfera permanece fixa quando jogador anda")
	check(not musou.try_activate() and get_nodes_in_group("musou_fields").size() == 1, "Sem esferas sobrepostas do mesmo caster")
	musou.add_charge(100)
	check(musou.charge == 0.0, "Nao recarrega enquanto esfera ativa")
	var victim := spawn(director.red_panda_scene, Vector3.ZERO)
	victim.global_position = sphere.global_position - Vector3.UP
	var outside := spawn(director.fox_scene, Vector3(30, 0, 0))
	var hp := victim.health.current_health
	sphere._pulse()
	sphere._pulse()
	check(victim.health.current_health == hp - 16.0, "Esfera causa dano repetido de 8 por pulso")
	check(victim.posture == 60.0, "Musou nao substitui pesado na quebra de postura")
	check(outside.health.current_health == outside.max_health, "Alvo fora do raio nao recebe dano")
	check(health.current_health == health.max_health, "Campo nao atinge jogador")
	check(musou.charge == 0.0, "Pulsos nao geram carga recursiva")
	victim.posture = 0.0
	victim.posture_break_left = 6.0
	victim._enter(Enemy.State.AIRBORNE)
	victim.slamming = true
	victim.velocity.y = -30.0
	sphere._pulse()
	check(victim.slamming and victim.velocity.y == -30.0, "Musou nao interrompe slam nem renova hang")
	victim.global_position = sphere.global_position + Vector3(2, -1, 0)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 3, 3)
	collider.shape = box
	wall.add_child(collider)
	game.add_child(wall)
	wall.global_position = sphere.global_position + Vector3(1, 0, 0)
	await frames(2)
	hp = victim.health.current_health
	sphere._pulse()
	check(victim.health.current_health == hp, "Parede bloqueia dano da esfera")
	wall.queue_free()
	await frames(2)
	victim.health.current_health = 1.0
	var kos := director.kos
	sphere._pulse()
	check(victim.is_dead() and director.kos == kos + 1, "Morte por musou conta um KO")
	sphere._pulse()
	check(director.kos == kos + 1, "Pulsos posteriores nao duplicam KO")
	sphere.age = sphere.duration - 0.01
	sphere.next_tick = sphere.duration
	sphere._physics_process(0.02)
	await frames(2)
	check(not is_instance_valid(sphere), "Campo se remove no fim da duracao")
	outside.queue_free()
	musou.add_charge(100)
	check(musou.try_activate(), "Pode carregar e usar novamente apos termino")
	health.invincible = false
	health.take_damage(99999)
	await frames(2)
	check(not is_instance_valid(musou.field) and musou.charge == 0.0, "Morte do jogador remove campo e carga")
	check(not musou.try_activate(), "Morto nao pode ativar musou")
	var body := player.find_child("Mesh_0", true, false) as MeshInstance3D
	check(body.material_override is ShaderMaterial and body.material_overlay == null, "Toon substitui material sem overlay duplicado")
	var mat := body.material_override as ShaderMaterial
	check(mat.shader.resource_path.ends_with("nyakuza_toon.gdshader") and mat.next_pass != null, "Player usa toon com contorno")
	check(mat.get_shader_parameter("albedo_texture") != null, "Toon preserva textura do player")
	game.queue_free()
	await frames(3)
	check(get_nodes_in_group("musou_fields").is_empty(), "Encerrar cena limpa campos")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
