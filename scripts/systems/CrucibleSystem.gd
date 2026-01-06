extends Node
class_name CrucibleSystem

# Optional: keep Mount/Artifact from dropping for now.
const ROLLABLE_SLOTS: Array[int] = [
	Catalog.GearSlot.WEAPON,
	Catalog.GearSlot.HELMET,
	Catalog.GearSlot.SHOULDERS,
	Catalog.GearSlot.CHEST,
	Catalog.GearSlot.GLOVES,
	Catalog.GearSlot.BELT,
	Catalog.GearSlot.LEGS,
	Catalog.GearSlot.BOOTS,
	Catalog.GearSlot.RING,
	Catalog.GearSlot.BRACELET,
]

func roll_item_for_player(p: PlayerModel) -> GearItem:
	var item := GearItem.new()
	var rng := (RNG as RNGService)

	item.slot = ROLLABLE_SLOTS[rng.randi_range(0, ROLLABLE_SLOTS.size() - 1)]
	item.item_level = Catalog.roll_item_level(p.level)
	item.rarity = roll_rarity_for_level(p.crucible_level)

	item.stats = _roll_stats(item.slot, item.item_level, item.rarity, p.class_id)
	return item

func roll_rarity_for_level(crucible_level: int) -> int:
	var odds: Dictionary = Catalog.crucible_rarity_odds(crucible_level)

	var roll: float = RNG.randf() # 0..1
	var acc: float = 0.0

	for r in Catalog.RARITY_DISPLAY_ORDER:
		var p: float = float(odds.get(r, 0.0))
		if p <= 0.0:
			continue
		acc += p
		if roll <= acc:
			return int(r)
	print("Here")
	# Fallback
	return int(Catalog.Rarity.COMMON)

func _pct_roll(rng: RNGService, min_pct: int, max_pct: int) -> float:
	return float(rng.randi_range(min_pct, max_pct))

func _roll_stats(slot: int, item_level: int, rarity: int, class_id: int) -> Stats:
	var s := Stats.new()
	var mult: float = float(Catalog.RARITY_STAT_MULT.get(rarity, 1.0))
	var rng := (RNG as RNGService)

	match slot:
		Catalog.GearSlot.WEAPON:
			s.atk = 6.0 + float(item_level) * 1.9
			s.crit_chance = _pct_roll(rng, 0, 4)
			s.crit_dmg = _pct_roll(rng, 0, 8)

		Catalog.GearSlot.HELMET:
			s.hp = 16.0 + float(item_level) * 3.6
			s.def = 1.1 + float(item_level) * 0.45
			s.block = _pct_roll(rng, 0, 3)

		Catalog.GearSlot.SHOULDERS:
			s.hp = 14.0 + float(item_level) * 3.2
			s.def = 1.2 + float(item_level) * 0.50
			s.avoidance = _pct_roll(rng, 0, 2)

		Catalog.GearSlot.CHEST:
			s.hp = 26.0 + float(item_level) * 5.2
			s.def = 2.2 + float(item_level) * 0.75
			s.regen = 0.10 + float(item_level) * 0.02

		Catalog.GearSlot.GLOVES:
			s.atk = 2.2 + float(item_level) * 0.85
			s.atk_spd = 0.06 + float(item_level) * 0.012
			s.combo_chance = _pct_roll(rng, 0, 3)

		Catalog.GearSlot.BELT:
			s.hp = 10.0 + float(item_level) * 2.8
			s.def = 0.8 + float(item_level) * 0.30
			s.regen = 0.15 + float(item_level) * 0.03

		Catalog.GearSlot.LEGS:
			s.hp = 18.0 + float(item_level) * 4.0
			s.def = 1.6 + float(item_level) * 0.60
			s.avoidance = _pct_roll(rng, 0, 3)

		Catalog.GearSlot.BOOTS:
			s.hp = 11.0 + float(item_level) * 2.7
			s.avoidance = _pct_roll(rng, 0, 4)
			s.atk_spd = 0.03 + float(item_level) * 0.008

		Catalog.GearSlot.RING:
			match class_id:
				PlayerModel.ClassId.WARRIOR:
					s.str = 1.0 + float(item_level) * 0.28
				PlayerModel.ClassId.MAGE:
					s.int_ = 1.0 + float(item_level) * 0.28
				PlayerModel.ClassId.ARCHER:
					s.agi = 1.0 + float(item_level) * 0.28
			s.combo_chance = _pct_roll(rng, 0, 4)
			s.combo_dmg = _pct_roll(rng, 0, 10)

		Catalog.GearSlot.BRACELET:
			match class_id:
				PlayerModel.ClassId.WARRIOR:
					s.str = 1.0 + float(item_level) * 0.22
				PlayerModel.ClassId.MAGE:
					s.int_ = 1.0 + float(item_level) * 0.22
				PlayerModel.ClassId.ARCHER:
					s.agi = 1.0 + float(item_level) * 0.22
			s.crit_chance = _pct_roll(rng, 0, 4)
			s.crit_dmg = _pct_roll(rng, 0, 12)

		# Future slots: shouldn't drop (rollable list prevents it), but safe defaults.
		Catalog.GearSlot.MOUNT:
			s.hp = 8.0 + float(item_level) * 2.0
			s.agi = 0.5 + float(item_level) * 0.10

		Catalog.GearSlot.ARTIFACT:
			s.atk = 3.0 + float(item_level) * 0.7
			s.crit_chance = _pct_roll(rng, 0, 2)

		_:
			s.atk = 1.0 + float(item_level) * 0.3

	return s.scaled(mult)
