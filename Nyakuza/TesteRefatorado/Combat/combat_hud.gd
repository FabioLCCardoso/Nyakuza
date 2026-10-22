extends CanvasLayer
class_name CombatHUD
## HUD feita toda em codigo (sem cena de UI): barra de vida, contador de inimigos, flash de dano e tela de morte.
## Teclas para gravar o teaser:  F1 = god mode   F2 = esconde/mostra HUD   F5 = reinicia a cena

@export var player_health : HealthComponent
@export var player_combat : PlayerCombat
## Hitbox da katana: usada para contar os acertos do combo.
@export var hit_box : CombatHitBox
## Opcional: mostra o indicador "COMBO AEREO".
@export var air_combo : AirComboController

var musou: MusouController
var musou_bar: ProgressBar
var musou_label: Label
var musou_message_left: float = 0.0
var root : Control
var hp_trail : ColorRect
var hp_fill : ColorRect
var hp_text : Label
var enemies_label : Label
var vignette : TextureRect
var death_panel : Control
var god_label : Label
var vignette_tween : Tween
var enemy_timer : float = 0.0
var combo_label : Label
var combo_count : int = 0
var combo_left : float = 0.0
var director: WaveDirector
var ko_label: Label
var wave_label: Label
var health_tween: Tween
var combo_tween : Tween

func _ready():
	layer = 10
	_build_ui()
	if player_health != null:
		player_health.health_changed.connect(_on_health_changed)
		player_health.died.connect(_on_player_died)
		_on_health_changed(player_health.current_health, player_health.max_health)
	if player_combat != null:
		player_combat.player_hit.connect(_on_player_hit)
	if hit_box != null:
		hit_box.hit_landed.connect(_on_hit_landed)
	_update_god_label()
	_bind_director.call_deferred()
	_bind_musou.call_deferred()

func _process(delta):
	musou_message_left = maxf(0.0, musou_message_left - delta)
	if is_instance_valid(musou) and musou_message_left <= 0.0:
		_update_musou(musou.charge, musou.max_charge)
	if combo_left > 0.0:
		combo_left -= delta
		if combo_left <= 0.0:
			combo_count = 0
			combo_label.text = ""
	enemy_timer -= delta
	if enemy_timer <= 0.0:
		enemy_timer = 0.2
		if is_instance_valid(director):
			_update_wave_labels()
		else:
			enemies_label.text = "INIMIGOS  %d " % get_tree().get_node_count_in_group("enemies")

func _unhandled_key_input(event):
	var e := event as InputEventKey
	if e == null or not e.pressed or e.echo:
		return
	match e.keycode:
		KEY_F1:
			if player_health != null:
				player_health.invincible = not player_health.invincible
				_update_god_label()
		KEY_F2:
			root.visible = not root.visible
		KEY_F5:
			Engine.time_scale = 1.0
			get_tree().reload_current_scene()

# ------------------------------------------------------------------ UI
func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Vinheta vermelha quando apanha
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.45, 1.0])
	grad.colors = PackedColorArray([Color(0.8, 0.0, 0.0, 0.0), Color(0.8, 0.0, 0.0, 0.85)])
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	gtex.width = 256
	gtex.height = 256
	vignette = TextureRect.new()
	vignette.texture = gtex
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.modulate.a = 0.0
	root.add_child(vignette)

	# Barra de vida (canto inferior esquerdo)
	var bar := Control.new()
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 48
	bar.offset_right = 448
	bar.offset_top = -86
	bar.offset_bottom = -52
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bar)

	var frame := ColorRect.new()
	frame.color = Color(0, 0, 0, 0.75)
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = -4
	frame.offset_top = -4
	frame.offset_right = 4
	frame.offset_bottom = 4
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(frame)

	hp_trail = ColorRect.new()
	hp_trail.color = Color(1.0, 0.95, 0.85, 0.9)
	hp_trail.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(hp_trail)

	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.86, 0.12, 0.16)
	hp_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(hp_fill)

	hp_text = Label.new()
	hp_text.add_theme_font_size_override("font_size", 20)
	hp_text.add_theme_color_override("font_outline_color", Color.BLACK)
	hp_text.add_theme_constant_override("outline_size", 6)
	hp_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(hp_text)

	# Contador de inimigos (topo direito)
	enemies_label = Label.new()
	enemies_label.add_theme_font_size_override("font_size", 26)
	enemies_label.add_theme_color_override("font_outline_color", Color.BLACK)
	enemies_label.add_theme_constant_override("outline_size", 8)
	enemies_label.anchor_left = 1.0
	enemies_label.anchor_right = 1.0
	enemies_label.offset_left = -300
	enemies_label.offset_right = -40
	enemies_label.offset_top = 30
	enemies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemies_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(enemies_label)
	ko_label = Label.new()
	ko_label.add_theme_font_size_override("font_size", 38)
	ko_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	ko_label.add_theme_color_override("font_outline_color", Color.BLACK)
	ko_label.add_theme_constant_override("outline_size", 8)
	ko_label.anchor_left = 1.0
	ko_label.anchor_right = 1.0
	ko_label.offset_left = -350
	ko_label.offset_right = -40
	ko_label.offset_top = 68
	ko_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ko_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ko_label.text = "0 KOs"
	root.add_child(ko_label)
	wave_label = Label.new()
	wave_label.add_theme_font_size_override("font_size", 22)
	wave_label.add_theme_color_override("font_outline_color", Color.BLACK)
	wave_label.add_theme_constant_override("outline_size", 6)
	wave_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wave_label.offset_left = -290
	wave_label.offset_right = 290
	wave_label.offset_top = 28
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wave_label)

	# Contador de combo (lado direito)
	combo_label = Label.new()
	combo_label.add_theme_font_size_override("font_size", 54)
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	combo_label.add_theme_color_override("font_outline_color", Color.BLACK)
	combo_label.add_theme_constant_override("outline_size", 12)
	combo_label.anchor_left = 1.0
	combo_label.anchor_right = 1.0
	combo_label.anchor_top = 0.35
	combo_label.offset_left = -420
	combo_label.offset_right = -60
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.pivot_offset = Vector2(360, 30)
	combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(combo_label)

	# Indicador de god mode
	god_label = Label.new()
	god_label.add_theme_font_size_override("font_size", 18)
	god_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	god_label.add_theme_color_override("font_outline_color", Color.BLACK)
	god_label.add_theme_constant_override("outline_size", 5)
	god_label.offset_left = 48
	god_label.offset_top = 30
	god_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(god_label)

	# Dicas de teclas (discretas)
	var hint := Label.new()
	hint.text = "LMB Leve | RMB Pesado (lanca / slam) | F Guarda | Q Dash | R Musou\nWASD Mover | Espaco Pular | F5 Reiniciar | Esc Cursor"
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(1, 1, 1, 0.45)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -610
	hint.offset_right = -24
	hint.offset_top = -54
	hint.offset_bottom = -16
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	# Tela de morte
	death_panel = ColorRect.new()
	(death_panel as ColorRect).color = Color(0, 0, 0, 0.6)
	death_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_panel.visible = false
	root.add_child(death_panel)
	var big := Label.new()
	big.text = "VOCÊ MORREU"
	big.add_theme_font_size_override("font_size", 72)
	big.add_theme_color_override("font_color", Color(0.9, 0.1, 0.12))
	big.add_theme_color_override("font_outline_color", Color.BLACK)
	big.add_theme_constant_override("outline_size", 14)
	big.set_anchors_preset(Control.PRESET_FULL_RECT)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_panel.add_child(big)
	var small := Label.new()
	small.text = "Pressione F5 para reiniciar"
	small.add_theme_font_size_override("font_size", 24)
	small.set_anchors_preset(Control.PRESET_FULL_RECT)
	small.offset_top = 90
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	small.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_panel.add_child(small)

func _on_health_changed(current : float, maximum : float) -> void:
	var ratio := current / maximum if maximum > 0.0 else 0.0
	hp_text.text = "%d / %d" % [ceili(current), int(maximum)]
	hp_fill.anchor_right = ratio
	# "rastro" claro que demora para alcancar a barra (mostra quanto foi perdido)
	if health_tween != null:
		health_tween.kill()
	health_tween = create_tween()
	health_tween.tween_interval(0.35)
	health_tween.tween_property(hp_trail, "anchor_right", ratio, 0.4)

func _on_player_hit(_hit : HitData) -> void:
	if vignette_tween != null:
		vignette_tween.kill()
	vignette.modulate.a = 1.0
	vignette_tween = create_tween()
	vignette_tween.tween_property(vignette, "modulate:a", 0.0, 0.5)

func _on_player_died() -> void:
	death_panel.visible = true

func _update_god_label() -> void:
	god_label.text = "GOD MODE" if (player_health != null and player_health.invincible) else ""

func _on_hit_landed(_hit : HitData, _hurt : CombatHurtBox) -> void:
	combo_count += 1
	combo_left = 2.0
	var in_air := air_combo != null and air_combo.is_active()
	combo_label.text = "%s%d HIT%s" % ["AR  " if in_air else "", combo_count, "S" if combo_count > 1 else ""]
	combo_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0) if in_air else Color(1.0, 0.85, 0.25))
	if combo_tween != null:
		combo_tween.kill()
	combo_label.scale = Vector2(1.35, 1.35)
	combo_tween = create_tween()
	combo_tween.tween_property(combo_label, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _bind_director() -> void:
	director = get_tree().get_first_node_in_group("wave_director") as WaveDirector
	if director != null:
		director.stats_changed.connect(_update_wave_labels)
		_update_wave_labels()

func _update_wave_labels() -> void:
	ko_label.text = "%d KOs" % director.kos
	enemies_label.text = "VIVOS %d  |  A CHEGAR %d" % [director.alive.size(), director.pending.size()]
	match director.phase:
		WaveDirector.Phase.WAITING:
			wave_label.text = "ONDA %d / %d EM %d" % [director.wave_index + 2, director.waves.size(), ceili(director.countdown)]
		WaveDirector.Phase.SPAWNING, WaveDirector.Phase.FIGHTING:
			wave_label.text = "ONDA %d / %d — %s" % [director.wave_index + 1, director.waves.size(), director.waves[director.wave_index].title]
			if not director.status_message.is_empty():
				wave_label.text += "\n" + director.status_message
		WaveDirector.Phase.COMPLETE:
			wave_label.text = "VITORIA! TODAS AS ONDAS CONCLUIDAS\nF5 para jogar novamente"
		WaveDirector.Phase.DEFEAT:
			wave_label.text = "ONDAS INTERROMPIDAS"
		WaveDirector.Phase.ERROR:
			wave_label.text = "ERRO DE CONFIGURACAO\n" + director.status_message

func _bind_musou() -> void:
	if player_combat == null:
		return
	musou = player_combat.player.get_node_or_null("MusouController") as MusouController
	if musou == null:
		return
	musou_bar = ProgressBar.new()
	musou_bar.position = Vector2(48, 66)
	musou_bar.size = Vector2(280, 16)
	musou_bar.show_percentage = false
	musou_bar.modulate = Color(0.4, 0.8, 1.0)
	musou_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(musou_bar)
	musou_label = Label.new()
	musou_label.position = Vector2(48, 84)
	musou_label.add_theme_font_size_override("font_size", 17)
	musou_label.add_theme_constant_override("outline_size", 5)
	musou_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(musou_label)
	musou.charge_changed.connect(_update_musou)
	musou.activation_rejected.connect(func(reason: String):
		musou_label.text = reason
		musou_message_left = 1.4)
	musou.field_hit.connect(_on_hit_landed)
	_update_musou(musou.charge, musou.max_charge)

func _update_musou(current: float, maximum: float) -> void:
	musou_bar.max_value = maximum
	musou_bar.value = current
	if musou_message_left > 0.0:
		return
	if is_instance_valid(musou.field):
		musou_label.text = "MUSOU ATIVA — ESFERA DE CORTES"
	elif current >= maximum:
		musou_label.text = "R — MUSOU PRONTA"
	else:
		musou_label.text = "MUSOU %d / %d — acerte / perfect guard" % [int(current), int(maximum)]
