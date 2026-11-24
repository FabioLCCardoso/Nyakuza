extends SceneTree
func _initialize(): run.call_deferred()
func frames(n: int):
 for i in n: await physics_frame
 await process_frame
func shot(name: String):
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("NYAKUZA_PREVIEW_DIR").path_join(name+".png"))
func run():
 root.size=Vector2i(1280,720)
 var game:=load("res://TesteRefatorado/Campaign/Campaign.tscn").instantiate() as CityCampaign
 root.add_child(game);current_scene=game;game.director.set_physics_process(false)
 var player:=game.player
 player.get_node("HealthComponent").invincible=true
 await frames(60)
 player.get_node("CamRoot").set_physics_process(false)
 var camera:=Camera3D.new();game.add_child(camera);camera.current=true
 camera.position=player.position+Vector3(2.1,1.6,3.0);camera.look_at(player.position+Vector3.UP*1.1)
 var mode:=player.get_node("MusouController") as MusouController
 mode.add_charge(100);mode.try_activate()
 await frames(30);await shot("spike_skill01")
 await frames(50)
 var boss:=load("res://TesteRefatorado/Enemy/Boss/Cookie.tscn").instantiate() as CookieBoss
 game.add_child(boss);boss.position=player.position+Vector3(4,1,0)
 await frames(30)
 boss.health.take_damage(405)
 camera.position=boss.position+Vector3(2.1,1.6,3.0);camera.look_at(boss.position+Vector3.UP*1.1)
 await frames(30);await shot("cookie_skill01")
 game.queue_free();await frames(3);quit()
