extends Node
class_name BattleSystem

signal battle_changed
signal combat_log_added(line: String) # legacy; entries are preferred
signal combat_log_entry_added(entry: Dictionary)
signal combat_log_cleared

# Host (Game autoload) reference; kept as Node because Game.gd has no class_name.
var game: Node
var player: PlayerModel

# Persisted (saved) battle position/speed.
var battle_state: Dictionary = {
	"difficulty": "Easy",
	"level": 1,
	"stage": 1,
	"wave": 1,
	"speed_idx": 0,
}

# Runtime-only combat state.
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

#---------------------------------------------------------------------------------------------------
# Multi-enemy waves (placeholder visuals support)
#---------------------------------------------------------------------------------------------------
const WAVE_MIN_ENEMIES: int = 4
const WAVE_MAX_ENEMIES: int = 7

# Random attack timers for non-boss enemies (seconds, scaled by battle speed)
const ENEMY_ATK_INTERVAL_MIN: float = 1.20
const ENEMY_ATK_INTERVAL_MAX: float = 2.60

var _enemies: Array[Dictionary] = [] # each: {hp, hp_max, atk, atk_timer}
var _target_enemy_idx: int = 0

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

# ========== Dungeon Vars =================================
var _dungeon_active: bool = false
var _dungeon_id: String = ""
var _dungeon_level: int = 0
var _dungeon_saved_ctx: Dictionary = {}

#===================================================================================================

func setup(host_game: Node) -> void:
	game = host_game
	# Player can be assigned later (e.g., after SaveManager.load_or_new).
	player = (game.player if game != null else null)

func set_player(p: PlayerModel) -> void:
	if player == p:
		return
	player = p
	# Force re-init on player replacement.
	_battle_inited = false

func has_selected_class() -> bool:
	return player != null and int(player.class_id) >= 0

func tick(delta: float) -> void:
	# No combat until class is selected.
	var gp: PlayerModel = (game.player if game != null else player)
	if gp != player:
		set_player(gp)
	if not has_selected_class():
		return
	_battle_init_if_needed()
	_battle_process(delta)

func set_idle_status_text(text: String) -> void:
	battle_runtime["status_text"] = text
	battle_changed.emit()

#===================================================================================================
# Battle state (persisted)
#===================================================================================================

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

	# Request save if the host exposes it (or SaveManager hooks will catch battle_changed)
	if game != null and game.has_method("request_save"):
		game.call("request_save")

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

# Public: snapshot of current wave enemies for UI (placeholder squares).
# Each entry: {idx:int, hp:float, hp_max:float, alive:bool, is_target:bool}
func get_enemies_snapshot() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(_enemies.size()):
		var e: Dictionary = _enemies[i]
		var hp: float = float(e.get("hp", 0.0))
		var hm: float = max(1.0, float(e.get("hp_max", 1.0)))
		out.append({
			"idx": i,
			"hp": hp,
			"hp_max": hm,
			"alive": hp > 0.0,
			"is_target": i == _target_enemy_idx,
		})
	return out

func get_target_enemy_index() -> int:
	return _target_enemy_idx

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
	if game != null:
		game.player_changed.emit()

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
			total *= _enemy_vuln_mult()
			var applied := _apply_damage_to_target(total)
			log_combat("skill", "normal", "[color=#B58CFF]%s[/color] hits %dx for [b]%d[/b]" % [def.display_name, maxi(1, def.hits), int(round(applied))])

		SkillDef.EffectType.DOT:
			# Immediate hit + DoT
			if def.power > 0.0:
				var raw2 := _p_atk * def.power * mult
				_skill_deal_damage(def, raw2)
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
				var raw3 := _p_atk * def.power * mult
				_skill_deal_damage(def, raw3)
			battle_runtime["enemy_stun_time"] = max(float(battle_runtime.get("enemy_stun_time", 0.0)), def.duration)
			log_combat("skill", "cc", "[color=#B58CFF]%s[/color] stuns the enemy" % def.display_name)

		SkillDef.EffectType.SLOW:
			if def.power > 0.0:
				var raw4 := _p_atk * def.power * mult
				_skill_deal_damage(def, raw4)
			_apply_enemy_timed_mult("enemy_aps_mult", "enemy_aps_time", 1.0 - clamp(def.magnitude, 0.0, 0.80), def.duration)
			log_combat("skill", "cc", "[color=#B58CFF]%s[/color] slows the enemy" % def.display_name)

		SkillDef.EffectType.WEAKEN:
			if def.power > 0.0:
				var raw5 := _p_atk * def.power * mult
				_skill_deal_damage(def, raw5)
			_apply_enemy_timed_mult("enemy_atk_mult", "enemy_atk_time", 1.0 - clamp(def.magnitude, 0.0, 0.80), def.duration)
			log_combat("skill", "debuff", "[color=#B58CFF]%s[/color] weakens the enemy" % def.display_name)

		SkillDef.EffectType.ARMOR_BREAK:
			if def.power > 0.0:
				var raw6 := _p_atk * def.power * mult
				_skill_deal_damage(def, raw6)
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
			var raw7 := _p_atk * def.power * mult
			var dealt := _apply_defense(raw7, _enemy_def_effective())
			dealt *= _enemy_vuln_mult()
			var applied := _apply_damage_to_target(dealt)
			var heal3: float = float(applied) * clampf(float(def.magnitude), 0.0, 2.0)
			_skill_heal(def, heal3, true)
			log_combat("skill", "heal", "[color=#B58CFF]%s[/color] drains [b]%d[/b] and heals [b]%d[/b]" % [def.display_name, int(round(applied)), int(round(heal3))])

func _skill_deal_damage(def: SkillDef, raw: float) -> void:
	var dealt := _apply_defense(raw, _enemy_def_effective())
	# Vulnerability multiplier (target-scoped)
	dealt *= _enemy_vuln_mult()
	var applied := _apply_damage_to_target(dealt)
	log_combat("skill", "normal", "[color=#B58CFF]%s[/color] deals [b]%d[/b]" % [def.display_name, int(round(applied))])

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


#---------------------------------------------------------------------------------------------------
# Enemy-unit helpers (multi-enemy)
#---------------------------------------------------------------------------------------------------
func _enemies_total_hp() -> float:
	var t: float = 0.0
	for e in _enemies:
		t += max(0.0, float(e.get("hp", 0.0)))
	return t

func __refresh_enemy_totals() -> void:
	# Keep the legacy bars using total wave HP.
	battle_runtime["enemy_hp"] = _enemies_total_hp()
	# enemy_hp_max is set on spawn; keep it stable.

func _find_next_alive_enemy(from_idx: int = 0) -> int:
	if _enemies.is_empty():
		return -1
	for i in range(_enemies.size()):
		var idx := (from_idx + i) % _enemies.size()
		if float(_enemies[idx].get("hp", 0.0)) > 0.0:
			return idx
	return -1

func _ensure_valid_target() -> void:
	var idx := _target_enemy_idx
	if idx < 0 or idx >= _enemies.size() or float(_enemies[idx].get("hp", 0.0)) <= 0.0:
		idx = _find_next_alive_enemy(0)
	_target_enemy_idx = maxi(-1, idx)

func _reset_target_enemy_effects() -> void:
	# Target-scoped effects only (do NOT carry to a new enemy).
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

func _apply_damage_to_enemy(idx: int, amount: float) -> float:
	if idx < 0 or idx >= _enemies.size() or amount <= 0.0:
		return 0.0
	var e: Dictionary = _enemies[idx]
	var hp: float = max(0.0, float(e.get("hp", 0.0)))
	if hp <= 0.0:
		return 0.0
	var applied: float = minf(hp, amount)
	hp -= applied
	e["hp"] = hp
	_enemies[idx] = e
	__refresh_enemy_totals()
	if hp <= 0.0:
		_on_enemy_unit_defeated(idx)
	return applied

func _apply_damage_to_target(amount: float) -> float:
	_ensure_valid_target()
	return _apply_damage_to_enemy(_target_enemy_idx, amount)

func _on_enemy_unit_defeated(idx: int) -> void:
	# Per-unit death (wave ends only when total HP reaches 0).
	if game != null:
		var ts: Variant = game.get("task_system")
		if ts != null and (ts as Object).has_method("notify_enemy_killed"):
			(ts as Object).call("notify_enemy_killed", 1)
	# If target died, retarget and clear target-scoped effects.
	if idx == _target_enemy_idx:
		_target_enemy_idx = _find_next_alive_enemy(idx + 1)
		_reset_target_enemy_effects()
	# Optional lightweight log
	if not combat_log_compact_effective():
		var remaining := 0
		for e in _enemies:
			if float(e.get("hp", 0.0)) > 0.0:
				remaining += 1
		log_combat("system", "system", "[color=#CFCFCF]Enemy defeated[/color] (%d remaining)" % remaining)

func _split_total(total: float, parts: int) -> Array[float]:
	# Random partition of total into N positive pieces (sum preserved).
	var out: Array[float] = []
	if parts <= 1:
		out.append(total)
		return out
	var weights: Array[float] = []
	var s: float = 0.0
	for _i in range(parts):
		var w: float = max(0.001, (RNG as RNGService).randf())
		weights.append(w)
		s += w
	var remaining: float = total
	for i in range(parts):
		var v: float
		if i == parts - 1:
			v = remaining
		else:
			v = total * (weights[i] / s)
			# prevent tiny negative remainder due to float drift
			v = clampf(v, 0.0, remaining)
			remaining -= v
		out.append(v)
	return out

func _randf_range(a: float, b: float) -> float:
	return a + (b - a) * (RNG as RNGService).randf()

func _roll_enemy_attack_interval(is_boss: bool, attacker_is_target: bool) -> float:
	if is_boss:
		# Preserve prior cadence for boss (APS driven).
		var base := 1.0 / maxf(0.1, _e_aps)
		return base
	var r := _randf_range(ENEMY_ATK_INTERVAL_MIN, ENEMY_ATK_INTERVAL_MAX)
	if attacker_is_target:
		# Apply target-scoped slow/haste. (aps_mult < 1 => slower => longer interval)
		r = r / max(0.10, _enemy_aps_mult())
	return r

#===================================================================================================
# Battle runtime
#===================================================================================================

func on_player_changed() -> void:
	# Keep our cached player reference fresh.
	player = (game.player if game != null else player)
	if player == null:
		return

	# Gear/level changes should immediately affect combat.
	_battle_recompute_player_combat()

	# If we have no HP set yet, initialize.
	if float(battle_runtime.get("player_hp_max", 0.0)) <= 0.0:
		battle_runtime["player_hp_max"] = _p_hp_max
		battle_runtime["player_hp"] = _p_hp_max

	battle_changed.emit()

func _battle_init_if_needed() -> void:
	if _battle_inited:
		return
	if player == null:
		return

	_battle_inited = true
	_skills_ensure_player_initialized()
	_skills_init_runtime()
	_battle_reset_effects()
	_battle_recompute_player_combat()

	battle_runtime["player_hp_max"] = _p_hp_max
	battle_runtime["player_hp"] = _p_hp_max

	_battle_spawn_enemy(true)

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

	# Stun (target-scoped)
	if float(battle_runtime.get("enemy_stun_time", 0.0)) > 0.0:
		battle_runtime["enemy_stun_time"] = max(0.0, float(battle_runtime["enemy_stun_time"]) - dt)

	# Enemy DoT (target-scoped)
	if float(battle_runtime.get("enemy_dot_time", 0.0)) > 0.0:
		var dps := float(battle_runtime.get("enemy_dot_dps", 0.0))
		if dps > 0.0:
			var dealt := dps * dt * _enemy_vuln_mult()
			_apply_damage_to_target(dealt)
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
	
	var total: float = float(battle_runtime.get("dungeon_time_total", 0.0))
	if total > 0.0:
		var left: float = float(battle_runtime.get("dungeon_time_left", total))
		left = max(0.0, left - delta) # unscaled real time
		battle_runtime["dungeon_time_left"] = left

		if left <= 0.0:
			battle_runtime["status_text"] = "Time's up!"
			log_combat("system", "defeat", "[color=#FF4444][b]Time's up![/b][/color]")
			battle_changed.emit()
			_finish_dungeon(false, {}) # fail, no key consumed
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
	__refresh_enemy_totals()
	if float(battle_runtime.get("enemy_hp", 0.0)) <= 0.0:
		_battle_on_enemy_defeated()
		return

	_ensure_valid_target()
	_skills_tick(dt)

	# Accumulate real-time for aggregation flush
	_agg_flush_accum += delta
	if combat_log_compact_effective():
		_combat_log_flush(false)

	_p_atk_accum += dt

	var p_interval: float = 1.0 / max(0.1, _p_aps * _player_aps_mult())
	while _p_atk_accum >= p_interval:
		_p_atk_accum -= p_interval
		_battle_player_attack()
		if float(battle_runtime.get("enemy_hp", 0.0)) <= 0.0:
			_battle_on_enemy_defeated()
			return

	# Enemy attacks: each unit has its own random timer
	var is_boss: bool = bool(battle_runtime.get("is_boss", false))
	for i in range(_enemies.size()):
		var e: Dictionary = _enemies[i]
		if float(e.get("hp", 0.0)) <= 0.0:
			continue
		var t: float = float(e.get("atk_timer", 0.0)) - dt
		while t <= 0.0:
			_battle_enemy_attack_from(i)
			if float(battle_runtime.get("player_hp", 0.0)) <= 0.0:
				_battle_on_player_defeated()
				return
			# roll next timer (apply slow/haste only for target)
			var attacker_is_target := (i == _target_enemy_idx)
			t += _roll_enemy_attack_interval(is_boss, attacker_is_target)
		e["atk_timer"] = t
		_enemies[i] = e

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
	var applied: float = _apply_damage_to_target(dealt)

	# --- Combat log line ---
	if combat_log_compact_effective():
		_agg_player_hits["count"] = int(_agg_player_hits["count"]) + 1
		_agg_player_hits["dmg"] = int(_agg_player_hits["dmg"]) + int(round(applied))
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

		log_combat("player", sev, "[color=#7CFF7C]You[/color] hit for [b]%d[/b]%s" % [int(round(applied)), tag_txt])

func _battle_enemy_attack_from(attacker_idx: int) -> void:
	if attacker_idx < 0 or attacker_idx >= _enemies.size():
		return
	var e: Dictionary = _enemies[attacker_idx]
	var base: float = float(e.get("atk", 1.0))
	var dmg: float = base

	var is_target: bool = (attacker_idx == _target_enemy_idx)
	# Stun is target-scoped (only prevents the stunned target from acting).
	if is_target and float(battle_runtime.get("enemy_stun_time", 0.0)) > 0.0:
		return

	# Target-scoped weaken only affects the weakened enemy's attacks.
	if is_target:
		dmg *= _enemy_atk_mult()
		
	# Dungeon rule: optionally disable enemy damage (DPS race dungeons)
	if _dungeon_active:
		var mult: float = float(battle_runtime.get("dungeon_enemy_damage_mult", 1.0))
		if mult <= 0.0:
			return
		dmg *= mult
		
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

	if combat_log_compact_effective():
		_agg_enemy_hits["count"] = int(_agg_enemy_hits["count"]) + 1
		_agg_enemy_hits["dmg"] = int(_agg_enemy_hits["dmg"]) + int(round(dealt))
		if blocked: _agg_enemy_hits["blocks"] = int(_agg_enemy_hits["blocks"]) + 1
	else:
		var tag_txt: String = ""
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
	if _dungeon_active:
		var ds: DungeonSystem = (game.get("dungeon_system") as DungeonSystem)
		var reward: Dictionary = {}
		if ds != null:
			reward = ds.reward_and_advance_on_success(_dungeon_id)

		if game != null and game.has_signal("inventory_event") and ds != null:
			game.emit_signal("inventory_event", "Dungeon cleared! Gained: %s" % ds.reward_to_text(reward))

		_finish_dungeon(true, reward)
		return
	
	if player == null:
		return

	# Reward based on the wave we just completed (before advancing)
	var diff: String = String(battle_state.get("difficulty", "Easy"))
	var lvl: int = int(battle_state.get("level", 1))
	var stg: int = int(battle_state.get("stage", 1))
	var wav: int = int(battle_state.get("wave", 1))
	var is_boss: bool = (wav == Catalog.BATTLE_WAVES_PER_STAGE)

	var gold_gain: int = Catalog.battle_gold_for_wave(diff, lvl, stg, wav, is_boss)
	var key_gain: int = Catalog.battle_keys_for_wave(diff, lvl, stg, wav, is_boss)

	# Preserve existing behavior: gold is applied via add_gold(), then keys are applied separately.
	if game != null and game.has_method("add_gold"):
		game.call("add_gold", gold_gain)
	else:
		player.gold += gold_gain
		if game != null:
			game.player_changed.emit()

	player.crucible_keys += key_gain
	if game != null:
		game.player_changed.emit()

	if combat_log_compact_effective():
		_agg_rewards["gold"] = int(_agg_rewards["gold"]) + gold_gain
		_agg_rewards["keys"] = int(_agg_rewards["keys"]) + key_gain
		_agg_rewards["waves"] = int(_agg_rewards["waves"]) + 1
		if is_boss:
			_agg_rewards["boss_waves"] = int(_agg_rewards["boss_waves"]) + 1
	else:
		log_combat(
			"reward",
			"reward",
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
		log_combat(
			"system",
			"system",
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
	if _dungeon_active:
		battle_runtime["player_hp"] = 0.0
		battle_runtime["status_text"] = "Defeated!"
		if combat_log_compact_effective():
			_combat_log_flush(true)
		log_combat("system", "defeat", "[color=#FF4444][b]Defeated![/b][/color]")
		battle_changed.emit()

		if game != null and game.has_signal("inventory_event"):
			game.emit_signal("inventory_event", "Dungeon failed.")

		_finish_dungeon(false, {})
		return
		
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
	if _dungeon_active:
		_battle_spawn_dungeon_enemy(reset_hp)
		return
		
	var diff: String = String(battle_state.get("difficulty", "Easy"))
	var lvl: int = int(battle_state.get("level", 1))
	var stg: int = int(battle_state.get("stage", 1))
	var wav: int = int(battle_state.get("wave", 1))

	var is_boss: bool = (wav == Catalog.BATTLE_WAVES_PER_STAGE)
	battle_runtime["is_boss"] = is_boss

	var m: Dictionary = Catalog.battle_enemy_multipliers(diff, lvl, stg, wav, is_boss)

	var total_hp: float = Catalog.ENEMY_BASE_HP * float(m["hp"])
	var base_atk: float = Catalog.ENEMY_BASE_ATK * float(m["atk"])
	var def: float = Catalog.ENEMY_BASE_DEF * float(m["def"])

	# Legacy: enemy_hp_max / enemy_hp represent TOTAL wave HP for UI.
	battle_runtime["enemy_hp_max"] = total_hp
	if reset_hp:
		battle_runtime["enemy_hp"] = total_hp

	_e_def = max(0.0, def)
	_e_atk = max(1.0, base_atk)

	# Build enemy units
	var count: int = 1 if is_boss else (RNG as RNGService).randi_range(WAVE_MIN_ENEMIES, WAVE_MAX_ENEMIES)
	_enemies.clear()

	# HP split
	var hp_parts: Array[float] = _split_total(total_hp, count)

	# ATK split: preserve overall DPS compared to the legacy system.
	# Legacy DPS ~= base_atk * _e_aps. For non-boss, attacks occur on random timers;
	# choose per-hit damage so that sum(atk_i)/mean_interval == legacy DPS.
	var legacy_dps: float = base_atk * _e_aps
	var mean_interval: float = (ENEMY_ATK_INTERVAL_MIN + ENEMY_ATK_INTERVAL_MAX) * 0.5
	var sum_per_hit: float = legacy_dps * (mean_interval if not is_boss else (1.0 / max(0.1, _e_aps)))
	var atk_parts: Array[float] = _split_total(sum_per_hit, count)

	for i in range(count):
		var hpv: float = max(1.0, float(hp_parts[i]))
		var atkv: float = max(1.0, float(atk_parts[i]))
		var t0: float
		if is_boss:
			t0 = _roll_enemy_attack_interval(true, true)
		else:
			# spread initial attacks so they don't all fire at once
			t0 = _randf_range(0.15, mean_interval)
		_enemies.append({
			"hp_max": hpv,
			"hp": (hpv if reset_hp else hpv),
			"atk": atkv,
			"atk_timer": t0,
		})

	_target_enemy_idx = 0
	_ensure_valid_target()
	_reset_target_enemy_effects()
	__refresh_enemy_totals()

func _battle_spawn_dungeon_enemy(reset_hp: bool) -> void:
	var ds: DungeonSystem = (game.get("dungeon_system") as DungeonSystem)
	if ds == null:
		return

	var stats: Dictionary = ds.enemy_stats_for_level(_dungeon_id, _dungeon_level)

	var hp: float = float(stats.get("hp", Catalog.ENEMY_BASE_HP))
	var atk: float = float(stats.get("atk", Catalog.ENEMY_BASE_ATK))
	var df: float = float(stats.get("def", Catalog.ENEMY_BASE_DEF))
	var aps: float = float(stats.get("aps", 0.75))

	battle_runtime["is_boss"] = true
	battle_runtime["enemy_name"] = String(stats.get("name", "Boss"))
	battle_runtime["enemy_sprite_path"] = String(stats.get("sprite_path", ""))


	battle_runtime["enemy_hp_max"] = hp
	if reset_hp:
		battle_runtime["enemy_hp"] = hp

	_e_def = max(0.0, df)
	_e_aps = max(0.10, aps)

	_enemies.clear()
	_enemies.append({
		"hp_max": hp,
		"hp": (hp if reset_hp else hp),
		"atk": max(1.0, atk),
		"atk_timer": _roll_enemy_attack_interval(true, true),
	})

	_target_enemy_idx = 0
	_ensure_valid_target()
	_reset_target_enemy_effects()
	__refresh_enemy_totals()

func _battle_recompute_player_combat() -> void:
	if player == null:
		return

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

# ===================================================================================================
# Combat log
# ===================================================================================================

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

# ==============================================================================================

func start_dungeon_run(dungeon_id: String) -> bool:
	if game == null:
		return false

	var ds: DungeonSystem = game.get("dungeon_system") as DungeonSystem
	if ds == null:
		return false

	# Refresh player reference
	var gp: PlayerModel = (game.player if game != null else player)
	if gp != player:
		set_player(gp)
	if player == null:
		return false

	if _dungeon_active:
		return false

	# Consume entry key up front
	if not ds.begin_attempt(dungeon_id):
		if game.has_signal("inventory_event"):
			game.emit_signal("inventory_event", "Not enough dungeon keys.")
		return false

	_dungeon_saved_ctx = _capture_dungeon_context()

	_dungeon_active = true
	_dungeon_id = dungeon_id
	_dungeon_level = ds.get_current_level(dungeon_id)
	
	var limit: float = 0.0
	if ds != null and ds.has_method("time_limit_seconds"):
		limit = float(ds.time_limit_seconds(dungeon_id))

	battle_runtime["dungeon_time_total"] = limit
	battle_runtime["dungeon_time_left"] = limit

	
	battle_runtime["dungeon_id"] = dungeon_id
	battle_runtime["dungeon_level"] = _dungeon_level
	
	# Dungeon combat rules
	var mult: float = 1.0
	#var ds: Variant = (game.get("dungeon_system") if game != null else null)
	if ds != null and (ds as Object).has_method("enemy_damage_mult"):
		mult = float((ds as Object).call("enemy_damage_mult", dungeon_id))
	battle_runtime["dungeon_enemy_damage_mult"] = mult

	# Reset to a clean dungeon fight
	clear_combat_log()
	_skills_init_runtime()
	_battle_reset_effects()
	_battle_recompute_player_combat()

	battle_runtime["player_hp_max"] = _p_hp_max
	battle_runtime["player_hp"] = _p_hp_max
	battle_runtime["status_text"] = "Dungeon"

	_defeat_pause_remaining = 0.0
	_p_atk_accum = 0.0

	_battle_inited = true
	_battle_spawn_enemy(true)
	battle_changed.emit()

	if game.has_signal("dungeon_started"):
		game.emit_signal("dungeon_started", dungeon_id, _dungeon_level)
	return true

func abort_dungeon_run() -> void:
	if not _dungeon_active:
		return
	_finish_dungeon(false, {})

func _capture_dungeon_context() -> Dictionary:
	return {
		"battle_state": battle_state.duplicate(true),
		"battle_runtime": battle_runtime.duplicate(true),
		"battle_inited": _battle_inited,
		"p_atk_accum": _p_atk_accum,
		"defeat_pause": _defeat_pause_remaining,

		"skill_cd": _skill_cd.duplicate(),
		"skill_queue": _skill_queue.duplicate(),
		"skill_lock": _skill_lock,

		"enemies": _enemies.duplicate(true),
		"target_idx": _target_enemy_idx,

		"combat_log_entries": combat_log_entries.duplicate(true),

		"agg_player": _agg_player_hits.duplicate(true),
		"agg_enemy": _agg_enemy_hits.duplicate(true),
		"agg_rewards": _agg_rewards.duplicate(true),
		"agg_flush_accum": _agg_flush_accum,
	}

func _restore_dungeon_context(ctx: Dictionary) -> void:
	if ctx.is_empty():
		return

	battle_state = (ctx.get("battle_state", {}) as Dictionary)
	battle_runtime = (ctx.get("battle_runtime", {}) as Dictionary)

	_battle_inited = bool(ctx.get("battle_inited", true))
	_p_atk_accum = float(ctx.get("p_atk_accum", 0.0))
	_defeat_pause_remaining = float(ctx.get("defeat_pause", 0.0))

	_skill_cd = (ctx.get("skill_cd", [0.0,0.0,0.0,0.0,0.0]) as Array).duplicate()
	_skill_queue = (ctx.get("skill_queue", []) as Array).duplicate()
	_skill_lock = float(ctx.get("skill_lock", 0.0))

	_enemies = (ctx.get("enemies", []) as Array).duplicate(true)
	_target_enemy_idx = int(ctx.get("target_idx", 0))
	_ensure_valid_target()
	__refresh_enemy_totals()

	_agg_player_hits = (ctx.get("agg_player", {"count":0,"dmg":0,"crits":0,"combos":0}) as Dictionary).duplicate(true)
	_agg_enemy_hits = (ctx.get("agg_enemy", {"count":0,"dmg":0,"blocks":0,"avoids":0}) as Dictionary).duplicate(true)
	_agg_rewards = (ctx.get("agg_rewards", {"gold":0,"keys":0,"waves":0,"boss_waves":0}) as Dictionary).duplicate(true)
	_agg_flush_accum = float(ctx.get("agg_flush_accum", 0.0))

	# Restore log entries (re-emit so UI updates)
	var entries: Array = ctx.get("combat_log_entries", [])
	combat_log_entries = entries.duplicate(true)
	combat_log_cleared.emit()
	for e in combat_log_entries:
		combat_log_entry_added.emit(e)

	battle_changed.emit()

func _finish_dungeon(success: bool, reward: Dictionary) -> void:
	var attempted_level: int = _dungeon_level
	var did: String = _dungeon_id

	_dungeon_active = false
	_dungeon_id = ""
	_dungeon_level = 0

	var ctx := _dungeon_saved_ctx
	_dungeon_saved_ctx = {}
	_restore_dungeon_context(ctx)

	if game != null:
		if game.has_signal("player_changed"):
			game.emit_signal("player_changed")
		if game.has_signal("dungeon_finished"):
			game.emit_signal("dungeon_finished", did, attempted_level, success, reward)
