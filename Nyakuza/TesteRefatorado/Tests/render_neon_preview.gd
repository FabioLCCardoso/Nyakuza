extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var game := load("res://TesteRefatorado/Scene/NeonCombatScene.tscn").instantiate() as Node3D
 (game.get_node("WaveDirector") as WaveDirector).auto_start=false
 root.add_child(game);current_scene=game
 root.size=Vector2i(1280,720);root.msaa_3d=Viewport.MSAA_4X
 (game.get_node("CombatHUD") as CombatHUD).root.hide()
 var camera := Camera3D.new();game.add_child(camera)
 camera.global_position=Vector3(15,11,20);camera.look_at(Vector3(0,5,-9));camera.current=true
 for i in 25: await process_frame
 await RenderingServer.frame_post_draw
 var destination:=OS.get_environment("NYAKUZA_PREVIEW_DIR")
 if destination.is_empty():destination="user://"
 root.get_texture().get_image().save_png(destination.path_join("NeonCity_preview.png"))
 var player:=game.get_node("Player") as Player
 (player.get_node("HealthComponent") as HealthComponent).invincible=true
 for i in 60: await physics_frame
 var musou:=player.get_node("MusouController") as MusouController
 musou.add_charge(100);musou.duration=20;musou.damage_per_tick=1
 musou.try_activate()
 if is_instance_valid(musou.field):
  var center:=musou.field.global_position
  var director:=game.get_node("WaveDirector") as WaveDirector
  for i in 12:
   var enemy:=director.fox_scene.instantiate() as Enemy
   game.add_child(enemy)
   var a:=float(i)*TAU/12.0
   enemy.global_position=Vector3(center.x+sin(a)*2.6,.55,center.z+cos(a)*2.6)
  camera.global_position=Vector3(8,7,13);camera.look_at(Vector3(center.x,1.8,center.z))
  for i in 75:await physics_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(destination.path_join("Musou_vortex_preview.png"))
 game.queue_free()
 for i in 3:await process_frame
 quit()
