extends Node3D
class_name SkillsContainer

signal completed_recovery
## avisam a hitbox quando a janela de dano abre/fecha.
signal delivery_started(skill : ActiveSkill)
signal delivery_ended

## Os golpes do combo, em ordem (golpe 1, 2, 3...). Pra aumentar o combo basta adicionar mais ActiveSkills aqui.
@export var active_skills : Array[ActiveSkill]

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

func _ready(): 
	windup_timer.timeout.connect(_on_windup_timer_timeout)
	delivery_timer.timeout.connect(_on_delivery_timer_timeout)
	recovery_timer.timeout.connect(_on_recovery_timer_timeout)
	end_timer.timeout.connect(_on_end_timer_timeout)
	combo_timer.timeout.connect(_on_combo_timer_timeout)
	windup_timer.one_shot = true
	delivery_timer.one_shot = true
	recovery_timer.one_shot = true 
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
	
func set_attack_buffer_timescale(value : float): 
	anim_tree["parameters/attack_buffer_" + str(attack_buffer_id) + "/TimeScale/scale"] = value
	
func set_attack_transition(value: String): 
	anim_tree["parameters/attack_transition/transition_request"] = value
	
## Skill que vai tocar no PROXIMO start_attack() (o indice ja aponta pro proximo golpe do combo).
func get_current_skill() -> ActiveSkill: 
	return active_skills[current_attack_id]

func _stop_timers():
	if attack_state == ActiveSkill.State.DELIVERING:
		delivery_ended.emit()
	windup_timer.stop()
	delivery_timer.stop()
	recovery_timer.stop()
	end_timer.stop()
	combo_timer.stop()
	stop_vfx()
	
func start_attack(): 
	_stop_timers()
	
	current_active_skill = active_skills[current_attack_id]
	switch_attack_buffer(current_active_skill.animation_name)
	
	## COMBO: o proximo clique toca o proximo golpe; depois do ultimo volta pro primeiro.
	current_attack_id = (current_attack_id + 1) % active_skills.size()
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
	windup_timer.start(current_active_skill.windup_duration)

func _on_windup_timer_timeout(): 
	deliver()
	
func deliver(): 
	attack_state = ActiveSkill.State.DELIVERING
	set_attack_buffer_timescale(1)
	delivery_timer.start(current_active_skill.delivery_duration)
	delivery_started.emit(current_active_skill)
	play_vfx(current_active_skill)
	
func _on_delivery_timer_timeout(): 
	recover()

func recover(): 
	delivery_ended.emit()
	attack_state = ActiveSkill.State.RECOVERING
	recovery_timer.start(current_active_skill.recovery_duration)
	
func _on_recovery_timer_timeout(): 
	attack_state = ActiveSkill.State.READY
	completed_recovery.emit()
	end_timer.start(0.05)
	combo_timer.start(combo_window)

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
	for skill in active_skills:
		if skill.vfx != null:
			skill.vfx.hide()

func setup(_anim_tree : AnimationTree):
	anim_tree = _anim_tree
	attack_transition_node = anim_tree.tree_root.get("nodes/attack_transition/node")
