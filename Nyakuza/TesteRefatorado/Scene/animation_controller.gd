extends Node

@export var animation_tree : AnimationTree
@export var player : CharacterBody3D

var on_floor_blend : float = 1
var on_floor_blend_target : float = 1

var was_on_floor: bool = false

var tween : Tween 

func _ready() -> void:
	var ap := animation_tree.get_node(animation_tree.anim_player) as AnimationPlayer
	ap.add_animation_library("Spike", preload("res://TesteRefatorado/Player/Animations/SpikeCombat.tres"))
	animation_tree.tree_root = animation_tree.tree_root.duplicate(true)
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	var tree := animation_tree.tree_root as AnimationNodeBlendTree
	(tree.get_node("Animation") as AnimationNodeAnimation).animation = &"Spike/GroundJump"
	var ground := tree.get_node("Animation") as AnimationNodeAnimation
	ground.use_custom_timeline = false
	(tree.get_node("Animation 2") as AnimationNodeAnimation).animation = &"Spike/DoubleJump"
	(tree.get_node("falling") as AnimationNodeAnimation).animation = &"Spike/AirFall"
	for key in ["ground_jump", "air_jump"]:
		var shot := tree.get_node(key) as AnimationNodeOneShot
		shot.fadein_time = 0.035
		shot.fadeout_time = 0.10
	_bind_weapon_to_hand()

func _bind_weapon_to_hand() -> void:
	var socket := player.find_child("katana", true, false) as BoneAttachment3D
	if socket == null:return
	var skeleton := socket.get_parent() as Skeleton3D
	var hand := skeleton.find_bone("mixamorig_RightHand")
	var old := skeleton.find_bone(socket.bone_name)
	if hand < 0 or old < 0 or hand == old:return
	# Mantém o grip e o rastro ao trocar a referência do dedo para a mão.
	var grip := skeleton.get_bone_global_rest(hand).affine_inverse() * skeleton.get_bone_global_rest(old)
	for child in socket.get_children():
		if child is Node3D:child.transform = grip * child.transform
	socket.bone_name = skeleton.get_bone_name(hand)
	socket.bone_idx = hand

func _physics_process(delta: float) -> void:
	var grounded := player.is_on_floor()
	on_floor_blend_target = 1.0 if grounded else 0.0
	on_floor_blend = lerpf(on_floor_blend, on_floor_blend_target, 1.0 - exp(-12.0 * delta))
	animation_tree["parameters/on_floor_blend/blend_amount"] = on_floor_blend
	if grounded and not was_on_floor:
		for key in ["ground_jump", "air_jump"]:
			animation_tree["parameters/" + key + "/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT
	was_on_floor = grounded

func _jump(jump_state: JumpState):
	# O segundo salto substitui o primeiro: não mistura duas animações de salto.
	var other := "ground_jump" if jump_state.animation_name == "air_jump" else "air_jump"
	animation_tree["parameters/" + other + "/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT
	animation_tree["parameters/" + jump_state.animation_name + "/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE

func _on_set_movement_state(_movement_state : MovementState):
	if tween:
		tween.kill()
		
	tween = create_tween()
	tween.tween_property(animation_tree, "parameters/movement_blend/blend_position", _movement_state.id, 0.25)
	tween.parallel().tween_property(animation_tree, "parameters/movement_anim_speed/scale", _movement_state.animation_speed, 0.7)
