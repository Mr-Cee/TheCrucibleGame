extends Resource
class_name DungeonDef

enum DungeonKind { BOSS, WAVES }

@export var enemy_sprite_path: String = "" # e.g. "res://assets/enemies/crucible_warden.png"


@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

# Each dungeon uses its own key type. We track counts by dungeon_id for now.
@export var key_display_name: String = "Dungeon Key"

# Reward formula: base + (level-1)*per_level
@export var reward_currency: String = ""   # e.g., "crucible_keys"
@export var reward_base: int = 0           # e.g., 100
@export var reward_per_level: int = 0      # e.g., 5

# --- Dungeon behavior ---
@export var kind: int = DungeonKind.BOSS

@export var time_limit_seconds: float = 0.0 # 0 = no timer

# --- Boss configuration (used when kind == BOSS) ---
@export var enemy_name: String = "Boss"
@export var enemy_hp_mult_base: float = 10.0
@export var enemy_hp_mult_per_level: float = 0.75
@export var enemy_atk_mult_base: float = 4.0
@export var enemy_atk_mult_per_level: float = 0.25
@export var enemy_def_mult_base: float = 2.0
@export var enemy_def_mult_per_level: float = 0.10
@export var enemy_aps: float = 0.75
@export var enemy_damage_mult: float = 1.0 # 1.0 = normal, 0.0 = enemy deals no damage
