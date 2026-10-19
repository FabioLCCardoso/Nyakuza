extends RefCounted
class_name DamagePopup
## Numero de dano flutuante. Uso: DamagePopup.spawn(get_tree(), posicao_mundo, "12")

static func spawn(tree : SceneTree, world_pos : Vector3, text : String, color : Color = Color(1.0, 0.85, 0.25), size : float = 1.0) -> void:
	var scene : Node = tree.current_scene
	if scene == null:
		return

	if tree.get_node_count_in_group("damage_popups") >= 48:
		return
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.0075 * size
	label.outline_size = 14
	label.outline_modulate = Color(0, 0, 0, 1)
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 10
	label.outline_render_priority = 9
	scene.add_child(label)
	label.add_to_group("damage_popups")

	var start := world_pos + Vector3(randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3))
	label.global_position = start
	label.scale = Vector3.ONE * 1.6

	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "global_position:y", start.y + 1.2, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.tween_property(label, "outline_modulate:a", 0.0, 0.3).set_delay(0.5)
	tw.chain().tween_callback(label.queue_free)
