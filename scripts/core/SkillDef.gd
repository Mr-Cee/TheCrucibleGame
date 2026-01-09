extends Resource
class_name SkillDef

enum SkillType { ACTIVE, PASSIVE }

# For now everything in the catalog is ACTIVE. We'll use PASSIVE later.
@export var type: int = SkillType.ACTIVE

# Active skill definition. Universal across classes.

enum EffectType {
	DAMAGE,            # Instant single-hit damage
	MULTI_HIT,         # Instant multi-hit damage (hits property)
	DOT,               # Applies a DoT to the enemy (secondary_power = DPS multiplier, duration)
	HEAL,              # Instant heal (power is % of player max HP)
	HOT,               # Heal-over-time (secondary_power = HPS % of player max HP, duration)
	SHIELD,            # Instant shield (power is % of player max HP)
	STUN,              # Stuns enemy (duration), may have minor damage via power
	SLOW,              # Slows enemy attacks (magnitude as slow %, duration), may have minor damage via power
	WEAKEN,            # Reduces enemy damage (magnitude as %, duration)
	ARMOR_BREAK,       # Reduces enemy defense (magnitude as %, duration)
	VULNERABILITY,     # Increases enemy damage taken (magnitude as %, duration)
	BUFF_ATK,          # Increases player ATK (magnitude as %, duration)
	BUFF_DEF,          # Increases player DEF (magnitude as %, duration)
	BUFF_APS,          # Increases player APS (magnitude as %, duration)
	BUFF_AVOID,        # Adds player avoidance percent-points (magnitude in pp, duration)
	BUFF_CRIT,         # Adds player crit percent-points (magnitude in pp, duration)
	COOLDOWN_REDUCE_OTHERS, # Reduces other equipped skill cooldowns (power seconds)
	LIFE_DRAIN,        # Damage + heal for a portion of damage (magnitude as % heal of dealt)
}

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""

@export var cooldown: float = 12.0 # seconds (before INT reduction)
@export var effect: EffectType = EffectType.DAMAGE

# Meaning depends on effect:
# - DAMAGE/MULTI_HIT: damage multiplier vs player ATK
# - STUN/SLOW: damage multiplier vs player ATK (optional, can be 0)
# - HEAL/SHIELD: % of player max HP (e.g., 0.18 = 18%)
# - COOLDOWN_REDUCE_OTHERS: seconds to reduce
@export var power: float = 1.0

# For MULTI_HIT
@export var hits: int = 1

# For timed effects (DOT/HOT/STUN/SLOW/DEBUFF/BUFF)
@export var duration: float = 0.0

# For magnitude-based timed effects:
# - SLOW/WEAKEN/ARMOR_BREAK/VULNERABILITY/BUFF_*: percent (0.25 = 25%) OR pp for BUFF_AVOID/BUFF_CRIT
# - LIFE_DRAIN: heal percent of dealt damage (0.30 = 30%)
@export var magnitude: float = 0.0

# Secondary meaning:
# - DOT: DPS multiplier vs player ATK
# - HOT: HPS percent vs player max HP
@export var secondary_power: float = 0.0

func level_multiplier(skill_level: int) -> float:
	# Simple scaling: +15% per level above 1.
	return 1.0 + 0.15 * float(maxi(0, skill_level - 1))

func effective_cooldown(int_stat: float) -> float:
	# Design note: game doc states INT reduces cooldowns for all classes.
	# This gives up to 30% cooldown reduction at high INT.
	var cdr: float = clampf(float(int_stat) * 0.001, 0.0, 0.30)
	return cooldown * (1.0 - cdr)
