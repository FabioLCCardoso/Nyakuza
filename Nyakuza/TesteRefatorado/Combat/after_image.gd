extends RefCounted
class_name AfterImage
## Rastro "fantasma": tira uma foto da pose atual do corpo e deixa a copia desbotando no lugar.
## Uso: AfterImage.spawn(get_tree(), lista_de_MeshInstance3D, Color(0.5, 0.85, 1.0, 0.5), 0.3)
## Dica: pode ser chamado de qualquer lugar (ex: no seu DashController, a cada 0.04 s durante o dash).

static func spawn(tree : SceneTree, sources : Array[MeshInstance3D], color : Color = Color(0.55, 0.85, 1.0, 0.5), lifetime : float = 0.3) -> void:
	var parent : Node = tree.current_scene if tree.current_scene != null else tree.root
	for mi in sources:
		if not is_instance_valid(mi) or not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var mesh : Mesh = mi.mesh
		if mi.skin != null:
			mesh = mi.bake_mesh_from_current_skeleton_pose()   # corpo com a pose atual do esqueleto
			if mesh == null:
				continue
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = color
		var ghost := MeshInstance3D.new()
		ghost.mesh = mesh
		ghost.material_override = mat
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(ghost)
		ghost.global_transform = mi.global_transform
		var tw := ghost.create_tween()
		tw.tween_property(mat, "albedo_color:a", 0.0, lifetime)
		tw.tween_callback(ghost.queue_free)
