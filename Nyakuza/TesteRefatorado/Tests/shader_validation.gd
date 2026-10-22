extends SceneTree
func _initialize() -> void:
	var failed := false
	for path in ["Visuals/nyakuza_toon.gdshader", "Visuals/ink_outline.gdshader", "Musou/cutting_sphere.gdshader"]:
		var shader := load("res://TesteRefatorado/" + path) as Shader
		var parameters := shader.get_shader_uniform_list()
		print("SHADER %s: %d uniforms" % [path, parameters.size()])
		failed = failed or parameters.is_empty()
	quit(1 if failed else 0)
