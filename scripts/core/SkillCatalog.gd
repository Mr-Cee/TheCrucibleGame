extends Node
class_name SkillCatalog

# Central registry of skill definitions.
# MVP: purely code-driven. Later, migrate to .tres and load them.

static var _defs: Dictionary = {} # skill_id -> SkillDef

static func _mk_active(id: String, name: String, cooldown: float, base_power: float, power_per_level: float, scaling_stat: String, scaling_mult: float, desc: String, can_crit: bool = true, target: int = SkillDef.Target.ENEMY) -> SkillDef:
	var d := SkillDef.new()
	d.id = id
	d.display_name = name
	d.description = desc
	d.type = SkillDef.SkillType.ACTIVE
	d.target = target
	d.base_cooldown = cooldown
	d.base_power = base_power
	d.power_per_level = power_per_level
	d.scaling_stat = scaling_stat
	d.scaling_mult = scaling_mult
	d.can_crit = can_crit
	return d

static func _mk_passive(id: String, name: String, passive_flat: Stats, desc: String) -> SkillDef:
	var d := SkillDef.new()
	d.id = id
	d.display_name = name
	d.description = desc
	d.type = SkillDef.SkillType.PASSIVE
	d.passive_flat = passive_flat
	return d

static func _ensure_built() -> void:
	if _defs.size() > 0:
		return

	# --- Warrior starter kit ---
	_defs["war_shield_slam"] = _mk_active("war_shield_slam", "Shield Slam", 8.0, 14.0, 3.0, "def", 0.6,
		"Slam the enemy with your shield, dealing damage that scales with DEF.")
	_defs["war_cleave"] = _mk_active("war_cleave", "Cleave", 10.0, 22.0, 4.0, "str", 1.2,
		"A heavy swing that deals damage scaling with STR.")
	var war_pass := Stats.new()
	war_pass.hp = 50
	war_pass.def = 4
	_defs["war_fortitude"] = _mk_passive("war_fortitude", "Fortitude", war_pass, "Increase max HP and DEF.")

	# --- Mage starter kit ---
	_defs["mag_fireball"] = _mk_active("mag_fireball", "Fireball", 7.0, 24.0, 5.0, "int", 1.4,
		"Hurl a fireball that deals damage scaling with INT.")
	_defs["mag_arcane_burst"] = _mk_active("mag_arcane_burst", "Arcane Burst", 12.0, 40.0, 7.0, "int", 2.0,
		"Release a burst of arcane energy. Higher base damage and scaling.")
	var mag_pass := Stats.new()
	mag_pass.int_ = 5
	mag_pass.crit_chance = 3
	_defs["mag_focus"] = _mk_passive("mag_focus", "Focus", mag_pass, "Increase INT and Critical Chance.")

	# --- Archer starter kit ---
	_defs["arc_piercing_shot"] = _mk_active("arc_piercing_shot", "Piercing Shot", 6.0, 18.0, 4.0, "agi", 1.2,
		"A precise shot dealing damage scaling with AGI.")
	_defs["arc_rapid_volley"] = _mk_active("arc_rapid_volley", "Rapid Volley", 11.0, 26.0, 5.0, "agi", 1.6,
		"A volley of arrows that hits hard as your AGI climbs.")
	var arc_pass := Stats.new()
	arc_pass.agi = 5
	arc_pass.atk_spd = 0.05
	_defs["arc_swiftness"] = _mk_passive("arc_swiftness", "Swiftness", arc_pass, "Increase AGI and Attack Speed.")

static func get_def(skill_id: String) -> SkillDef:
	_ensure_built()
	return _defs.get(skill_id, null)

static func all_skill_ids() -> Array[String]:
	_ensure_built()
	var out: Array[String] = []
	for k in _defs.keys():
		out.append(String(k))
	out.sort()
	return out

static func starting_active_loadout_for_class(class_id: int) -> Array[String]:
	# class_id values: 0 warrior, 1 mage, 2 archer (matches PlayerModel.ClassId enum ordering)
	match class_id:
		0: return ["war_shield_slam", "war_cleave"]
		1: return ["mag_fireball", "mag_arcane_burst"]
		2: return ["arc_piercing_shot", "arc_rapid_volley"]
	return []

static func starting_passives_for_class(class_id: int) -> Array[String]:
	match class_id:
		0: return ["war_fortitude"]
		1: return ["mag_focus"]
		2: return ["arc_swiftness"]
	return []

static func starting_skill_levels_for_class(class_id: int) -> Dictionary:
	var d: Dictionary = {}
	for id in starting_active_loadout_for_class(class_id):
		d[id] = 1
	for id in starting_passives_for_class(class_id):
		d[id] = 1
	return d
