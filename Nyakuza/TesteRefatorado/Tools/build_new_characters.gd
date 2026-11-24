extends SceneTree
## Ferramenta offline. Regera derivados, preservando os GLBs originais.
func _initialize() -> void: run.call_deferred()
func own(node: Node, scene: Node) -> void:
 for child in node.get_children():
  child.owner=scene
  own(child,scene)
func run()->void:
 for kind in ["Fox", "Cookie"]:
  var source_path: String = "FoxEnemy/fox.glb" if kind == "Fox" else "Cookie/cookie.glb"
  var model := load("res://PLACEHOLDERS/" + source_path).instantiate() as Node3D
  root.add_child(model)
  var sk := model.find_child("Skeleton3D",true,false) as Skeleton3D
  var player := model.find_child("AnimationPlayer",true,false) as AnimationPlayer
  var lib := AnimationLibrary.new()
  for clip_name in player.get_animation_list():
   var a := player.get_animation(clip_name).duplicate(true) as Animation
   for t in a.get_track_count():
    if a.track_get_type(t)==Animation.TYPE_POSITION_3D and String(a.track_get_path(t)).ends_with(":mixamorig_Hips"):
     var rest := sk.get_bone_rest(sk.find_bone("mixamorig_Hips")).origin
     for k in a.track_get_key_count(t):
      var pos: Vector3 = a.track_get_key_value(t,k)
      pos.x=rest.x; pos.z=rest.z
      a.track_set_key_value(t,k,pos)
   a.loop_mode = Animation.LOOP_LINEAR if clip_name in ["Idle_8","Running","Walking","Walk_Left_with_Gun_inplace","Walk_Backward_While_Shooting_inplace"] else Animation.LOOP_NONE
   lib.add_animation(clip_name,a)
  var pose_name: String = "Run_and_Shoot" if kind=="Fox" else "Right_Hand_Sword_Slash"
  var pose := lib.get_animation(pose_name)
  var idle := Animation.new();idle.length=1;idle.loop_mode=Animation.LOOP_LINEAR
  for t in pose.get_track_count():
   var dest := idle.add_track(pose.track_get_type(t));idle.track_set_path(dest,pose.track_get_path(t));idle.track_insert_key(dest,0,pose.track_get_key_value(t,0))
  lib.add_animation("Aim_Hold" if kind=="Fox" else "Idle_Hold",idle)
  var path: String = "res://TesteRefatorado/Enemy/Visuals/"+kind+"Animations.tres"
  assert(ResourceSaver.save(lib,path)==OK)
  player.stop()
  for key in player.get_animation_library_list():player.remove_animation_library(key)
  player.add_animation_library("",load(path));sk.reset_bone_poses();own(model,model)
  preload("res://TesteRefatorado/Tools/enemy_toon_materials.gd").apply(model,kind)
  var packed := PackedScene.new();packed.pack(model)
  assert(ResourceSaver.save(packed,"res://TesteRefatorado/Enemy/Visuals/"+kind+"Visual.tscn")==OK)
  model.queue_free()
 var source := load("res://PLACEHOLDERS/glock/glock-17.glb").instantiate() as Node3D
 root.add_child(source)
 var gun := Node3D.new();gun.name="Glock";root.add_child(gun)
 # Eixo +X do arquivo vira +Z; grip centralizado, sem animação de apresentação.
 var align := Basis(Vector3.BACK,Vector3.UP,Vector3.LEFT).scaled(Vector3.ONE*.105)
 var origin := Vector3(-.60,.75,-.10)
 for original in source.find_children("*","MeshInstance3D",true,false):
  var part := MeshInstance3D.new();part.mesh=original.mesh;gun.add_child(part);part.owner=gun
  part.transform=Transform3D(align,-(align*origin))*original.global_transform
 var muzzle := Marker3D.new();muzzle.name="Muzzle";muzzle.position=Vector3(0,.15,.27);gun.add_child(muzzle);muzzle.owner=gun
 var packed := PackedScene.new();packed.pack(gun)
 assert(ResourceSaver.save(packed,"res://TesteRefatorado/Enemy/Weapons/Glock.tscn")==OK)
 source.queue_free();gun.queue_free()
 await process_frame
 print("Fox, Cookie e Glock gerados dos GLBs originais.")
 quit()
