extends Resource
class_name SkillDef

enum SkillType { ACTIVE, PASSIVE }
enum Target { ENEMY, SELF }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

@export var type: int = SkillType.ACTIVE
@export var target: int = Target.ENEMY

# Active skill properties
@export var base_cooldown: float = 5.0
@export var base_power: float = 10.0
@export var power_per_level: float = 2.0

# scaling_stat: "atk", "str", "int", "agi", "def", "hp"
@export var scaling_stat: String = "atk"
@export var scaling_mult: float = 1.0
@export var can_crit: bool = true

# Passive skill properties
@export var passive_flat: Stats

func power(level: int) -> float:
	level = max(1, level)
	return base_power + power_per_level * float(level - 1)
