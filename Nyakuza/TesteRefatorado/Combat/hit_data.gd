extends RefCounted
class_name HitData
## Pacote de dados de UM golpe. Quem bate monta um HitData e entrega para a
## CombatHurtBox de quem apanhou. Quem apanha decide o que fazer com ele.

## Camadas de fisica usadas SOMENTE pelas Area3D de combate (corpos continuam na camada 1).
## Camada 4 = hurtbox do player, camada 5 = hurtbox dos inimigos.
const LAYER_PLAYER_HURT : int = 1 << 3   # = 8
const LAYER_ENEMY_HURT : int = 1 << 4    # = 16

var attacker : Node3D
var damage : float = 10.0
var knockback : float = 4.0        # empurrao horizontal (m/s)
var knockup : float = 0.0          # lancamento vertical (m/s). > 0 = launcher
var stagger_duration : float = 0.4 # tempo de "stun" (s)
var direction : Vector3 = Vector3.FORWARD  # horizontal, de quem bateu -> quem apanhou
var hit_stop : float = 0.0         # congelada de tela (s). Usado so pelo player
var slam : bool = false            # finisher aereo: joga o alvo no chao (impacto + onda de choque)
var is_heavy: bool = false
var posture_damage: float = 0.0
var grants_musou: bool = false
var show_damage_popup: bool = true
var affects_air_reaction: bool = true
var unblockable : bool = false     # a guarda nao segura (para golpes especiais de boss)
