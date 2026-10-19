extends Area3D
class_name CombatHurtBox
## Area3D que "recebe" golpes. Nao aplica dano sozinha: apenas repassa o HitData
## pelo sinal hit_received, e o dono (Enemy, PlayerCombat) decide a reacao.

signal hit_received(hit : HitData)

enum Team { PLAYER, ENEMY }
@export var team : Team = Team.ENEMY

func _ready():
	# Camadas configuradas aqui para ficarem todas num lugar so (ver HitData).
	collision_layer = HitData.LAYER_PLAYER_HURT if team == Team.PLAYER else HitData.LAYER_ENEMY_HURT
	collision_mask = 0
	monitoring = false
	monitorable = true

var can_receive_hits: bool = true

func receive_hit(hit : HitData) -> void:
	if can_receive_hits:
		hit_received.emit(hit)
