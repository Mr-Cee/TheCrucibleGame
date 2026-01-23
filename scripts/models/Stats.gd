extends Resource
class_name Stats

# ------------------------------------------------------------------------------------
# Conventions (recommended):
# - "Chance/Rate/RES/Bonus/Boost" fields are expressed as percent-points (0..100),
#   unless otherwise stated.
# - "Mult" fields are additive % modifiers to a base multiplier of 1.0.
#   Example: basic_atk_mult = 20 means basic attacks deal 1.20x.
# - Base attributes (hp/atk/def/atk_spd) are raw values.
# ------------------------------------------------------------------------------------

# -----------------------
# Basic Attributes
# -----------------------
@export var hp: float = 0.0
@export var atk: float = 0.0
@export var def: float = 0.0
@export var atk_spd: float = 0.0

# -----------------------
# Existing Advanced (legacy names)
# -----------------------
@export var block: float = 0.0                # percent-points
@export var avoidance: float = 0.0            # percent-points (treat as "Evasion" going forward)

@export var crit_chance: float = 0.0          # percent-points (Crit Rate)
@export var crit_dmg: float = 0.0             # percent bonus (Crit DMG)

@export var combo_chance: float = 0.0         # percent-points (Combo)
@export var combo_dmg: float = 0.0            # percent bonus (treat as "Combo Multiplier bonus")

@export var counter_chance: float = 0.0       # percent-points (Counterstrike)
@export var counter_dmg: float = 0.0          # percent bonus (treat as "Counter Multiplier bonus")

@export var regen: float = 0.0                # flat HP per second (Regeneration)

# -----------------------
# New Advanced Attributes (requested)
# -----------------------
@export var crit_res: float = 0.0             # percent-points, subtract from attacker crit chance

@export var ignore_combo: float = 0.0         # percent-points, chance to ignore being combo-hit
@export var ignore_counter: float = 0.0       # percent-points, chance to ignore counter procs against you

@export var stun_chance: float = 0.0          # percent-points, chance to stun on hit/skill
@export var ignore_stun: float = 0.0          # percent-points, resistance vs stun chance

@export var ignore_evasion: float = 0.0       # percent-points, chance to bypass enemy evasion/avoidance

@export var basic_atk_mult: float = 0.0       # percent bonus; 20 => 1.20x basic damage
@export var basic_atk_dmg_res: float = 0.0    # percent-points reduction vs incoming basic attacks

@export var combo_dmg_res: float = 0.0        # percent-points reduction vs incoming combo damage
@export var counter_dmg_res: float = 0.0      # percent-points reduction vs incoming counter damage

@export var skill_crit_chance: float = 0.0    # percent-points (Skill Crit)
@export var skill_crit_dmg: float = 0.0       # percent bonus (Skill Crit DMG)
@export var skill_dmg_res: float = 0.0        # percent-points reduction vs incoming skill damage

@export var boss_dmg: float = 0.0             # percent bonus vs bosses
@export var boss_dmg_res: float = 0.0         # percent-points reduction vs boss damage

@export var pet_dmg: float = 0.0              # percent bonus (future)
@export var pet_dmg_res: float = 0.0          # percent-points reduction vs pet damage (future)

@export var hp_bonus_pct: float = 0.0         # percent bonus to HP
@export var atk_bonus_pct: float = 0.0        # percent bonus to ATK
@export var def_bonus_pct: float = 0.0        # percent bonus to DEF
@export var atk_spd_bonus_pct: float = 0.0    # percent bonus to ATK SPD

@export var final_dmg_boost_pct: float = 0.0  # percent bonus to ALL outgoing damage at final step
@export var final_dmg_res_pct: float = 0.0    # percent-points reduction to ALL incoming damage at final step

# ====================================================================================

func add(other: Stats) -> void:
	# Basic
	hp += other.hp
	atk += other.atk
	def += other.def
	atk_spd += other.atk_spd

	# Existing advanced
	block += other.block
	avoidance += other.avoidance
	crit_chance += other.crit_chance
	crit_dmg += other.crit_dmg
	combo_chance += other.combo_chance
	combo_dmg += other.combo_dmg
	counter_chance += other.counter_chance
	counter_dmg += other.counter_dmg
	regen += other.regen

	# New advanced
	crit_res += other.crit_res
	ignore_combo += other.ignore_combo
	ignore_counter += other.ignore_counter
	stun_chance += other.stun_chance
	ignore_stun += other.ignore_stun
	ignore_evasion += other.ignore_evasion

	basic_atk_mult += other.basic_atk_mult
	basic_atk_dmg_res += other.basic_atk_dmg_res
	combo_dmg_res += other.combo_dmg_res
	counter_dmg_res += other.counter_dmg_res

	skill_crit_chance += other.skill_crit_chance
	skill_crit_dmg += other.skill_crit_dmg
	skill_dmg_res += other.skill_dmg_res

	boss_dmg += other.boss_dmg
	boss_dmg_res += other.boss_dmg_res

	pet_dmg += other.pet_dmg
	pet_dmg_res += other.pet_dmg_res

	hp_bonus_pct += other.hp_bonus_pct
	atk_bonus_pct += other.atk_bonus_pct
	def_bonus_pct += other.def_bonus_pct
	atk_spd_bonus_pct += other.atk_spd_bonus_pct

	final_dmg_boost_pct += other.final_dmg_boost_pct
	final_dmg_res_pct += other.final_dmg_res_pct


func scaled(mult: float) -> Stats:
	# Keeps current behavior: scales everything (including % fields), consistent with your existing file.
	var s := Stats.new()

	s.hp = hp * mult
	s.atk = atk * mult
	s.def = def * mult
	s.atk_spd = atk_spd * mult

	s.block = block * mult
	s.avoidance = avoidance * mult
	s.crit_chance = crit_chance * mult
	s.crit_dmg = crit_dmg * mult
	s.combo_chance = combo_chance * mult
	s.combo_dmg = combo_dmg * mult
	s.counter_chance = counter_chance * mult
	s.counter_dmg = counter_dmg * mult
	s.regen = regen * mult

	s.crit_res = crit_res * mult
	s.ignore_combo = ignore_combo * mult
	s.ignore_counter = ignore_counter * mult
	s.stun_chance = stun_chance * mult
	s.ignore_stun = ignore_stun * mult
	s.ignore_evasion = ignore_evasion * mult

	s.basic_atk_mult = basic_atk_mult * mult
	s.basic_atk_dmg_res = basic_atk_dmg_res * mult
	s.combo_dmg_res = combo_dmg_res * mult
	s.counter_dmg_res = counter_dmg_res * mult

	s.skill_crit_chance = skill_crit_chance * mult
	s.skill_crit_dmg = skill_crit_dmg * mult
	s.skill_dmg_res = skill_dmg_res * mult

	s.boss_dmg = boss_dmg * mult
	s.boss_dmg_res = boss_dmg_res * mult

	s.pet_dmg = pet_dmg * mult
	s.pet_dmg_res = pet_dmg_res * mult

	s.hp_bonus_pct = hp_bonus_pct * mult
	s.atk_bonus_pct = atk_bonus_pct * mult
	s.def_bonus_pct = def_bonus_pct * mult
	s.atk_spd_bonus_pct = atk_spd_bonus_pct * mult

	s.final_dmg_boost_pct = final_dmg_boost_pct * mult
	s.final_dmg_res_pct = final_dmg_res_pct * mult

	return s


# -----------------------
# Final Attribute helpers
# -----------------------
func final_hp_value() -> float:
	return hp * (1.0 + (hp_bonus_pct / 100.0))

func final_atk_value() -> float:
	return atk * (1.0 + (atk_bonus_pct / 100.0))

func final_def_value() -> float:
	return def * (1.0 + (def_bonus_pct / 100.0))

func final_atk_spd_value() -> float:
	return atk_spd * (1.0 + (atk_spd_bonus_pct / 100.0))

func to_lines() -> Array[String]:
	var out: Array[String] = []

	# Basic
	if hp != 0: out.append("HP: %s" % snapped(hp, 0.01))
	if atk != 0: out.append("ATK: %s" % snapped(atk, 0.01))
	if def != 0: out.append("DEF: %s" % snapped(def, 0.01))
	if atk_spd != 0: out.append("ATK SPD: %s" % snapped(atk_spd, 0.01))

	# Advanced (existing)
	if crit_chance != 0: out.append("Crit Rate: %s%%" % snapped(crit_chance, 0.01))
	if crit_dmg != 0: out.append("Crit DMG: %s%%" % snapped(crit_dmg, 0.01))
	if crit_res != 0: out.append("Crit RES: %s%%" % snapped(crit_res, 0.01))

	if combo_chance != 0: out.append("Combo: %s%%" % snapped(combo_chance, 0.01))
	if combo_dmg != 0: out.append("Combo Mult: %s%%" % snapped(combo_dmg, 0.01))
	if ignore_combo != 0: out.append("Ignore Combo: %s%%" % snapped(ignore_combo, 0.01))
	if combo_dmg_res != 0: out.append("Combo DMG RES: %s%%" % snapped(combo_dmg_res, 0.01))

	if counter_chance != 0: out.append("Counter: %s%%" % snapped(counter_chance, 0.01))
	if counter_dmg != 0: out.append("Counter Mult: %s%%" % snapped(counter_dmg, 0.01))
	if ignore_counter != 0: out.append("Ignore Counter: %s%%" % snapped(ignore_counter, 0.01))
	if counter_dmg_res != 0: out.append("Counter DMG RES: %s%%" % snapped(counter_dmg_res, 0.01))

	# Evasion
	if avoidance != 0: out.append("Evasion: %s%%" % snapped(avoidance, 0.01))
	if ignore_evasion != 0: out.append("Ignore Evasion: %s%%" % snapped(ignore_evasion, 0.01))

	# Stun
	if stun_chance != 0: out.append("Stun: %s%%" % snapped(stun_chance, 0.01))
	if ignore_stun != 0: out.append("Ignore Stun: %s%%" % snapped(ignore_stun, 0.01))

	# Basic attack / skill related
	if basic_atk_mult != 0: out.append("Basic ATK Mult: %s%%" % snapped(basic_atk_mult, 0.01))
	if basic_atk_dmg_res != 0: out.append("Basic ATK DMG RES: %s%%" % snapped(basic_atk_dmg_res, 0.01))

	if skill_crit_chance != 0: out.append("Skill Crit: %s%%" % snapped(skill_crit_chance, 0.01))
	if skill_crit_dmg != 0: out.append("Skill Crit DMG: %s%%" % snapped(skill_crit_dmg, 0.01))
	if skill_dmg_res != 0: out.append("Skill DMG RES: %s%%" % snapped(skill_dmg_res, 0.01))

	# Boss/Pet
	if boss_dmg != 0: out.append("Boss DMG: %s%%" % snapped(boss_dmg, 0.01))
	if boss_dmg_res != 0: out.append("Boss DMG RES: %s%%" % snapped(boss_dmg_res, 0.01))
	if pet_dmg != 0: out.append("Pet DMG: %s%%" % snapped(pet_dmg, 0.01))
	if pet_dmg_res != 0: out.append("Pet DMG RES: %s%%" % snapped(pet_dmg_res, 0.01))

	# Bonuses / finals
	if hp_bonus_pct != 0: out.append("HP Bonus: %s%%" % snapped(hp_bonus_pct, 0.01))
	if atk_bonus_pct != 0: out.append("ATK Bonus: %s%%" % snapped(atk_bonus_pct, 0.01))
	if def_bonus_pct != 0: out.append("DEF Bonus: %s%%" % snapped(def_bonus_pct, 0.01))
	if atk_spd_bonus_pct != 0: out.append("ATK SPD Bonus: %s%%" % snapped(atk_spd_bonus_pct, 0.01))

	if final_dmg_boost_pct != 0: out.append("Final DMG Boost: %s%%" % snapped(final_dmg_boost_pct, 0.01))
	if final_dmg_res_pct != 0: out.append("Final DMG RES: %s%%" % snapped(final_dmg_res_pct, 0.01))

	# Existing legacy advanced not in your new list (kept)
	if block != 0: out.append("Block: %s%%" % snapped(block, 0.01))
	if regen != 0: out.append("Regen: %s/s" % snapped(regen, 0.01))

	# Final computed lines (only show if any relevant bonus is non-zero)
	if hp_bonus_pct != 0 and hp != 0:
		out.append("Final HP: %s" % snapped(final_hp_value(), 0.01))
	if atk_bonus_pct != 0 and atk != 0:
		out.append("Final ATK: %s" % snapped(final_atk_value(), 0.01))
	if def_bonus_pct != 0 and def != 0:
		out.append("Final DEF: %s" % snapped(final_def_value(), 0.01))
	if atk_spd_bonus_pct != 0 and atk_spd != 0:
		out.append("Final ATK SPD: %s" % snapped(final_atk_spd_value(), 0.01))

	return out

func to_dict() -> Dictionary:
	return {
		# Basic
		"hp": hp,
		"atk": atk,
		"def": def,
		"atk_spd": atk_spd,

		# Existing advanced
		"block": block,
		"avoidance": avoidance,
		"crit_chance": crit_chance,
		"crit_dmg": crit_dmg,
		"combo_chance": combo_chance,
		"combo_dmg": combo_dmg,
		"counter_chance": counter_chance,
		"counter_dmg": counter_dmg,
		"regen": regen,

		# New advanced
		"crit_res": crit_res,
		"ignore_combo": ignore_combo,
		"ignore_counter": ignore_counter,
		"stun_chance": stun_chance,
		"ignore_stun": ignore_stun,
		"ignore_evasion": ignore_evasion,

		"basic_atk_mult": basic_atk_mult,
		"basic_atk_dmg_res": basic_atk_dmg_res,
		"combo_dmg_res": combo_dmg_res,
		"counter_dmg_res": counter_dmg_res,

		"skill_crit_chance": skill_crit_chance,
		"skill_crit_dmg": skill_crit_dmg,
		"skill_dmg_res": skill_dmg_res,

		"boss_dmg": boss_dmg,
		"boss_dmg_res": boss_dmg_res,
		"pet_dmg": pet_dmg,
		"pet_dmg_res": pet_dmg_res,

		"hp_bonus_pct": hp_bonus_pct,
		"atk_bonus_pct": atk_bonus_pct,
		"def_bonus_pct": def_bonus_pct,
		"atk_spd_bonus_pct": atk_spd_bonus_pct,

		"final_dmg_boost_pct": final_dmg_boost_pct,
		"final_dmg_res_pct": final_dmg_res_pct,
	}

static func from_dict(d: Dictionary) -> Stats:
	var s := Stats.new()

	# Basic
	s.hp = float(d.get("hp", 0.0))
	s.atk = float(d.get("atk", 0.0))
	s.def = float(d.get("def", 0.0))
	s.atk_spd = float(d.get("atk_spd", 0.0))

	# Existing advanced
	s.block = float(d.get("block", 0.0))
	s.avoidance = float(d.get("avoidance", 0.0))
	s.crit_chance = float(d.get("crit_chance", 0.0))
	s.crit_dmg = float(d.get("crit_dmg", 0.0))
	s.combo_chance = float(d.get("combo_chance", 0.0))
	s.combo_dmg = float(d.get("combo_dmg", 0.0))
	s.counter_chance = float(d.get("counter_chance", 0.0))
	s.counter_dmg = float(d.get("counter_dmg", 0.0))
	s.regen = float(d.get("regen", 0.0))

	# New advanced (safe defaults for older saves)
	s.crit_res = float(d.get("crit_res", 0.0))
	s.ignore_combo = float(d.get("ignore_combo", 0.0))
	s.ignore_counter = float(d.get("ignore_counter", 0.0))
	s.stun_chance = float(d.get("stun_chance", 0.0))
	s.ignore_stun = float(d.get("ignore_stun", 0.0))
	s.ignore_evasion = float(d.get("ignore_evasion", 0.0))

	s.basic_atk_mult = float(d.get("basic_atk_mult", 0.0))
	s.basic_atk_dmg_res = float(d.get("basic_atk_dmg_res", 0.0))
	s.combo_dmg_res = float(d.get("combo_dmg_res", 0.0))
	s.counter_dmg_res = float(d.get("counter_dmg_res", 0.0))

	s.skill_crit_chance = float(d.get("skill_crit_chance", 0.0))
	s.skill_crit_dmg = float(d.get("skill_crit_dmg", 0.0))
	s.skill_dmg_res = float(d.get("skill_dmg_res", 0.0))

	s.boss_dmg = float(d.get("boss_dmg", 0.0))
	s.boss_dmg_res = float(d.get("boss_dmg_res", 0.0))
	s.pet_dmg = float(d.get("pet_dmg", 0.0))
	s.pet_dmg_res = float(d.get("pet_dmg_res", 0.0))

	s.hp_bonus_pct = float(d.get("hp_bonus_pct", 0.0))
	s.atk_bonus_pct = float(d.get("atk_bonus_pct", 0.0))
	s.def_bonus_pct = float(d.get("def_bonus_pct", 0.0))
	s.atk_spd_bonus_pct = float(d.get("atk_spd_bonus_pct", 0.0))

	s.final_dmg_boost_pct = float(d.get("final_dmg_boost_pct", 0.0))
	s.final_dmg_res_pct = float(d.get("final_dmg_res_pct", 0.0))

	return s
