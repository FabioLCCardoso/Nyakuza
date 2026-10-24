extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
 checks += 1
 if ok: print("PASS: " + message)
 else:
  failures += 1
  push_error("FAIL: " + message)
func frames(count: int) -> void:
 for i in count: await physics_frame
 await process_frame
func run() -> void:
 var game := load("res://TesteRefatorado/Scene/NeonCombatScene.tscn").instantiate() as Node3D
 var director := game.get_node("WaveDirector") as WaveDirector
 director.auto_start = false
 root.add_child(game)
 current_scene = game
 var player := game.get_node("Player") as Player
 (player.get_node("HealthComponent") as HealthComponent).invincible = true
 await frames(90)
 check(player.is_on_floor(), "Jogador parado cai e encontra o piso")
 check(game.has_node("NeonCityArena") and not game.has_node("Floor"), "Nova arena sem piso antigo duplicado")
 var space := game.get_world_3d().direct_space_state
 for marker in game.get_node("SpawnPoints").get_children():
  var ray := PhysicsRayQueryParameters3D.create(marker.global_position + Vector3.UP * 2, marker.global_position - Vector3.UP * 2, 1)
  check(not space.intersect_ray(ray).is_empty(), "Spawn com piso: " + marker.name)
  ray = PhysicsRayQueryParameters3D.create(marker.global_position + Vector3.UP, Vector3(0,1.6,0),1)
  check(space.intersect_ray(ray).is_empty(), "Spawn com caminho central: " + marker.name)
 check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,2,0),Vector3(30,2,0),1)).is_empty(), "Perimetro tem colisao")
 var enemies: Array[Enemy] = []
 var center := Vector3(0,1.6,3)
 for i in 16:
  var packed: PackedScene = director.red_panda_scene if i == 0 else director.fox_scene
  var e := packed.instantiate() as Enemy
  game.add_child(e)
  var a := float(i)*TAU/16.0
  e.global_position = Vector3(sin(a)*2.65,0.55,3+cos(a)*2.65)
  enemies.append(e)
 var sphere := MusouSphere.new()
 sphere.caster = player
 sphere.duration = 12
 sphere.damage_per_tick = 0
 game.add_child(sphere)
 sphere.global_position = center
 await frames(180)
 check(sphere.slots.size() == 19, "19 posicoes reservaveis")
 check(sphere.captured.size() == 16, "16 inimigos capturados")
 var min_distance: float = INF
 var mean_radius: float = 0.0
 var all_stunned: bool = true
 for e in enemies:
  all_stunned = all_stunned and e.is_musou_captured() and e.state == Enemy.State.STAGGER and e.collision_mask == 5
  mean_radius += Vector2(e.global_position.x,e.global_position.z-3).length()/16.0
  for other in enemies:
   if e != other: min_distance = minf(min_distance, e.global_position.distance_to(other.global_position))
 check(all_stunned, "Stunlock continuo e colisao entre corpos")
 check(min_distance >= 0.79, "Capsulas nao se sobrepoem")
 check(mean_radius < 2.2, "Atracao aproxima horda do centro")
 print("METRICS: min_distance=",min_distance," mean_radius=",mean_radius)
 check(enemies[0].posture == 60.0, "Captura nao consome postura do elite")
 enemies[0]._start_attack()
 check(enemies[0].state == Enemy.State.STAGGER, "Inimigo capturado nao inicia ataque")
 sphere.queue_free()
 await frames(2)
 var released: bool = true
 for e in enemies: released = released and not e.is_musou_captured() and e.collision_mask == 1
 check(released, "Remocao do campo restaura todas as mascaras")
 for e in enemies: e.queue_free()
 await frames(2)
 var e := director.fox_scene.instantiate() as Enemy
 game.add_child(e); e.global_position=Vector3(0,.55,3)
 sphere = MusouSphere.new(); sphere.caster=player; sphere.duration=1; sphere.damage_per_tick=0
 game.add_child(sphere); sphere.global_position=center
 await frames(5)
 check(e.is_musou_captured(), "Captura inicial")
 e.global_position.x=10
 await frames(10)
 check(not e.is_musou_captured() and sphere.captured.is_empty(), "Saida do alcance libera reserva")
 e.global_position.x=0
 await frames(10)
 check(e.is_musou_captured(), "Alvo pode ser recapturado")
 await frames(60)
 check(not is_instance_valid(sphere) and not e.is_musou_captured() and e.collision_mask==1, "Expiracao natural libera corpos")
 game.queue_free()
 await frames(3)
 print("RESULT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
