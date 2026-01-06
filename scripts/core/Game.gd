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
	"enemy_name": "",
	"is_boss": false,
	"last_event": "",
}
var _battle_inited: bool = false
var _player_atk_accum: float = 0.0
var _enemy_atk_accum: float = 0.0

# Cached combat numbers (recomputed when player changes gear/level)
var _p_hp_max: float = 1.0
var _p_atk: float = 1.0
var _p_def: float = 0.0
var _p_attacks_per_sec: float = 1.0
var _p_crit_chance: float = 0.05        # 5%
var _p_crit_mult: float = 1.5           # 150% default per spec
var _p_combo_chance: float = 0.0        # percent points (e.g. 10 = 10%)
var _p_combo_mult: float = 0.5          # 50% default per spec
var _p_block_chance: float = 0.0        # percent
var _p_avoid_chance: float = 0.0        # percent
var _p_counter_chance: float = 0.0      # percent
var _p_counter_mult: float = 0.10       # 10% default reflect per spec

# Enemy
var _e_atk: float = 1.0
var _e_attacks_per_sec: float = 0.8
var _e_def: float = 0.0

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
	_battle_spawn_enemy(true)
	battle_changed.emit()

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
	if player == null:
		return
	if not _battle_inited:
		return

	var speed: float = _battle_speed_multiplier()
	var dt: float = delta * speed

	# Regen can be added later; MVP: no regen (or tiny). Spec includes regen but can be low.
	# battle_runtime["player_hp"] = min(_p_hp_max, float(battle_runtime["player_hp"]) + dt * 0.0)

	_player_atk_accum += dt
	_enemy_atk_accum += dt

	var p_interval: float = 1.0 / max(0.1, _p_attacks_per_sec)
	var e_interval: float = 1.0 / max(0.1, _e_attacks_per_sec)

	while _player_atk_accum >= p_interval:
		_player_atk_accum -= p_interval
		_battle_player_attack()
		if float(battle_runtime["enemy_hp"]) <= 0.0:
			_battle_on_enemy_defeated()
			return

	while _enemy_atk_accum >= e_interval:
		_enemy_atk_accum -= e_interval
		_battle_enemy_attack()
		if float(battle_runtime["player_hp"]) <= 0.0:
			_battle_on_player_defeated()
			return

func _battle_player_attack() -> void:
	var dmg: float = _p_atk

	# Crit
	var r: float = (RNG as RNGService).randf()
	if r < _p_crit_chance:
		dmg *= _p_crit_mult

	# Combo: supports >100% per spec
	# combo chance stored as percent points (e.g. 150 = always 2 hits, 50% for 3rd)
	var cc: float = max(0.0, _p_combo_chance) / 100.0
	var guaranteed: int = int(floor(cc))
	var extra_chance: float = cc - float(guaranteed)

	var hits: int = 1 + guaranteed
	if (RNG as RNGService).randf() < extra_chance:
		hits += 1

	var total: float = dmg
	if hits > 1:
		# extra hits do reduced damage (default 50% unless you add combo dmg stat later)
		total += float(hits - 1) * (dmg * _p_combo_mult)

	# Apply enemy mitigation
	var mitigated: float = _apply_defense(total, _e_def)
	battle_runtime["enemy_hp"] = max(0.0, float(battle_runtime["enemy_hp"]) - mitigated)

func _battle_enemy_attack() -> void:
	var dmg: float = _e_atk

	# Avoidance first
	if (RNG as RNGService).randf() < (_p_avoid_chance / 100.0):
		return

	# Block reduces major portion
	if (RNG as RNGService).randf() < (_p_block_chance / 100.0):
		dmg *= 0.30

	# Apply player mitigation
	var mitigated: float = _apply_defense(dmg, _p_def)
	battle_runtime["player_hp"] = max(0.0, float(battle_runtime["player_hp"]) - mitigated)

	# Counterstrike: reflect portion of incoming mitigated damage
	if (RNG as RNGService).randf() < (_p_counter_chance / 100.0):
		var reflect: float = mitigated * _p_counter_mult
		battle_runtime["enemy_hp"] = max(0.0, float(battle_runtime["enemy_hp"]) - reflect)

func _apply_defense(raw: float, defense: float) -> float:
	# Simple diminishing returns mitigation
	# dmg * (100 / (100 + def))
	var denom: float = 100.0 + max(0.0, defense)
	return max(1.0, raw * (100.0 / denom))

func _battle_on_enemy_defeated() -> void:
	# Rewards: gold every wave; keys primarily from bosses (your doc says keys from waves/tasks/events)
	# Boss = wave 5.
	var is_boss: bool = bool(battle_runtime.get("is_boss", false))

	var lvl: int = int(battle_state.get("level", 1))
	var stage: int = int(battle_state.get("stage", 1))
	var wave: int = int(battle_state.get("wave", 1))

	var gold_gain: int = 5 + (lvl - 1) * 3 + (stage - 1) * 2 + (wave - 1)
	add_gold(gold_gain)

	if is_boss:
		player.crucible_keys += 1
		player_changed.emit()

	# Advance wave/stage/level/difficulty per spec
	_battle_advance_progression()

	# Start next wave with full HP for MVP (keeps the failure loop clean)
	battle_runtime["player_hp_max"] = _p_hp_max
	battle_runtime["player_hp"] = _p_hp_max
	_battle_spawn_enemy(true)

	battle_changed.emit()

func _battle_on_player_defeated() -> void:
	# Spec: on fail, reset to wave 1 and keep retrying until pass. :contentReference[oaicite:1]{index=1}
	battle_state["wave"] = 1
	_player_atk_accum = 0.0
	_enemy_atk_accum = 0.0

	battle_runtime["player_hp_max"] = _p_hp_max
	battle_runtime["player_hp"] = _p_hp_max
	_battle_spawn_enemy(true)

	battle_changed.emit()

func _battle_advance_progression() -> void:
	var wave: int = int(battle_state.get("wave", 1))
	var stage: int = int(battle_state.get("stage", 1))
	var lvl: int = int(battle_state.get("level", 1))
	var diff: String = String(battle_state.get("difficulty", "Easy"))

	wave += 1
	if wave > 5:
		wave = 1
		stage += 1
		if stage > 10:
			stage = 1
			lvl += 1
			if lvl > 10:
				lvl = 1
				# Extend later with additional difficulties
				diff = "Hard" if diff == "Easy" else diff

	battle_state["wave"] = wave
	battle_state["stage"] = stage
	battle_state["level"] = lvl
	battle_state["difficulty"] = diff

func _battle_spawn_enemy(reset_hp: bool) -> void:
	var diff: String = String(battle_state.get("difficulty", "Easy"))
	var lvl: int = int(battle_state.get("level", 1))
	var stage: int = int(battle_state.get("stage", 1))
	var wave: int = int(battle_state.get("wave", 1))

	var is_boss: bool = (wave == 5)
	battle_runtime["is_boss"] = is_boss
	battle_runtime["enemy_name"] = "Boss" if is_boss else "Monster"

	# Difficulty tier
	var diff_mult: float = 1.0
	if diff == "Hard":
		diff_mult = 1.8

	# Baseline scaling — tune freely
	var prog: float = float((lvl - 1) * 10 + (stage - 1))
	var hp: float = (40.0 + prog * 8.0) * diff_mult
	var atk: float = (4.0 + prog * 0.9) * diff_mult
	var def: float = (0.0 + prog * 0.25) * diff_mult

	# Boss multipliers; stage 5 and 10 bosses are tougher per spec :contentReference[oaicite:2]{index=2}
	if is_boss:
		var boss_mult: float = 2.0
		if stage == 5:
			boss_mult = 2.4
		elif stage == 10:
			boss_mult = 2.8
			if lvl == 10 and diff == "Easy":
				boss_mult = 3.4 # gateway boss (Easy 10-10)
		hp *= boss_mult
		atk *= boss_mult
		def *= 1.15

	# Enemy attack speed: mobs faster, bosses slower but harder
	_e_attacks_per_sec = 0.9 if not is_boss else 0.7
	_e_atk = max(1.0, atk)
	_e_def = max(0.0, def)

	battle_runtime["enemy_hp_max"] = hp
	if reset_hp:
		battle_runtime["enemy_hp"] = hp

func _battle_recompute_player_combat() -> void:
	# Base stats by class (tune later)
	var base_hp: float = 100.0
	var base_atk: float = 10.0
	var base_def: float = 3.0

	match int(player.class_id):
		PlayerModel.ClassId.WARRIOR:
			base_hp = 120.0
			base_atk = 9.0
			base_def = 4.0
		PlayerModel.ClassId.MAGE:
			base_hp = 90.0
			base_atk = 12.0
			base_def = 2.0
		PlayerModel.ClassId.ARCHER:
			base_hp = 105.0
			base_atk = 10.0
			base_def = 3.0

	var plvl: int = int(player.level)
	base_hp += float(plvl) * 5.0
	base_atk += float(plvl) * 0.9
	base_def += float(plvl) * 0.25

	# Sum gear stats
	var hp_add: float = 0.0
	var atk_add: float = 0.0
	var def_add: float = 0.0
	var str_add: float = 0.0
	var int_add: float = 0.0
	var agi_add: float = 0.0
	var atk_spd_bonus: float = 0.0

	var crit_ch: float = 0.0
	var combo_ch: float = 0.0
	var block_ch: float = 0.0
	var avoid_ch: float = 0.0
	var counter_ch: float = 0.0

	for slot_id in player.equipped.keys():
		var it: GearItem = player.equipped.get(slot_id, null)
		if it == null:
			continue
		var s: Stats = it.stats
		if s == null:
			continue

		hp_add += float(s.hp)
		atk_add += float(s.atk)
		def_add += float(s.def)
		str_add += float(s.str)
		int_add += float(s.int_)
		agi_add += float(s.agi)
		atk_spd_bonus += float(s.atk_spd)

		crit_ch += float(s.crit_chance)
		combo_ch += float(s.combo_chance)
		block_ch += float(s.block)
		avoid_ch += float(s.avoidance)
		counter_ch += float(s.counter_chance)

	# STR adds HP for all classes per spec; main stat scales damage for that class :contentReference[oaicite:3]{index=3}
	var hp_total: float = base_hp + hp_add + (str_add * 5.0)
	var atk_total: float = base_atk + atk_add
	var def_total: float = base_def + def_add

	var dmg_scale: float = 1.0
	match int(player.class_id):
		PlayerModel.ClassId.WARRIOR:
			dmg_scale += str_add * 0.01
		PlayerModel.ClassId.MAGE:
			dmg_scale += int_add * 0.01
		PlayerModel.ClassId.ARCHER:
			dmg_scale += agi_add * 0.01

	atk_total *= dmg_scale

	# Attack speed: base 1.0 aps, bonus from AGI + gear
	# Treat atk_spd as percent bonus (0.05 = +5%).
	var aps: float = 1.0 * (1.0 + atk_spd_bonus + (agi_add * 0.002))
	aps = clamp(aps, 0.3, 10.0)

	_p_hp_max = max(1.0, hp_total)
	_p_atk = max(1.0, atk_total)
	_p_def = max(0.0, def_total)
	_p_attacks_per_sec = aps

	# Convert percent-point stats to probabilities
	_p_crit_chance = clamp(crit_ch / 100.0, 0.0, 0.75)
	_p_combo_chance = max(0.0, combo_ch)
	_p_block_chance = clamp(block_ch, 0.0, 75.0)
	_p_avoid_chance = clamp(avoid_ch, 0.0, 60.0)
	_p_counter_chance = clamp(counter_ch, 0.0, 60.0)

	# Keep runtime HP in sync if max increases (don’t heal to full automatically unless you want that)
	var cur_hp: float = float(battle_runtime.get("player_hp", 0.0))
	var cur_max: float = float(battle_runtime.get("player_hp_max", 0.0))
	if cur_max <= 0.0:
		battle_runtime["player_hp_max"] = _p_hp_max
		battle_runtime["player_hp"] = _p_hp_max
	else:
		var pct: float = cur_hp / max(1.0, cur_max)
		battle_runtime["player_hp_max"] = _p_hp_max
		battle_runtime["player_hp"] = clamp(pct * _p_hp_max, 1.0, _p_hp_max)
