extends SceneTree
var checks := 0
var failures := 0
func _initialize(): run.call_deferred()
func check(ok: bool, message: String):
	checks += 1
	if ok: print("PASS: "+message)
	else:
		failures += 1; push_error("FAIL: "+message)
func frames(n: int):
	for i in n: await physics_frame
	await process_frame
func hit(enemy: Enemy, damage: float, posture_damage: float = 0):
	var data := HitData.new(); data.damage=damage; data.posture_damage=posture_damage; data.is_heavy=posture_damage>0
	enemy.hurt_box.receive_hit(data)
func run():
	var game := load("res://TesteRefatorado/Campaign/Campaign.tscn").instantiate() as CityCampaign
	root.add_child(game); current_scene=game; game.director.set_physics_process(false)
	var player := game.player
	var health := player.get_node("HealthComponent") as HealthComponent
	health.invincible=true; player.global_position=Vector3(0,.55,0)
	await frames(60)
	var foxes: Array[FoxRanged]=[]
	for i in 3:
		var fox := load("res://TesteRefatorado/Enemy/fox.tscn").instantiate() as FoxRanged
		game.add_child(fox); fox.position=Vector3(i*2-2,.1,7); fox.set_physics_process(false); fox._enter(Enemy.State.CHASE)
		foxes.append(fox)
	var coordinator := foxes[0].attack_coordinator
	coordinator.shot_spacing_left=0;foxes[0]._start_attack()
	coordinator.shot_spacing_left=0;foxes[1]._start_attack()
	coordinator.shot_spacing_left=0;foxes[2]._start_attack()
	check(coordinator.shooters.size()==2 and foxes[2].state==Enemy.State.CHASE,"Limite compartilhado de dois atiradores")
	check(foxes[0].anim.current_animation=="Aim_Hold", "Mira antes do tiro")
	check(foxes[0].weapon.get_parent() is BoneAttachment3D and foxes[0].weapon.has_node("Muzzle"),"Glock acompanha mão com muzzle")
	var before:=health.current_health
	foxes[0]._enter(Enemy.State.ATTACK_ACTIVE,.18);foxes[0]._process_attack_active()
	check(get_nodes_in_group("enemy_projectiles").size()==1 and health.current_health==before,"Disparo cria projétil sem dano instantâneo")
	foxes[0]._process_attack_active()
	check(get_nodes_in_group("enemy_projectiles").size()==1,"Uma bala por janela ativa")
	hit(foxes[1],1)
	check(foxes[1].state==Enemy.State.STAGGER and not coordinator.shooters.has(foxes[1].get_instance_id()),"Stagger interrompe mira e libera vaga")
	coordinator.shot_spacing_left=0;foxes[2]._start_attack()
	check(foxes[2].state==Enemy.State.ATTACK_WINDUP,"Outra raposa ocupa vaga liberada")
	var capture:=Node3D.new();game.add_child(capture)
	foxes[2].set_musou_capture(capture,foxes[2].position,7)
	check(not coordinator.shooters.has(foxes[2].get_instance_id()),"Captura libera vaga")
	foxes[2].end_musou_capture(capture)
	hit(foxes[0],9999)
	check(foxes[0].state==Enemy.State.DEAD and foxes[0].anim.current_animation=="Knock_Down","Morte usa Knock_Down")
	check(not coordinator.shooters.has(foxes[0].get_instance_id()),"Morte libera vaga")
	# Bala física: colisão real com hurtbox e bloqueio por parede.
	for projectile in get_nodes_in_group("enemy_projectiles"): projectile.queue_free()
	await frames(2)
	health.invincible=false
	player.get_node("PlayerCombat").invuln_left=0
	before=health.current_health
	var projectile:=load("res://TesteRefatorado/Enemy/ranged_bullet.gd").new() as Node3D
	projectile.shooter=foxes[1];projectile.damage=9;projectile.speed=40
	game.add_child(projectile)
	projectile.global_position=player.global_position+Vector3(0,1,-1)
	projectile.direction=Vector3.BACK
	await frames(4)
	check(is_equal_approx(before-health.current_health,9),"Projétil atinge hurtbox real do player uma vez")
	health.invincible=true
	var wall:=StaticBody3D.new();game.add_child(wall);wall.position=Vector3(0,1,-2)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(3,3,.2);shape.shape=box;wall.add_child(shape)
	await frames(2)
	projectile=load("res://TesteRefatorado/Enemy/ranged_bullet.gd").new()
	projectile.shooter=foxes[1];projectile.speed=40;game.add_child(projectile)
	projectile.global_position=Vector3(0,1,-3);projectile.direction=Vector3.BACK
	await frames(4)
	check(not is_instance_valid(projectile),"Parede bloqueia e remove projétil")
	wall.queue_free()
	for fox in foxes:fox.queue_free()
	capture.queue_free();await frames(2)
	var boss:=load("res://TesteRefatorado/Enemy/Boss/Cookie.tscn").instantiate() as CookieBoss
	game.add_child(boss);boss.position=Vector3(0,.05,5)
	await frames(12);boss.set_physics_process(false)
	hit(boss,404)
	check(boss.boss_phase==1 and boss.health.current_health==496,"Acima de 55% mantém fase 1")
	hit(boss,1)
	check(boss.boss_phase==2 and boss.phase_pending,"55% agenda transformação uma vez")
	boss._physics_process(1.0/60)
	check(boss.transforming and boss.anim.current_animation=="Skill_01","Cookie executa Skill_01")
	check(is_instance_valid(boss.aura) and boss.aura.aura_color.r==1,"Aura vermelha na fase 2")
	before=boss.health.current_health;hit(boss,100)
	check(is_equal_approx(before-boss.health.current_health,65),"Segunda fase reduz dano em 35%")
	check(not boss.phase_pending,"Golpes seguintes não repetem transformação")
	boss._enter(Enemy.State.CHASE);boss.attack_index=3;boss._start_attack()
	check(boss.attack_animation==&"Skill_03" and boss.radial_skill,"Fase 2 desbloqueia ataque em área")
	hit(boss,1,999)
	check(not boss.has_posture_armor(),"Ataque forte quebra postura do Cookie")
	check(boss.weapon.get_parent() is BoneAttachment3D,"Katana ligada ao osso da mão")
	var mesh:=boss.model.find_child("Mesh_0",true,false) as MeshInstance3D
	check(mesh.get_surface_override_material(0) is ShaderMaterial,"Cookie usa toon texturizado")
	boss.queue_free();await frames(2)
	var mode:=player.get_node("MusouController") as MusouController
	mode.add_charge(100)
	check(mode.try_activate(),"Musou ativa no chão")
	check(mode.activation_left>0 and mode.activation_player.current_animation=="Spike/Skill_01","Spike usa Skill_01 na ativação")
	check(not mode.try_sphere(),"Especial aguarda animação de ativação")
	var dash:=player.get_node("DashController") as DashController
	dash.dash();check(not player.movement_controller.is_dashing(),"Dash não corta Skill_01")
	paused=true;var remaining:=mode.activation_left;await frames(5)
	check(mode.activation_left==remaining,"Pausa congela ativação")
	paused=false;await frames(75)
	check(mode.activation_left==0 and mode.skills.anim_tree.active and not player.is_attacking,"Fim da ativação devolve controle")
	check(mode.try_sphere(),"Especial disponível depois de Skill_01")
	mode.end_mode();game.queue_free();await frames(3)
	print("FOX_COOKIE: %d checks / %d failures" % [checks,failures]);quit(1 if failures else 0)
