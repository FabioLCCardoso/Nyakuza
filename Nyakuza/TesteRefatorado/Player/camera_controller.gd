extends Node3D
class_name CameraController
signal set_cam_rotation(_cam_rotation: float)
@export var player: Player
@export_category("Aerial framing")
@export var aerial_framing: bool = true
@export_range(0.0, 0.8) var target_weight: float = 0.45
@export var max_focus_offset: float = 3.0
@export var air_distance: float = 4.8
@export var slam_distance: float = 6.5
@export var max_air_distance: float = 10.0
@export var air_pitch: float = -12.0
@export var slam_pitch: float = -28.0
@export var framing_speed: float = 8.0
@export var air_fov: float = 76.0
@export var slam_hold_time: float = 0.45
@export_category("Mouse")
@export var yaw_sensitivity: float = 0.07
@export var pitch_sensitivity: float = 0.07
@export var yaw_acceleration: float = 15.0
@export var pitch_acceleration: float = 15.0
@export var pitch_max: float = 75.0
@export var pitch_min: float = -55.0
@onready var yaw_node: Node3D = $CamYaw
@onready var pitch_node: Node3D = $CamYaw/CamPitch
@onready var spring_arm: SpringArm3D = $CamYaw/CamPitch/SpringArm3D
@onready var camera: Camera3D = $CamYaw/CamPitch/SpringArm3D/Camera3D
var yaw: float = 0.0
var pitch: float = 0.0
var base_position: Vector3
var base_distance: float
var desired_fov: float = 75.0
var air_target: Node3D
var in_air: bool = false
var slamming: bool = false
var slam_left: float = 0.0
var input_grace: float = 0.0
var last_focus: Vector3 = Vector3.ZERO

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	base_position = position
	base_distance = spring_arm.spring_length
	desired_fov = camera.fov
	spring_arm.collision_mask = 1
	spring_arm.add_excluded_object(player.get_rid())

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * yaw_sensitivity
		pitch -= event.relative.y * pitch_sensitivity
		input_grace = 0.8

func begin_air(target: Node3D) -> void:
	in_air = true
	slamming = false
	slam_left = 0.0
	air_target = target

func set_air_target(target: Node3D) -> void:
	if not slamming:
		air_target = target

func begin_slam(target: Node3D) -> void:
	slamming = true
	air_target = target
	slam_left = slam_hold_time

func end_air(immediate: bool = false) -> void:
	in_air = false
	if immediate or not slamming:
		air_target = null
		slamming = false
		slam_left = 0.0
	else:
		slam_left = slam_hold_time

func _physics_process(delta: float) -> void:
	input_grace = maxf(input_grace - delta, 0.0)
	if not in_air and slam_left > 0.0:
		slam_left = maxf(slam_left - delta, 0.0)
		if slam_left <= 0.0:
			slamming = false
			air_target = null
	var framing: bool = aerial_framing and (in_air or slam_left > 0.0)
	var desired_position: Vector3 = base_position
	var distance: float = base_distance
	var target_fov: float = desired_fov
	var target_pitch: float = clampf(pitch, pitch_min, pitch_max)
	if framing:
		if is_instance_valid(air_target):
			var relative: Vector3 = player.global_basis.inverse() * (air_target.global_position - player.global_position)
			last_focus = (relative * target_weight).limit_length(max_focus_offset)
		desired_position += last_focus
		distance = clampf((slam_distance if slamming else air_distance) + last_focus.length() * 0.5, base_distance, max_air_distance)
		target_fov = air_fov
		if input_grace <= 0.0:
			target_pitch = lerpf(target_pitch, slam_pitch if slamming else air_pitch, 0.75)
	var blend: float = 1.0 - exp(-framing_speed * delta)
	position = position.lerp(desired_position, blend)
	spring_arm.spring_length = lerpf(spring_arm.spring_length, distance, blend)
	camera.fov = lerpf(camera.fov, target_fov, blend)
	yaw_node.rotation_degrees.y = lerpf(yaw_node.rotation_degrees.y, yaw, 1.0 - exp(-yaw_acceleration * delta))
	pitch = clampf(pitch, pitch_min, pitch_max)
	pitch_node.rotation_degrees.x = lerpf(pitch_node.rotation_degrees.x, target_pitch, 1.0 - exp(-pitch_acceleration * delta))
	set_cam_rotation.emit(yaw_node.rotation.y)

func _on_set_movement_state(movement_state: MovementState) -> void:
	if not player.is_attacking:
		set_fov(movement_state.camera_fov)

func set_fov(value: float, attack_request: bool = false) -> void:
	if attack_request:
		return
	desired_fov = clampf(value, 50.0, 95.0)
