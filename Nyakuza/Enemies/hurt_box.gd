extends Area3D

@export var health := 50
@onready var damage_indicator: Node3D = $DamageIndicator



func take_damage(damage: int):
	damage_indicator.create_indicator_label(-damage)
	
	health -= damage
	
	health = clamp(health, 0, 50)
