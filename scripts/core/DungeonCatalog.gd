extends Node
class_name DungeonCatalog

const CRUCIBLE_KEY_DUNGEON_ID: String = "crucible_key_dungeon"
const MOLTEN_DEPTHS_DUNGEON_ID: String = "molten_depths"


static var _defs: Dictionary = {}

static func _ensure() -> void:
	if not _defs.is_empty():
		return

	var d := DungeonDef.new()
	d.id = CRUCIBLE_KEY_DUNGEON_ID
	d.time_limit_seconds = 30.0
	d.display_name = "Crucible Key Dungeon"
	d.description = "Fight a single boss that grows stronger each level. Earn Crucible Keys."
	d.key_display_name = "Crucible Dungeon Key"
	d.reward_currency = "crucible_keys"
	d.reward_base = 100
	d.reward_per_level = 5
	d.kind = DungeonDef.DungeonKind.BOSS
	d.enemy_name = "Crucible Warden"
	d.enemy_sprite_path = "res://assets/bosses/crucible_warden.png"
	d.enemy_hp_mult_base = 12.0
	d.enemy_hp_mult_per_level = 0.85
	d.enemy_atk_mult_base = 4.5
	d.enemy_atk_mult_per_level = 0.28
	d.enemy_def_mult_base = 2.2
	d.enemy_def_mult_per_level = 0.12
	d.enemy_aps = 0.75
	d.enemy_damage_mult = 0.0

	_defs[d.id] = d
	
		# ----------------------------
	# Molten Depths (new dungeon)
	# ----------------------------
	var m := DungeonDef.new()
	m.id = MOLTEN_DEPTHS_DUNGEON_ID
	m.display_name = "Molten Depths"
	m.description = "Defeat five molten guardians under strict timers. Earn crystals and skill tickets."
	m.key_display_name = "Molten Dungeon Key"
	m.daily_key_cap = 5

	# 5 boss-like enemies, 30 seconds each (your dungeon runner will reset timer per wave)
	m.kind = DungeonDef.DungeonKind.WAVES
	m.waves_count = 5
	m.time_limit_seconds = 30.0

	# Boss-like baseline scaling (tune as desired)
	m.enemy_name = "Molten Guardian"
	m.enemy_sprite_path = "res://assets/bosses/molten_guardian.png" # placeholder; set your actual path
	m.enemy_hp_mult_base = 10.0
	m.enemy_hp_mult_per_level = 0.75
	m.enemy_atk_mult_base = 5.0
	m.enemy_atk_mult_per_level = 0.30
	m.enemy_def_mult_base = 2.0
	m.enemy_def_mult_per_level = 0.10
	m.enemy_aps = 0.75
	m.enemy_damage_mult = 1.0 # enemies DO damage in this dungeon

	# Final wave slightly tougher
	m.waves_final_hp_mult = 1.20
	m.waves_final_atk_mult = 1.10
	m.waves_final_def_mult = 1.05

	# Multi rewards:
	# crystals: 100 + 5*(level-1)
	# tickets: 10 + floor((level-1)/5)
	m.reward_curves = [
		{ "id": "crystals", "base": 100, "per_level": 5 },
		{ "id": "skill_tickets", "base": 10, "step_every": 5, "step_amount": 1 },
	]

	_defs[m.id] = m


static func get_def(dungeon_id: String) -> DungeonDef:
	_ensure()
	return _defs.get(dungeon_id, null)

static func all_ids() -> Array[String]:
	_ensure()
	var out: Array[String] = []
	for k in _defs.keys():
		out.append(String(k))
	out.sort()
	return out
