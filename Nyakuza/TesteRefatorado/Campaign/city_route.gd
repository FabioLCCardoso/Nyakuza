extends Node3D
class_name CityRoute
## Os quatro distritos reutilizam o modulo original. Geracao ocorre ao executar.
const TITLES = ["RUA DOS LETREIROS", "DISTRITO ARCADE", "PÁTIO DOS TORII", "FORTALEZA ECLIPSE"]
const COLORS = [Color(0.1, 0.8, 1), Color(1, 0.12, 0.55), Color(1, 0.45, 0.12), Color(0.75, 0.25, 1)]
@export_range(68.0, 120.0, 1.0) var district_spacing: float = 68.0
@export var healing_crate_scene: PackedScene = preload("res://TesteRefatorado/Pickups/BreakableCrate.tscn")
@export var crate_positions: Array[Vector3] = [Vector3(-8, 0.5, 12), Vector3(8, 0.5, -12)]
@export var arena_module: PackedScene = preload("res://TesteRefatorado/Arena/NeonCityArena.tscn")
var districts: Array[Node3D] = []
var gates: Array[Array] = []
var entries: Array[Area3D] = []
var spawn_sets: Array[Node3D] = []
var exit_labels: Array[Label3D] = []

func center(index: int) -> Vector3:
	return Vector3(0, 0, -district_spacing * index)

func _ready() -> void:
	for i in 4:
		var district := arena_module.instantiate() as Node3D
		district.name = "District%d" % (i + 1)
		district.position = center(i)
		add_child(district)
		districts.append(district)
		if i > 0:
			for key in ["WorldEnvironment", "MoonKey"]:
				var node := district.get_node_or_null(key)
				if node != null: node.free()
			_open_wall(district, 1)
		if i < 3: _open_wall(district, -1)
		for geometry in district.find_children("*", "GeometryInstance3D", true, false):
			geometry.visibility_range_end = 100.0
		for sign_node in district.find_children("*", "Label3D", true, false):
			sign_node.modulate = COLORS[i]
		_decorate(district, i)
		if healing_crate_scene != null:
			for crate_pos in crate_positions:
				var crate := healing_crate_scene.instantiate() as Node3D
				crate.position = crate_pos
				district.add_child(crate)
		var markers := Node3D.new()
		markers.name = "SpawnPoints"
		district.add_child(markers)
		spawn_sets.append(markers)
		for pos in [Vector3(-12, 0.6, 10), Vector3(12, 0.6, 10), Vector3(-12, 0.6, -10), Vector3(12, 0.6, -10), Vector3(-7, 0.6, -18), Vector3(7, 0.6, -18)]:
			var marker := Marker3D.new()
			marker.position = pos
			markers.add_child(marker)
		if i > 0:
			var entry := Area3D.new()
			entry.name = "EnterDistrict%d" % (i + 1)
			entry.position = center(i) + Vector3(0, 12, 20)
			entry.collision_layer = 0
			entry.collision_mask = 2
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(44, 24, 8)
			shape.shape = box
			entry.add_child(shape)
			add_child(entry)
			entries.append(entry)
	for i in 3:
		var z: float = -district_spacing * (i + 0.5)
		var length: float = district_spacing - 52.0
		_box(self, "Passage", Vector3(0, 0, z), Vector3(12, 1, length), Color(0.06, 0.025, 0.12), true)
		for side in [-1, 1]:
			_box(self, "PassageWall", Vector3(side * 6.5, 7, z), Vector3(1, 14, length), Color(0.04, 0.02, 0.09), true)
			_box(self, "Guide", Vector3(side * 5.8, 0.56, z), Vector3(0.15, 0.1, length - 1), COLORS[i + 1], false, true)
		var pair: Array = []
		for gate_z in [-district_spacing * i - 27, -district_spacing * (i + 1) + 27]:
			var gate := _box(self, "Gate", Vector3(0, 12, gate_z), Vector3(12, 24, 0.65), COLORS[i], true, true)
			var mesh := gate.get_node("Mesh") as MeshInstance3D
			(mesh.mesh as BoxMesh).size = Vector3(12, 5, 0.65)
			mesh.position.y = -9.0
			pair.append(gate)
		gates.append(pair)
		var label := Label3D.new()
		label.position = center(i) + Vector3(0, 7, -25.5)
		label.text = "BLOQUEADO • CONCLUA AS ONDAS"
		label.font_size = 56
		label.pixel_size = 0.009
		label.modulate = COLORS[i]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
		exit_labels.append(label)
	activate_district(0)

func _open_wall(district: Node3D, side: int) -> void:
	var boundary := district.get_node_or_null("BoundaryZ%d" % side)
	if boundary != null: boundary.free()
	for x in [-14, 14]:
		_box(district, "PortalWall", Vector3(x, 5, side * 27), Vector3(16, 10, 1), Color(0.035, 0.02, 0.07), true)
	for key in ["Garage%d" % side, "EndTower%d_2" % side, "EndTower%d_3" % side, "EndTower%d_4" % side]:
		var node := district.get_node_or_null("Buildings/" + key)
		if node != null: node.free()
	var slats := district.get_node_or_null("Details/GarageSlats") as Node3D
	if slats != null: slats.hide()

func _decorate(district: Node3D, index: int) -> void:
	var title := Label3D.new()
	title.position = Vector3(0, 9, 24)
	title.rotation.y = PI
	title.text = "%02d / %s" % [index + 1, TITLES[index]]
	title.font_size = 64
	title.pixel_size = 0.012
	title.modulate = COLORS[index]
	district.add_child(title)
	if index == 1:
		for x in [-18, 18]:
			for z in [-8, 0, 8]:
				_box(district, "Arcade", Vector3(x, 1.5, z), Vector3(1.5, 2, 1.3), Color(0.07, 0.025, 0.12), true)
				_box(district, "Screen", Vector3(x, 1.9, z + 0.67), Vector3(1.1, 0.8, 0.05), COLORS[index], false, true)
	if index == 2:
		for z in [-12, 0, 12]:
			for x in [-10, 10]:
				_box(district, "ToriiPole", Vector3(x, 3.5, z), Vector3(0.7, 6, 0.7), Color(0.7, 0.04, 0.08), true)
			_box(district, "ToriiBeam", Vector3(0, 6.6, z), Vector3(22, 0.5, 1), Color(0.8, 0.06, 0.1), false)
	if index == 3:
		var seal := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 9
		cylinder.bottom_radius = 9
		cylinder.height = 0.03
		seal.mesh = cylinder
		seal.position.y = 0.52
		seal.material_override = _material(Color(0.15, 0.035, 0.25))
		district.add_child(seal)
		for x in [-10, 10]:
			_box(district, "Obelisk", Vector3(x, 4, -14), Vector3(1.8, 7, 1.8), Color(0.025, 0.015, 0.055), true)
			_box(district, "Crest", Vector3(x, 5, -13), Vector3(0.7, 3, 0.1), COLORS[index], false, true)

func _material(color: Color, emission: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = emission
	material.emission = color
	material.emission_energy_multiplier = 1.25
	return material

func _box(parent: Node3D, label: String, pos: Vector3, size: Vector3, color: Color, solid: bool, emission: bool = false) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	node.name = label
	node.position = pos
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color, emission)
	node.add_child(mesh)
	if solid:
		(node as StaticBody3D).collision_layer = 1
		(node as StaticBody3D).collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		node.add_child(collision)
	parent.add_child(node)
	return node

func set_passage(index: int, open: bool) -> void:
	for gate in gates[index]:
		gate.set_deferred("collision_layer", 0 if open else 1)
		gate.get_node("Mesh").visible = not open
	exit_labels[index].text = "ÁREA LIBERADA • SIGA EM FRENTE ↓" if open else "BLOQUEADO • CONCLUA AS ONDAS"

func activate_district(index: int) -> void:
	for i in districts.size():
		for light in districts[i].find_children("*", "OmniLight3D", true, false):
			light.visible = i == index
