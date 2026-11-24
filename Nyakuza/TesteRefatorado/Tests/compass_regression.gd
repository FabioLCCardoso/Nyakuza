extends SceneTree
var checks:=0
var failures:=0
func _initialize():run.call_deferred()
func check(ok: bool, message: String):
	checks+=1
	if ok:print("PASS: "+message)
	else:
		failures+=1;push_error("FAIL: "+message)
func frames(n: int):
	for i in n:await physics_frame
	await process_frame
func run():
	var game:=load("res://TesteRefatorado/Campaign/Campaign.tscn").instantiate() as CityCampaign
	root.add_child(game);current_scene=game
	game.director.set_physics_process(false)
	game.player.get_node("HealthComponent").invincible=true
	await frames(5)
	check(game.objective_panel.size.x<=360.1,"Largura compacta")
	check(game.objective_panel.size.y<75,"Altura compacta")
	check(not game.compass.has_destination,"Sem destino bloqueado durante waves")
	game.director.phase = WaveDirector.Phase.WAITING
	game._refresh_objective()
	check(game.objective.text == "PRÓXIMA ONDA · %ds" % ceili(game.director.countdown), "HUD mostra apenas a contagem")
	for sector in game.route.districts:
		check(sector.find_children("*", "Label3D", false, false).is_empty(), "Sem título 3D na entrada")
	game.compass.heading=0
	check(is_zero_approx(game.compass.relative_bearing(Vector3.FORWARD)),"Norte centralizado")
	check(game.compass.relative_bearing(Vector3.RIGHT)>0,"Leste à direita")
	check(game.compass.relative_bearing(Vector3.LEFT)<0,"Oeste à esquerda")
	game.compass.heading=PI-.01
	check(absf(game.compass.relative_bearing(Vector3(.01,0,1)))<.03,"Transição em 180 graus")
	game._on_encounter_finished()
	check(game.stage==CityCampaign.Stage.TRAVEL and game.compass.has_destination,"Waves concluídas liberam marcador")
	check(is_equal_approx(game.compass.destination.z,-27),"Destino inicial no portão")
	game.player.position=Vector3(0,.5,-28);game._refresh_objective()
	check(is_equal_approx(game.compass.destination.z,-48),"Depois do portão aponta à entrada")
	check(game.compass.destination.z<game.player.position.z,"Não manda voltar ao portão")
	game._start_district(1)
	check(not game.compass.has_destination,"Próxima área remove marcador de viagem")
	game._on_encounter_finished()
	check(is_equal_approx(game.compass.destination.z,-95),"Segundo distrito tem destino correto")
	game._start_district(3)
	check(game.compass.has_destination and game.boss_bar.custom_minimum_size.x==0,"Boss tem marcador e barra compacta")
	await frames(2)
	check(game.objective_panel.size.x<=360.1,"Boss não alarga HUD")
	game.stage=CityCampaign.Stage.VICTORY;game._refresh_objective()
	check(not game.compass.has_destination,"Vitória remove destino")
	game.stage=CityCampaign.Stage.DEFEAT;game._refresh_objective()
	check(not game.compass.has_destination,"Derrota remove destino")
	game.queue_free();await frames(2)
	print("RESULT: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
