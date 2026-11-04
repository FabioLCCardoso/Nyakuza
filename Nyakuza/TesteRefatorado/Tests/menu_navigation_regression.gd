extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
	else: print("PASS: " + message)
func frames(n: int) -> void:
	for i in n: await process_frame
func press(menu: GameMenu, text: String) -> void:
	for node in menu.content.get_children():
		if node is Button and node.text == text:
			node.pressed.emit()
			return
	check(false, "Botao nao encontrado: " + text)
func run() -> void:
	var menu := load("res://TesteRefatorado/UI/MainMenu.tscn").instantiate() as GameMenu
	root.add_child(menu)
	current_scene = menu
	await frames(3)
	check(not paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Menu inicial libera mouse")
	press(menu, "CONTROLES")
	await frames(2)
	check(menu.controls_visible, "Controles no menu inicial")
	press(menu, "← VOLTAR")
	await frames(2)
	check(not menu.controls_visible and menu.title.text == "NYAKUZA", "Voltar dos controles")
	press(menu, "INICIAR JOGO →")
	await frames(8)
	var game := current_scene as CityCampaign
	check(game != null and game.current_area == 0, "Iniciar abre campanha")
	check(get_nodes_in_group("wave_director").size() == 1, "Um diretor por partida")
	if DisplayServer.get_name() != "headless":
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Jogo captura mouse")
	game.menu.pause_game()
	press(game.menu, "CONTROLES")
	await frames(2)
	check(paused and game.menu.controls_visible, "Ajuda mantem pausa")
	press(game.menu, "← VOLTAR")
	await frames(2)
	check(paused and not game.menu.controls_visible, "Voltar da ajuda mantem pausa")
	press(game.menu, "CONTINUAR")
	await frames(2)
	check(not paused and not game.menu.screen.visible, "Continuar retoma partida")
	game.director.kos = 12
	game.menu.pause_game()
	Engine.time_scale = 0.25
	press(game.menu, "VOLTAR AO MENU PRINCIPAL")
	await frames(10)
	menu = current_scene as GameMenu
	check(menu != null and not paused and Engine.time_scale == 1, "Voltar ao menu restaura tempo")
	check(get_nodes_in_group("wave_director").is_empty() and get_nodes_in_group("enemies").is_empty(), "Cena anterior liberada")
	press(menu, "INICIAR JOGO →")
	await frames(8)
	game = current_scene as CityCampaign
	check(game.current_area == 0 and game.director.kos == 0, "Nova partida reseta area e KOs")
	check(get_nodes_in_group("game_menu").size() == 1, "Menu de pausa sem duplicatas")
	game.free()
	await frames(8)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
