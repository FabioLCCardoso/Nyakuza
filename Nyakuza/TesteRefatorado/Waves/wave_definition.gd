extends Resource
class_name WaveDefinition

@export var title: String = "Horda"
@export_range(0, 200) var penguins: int = 6
@export_range(0, 200) var foxes: int = 0
@export_range(0, 200) var red_pandas: int = 0
@export_range(0.05, 5.0) var spawn_interval: float = 0.3
@export_range(0.0, 30.0) var rest_time: float = 4.0

func get_total() -> int:
	return penguins + foxes + red_pandas
