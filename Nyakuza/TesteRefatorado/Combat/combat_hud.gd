extends CanvasLayer
class_name CombatHUD
## HUD feita toda em codigo (sem cena de UI): barra de vida, contador de inimigos, flash de dano e tela de morte.
## Teclas para gravar o teaser:  F1 = god mode   F2 = esconde/mostra HUD   R = reinicia a cena

@export var player_health : HealthComponent
@export var player_combat : PlayerCombat

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

func _ready():
	layer = 10
	_build_ui()
	if player_health != null:
		player_health.health_changed.connect(_on_health_changed)
		player_health.died.connect(_on_player_died)
		_on_health_changed(player_health.current_health, player_health.max_health)
	if player_combat != null:
		player_combat.player_hit.connect(_on_player_hit)
	_update_god_label()

func _process(delta):
	enemy_timer -= delta
	if enemy_timer <= 0.0:
		enemy_timer = 0.2
		enemies_label.text = "INIMIGOS  %d " % get_tree().get_nodes_in_group("enemies").size()

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
		KEY_R:
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
	hint.text = "LMB - Attack, WASD - Movement, Mouse - Camera, Q - Evade"
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(1, 1, 1, 0.45)
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -420
	hint.offset_right = -24
	hint.offset_top = -40
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
	small.text = "Pressione R para reiniciar"
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
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(hp_trail, "anchor_right", ratio, 0.4)

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
