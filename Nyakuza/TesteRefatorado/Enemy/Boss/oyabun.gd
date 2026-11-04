extends Enemy
class_name OyabunBoss
signal phase_changed(phase: int)
var boss_phase: int = 1

func _ready() -> void:
	super._ready()
	health.health_changed.connect(_health_changed)

func _health_changed(current: float, maximum: float) -> void:
	if current > 0 and current <= maximum * 0.5 and boss_phase == 1:
		boss_phase = 2
		phase_changed.emit(2)

func _start_attack() -> void:
	# Alteracao somente no proximo golpe: nao encurta um aviso ja iniciado.
	if boss_phase == 2:
		attack_windup = 0.95
		attack_damage = 34
		attack_cooldown = 0.8
		area_attack_radius = 3.0
	else:
		attack_windup = 1.45
		attack_damage = 28
		attack_cooldown = 1.35
		area_attack_radius = 2.4
	if area_indicator != null:
		var ring := area_indicator.mesh as TorusMesh
		var radius := area_attack_radius / maxf(absf(global_basis.get_scale().x), 0.01)
		ring.inner_radius = radius - 0.08
		ring.outer_radius = radius
	super._start_attack()
