extends SceneTree
var checks:int=0
var failures:int=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
 checks+=1
 if ok:print("PASS: "+message)
 else:failures+=1;push_error("FAIL: "+message)
func frames(n:int)->void:
 for i in n:await physics_frame
 await process_frame
func run()->void:
 var game:=load("res://TesteRefatorado/Scene/NeonCombatScene.tscn").instantiate() as Node3D
 (game.get_node("WaveDirector") as WaveDirector).auto_start=false
 root.add_child(game);current_scene=game
 var player:=game.get_node("Player") as Player
 var health:=player.get_node("HealthComponent") as HealthComponent
 var combat:=player.get_node("PlayerCombat") as PlayerCombat
 var guard:=player.get_node("GuardController") as GuardController
 health.invincible=true;await frames(70)
 player.movement_controller.set_physics_process(false);player.set_physics_process(false)
 var fx:=CombatVFX.get_manager(self)
 for kind in ["penguin","red_panda"]:
  var e:=load("res://TesteRefatorado/Enemy/"+kind+".tscn").instantiate() as Enemy
  game.add_child(e);e.global_position=player.global_position+Vector3(0,.6,-1.8 if kind=="penguin" else -1.25)
  e.rotation.y=0;e.target=player;e.attack_cd=100;await frames(20)
  check(e.weapon!=null and e.weapon.get_parent() is BoneAttachment3D,kind+" arma vinculada a mao")
  check(e.anim.has_animation("Knock_Down"),kind+" Knock Down existe")
  check(e.anim.get_animation("Walking").loop_mode==Animation.LOOP_LINEAR,kind+" locomocao em loop")
  check((e.model.find_child("Mesh_0",true,false) as MeshInstance3D).material_override==null,kind+" preserva texturas")
  var visual := e.model.find_child("Mesh_0",true,false) as MeshInstance3D
  var material := visual.get_active_material(0) as ShaderMaterial
  check(material != null and material.shader.resource_path.ends_with("nyakuza_toon.gdshader"),kind+" toon ativo apos ready")
  if material != null:
   var texture := material.get_shader_parameter("albedo_texture") as Texture2D
   var expected := "PenguinEnemy" if kind=="penguin" else "RedPandaEnemy"
   check(texture != null and expected in texture.resource_path,kind+" textura original vinculada")
   check(material.next_pass == null and float(material.get_shader_parameter("ink_strength")) > 0.0,kind+" borda interna sem casca expandida")
   check(visual.material_overlay == e.flash_mat,kind+" flash preservado")
  var before:=fx.blood_spawned;var hit:=HitData.new();hit.attacker=player;hit.damage=1;hit.direction=Vector3.BACK
  e.hurt_box.receive_hit(hit);check(fx.blood_spawned==before+1,"Sangue em dano confirmado")
  e.hurt_box.receive_hit(hit);check(fx.blood_spawned==before+1,"Multihit limita repeticao visual")
  e.health.invincible=true;await frames(10);e.hurt_box.receive_hit(hit)
  check(fx.blood_spawned==before+1,"Invulnerabilidade nao cria sangue")
  e.health.invincible=false;health.invincible=false;combat.invuln_left=0;guard.stop_guard()
  var hp:=health.current_health;var impacts:=fx.ground_spawned
  e._enter(Enemy.State.CHASE);e.attack_cooldown=100
  for attempt in 20:
   e._start_attack()
   if e.state==Enemy.State.ATTACK_WINDUP:break
   await frames(1)
  check(e.state==Enemy.State.ATTACK_WINDUP,kind+" inicia preparacao")
  await frames(5);check(health.current_health==hp,kind+" nao causa dano na preparacao")
  await frames(150)
  print("METRICS ",kind," damage=",hp-health.current_health," ground=",fx.ground_spawned-impacts)
  check(health.current_health<hp,kind+" golpe animado atinge hurtbox real")
  check(hp-health.current_health<=e.attack_damage,kind+" um dano por ataque")
  if kind=="penguin":check(fx.ground_spawned==impacts+1,"Dragon Slayer gera um impacto")
  health.invincible=true;e.corpse_time=.35;hit.damage=9999;e.hurt_box.receive_hit(hit)
  check(e.is_dead() and not e.hurt_box.can_receive_hits,"Morte desliga hurtbox")
  check(e.anim.current_animation=="Knock_Down","Morte toca Knock Down")
  await frames(30);check(is_instance_valid(e) and not e.corpse_started,"Corpo nao some durante animacao")
  await frames(135);check(is_instance_valid(e),"Corpo permanece apos cair")
  await frames(110);check(not is_instance_valid(e),"Corpo removido apos prazo e transicao")
 var cancelled:=load("res://TesteRefatorado/Enemy/penguin.tscn").instantiate() as Enemy
 game.add_child(cancelled);cancelled.global_position=player.global_position+Vector3(0,.5,-2);cancelled.target=player;cancelled.attack_cd=100
 await frames(10);cancelled._enter(Enemy.State.CHASE);cancelled._start_attack()
 var count_ground:=fx.ground_spawned;var interrupt:=HitData.new();interrupt.damage=1;interrupt.attacker=player;interrupt.stagger_duration=3
 cancelled.hurt_box.receive_hit(interrupt);await frames(130)
 check(fx.ground_spawned==count_ground,"Interromper ataque cancela impacto")
 cancelled.queue_free();await frames(2)
 var victim:=load("res://TesteRefatorado/Enemy/fox.tscn").instantiate() as Enemy
 game.add_child(victim);victim.global_position=player.global_position+Vector3(6,.5,0);victim.attack_cd=100;await frames(10)
 var launcher:=HitData.new();launcher.attacker=player;launcher.damage=1;launcher.knockup=9;victim.hurt_box.receive_hit(launcher);await frames(15)
 var slam:=HitData.new();slam.attacker=player;slam.damage=1;slam.slam=true;count_ground=fx.ground_spawned;victim.hurt_box.receive_hit(slam);await frames(70)
 check(fx.ground_spawned==count_ground+1,"Slam dispara efeito no contato com piso")
 victim.queue_free();await frames(2)
 health.invincible=false;combat.invuln_left=0;guard.start_guard()
 var hit:=HitData.new();hit.damage=4;hit.direction=-player.movement_controller.mesh_root.global_basis.z
 var attacker:=Node3D.new();game.add_child(attacker);attacker.global_position=player.global_position+player.movement_controller.mesh_root.global_basis.z*2;hit.attacker=attacker
 var count:=fx.blood_spawned;combat._on_hit_received(hit);check(fx.blood_spawned==count,"Guarda nao gera sangue")
 guard.stop_guard();health.invincible=true
 fx.settings=fx.settings.duplicate() as CombatVFXSettings;fx.settings.blood_enabled=false
 fx.blood_hit(player,player.global_position+Vector3.UP,Vector3.BACK);check(fx.blood_spawned==count,"Opcao desliga sangue")
 fx.settings.blood_enabled=true;fx.settings.blood_interval=0;fx.settings.max_bursts=3;fx.settings.max_marks=4
 for i in 12:fx.blood_hit(player,player.global_position+Vector3.UP,Vector3.BACK)
 await frames(2);check(fx.bursts.size()<=3 and fx.marks.size()<=4,"Orcamento limita VFX")
 count_ground=fx.ground_spawned;fx.ground_impact(Vector3(1000,20,1000));check(fx.ground_spawned==count_ground,"Sem piso nao cria rachadura")
 game.queue_free();await frames(65);check(not is_instance_valid(fx),"Fechar cena limpa efeitos")
 print("RESULT: ",checks," checks, ",failures," failures");quit(1 if failures else 0)
