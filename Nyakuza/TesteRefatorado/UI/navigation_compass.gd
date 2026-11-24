extends Control
class_name NavigationCompass
## Norte = -Z. A faixa acompanha a câmera, não o giro do personagem.
@export_range(45,120) var half_view_degrees: float = 75.0
var player: Node3D
var destination: Vector3
var has_destination := false
var heading := 0.0
var target_angle := 0.0
var distance := 0.0
var marker_color := Color(.35,.9,1)
func _ready() -> void:
	custom_minimum_size=Vector2(0,34)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	clip_contents=true
func clear_destination() -> void:
	has_destination=false
	queue_redraw()
func set_destination(point: Vector3, color: Color=Color(.35,.9,1)) -> void:
	destination=point;marker_color=color;has_destination=true
func relative_bearing(direction: Vector3) -> float:
	return wrapf(atan2(direction.x,-direction.z)-heading,-PI,PI)
func _process(_delta: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	if is_instance_valid(camera):
		var forward: Vector3=-camera.global_basis.z
		if Vector2(forward.x,forward.z).length_squared()>.0001:
			heading=atan2(forward.x,-forward.z)
	if is_instance_valid(player) and has_destination:
		var offset:=destination-player.global_position;offset.y=0
		distance=offset.length()
		target_angle=relative_bearing(offset) if distance>.1 else 0.0
	queue_redraw()
func _draw() -> void:
	var font:=ThemeDB.fallback_font
	var half_width:=maxf(1,size.x*.5-14)
	var center:=size.x*.5
	var limit:=deg_to_rad(half_view_degrees)
	draw_line(Vector2(14,27),Vector2(size.x-14,27),Color(.6,.8,.9,.28),1)
	for step in 24:
		var angle:=wrapf(float(step)*TAU/24-heading,-PI,PI)
		if absf(angle)>limit:continue
		var x:=center+angle/limit*half_width
		var opacity:=lerpf(1,.25,absf(angle)/limit)
		var major:=step%6==0
		draw_line(Vector2(x,23 if major else 25),Vector2(x,28),Color(.8,.88,.95,opacity),1)
		if major:
			var label: String=["N","L","S","O"][step/6]
			var width:=font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
			draw_string(font,Vector2(x-width*.5,19),label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(.9,.94,1,opacity))
	draw_colored_polygon(PackedVector2Array([Vector2(center-3,1),Vector2(center+3,1),Vector2(center,5)]),Color(.9,.95,1,.85))
	if not has_destination:return
	var marker_x:=center+clampf(target_angle/limit,-1,1)*half_width
	if absf(target_angle)>limit:
		var side:=signf(target_angle)
		draw_colored_polygon(PackedVector2Array([Vector2(marker_x+side*5,27),Vector2(marker_x-side*3,22),Vector2(marker_x-side*3,32)]),marker_color)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(marker_x,22),Vector2(marker_x+4,27),Vector2(marker_x,32),Vector2(marker_x-4,27)]),marker_color)
