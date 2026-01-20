extends Node
class_name DungeonSystem

signal changed

var _game: Node = null
var _player: PlayerModel = null

func setup(game: Node, player: PlayerModel) -> void:
	_game = game
	_player = player
	_ensure_player_fields()

func _ensure_player_fields() -> void:
	if _player == null:
		return

	# Ensure dictionaries exist (older saves)
	if _player.dungeon_keys == null:
		_player.dungeon_keys = {}
	if _player.dungeon_levels == null:
		_player.dungeon_levels = {}

	# Seed defaults for all known dungeons
	for did in DungeonCatalog.all_ids():
		if not _player.dungeon_levels.has(did):
			_player.dungeon_levels[did] = 1
		else:
			_player.dungeon_levels[did] = maxi(1, int(_player.dungeon_levels.get(did, 1)))

		if not _player.dungeon_keys.has(did):
			_player.dungeon_keys[did] = 0
		else:
			_player.dungeon_keys[did] = maxi(0, int(_player.dungeon_keys.get(did, 0)))

func get_current_level(dungeon_id: String) -> int:
	_ensure_player_fields()
	return maxi(1, int(_player.dungeon_levels.get(dungeon_id, 1)))

func get_last_completed_level(dungeon_id: String) -> int:
	return maxi(0, get_current_level(dungeon_id) - 1)

func set_current_level(dungeon_id: String, level: int) -> void:
	_ensure_player_fields()
	_player.dungeon_levels[dungeon_id] = maxi(1, level)
	changed.emit()

func get_key_count(dungeon_id: String) -> int:
	_ensure_player_fields()
	return maxi(0, int(_player.dungeon_keys.get(dungeon_id, 0)))

func add_keys(dungeon_id: String, amount: int) -> void:
	if amount == 0:
		return
	_ensure_player_fields()
	_player.dungeon_keys[dungeon_id] = maxi(0, get_key_count(dungeon_id) + amount)
	changed.emit()

func can_attempt(dungeon_id: String) -> bool:
	# We require at least 1 key to enter because success will consume a key.
	return get_key_count(dungeon_id) > 0

func can_sweep(dungeon_id: String) -> bool:
	return get_key_count(dungeon_id) > 0 and get_last_completed_level(dungeon_id) > 0

func reward_for_level(dungeon_id: String, level: int) -> Dictionary:
	var def := DungeonCatalog.get_def(dungeon_id)
	if def == null:
		return {}

	level = maxi(1, level)
	var amt: int = def.reward_base + (level - 1) * def.reward_per_level
	return { def.reward_currency: amt }

func reward_to_text(reward: Dictionary) -> String:
	var parts: Array[String] = []
	for k in reward.keys():
		parts.append("%s: %d" % [String(k), int(reward[k])])
	return ", ".join(parts)

func sweep(dungeon_id: String) -> Dictionary:
	if not can_sweep(dungeon_id):
		return {}

	# Consume 1 key
	_player.dungeon_keys[dungeon_id] = get_key_count(dungeon_id) - 1

	# Reward is for last completed level (current_level - 1)
	var lvl: int = get_last_completed_level(dungeon_id)
	var reward := reward_for_level(dungeon_id, lvl)
	_apply_reward(reward)

	changed.emit()
	return reward

func complete_current_level_success(dungeon_id: String) -> Dictionary:
	# Call this after the dungeon boss is defeated in the future dungeon battle scene.
	# Success: consume 1 key, grant reward for CURRENT level, advance level by 1.
	if not can_attempt(dungeon_id):
		return {}

	_player.dungeon_keys[dungeon_id] = get_key_count(dungeon_id) - 1

	var cur: int = get_current_level(dungeon_id)
	var reward := reward_for_level(dungeon_id, cur)
	_apply_reward(reward)

	set_current_level(dungeon_id, cur + 1)
	changed.emit()
	return reward

func _apply_reward(reward: Dictionary) -> void:
	# MVP: only the currency we need right now.
	if reward.has("crucible_keys"):
		_player.crucible_keys += int(reward["crucible_keys"])

func begin_attempt(dungeon_id: String) -> bool:
	# Only validates. Do NOT consume a key here.
	return can_attempt(dungeon_id)

func reward_and_advance_on_success(dungeon_id: String) -> Dictionary:
		# Consume the dungeon key ONLY on success.
	if not _consume_key(dungeon_id):
		return {}
		
	var cur: int = get_current_level(dungeon_id)
	var reward := reward_for_level(dungeon_id, cur)
	_apply_reward(reward)
	set_current_level(dungeon_id, cur + 1)
	changed.emit()
	return reward

func enemy_stats_for_level(dungeon_id: String, level: int) -> Dictionary:
	var def := DungeonCatalog.get_def(dungeon_id)
	if def == null:
		return {}

	level = maxi(1, level)

	match int(def.kind):
		DungeonDef.DungeonKind.BOSS:
			var hp_mult: float = def.enemy_hp_mult_base + float(level - 1) * def.enemy_hp_mult_per_level
			var atk_mult: float = def.enemy_atk_mult_base + float(level - 1) * def.enemy_atk_mult_per_level
			var def_mult: float = def.enemy_def_mult_base + float(level - 1) * def.enemy_def_mult_per_level

			# Uses your existing Catalog base constants for consistency.
			var hp: float = float(Catalog.ENEMY_BASE_HP) * hp_mult
			var atk: float = float(Catalog.ENEMY_BASE_ATK) * atk_mult
			var df: float = float(Catalog.ENEMY_BASE_DEF) * def_mult

			return {
				"name": def.enemy_name,
				"hp": hp,
				"atk": atk,
				"def": df,
				"aps": def.enemy_aps,
				"is_boss": true,
				"sprite_path": def.enemy_sprite_path,
			}

		_:
			# Waves later
			return {}

func _consume_key(dungeon_id: String) -> bool:
	var k: int = get_key_count(dungeon_id) # or your existing getter
	if k <= 0:
		return false
	add_keys(dungeon_id, k - 1)       # or your existing setter
	return true
