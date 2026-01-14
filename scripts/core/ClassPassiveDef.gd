extends Resource
class_name ClassPassiveDef

# A class passive is a progression perk tied to a specific node in the class tree.
# Each class node provides 5 passives:
#   Slot 1: Signature mechanic (class-altering)
#   Slots 2-5: Stat bonuses

@export var id: String = ""                 # unique passive id
@export var class_def_id: String = ""       # owning class (e.g. "knight")
@export var slot: int = 1                   # 1..5 (1 = signature)
@export var unlock_level: int = 1           # absolute player level required

@export var display_name: String = ""       # UI label
@export var description: String = ""        # UI text

@export var cp_gain: int = 0                # CP awarded when unlocked

# For stat passives (slots 2-5). Null for signatures.
@export var flat_stats: Stats

# For signature passives (slot 1). Empty for stat passives.
# This is intentionally data-driven; implement behavior in battle using effect_key + params.
@export var effect_key: String = ""         # e.g. "shield_on_spawn"
@export var params: Dictionary = {}

func is_signature() -> bool:
	return slot == 1 and effect_key != ""

func is_stat_passive() -> bool:
	return slot >= 2 and flat_stats != null
