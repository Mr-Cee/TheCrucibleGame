extends Resource
class_name PlayerModel

enum ClassId { WARRIOR, MAGE, ARCHER }

@export var class_id: int = ClassId.WARRIOR
@export var level: int = 1

@export var gold: int = 0
@export var crystals: int = 0
@export var diamonds: int = 0

@export var crucible_keys: int = 10

@export var crucible_level: int = 1

@export var equipped := {
	Catalog.GearSlot.WEAPON: null,
	Catalog.GearSlot.HELMET: null,
	Catalog.GearSlot.SHOULDERS: null,
	Catalog.GearSlot.CHEST: null,
	Catalog.GearSlot.GLOVES: null,
	Catalog.GearSlot.BELT: null,
	Catalog.GearSlot.LEGS: null,
	Catalog.GearSlot.BOOTS: null,
	Catalog.GearSlot.RING: null,
	Catalog.GearSlot.BRACELET: null,
	Catalog.GearSlot.MOUNT: null,
	Catalog.GearSlot.ARTIFACT: null,
}

@export var crucible_batch: int = 1
@export var crucible_rarity_min: int = Catalog.Rarity.COMMON
@export var crucible_auto_sell_below: bool = true

func base_stats() -> Stats:
	var s := Stats.new()
	# Simple class baselines; tune later. :contentReference[oaicite:3]{index=3}
	match class_id:
		ClassId.WARRIOR:
			s.hp = 120
			s.def = 12
			s.atk = 8
			s.str = 5
		ClassId.MAGE:
			s.hp = 80
			s.def = 6
			s.atk = 12
			s.int_ = 5
		ClassId.ARCHER:
			s.hp = 100
			s.def = 9
			s.atk = 10
			s.agi = 5
	# Growth per level (MVP)
	s.hp += (level - 1) * 8
	s.def += (level - 1) * 0.8
	s.atk += (level - 1) * 1.0
	return s

func total_stats() -> Stats:
	var s := base_stats()
	for slot in equipped.keys():
		var item:GearItem = equipped[slot]
		if item != null:
			s.add(item.stats)
	# Global stat synergies per your doc (e.g., STR increases HP for all). :contentReference[oaicite:4]{index=4}
	# MVP conversion rates:
	s.hp += s.str * 5.0
	s.atk += s.str * 0.5
	s.atk += s.int_ * 0.6
	s.atk += s.agi * 0.55
	s.atk_spd += s.agi * 0.05
	return s

func combat_power() -> int:
	# CP formula (MVP): weighted sum. Tune as we balance.
	var s := total_stats()
	var cp := 0.0
	cp += s.hp * 0.20
	cp += s.def * 2.0
	cp += s.atk * 6.0
	cp += s.str * 4.0
	cp += s.int_ * 4.0
	cp += s.agi * 4.0
	cp += s.atk_spd * 20.0
	cp += (s.block + s.avoidance) * 10.0
	cp += (s.crit_chance + s.combo_chance) * 8.0
	return int(round(cp))

func to_dict() -> Dictionary:
	var eq_out: Dictionary = {}
	for k in equipped.keys():
		var slot_id: int = int(k)
		var item: GearItem = equipped.get(slot_id, null)
		eq_out[str(slot_id)] = item.to_dict() if item != null else null

	return {
		"gold": gold,
		"diamonds": diamonds,
		"crystals": crystals,
		"level": level,
		"class_id": class_id,
		"crucible_keys": crucible_keys,
		"crucible_level": crucible_level,
		"equipped": eq_out,
		"crucible_batch": crucible_batch,
		"crucible_rarity_min": crucible_rarity_min,
		"crucible_auto_sell_below": crucible_auto_sell_below,
	}

static func from_dict(d: Dictionary) -> PlayerModel:
	var p := PlayerModel.new()
	p.gold = int(d.get("gold", 0))
	p.diamonds = int(d.get("diamonds", 0))
	p.crystals = int(d.get("crystals", 0))
	p.level = int(d.get("level", 1))
	p.class_id = int(d.get("class_id", 0))
	p.crucible_keys = int(d.get("crucible_keys", 0))
	p.crucible_level = int(d.get("crucible_level", 1))
	p.crucible_batch = int(d.get("crucible_batch", 1))
	p.crucible_rarity_min = int(d.get("crucible_rarity_min", Catalog.Rarity.COMMON))
	p.crucible_auto_sell_below = bool(d.get("crucible_auto_sell_below", true))

	# Ensure equipped exists for all slots
	p.equipped = {}
	for slot_id in Catalog.GEAR_SLOT_NAMES.keys():
		p.equipped[int(slot_id)] = null

	var eqv: Variant = d.get("equipped", {})
	if typeof(eqv) == TYPE_DICTIONARY:
		var eqd: Dictionary = eqv
		for sk in eqd.keys():
			var slot: int = int(sk)
			var iv: Variant = eqd[sk]
			if iv == null:
				p.equipped[slot] = null
			elif typeof(iv) == TYPE_DICTIONARY:
				p.equipped[slot] = GearItem.from_dict(iv as Dictionary)

	return p
