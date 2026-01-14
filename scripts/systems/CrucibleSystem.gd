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

	# IMPORTANT: actually assign rarity to the item
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
	var rng := (RNG as RNGService)

	# Rarity multiplier (existing behavior)
	var mult: float = float(Catalog.RARITY_STAT_MULT.get(rarity, 1.0))

	# -----------------------------
	# 1) Main stats (Common/Uncommon baseline)
	# -----------------------------
	var is_weapon: bool = (slot == Catalog.GearSlot.WEAPON)
	var is_armor: bool = (
		slot == Catalog.GearSlot.HELMET
		or slot == Catalog.GearSlot.SHOULDERS
		or slot == Catalog.GearSlot.CHEST
		or slot == Catalog.GearSlot.GLOVES
		or slot == Catalog.GearSlot.BELT
		or slot == Catalog.GearSlot.LEGS
		or slot == Catalog.GearSlot.BOOTS
	)
	var is_accessory: bool = (slot == Catalog.GearSlot.RING or slot == Catalog.GearSlot.BRACELET)

	# Slot-flavored main stat coefficients (tune freely)
	# These are intentionally simple and consistent with your new tier rules.
	match slot:
		Catalog.GearSlot.WEAPON:
			# Weapon main stats: HP + ATK
			s.hp  = 8.0  + float(item_level) * 2.0
			s.atk = 6.0  + float(item_level) * 1.9

		Catalog.GearSlot.HELMET:
			s.hp  = 16.0 + float(item_level) * 3.6
			s.def = 1.1  + float(item_level) * 0.45

		Catalog.GearSlot.SHOULDERS:
			s.hp  = 14.0 + float(item_level) * 3.2
			s.def = 1.2  + float(item_level) * 0.50

		Catalog.GearSlot.CHEST:
			s.hp  = 26.0 + float(item_level) * 5.2
			s.def = 2.2  + float(item_level) * 0.75

		Catalog.GearSlot.GLOVES:
			s.hp  = 12.0 + float(item_level) * 3.0
			s.def = 0.9  + float(item_level) * 0.35

		Catalog.GearSlot.BELT:
			s.hp  = 10.0 + float(item_level) * 2.8
			s.def = 0.8  + float(item_level) * 0.30

		Catalog.GearSlot.LEGS:
			s.hp  = 18.0 + float(item_level) * 4.0
			s.def = 1.6  + float(item_level) * 0.60

		Catalog.GearSlot.BOOTS:
			s.hp  = 11.0 + float(item_level) * 2.7
			s.def = 0.7  + float(item_level) * 0.25

		Catalog.GearSlot.RING:
			# Accessories main stats (treat as armor-like)
			s.hp  = 8.0  + float(item_level) * 2.2
			s.def = 0.6  + float(item_level) * 0.22

		Catalog.GearSlot.BRACELET:
			s.hp  = 9.0  + float(item_level) * 2.0
			s.def = 0.55 + float(item_level) * 0.20

		_:
			# Safe default
			s.hp  = 6.0 + float(item_level) * 2.0
			s.def = 0.5 + float(item_level) * 0.2

	# -----------------------------
	# 2) Rare+: add class main stat (STR/INT/AGI)
	# -----------------------------
	if _rarity_meets_or_above(rarity, Catalog.Rarity.RARE):
		var v: float = 1.0 + float(item_level) * 0.25
		match class_id:
			PlayerModel.ClassId.WARRIOR:
				s.str = v
			PlayerModel.ClassId.MAGE:
				s.int_ = v
			PlayerModel.ClassId.ARCHER:
				s.agi = v

	# -----------------------------
	# 3) Unique+: add 1 secondary stat (chance/defensive)
	# -----------------------------
	if _rarity_meets_or_above(rarity, Catalog.Rarity.UNIQUE):
		_add_secondary_tier1(s, slot, item_level, rng)

	# -----------------------------
	# 4) Mythic+: add another secondary stat (damage modifiers / utility)
	# -----------------------------
	if _rarity_meets_or_above(rarity, Catalog.Rarity.MYTHIC):
		_add_secondary_tier2(s, slot, item_level, rng)

	return s.scaled(mult)
	
func _rarity_rank_map() -> Dictionary:
	# Build once per call-site (small map; fine for MVP).
	var m: Dictionary = {}
	for i in range(Catalog.RARITY_DISPLAY_ORDER.size()):
		m[int(Catalog.RARITY_DISPLAY_ORDER[i])] = i
	return m

func _rarity_meets_or_above(rarity: int, threshold: int) -> bool:
	var m := _rarity_rank_map()
	var r_rank: int = int(m.get(rarity, 0))
	var t_rank: int = int(m.get(threshold, 0))
	return r_rank >= t_rank

func _pick_weighted(keys: Array[String], weights: Array[float], rng: RNGService) -> String:
	var total: float = 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return keys[0]

	var roll: float = rng.randf() * total
	var acc: float = 0.0
	for i in range(keys.size()):
		acc += float(weights[i])
		if roll <= acc:
			return keys[i]
	return keys[keys.size() - 1]

func _stat_exists(s: Object, prop: String) -> bool:
	# Avoid hard-crashing if a stat isn't implemented yet (counterstrike)
	for p in s.get_property_list():
		if String(p.get("name", "")) == prop:
			return true
	return false

func _set_stat_safe(s: Object, prop: String, value) -> void:
	if _stat_exists(s, prop):
		s.set(prop, value)

func _add_secondary_tier1(s: Stats, slot: int, item_level: int, rng: RNGService) -> void:
	# Tier 1 secondary: chance-based / defensive
	# Pool: crit_chance, combo_chance, avoidance, block (+ optional counter_chance)
	var keys: Array[String] = ["crit_chance", "combo_chance", "avoidance", "block", "counter_chance"]
	var weights: Array[float]

	# Slot bias
	if slot == Catalog.GearSlot.WEAPON:
		weights = [3.0, 2.0, 0.8, 0.4, 1.0]
	elif slot == Catalog.GearSlot.RING or slot == Catalog.GearSlot.BRACELET:
		weights = [1.6, 1.6, 1.4, 1.4, 1.2]
	else:
		# Armor
		weights = [0.8, 0.8, 2.0, 2.3, 1.8]

	var pick: String = _pick_weighted(keys, weights, rng)

	# Roll sizes (simple, scales slightly with item level)
	var max_ch: int = 2 + int(floor(float(item_level) / 5.0)) # grows slowly
	max_ch = clampi(max_ch, 2, 8)

	match pick:
		"crit_chance":
			s.crit_chance = float(rng.randi_range(0, max_ch))
		"combo_chance":
			s.combo_chance = float(rng.randi_range(0, max_ch))
		"avoidance":
			s.avoidance = float(rng.randi_range(0, max(2, max_ch - 1)))
		"block":
			s.block = float(rng.randi_range(0, max(2, max_ch - 1)))
		"counter_chance":
			_set_stat_safe(s, "counter_chance", float(rng.randi_range(0, max(2, max_ch - 1))))
		_:
			s.crit_chance = float(rng.randi_range(0, max_ch))

func _add_secondary_tier2(s: Stats, slot: int, item_level: int, rng: RNGService) -> void:
	# Tier 2 secondary: damage modifiers / utility
	# Pool: crit_dmg, combo_dmg, atk_spd, regen (+ optional counter_dmg)
	var keys: Array[String] = ["crit_dmg", "combo_dmg", "atk_spd", "regen", "counter_dmg"]
	var weights: Array[float]

	if slot == Catalog.GearSlot.WEAPON:
		weights = [3.0, 2.2, 1.1, 0.4, 1.3]
	elif slot == Catalog.GearSlot.RING or slot == Catalog.GearSlot.BRACELET:
		weights = [1.8, 1.8, 1.2, 1.0, 1.2]
	else:
		# Armor
		weights = [1.0, 1.0, 1.1, 2.0, 1.6]

	var pick: String = _pick_weighted(keys, weights, rng)

	# Scales
	var max_pct: int = 6 + int(floor(float(item_level) / 3.0)) # grows faster
	max_pct = clampi(max_pct, 6, 30)

	match pick:
		"crit_dmg":
			s.crit_dmg = float(rng.randi_range(0, max_pct))
		"combo_dmg":
			s.combo_dmg = float(rng.randi_range(0, max_pct))
		"atk_spd":
			# attack speed as additive fraction (0.00..)
			var v: float = 0.02 + float(item_level) * 0.004
			s.atk_spd = v
		"regen":
			# regen as flat/sec (tune later)
			var v2: float = 0.05 + float(item_level) * 0.01
			s.regen = v2
		"counter_dmg":
			_set_stat_safe(s, "counter_dmg", float(rng.randi_range(0, max_pct)))
		_:
			s.crit_dmg = float(rng.randi_range(0, max_pct))


	
