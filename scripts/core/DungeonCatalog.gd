extends Node
class_name DungeonCatalog

const CRUCIBLE_KEY_DUNGEON_ID: String = "crucible_key_dungeon"

static var _defs: Dictionary = {}

static func _ensure() -> void:
	if not _defs.is_empty():
		return

	var d := DungeonDef.new()
	d.id = CRUCIBLE_KEY_DUNGEON_ID
	d.display_name = "Crucible Key Dungeon"
	d.description = "Fight a single boss that grows stronger each level. Earn Crucible Keys."
	d.key_display_name = "Crucible Dungeon Key"
	d.reward_currency = "crucible_keys"
	d.reward_base = 100
	d.reward_per_level = 5
	d.kind = DungeonDef.DungeonKind.BOSS
	d.enemy_name = "Crucible Warden"
	d.enemy_sprite_path = "res://assets/enemies/crucible_warden.png"
	d.enemy_hp_mult_base = 12.0
	d.enemy_hp_mult_per_level = 0.85
	d.enemy_atk_mult_base = 4.5
	d.enemy_atk_mult_per_level = 0.28
	d.enemy_def_mult_base = 2.2
	d.enemy_def_mult_per_level = 0.12
	d.enemy_aps = 0.75

	_defs[d.id] = d

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
