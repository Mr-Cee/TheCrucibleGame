extends Resource
class_name Stats

@export var hp: float = 0
@export var def: float = 0
@export var atk: float = 0

@export var str: float = 0
@export var int_: float = 0
@export var agi: float = 0

@export var atk_spd: float = 0
@export var block: float = 0
@export var avoidance: float = 0
@export var counter_chance: float = 0
@export var counter_dmg: float = 0
@export var crit_chance: float = 0
@export var crit_dmg: float = 0
@export var combo_chance: float = 0
@export var combo_dmg: float = 0
@export var regen: float = 0

func add(other:Stats) -> void:
	hp += other.hp
	def += other.def
	atk += other.atk
	str += other.str
	int_ += other.int_
	agi += other.agi
	atk_spd += other.atk_spd
	block += other.block
	avoidance += other.avoidance
	counter_chance += other.counter_chance
	counter_dmg += other.counter_dmg
	crit_chance += other.crit_chance
	crit_dmg += other.crit_dmg
	combo_chance += other.combo_chance
	combo_dmg += other.combo_dmg
	regen += other.regen

func scaled(mult:float) -> Stats:
	var s := Stats.new()
	s.hp = hp * mult
	s.def = def * mult
	s.atk = atk * mult
	s.str = str * mult
	s.int_ = int_ * mult
	s.agi = agi * mult
	s.atk_spd = atk_spd * mult
	s.block = block * mult
	s.avoidance = avoidance * mult
	s.counter_chance = counter_chance * mult
	s.counter_dmg = counter_dmg * mult
	s.crit_chance = crit_chance * mult
	s.crit_dmg = crit_dmg * mult
	s.combo_chance = combo_chance * mult
	s.combo_dmg = combo_dmg * mult
	s.regen = regen * mult
	return s

func to_lines() -> Array[String]:
	var out:Array[String] = []
	if hp != 0: out.append("HP: %s" % snapped(hp, 0.01))
	if def != 0: out.append("DEF: %s" % snapped(def, 0.01))
	if atk != 0: out.append("ATK: %s" % snapped(atk, 0.01))
	if str != 0: out.append("STR: %s" % snapped(str, 0.01))
	if int_ != 0: out.append("INT: %s" % snapped(int_, 0.01))
	if agi != 0: out.append("AGI: %s" % snapped(agi, 0.01))
	if atk_spd != 0: out.append("ATK SPD: %s" % snapped(atk_spd, 0.01))
	if block != 0: out.append("Block: %s%%" % snapped(block, 0.01))
	if avoidance != 0: out.append("Avoid: %s%%" % snapped(avoidance, 0.01))
	if counter_chance != 0: out.append("Counter Chance: %s%%" % snapped(counter_chance, 0.01))
	if counter_dmg != 0: out.append("Counter Dmg: %s%%" % snapped(counter_dmg, 0.01))
	if crit_chance != 0: out.append("Crit Chance: %s%%" % snapped(crit_chance, 0.01))
	if crit_dmg != 0: out.append("Crit Dmg: %s%%" % snapped(crit_dmg, 0.01))
	if combo_chance != 0: out.append("Combo Chance: %s%%" % snapped(combo_chance, 0.01))
	if combo_dmg != 0: out.append("Combo Dmg: %s%%" % snapped(combo_dmg, 0.01))
	if regen != 0: out.append("Regen: %s/s" % snapped(regen, 0.01))
	return out

func to_dict() -> Dictionary:
	return {
		"atk": atk,
		"hp": hp,
		"def": def,
		"atk_spd": atk_spd,
		"crit_chance": crit_chance,
		"crit_dmg": crit_dmg,
		"avoidance": avoidance,
		"combo_chance": combo_chance,
		"combo_dmg": combo_dmg,
		"block": block,
		"regen": regen,
		"str": str,
		"int": int_,
		"agi": agi,
	}

static func from_dict(d: Dictionary) -> Stats:
	var s := Stats.new()
	s.atk = float(d.get("atk", 0.0))
	s.hp = float(d.get("hp", 0.0))
	s.def = float(d.get("def", 0.0))
	s.atk_spd = float(d.get("atk_spd", 0.0))
	s.crit_chance = float(d.get("crit_chance", 0.0))
	s.crit_dmg = float(d.get("crit_dmg", 0.0))
	s.avoidance = float(d.get("avoidance", 0.0))
	s.combo_chance = float(d.get("combo_chance", 0.0))
	s.combo_dmg = float(d.get("combo_dmg", 0.0))
	s.block = float(d.get("block", 0.0))
	s.regen = float(d.get("regen", 0.0))
	s.str = float(d.get("str", 0.0))
	s.int_ = float(d.get("int", 0.0))
	s.agi = float(d.get("agi", 0.0))
	return s
