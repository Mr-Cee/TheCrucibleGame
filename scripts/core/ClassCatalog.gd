extends Node
class_name ClassCatalog

# Code-driven class progression tree (Tier unlocks at Lv 25/50/75).

static var _defs: Dictionary = {} # class_def_id -> ClassDef

static func _mk(id: String, name: String, base_class_id: int, tier: int, unlock_level: int, parent_id: String = "", passive_flat: Stats = null, granted_passives: Array[String] = []) -> ClassDef:
	var d := ClassDef.new()
	d.id = id
	d.display_name = name
	d.base_class_id = base_class_id
	d.tier = tier
	d.unlock_level = unlock_level
	d.parent_id = parent_id
	d.passive_flat = passive_flat
	d.granted_passive_skills = granted_passives
	return d

static func _ensure_built() -> void:
	if _defs.size() > 0:
		return

	# Warrior line
	_defs["warrior"] = _mk("warrior", "Warrior", 0, 1, 1)

	var knight_stats := Stats.new()
	knight_stats.def = 5
	knight_stats.hp = 40
	_defs["knight"] = _mk("knight", "Knight", 0, 2, 25, "warrior", knight_stats, ["war_fortitude"])

	var bers_stats := Stats.new()
	bers_stats.atk = 6
	bers_stats.combo_chance = 3
	_defs["berserker"] = _mk("berserker", "Berserker", 0, 2, 25, "warrior", bers_stats)

	_defs["paladin"] = _mk("paladin", "Paladin", 0, 3, 50, "knight")
	_defs["sentinel"] = _mk("sentinel", "Sentinel", 0, 3, 50, "knight")
	_defs["warlord"] = _mk("warlord", "Warlord", 0, 3, 50, "berserker")
	_defs["bloodreaver"] = _mk("bloodreaver", "Bloodreaver", 0, 3, 50, "berserker")

	_defs["crusader"] = _mk("crusader", "Crusader", 0, 4, 75, "paladin")
	_defs["templar"] = _mk("templar", "Templar", 0, 4, 75, "paladin")
	_defs["bulwark"] = _mk("bulwark", "Bulwark", 0, 4, 75, "sentinel")
	_defs["ironclad"] = _mk("ironclad", "Ironclad", 0, 4, 75, "sentinel")
	_defs["warmaster"] = _mk("warmaster", "Warmaster", 0, 4, 75, "warlord")
	_defs["conqueror"] = _mk("conqueror", "Conqueror", 0, 4, 75, "warlord")
	_defs["slaughterlord"] = _mk("slaughterlord", "Slaughterlord", 0, 4, 75, "bloodreaver")
	_defs["dreadknight"] = _mk("dreadknight", "Dreadknight", 0, 4, 75, "bloodreaver")

	# Mage line
	_defs["mage"] = _mk("mage", "Mage", 1, 1, 1)

	var sorc := Stats.new()
	sorc.int_ = 6
	sorc.crit_chance = 4
	_defs["sorcerer"] = _mk("sorcerer", "Sorcerer", 1, 2, 25, "mage", sorc, ["mag_focus"])

	var lock := Stats.new()
	lock.int_ = 5
	lock.regen = 0.5
	_defs["warlock"] = _mk("warlock", "Warlock", 1, 2, 25, "mage", lock)

	_defs["archmage"] = _mk("archmage", "Archmage", 1, 3, 50, "sorcerer")
	_defs["spellblade"] = _mk("spellblade", "Spellblade", 1, 3, 50, "sorcerer")
	_defs["hexer"] = _mk("hexer", "Hexer", 1, 3, 50, "warlock")
	_defs["necromancer"] = _mk("necromancer", "Necromancer", 1, 3, 50, "warlock")

	_defs["arcanist"] = _mk("arcanist", "Arcanist", 1, 4, 75, "archmage")
	_defs["elementalist"] = _mk("elementalist", "Elementalist", 1, 4, 75, "archmage")
	_defs["battlemage"] = _mk("battlemage", "Battlemage", 1, 4, 75, "spellblade")
	_defs["magus_assassin"] = _mk("magus_assassin", "Magus Assassin", 1, 4, 75, "spellblade")
	_defs["curse_lord"] = _mk("curse_lord", "Curse Lord", 1, 4, 75, "hexer")
	_defs["void_scholar"] = _mk("void_scholar", "Void Scholar", 1, 4, 75, "hexer")
	_defs["lich"] = _mk("lich", "Lich", 1, 4, 75, "necromancer")
	_defs["deathcaller"] = _mk("deathcaller", "Deathcaller", 1, 4, 75, "necromancer")

	# Archer line
	_defs["archer"] = _mk("archer", "Archer", 2, 1, 1)

	var ranger := Stats.new()
	ranger.agi = 6
	ranger.atk_spd = 0.05
	_defs["ranger"] = _mk("ranger", "Ranger", 2, 2, 25, "archer", ranger, ["arc_swiftness"])

	var rogue := Stats.new()
	rogue.agi = 5
	rogue.avoidance = 3
	_defs["rogue"] = _mk("rogue", "Rogue", 2, 2, 25, "archer", rogue)

	_defs["sharpshooter"] = _mk("sharpshooter", "Sharpshooter", 2, 3, 50, "ranger")
	_defs["beastmaster"] = _mk("beastmaster", "Beastmaster", 2, 3, 50, "ranger")
	_defs["assassin"] = _mk("assassin", "Assassin", 2, 3, 50, "rogue")
	_defs["shadowdancer"] = _mk("shadowdancer", "Shadowdancer", 2, 3, 50, "rogue")

	_defs["deadeye"] = _mk("deadeye", "Deadeye", 2, 4, 75, "sharpshooter")
	_defs["sniper"] = _mk("sniper", "Sniper", 2, 4, 75, "sharpshooter")
	_defs["primal_warden"] = _mk("primal_warden", "Primal Warden", 2, 4, 75, "beastmaster")
	_defs["wildcaller"] = _mk("wildcaller", "Wildcaller", 2, 4, 75, "beastmaster")
	_defs["nightblade"] = _mk("nightblade", "Nightblade", 2, 4, 75, "assassin")
	_defs["phantom"] = _mk("phantom", "Phantom", 2, 4, 75, "assassin")
	_defs["bladedancer"] = _mk("bladedancer", "Bladedancer", 2, 4, 75, "shadowdancer")
	_defs["umbral_stalker"] = _mk("umbral_stalker", "Umbral Stalker", 2, 4, 75, "shadowdancer")

static func get_def(class_def_id: String) -> ClassDef:
	_ensure_built()
	return _defs.get(class_def_id, null)

static func base_def_for_class_id(class_id: int) -> ClassDef:
	_ensure_built()
	match class_id:
		0: return _defs["warrior"]
		1: return _defs["mage"]
		2: return _defs["archer"]
	return null

static func next_choices(current_class_def_id: String, player_level: int) -> Array[ClassDef]:
	_ensure_built()
	var out: Array[ClassDef] = []
	for d in _defs.values():
		var cd: ClassDef = d
		if cd.parent_id == current_class_def_id and player_level >= cd.unlock_level:
			out.append(cd)
	out.sort_custom(func(a: ClassDef, b: ClassDef) -> bool:
		return a.display_name < b.display_name
	)
	return out
