extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 var game:=Node3D.new();root.add_child(game);current_scene=game
 root.size=Vector2i(960,720);root.msaa_3d=Viewport.MSAA_4X
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR
 env.environment.background_color=Color(.055,.04,.075);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color=Color(.85,.85,1);env.environment.ambient_light_energy=.65;game.add_child(env)
 var light:=DirectionalLight3D.new();game.add_child(light);light.rotation_degrees=Vector3(-45,-35,0);light.light_energy=1.2;light.shadow_enabled=true
 var body:=StaticBody3D.new();game.add_child(body)
 var box:=BoxMesh.new();box.size=Vector3(20,.2,20)
 var mesh:=MeshInstance3D.new();mesh.mesh=box;mesh.position.y=-.1;body.add_child(mesh)
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.26,.25,.29);mesh.material_override=mat
 var shape:=CollisionShape3D.new();var geom:=BoxShape3D.new();geom.size=box.size;shape.shape=geom;shape.position.y=-.1;body.add_child(shape)
 var camera:=Camera3D.new();game.add_child(camera);camera.position=Vector3(2.5,1.9,3.5);camera.look_at(Vector3(0,.8,0));camera.current=true
 var dest:=OS.get_environment("NYAKUZA_PREVIEW_DIR")
 for kind in ["penguin","red_panda"]:
  var enemy:=load("res://TesteRefatorado/Enemy/"+kind+".tscn").instantiate() as Enemy
  game.add_child(enemy);enemy.set_physics_process(false);enemy.anim.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
  var fx:=CombatVFX.get_manager(self)
  for pose in ["idle","raise","impact","dead"]:
   var clip:=enemy.ANIM_IDLE if pose=="idle" else (enemy.ANIM_DEATH if pose=="dead" else enemy.attack_animation)
   var fraction:=0.0 if pose=="idle" else (.6 if pose=="raise" else (.8 if pose=="impact" else .999))
   enemy.anim.play(clip);enemy.anim.seek(enemy.anim.get_animation(clip).length*fraction,true)
   var sk:=enemy.model.find_child("Skeleton3D",true,false) as Skeleton3D;sk.force_update_all_bone_transforms()
   for i in 4:await process_frame
   if pose=="impact":
    if kind=="penguin":fx.ground_impact(enemy.weapon.to_global(enemy.blade_tip),1.8)
    else:fx.blood_hit(enemy,enemy.global_position+Vector3.UP,Vector3(.7,.3,1),true)
    for i in 7:await physics_frame
   if pose=="dead":
    enemy._lay_weapon_on_ground();enemy.bar_mesh.hide()
    if enemy.posture_bar!=null:enemy.posture_bar.hide()
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(dest.path_join(kind+"_"+pose+".png"))
  enemy.queue_free();fx.queue_free();await process_frame
 game.queue_free();await process_frame;quit()
