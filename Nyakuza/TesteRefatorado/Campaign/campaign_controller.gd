extends Node3D
class_name CityCampaign
signal district_started(index: int)
signal district_cleared(index: int)
signal campaign_finished
enum Stage { COMBAT, TRAVEL, BOSS, VICTORY, DEFEAT }
@export var area_1_waves: Array[WaveDefinition] = []
@export var area_2_waves: Array[WaveDefinition] = []
@export var area_3_waves: Array[WaveDefinition] = []
@export var boss_scene: PackedScene = preload("res://TesteRefatorado/Enemy/Boss/Oyabun.tscn")
@export var heal_between_areas: float = 30.0
var current_area: int = 0
var stage: Stage = Stage.COMBAT
var cleared: Array[bool] = [false, false, false, false]
var transition_pending: bool = false
var boss: OyabunBoss
var route: CityRoute
var director: WaveDirector
var player: Player
var menu: GameMenu
var objective: Label
var boss_label: Label
var boss_bar: ProgressBar
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
	_start_district(0)

func _build_objective() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 12
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_top = 16
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.01, 0.055, 0.87)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.border_width_bottom = 2
	style.border_color = GameMenu.CYAN
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	objective = Label.new()
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.add_theme_font_size_override("font_size", 17)
	box.add_child(objective)
	boss_label = Label.new()
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override("font_size", 18)
	boss_label.add_theme_color_override("font_color", GameMenu.PINK)
	box.add_child(boss_label)
	boss_label.hide()
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(500, 18)
	boss_bar.show_percentage = false
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(boss_bar)
	boss_bar.hide()

func _process(delta: float) -> void:
	objective_clock -= delta
	if objective_clock <= 0:
		objective_clock = 0.2
		_refresh_objective()

func _start_district(index: int) -> void:
	current_area = index
	route.activate_district(index)
	if index > 0: route.set_passage(index - 1, false)
	if index == 3:
		stage = Stage.BOSS
		boss = boss_scene.instantiate() as OyabunBoss
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
	route.set_passage(current_area, true)
	player.get_node("HealthComponent").heal(heal_between_areas)
	district_cleared.emit(current_area)
	_refresh_objective()

func _boss_health(current: float, maximum: float) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current
	boss_label.text = "OYABUN • GUARDIÃO DO ECLIPSE / FASE %d" % boss.boss_phase

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

func _refresh_objective() -> void:
	if objective == null: return
	var header := "%02d / 04 • %s" % [current_area + 1, CityRoute.TITLES[current_area]]
	var detail := ""
	match stage:
		Stage.COMBAT:
			if director.phase == WaveDirector.Phase.WAITING:
				detail = "Próxima onda em %ds" % ceili(director.countdown)
			else:
				detail = "ONDA %d/%d • Derrote todos os inimigos" % [director.wave_index + 1, director.waves.size()]
		Stage.TRAVEL:
			var distance := player.global_position.distance_to(route.center(current_area) + Vector3(0, 0.5, -27))
			detail = "CONCLUÍDA • Siga para o portão iluminado (%dm)" % roundi(distance)
		Stage.BOSS: detail = "Quebre a postura com ataques fortes."
		Stage.VICTORY: detail = "ROTA CONCLUÍDA • CIDADE LIBERADA"
		Stage.DEFEAT: detail = "SPIKE CAIU"
	objective.text = header + "\n" + detail
