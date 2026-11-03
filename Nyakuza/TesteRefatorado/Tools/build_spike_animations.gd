extends SceneTree
## Deriva clips do GLB original; não altera o asset importado.
func _initialize() -> void: build.call_deferred()
func build() -> void:
 var model := load("res://PLACEHOLDERS/spike_prototipo.tscn").instantiate() as Node3D
 root.add_child(model)
 var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
 var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
 var hips := skeleton.get_bone_rest(skeleton.find_bone("mixamorig_Hips")).origin
 var library := AnimationLibrary.new()
 for name in ["Right_Hand_Sword_Slash", "Charged_Slash", "Attack", "Charged_Upward_Slash"]:
  var clip := player.get_animation(name).duplicate(true) as Animation
  for t in clip.get_track_count():
   if clip.track_get_type(t) == Animation.TYPE_POSITION_3D and String(clip.track_get_path(t)).ends_with(":mixamorig_Hips"):
    for k in clip.track_get_key_count(t):
     var p: Vector3 = clip.track_get_key_value(t,k)
     p.x = hips.x; p.z = hips.z
     clip.track_set_key_value(t,k,p)
  clip.loop_mode = Animation.LOOP_NONE
  library.add_animation(name, clip)
 library.add_animation("GroundJump", slice(player.get_animation("Basic_Jump"),1.50,2.23,.52,hips))
 library.add_animation("DoubleJump", slice(player.get_animation("Basic_Jump"),1.72,2.28,.42,hips))
 var falling := slice(player.get_animation("Jump_Run"),.78,.82,1.0,hips)
 falling.loop_mode = Animation.LOOP_LINEAR
 library.add_animation("AirFall", falling)
 assert(ResourceSaver.save(library,"res://TesteRefatorado/Player/Animations/SpikeCombat.tres") == OK)
 print("Spike: 4 ataques in-place + GroundJump, DoubleJump e AirFall gerados.")
 model.queue_free();await process_frame;quit()
func slice(source: Animation, start: float, end: float, duration: float, hips: Vector3) -> Animation:
 var clip := Animation.new();clip.length = duration
 for t in source.get_track_count():
  var kind := source.track_get_type(t)
  if kind not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:continue
  var track := clip.add_track(kind);clip.track_set_path(track,source.track_get_path(t))
  for i in 31:
   var at := lerpf(start,end,float(i)/30)
   var target := duration*float(i)/30
   if kind == Animation.TYPE_ROTATION_3D:clip.rotation_track_insert_key(track,target,source.rotation_track_interpolate(t,at))
   elif kind == Animation.TYPE_SCALE_3D:clip.scale_track_insert_key(track,target,source.scale_track_interpolate(t,at))
   else:
    var value := source.position_track_interpolate(t,at)
    if String(source.track_get_path(t)).ends_with(":mixamorig_Hips"):value = hips
    clip.position_track_insert_key(track,target,value)
 return clip
