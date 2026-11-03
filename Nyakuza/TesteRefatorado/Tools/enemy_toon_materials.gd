extends RefCounted
## Conversão offline por superfície. Não altera o GLB nem compartilha texturas
## entre espécies. Rodar pelo build_enemy_assets.gd sobrescreve os derivados.
static func apply(model: Node3D, kind: String) -> void:
 var surface_index := 0
 for mesh in model.find_children("*", "MeshInstance3D", true, false):
  var instance := mesh as MeshInstance3D
  for surface in instance.mesh.get_surface_count():
   var original := instance.get_active_material(surface) as BaseMaterial3D
   assert(original != null, "Material de origem não suportado: " + kind)
   var toon := load("res://TesteRefatorado/Visuals/toon_balanced.tres").duplicate(true) as ShaderMaterial
   toon.resource_name = kind + " Textured Toon"
   toon.set_shader_parameter("albedo_texture", original.albedo_texture)
   toon.set_shader_parameter("base_color", original.albedo_color)
   toon.set_shader_parameter("uv_scale", original.uv1_scale)
   toon.set_shader_parameter("uv_offset", original.uv1_offset)
   # Contraste gráfico sem esmagar as áreas escuras pintadas na textura.
   toon.set_shader_parameter("shadow_color", Color(.30, .25, .40))
   toon.set_shader_parameter("mid_color", Color(.72, .66, .80))
   toon.set_shader_parameter("saturation", 1.04)
   toon.set_shader_parameter("ambient_floor", .22)
   toon.set_shader_parameter("rim_strength", .12)
   toon.set_shader_parameter("hatch_strength", .025)
   # A malha Meshy tem faces/costuras que expõem a casca expandida.
   # Acentuação interna das bordas evita artefatos e uma segunda passagem.
   toon.next_pass = null
   toon.set_shader_parameter("ink_strength", .7)
   var suffix := "" if surface_index == 0 else "_" + str(surface_index)
   var path := "res://TesteRefatorado/Enemy/Materials/" + kind + "Toon" + suffix + ".tres"
   assert(ResourceSaver.save(toon, path) == OK, "Falha salvando " + path)
   instance.set_surface_override_material(surface, load(path))
   surface_index += 1
