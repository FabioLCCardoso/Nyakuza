extends Node3D
class_name CombatVFX
## Gerenciador por cena: efeitos sem colisao, limitados e removidos automaticamente.
@export var settings: CombatVFXSettings = preload("res://TesteRefatorado/VFX/default_vfx_settings.tres")
var bursts: Array[Node3D] = []
var marks: Array[Node3D] = []
var recent_hits: Dictionary = {}
var last_ground_msec: int = -1000
var blood_spawned: int = 0
var ground_spawned: int = 0
var drop_mesh: SphereMesh
var debris_mesh: BoxMesh
var rng := RandomNumberGenerator.new()
static func get_manager(tree:SceneTree)->CombatVFX:
 var parent:Node=tree.current_scene if tree.current_scene!=null else tree.root
 var manager:=parent.get_node_or_null("CombatVFX") as CombatVFX
 if manager==null:
  manager=CombatVFX.new();manager.name="CombatVFX";parent.add_child(manager)
 return manager
static func floor_at(source:Node3D,position:Vector3)->Dictionary:
 var hit:=source.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position+Vector3.UP*3,position-Vector3.UP*5,1))
 if hit.is_empty() or hit.normal.dot(Vector3.UP)<.7:return {}
 return hit
func _ready()->void:
 rng.randomize();drop_mesh=SphereMesh.new();drop_mesh.radius=.035;drop_mesh.height=.15;drop_mesh.radial_segments=6;drop_mesh.rings=3
 debris_mesh=BoxMesh.new();debris_mesh.size=Vector3(.16,.13,.2)
func _process(_delta:float)->void:
 for key in recent_hits.keys():
  if not is_instance_valid(recent_hits[key].ref.get_ref()) or Time.get_ticks_msec()-int(recent_hits[key].time)>2000:recent_hits.erase(key)
func material(color:Color)->StandardMaterial3D:
 var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.9;mat.cull_mode=BaseMaterial3D.CULL_DISABLED
 return mat
func register_effect(node:Node3D,mark:bool,lifetime:float)->void:
 var list:Array[Node3D]=marks if mark else bursts
 for i in range(list.size()-1,-1,-1):
  if not is_instance_valid(list[i]):list.remove_at(i)
 var limit:=maxi(1,settings.max_marks if mark else settings.max_bursts)
 while list.size()>=limit:
  var old:Node3D=list.pop_front()
  if is_instance_valid(old):old.queue_free()
 list.append(node)
 var reference:WeakRef=weakref(node)
 get_tree().create_timer(lifetime, false).timeout.connect(func():
  var effect:=reference.get_ref() as Node3D
  if is_instance_valid(effect):effect.queue_free())
func burst(at:Vector3,direction:Vector3,count:int,life:float,color:Color,rock:bool=false)->void:
 var particles:=GPUParticles3D.new();particles.name="Debris" if rock else "BloodSpray"
 particles.one_shot=true;particles.amount=maxi(1,count);particles.lifetime=life;particles.explosiveness=1.0;particles.local_coords=false
 particles.visibility_aabb=AABB(Vector3(-6,-6,-6),Vector3(12,12,12));particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var process:=ParticleProcessMaterial.new();process.direction=direction.normalized() if direction.length_squared()>.001 else Vector3.UP
 process.spread=58;process.initial_velocity_min=2;process.initial_velocity_max=4.2 if rock else 3.2;process.gravity=Vector3(0,-12,0)
 process.angular_velocity_min=-160;process.angular_velocity_max=160;process.scale_min=.7;process.scale_max=1.7
 var curve:=Curve.new();curve.add_point(Vector2(0,1));curve.add_point(Vector2(.65,1));curve.add_point(Vector2(1,0))
 var texture:=CurveTexture.new();texture.curve=curve;process.scale_curve=texture
 particles.process_material=process;particles.draw_pass_1=debris_mesh if rock else drop_mesh;particles.material_override=material(color)
 add_child(particles);particles.global_position=at;particles.emitting=true;particles.restart();register_effect(particles,false,life+.15)
func flat_mesh(points:PackedVector3Array,color:Color)->MeshInstance3D:
 var mesh:=ArrayMesh.new();var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=points
 var normals:=PackedVector3Array();normals.resize(points.size());normals.fill(Vector3.UP);arrays[Mesh.ARRAY_NORMAL]=normals
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var node:=MeshInstance3D.new();node.mesh=mesh;node.material_override=material(color);node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return node
func fade_mark(mark:MeshInstance3D,life:float)->void:
 var mat:=mark.material_override as StandardMaterial3D;var tween:=mark.create_tween()
 tween.tween_interval(maxf(.1,life-1));tween.tween_callback(func():mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA)
 tween.tween_property(mat,"albedo_color:a",0.0,1.0);register_effect(mark,true,life+.1)
func blood_hit(victim:Node3D,at:Vector3,direction:Vector3,heavy:bool=false)->void:
 if not settings.blood_enabled or settings.blood_intensity<=0:return
 var now:=Time.get_ticks_msec();var id:=victim.get_instance_id()
 if recent_hits.has(id) and now-int(recent_hits[id].time)<int(settings.blood_interval*1000):return
 recent_hits[id]={"ref":weakref(victim),"time":now};blood_spawned+=1
 burst(at,(direction+Vector3.UP*.65).normalized(),int((14 if heavy else 8)*settings.blood_intensity),.55,settings.blood_color)
 var floor_hit:=floor_at(self,at)
 if floor_hit.is_empty():return
 var verts:=PackedVector3Array()
 for drop in (7 if heavy else 4):
  var center:=Vector3(rng.randf_range(-.22,.22),0,rng.randf_range(-.22,.22));var radius:=rng.randf_range(.04,.13)*(1.5 if heavy else 1.0)
  for i in 7:
   var a:=float(i)*TAU/7;var b:=float(i+1)*TAU/7
   verts.append(center);verts.append(center+Vector3(cos(a),0,sin(a))*radius);verts.append(center+Vector3(cos(b),0,sin(b))*radius)
 var mark:=flat_mesh(verts,settings.blood_color.darkened(.25));mark.name="BloodMark";add_child(mark);mark.global_position=floor_hit.position+Vector3.UP*.018
 fade_mark(mark,settings.blood_mark_lifetime)
func ground_impact(at:Vector3,radius:float=1.8)->void:
 if not settings.ground_enabled:return
 var now:=Time.get_ticks_msec()
 if now-last_ground_msec<90:return
 var floor_hit:=floor_at(self,at)
 if floor_hit.is_empty():return
 last_ground_msec=now;ground_spawned+=1
 var center:Vector3=floor_hit.position+Vector3.UP*.025;radius=clampf(radius,.5,3)
 burst(center+Vector3.UP*.12,Vector3.UP,18,.85,Color(.22,.18,.25),true);dust(center,radius)
 var verts:=PackedVector3Array()
 for ray in 12:
  var angle:=float(ray)*TAU/12+rng.randf_range(-.14,.14);var start:=Vector3.ZERO
  for segment in 4:
   var end:=Vector3(cos(angle),0,sin(angle))*radius*float(segment+1)/4+Vector3(rng.randf_range(-.1,.1),0,rng.randf_range(-.1,.1))
   var across:=Vector3(-(end-start).z,0,(end-start).x).normalized()*(.04-float(segment)*.007)
   verts.append_array(PackedVector3Array([start-across,start+across,end+across,start-across,end+across,end-across]));start=end
 var cracks:=flat_mesh(verts,Color(.018,.008,.025));cracks.name="GroundCracks";add_child(cracks);cracks.global_position=center
 fade_mark(cracks,settings.ground_mark_lifetime)
 var ring:=MeshInstance3D.new();ring.name="ImpactRing";var torus:=TorusMesh.new();torus.inner_radius=.91;torus.outer_radius=1;torus.rings=32;torus.ring_segments=6
 ring.mesh=torus;ring.material_override=material(Color(.75,.65,.8,.8));(ring.material_override as StandardMaterial3D).transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 add_child(ring);ring.global_position=center;ring.scale=Vector3(.1,.06,.1)
 var tween:=ring.create_tween().set_parallel();tween.tween_property(ring,"scale",Vector3(radius,.04,radius),.32);tween.tween_property(ring.material_override,"albedo_color:a",0.0,.32)
 register_effect(ring,false,.4)
func dust(at:Vector3,radius:float)->void:
 var p:=GPUParticles3D.new();p.name="ImpactDust";p.one_shot=true;p.explosiveness=1;p.amount=10;p.lifetime=.7;p.local_coords=false
 p.visibility_aabb=AABB(Vector3(-5,-2,-5),Vector3(10,5,10));p.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var process:=ParticleProcessMaterial.new();process.direction=Vector3.UP;process.spread=85;process.initial_velocity_min=radius*.65;process.initial_velocity_max=radius*1.3
 process.gravity=Vector3(0,.15,0);process.scale_min=.6;process.scale_max=1.3
 var fade:=Gradient.new();fade.colors=PackedColorArray([Color(1,1,1,.35),Color(1,1,1,0)])
 var ramp:=GradientTexture1D.new();ramp.gradient=fade;process.color_ramp=ramp;p.process_material=process
 var quad:=QuadMesh.new();quad.size=Vector2(.75,.75);p.draw_pass_1=quad
 var mat:=material(Color(.55,.48,.58));mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;mat.vertex_color_use_as_albedo=true
 var radial:=Gradient.new();radial.colors=PackedColorArray([Color.WHITE,Color(1,1,1,0)])
 var texture:=GradientTexture2D.new();texture.gradient=radial;texture.fill=GradientTexture2D.FILL_RADIAL;texture.fill_from=Vector2(.5,.5);texture.fill_to=Vector2(1,.5)
 mat.albedo_texture=texture;p.material_override=mat;add_child(p);p.global_position=at+Vector3.UP*.15;p.restart();register_effect(p,false,.85)
