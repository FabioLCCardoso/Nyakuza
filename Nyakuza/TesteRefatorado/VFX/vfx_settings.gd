extends Resource
class_name CombatVFXSettings
@export var blood_enabled: bool = true
@export_range(0.0,2.0) var blood_intensity: float = 1.0
@export var blood_color: Color = Color(.55,.015,.035)
@export var blood_interval: float = .12
@export var blood_mark_lifetime: float = 5.0
@export var ground_enabled: bool = true
@export var ground_mark_lifetime: float = 6.0
@export var max_bursts: int = 24
@export var max_marks: int = 32
