extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(name: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("NYAKUZA_PREVIEW_DIR").path_join(name + ".png")
	root.get_texture().get_image().save_png(path)
	print("PREVIEW: " + name)
func run() -> void:
	root.size = Vector2i(1280, 720)
	root.msaa_3d = Viewport.MSAA_2X
	var menu := load("res://TesteRefatorado/UI/MainMenu.tscn").instantiate() as GameMenu
	root.add_child(menu)
	current_scene = menu
	await shot("Nyakuza_menu")
	menu.show_controls(menu.show_main)
	await shot("Nyakuza_controles")
	menu.free()
	await frames(3)
	var game := load("res://TesteRefatorado/Campaign/Campaign.tscn").instantiate() as CityCampaign
	root.add_child(game)
	current_scene = game
	game.director.set_physics_process(false)
	game.player.get_node("HealthComponent").invincible = true
	for i in 20: await physics_frame
	game.menu.pause_game()
	await shot("Nyakuza_pausa")
	game.menu.resume_game()
	for node in game.get_children():
		if node is CanvasLayer: node.hide()
	game.player.get_node("CamRoot").set_physics_process(false)
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.current = true
	camera.far = 600
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 220
	camera.position = Vector3(110, 170, 15)
	camera.look_at(Vector3(0, 0, -102))
	for geometry in game.route.find_children("*", "GeometryInstance3D", true, false):
		geometry.visibility_range_end = 0
	await shot("Nyakuza_cidade_quatro_areas")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 65
	for i in 4:
		game.route.activate_district(i)
		camera.position = game.route.center(i) + Vector3(17, 17, 24)
		camera.look_at(game.route.center(i) + Vector3(0, 2, 0))
		await shot("Nyakuza_area_%d" % (i + 1))
	game._start_district(3)
	game.player.position = game.route.center(3) + Vector3(0, 0.8, 0)
	camera.position = game.boss.position + Vector3(3.5, 2.8, 5.5)
	camera.look_at(game.boss.position + Vector3.UP * 1.5)
	for node in game.get_children():
		if node is CanvasLayer and node.layer == 12: node.show()
	await shot("Nyakuza_boss")
	game.free()
	await frames(70)
	quit()
