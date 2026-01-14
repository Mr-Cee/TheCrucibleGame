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

#===================================================================================================
# Skills (Active) runtime
#===================================================================================================

const ACTIVE_SKILL_SLOTS: int = 5
const SKILL_GLOBAL_GCD: float = 0.25  # slight delay between skill activations to prevent stacking

# Per-slot cooldown remaining (seconds, scaled by battle speed)
var _skill_cd: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]

# Queue of slot indices waiting to cast once global lock clears
var _skill_queue: Array[int] = []

# Global lock remaining (seconds, scaled by battle speed)
var _skill_lock: float = 0.0
const AGG_FLUSH_INTERVAL: float = 0.35

var task_system: TaskSystem


#===================================================================================================

const TIME_VOUCHER_SECONDS: int = 5 * 60 # 5 minutes

#===================================================================================================

func _ready() -> void:
	SaveManager.load_or_new()
	SaveManager.init_autosave_hooks()
	
	if player != null and not player.leveled_up.is_connected(_on_player_leveled_up):
		player.leveled_up.connect(_on_player_leveled_up)
	
	player_changed.connect(_battle_on_player_changed)

	if has_selected_class():
		_battle_init_if_needed()
	else:
		battle_runtime["status_text"] = "Choose a class to begin."
		battle_changed.emit()

	
	task_system = TaskSystem.new()
	add_child(task_system)
	task_system.setup(player)

	
	crucible_tick_upgrade_completion()

func _process(delta: float) -> void:
	_upgrade_check_accum += delta
	if _upgrade_check_accum >= 1.0:
		_upgrade_check_accum = 0.0
		crucible_tick_upgrade_completion()
	if has_selected_class():
		_battle_init_if_needed()
		_battle_process(delta)
	else:
		# Do not advance combat at all until class is selected.
		pass


func has_selected_class() -> bool:
	return player != null and int(player.class_id) >= 0

func set_player_class(new_class_id: int, new_class_def_id: String = "") -> void:
	if player == null:
		return
	player.class_id = new_class_id
	if new_class_def_id != "" and "class_def_id" in player:
		player.class_def_id = new_class_def_id
	player_changed.emit()

func add_gold(amount:int) -> void:
	player.gold += amount
	emit_signal("player_changed")

func _on_player_leveled_up(levels_gained: int) -> void:
	if "task_system" in self and task_system != null:
		task_system.notify_level_up(levels_gained)

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
	if not has_selected_class():
		return


	_battle_inited = true
	_skills_ensure_player_initialized()
	_skills_init_runtime()
	_battle_reset_effects()
	_battle_recompute_player_combat()

	battle_runtime["player_hp_max"] = _p_hp_max
	battle_runtime["player_hp"] = _p_hp_max

	_battle_spawn_enemy(true)

func _battle_on_player_changed() -> void:
	if player == null:
		return

	# Still in class selection state; don't run combat math.
	if not has_selected_class():
		battle_runtime["status_text"] = "Choose a class to begin."
		battle_changed.emit()
		return

	# If class was just chosen, initialize combat now.
	if not _battle_inited:
		_battle_init_if_needed()

	# Gear/level changes should immediately affect combat.
	_battle_recompute_player_combat()

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

#===================================================================================================
# Active Skills API (UI)
#===================================================================================================

func skills_auto_enabled() -> bool:
	if player == null:
		return true
	if player.has_method("get") and player.get("skill_auto") != null:
		return bool(player.get("skill_auto"))
	# Backwards compatibility
	return true

func set_skills_auto_enabled(enabled: bool) -> void:
	if player == null:
		return
	# Persist on player
	player.set("skill_auto", enabled)
	player_changed.emit()

func get_equipped_active_skill_id(slot: int) -> String:
	if player == null:
		return ""
	var arr: Array = player.get("equipped_active_skills")
	if arr == null:
		return ""
	if slot < 0 or slot >= arr.size():
		return ""
	return String(arr[slot])

func get_skill_cooldown_remaining(slot: int) -> float:
	if slot < 0 or slot >= _skill_cd.size():
		return 0.0
	return max(0.0, float(_skill_cd[slot]))

func get_skill_cooldown_total(slot: int) -> float:
	var id := get_equipped_active_skill_id(slot)
	if id == "":
		return 0.0
	var def := SkillCatalog.get_def(id)
	if def == null:
		return 0.0
	# If you later wire INT into cooldown reduction, swap in def.effective_cooldown(int_stat)
	return float(def.cooldown)

func request_cast_active_skill(slot: int) -> void:
	# Manual request. In auto-mode the system enqueues automatically.
	if slot < 0 or slot >= ACTIVE_SKILL_SLOTS:
		return
	_enqueue_skill_slot(slot)

#===================================================================================================
# Active Skills runtime
#===================================================================================================

func _skills_init_runtime() -> void:
	_skill_cd = [0.0, 0.0, 0.0, 0.0, 0.0]
	_skill_queue = []
	_skill_lock = 0.0

func _skills_ensure_player_initialized() -> void:
	if player == null:
		return
	if player.has_method("ensure_active_skills_initialized"):
		player.call("ensure_active_skills_initialized")

func _enqueue_skill_slot(slot: int) -> void:
	if player == null:
		return
	_skills_ensure_player_initialized()

	var id := get_equipped_active_skill_id(slot)
	if id == "":
		return
	if SkillCatalog.get_def(id) == null:
		return

	# Not ready yet
	if float(_skill_cd[slot]) > 0.0:
		return

	# Avoid duplicate queue entries
	if _skill_queue.has(slot):
		return

	_skill_queue.append(slot)

func _skills_tick(dt: float) -> void:
	# Cooldowns
	for i in range(_skill_cd.size()):
		if _skill_cd[i] > 0.0:
			_skill_cd[i] = max(0.0, _skill_cd[i] - dt)

	# Global lock
	if _skill_lock > 0.0:
		_skill_lock = max(0.0, _skill_lock - dt)

	# Auto-enqueue ready skills
	if skills_auto_enabled():
		for i in range(ACTIVE_SKILL_SLOTS):
			_enqueue_skill_slot(i)

	# Cast if possible
	if _skill_lock <= 0.0 and _skill_queue.size() > 0:
		var slot := int(_skill_queue.pop_front())
		_cast_skill_from_slot(slot)

func _cast_skill_from_slot(slot: int) -> void:
	var id := get_equipped_active_skill_id(slot)
	if id == "":
		return
	var def := SkillCatalog.get_def(id)
	if def == null:
		return

	# If we became busy, re-queue
	if _skill_lock > 0.0:
		_enqueue_skill_slot(slot)
		return

	# Double-check ready
	if float(_skill_cd[slot]) > 0.0:
		return

	# Apply effects
	_apply_active_skill(def, slot)

	# Start cooldown + lock
	_skill_cd[slot] = float(def.cooldown)
	_skill_lock = SKILL_GLOBAL_GCD

func _apply_active_skill(def: SkillDef, slot: int) -> void:
	# Basic scaling using cached combat values.
	# Later you can incorporate STR/INT/AGI and skill rarities/levels.
	var lvl: int = 1
	if player != null:
		var sl: Variant = player.get("skill_levels")
		if typeof(sl) == TYPE_DICTIONARY and (sl as Dictionary).has(def.id):
			lvl = int((sl as Dictionary)[def.id])

	var mult := def.level_multiplier(lvl)

	match def.effect:
		SkillDef.EffectType.DAMAGE:
			var raw := _p_atk * def.power * mult
			_skill_deal_damage(def, raw)

		SkillDef.EffectType.MULTI_HIT:
			var per := _p_atk * def.power * mult
			var total := 0.0
			for _i in range(maxi(1, def.hits)):
				total += _apply_defense(per, _enemy_def_effective())
			battle_runtime["enemy_hp"] = max(0.0, float(battle_runtime["enemy_hp"]) - total)
			log_combat("skill", "normal", "[color=#B58CFF]%s[/color] hits %dx for [b]%d[/b]" % [def.display_name, maxi(1, def.hits), int(round(total))])

		SkillDef.EffectType.DOT:
			# Immediate hit + DoT
			if def.power > 0.0:
				var raw := _p_atk * def.power * mult
				_skill_deal_damage(def, raw)
			# DoT DPS stacks additively
			var dps_add := _p_atk * def.secondary_power * mult
			battle_runtime["enemy_dot_dps"] = float(battle_runtime.get("enemy_dot_dps", 0.0)) + dps_add
			battle_runtime["enemy_dot_time"] = max(float(battle_runtime.get("enemy_dot_time", 0.0)), def.duration)
			log_combat("skill", "normal", "[color=#B58CFF]%s[/color] applies DoT" % def.display_name)

		SkillDef.EffectType.HEAL:
			var heal := _p_hp_max * def.power * mult
			_skill_heal(def, heal)

		SkillDef.EffectType.HOT:
			battle_runtime["player_hot_hps"] = float(battle_runtime.get("player_hot_hps", 0.0)) + (_p_hp_max * def.secondary_power * mult)
			battle_runtime["player_hot_time"] = max(float(battle_runtime.get("player_hot_time", 0.0)), def.duration)
			log_combat("skill", "heal", "[color=#B58CFF]%s[/color] applies healing over time" % def.display_name)

		SkillDef.EffectType.SHIELD:
			var shield := _p_hp_max * def.power * mult
			battle_runtime["player_shield"] = float(battle_runtime.get("player_shield", 0.0)) + shield
			log_combat("skill", "shield", "[color=#B58CFF]%s[/color] grants a shield of [b]%d[/b]" % [def.display_name, int(round(shield))])

			# Special-case: Second Wind also heals a bit
			if def.id == "second_wind":
				var heal2 := _p_hp_max * 0.12 * mult
				_skill_heal(def, heal2, true)

		SkillDef.EffectType.STUN:
			if def.power > 0.0:
				var raw := _p_atk * def.power * mult
				_skill_deal_damage(def, raw)
			battle_runtime["enemy_stun_time"] = max(float(battle_runtime.get("enemy_stun_time", 0.0)), def.duration)
			log_combat("skill", "cc", "[color=#B58CFF]%s[/color] stuns the enemy" % def.display_name)

		SkillDef.EffectType.SLOW:
			if def.power > 0.0:
				var raw := _p_atk * def.power * mult
				_skill_deal_damage(def, raw)
			_apply_enemy_timed_mult("enemy_aps_mult", "enemy_aps_time", 1.0 - clamp(def.magnitude, 0.0, 0.80), def.duration)
			log_combat("skill", "cc", "[color=#B58CFF]%s[/color] slows the enemy" % def.display_name)

		SkillDef.EffectType.WEAKEN:
			if def.power > 0.0:
				var raw := _p_atk * def.power * mult
				_skill_deal_damage(def, raw)
			_apply_enemy_timed_mult("enemy_atk_mult", "enemy_atk_time", 1.0 - clamp(def.magnitude, 0.0, 0.80), def.duration)
			log_combat("skill", "debuff", "[color=#B58CFF]%s[/color] weakens the enemy" % def.display_name)

		SkillDef.EffectType.ARMOR_BREAK:
			if def.power > 0.0:
				var raw := _p_atk * def.power * mult
				_skill_deal_damage(def, raw)
			_apply_enemy_timed_mult("enemy_def_mult", "enemy_def_time", 1.0 - clamp(def.magnitude, 0.0, 0.80), def.duration)
			log_combat("skill", "debuff", "[color=#B58CFF]%s[/color] reduces enemy defense" % def.display_name)

		SkillDef.EffectType.VULNERABILITY:
			_apply_enemy_timed_mult("enemy_vuln_mult", "enemy_vuln_time", 1.0 + clamp(def.magnitude, 0.0, 3.0), def.duration)
			log_combat("skill", "debuff", "[color=#B58CFF]%s[/color] marks the enemy" % def.display_name)

		SkillDef.EffectType.BUFF_ATK:
			_apply_player_timed_mult("player_atk_mult", "player_atk_time", 1.0 + clamp(def.magnitude, 0.0, 3.0), def.duration)
			log_combat("skill", "buff", "[color=#B58CFF]%s[/color] increases your attack" % def.display_name)

		SkillDef.EffectType.BUFF_DEF:
			_apply_player_timed_mult("player_def_mult", "player_def_time", 1.0 + clamp(def.magnitude, 0.0, 3.0), def.duration)
			log_combat("skill", "buff", "[color=#B58CFF]%s[/color] increases your defense" % def.display_name)

		SkillDef.EffectType.BUFF_APS:
			_apply_player_timed_mult("player_aps_mult", "player_aps_time", 1.0 + clamp(def.magnitude, 0.0, 3.0), def.duration)
			log_combat("skill", "buff", "[color=#B58CFF]%s[/color] increases your attack speed" % def.display_name)

		SkillDef.EffectType.BUFF_AVOID:
			battle_runtime["player_avoid_pp_add"] = float(def.magnitude)
			battle_runtime["player_avoid_time"] = max(float(battle_runtime.get("player_avoid_time", 0.0)), def.duration)
			log_combat("skill", "buff", "[color=#B58CFF]%s[/color] increases your avoidance" % def.display_name)

		SkillDef.EffectType.BUFF_CRIT:
			battle_runtime["player_crit_pp_add"] = float(def.magnitude)
			battle_runtime["player_crit_time"] = max(float(battle_runtime.get("player_crit_time", 0.0)), def.duration)
			log_combat("skill", "buff", "[color=#B58CFF]%s[/color] increases your crit chance" % def.display_name)

		SkillDef.EffectType.COOLDOWN_REDUCE_OTHERS:
			for i in range(ACTIVE_SKILL_SLOTS):
				if i == slot:
					continue
				_skill_cd[i] = max(0.0, float(_skill_cd[i]) - def.power)
			log_combat("skill", "buff", "[color=#B58CFF]%s[/color] hastens your other skills" % def.display_name)

		SkillDef.EffectType.LIFE_DRAIN:
			var raw := _p_atk * def.power * mult
			var dealt := _apply_defense(raw, _enemy_def_effective())
			battle_runtime["enemy_hp"] = max(0.0, float(battle_runtime["enemy_hp"]) - dealt)
			var heal: float = float(dealt) * clampf(float(def.magnitude), 0.0, 2.0)
			_skill_heal(def, heal, true)
			log_combat("skill", "heal", "[color=#B58CFF]%s[/color] drains [b]%d[/b] and heals [b]%d[/b]" % [def.display_name, int(round(dealt)), int(round(heal))])

func _skill_deal_damage(def: SkillDef, raw: float) -> void:
	var dealt := _apply_defense(raw, _enemy_def_effective())
	# Vulnerability multiplier
	dealt *= _enemy_vuln_mult()
	battle_runtime["enemy_hp"] = max(0.0, float(battle_runtime["enemy_hp"]) - dealt)
	log_combat("skill", "normal", "[color=#B58CFF]%s[/color] deals [b]%d[/b]" % [def.display_name, int(round(dealt))])

func _skill_heal(def: SkillDef, amount: float, quiet: bool = false) -> void:
	var hp := float(battle_runtime.get("player_hp", 0.0))
	var hp_max := float(battle_runtime.get("player_hp_max", 1.0))
	var healed: float = clampf(float(amount), 0.0, maxf(0.0, float(hp_max) - float(hp)))
	battle_runtime["player_hp"] = hp + healed
	if not quiet:
		log_combat("skill", "heal", "[color=#B58CFF]%s[/color] heals [b]%d[/b]" % [def.display_name, int(round(healed))])

func _apply_enemy_timed_mult(mult_key: String, time_key: String, mult: float, time: float) -> void:
	battle_runtime[mult_key] = mult
	battle_runtime[time_key] = max(float(battle_runtime.get(time_key, 0.0)), time)

func _apply_player_timed_mult(mult_key: String, time_key: String, mult: float, time: float) -> void:
	battle_runtime[mult_key] = mult
	battle_runtime[time_key] = max(float(battle_runtime.get(time_key, 0.0)), time)

func _enemy_def_effective() -> float:
	return _e_def * float(battle_runtime.get("enemy_def_mult", 1.0))

func _enemy_atk_mult() -> float:
	return float(battle_runtime.get("enemy_atk_mult", 1.0))

func _enemy_aps_mult() -> float:
	return float(battle_runtime.get("enemy_aps_mult", 1.0))

func _enemy_vuln_mult() -> float:
	return float(battle_runtime.get("enemy_vuln_mult", 1.0))

func _player_atk_mult() -> float:
	return float(battle_runtime.get("player_atk_mult", 1.0))

func _player_def_mult() -> float:
	return float(battle_runtime.get("player_def_mult", 1.0))

func _player_aps_mult() -> float:
	return float(battle_runtime.get("player_aps_mult", 1.0))

func _battle_reset_effects() -> void:
	# Player
	battle_runtime["player_shield"] = 0.0
	battle_runtime["player_hot_dps"] = 0.0
	battle_runtime["player_hot_hps"] = 0.0
	battle_runtime["player_hot_time"] = 0.0

	battle_runtime["player_atk_mult"] = 1.0
	battle_runtime["player_atk_time"] = 0.0
	battle_runtime["player_def_mult"] = 1.0
	battle_runtime["player_def_time"] = 0.0
	battle_runtime["player_aps_mult"] = 1.0
	battle_runtime["player_aps_time"] = 0.0
	battle_runtime["player_avoid_pp_add"] = 0.0
	battle_runtime["player_avoid_time"] = 0.0
	battle_runtime["player_crit_pp_add"] = 0.0
	battle_runtime["player_crit_time"] = 0.0

	# Enemy
	battle_runtime["enemy_stun_time"] = 0.0
	battle_runtime["enemy_dot_dps"] = 0.0
	battle_runtime["enemy_dot_time"] = 0.0

	battle_runtime["enemy_atk_mult"] = 1.0
	battle_runtime["enemy_atk_time"] = 0.0
	battle_runtime["enemy_def_mult"] = 1.0
	battle_runtime["enemy_def_time"] = 0.0
	battle_runtime["enemy_aps_mult"] = 1.0
	battle_runtime["enemy_aps_time"] = 0.0
	battle_runtime["enemy_vuln_mult"] = 1.0
	battle_runtime["enemy_vuln_time"] = 0.0

func _battle_tick_effects(dt: float) -> void:
	# Timers down, reset multipliers when expired
	_tick_timer_reset_mult("player_atk_time", "player_atk_mult", 1.0, dt)
	_tick_timer_reset_mult("player_def_time", "player_def_mult", 1.0, dt)
	_tick_timer_reset_mult("player_aps_time", "player_aps_mult", 1.0, dt)
	_tick_timer_reset_mult("player_avoid_time", "player_avoid_pp_add", 0.0, dt)
	_tick_timer_reset_mult("player_crit_time", "player_crit_pp_add", 0.0, dt)

	_tick_timer_reset_mult("enemy_atk_time", "enemy_atk_mult", 1.0, dt)
	_tick_timer_reset_mult("enemy_def_time", "enemy_def_mult", 1.0, dt)
	_tick_timer_reset_mult("enemy_aps_time", "enemy_aps_mult", 1.0, dt)
	_tick_timer_reset_mult("enemy_vuln_time", "enemy_vuln_mult", 1.0, dt)

	# Stun
	if float(battle_runtime.get("enemy_stun_time", 0.0)) > 0.0:
		battle_runtime["enemy_stun_time"] = max(0.0, float(battle_runtime["enemy_stun_time"]) - dt)

	# Enemy DoT
	if float(battle_runtime.get("enemy_dot_time", 0.0)) > 0.0:
		var dps := float(battle_runtime.get("enemy_dot_dps", 0.0))
		if dps > 0.0:
			var dealt := dps * dt * _enemy_vuln_mult()
			battle_runtime["enemy_hp"] = max(0.0, float(battle_runtime["enemy_hp"]) - dealt)
		battle_runtime["enemy_dot_time"] = max(0.0, float(battle_runtime["enemy_dot_time"]) - dt)
		if float(battle_runtime["enemy_dot_time"]) <= 0.0:
			battle_runtime["enemy_dot_dps"] = 0.0

	# Player HoT
	if float(battle_runtime.get("player_hot_time", 0.0)) > 0.0:
		var hps := float(battle_runtime.get("player_hot_hps", 0.0))
		if hps > 0.0:
			_skill_heal(SkillDef.new(), hps * dt, true) # quiet tick
		battle_runtime["player_hot_time"] = max(0.0, float(battle_runtime["player_hot_time"]) - dt)
		if float(battle_runtime["player_hot_time"]) <= 0.0:
			battle_runtime["player_hot_hps"] = 0.0

func _tick_timer_reset_mult(time_key: String, mult_key: String, reset_value: float, dt: float) -> void:
	var t := float(battle_runtime.get(time_key, 0.0))
	if t <= 0.0:
		return
	t = max(0.0, t - dt)
	battle_runtime[time_key] = t
	if t <= 0.0:
		battle_runtime[mult_key] = reset_value

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

	# Timed effects + active skills
	_battle_tick_effects(dt)
	if float(battle_runtime.get("enemy_hp", 0.0)) <= 0.0:
		_battle_on_enemy_defeated()
		return
	_skills_tick(dt)
	
	# Accumulate real-time for aggregation flush
	_agg_flush_accum += delta
	if combat_log_compact_effective():
		_combat_log_flush(false)


	_p_atk_accum += dt
	_e_atk_accum += dt

	var p_interval: float = 1.0 / max(0.1, _p_aps * _player_aps_mult())
	var e_interval: float = 1.0 / max(0.1, _e_aps * _enemy_aps_mult())

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

	var dmg: float = _p_atk * _player_atk_mult()

	# Crit
	var crit_chance: float = clamp(_p_crit + (float(battle_runtime.get("player_crit_pp_add", 0.0)) / 100.0), 0.0, 0.90)

	if (RNG as RNGService).randf() < crit_chance:
		was_crit = true
		dmg *= 1.5

	# Combo (percent points; allow >100)
	var cc: float = max(0.0, _p_combo) / 100.0
	var guaranteed: int = int(floor(cc))
	var extra_chance: float = cc - float(guaranteed)

	hits = 1 + guaranteed
	if (RNG as RNGService).randf() < extra_chance:
		hits += 1

	var total: float = dmg
	if hits > 1:
		total += float(hits - 1) * (dmg * 0.5) # extra hits at 50%

	var dealt: float = _apply_defense(total, _enemy_def_effective())
	dealt *= _enemy_vuln_mult()
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
	var dmg: float = _e_atk * _enemy_atk_mult()

	# Stun: enemy cannot act
	if float(battle_runtime.get("enemy_stun_time", 0.0)) > 0.0:
		return

	# Avoid
	if (RNG as RNGService).randf() < (clamp(_p_avoid + float(battle_runtime.get("player_avoid_pp_add", 0.0)), 0.0, 100.0) / 100.0):
		if combat_log_compact_effective():
			_agg_enemy_hits["avoids"] = int(_agg_enemy_hits["avoids"]) + 1
		else:
			log_combat("enemy", "avoid", "[color=#FF8A8A]Enemy[/color] attacks — [color=#7FB0FF](AVOID)[/color]")
		return

	var blocked: bool = false
	if (RNG as RNGService).randf() < (clamp(_p_block, 0.0, 100.0) / 100.0):
		blocked = true
		dmg *= 0.30

	var dealt: float = _apply_defense(dmg, _p_def * _player_def_mult())
	var shield: float = float(battle_runtime.get("player_shield", 0.0))
	var remaining: float = dealt
	if shield > 0.0 and remaining > 0.0:
		var absorbed: float = minf(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
		battle_runtime["player_shield"] = shield

	battle_runtime["player_hp"] = max(0.0, float(battle_runtime["player_hp"]) - remaining)

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
		log_combat("enemy", sev, "[color=#FF8A8A]Enemy[/color] hit you for [b]%d[/b]%s" % [int(round(remaining)), tag_txt])

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
		
	get_node("/root/Game").task_system.notify_enemy_killed(1)

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

	# Reset per-enemy effects
	battle_runtime["enemy_stun_time"] = 0.0
	battle_runtime["enemy_dot_dps"] = 0.0
	battle_runtime["enemy_dot_time"] = 0.0
	battle_runtime["enemy_atk_mult"] = 1.0
	battle_runtime["enemy_atk_time"] = 0.0
	battle_runtime["enemy_def_mult"] = 1.0
	battle_runtime["enemy_def_time"] = 0.0
	battle_runtime["enemy_aps_mult"] = 1.0
	battle_runtime["enemy_aps_time"] = 0.0
	battle_runtime["enemy_vuln_mult"] = 1.0
	battle_runtime["enemy_vuln_time"] = 0.0

	# If you tune enemy attack speed elsewhere, keep your existing logic:
	# _e_aps = is_boss ? 0.7 : 0.9

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

# -----------------------------------------------------------------------------------------------
# Dev helpers
# -----------------------------------------------------------------------------------------------

# Sets the player's character level directly (dev tools).
# If reset_xp is true, XP is cleared so the player is exactly at the requested level.
func dev_set_character_level(target_level: int, reset_xp: bool = true) -> void:
	if player == null:
		return

	var lvl: int = maxi(1, target_level)
	player.level = lvl
	if reset_xp:
		player.xp = 0

	# Keep downstream systems stable (skills arrays, etc.).
	if player.has_method("ensure_class_and_skills_initialized"):
		player.ensure_class_and_skills_initialized()

	# Refresh UI/battle.
	player_changed.emit()

	# If the current tutorial task is "level up to X", sync its display immediately.
	if task_system != null:
		task_system.notify_level_up(1)

	# Persist quickly when using dev tools (if you have this hook).
	if has_method("request_save"):
		call("request_save")

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
	print("Offline (%s): +%d gold, +%d keys, +%d XP" % [_fmt_duration_short(capped), gold_gain, key_gain, xp_gain]
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

func popup_root() -> Control:
	var root := get_tree().root

	var layer := root.get_node_or_null("PopupLayer") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "PopupLayer"
		layer.layer = 20
		root.add_child(layer)

	var ui := layer.get_node_or_null("Root") as Control
	if ui == null:
		ui = Control.new()
		ui.name = "Root"
		ui.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui.offset_left = 0
		ui.offset_top = 0
		ui.offset_right = 0
		ui.offset_bottom = 0
		ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(ui)

	return ui
