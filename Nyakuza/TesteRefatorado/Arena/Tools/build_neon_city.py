"""Reconstrói NeonCityArena.tscn. Atenção: sobrescreve edições manuais nessa cena."""
from pathlib import Path
import math,random,json
out=Path(__file__).resolve().parents[1];random.seed(41)
resources=[];nodes=[];counter=0
ext='''[ext_resource type="FontFile" path="res://TesteRefatorado/Arena/Fonts/NotoSansJP.ttf" id="font"]
[ext_resource type="Shader" path="res://TesteRefatorado/Arena/neon_ground.gdshader" id="ground"]
[ext_resource type="Shader" path="res://TesteRefatorado/Arena/rising_sun_flag.gdshader" id="flag"]
[ext_resource type="Shader" path="res://TesteRefatorado/Arena/neon_sky.gdshader" id="sky"]
'''
def res(kind,props):
 global counter
 counter+=1;id='R'+str(counter);resources.append(f'[sub_resource type="{kind}" id="{id}"]\n{props}\n');return f'SubResource("{id}")'
def v(x):return 'Vector3('+', '.join(str(round(a,5)) for a in x)+')'
def node(name,kind,parent='.',props=''):
 nodes.append(f'[node name="{name}" type="{kind}"'+(f' parent="{parent}"' if parent is not None else '')+']\n'+props+'\n')
def mat(color,emission=0):
 return res('StandardMaterial3D',f'albedo_color = Color({color}, 1)\nroughness = 0.6'+(f'\nemission_enabled = true\nemission = Color({color}, 1)\nemission_energy_multiplier = {emission}' if emission else ''))
stone=mat('0.055, 0.025, 0.09'); facade=mat('0.11, 0.055, 0.18');dark=mat('0.018, 0.015, 0.04');red=mat('0.5, 0.025, 0.07'); cyan=mat('0.04, 0.7, 0.95',1.5);pink=mat('0.8, 0.025, 0.3',1.6); violet=mat('0.3, 0.05, 0.8',1.1);white=mat('0.6, 0.8, 0.85',0.5);yellow=mat('0.9, 0.5, 0.04',0.8)
ground=res('ShaderMaterial','shader = ExtResource("ground")');flag=res('ShaderMaterial','shader = ExtResource("flag")'); sky_mat=res('ShaderMaterial','shader = ExtResource("sky")');sky=res('Sky',f'sky_material = {sky_mat}')
env=res('Environment',f'background_mode = 2\nsky = {sky}\nambient_light_source = 3\nambient_light_color = Color(0.28, 0.21, 0.5, 1)\nambient_light_energy = 0.7\nreflected_light_source = 2\ntonemap_mode = 2\nglow_enabled = true\nglow_intensity = 0.55\nfog_enabled = true\nfog_density = 0.002\nfog_light_color = Color(0.17, 0.04, 0.25, 1)')
def box(name,pos,size,material,parent='.',collision=False):
 mesh=res('BoxMesh',f'size = {v(size)}\nmaterial = {material}')
 if collision:
  node(name,'StaticBody3D',parent,f'position = {v(pos)}\ncollision_layer = 1\ncollision_mask = 0');path=name if parent=='.' else parent+'/'+name
  node('Mesh','MeshInstance3D',path,f'mesh = {mesh}');shape=res('BoxShape3D',f'size = {v(size)}');node('Collision','CollisionShape3D',path,f'shape = {shape}')
 else:node(name,'MeshInstance3D',parent,f'position = {v(pos)}\nmesh = {mesh}')
def label(name,text,pos,rot,width=0.009,color='0.45, 0.95, 1'):
 node(name,'Label3D','Signs',f'position = {v(pos)}\nrotation = {v((0,rot,0))}\nfont = ExtResource("font")\ntext = {json.dumps(text,ensure_ascii=False)}\nfont_size = 110\npixel_size = {width}\nmodulate = Color({color}, 1)\noutline_size = 3\noutline_modulate = Color(0.04, 0.01, 0.08, 1)\nno_depth_test = false')
def batch(name,size,material,positions):
 mesh=res('BoxMesh',f'size = {v(size)}\nmaterial = {material}');buf=[]
 for x,y,z in positions:buf.extend([1,0,0,x,0,1,0,y,0,0,1,z])
 mm=res('MultiMesh',f'transform_format = 1\ninstance_count = {len(positions)}\nmesh = {mesh}\nbuffer = PackedFloat32Array('+', '.join(str(round(a,4)) for a in buf)+')');node(name,'MultiMeshInstance3D','Details',f'multimesh = {mm}\ncast_shadow = 0')
node('NeonCityArena','Node3D',None)
for group in ['Buildings','Signs','Torii','Flags','Details','Props']:node(group,'Node3D')
node('WorldEnvironment','WorldEnvironment',props=f'environment = {env}')
node('MoonKey','DirectionalLight3D',props='rotation_degrees = Vector3(-48, -25, 0)\nlight_color = Color(0.58, 0.68, 1, 1)\nlight_energy = 1.2\nshadow_enabled = true\ndirectional_shadow_max_distance = 70.0')
box('Ground',(0,0,0),(48,1,60),ground,collision=True)
for side in [-1,1]:
 box('Sidewalk'+str(side),(side*19.5,.56,0),(3,.12,52),stone)
 box('BoundaryX'+str(side),(side*21.8,5,0),(1,10,54),facade,collision=True)
 box('BoundaryZ'+str(side),(0,5,side*27),(44,10,1),facade,collision=True)
win=[[],[],[],[]]
for side in [-1,1]:
 for i,z in enumerate([-22,-13,-4,5,14,23]):
  h=random.choice([12,15,18,21]); x=side*24
  box(f'Tower{side}_{i}',(x,h/2+.5,z),(5,h,8),facade,'Buildings')
  box(f'Roof{side}_{i}',(x,h+.6,z),(5.2,.12,8.2),pink if i%2 else cyan,'Buildings')
  for y in range(6,h,3):
   for dz in [-2.4,0,2.4]:win[i%2].append((side*21.43,y,z+dz))
  box(f'Shop{side}_{i}',(side*21.23,3.3,z),(.22,1.4,7.2),dark,'Signs')
  box(f'ShopLine{side}_{i}',(side*21.04,2.5,z),(.08,.08,7.1),cyan if i%2 else pink,'Signs')
  text=['ラーメン','カラオケ','ゲームセンター','ネコ組','夜の街','NEKO CLUB'][i]
  label(f'ShopText{side}_{i}',text,(side*21.05,3.3,z),-side*math.pi/2,.007)
  box(f'Blade{side}_{i}',(side*20.5,8,z+3.6),(.4,5,1.6),pink if i%2 else violet,'Signs')
  label(f'BladeText{side}_{i}','ネ\nオ\nン',(side*20.26,8,z+3.6),-side*math.pi/2,.007,'1, 0.85, 0.95')
for side in [-1,1]:
 for i,x in enumerate(range(-18,19,6)):
  h=random.choice([14,18,22]);box(f'EndTower{side}_{i}',(x,h/2+.5,side*30),(5,h,5),facade,'Buildings')
  for y in range(7,h,3):
   for dx in [-1.4,1.4]:win[2+i%2].append((x+dx,y,side*27.43))
 box(f'Garage{side}',(0,3,side*26.4),(12,5,.1),dark,'Buildings')
 label(f'Club{side}','NEKO DISTRICT',(0,8,side*26.4),math.pi if side==1 else 0,.011,'1, 0.35, 0.7')
 for x in [-5.5,5.5]:box(f'Pillar{side}_{x}',(x,3.6,side*22),(.65,6.2,.65),red,'Torii',True)
 box(f'Beam{side}',(0,5.5,side*22),(12,.4,.6),red,'Torii')
 box(f'Cap{side}',(0,6.9,side*22),(14,.4,1),dark,'Torii')
 box(f'Top{side}',(0,7.15,side*22),(13.5,.15,.9),red,'Torii')
 for x in [-17,17]:
  key=f'{side}_{x}';box('FlagPole'+key,(x,4,side*17),(.12,7,.12),stone,'Flags',True)
  plane=res('PlaneMesh',f'size = Vector2(2.5, 1.6)\nsubdivide_width = 20\nsubdivide_depth = 12\nmaterial = {flag}')
  node('Flag'+key,'MeshInstance3D','Flags',f'position = {v((x+1.3,6.4,side*17))}\nrotation_degrees = Vector3(90, 0, 0)\nmesh = {plane}\ncast_shadow = 0')
for i,positions in enumerate(win):batch('Windows'+str(i),(.08,1.15,1.1) if i<2 else (1.1,1.15,.08),cyan if i%2==0 else pink,positions)
batch('Crosswalk',(1.1,.015,3),white,[(x,.515,z) for z in [-19,19] for x in range(-7,8,2)])
batch('RoadLines',(.12,.016,1.4),yellow,[(x,.516,z) for x in [-8,8] for z in range(-15,16,3)])
batch('PlazaDots',(.35,.018,.35),violet,[(x,.518,z) for x in [-13,13] for z in range(-15,16,3)])
batch('GarageSlats',(11.5,.035,.08),stone,[(0,y*.3+.7,z) for z in [-26.3,26.3] for y in range(15)])
for i,(x,z) in enumerate([(-19,-12),(19,-12),(-19,12),(19,12)]):
 box('LampPole'+str(i),(x,2.7,z),(.16,4.4,.16),stone,'Props',True)
 box('Lamp'+str(i),(x,5,z),(.65,.25,.65),cyan if i%2 else pink,'Props')
 node('NeonLight'+str(i),'OmniLight3D','Props',f'position = {v((x,4.8,z))}\nlight_color = Color('+('0.1, 0.5, 1, 1)' if i%2 else '1, 0.04, 0.3, 1)')+'\nlight_energy = 3.0\nomni_range = 10.0\nshadow_enabled = false')
 box('Vending'+str(i),(x,1.6,z+2),(1,2.2,.8),dark,'Props',True)
 box('VendingGlow'+str(i),(x,1.8,z+2.42),(.75,1.2,.03),cyan,'Props')
text='[gd_scene format=3]\n\n'+ext+'\n'+'\n'.join(resources)+'\n'+'\n'.join(nodes)
(out/'NeonCityArena.tscn').write_text(text)
print('Arena:',len(nodes),'nodes;',sum(len(p) for p in win)+16+22+22+30,'batched details')
