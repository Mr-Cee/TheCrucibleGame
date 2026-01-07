extends Node
#class_name Game

signal player_changed
signal inventory_event(message:String)
signal battle_changed

#===================================================================================================

var player: PlayerModel
var battle_state: Dictionary = {
	"difficulty": "Easy",
	"level": 1,
	"stage": 1,
	"wave": 1,
	"speed_idx": 0,
}
var crucible_draw_cooldown_base: float = 1.0
var crucible_draw_cooldown_mult: float = 1.0 # battlepass can reduce this, e.g. 0.5
var _upgrade_check_accum: float = 0.0

var battle_runtime: Dictionary = {
	"player_hp": 0.0,
	"player_hp_max": 0.0,
	"enemy_hp": 0.0,
	"enemy_hp_max": 0.0,
	"is_boss": false,
}

var _battle_inited: bool = false
var _p_atk_accum: float = 0.0
var _e_atk_accum: float = 0.0

# Cached player combat
var _p_hp_max: float = 1.0
var _p_atk: float = 1.0
var _p_def: float = 0.0
var _p_aps: float = 1.0
var _p_crit: float = 0.0        # 0..1
var _p_combo: float = 0.0       # percent points (can exceed 100)
var _p_block: float = 0.0       # percent points
var _p_avoid: float = 0.0       # percent points

# Enemy combat
var _e_atk: float = 1.0
var _e_def: float = 0.0
var _e_aps: float = 0.8

#===================================================================================================

const TIME_VOUCHER_SECONDS: int = 5 * 60 # 5 minutes

#===================================================================================================

func _ready() -> void:
	SaveManager.load_or_new()
	SaveManager.init_autosave_hooks()
	
	player_changed.connect(_battle_on_player_changed)

	_battle_init_if_needed()

	
	crucible_tick_upgrade_completion()

func _process(delta: float) -> void:
	_upgrade_check_accum += delta
	if _upgrade_check_accum >= 1.0:
		_upgrade_check_accum = 0.0
		crucible_tick_upgrade_completion()
	_battle_init_if_needed()
	_battle_process(delta)

func add_gold(amount:int) -> void:
	player.gold += amount
	emit_signal("player_changed")

func add_battle_rewards(gold_amount: int, key_amount: int) -> void:
	if gold_amount != 0:
		player.gold += gold_amount
	if key_amount != 0:
		player.crucible_keys += key_amount
	player_changed.emit()

func spend_crucible_key() -> bool:
	if player.crucible_keys <= 0:
		return false
	player.crucible_keys -= 1
	emit_signal("player_changed")
	return true

#func equip_item(item:GearItem) -> GearItem:
	#var old:GearItem = player.equipped.get(item.slot, null)
	#player.equipped[item.slot] = item
	#emit_signal("player_changed")
	#return old

func equip_item(item: GearItem) -> GearItem:
	if item == null:
		return null

	var slot: int = int(item.slot)
	var old: GearItem = player.equipped.get(slot, null)

	player.equipped[slot] = item
	player_changed.emit()
	return old
	
func sell_item(item:GearItem) -> int:
	var base := item.item_level * 10
	var mult: float = float(Catalog.RARITY_STAT_MULT.get(item.rarity, 1.0))
	var value := int(round(base * mult))
	add_gold(value)
	emit_signal("inventory_event", "Sold for %d gold" % value)
	return value

func reset_battle_state() -> void:
	battle_state = {
		"difficulty": "Easy",
		"level": 1,
		"stage": 1,
		"wave": 1,
		"speed_idx": 0,
	}
	battle_changed.emit()

func set_battle_state(state: Dictionary) -> void:
	# Defensive copy + defaults
	var d: Dictionary = {}
	d["difficulty"] = String(state.get("difficulty", "Easy"))
	d["level"] = int(state.get("level", 1))
	d["stage"] = int(state.get("stage", 1))
	d["wave"] = int(state.get("wave", 1))
	d["speed_idx"] = int(state.get("speed_idx", 0))

	battle_state = d
	battle_changed.emit()

func patch_battle_state(patch: Dictionary) -> void:
	var changed: bool = false
	for k in patch.keys():
		var new_val = patch[k]
		if battle_state.get(k) != new_val:
			battle_state[k] = new_val
			changed = true
	if changed:
		battle_changed.emit()

func crucible_draw_cooldown() -> float:
	return max(0.05, crucible_draw_cooldown_base * crucible_draw_cooldown_mult)

func spend_crucible_keys(count: int) -> int:
	var n: int = mini(count, int(player.crucible_keys))
	if n <= 0:
		return 0
	player.crucible_keys -= n
	player_changed.emit()
	return n

# --- Crucible upgrade rules (tune freely) ---

func crucible_required_payment_stages(current_level: int) -> int:
	# Spec:
	# 1->2, 2->3: 1 stage
	# 3->4, 4->5: 2 stages
	# next two: 3 stages
	# next two: 4 stages
	# everything after: 5 stages
	if current_level < 3:
		return 1
	if current_level < 5:
		return 2
	if current_level < 7:
		return 3
	if current_level < 9:
		return 4
	return 5

func crucible_stage_cost_gold(current_level: int, stage_index: int) -> int:
	# stage_index is 0..required-1
	# MVP scalable formula. Tweak as desired.
	var base: float = 250.0
	var level_scale: float = pow(1.35, float(current_level - 1))
	var stage_scale: float = 1.0 + float(stage_index) * 0.20
	return int(round(base * level_scale * stage_scale))

func crucible_upgrade_time_seconds(current_level: int) -> int:
	return Catalog.crucible_upgrade_time_seconds(current_level)

func crucible_is_upgrading() -> bool:
	return player.crucible_upgrade_target_level > 0 and player.crucible_upgrade_finish_unix > 0

func crucible_upgrade_seconds_remaining() -> int:
	if not crucible_is_upgrading():
		return 0
	var now: int = int(Time.get_unix_time_from_system())
	return max(0, player.crucible_upgrade_finish_unix - now)

func crucible_upgrade_is_fully_paid() -> bool:
	var req: int = crucible_required_payment_stages(player.crucible_level)
	return player.crucible_upgrade_paid_stages >= req

func crucible_pay_one_upgrade_stage() -> bool:
	# Disallow paying while timer running; gold is only the pre-requisite.
	if crucible_is_upgrading():
		inventory_event.emit("Upgrade already in progress.")
		return false

	var req: int = crucible_required_payment_stages(player.crucible_level)
	if player.crucible_upgrade_paid_stages >= req:
		inventory_event.emit("All payment stages completed.")
		return false

	var stage_index: int = player.crucible_upgrade_paid_stages
	var cost: int = crucible_stage_cost_gold(player.crucible_level, stage_index)

	if player.gold < cost:
		inventory_event.emit("Not enough gold.")
		return false

	player.gold -= cost
	player.crucible_upgrade_paid_stages += 1

	player_changed.emit() # SaveManager listens to this
	return true

func crucible_start_upgrade_timer() -> bool:
	if crucible_is_upgrading():
		inventory_event.emit("Upgrade already in progress.")
		return false

	if not crucible_upgrade_is_fully_paid():
		inventory_event.emit("Pay all upgrade stages first.")
		return false

	var current_level: int = player.crucible_level
	player.crucible_upgrade_target_level = current_level + 1

	var now: int = int(Time.get_unix_time_from_system())
	var seconds: int = crucible_upgrade_time_seconds(current_level)
	player.crucible_upgrade_finish_unix = now + seconds

	player_changed.emit() # SaveManager listens to this
	return true

func crucible_tick_upgrade_completion() -> void:
	if not crucible_is_upgrading():
		return

	var remaining: int = crucible_upgrade_seconds_remaining()
	if remaining > 0:
		return

	# Complete!
	var target: int = player.crucible_upgrade_target_level
	if target <= player.crucible_level:
		# Safety reset
		player.crucible_upgrade_paid_stages = 0
		player.crucible_upgrade_target_level = 0
		player.crucible_upgrade_finish_unix = 0
		player_changed.emit()
		return

	player.crucible_level = target

	# Reset upgrade state for next upgrade
	player.crucible_upgrade_paid_stages = 0
	player.crucible_upgrade_target_level = 0
	player.crucible_upgrade_finish_unix = 0

	inventory_event.emit("Crucible upgraded to Lv.%d" % player.crucible_level)
	player_changed.emit() # SaveManager listens to this

func can_use_time_voucher_on_crucible() -> bool:
	return crucible_is_upgrading() and player.time_vouchers > 0

func use_time_voucher_on_crucible(count: int = 1) -> int:
	if count <= 0:
		return 0
	if not crucible_is_upgrading():
		inventory_event.emit("No active upgrade to speed up.")
		return 0
	if player.time_vouchers <= 0:
		inventory_event.emit("No time vouchers available.")
		return 0

	var use_n: int = mini(count, int(player.time_vouchers))
	var now: int = int(Time.get_unix_time_from_system())

	var reduce: int = use_n * TIME_VOUCHER_SECONDS
	player.crucible_upgrade_finish_unix = max(now, player.crucible_upgrade_finish_unix - reduce)
	player.time_vouchers -= use_n

	player_changed.emit()
	crucible_tick_upgrade_completion()
	return use_n

func _battle_init_if_needed() -> void:
	if _battle_inited:
		return
	if player == null:
		return

	_battle_inited = true
	_battle_recompute_player_combat()

	battle_runtime["player_hp_max"] = _p_hp_max
	battle_runtime["player_hp"] = _p_hp_max

	_battle_spawn_enemy(true)

func _battle_on_player_changed() -> void:
	# Gear/level changes should immediately affect combat.
	_battle_recompute_player_combat()

	# If we have no HP set yet, initialize.
	if float(battle_runtime.get("player_hp_max", 0.0)) <= 0.0:
		battle_runtime["player_hp_max"] = _p_hp_max
		battle_runtime["player_hp"] = _p_hp_max

	battle_changed.emit()

func _battle_on_battle_state_changed() -> void:
	# If speed changed etc., just refresh UI.
	pass

func _battle_speed_multiplier() -> float:
	var idx: int = int(battle_state.get("speed_idx", 0))
	match idx:
		0: return 1.0
		1: return 3.0
		2: return 5.0
		3: return 10.0
	return 1.0

func _battle_process(delta: float) -> void:
	if not _battle_inited:
		return

	var dt: float = delta * _battle_speed_multiplier()

	_p_atk_accum += dt
	_e_atk_accum += dt

	var p_interval: float = 1.0 / max(0.1, _p_aps)
	var e_interval: float = 1.0 / max(0.1, _e_aps)

	while _p_atk_accum >= p_interval:
		_p_atk_accum -= p_interval
		_battle_player_attack()
		if float(battle_runtime["enemy_hp"]) <= 0.0:
			_battle_on_enemy_defeated()
			return

	while _e_atk_accum >= e_interval:
		_e_atk_accum -= e_interval
		_battle_enemy_attack()
		if float(battle_runtime["player_hp"]) <= 0.0:
			_battle_on_player_defeated()
			return

func _battle_player_attack() -> void:
	var dmg: float = _p_atk

	# Crit (crit chance is 0..1)
	if (RNG as RNGService).randf() < _p_crit:
		dmg *= 1.5

	# Combo: percent points; allow >100
	var cc: float = max(0.0, _p_combo) / 100.0
	var guaranteed: int = int(floor(cc))
	var extra_chance: float = cc - float(guaranteed)

	var hits: int = 1 + guaranteed
	if (RNG as RNGService).randf() < extra_chance:
		hits += 1

	var total: float = dmg
	if hits > 1:
		# extra hits at 50% damage (tune later)
		total += float(hits - 1) * (dmg * 0.5)

	var dealt: float = _apply_defense(total, _e_def)
	battle_runtime["enemy_hp"] = max(0.0, float(battle_runtime["enemy_hp"]) - dealt)

func _battle_enemy_attack() -> void:
	var dmg: float = _e_atk

	# Avoid (percent points)
	if (RNG as RNGService).randf() < (clamp(_p_avoid, 0.0, 100.0) / 100.0):
		return

	# Block (percent points) reduces damage heavily
	if (RNG as RNGService).randf() < (clamp(_p_block, 0.0, 100.0) / 100.0):
		dmg *= 0.30

	var dealt: float = _apply_defense(dmg, _p_def)
	battle_runtime["player_hp"] = max(0.0, float(battle_runtime["player_hp"]) - dealt)

func _apply_defense(raw: float, defense: float) -> float:
	# Diminishing returns: dmg * (100 / (100 + def))
	var d: float = max(0.0, defense)
	return max(1.0, raw * (100.0 / (100.0 + d)))

func _battle_on_enemy_defeated() -> void:
	# Reward based on the wave we just completed (before advancing)
	var diff: String = String(battle_state.get("difficulty", "Easy"))
	var lvl: int = int(battle_state.get("level", 1))
	var stg: int = int(battle_state.get("stage", 1))
	var wav: int = int(battle_state.get("wave", 1))
	var is_boss: bool = (wav == Catalog.BATTLE_WAVES_PER_STAGE)

	var gold_gain: int = Catalog.battle_wave_gold(diff, lvl, stg, wav, is_boss)
	var key_gain: int = Catalog.battle_wave_keys(diff, lvl, stg, wav, is_boss)

	add_gold(gold_gain)
	player.crucible_keys += key_gain
	player_changed.emit()

	# Advance progression using Catalog (tunable)
	var next: Dictionary = Catalog.battle_advance_progression(diff, lvl, stg, wav)
	patch_battle_state(next)

	# Full heal between waves for MVP
	battle_runtime["player_hp_max"] = _p_hp_max
	battle_runtime["player_hp"] = _p_hp_max

	_battle_spawn_enemy(true)

func _battle_on_player_defeated() -> void:
	# Reset to wave 1 and retry
	battle_state["wave"] = 1
	battle_changed.emit() # progression change; okay to save

	_p_atk_accum = 0.0
	_e_atk_accum = 0.0

	battle_runtime["player_hp_max"] = _p_hp_max
	battle_runtime["player_hp"] = _p_hp_max

	_battle_spawn_enemy(true)

func _battle_spawn_enemy(reset_hp: bool) -> void:
	var diff: String = String(battle_state.get("difficulty", "Easy"))
	var lvl: int = int(battle_state.get("level", 1))
	var stg: int = int(battle_state.get("stage", 1))
	var wav: int = int(battle_state.get("wave", 1))

	var is_boss: bool = (wav == Catalog.BATTLE_WAVES_PER_STAGE)
	battle_runtime["is_boss"] = is_boss

	# Simple scaling (tune later)
	var prog: float = float((lvl - 1) * Catalog.BATTLE_STAGES_PER_LEVEL + (stg - 1))
	var hp: float = 50.0 + prog * 10.0
	var atk: float = 6.0 + prog * 1.2
	var def: float = 0.0 + prog * 0.35

	if is_boss:
		hp *= 2.3
		atk *= 1.6
		def *= 1.1
		_e_aps = 0.7
	else:
		_e_aps = 0.9

	_e_atk = max(1.0, atk)
	_e_def = max(0.0, def)

	battle_runtime["enemy_hp_max"] = hp
	if reset_hp:
		battle_runtime["enemy_hp"] = hp

func _battle_recompute_player_combat() -> void:
	# Base values (tune later)
	var base_hp: float = 100.0 + float(player.level) * 5.0
	var base_atk: float = 10.0 + float(player.level) * 1.0
	var base_def: float = 3.0 + float(player.level) * 0.25

	var hp_add: float = 0.0
	var atk_add: float = 0.0
	var def_add: float = 0.0
	var atk_spd: float = 0.0

	var crit_pp: float = 0.0
	var combo_pp: float = 0.0
	var block_pp: float = 0.0
	var avoid_pp: float = 0.0

	for k in player.equipped.keys():
		var it: GearItem = player.equipped.get(k, null)
		if it == null or it.stats == null:
			continue
		var s: Stats = it.stats
		hp_add += float(s.hp)
		atk_add += float(s.atk)
		def_add += float(s.def)
		atk_spd += float(s.atk_spd)

		crit_pp += float(s.crit_chance)
		combo_pp += float(s.combo_chance)
		block_pp += float(s.block)
		avoid_pp += float(s.avoidance)

	_p_hp_max = max(1.0, base_hp + hp_add)
	_p_atk = max(1.0, base_atk + atk_add)
	_p_def = max(0.0, base_def + def_add)

	# APS: base 1.0, plus atk_spd (treat as additive percent like 0.05 = +5%)
	_p_aps = clamp(1.0 * (1.0 + atk_spd), 0.3, 10.0)

	_p_crit = clamp(crit_pp / 100.0, 0.0, 0.75)
	_p_combo = max(0.0, combo_pp)
	_p_block = clamp(block_pp, 0.0, 75.0)
	_p_avoid = clamp(avoid_pp, 0.0, 60.0)

func _battle_advance_progression() -> void:
	var diff: String = String(battle_state.get("difficulty", "Easy"))
	var lvl: int = int(battle_state.get("level", 1))
	var stage: int = int(battle_state.get("stage", 1))
	var wave: int = int(battle_state.get("wave", 1))

	var next: Dictionary = Catalog.battle_advance_progression(diff, lvl, stage, wave)

	battle_state["difficulty"] = String(next["difficulty"])
	battle_state["level"] = int(next["level"])
	battle_state["stage"] = int(next["stage"])
	battle_state["wave"] = int(next["wave"])
