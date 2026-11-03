extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 var game:=load("res://TesteRefatorado/Scene/CombatScene.tscn").instantiate() as Node3D
 game.get_node("WaveDirector").auto_start=false
 root.add_child(game);current_scene=game
 root.size=Vector2i(640,480);root.msaa_3d=Viewport.MSAA_4X
 var player:=game.get_node("Player") as Player
 var skills:SkillsContainer=player.get_node("ActiveSkillController").skills_container
 var controller:=player.get_node("ActiveSkillController") as ActiveSkillController
 player.get_node("PlayerCombat").god_mode=true
 for i in 20:await physics_frame
 player.movement_controller.set_physics_process(false)
 player.get_node("CamRoot").set_process(false);player.get_node("CamRoot").set_physics_process(false)
 var env:=game.find_child("WorldEnvironment",true,false) as WorldEnvironment
 if env!=null:
  env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.055,.04,.075)
  env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.8,.8,1);env.environment.ambient_light_energy=.7
 for layer in game.find_children("*","CanvasLayer",true,false):layer.hide()
 for old in game.find_children("*","DirectionalLight3D",true,false):old.hide()
 var key:=DirectionalLight3D.new();game.add_child(key);key.rotation_degrees=Vector3(-40,-30,0);key.light_energy=1.8;key.shadow_enabled=true
 var camera:=Camera3D.new();game.add_child(camera);camera.position=player.position+Vector3(2.3,2.0,3.5);camera.look_at(player.position+Vector3.UP*1.35);camera.current=true
 var dest:=OS.get_environment("NYAKUZA_PREVIEW_DIR");DirAccess.make_dir_recursive_absolute(dest+"/spike_frames")
 var shot:=0
 for move in ["light_1","light_2","light_3","heavy","double_jump"]:
  if move=="double_jump":
   controller.cancel_attack()
   player.movement_controller.set_physics_process(true)
   camera.position=player.position+Vector3(5,4.0,7.5)
   camera.look_at(player.position+Vector3.UP*2.7)
   player.pressed_jump.emit(player.jump_states["ground_jump"])
   for j in 10:await physics_frame
   player.pressed_jump.emit(player.jump_states["air_jump"])
  else:
   controller.heavy_left=0;controller.start_attack(move=="heavy")
  for i in (100 if move=="double_jump" else 42):
   await physics_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(dest+"/spike_frames/%04d.png"%shot);shot+=1
   if i in [3,12,22,32]:root.get_texture().get_image().save_png(dest+"/spike_"+move+"_"+str(i)+".png")
 game.queue_free()
 for i in 70:await process_frame
 quit()
