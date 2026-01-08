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

# --- Crucible upgrade gold tuning (per payment stage) ---
# "current_level" means upgrading from Lv.N to Lv.N+1.
# Each payment stage within the SAME level costs the SAME amount.
const CRUCIBLE_UPGRADE_GOLD_TABLE: Dictionary = {
	1: 15000,   # Lv1 -> Lv2 (1 stage)
	# Add more overrides anytime you want.
}

# Used when not in table
const CRUCIBLE_UPGRADE_GOLD_BASE: int = 15000          # anchor cost (per stage)
const CRUCIBLE_UPGRADE_GOLD_GROWTH: float = 1.70      # exponential growth per level
const CRUCIBLE_UPGRADE_GOLD_ANCHOR_LEVEL: int = 1     # growth starts after this level

static func crucible_upgrade_stage_cost_gold(current_level: int) -> int:
	current_level = max(1, current_level)

	# Explicit early-game overrides
	if CRUCIBLE_UPGRADE_GOLD_TABLE.has(current_level):
		return int(CRUCIBLE_UPGRADE_GOLD_TABLE[current_level])

	# Exponential tail
	var n: int = max(0, current_level - CRUCIBLE_UPGRADE_GOLD_ANCHOR_LEVEL)
	var cost: float = float(CRUCIBLE_UPGRADE_GOLD_BASE) * pow(CRUCIBLE_UPGRADE_GOLD_GROWTH, float(n))
	return int(round(cost))


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
const CRUCIBLE_XP_BASE_PER_DRAW: int = 5
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

# --- Battle rewards tuning ---
const BATTLE_GOLD_BASE: int = 5
const BATTLE_GOLD_PER_LEVEL: int = 2
const BATTLE_GOLD_PER_STAGE: int = 1
const BATTLE_GOLD_PER_WAVE: int = 0

const BATTLE_GOLD_BOSS_BONUS: int = 10

const BATTLE_KEYS_PER_WAVE: int = 1
const BATTLE_KEYS_BOSS_BONUS: int = 2

static func battle_gold_for_wave(difficulty: String, level: int, stage: int, wave: int, is_boss: bool) -> int:
	# MVP tuning:
	# - scales gently with level/stage
	# - boss wave gets a noticeable bump
	var base: int = 5 + (level - 1) * 2 + (stage - 1)
	var wave_bonus: int = (wave - 1)  # small ramp 0..4
	var gold: int = base + wave_bonus

	if is_boss:
		gold = int(round(float(gold) * 1.50))  # boss bonus (50%)
	return max(1, gold)

static func battle_keys_for_wave(difficulty: String, level: int, stage: int, wave: int, is_boss: bool) -> int:
	# Your request: keys after every wave + bonus on boss.
	# MVP: 1 key per wave; boss gives +1 bonus (total 2 on boss).
	var keys: int = 1
	if is_boss:
		keys += 1
	return max(0, keys)

# --- Battle progression tuning ---
const BATTLE_WAVES_PER_STAGE: int = 5
const BATTLE_STAGES_PER_LEVEL: int = 10
const BATTLE_LEVELS_PER_DIFFICULTY: int = 10

# Ordered list controls difficulty progression.
const BATTLE_DIFFICULTY_ORDER: Array[String] = [
	"Easy",
	"Hard",
	"Nightmare",
	"Hell",
	"Abyss I",
	"Abyss II",
	"Abyss II",
	"Apocolypse I",
	"Apocolypse II",
	"Apocolypse III",
	"Apocolypse IV",
	"Apocolypse V",
	"Void I",
	"Void II",
	"Void III",
	"Void IV",
	"Void V",
	"Void VI",
	"Void VII",
	"Void VIII",
	"Void IX",
	"Void X",
	"Eternal",
	# Add later: "Nightmare", "Hell", etc.
]

# --- Battle difficulty scaling (formula-based) ---
# Everything is derived from difficulty index + level + stage + wave.

# Base enemy stats at Easy / Lv1 / Stage1 / Wave1 (tune freely)
const ENEMY_BASE_HP: float = 80.0
const ENEMY_BASE_ATK: float = 8.0
const ENEMY_BASE_DEF: float = 1.5

# Difficulty tier growth per step in BATTLE_DIFFICULTY_ORDER.
# These are intentionally “chunky” so each named tier feels meaningful.
const DIFF_HP_GROWTH: float = 1.55
const DIFF_ATK_GROWTH: float = 1.70
const DIFF_DEF_GROWTH: float = 1.55

# Within a difficulty: levels and stages should ramp noticeably
const LEVEL_HP_GROWTH: float = 1.18
const LEVEL_ATK_GROWTH: float = 1.22
const LEVEL_DEF_GROWTH: float = 1.18

const STAGE_HP_GROWTH: float = 1.08
const STAGE_ATK_GROWTH: float = 1.10
const STAGE_DEF_GROWTH: float = 1.08

# Wave ramp inside a stage (Wave 5 will also get boss multipliers)
const WAVE_HP_GROWTH: float = 1.05
const WAVE_ATK_GROWTH: float = 1.06
const WAVE_DEF_GROWTH: float = 1.05

# Boss wave multipliers (wave 5)
const BOSS_HP_MULT: float = 2.35
const BOSS_ATK_MULT: float = 1.70
const BOSS_DEF_MULT: float = 1.12

# Optional: stage “gateway” bosses (stage 5 and stage 10 bosses are extra spicy)
const GATEWAY_BOSS_MULT: float = 1.20
const FINAL_STAGE_BOSS_MULT: float = 1.35  # stage 10 boss additional


#static func battle_difficulty_scalars(diff: String) -> Dictionary:
	#return BATTLE_DIFFICULTY_SCALARS.get(diff, BATTLE_DIFFICULTY_SCALARS["Easy"])


static func battle_difficulty_index(diff: String) -> int:
	var idx: int = BATTLE_DIFFICULTY_ORDER.find(diff)
	return 0 if idx < 0 else idx

static func battle_enemy_multipliers(diff: String, level: int, stage: int, wave: int, is_boss: bool) -> Dictionary:
	level = max(1, level)
	stage = max(1, stage)
	wave = max(1, wave)

	var tier: int = battle_difficulty_index(diff)

	var hp_mult: float = pow(DIFF_HP_GROWTH, float(tier))
	var atk_mult: float = pow(DIFF_ATK_GROWTH, float(tier))
	var def_mult: float = pow(DIFF_DEF_GROWTH, float(tier))

	hp_mult *= pow(LEVEL_HP_GROWTH, float(level - 1))
	atk_mult *= pow(LEVEL_ATK_GROWTH, float(level - 1))
	def_mult *= pow(LEVEL_DEF_GROWTH, float(level - 1))

	hp_mult *= pow(STAGE_HP_GROWTH, float(stage - 1))
	atk_mult *= pow(STAGE_ATK_GROWTH, float(stage - 1))
	def_mult *= pow(STAGE_DEF_GROWTH, float(stage - 1))

	hp_mult *= pow(WAVE_HP_GROWTH, float(wave - 1))
	atk_mult *= pow(WAVE_ATK_GROWTH, float(wave - 1))
	def_mult *= pow(WAVE_DEF_GROWTH, float(wave - 1))

	# Boss wave (wave 5)
	if is_boss:
		hp_mult *= BOSS_HP_MULT
		atk_mult *= BOSS_ATK_MULT
		def_mult *= BOSS_DEF_MULT

		# Optional: “gateway” boss bumps
		if stage == 5 or stage == 10:
			hp_mult *= GATEWAY_BOSS_MULT
			atk_mult *= GATEWAY_BOSS_MULT
			def_mult *= GATEWAY_BOSS_MULT
		if stage == 10:
			hp_mult *= FINAL_STAGE_BOSS_MULT
			atk_mult *= FINAL_STAGE_BOSS_MULT
			def_mult *= FINAL_STAGE_BOSS_MULT

	return {"hp": hp_mult, "atk": atk_mult, "def": def_mult}

# Optional: per-difficulty overrides (can leave empty for now).
const BATTLE_DIFFICULTY_RULES: Dictionary = {
	# "Easy": {"levels": 10, "stages": 10, "waves": 5},
	# "Hard": {"levels": 10, "stages": 10, "waves": 5},
}

static func battle_rules_for_difficulty(diff: String) -> Dictionary:
	var r: Dictionary = BATTLE_DIFFICULTY_RULES.get(diff, {})
	return {
		"levels": int(r.get("levels", BATTLE_LEVELS_PER_DIFFICULTY)),
		"stages": int(r.get("stages", BATTLE_STAGES_PER_LEVEL)),
		"waves": int(r.get("waves", BATTLE_WAVES_PER_STAGE)),
	}

static func battle_next_difficulty(diff: String) -> String:
	var idx: int = BATTLE_DIFFICULTY_ORDER.find(diff)
	if idx == -1:
		return BATTLE_DIFFICULTY_ORDER[0]
	if idx + 1 >= BATTLE_DIFFICULTY_ORDER.size():
		# Stay at max difficulty for now (or loop if you prefer)
		return BATTLE_DIFFICULTY_ORDER[BATTLE_DIFFICULTY_ORDER.size() - 1]
	return BATTLE_DIFFICULTY_ORDER[idx + 1]

static func battle_advance_progression(diff: String, level: int, stage: int, wave: int) -> Dictionary:
	level = max(1, level)
	stage = max(1, stage)
	wave = max(1, wave)

	var rules: Dictionary = battle_rules_for_difficulty(diff)
	var max_levels: int = int(rules["levels"])
	var max_stages: int = int(rules["stages"])
	var max_waves: int = int(rules["waves"])

	# Advance wave -> stage -> level -> difficulty
	wave += 1
	if wave > max_waves:
		wave = 1
		stage += 1
		

		if stage > max_stages:
			stage = 1
			level += 1

			if level > max_levels:
				level = 1
				diff = battle_next_difficulty(diff)

	return {
		"difficulty": diff,
		"level": level,
		"stage": stage,
		"wave": wave,
	}
