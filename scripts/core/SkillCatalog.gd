extends Node
class_name SkillCatalog

# Code-driven active skill catalog (universal skills).
# Passive skills will be handled separately later.

static var _defs: Dictionary = {} # id -> SkillDef

static func _add_def(id: String, name: String, desc: String, cd: float, effect: SkillDef.EffectType,
		power: float, hits: int = 1, duration: float = 0.0, magnitude: float = 0.0, secondary_power: float = 0.0) -> void:
	var d := SkillDef.new()
	d.id = id
	d.display_name = name
	d.description = desc
	d.cooldown = cd
	d.effect = effect
	d.power = power
	d.hits = hits
	d.duration = duration
	d.magnitude = magnitude
	d.secondary_power = secondary_power
	_defs[id] = d

static func _ensure_built() -> void:
	if _defs.size() > 0:
		return

	# ------------------------------
	# Damage / Burst
	# ------------------------------
	_add_def("arcane_bolt", "Arcane Bolt",
		"Fire a focused bolt of energy dealing moderate damage.",
		10.0, SkillDef.EffectType.DAMAGE, 2.0)

	_add_def("power_strike", "Power Strike",
		"A crushing strike that deals heavy damage.",
		12.0, SkillDef.EffectType.DAMAGE, 2.6)

	_add_def("rapid_shot", "Rapid Shot",
		"Fire a quick volley, dealing multiple smaller hits.",
		11.0, SkillDef.EffectType.MULTI_HIT, 0.95, 3)

	_add_def("meteor_fragment", "Meteor Fragment",
		"Call down a fragment from above for high burst damage.",
		18.0, SkillDef.EffectType.DAMAGE, 3.4)

	_add_def("whirlwind", "Whirlwind",
		"Spin and strike repeatedly, dealing several hits.",
		16.0, SkillDef.EffectType.MULTI_HIT, 0.85, 5)

	_add_def("piercing_arrow", "Piercing Arrow",
		"A piercing shot that briefly reduces enemy defense.",
		14.0, SkillDef.EffectType.ARMOR_BREAK, 1.8, 1, 6.0, 0.25)

	# ------------------------------
	# DoT / Attrition
	# ------------------------------
	_add_def("flame_wave", "Flame Wave",
		"Burn the enemy, dealing damage and applying a short burn.",
		14.0, SkillDef.EffectType.DOT, 1.5, 1, 6.0, 0.0, 0.35)

	_add_def("poisoned_blade", "Poisoned Blade",
		"Slash and poison the enemy, applying a lingering toxin.",
		13.0, SkillDef.EffectType.DOT, 1.25, 1, 7.0, 0.0, 0.30)

	_add_def("shadow_bleed", "Shadow Bleed",
		"Strike from the shadows and cause bleeding over time.",
		15.0, SkillDef.EffectType.DOT, 1.35, 1, 8.0, 0.0, 0.28)

	_add_def("life_drain", "Life Drain",
		"Drain life from the enemy: deal damage and heal for a portion dealt.",
		16.0, SkillDef.EffectType.LIFE_DRAIN, 1.9, 1, 0.0, 0.35)

	# ------------------------------
	# Crowd Control / Debuffs
	# ------------------------------
	_add_def("frost_lance", "Frost Lance",
		"Impale with frost, dealing damage and slowing enemy attacks.",
		12.0, SkillDef.EffectType.SLOW, 1.6, 1, 5.0, 0.30)

	_add_def("thunderclap", "Thunderclap",
		"A stunning shockwave that deals damage and briefly stuns.",
		17.0, SkillDef.EffectType.STUN, 1.7, 1, 1.5)

	_add_def("concussive_shot", "Concussive Shot",
		"A heavy shot that deals damage and briefly stuns.",
		15.0, SkillDef.EffectType.STUN, 1.5, 1, 1.2)

	_add_def("hex_frailty", "Hex of Frailty",
		"Curse the enemy, reducing their damage for a short time.",
		14.0, SkillDef.EffectType.WEAKEN, 0.0, 1, 7.0, 0.22)

	_add_def("marked_prey", "Marked Prey",
		"Mark the enemy, increasing the damage they take.",
		13.0, SkillDef.EffectType.VULNERABILITY, 0.0, 1, 7.0, 0.20)

	_add_def("time_snare", "Time Snare",
		"Distort time to slow enemy attacks significantly.",
		18.0, SkillDef.EffectType.SLOW, 0.0, 1, 6.0, 0.40)

	# ------------------------------
	# Healing / Shielding
	# ------------------------------
	_add_def("healing_surge", "Healing Surge",
		"Instantly restore a chunk of health.",
		12.0, SkillDef.EffectType.HEAL, 0.22)

	_add_def("rejuvenation", "Rejuvenation",
		"Heal over time for a short duration.",
		15.0, SkillDef.EffectType.HOT, 0.0, 1, 8.0, 0.0, 0.035)

	_add_def("barrier", "Barrier",
		"Gain a protective shield that absorbs damage.",
		14.0, SkillDef.EffectType.SHIELD, 0.22)

	_add_def("guardian_wall", "Guardian Wall",
		"A stronger shield with a slightly longer cooldown.",
		18.0, SkillDef.EffectType.SHIELD, 0.30)

	_add_def("second_wind", "Second Wind",
		"Heal and gain a small shield.",
		16.0, SkillDef.EffectType.SHIELD, 0.14)

	# ------------------------------
	# Self Buffs
	# ------------------------------
	_add_def("battle_cry", "Battle Cry",
		"Increases your attack for a short duration.",
		16.0, SkillDef.EffectType.BUFF_ATK, 0.0, 1, 8.0, 0.20)

	_add_def("iron_skin", "Iron Skin",
		"Increases your defense for a short duration.",
		16.0, SkillDef.EffectType.BUFF_DEF, 0.0, 1, 8.0, 0.30)

	_add_def("adrenaline_rush", "Adrenaline Rush",
		"Increases your attack speed for a short duration.",
		15.0, SkillDef.EffectType.BUFF_APS, 0.0, 1, 7.0, 0.25)

	_add_def("smoke_bomb", "Smoke Bomb",
		"Increases your chance to avoid attacks for a short duration.",
		18.0, SkillDef.EffectType.BUFF_AVOID, 0.0, 1, 6.0, 12.0)

	_add_def("deadly_focus", "Deadly Focus",
		"Increases your critical chance for a short duration.",
		18.0, SkillDef.EffectType.BUFF_CRIT, 0.0, 1, 6.0, 10.0)

	# ------------------------------
	# Utility
	# ------------------------------
	_add_def("arcane_overload", "Arcane Overload",
		"Reduce the remaining cooldown of your other equipped skills.",
		20.0, SkillDef.EffectType.COOLDOWN_REDUCE_OTHERS, 2.0)

	# Two hybrid/control skills to round out the set
	_add_def("crippling_blow", "Crippling Blow",
		"Deal damage and weaken the enemy's damage output.",
		17.0, SkillDef.EffectType.WEAKEN, 1.3, 1, 6.0, 0.18)

	_add_def("shatter_armor", "Shatter Armor",
		"Deal damage and significantly reduce enemy defense.",
		19.0, SkillDef.EffectType.ARMOR_BREAK, 1.4, 1, 6.0, 0.35)

static func get_def(id: String) -> SkillDef:
	_ensure_built()
	return _defs.get(id, null)

static func all_active_ids() -> Array[String]:
	_ensure_built()
	var out: Array[String] = []
	for k in _defs.keys():
		var sd: SkillDef = _defs[k]
		if sd != null and sd.type == SkillDef.SkillType.ACTIVE:
			out.append(String(k))
	out.sort()
	return out

static func starter_loadout() -> Array[String]:
	# Pick 5 universal skills that cover damage/CC/heal/shield/utility.
	return [
		"arcane_bolt",
		"thunderclap",
		"healing_surge",
		"barrier",
		"marked_prey"
	]

######========= BACKWARDS COMPATIBILITY CODE++++++++++###############
static func starting_skill_levels_for_class(_class_id: int) -> Dictionary:
	# Universal active skills MVP: grant all active skills at level 1.
	# Passive skills will be handled later, so we grant none here.
	_ensure_built()
	var out: Dictionary = {}
	for sid in all_active_ids():
		out[sid] = 1
	return out

static func starting_active_loadout_for_class(_class_id: int) -> Array[String]:
	# Universal starter loadout (5 slots). You can tweak this set anytime.
	return starter_loadout()

static func starting_passives_for_class(_class_id: int) -> Array[String]:
	# Passive system later. For now, start with none.
	return []
	
