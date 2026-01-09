extends Node
#class_name Game

signal player_changed
signal inventory_event(message:String)
signal battle_changed

signal combat_log_added(line: String)

signal combat_log_entry_added(entry: Dictionary)
signal combat_log_cleared

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
	"status_text": "",
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

#Damage multipliers derived from stats
var _p_crit_mult: float = 1.5          # default: 50% crit damage
var _p_combo_extra_mult: float = 0.5   # default: extra hit does 50% damage
var _p_regen: float = 0.0              #HP per second
var _p_skill_cd_mult: float = 1.0      # multiplier on skill cooldown, INT reduces this

# Cache of players computed total stats (so skills can scale off STR/INT/AGI, etc.)
var _p_stats: Stats = null

# Active skill cooldown runtime (skill_id -> remaining seconds)
var _skill_cd: Dictionary = {}

# Enemy combat
var _e_atk: float = 1.0
var _e_def: float = 0.0
var _e_aps: float = 0.8

var _defeat_pause_remaining: float = 0.0
const DEFEAT_PAUSE_SECONDS: float = 1.5

const COMBAT_LOG_MAX_LINES: int = 120
var combat_log: Array[String] = []
const COMBAT_LOG_MAX_ENTRIES: int = 200
var combat_log_entries: Array[Dictionary] = []

# User toggle; effective compact mode will also auto-enable at high speed
var _combat_log_compact_user: bool = false

# Aggregation buffers (used when compact mode is effective)
var _agg_player_hits: Dictionary = {"count": 0, "dmg": 0, "crits": 0, "combos": 0}
var _agg_enemy_hits: Dictionary = {"count": 0, "dmg": 0, "blocks": 0, "avoids": 0}
var _agg_rewards: Dictionary = {"gold": 0, "keys": 0, "waves": 0, "boss_waves": 0}
var _agg_flush_accum: float = 0.0
const AGG_FLUSH_INTERVAL: float = 0.35

#===================================================================================================

const TIME_VOUCHER_SECONDS: int = 5 * 60 # 5 minutes

#===================================================================================================

func _ready() -> void:
	SaveManager.load_or_new()
	SaveManager.init_autosave_hooks()
	
	player_changed.connect(_battle_on_player_changed)

	if not class_selection_needed():
		_battle_init_if_needed()
	
	crucible_tick_upgrade_completion()

func class_selection_needed() -> bool:
	if player == null:
		return true
	if int(player.class_id) < 0:
		return true

	# Advanced class pending?
	var cid := ""
	if player.has_method("ensure_class_and_skills_initialized"):
		player.ensure_class_and_skills_initialized()
	cid = String(player.get("class_def_id"))
	if cid != "":
		var pending: Array[ClassDef] = ClassCatalog.next_choices(cid, int(player.level))
		if not pending.is_empty():
			return true

	return false


func _process(delta: float) -> void:
	_upgrade_check_accum += delta
	if _upgrade_check_accum >= 1.0:
		_upgrade_check_accum = 0.0
		crucible_tick_upgrade_completion()
	if not class_selection_needed():
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
	# stage_index intentionally ignored: all stages within a level cost the same.
	return Catalog.crucible_upgrade_stage_cost_gold(current_level)

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
	_skills_sync_loadout()

	battle_runtime["player_hp_max"] = _p_hp_max
	battle_runtime["player_hp"] = _p_hp_max

	_battle_spawn_enemy(true)

func _battle_on_player_changed() -> void:
	if class_selection_needed():
		# Don’t recompute battle stats or touch battle runtime until a class is chosen.
		return
	# Gear/level changes should immediately affect combat.
	_battle_recompute_player_combat()
	_skills_sync_loadout()

	# Update max HP and clamp current HP
	battle_runtime["player_hp_max"] = _p_hp_max
	battle_runtime["player_hp"] = clamp(float(battle_runtime.get("player_hp")), 0.0, _p_hp_max)

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
		
	# If defeated, freeze battle briefly so UI can show 0 HP.
	if _defeat_pause_remaining > 0.0:
		_defeat_pause_remaining -= delta  # unscaled real-time
		if _defeat_pause_remaining <= 0.0:
			_finish_defeat_reset()
		return

	var dt: float = delta * _battle_speed_multiplier()
	
	# Accumulate real-time for aggregation flush
	_agg_flush_accum += delta
	if combat_log_compact_effective():
		_combat_log_flush(false)
		
	# Regen tick (scaled by battle speed)
	if _p_regen > 0.0 and float(battle_runtime.get("player_hp", 0.0)) > 0.0:
		var nhp: float = float(battle_runtime["player_hp"]) + (_p_regen * dt)
		battle_runtime["player_hp"] = clamp(nhp, 0.0, _p_hp_max)


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
	var was_crit: bool = false
	var hits: int = 1

	var dmg: float = _p_atk

	# Crit
	if (RNG as RNGService).randf() < _p_crit:
		was_crit = true
		dmg *= _p_crit_mult

	# Combo (percent points; allow >100)
	var cc: float = max(0.0, _p_combo) / 100.0
	var guaranteed: int = int(floor(cc))
	var extra_chance: float = cc - float(guaranteed)

	hits = 1 + guaranteed
	if (RNG as RNGService).randf() < extra_chance:
		hits += 1

	var total: float = dmg
	if hits > 1:
		total += (dmg * _p_combo_extra_mult) # extra hits scale with combo dmg

	var dealt: float = _apply_defense(total, _e_def)
	battle_runtime["enemy_hp"] = max(0.0, float(battle_runtime["enemy_hp"]) - dealt)

	# --- Combat log line ---
	if combat_log_compact_effective():
		_agg_player_hits["count"] = int(_agg_player_hits["count"]) + 1
		_agg_player_hits["dmg"] = int(_agg_player_hits["dmg"]) + int(round(dealt))
		if was_crit: _agg_player_hits["crits"] = int(_agg_player_hits["crits"]) + 1
		if hits > 1: _agg_player_hits["combos"] = int(_agg_player_hits["combos"]) + 1
	else:
		var tags: Array[String] = []
		if was_crit: tags.append("CRIT")
		if hits > 1: tags.append("COMBO x%d" % hits)
		var tag_txt: String = ""
		if tags.size() > 0:
			tag_txt = " [color=#FFD24A](%s)[/color]" % ", ".join(tags)

		var sev: String = "normal"
		if was_crit: sev = "crit"
		elif hits > 1: sev = "combo"

		log_combat("player", sev, "[color=#7CFF7C]You[/color] hit for [b]%d[/b]%s" % [int(round(dealt)), tag_txt])

func _battle_enemy_attack() -> void:
	var dmg: float = _e_atk

	# Avoid
	if (RNG as RNGService).randf() < (clamp(_p_avoid, 0.0, 100.0) / 100.0):
		if combat_log_compact_effective():
			_agg_enemy_hits["avoids"] = int(_agg_enemy_hits["avoids"]) + 1
		else:
			log_combat("enemy", "avoid", "[color=#FF8A8A]Enemy[/color] attacks — [color=#7FB0FF](AVOID)[/color]")
		return

	var blocked: bool = false
	if (RNG as RNGService).randf() < (clamp(_p_block, 0.0, 100.0) / 100.0):
		blocked = true
		dmg *= 0.30

	var dealt: float = _apply_defense(dmg, _p_def)
	battle_runtime["player_hp"] = max(0.0, float(battle_runtime["player_hp"]) - dealt)

	var tag_txt: String = ""
	if blocked:
		tag_txt = " [color=#7FB0FF](BLOCK)[/color]"

	if combat_log_compact_effective():
		_agg_enemy_hits["count"] = int(_agg_enemy_hits["count"]) + 1
		_agg_enemy_hits["dmg"] = int(_agg_enemy_hits["dmg"]) + int(round(dealt))
		if blocked: _agg_enemy_hits["blocks"] = int(_agg_enemy_hits["blocks"]) + 1
	else:
		tag_txt = ""
		var sev: String = "normal"
		if blocked:
			tag_txt = " [color=#7FB0FF](BLOCK)[/color]"
			sev = "block"
		log_combat("enemy", sev, "[color=#FF8A8A]Enemy[/color] hit you for [b]%d[/b]%s" % [int(round(dealt)), tag_txt])

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

	var gold_gain: int = Catalog.battle_gold_for_wave(diff, lvl, stg, wav, is_boss)
	var key_gain: int = Catalog.battle_keys_for_wave(diff, lvl, stg, wav, is_boss)

	add_gold(gold_gain)
	player.crucible_keys += key_gain
	player_changed.emit()
	
	if combat_log_compact_effective():
		_agg_rewards["gold"] = int(_agg_rewards["gold"]) + gold_gain
		_agg_rewards["keys"] = int(_agg_rewards["keys"]) + key_gain
		_agg_rewards["waves"] = int(_agg_rewards["waves"]) + 1
		if is_boss:
			_agg_rewards["boss_waves"] = int(_agg_rewards["boss_waves"]) + 1
	else:
		log_combat("reward", "reward",
			"[color=#CFCFCF]Wave cleared[/color]%s — +%d gold, +%d keys" % [
				(" [color=#FFD24A](BOSS)[/color]" if is_boss else ""),
				gold_gain,
				key_gain
			]
		)
	# Advance progression using Catalog (tunable)
	var next: Dictionary = Catalog.battle_advance_progression(diff, lvl, stg, wav)
	
	# OPTIONAL: flush any compact aggregation before we potentially wipe
	if combat_log_compact_effective():
		_combat_log_flush(true)

	# Clear combat log when finishing boss wave and moving to next stage
	if is_boss:
		clear_combat_log()
		# (Optional) add a header line so the new stage isn’t “silent”
		log_combat("system", "system",
			"[color=#CFCFCF]Entering[/color] %s - Lv %d - Stage %d" % [
				String(next.get("difficulty", diff)),
				int(next.get("level", lvl)),
				int(next.get("stage", stg + 1))
			]
		)
	
	patch_battle_state(next)

	# Full heal between waves for MVP
	battle_runtime["player_hp_max"] = _p_hp_max
	battle_runtime["player_hp"] = _p_hp_max
	_combat_log_flush(true)
	_battle_spawn_enemy(true)

func _battle_on_player_defeated() -> void:
	# Set HP to 0 and pause so UI can show defeat.
	battle_runtime["player_hp"] = 0.0
	battle_runtime["status_text"] = "Defeated!"
	_defeat_pause_remaining = DEFEAT_PAUSE_SECONDS
	if combat_log_compact_effective():
		_combat_log_flush(true)
	log_combat("system", "defeat", "[color=#FF4444][b]Defeated![/b][/color]")

	# Stop any accumulated swings from firing immediately after reset.
	_p_atk_accum = 0.0
	_e_atk_accum = 0.0

	# Emit once so label updates immediately if you’re also signal-driven.
	battle_changed.emit()
	_battle_spawn_enemy(true)

func _battle_spawn_enemy(reset_hp: bool) -> void:
	var diff: String = String(battle_state.get("difficulty", "Easy"))
	var lvl: int = int(battle_state.get("level", 1))
	var stg: int = int(battle_state.get("stage", 1))
	var wav: int = int(battle_state.get("wave", 1))

	var is_boss: bool = (wav == Catalog.BATTLE_WAVES_PER_STAGE)
	battle_runtime["is_boss"] = is_boss

	var m: Dictionary = Catalog.battle_enemy_multipliers(diff, lvl, stg, wav, is_boss)

	var hp: float = Catalog.ENEMY_BASE_HP * float(m["hp"])
	var atk: float = Catalog.ENEMY_BASE_ATK * float(m["atk"])
	var def: float = Catalog.ENEMY_BASE_DEF * float(m["def"])

	battle_runtime["enemy_hp_max"] = hp
	if reset_hp:
		battle_runtime["enemy_hp"] = hp

	_e_atk = max(1.0, atk)
	_e_def = max(0.0, def)

	# If you tune enemy attack speed elsewhere, keep your existing logic:
	# _e_aps = is_boss ? 0.7 : 0.9

func _battle_recompute_player_combat() -> void:
	# Use the player's full stat pipeline (base class + class node + skills + gear + synergies).
	_p_stats = player.total_stats()
	
	_p_hp_max = max(1.0, float(_p_stats.hp))
	_p_atk = max(1.0, float(_p_stats.atk))
	_p_def = max(0.0, float(_p_stats.def))
	
	# APS: base 1.0, plus atk_spd (treat as additive percent like 0.05 = +5%)
	_p_aps = clamp(1.0 * (1.0 + float(_p_stats.atk_spd)), 0.3, 10.0)
	
	_p_crit = clamp(float(_p_stats.crit_chance) / 100.0, 0.0, 0.75)
	_p_combo = max(0.0, float(_p_stats.combo_chance))
	_p_block = clamp(float(_p_stats.block), 0.0, 75.0)
	_p_avoid = clamp(float(_p_stats.avoidance), 0.0, 60.0)
	
	_p_regen = max(0.0, float(_p_stats.regen))
	
	# Crit and combo damage are stored as percent points.
	# Baselines: crit bonus +50%, combo extra hits deal 50%.
	_p_crit_mult = 1.0 + 0.5 + (clamp(float(_p_stats.crit_dmg), 0.0, 500.0) / 100.0)
	_p_combo_extra_mult = 0.5 + (clamp(float(_p_stats.combo_dmg), 0.0, 500.0) / 100.0)
	
	# INT reduces skill cooldowns (linear reduction, clamped).
	_p_skill_cd_mult = _compute_skill_cd_mult(float(_p_stats.int_))

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

func dev_set_battle_position(diff: String, level: int, stage: int, wave: int) -> void:
	patch_battle_state({
		"difficulty": diff,
		"level": level,
		"stage": stage,
		"wave": wave,
	})

	# Force battle runtime to reinitialize to the new state
	_battle_inited = false
	_p_atk_accum = 0.0
	_e_atk_accum = 0.0
	_battle_init_if_needed()

	# Request save if your Game exposes it (or SaveManager hooks will catch battle_changed)
	if has_method("request_save"):
		call("request_save")

func _finish_defeat_reset() -> void:
	_defeat_pause_remaining = 0.0
	battle_runtime["status_text"] = ""

	# Reset to wave 1 and retry
	battle_state["wave"] = 1
	battle_changed.emit() # progression changed (autosave ok)

	# Restore player HP and respawn enemy for the reset wave
	_battle_recompute_player_combat()
	battle_runtime["player_hp_max"] = _p_hp_max
	battle_runtime["player_hp"] = _p_hp_max
	clear_combat_log()
	_battle_spawn_enemy(true)

#func log_combat(line: String) -> void:
	#combat_log.append(line)
	#if combat_log.size() > COMBAT_LOG_MAX_LINES:
		#combat_log.pop_front()
	#combat_log_added.emit(line)

func combat_log_text() -> String:
	return "\n".join(combat_log)

func set_combat_log_compact_user(enabled: bool) -> void:
	_combat_log_compact_user = enabled

func combat_log_compact_effective() -> bool:
	# Auto-compact at high speed (>= 5x), or if user explicitly enabled it.
	if _combat_log_compact_user:
		return true
	return _battle_speed_multiplier() >= 5.0

func clear_combat_log() -> void:
	combat_log_entries.clear()
	combat_log_cleared.emit()

func get_combat_log_entries() -> Array[Dictionary]:
	# Return a shallow copy so UI can iterate safely.
	return combat_log_entries.duplicate()

func _log_add(category: String, severity: String, bbcode_line: String) -> void:
	var entry := {
		"t": Time.get_ticks_msec(),
		"cat": category,      # "player" | "enemy" | "reward" | "system"
		"sev": severity,      # "normal" | "crit" | "combo" | "block" | "avoid" | "defeat" | "reward" | "system"
		"bb": bbcode_line,
	}
	combat_log_entries.append(entry)
	if combat_log_entries.size() > COMBAT_LOG_MAX_ENTRIES:
		combat_log_entries.pop_front()
	combat_log_entry_added.emit(entry)

func log_combat(category: String, severity: String, message_bbcode: String) -> void:
	# This is the public API battle code calls.
	# message_bbcode should NOT include trailing newline.
	_log_add(category, severity, message_bbcode)

func _combat_log_flush(force: bool) -> void:
	# Flush aggregated lines if anything pending.
	if not force and _agg_flush_accum < AGG_FLUSH_INTERVAL:
		return

	_agg_flush_accum = 0.0

	# Player hits
	if int(_agg_player_hits["count"]) > 0:
		var c: int = int(_agg_player_hits["count"])
		var dmg: int = int(_agg_player_hits["dmg"])
		var crits: int = int(_agg_player_hits["crits"])
		var combos: int = int(_agg_player_hits["combos"])

		var tags: Array[String] = []
		if crits > 0: tags.append("CRIT x%d" % crits)
		if combos > 0: tags.append("COMBO x%d" % combos)
		var tag_txt: String = ""
		if tags.size() > 0:
			tag_txt = " [color=#FFD24A](%s)[/color]" % ", ".join(tags)

		log_combat("player", "normal", "[color=#7CFF7C]You[/color] dealt [b]%d[/b] damage (%d hits)%s" % [dmg, c, tag_txt])

		_agg_player_hits = {"count": 0, "dmg": 0, "crits": 0, "combos": 0}

	# Enemy hits
	if int(_agg_enemy_hits["count"]) > 0 or int(_agg_enemy_hits["avoids"]) > 0:
		var hits: int = int(_agg_enemy_hits["count"])
		var dmg2: int = int(_agg_enemy_hits["dmg"])
		var blocks: int = int(_agg_enemy_hits["blocks"])
		var avoids: int = int(_agg_enemy_hits["avoids"])

		var parts: Array[String] = []
		if hits > 0:
			parts.append("hit for [b]%d[/b] (%d hits)" % [dmg2, hits])
		if blocks > 0:
			parts.append("[color=#7FB0FF]BLOCK x%d[/color]" % blocks)
		if avoids > 0:
			parts.append("[color=#7FB0FF]AVOID x%d[/color]" % avoids)

		log_combat("enemy", "normal", "[color=#FF8A8A]Enemy[/color] %s" % " | ".join(parts))

		_agg_enemy_hits = {"count": 0, "dmg": 0, "blocks": 0, "avoids": 0}

	# Rewards
	if int(_agg_rewards["waves"]) > 0:
		var g: int = int(_agg_rewards["gold"])
		var k: int = int(_agg_rewards["keys"])
		var w: int = int(_agg_rewards["waves"])
		var bw: int = int(_agg_rewards["boss_waves"])

		var boss_txt: String = ""
		if bw > 0:
			boss_txt = " [color=#FFD24A](Boss clears: %d)[/color]" % bw

		log_combat("reward", "reward", "[color=#CFCFCF]Rewards[/color]: +%d gold, +%d keys (%d waves)%s" % [g, k, w, boss_txt])

		_agg_rewards = {"gold": 0, "keys": 0, "waves": 0, "boss_waves": 0}

# ----------------- Skills (MVP) -----------------

func _compute_skill_cd_mult(int_value: float) -> float:
	# each 1 int reduces cooldown by 1% to a max reduction of 60%
	return clamp(1.0 - (max(0.0, int_value) * 0.01), 0.40, 1.0)

func _skills_sync_loadout() -> void:
	if player == null:
		return
	player.ensure_class_and_skills_initialized()
	
	# Remove cooldown entries that no longer exist
	var keep := {}
	for sid in player.equipped_active_skills:
		keep[String(sid)] = true
		
	for k in _skill_cd.keys():
		if not keep.has(String(k)):
			_skill_cd.erase(k)
			
	# Ensure cooldown entries exist for all equipped skills
	for sid in player.equipped_active_skills:
		var id: String = String(sid)
		if not _skill_cd.has(id):
			_skill_cd[id] = 0.0
			
func _battle_process_skills(dt: float) -> void:
	if player == null:
		return
	if player.equipped_active_skills.is_empty():
		return
	if float(battle_runtime.get("enemy_hp", 0.0)) <= 0.0:
		return
		
	# Tick cooldowns and cast ready skills.
	# Safety cap to avoid huge multi-cast loops at high dt
	var casts_left: int = 8
	
	for sid in player.equipped_active_skills:
		if casts_left <= 0:
			break
		var id: String = String(sid)
		var sd: SkillDef = SkillCatalog.get_def(id)
		if sd == null or sd.type != SkillDef.SkillType.ACTIVE:
			continue
		
		var cd_left: float = float(_skill_cd.get(id, 0.0)) - dt
		_skill_cd[id] = cd_left
		
		if cd_left > 0.0:
			continue
			
		# Cast now
		_battle_cast_skill(sd)
		
		# Reset cooldown; if cd_left is negative, carry it forward so long dt doesn't lose time
		var cd_reset: float = max(0.25, float(sd.base_cooldown) * _p_skill_cd_mult)
		_skill_cd[id] = cd_reset + cd_left
		casts_left -= 1
		
func _battle_cast_skill(sd: SkillDef) -> void:
	if sd == null:
		return
		
	var lvl: int = maxi(1, player.get_skill_level(sd.id))
	
	# Basic damage formula:
	# damage = power(level) + scaling_stat * scaling_mult
	var raw: float = float(sd.power(lvl))
	raw+= _skill_get_stat_value(sd.scaling_stat) * float(sd.scaling_mult)
	
	if sd.target == SkillDef.Target.SELF:
		# MVP treat SELF skills as heal. (You can add real effect types later)
		var healed: float = raw
		battle_runtime["player_hp"] = clamp(float(battle_runtime["player_hp"]) + healed, 0.0, _p_hp_max)
		log_combat("player", "system", "[color=#7CFF7C]You[/color] cast [b]%s[/b] and healed [b]%d[/b]" % [sd.display_name, int(round(healed))])
		return
		
	# Enemy-targeted skill
	var was_crit: bool = false
	var dmg: float = raw
	if sd.can_crit and (RNG as RNGService).randf() < _p_crit:
		was_crit = true
		dmg *= _p_crit_mult
		
	var dealt: float = _apply_defense(dmg, _e_def)
	battle_runtime["enemy_hp"] = max(0.0, float(battle_runtime["enemy_hp"]) - dealt)
	
	var sev: String = "normal"
	if was_crit:
		sev = "crit"
	
	log_combat("player", sev, "[color=#7CFF7C]You[/color] cast [b]%s[/b] for [b]%d[/b]%s" % [
		sd.display_name,
		int(round(dealt)),
		(" [color=#FFD24A](CRIT)[/color]" if was_crit else "")
	])

func _skill_get_stat_value(stat_name: String) -> float:
	if _p_stats == null:
		return 0.0
	match stat_name:
		"atk": return float(_p_stats.atk)
		"str": return float(_p_stats.str)
		"int": return float(_p_stats.int_)
		"agi": return float(_p_stats.agi)
		"def": return float(_p_stats.def)
		"hp": return float(_p_stats.hp)
	return 0.0

func _fmt_duration_short(seconds: int) -> String:
	seconds = maxi(0, seconds)
	var m: int = seconds / 60
	var s: int = seconds % 60
	var h: int = m / 60
	m = m % 60
	if h > 0:
		return "%dh %dm" % [h, m]
	if m > 0:
		return "%dm %ds" % [m, s]
	return "%ds" % s

func apply_offline_rewards_on_load() -> Dictionary:
	if player == null:
		return {"applied": false}

	var now_unix: int = int(Time.get_unix_time_from_system())
	var last_unix: int = int(player.last_active_unix)

	if last_unix <= 0:
		player.last_active_unix = now_unix
		return {"applied": false}

	var dt: int = now_unix - last_unix
	if dt <= 0:
		player.last_active_unix = now_unix
		return {"applied": false}

	# Dynamic cap based on entitlements
	var cap: int = Catalog.offline_cap_seconds_for_player(player, now_unix)
	var capped: int = mini(dt, cap)

	if capped < 30:
		player.last_active_unix = now_unix
		return {"applied": false}

	# IMPORTANT: offline rewards depend only on difficulty + level
	var diff: String = String(battle_state.get("difficulty", "Easy"))
	var lvl: int = int(battle_state.get("level", 1))

	var sim: Dictionary = Catalog.offline_simulate_rewards(player.level, diff, lvl, capped)

	var gold_gain: int = int(sim.get("gold", 0))
	var key_gain: int = int(sim.get("keys", 0))
	var xp_gain: int = int(sim.get("xp", 0))

	if gold_gain != 0:
		player.gold += gold_gain
	if key_gain != 0:
		player.crucible_keys += key_gain

	var levels: int = 0
	if xp_gain > 0:
		levels = player.add_xp(xp_gain)

	# DO NOT modify battle_state at all (true simulation)
	player.last_active_unix = now_unix

	inventory_event.emit(
		"Offline (%s): +%d gold, +%d keys, +%d XP" % [_fmt_duration_short(capped), gold_gain, key_gain, xp_gain]
	)
	if levels > 0:
		inventory_event.emit("Level Up! Lv.%d" % player.level)

	return {
		"applied": (gold_gain != 0 or key_gain != 0 or xp_gain != 0),
		"seconds": capped,
		"gold": gold_gain,
		"keys": key_gain,
		"xp": xp_gain,
		"levels": levels,
	}
