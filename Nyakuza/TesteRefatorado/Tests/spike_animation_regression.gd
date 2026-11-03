extends SceneTree
var checks:int=0
var failures:int=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if ok:print("PASS: "+label)
 else:failures+=1;push_error("FAIL: "+label)
func frames(n:int)->void:
 for i in n:await physics_frame
 await process_frame
func run()->void:
 var game:=load("res://TesteRefatorado/Scene/NeonCombatScene.tscn").instantiate() as Node3D
 game.get_node("WaveDirector").auto_start=false
 root.add_child(game);current_scene=game
 var player:=game.get_node("Player") as Player
 var controller:=player.get_node("ActiveSkillController") as ActiveSkillController
 var skills:=controller.skills_container
 var ac:=player.get_node("AnimationController")
 var tree:=player.get_node("MeshRoot/AnimationTree") as AnimationTree
 var skeleton:=player.find_child("Skeleton3D",true,false) as Skeleton3D
 var weapon:=player.find_child("antique_katana_01",true,false) as MeshInstance3D
 var socket:=weapon.get_parent() as BoneAttachment3D
 player.get_node("PlayerCombat").god_mode=true
 await frames(10)
 player.movement_controller.set_physics_process(false)
 check(socket.bone_name=="mixamorig_RightHand","Espada vinculada à mão")
 check(tree.callback_mode_process==AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS,"Animação acompanha relógio da física")
 for mode in [false,true]:
  skills.set_air_mode(mode)
  for index in range(skills.skills().size()+1):
   var heavy:=index==skills.skills().size()
   controller.cancel_attack();skills.set_air_mode(mode);skills.current_attack_id=mini(index,skills.skills().size()-1)
   controller.heavy_left=0;controller.start_attack(heavy)
   var skill:=skills.current_active_skill
   var label:=str(skill.name)
   var wind:Array[Vector3]=[];var swing:Array[Vector3]=[];var recover:Array[Vector3]=[]
   for i in 90:
    await frames(1)
    var tip:=weapon.to_global(Vector3(0,0,1))
    match skills.attack_state:
     ActiveSkill.State.WINDING_UP:wind.append(tip)
     ActiveSkill.State.DELIVERING:swing.append(tip)
     ActiveSkill.State.RECOVERING:recover.append(tip)
     ActiveSkill.State.READY:break
   check(path_length(wind)>.005,label+" preparação animada")
   check(path_length(swing)>.25,label+" espada percorre arco durante corte")
   check(path_length(recover)>.02,label+" follow-through animado")
   check(skills.attack_state==ActiveSkill.State.READY,label+" conclui e devolve controle")
   print("MOTION ",label," ",path_length(wind)," / ",path_length(swing)," / ",path_length(recover))
   await frames(10)
 # Buffer só substitui o golpe depois do corte e follow-through mínimo.
 skills.set_air_mode(false);controller.cancel_attack();controller.start_attack()
 for i in 60:
  await frames(1)
  if skills.attack_state==ActiveSkill.State.RECOVERING:break
 var first:=skills.current_active_skill
 controller._queue_attack(false)
 await frames(1)
 check(skills.current_active_skill==first,"Buffer não corta início do follow-through")
 await frames(12)
 check(skills.current_active_skill!=first,"Buffer encadeia próximo ataque")
 controller.cancel_attack();await frames(3)
 check(not player.is_attacking and skills.attack_state==ActiveSkill.State.READY,"Cancelamento continua imediato")
 # Salto real: física mantém altura; pose não acrescenta root motion.
 player.movement_controller.set_physics_process(true)
 await frames(90)
 player.pressed_jump.emit(player.jump_states["ground_jump"])
 await frames(8)
 var y_before:=player.global_position.y
 player.pressed_jump.emit(player.jump_states["air_jump"])
 await frames(5)
 check(player.global_position.y>y_before,"Double jump mantém impulso físico")
 check(bool(tree.get("parameters/air_jump/active")),"Double jump toca seu clip")
 check(not bool(tree.get("parameters/ground_jump/active")),"Double jump cancela clip do primeiro salto")
 var hip:=skeleton.get_bone_pose_position(0)
 await frames(8)
 check(skeleton.get_bone_pose_position(0).distance_to(hip)<.03,"Pose aérea não duplica deslocamento do corpo")
 await frames(150)
 check(player.is_on_floor(),"Retorna ao piso após double jump")
 check(not bool(tree.get("parameters/air_jump/active")),"Pouso encerra a pose de double jump")
 game.queue_free();await frames(2)
 print("RESULT: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func path_length(points:Array[Vector3])->float:
 var total:=0.0
 for i in range(1,points.size()):total+=points[i].distance_to(points[i-1])
 return total
