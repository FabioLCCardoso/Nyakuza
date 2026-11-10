extends SceneTree
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
	await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("NYAKUZA_PREVIEW_DIR").path_join(name + ".png"))
	print("PREVIEW: " + name)
func run() -> void:
	root.size = Vector2i(1280, 720)
	root.msaa_3d = Viewport.MSAA_2X
	var game := load("res://TesteRefatorado/Campaign/Campaign.tscn").instantiate() as CityCampaign
	root.add_child(game)
	current_scene = game
	game.director.set_physics_process(false)
	var player := game.player
	player.get_node("HealthComponent").invincible = true
	await frames(60)
	player.get_node("CamRoot").set_physics_process(false)
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.current = true
	camera.position = player.position + Vector3(4, 3, 6)
	camera.look_at(player.position + Vector3.UP)
	var crate := load("res://TesteRefatorado/Pickups/BreakableCrate.tscn").instantiate() as BreakableCrate
	game.add_child(crate)
	crate.position = Vector3(2, 0.5, 0)
	var pickup := load("res://TesteRefatorado/Pickups/HealingPickup.tscn").instantiate() as HealingPickup
	game.add_child(pickup)
	pickup.position = Vector3(-1.8, 0.5, 0)
	var mode := player.get_node("MusouController") as MusouController
	mode.add_charge(100)
	mode.try_activate()
	await frames(10)
	await shot("Nyakuza_Musou_Aura_Cura")
	mode.end_mode()
	await frames(2)
	player.movement_direction = Vector3.LEFT
	player.get_node("DashController").dash()
	await frames(8)
	await shot("Nyakuza_Dash_Trail")
	await frames(40)
	mode.add_charge(100)
	mode.try_activate()
	mode.try_explosion()
	await frames(6)
	await shot("Nyakuza_Explosao")
	game.menu.pause_game()
	game.menu.show_controls(game.menu.show_pause)
	await process_frame
	await shot("Nyakuza_Controles_Musou")
	paused = false
	game.free()
	await frames(10)
	quit()
