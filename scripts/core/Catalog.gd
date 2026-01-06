extends Node
#class_name Catalog

enum Rarity { COMMON, UNCOMMON, RARE, UNIQUE, MYTHIC, LEGENDARY, IMMORTAL, SUPREME, AUROUS, ETERNAL }

const RARITY_NAMES := {
	Rarity.COMMON: "Common",
	Rarity.UNCOMMON: "Uncommon",
	Rarity.RARE: "Rare",
	Rarity.UNIQUE: "Unique",
	Rarity.MYTHIC: "Mythic",
	Rarity.LEGENDARY: "Legendary",
	Rarity.IMMORTAL: "Immortal",
	Rarity.SUPREME: "Supreme",
	Rarity.AUROUS: "Aurous",
	Rarity.ETERNAL: "Eternal",
}

const RARITY_PULSE := {
	Rarity.LEGENDARY: true,
	Rarity.IMMORTAL: true,
	Rarity.SUPREME: true,
	Rarity.AUROUS: true,
	Rarity.ETERNAL: true,
}

# UI-friendly colors (Godot Color)
const RARITY_COLORS := {
	Rarity.COMMON: Color("8a8a8a"),   # gray
	Rarity.UNCOMMON: Color("2ecc71"),     # green
	Rarity.RARE: Color("3498db"),       # blue
	Rarity.UNIQUE: Color("9b59b6"),     # purple
	Rarity.MYTHIC: Color("f1c40f"),     # yellow
	Rarity.LEGENDARY: Color("e67e22"),  # orange
	Rarity.IMMORTAL: Color("ff66cc"),   # pink
	Rarity.SUPREME: Color("00ffff"),    # cyan
	Rarity.AUROUS: Color("ffd700"),     # gold
	Rarity.ETERNAL: Color("66ffff"),    # cyan-ish (rainbow effect later)
}

# --- Display order for tables/UI (do NOT rely on enum ordering) ---
const RARITY_DISPLAY_ORDER: Array[int] = [
	Rarity.COMMON,
	Rarity.UNCOMMON,
	Rarity.RARE,
	Rarity.UNIQUE,
	Rarity.MYTHIC,
	Rarity.LEGENDARY,
	Rarity.IMMORTAL,
	Rarity.SUPREME,
	Rarity.AUROUS,
	Rarity.ETERNAL,
]

# --- When each rarity becomes available (MVP tuning knobs) ---
const CRUCIBLE_RARITY_UNLOCK_LEVEL := {
	Rarity.COMMON: 1,
	Rarity.UNCOMMON: 1,
	Rarity.RARE: 1,
	Rarity.UNIQUE: 3,
	Rarity.MYTHIC: 6,
	Rarity.LEGENDARY: 10,
	Rarity.IMMORTAL: 12,
	Rarity.SUPREME: 15,
	Rarity.AUROUS: 18,
	Rarity.ETERNAL: 22,
}

# --- Base weights + growth per level (MVP tuning knobs) ---
# Higher-tier growth > 1 increases over time; lower-tier growth < 1 decreases.
const CRUCIBLE_RARITY_BASE_WEIGHT := {
	Rarity.COMMON: 60.0,
	Rarity.UNCOMMON: 30.0,
	Rarity.RARE: 10.0,
	Rarity.UNIQUE: 3.0,
	Rarity.MYTHIC: 1.0,
	Rarity.LEGENDARY: 0.3,
	Rarity.IMMORTAL: 0.1,
	Rarity.SUPREME: 0.03,
	Rarity.AUROUS: 0.01,
	Rarity.ETERNAL: 0.003,
}

const CRUCIBLE_RARITY_GROWTH := {
	Rarity.COMMON: 0.970,
	Rarity.UNCOMMON: 0.985,
	Rarity.RARE: 1.030,
	Rarity.UNIQUE: 1.050,
	Rarity.MYTHIC: 1.070,
	Rarity.LEGENDARY: 1.080,
	Rarity.IMMORTAL: 1.090,
	Rarity.SUPREME: 1.100,
	Rarity.AUROUS: 1.100,
	Rarity.ETERNAL: 1.100,
}

enum GearSlot { WEAPON, HELMET, SHOULDERS, CHEST, GLOVES, BELT, LEGS, BOOTS, RING, BRACELET, MOUNT, ARTIFACT }

const GEAR_SLOT_NAMES := {
	GearSlot.WEAPON: "Weapon",
	GearSlot.HELMET: "Helmet",
	GearSlot.SHOULDERS: "Shoulders",
	GearSlot.CHEST: "Chest",
	GearSlot.GLOVES: "Gloves",
	GearSlot.BELT: "Belt",
	GearSlot.LEGS: "Legs",
	GearSlot.BOOTS: "Boots",
	GearSlot.RING: "Ring",
	GearSlot.BRACELET: "Bracelet",
	GearSlot.MOUNT: "Mount",
	GearSlot.ARTIFACT: "Artifact",
}

# Rarity multipliers (tuning knobs)
const RARITY_STAT_MULT := {
	Rarity.COMMON: 0.90,
	Rarity.UNCOMMON: 1.00,
	Rarity.RARE: 1.15,
	Rarity.UNIQUE: 1.35,
	Rarity.MYTHIC: 1.60,
	Rarity.LEGENDARY: 1.90,
	Rarity.IMMORTAL: 2.25,
	Rarity.SUPREME: 2.65,
	Rarity.AUROUS: 3.10,
	Rarity.ETERNAL: 3.70,
}

# --- Crucible upgrade time tuning (seconds) ---
# "current_level" means upgrading from Lv.N to Lv.N+1.
const CRUCIBLE_UPGRADE_TIME_TABLE: Dictionary = {
	1: 10 * 60,  # Lv1 -> Lv2
	2: 15 * 60,  # Lv2 -> Lv3
	3: 30 * 60,  # Lv3 -> Lv4
	4: 45 * 60,  # Lv4 -> Lv5
	# Add more explicit overrides here anytime you want.
}

const CRUCIBLE_UPGRADE_TIME_BASE: int = 45 * 60   # base used when not in table (seconds)
const CRUCIBLE_UPGRADE_TIME_GROWTH: float = 1.25  # exponential growth per level beyond base_anchor
const CRUCIBLE_UPGRADE_TIME_ANCHOR_LEVEL: int = 4 # growth starts after this level (uses base)

# Base chance tables by Crucible level band (simple MVP)
func get_rarity_weights(crucible_level:int) -> Dictionary:
	# Return {rarity:int: weight:float}
	# Early levels: only lower rarities possible, matching your spec. :contentReference[oaicite:1]{index=1}
	if crucible_level <= 3:
		return {
			Rarity.COMMON: 60,
			Rarity.UNCOMMON: 35,
			Rarity.RARE: 5,
		}
	if crucible_level <= 8:
		return {
			Rarity.COMMON: 40,
			Rarity.UNCOMMON: 35,
			Rarity.RARE: 18,
			Rarity.UNIQUE: 7,
		}
	if crucible_level <= 15:
		return {
			Rarity.COMMON: 22,
			Rarity.UNCOMMON: 30,
			Rarity.RARE: 25,
			Rarity.UNIQUE: 15,
			Rarity.MYTHIC: 8,
		}
	# Higher levels gradually open the rest (tune later)
	return {
		Rarity.COMMON: 10,
		Rarity.UNCOMMON: 18,
		Rarity.RARE: 22,
		Rarity.UNIQUE: 18,
		Rarity.MYTHIC: 14,
		Rarity.LEGENDARY: 9,
		Rarity.IMMORTAL: 5,
		Rarity.SUPREME: 2,
		Rarity.AUROUS: 0.8,
		Rarity.ETERNAL: 0.2,
	}

func roll_item_level(player_level:int) -> int:
	# Item level range: player_level-2 .. player_level (min 1)
	var lo: int = int(max(1, player_level - 2))
	return (RNG as RNGService).randi_range(lo, player_level)

func rarity_to_bbcode(rarity:int, text:String) -> String:
	var c:Color = RARITY_COLORS.get(rarity, Color.WHITE)
	return "[color=#%s]%s[/color]" % [c.to_html(false), text]

static func crucible_rarity_odds(level: int) -> Dictionary:
	level = max(1, level)

	var raw: Dictionary = {}
	var sum: float = 0.0

	for r in RARITY_DISPLAY_ORDER:
		var unlock: int = int(CRUCIBLE_RARITY_UNLOCK_LEVEL.get(r, 1))
		if level < unlock:
			raw[r] = 0.0
			continue

		var base: float = float(CRUCIBLE_RARITY_BASE_WEIGHT.get(r, 0.0))
		var g: float = float(CRUCIBLE_RARITY_GROWTH.get(r, 1.0))
		var n: int = level - unlock
		var w: float = base * pow(g, float(n))
		raw[r] = w
		sum += w

	# Fallback safety
	if sum <= 0.0:
		return { Rarity.COMMON: 1.0 }

	# Normalize to probabilities
	var probs: Dictionary = {}
	for r in raw.keys():
		probs[r] = float(raw[r]) / sum
	return probs

static func crucible_rarity_unlock_level(rarity: int) -> int:
	return int(CRUCIBLE_RARITY_UNLOCK_LEVEL.get(rarity, 1))

static func crucible_upgrade_time_seconds(current_level: int) -> int:
	current_level = max(1, current_level)

	# Explicit early-game overrides
	if CRUCIBLE_UPGRADE_TIME_TABLE.has(current_level):
		return int(CRUCIBLE_UPGRADE_TIME_TABLE[current_level])

	# Exponential tail
	var n: int = max(0, current_level - CRUCIBLE_UPGRADE_TIME_ANCHOR_LEVEL)
	var secs: float = float(CRUCIBLE_UPGRADE_TIME_BASE) * pow(CRUCIBLE_UPGRADE_TIME_GROWTH, float(n))
	return int(round(secs))

# --- Crucible XP tuning ---
const CRUCIBLE_XP_BASE_PER_DRAW: int = 12
const CRUCIBLE_XP_PER_ITEM_LEVEL: float = 0.50

# Optional: scale XP by rarity (uses same keys as RARITY_STAT_MULT)
const CRUCIBLE_XP_RARITY_MULT := {
	Rarity.COMMON: 1.00,
	Rarity.UNCOMMON: 1.05,
	Rarity.RARE: 1.15,
	Rarity.UNIQUE: 1.30,
	Rarity.MYTHIC: 1.55,
	Rarity.LEGENDARY: 1.90,
	Rarity.IMMORTAL: 2.25,
	Rarity.SUPREME: 2.65,
	Rarity.AUROUS: 3.10,
	Rarity.ETERNAL: 3.70,
}

static func crucible_xp_for_draw(player_level: int, item_level: int, rarity: int) -> int:
	# Primary driver is "per draw" XP, with mild scaling by item level and rarity.
	var base: float = float(CRUCIBLE_XP_BASE_PER_DRAW) + float(item_level) * CRUCIBLE_XP_PER_ITEM_LEVEL
	var mult: float = float(CRUCIBLE_XP_RARITY_MULT.get(rarity, 1.0))
	return int(round(base * mult))
