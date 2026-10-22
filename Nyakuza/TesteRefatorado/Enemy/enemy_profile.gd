extends Resource
class_name EnemyProfile
## Dados compartilhados, nunca modificados durante a partida. Duplique o .tres para uma nova classe.

@export var display_name: String = "Inimigo"
@export var max_health: float = 60.0
@export var move_speed: float = 3.6
@export var attack_range: float = 1.9
@export var attack_damage: float = 8.0
@export var attack_knockback: float = 5.0
@export var attack_windup: float = 0.45
@export var attack_active: float = 0.2
@export var attack_recover: float = 0.6
@export var attack_cooldown: float = 0.6
## Zero usa o golpe frontal; positivo usa area circular, com aviso no chao.
@export var area_attack_radius: float = 0.0
@export_range(0.1, 1.0) var stagger_scale: float = 1.0
@export_range(0.0, 1.0) var knockback_scale: float = 1.0
@export_category("Posture")
## Zero desliga postura. Dados do perfil sao copiados para cada inimigo.
@export var posture_max: float = 0.0
@export var posture_regen_delay: float = 3.0
@export var posture_regen_rate: float = 10.0
@export var posture_break_duration: float = 6.0
@export var tint: Color = Color(0.55, 0.1, 0.1)
