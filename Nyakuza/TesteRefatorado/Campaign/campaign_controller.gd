extends Node3D
class_name CityCampaign
signal district_started(index: int)
signal district_cleared(index: int)
signal campaign_finished
enum Stage { COMBAT, TRAVEL, BOSS, VICTORY, DEFEAT }
@export var area_1_waves: Array[WaveDefinition] = []
@export var area_2_waves: Array[WaveDefinition] = []
@export var area_3_waves: Array[WaveDefinition] = []
@export var boss_practice := false
@export var boss_scene: PackedScene = preload("res://TesteRefatorado/Enemy/Boss/Cookie.tscn")
@export var heal_between_areas: float = 30.0
@export_range(240,600,10) var compass_width: float = 360.0
var current_area: int = 0
var stage: Stage = Stage.COMBAT
var cleared: Array[bool] = [false, false, false, false]
var transition_pending: bool = false
var boss: CookieBoss
var route: CityRoute
var director: WaveDirector
var player: Player
var menu: GameMenu
var compass: NavigationCompass
var objective_panel: PanelContainer
var objective: Label
var boss_label: Label
var boss_bar: ProgressBar
@export var completion_seconds := 15.0
var completion_label := Label.new()
var completion_left := 0.0
var objective_clock: float = 0.0

func _ready() -> void:
	add_to_group("city_campaign")
	route = $NeonCityArena
	director = $WaveDirector
	player = $Player
	menu = preload("res://TesteRefatorado/UI/PauseMenu.tscn").instantiate()
	add_child(menu)
	$CombatHUD.wave_label.hide()
	_build_objective()
	director.encounter_finished.connect(_on_encounter_finished)
	director.stats_changed.connect(_refresh_objective)
	player.get_node("HealthComponent").died.connect(_on_player_died)
	for i in route.entries.size():
		route.entries[i].body_entered.connect(_entered.bind(i + 1))
	if boss_practice:
		player.position = route.center(3) + Vector3(0, 0.6, 7)
		player.reset_physics_interpolation()
		menu.replay_scene = scene_file_path
		_start_district(3)
	else:
		_start_district(0)

func _build_objective() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 12
	add_child(canvas)
	canvas.add_child(completion_label)
	completion_label.text = "LEVEL COMPLETE"
	completion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	completion_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	completion_label.offset_top = 68
	completion_label.add_theme_font_size_override("font_size", 34)
	completion_label.add_theme_constant_override("outline_size", 6)
	completion_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	completion_label.hide()
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	objective_panel = panel
	panel.offset_left = -compass_width * .5
	panel.offset_right = compass_width * .5
	panel.offset_top = 10
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.01, 0.055, 0.48)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 5
	style.border_width_bottom = 1
	style.border_color = GameMenu.CYAN
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	box.add_theme_constant_override("separation",1)
	compass=preload("res://TesteRefatorado/UI/navigation_compass.gd").new()
	compass.player=player
	box.add_child(compass)
	objective = Label.new()
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.add_theme_font_size_override("font_size", 12)
	box.add_child(objective)
	boss_label = Label.new()
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override("font_size", 12)
	boss_label.add_theme_color_override("font_color", GameMenu.PINK)
	box.add_child(boss_label)
	boss_label.hide()
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(0, 8)
	var fill:=StyleBoxFlat.new()
	fill.bg_color=GameMenu.PINK
	boss_bar.add_theme_stylebox_override("fill",fill)
	var background:=StyleBoxFlat.new()
	background.bg_color=Color(.14,.08,.2,.8)
	boss_bar.add_theme_stylebox_override("background",background)
	boss_bar.show_percentage = false
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(boss_bar)
	boss_bar.hide()

func _process(delta: float) -> void:
	if completion_left > 0:
		completion_left = maxf(0, completion_left - delta)
		completion_label.visible = completion_left > 0
	objective_clock -= delta
	if objective_clock <= 0:
		objective_clock = 0.2
		_refresh_objective()
	var width:=minf(compass_width,maxf(160,get_viewport().get_visible_rect().size.x-32))
	objective_panel.offset_left=-width*.5
	objective_panel.offset_right=width*.5

func _start_district(index: int) -> void:
	current_area = index
	route.activate_district(index)
	if index > 0: route.set_passage(index - 1, false)
	if index == 3:
		stage = Stage.BOSS
		boss = boss_scene.instantiate() as CookieBoss
		boss.position = route.center(3) + Vector3(0, 0.6, -6)
		add_child(boss)
		director.register_enemy(boss)
		boss.died.connect(_boss_defeated)
		boss.health.health_changed.connect(_boss_health)
		boss.phase_changed.connect(func(_phase: int): _boss_health(boss.health.current_health, boss.health.max_health))
		boss_label.show()
		boss_bar.show()
		_boss_health(boss.health.current_health, boss.health.max_health)
	else:
		stage = Stage.COMBAT
		var waves: Array[WaveDefinition] = [area_1_waves, area_2_waves, area_3_waves][index]
		if not director.start_encounter(waves, route.spawn_sets[index]):
			push_error("Nao foi possivel iniciar as ondas do distrito.")
	_refresh_objective()
	district_started.emit(index)

func _entered(body: Node3D, index: int) -> void:
	if body != player or stage != Stage.TRAVEL or index != current_area + 1 or transition_pending: return
	transition_pending = true
	# Instanciar o chefe altera Areas: adiar ate terminar a consulta de fisica.
	_enter_deferred.call_deferred(index)

func _enter_deferred(index: int) -> void:
	if stage == Stage.TRAVEL and index == current_area + 1:
		_start_district(index)
	transition_pending = false

func _on_encounter_finished() -> void:
	if stage != Stage.COMBAT or current_area >= 3: return
	cleared[current_area] = true
	stage = Stage.TRAVEL
	completion_left = completion_seconds
	completion_label.visible = completion_left > 0
	route.set_passage(current_area, true)
	player.get_node("HealthComponent").heal(heal_between_areas)
	district_cleared.emit(current_area)
	_refresh_objective()

func _boss_health(current: float, maximum: float) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current
	boss_label.text = "COOKIE · FASE %d" % boss.boss_phase

func _boss_defeated(_enemy: Enemy) -> void:
	if stage != Stage.BOSS: return
	stage = Stage.VICTORY
	cleared[3] = true
	district_cleared.emit(3)
	campaign_finished.emit()
	_refresh_objective()
	await get_tree().create_timer(3.0, false).timeout
	if stage == Stage.VICTORY:
		menu.show_result(true, director.kos)

func _on_player_died() -> void:
	if stage == Stage.VICTORY: return
	stage = Stage.DEFEAT
	$CombatHUD.death_panel.hide()
	_refresh_objective()
	menu.show_result(false, director.kos)

func navigation_target() -> Vector3:
	# Depois da saída, orienta até o gatilho seguinte sem mandar voltar.
	var exit_point: Vector3=route.gates[current_area][0].global_position
	exit_point.y=player.global_position.y
	var entry_point:=route.entries[current_area].global_position
	entry_point.y=player.global_position.y
	var forward: Vector3=(entry_point-exit_point).normalized()
	if (player.global_position-exit_point).dot(forward)>=-2.0:return entry_point
	return exit_point

func _refresh_objective() -> void:
	if objective==null:return
	compass.clear_destination()
	match stage:
		Stage.COMBAT:
			if director.phase==WaveDirector.Phase.WAITING:
				objective.text="PRÓXIMA ONDA · %ds" % ceili(director.countdown)
			else:objective.text="ONDA %d/%d" % [director.wave_index+1,director.waves.size()]
		Stage.TRAVEL:
			var point:=navigation_target()
			compass.set_destination(point)
			var offset:=point-player.global_position;offset.y=0
			objective.text="PRÓXIMA ÁREA · %d m" % roundi(offset.length())
		Stage.BOSS:
			objective.text="QUEBRE A POSTURA"
			if is_instance_valid(boss) and not boss.is_dead():compass.set_destination(boss.global_position,GameMenu.PINK)
		Stage.VICTORY:objective.text="CONCLUÍDO"
		Stage.DEFEAT:objective.text="DERROTA"
