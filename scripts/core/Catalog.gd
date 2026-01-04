extends Node
#class_name Catalog

enum Rarity { UNCOMMON, COMMON, RARE, UNIQUE, MYTHIC, LEGENDARY, IMMORTAL, SUPREME, AUROUS, ETERNAL }

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

# Base chance tables by Crucible level band (simple MVP)
func get_rarity_weights(crucible_level:int) -> Dictionary:
	# Return {rarity:int: weight:float}
	# Early levels: only lower rarities possible, matching your spec. :contentReference[oaicite:1]{index=1}
	if crucible_level <= 3:
		return {
			Rarity.UNCOMMON: 60,
			Rarity.COMMON: 35,
			Rarity.RARE: 5,
		}
	if crucible_level <= 8:
		return {
			Rarity.UNCOMMON: 40,
			Rarity.COMMON: 35,
			Rarity.RARE: 18,
			Rarity.UNIQUE: 7,
		}
	if crucible_level <= 15:
		return {
			Rarity.UNCOMMON: 22,
			Rarity.COMMON: 30,
			Rarity.RARE: 25,
			Rarity.UNIQUE: 15,
			Rarity.MYTHIC: 8,
		}
	# Higher levels gradually open the rest (tune later)
	return {
		Rarity.UNCOMMON: 10,
		Rarity.COMMON: 18,
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
