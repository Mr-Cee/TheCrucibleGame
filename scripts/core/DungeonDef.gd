extends Resource
class_name DungeonDef

enum DungeonKind { BOSS, WAVES }

@export var enemy_sprite_path: String = "" # e.g. "res://assets/enemies/crucible_warden.png"


@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

# Each dungeon uses its own key type. We track counts by dungeon_id for now.
@export var key_display_name: String = "Dungeon Key"
@export var daily_key_cap: int = 5 # daily top-off cap (player can exceed via other sources)

# Reward formula: base + (level-1)*per_level
@export var reward_currency: String = ""   # e.g., "crucible_keys"
@export var reward_base: int = 0           # e.g., 100
@export var reward_per_level: int = 0      # e.g., 5

# Multi-reward support (optional). If empty, we fall back to reward_currency/base/per_level.
# Each entry:
# { "id": "crystals", "base":100, "per_level":5 }
# { "id": "skill_tickets", "base":10, "step_every":5, "step_amount":1 }
@export var reward_curves: Array[Dictionary] = []

# --- Dungeon behavior ---
@export var kind: int = DungeonKind.BOSS
# WAVES config (used when kind == WAVES)
@export var waves_count: int = 1
@export var waves_final_hp_mult: float = 1.15
@export var waves_final_atk_mult: float = 1.10
@export var waves_final_def_mult: float = 1.05


@export var time_limit_seconds: float = 0.0 # 0 = no timer

# --- Boss configuration (used when kind == BOSS) ---wwwwwwwwwwwwww
@export var enemy_name: String = "Boss"
@export var enemy_hp_mult_base: float = 10.0
@export var enemy_hp_mult_per_level: float = 0.75
@export var enemy_atk_mult_base: float = 4.0
@export var enemy_atk_mult_per_level: float = 0.25
@export var enemy_def_mult_base: float = 2.0
@export var enemy_def_mult_per_level: float = 0.10
@export var enemy_aps: float = 0.75
@export var enemy_damage_mult: float = 1.0 # 1.0 = normal, 0.0 = enemy deals no damage
