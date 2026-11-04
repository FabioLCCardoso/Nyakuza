extends CanvasLayer
class_name GameMenu
const MAIN = "res://TesteRefatorado/UI/MainMenu.tscn"
const GAME = "res://TesteRefatorado/Campaign/Campaign.tscn"
const CYAN = Color(0.30, 0.88, 1)
const PINK = Color(1, 0.22, 0.52)
@export var in_game: bool = false
var screen: Control
var content: VBoxContainer
var title: Label
var subtitle: Label
var controls_visible: bool = false
var result: String = ""
var changing: bool = false
var controls_return: Callable

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	add_to_group("game_menu")
	_build()
	if in_game:
		screen.hide()
	else:
		get_tree().paused = false
		Engine.time_scale = 1.0
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		show_main()

func _build() -> void:
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = Color(0.01, 0.005, 0.035, 0.90)
	if not in_game:
		var material := ShaderMaterial.new()
		material.shader = preload("res://TesteRefatorado/UI/menu_background.gdshader")
		background.material = material
	screen.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 550)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.02, 0.065, 0.96)
	style.set_border_width_all(1)
	style.border_color = CYAN.darkened(0.4)
	style.content_margin_left = 44
	style.content_margin_right = 44
	style.content_margin_top = 30
	style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.97, 0.95, 1))
	content.add_child(title)
	subtitle = Label.new()
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", CYAN)
	content.add_child(subtitle)

func _clear() -> void:
	for node in content.get_children():
		if node != title and node != subtitle:
			content.remove_child(node)
			node.queue_free()
	controls_visible = false

func _text(value: String, size: int = 18, color: Color = Color(0.72, 0.72, 0.82)) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	content.add_child(label)
	return label

func _button(value: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 48
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 20)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.035, 0.10) if primary else Color(0.065, 0.055, 0.12)
	normal.border_color = PINK if primary else Color(0.25, 0.22, 0.35)
	normal.set_border_width_all(1)
	normal.content_margin_left = 20
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.08, 0.14, 0.22)
	hover.border_color = CYAN
	hover.set_border_width_all(2)
	for state in ["hover", "focus", "pressed"]:
		button.add_theme_stylebox_override(state, hover)
	button.pressed.connect(action)
	content.add_child(button)
	return button

func show_main() -> void:
	_clear()
	title.text = "NYAKUZA"
	title.add_theme_font_override("font", preload("res://TesteRefatorado/Arena/Fonts/edosz.ttf"))
	title.add_theme_font_size_override("font_size", 78)
	subtitle.text = "UMA NOITE. QUATRO DISTRITOS. NENHUM RECUO."
	_text("CIDADE NEON / ROTA DO ECLIPSE", 14, PINK)
	_text("01 Letreiros → 02 Arcade → 03 Torii → 04 Oyabun", 17)
	_text("Derrote as ondas, abra as passagens e enfrente o chefe.")
	_button("INICIAR JOGO →", start_game, true).grab_focus()
	_button("CONTROLES", func(): show_controls(show_main))
	_button("SAIR", func(): get_tree().quit())
	_text("Teclado + mouse • Enter para selecionar • Setas para navegar", 14)

func start_game() -> void:
	_change_scene(GAME)

func _change_scene(path: String) -> void:
	if changing: return
	changing = true
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		changing = false
		subtitle.text = "Não foi possível abrir a cena: %s" % error_string(error)
		if in_game: get_tree().paused = true

func pause_game() -> void:
	if not in_game or screen.visible: return
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	screen.show()
	show_pause()

func show_pause() -> void:
	_clear()
	title.text = "PAUSA"
	subtitle.text = "A CIDADE PODE ESPERAR."
	_text("A luta, os efeitos e as ondas estão pausados.")
	_button("CONTINUAR", resume_game, true).grab_focus()
	_button("CONTROLES", func(): show_controls(show_pause))
	_button("VOLTAR AO MENU PRINCIPAL", func(): _change_scene(MAIN))
	_text("Voltar ao menu encerra esta partida. O progresso não é salvo.", 15)
	_text("Esc / Start para continuar", 15, CYAN)

func resume_game() -> void:
	if not result.is_empty(): return
	screen.hide()
	controls_visible = false
	get_tree().paused = false
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null: player.refresh_movement_input()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func show_controls(back: Callable) -> void:
	_clear()
	controls_visible = true
	controls_return = back
	title.text = "CONTROLES"
	title.remove_theme_font_override("font")
	title.add_theme_font_size_override("font_size", 48)
	subtitle.text = "SPIKE / COMBATE E MOVIMENTO"
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 42)
	grid.add_theme_constant_override("v_separation", 7)
	content.add_child(grid)
	for row in [
		["WASD / Mouse", "Mover / olhar"],
		["Espaço / Espaço no ar", "Pular / salto duplo"],
		["Shift", "Correr"],
		["Mouse esquerdo", "Ataque leve / combo"],
		["Mouse direito", "Pesado / lançar / slam no ar"],
		["Q", "Esquivar / seguir inimigo lançado"],
		["F (segurar)", "Defender / defesa perfeita"],
		["R", "Musou (barra cheia)"],
		["Esc / Start", "Pausar / continuar"]]:
		for i in 2:
			var label := Label.new()
			label.text = row[i]
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", CYAN if i == 0 else Color.WHITE)
			grid.add_child(label)
	_button("← VOLTAR", back, true).grab_focus()

func show_result(won: bool, kos: int) -> void:
	result = "victory" if won else "defeat"
	screen.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clear()
	title.text = "CIDADE LIBERADA" if won else "FIM DE PARTIDA"
	subtitle.text = "ROTA DO ECLIPSE / %d KOs" % kos
	_text("Oyabun caiu. A noite é sua." if won else "Spike caiu. Tente uma nova investida.")
	_button("JOGAR NOVAMENTE →", start_game, true).grab_focus()
	_button("CONTROLES", func(): show_controls(func(): show_result(won, kos)))
	_button("MENU PRINCIPAL", func(): _change_scene(MAIN))

func _input(event: InputEvent) -> void:
	# B tambem e ui_cancel, mas durante o jogo precisa continuar sendo dash.
	var pause_event: bool = (event is InputEventKey and event.is_action_pressed("ui_cancel")) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START) or (screen.visible and event.is_action_pressed("ui_cancel"))
	if event.is_echo() or not pause_event: return
	get_viewport().set_input_as_handled()
	if screen.visible and controls_visible:
		controls_return.call()
	elif in_game:
		if not result.is_empty(): return
		if screen.visible: resume_game()
		else: pause_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and in_game and is_instance_valid(screen) and not screen.visible:
		pause_game()
