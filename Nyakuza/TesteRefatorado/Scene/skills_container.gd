extends Node3D
class_name SkillsContainer

signal completed_recovery
## avisam a hitbox quando a janela de dano abre/fecha.
signal delivery_started(skill : ActiveSkill)
signal delivery_ended

## Os golpes do combo, em ordem (golpe 1, 2, 3...). Pra aumentar o combo basta adicionar mais ActiveSkills aqui.
@export var active_skills : Array[ActiveSkill]
## Os golpes do COMBO AEREO, em ordem. Usados no lugar de active_skills enquanto o player esta no ar com os inimigos
## (ver AirComboController). O ultimo costuma ter slam = true (finisher que derruba o inimigo).
@export var air_skills : Array[ActiveSkill]
@export var heavy_ground_skill: ActiveSkill
@export var heavy_air_skill: ActiveSkill

@export_category("Combo")
## Tempo (s), depois que o golpe acaba, pra apertar de novo e continuar o combo. Passou disso, volta pro golpe 1.
@export var combo_window : float = 0.6

@onready var current_active_skill : ActiveSkill = active_skills[current_attack_id]
var current_attack_id : int = 0

var anim_tree : AnimationTree
var attack_transition_node : AnimationNodeTransition
var attack_anim_node : AnimationNodeAnimation
var attack_buffer : AnimationNodeBlendTree
var attack_buffer_id : int = 0 

var windup_timer : Timer = Timer.new()
var delivery_timer : Timer = Timer.new()
var recovery_timer : Timer = Timer.new()
var end_timer : Timer = Timer.new()
var combo_timer : Timer = Timer.new()
var vfx_token : int = 0

var attack_state : ActiveSkill.State = ActiveSkill.State.READY
## true = o proximo golpe vem de air_skills (ligado pelo AirComboController)
var air_mode : bool = false

func _ready(): 
	windup_timer.timeout.connect(_on_windup_timer_timeout)
	delivery_timer.timeout.connect(_on_delivery_timer_timeout)
	recovery_timer.timeout.connect(_on_recovery_timer_timeout)
	end_timer.timeout.connect(_on_end_timer_timeout)
	combo_timer.timeout.connect(_on_combo_timer_timeout)
	windup_timer.one_shot = true
	delivery_timer.one_shot = true
	recovery_timer.one_shot = true
	end_timer.one_shot = true 
	combo_timer.one_shot = true
	add_child(windup_timer)
	add_child(delivery_timer)
	add_child(recovery_timer)
	add_child(end_timer)
	add_child(combo_timer)

func switch_attack_buffer(attack_anim_name : StringName):
	attack_buffer_id = 1 - attack_buffer_id
	attack_buffer = anim_tree.tree_root.get("nodes/attack_buffer_" + str(attack_buffer_id) + "/node")
	attack_anim_node = attack_buffer.get_node("Animation")
	attack_anim_node.animation = attack_anim_name
	_apply_animation_trim(current_active_skill.animation_start_offset)
	
## Faz a animacao do buffer atual comecar em 'offset' segundos (0 = comeco normal).
## IMPORTANTE: sempre reseta, senao um offset antigo vazaria para o proximo golpe que usar esse buffer.
func _apply_animation_trim(offset : float):
	attack_anim_node.use_custom_timeline = offset > 0.0
	if offset > 0.0:
		var ap := anim_tree.get_node(anim_tree.anim_player) as AnimationPlayer
		var length : float = ap.get_animation(attack_anim_node.animation).length
		attack_anim_node.start_offset = offset
		attack_anim_node.timeline_length = maxf(length - offset, 0.05)

func set_attack_buffer_timescale(value : float): 
	anim_tree["parameters/attack_buffer_" + str(attack_buffer_id) + "/TimeScale/scale"] = value
	
func set_attack_transition(value: String): 
	anim_tree["parameters/attack_transition/transition_request"] = value
	
## Skill que vai tocar no PROXIMO start_attack() (o indice ja aponta pro proximo golpe do combo).
func get_current_skill(heavy: bool = false) -> ActiveSkill:
	if heavy:
		return heavy_air_skill if air_mode else heavy_ground_skill
	return skills()[current_attack_id] if not skills().is_empty() else null

## Lista de golpes em uso agora (chao ou ar).
func skills() -> Array[ActiveSkill]:
	if air_mode and not air_skills.is_empty():
		return air_skills
	return active_skills

## Troca entre combo de chao e combo aereo (sempre recomeca do golpe 1).
func set_air_mode(value : bool):
	if air_mode == value:
		return
	air_mode = value
	current_attack_id = 0
	combo_timer.stop()

func _stop_timers():
	if attack_state == ActiveSkill.State.DELIVERING:
		delivery_ended.emit()
	windup_timer.stop()
	delivery_timer.stop()
	recovery_timer.stop()
	end_timer.stop()
	combo_timer.stop()
	stop_vfx()
	
func start_attack(heavy: bool = false): 
	_stop_timers()
	
	current_active_skill = get_current_skill(heavy)
	if current_active_skill == null:
		return
	switch_attack_buffer(current_active_skill.animation_name)
	
	## COMBO: o proximo clique toca o proximo golpe; depois do ultimo volta pro primeiro.
	current_attack_id = 0 if heavy else (current_attack_id + 1) % skills().size()
	windup()

## Interrompe o golpe na hora (usado pelo dash). Por padrao zera o combo.
func cancel_attack(reset_combo : bool = true):
	_stop_timers()
	attack_state = ActiveSkill.State.READY
	if reset_combo:
		current_attack_id = 0
	attack_transition_node.xfade_time = 0.1
	set_attack_transition("end_attack")
	
func windup(): 
	attack_state = ActiveSkill.State.WINDING_UP
	attack_transition_node.xfade_time = current_active_skill.windup_duration
	set_attack_transition("attack_buffer_" + str(attack_buffer_id))
	set_attack_buffer_timescale(0)
	windup_timer.start(maxf(current_active_skill.windup_duration, 0.001))

func _on_windup_timer_timeout(): 
	deliver()
	
func deliver(): 
	attack_state = ActiveSkill.State.DELIVERING
	set_attack_buffer_timescale(current_active_skill.playback_speed)
	delivery_timer.start(maxf(current_active_skill.delivery_duration, 0.001))
	delivery_started.emit(current_active_skill)
	play_vfx(current_active_skill)
	
func _on_delivery_timer_timeout(): 
	recover()

func recover(): 
	delivery_ended.emit()
	attack_state = ActiveSkill.State.RECOVERING
	recovery_timer.start(maxf(current_active_skill.recovery_duration, 0.001))
	
func _on_recovery_timer_timeout(): 
	attack_state = ActiveSkill.State.READY
	end_timer.start(0.05)
	combo_timer.start(maxf(combo_window, 0.01))
	completed_recovery.emit()

func _on_end_timer_timeout():  
	set_attack_transition("end_attack")

func _on_combo_timer_timeout():
	current_attack_id = 0
	
## Liga o rastro da katana. vfx_delay = espera depois que o golpe comeca a andar; vfx_duration = quanto tempo fica ligado.
func play_vfx(skill : ActiveSkill): 
	var vfx : GPUTrail3D = skill.vfx
	if vfx == null:
		return
	vfx_token += 1
	var token : int = vfx_token
	
	if skill.vfx_delay > 0.0:
		await get_tree().create_timer(skill.vfx_delay).timeout
		if token != vfx_token:
			return
	
	vfx.restart()   # limpa o rastro velho, senao o trail liga o ponto antigo ao novo
	vfx.show()
	
	await get_tree().create_timer(skill.vfx_duration).timeout
	if token == vfx_token:
		stop_vfx()
	
func stop_vfx(): 
	vfx_token += 1
	for skill in active_skills + air_skills + [heavy_ground_skill, heavy_air_skill]:
		if skill != null and skill.vfx != null:
			skill.vfx.hide()

## Congela um FRAME de uma animacao existente como pose (usado pela guarda e pela subida do combo aereo).
## Usa os mesmos buffers do ataque, entao so funciona fora de um golpe (cancel_attack antes).
func hold_pose(anim_name : StringName, at_time : float, blend : float = 0.08):
	end_timer.stop()
	attack_buffer_id = 1 - attack_buffer_id
	attack_buffer = anim_tree.tree_root.get("nodes/attack_buffer_" + str(attack_buffer_id) + "/node")
	attack_anim_node = attack_buffer.get_node("Animation")
	attack_anim_node.animation = anim_name
	_apply_animation_trim(at_time)
	attack_transition_node.xfade_time = blend
	set_attack_transition("attack_buffer_" + str(attack_buffer_id))
	set_attack_buffer_timescale(0)

## Solta a pose congelada e volta pra locomocao.
func release_pose(blend : float = 0.15):
	end_timer.stop()
	attack_transition_node.xfade_time = blend
	set_attack_transition("end_attack")

func setup(_anim_tree : AnimationTree):
	anim_tree = _anim_tree
	attack_transition_node = anim_tree.tree_root.get("nodes/attack_transition/node")
