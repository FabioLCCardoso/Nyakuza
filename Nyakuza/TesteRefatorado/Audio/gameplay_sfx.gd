extends Node
class_name GameplaySFX

@export var clips: Dictionary[String, AudioStream]
@export var gain_db: Dictionary[String, float]
@export_range(4,32) var max_voices := 16
var last_frame: Dictionary = {}

static func play_at(source: Node3D, cue: String) -> void:
	if not is_instance_valid(source) or not source.is_inside_tree(): return
	var scene := source.get_tree().current_scene
	if scene == null: return
	var bank := scene.get_node_or_null("GameplaySFX") as GameplaySFX
	if bank == null:
		bank = (load("res://TesteRefatorado/Audio/GameplaySFX.tscn") as PackedScene).instantiate()
		scene.add_child(bank)
	bank._play(cue, source.global_position)

func _play(cue: String, pos: Vector3) -> void:
	var stream := clips.get(cue) as AudioStream
	if stream == null: return
	# Uma horda acertada no mesmo swing não deve somar dezenas de cortes.
	var frame := Engine.get_physics_frames()
	if cue in ["hit", "swish", "heavy"] and frame - int(last_frame.get(cue, -100)) < 3: return
	var voice: AudioStreamPlayer3D
	for child: AudioStreamPlayer3D in get_children():
		if not child.playing:
			voice = child
			break
	if not voice:
		if get_child_count() >= max_voices: return
		voice = AudioStreamPlayer3D.new()
		voice.unit_size = 9.0
		voice.max_distance = 48.0
		add_child(voice)
	last_frame[cue] = frame
	voice.global_position = pos
	voice.stream = stream
	voice.volume_db = gain_db.get(cue, -10.0)
	voice.play()

func _exit_tree() -> void:
	for voice: AudioStreamPlayer3D in get_children():
		voice.stop()
		voice.stream = null
