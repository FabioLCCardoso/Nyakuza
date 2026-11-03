extends SceneTree
## Ferramenta offline. Regera derivados, preservando os GLBs originais.
func _initialize() -> void: run.call_deferred()
func own(node: Node, scene: Node) -> void:
 for child in node.get_children():
  child.owner=scene
  own(child,scene)
func low_point(mesh: MeshInstance3D, sk: Skeleton3D) -> float:
 var arr:=mesh.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arr[Mesh.ARRAY_VERTEX]
 var bones:PackedInt32Array=arr[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arr[Mesh.ARRAY_WEIGHTS]
 var transforms:Array[Transform3D]=[]
 for b in mesh.skin.get_bind_count():transforms.append(sk.get_bone_global_pose(sk.find_bone(mesh.skin.get_bind_name(b)))*mesh.skin.get_bind_pose(b))
 var low:float=INF
 for v in vertices.size():
  var point:=Vector3.ZERO
  for k in 4:point+=(transforms[bones[v*4+k]]*vertices[v])*weights[v*4+k]
  low=minf(low,point.y)
 return low
func add_tail(mesh:MeshInstance3D,sk:Skeleton3D)->int:
 var tail:=sk.get_bone_count();sk.add_bone("NyakuzaTail");sk.set_bone_parent(tail,0)
 var rest:=Transform3D(Basis.IDENTITY,Vector3(0,.47,.18))
 sk.set_bone_rest(tail,sk.get_bone_global_rest(0).affine_inverse()*rest);sk.reset_bone_pose(tail)
 var skin:=mesh.skin.duplicate() as Skin
 var bind:=skin.get_bind_count();skin.add_named_bind("NyakuzaTail",rest.affine_inverse());mesh.skin=skin
 var source:=mesh.mesh;var result:=ArrayMesh.new()
 for surface in source.get_surface_count():
  var arrays:=source.surface_get_arrays(surface)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
  var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  for v in vertices.size():
   var mix:=1.0-smoothstep(-.04,.16,vertices[v].z) if vertices[v].y<.78 else 0.0
   if mix<=0:continue
   var entries:Array[Vector2]=[]
   for k in 4:entries.append(Vector2(bones[v*4+k],weights[v*4+k]*(1.0-mix)))
   entries.append(Vector2(bind,mix));entries.sort_custom(func(a:Vector2,b:Vector2)->bool:return a.y>b.y)
   var total:=0.0
   for k in 4:total+=entries[k].y
   for k in 4:bones[v*4+k]=int(entries[k].x);weights[v*4+k]=entries[k].y/total
  arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  result.surface_set_material(surface,source.surface_get_material(surface))
 mesh.mesh=result
 return tail
func run()->void:
 for kind in ["Penguin","RedPanda"]:
  var model:=load("res://PLACEHOLDERS/"+kind+"Enemy/"+kind+"Enemy.glb").instantiate() as Node3D
  root.add_child(model)
  var sk:=model.find_child("Skeleton3D",true,false) as Skeleton3D
  var mesh:=model.find_child("Mesh_0",true,false) as MeshInstance3D
  var player:=model.find_child("AnimationPlayer",true,false) as AnimationPlayer
  var tail:=add_tail(mesh,sk) if kind=="RedPanda" else -1
  var lib:=AnimationLibrary.new()
  for name in player.get_animation_list():
   if tail>=0:sk.reset_bone_pose(tail)
   var a:=player.get_animation(name).duplicate(true) as Animation
   var track: int=-1
   for t in a.get_track_count():
    if a.track_get_type(t)==Animation.TYPE_POSITION_3D and String(a.track_get_path(t)).ends_with(":mixamorig_Hips"):track=t
   if track<0:continue
   var rest:=sk.get_bone_rest(0).origin
   for k in a.track_get_key_count(track):
    var p:Vector3=a.track_get_key_value(track,k);p.x=rest.x;p.z=rest.z;a.track_set_key_value(track,k,p)
   var temp:=AnimationLibrary.new();temp.add_animation("sample",a);player.add_animation_library("bake",temp)
   var points:Array[Vector3]=[];var times:Array[float]=[];var rotations:Array[Quaternion]=[]
   for i in range(int(ceil(a.length*30))+1):
    var at:=minf(float(i)/30,a.length)
    player.play("bake/sample");player.seek(at,true);sk.force_update_all_bone_transforms()
    if tail>=0 and name=="Knock_Down":
     var correction:=sk.get_bone_global_pose(0).basis.inverse().orthonormalized().get_rotation_quaternion()
     sk.set_bone_pose_rotation(tail,correction);sk.force_update_all_bone_transforms();rotations.append(correction)
    var p:Vector3=a.position_track_interpolate(track,at);p.y+=maxf(0,-low_point(mesh,sk))+.015
    times.append(at);points.append(p)
   player.play(name);player.stop(true);player.remove_animation_library("bake")
   while a.track_get_key_count(track)>0:a.track_remove_key(track,0)
   for i in points.size():a.position_track_insert_key(track,times[i],points[i])
   if tail>=0:
    var t:=a.add_track(Animation.TYPE_ROTATION_3D);a.track_set_path(t,NodePath("SmartRigArmature/Skeleton3D:NyakuzaTail"))
    if rotations.is_empty():a.rotation_track_insert_key(t,0,sk.get_bone_rest(tail).basis.get_rotation_quaternion())
    else:
     for i in times.size():a.rotation_track_insert_key(t,times[i],rotations[i])
   a.loop_mode=Animation.LOOP_LINEAR if name in ["Running","Walking","Idle_8"] else Animation.LOOP_NONE
   lib.add_animation(name,a);print(kind," normalized ",name)
  if kind=="Penguin":
   var source:=lib.get_animation("Attack");var idle:=Animation.new();idle.length=1;idle.loop_mode=Animation.LOOP_LINEAR
   for t in source.get_track_count():
    var dest:=idle.add_track(source.track_get_type(t));idle.track_set_path(dest,source.track_get_path(t));idle.track_insert_key(dest,0,source.track_get_key_value(t,0))
   lib.add_animation("Idle_Hold",idle)
  var path: String="res://TesteRefatorado/Enemy/Visuals/"+kind+"Animations.tres"
  ResourceSaver.save(lib,path);player.stop()
  for key in player.get_animation_library_list():player.remove_animation_library(key)
  player.add_animation_library("",load(path) as AnimationLibrary);sk.reset_bone_poses();own(model,model)
  preload("res://TesteRefatorado/Tools/enemy_toon_materials.gd").apply(model, kind)
  var packed:=PackedScene.new();packed.pack(model);ResourceSaver.save(packed,"res://TesteRefatorado/Enemy/Visuals/"+kind+"Visual.tscn")
  model.queue_free()
 for kind in ["DragonSlayer","Katana"]:
  var path: String="DragonSlayer/dragon_slayer_berserk.glb" if kind=="DragonSlayer" else "katanalowpoly/katana_low_poly.glb"
  var source:=load("res://PLACEHOLDERS/"+path).instantiate() as Node3D;root.add_child(source)
  var weapon:=Node3D.new();weapon.name=kind;root.add_child(weapon)
  for original in source.find_children("*","MeshInstance3D",true,false):
   var part:=MeshInstance3D.new();part.name=original.name;part.mesh=original.mesh;weapon.add_child(part);part.owner=weapon
   if kind=="DragonSlayer":
    part.basis=Basis(Vector3(0,-1,0),Vector3(0,0,1),Vector3(-1,0,0)).scaled(Vector3.ONE*1.25);part.position=Vector3(0,1.1,0)
   else:part.transform=Transform3D(Basis(Vector3.RIGHT,Vector3(0,0,-1),Vector3.UP),Vector3(0,.3,.01))*original.global_transform
  var packed:=PackedScene.new();packed.pack(weapon);ResourceSaver.save(packed,"res://TesteRefatorado/Enemy/Weapons/"+kind+".tscn")
  source.queue_free();weapon.queue_free()
 await process_frame
 quit()
