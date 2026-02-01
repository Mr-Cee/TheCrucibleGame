extends Node
#class_name Game

signal player_changed
signal inventory_event(message: String)
signal battle_changed

signal combat_log_added(line: String)
signal combat_log_entry_added(entry: Dictionary)
signal combat_log_cleared

signal dungeon_run_requested(dungeon_id: String, level: int)
signal dungeon_started(dungeon_id: String, level: int)
signal dungeon_finished(dungeon_id: String, attempted_level: int, success: bool, reward: Dictionary)

var _dungeon_return_scene_path: String = ""
var _pending_dungeon_id: String = ""

#===================================================================================================

var player: PlayerModel

# Crucible draw pacing
var crucible_draw_cooldown_base: float = 1.0
var crucible_draw_cooldown_mult: float = 1.0 # battlepass can reduce this, e.g. 0.5
var _upgrade_check_accum: float = 0.0

var task_system: TaskSystem
var battle_system: BattleSystem
var dungeon_system: DungeonSystem

const TIME_VOUCHER_SECONDS: int = 5 * 60 # 5 minutes

#---------------------------------------------------------------------------------------------------
# Proxies for compatibility (SaveManager/UI expect these on Game)
#---------------------------------------------------------------------------------------------------

var battle_state: Dictionary:
	get:
		_ensure_battle_system()
		return battle_system.battle_state

var battle_runtime: Dictionary:
	get:
		_ensure_battle_system()
		return battle_system.battle_runtime

#===================================================================================================

func _ready() -> void:
	_ensure_battle_system()

	# Ensure battle system tracks player updates
	if not player_changed.is_connected(_on_player_changed_forward):
		player_changed.connect(_on_player_changed_forward)

	SaveManager.load_or_new()
	SaveManager.init_autosave_hooks()

	if player != null and not player.leveled_up.is_connected(_on_player_leveled_up):
		player.leveled_up.connect(_on_player_leveled_up)

	# Give battle system the current player (load_or_new may have just created it)
	if battle_system != null:
		battle_system.set_player(player)

	if has_selected_class():
		# Force early init so UI has values immediately
		battle_system.tick(0.0)
	else:
		battle_system.set_idle_status_text("Choose a class to begin.")
		
	if not dungeon_run_requested.is_connected(_on_dungeon_run_requested):
		dungeon_run_requested.connect(_on_dungeon_run_requested)


	task_system = TaskSystem.new()
	add_child(task_system)
	task_system.setup(player)
	
	dungeon_system = DungeonSystem.new()
	add_child(dungeon_system)
	dungeon_system.setup(self, player)

	crucible_tick_upgrade_completion()

func _process(delta: float) -> void:
	_upgrade_check_accum += delta
	if _upgrade_check_accum >= 1.0:
		_upgrade_check_accum = 0.0
		crucible_tick_upgrade_completion()

	# BattleSystem internally checks class selection; safe to tick always.
	if battle_system != null:
		#battle_system.set_player(player) # keep it in sync if player object was replaced on load/new
		battle_system.tick(delta)

#===================================================================================================
# Battle system bootstrapping + signal forwarding
#===================================================================================================

func _ensure_battle_system() -> void:
	if battle_system != null and is_instance_valid(battle_system):
		return

	battle_system = BattleSystem.new()
	battle_system.name = "BattleSystem"
	add_child(battle_system)

	battle_system.setup(self)

	# Forward signals so the rest of the project can keep listening to Game.*
	if not battle_system.battle_changed.is_connected(_on_battle_system_battle_changed):
		battle_system.battle_changed.connect(_on_battle_system_battle_changed)

	if not battle_system.combat_log_added.is_connected(_on_battle_system_combat_log_added):
		battle_system.combat_log_added.connect(_on_battle_system_combat_log_added)

	if not battle_system.combat_log_entry_added.is_connected(_on_battle_system_log_entry_added):
		battle_system.combat_log_entry_added.connect(_on_battle_system_log_entry_added)

	if not battle_system.combat_log_cleared.is_connected(_on_battle_system_log_cleared):
		battle_system.combat_log_cleared.connect(_on_battle_system_log_cleared)

func _on_player_changed_forward() -> void:
	if battle_system != null:
		battle_system.on_player_changed()

func _on_battle_system_battle_changed() -> void:
	battle_changed.emit()

func _on_battle_system_combat_log_added(line: String) -> void:
	combat_log_added.emit(line)

func _on_battle_system_log_entry_added(entry: Dictionary) -> void:
	combat_log_entry_added.emit(entry)

func _on_battle_system_log_cleared() -> void:
	combat_log_cleared.emit()

#===================================================================================================
# Player + inventory
#===================================================================================================

func has_selected_class() -> bool:
	return player != null and int(player.class_id) >= 0

func set_player_class(new_class_id: int, new_class_def_id: String = "") -> void:
	if player == null:
		return
	player.class_id = new_class_id
	if new_class_def_id != "" and "class_def_id" in player:
		player.class_def_id = new_class_def_id
	player_changed.emit()

func add_gold(amount: int) -> void:
	player.gold += amount
	player_changed.emit()

func _on_player_leveled_up(levels_gained: int) -> void:
	if "task_system" in self and task_system != null:
		task_system.notify_level_up(levels_gained)

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
	player_changed.emit()
	return true

func equip_item(item: GearItem) -> GearItem:
	if item == null:
		return null

	var slot: int = int(item.slot)
	var old: GearItem = player.equipped.get(slot, null)

	player.equipped[slot] = item
	player_changed.emit()
	return old

func sell_item(item: GearItem) -> int:
	var base := item.item_level * 10
	var mult: float = float(Catalog.RARITY_STAT_MULT.get(item.rarity, 1.0))
	var value := int(round(base * mult))
	add_gold(value)
	inventory_event.emit("Sold for %d gold" % value)
	return value


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

#===================================================================================================
# Battle state API (wrappers)
#===================================================================================================

func reset_battle_state() -> void:
	_ensure_battle_system()
	battle_system.reset_battle_state()

func set_battle_state(state: Dictionary) -> void:
	_ensure_battle_system()
	battle_system.set_battle_state(state)

func patch_battle_state(patch: Dictionary) -> void:
	_ensure_battle_system()
	battle_system.patch_battle_state(patch)

func dev_set_battle_position(diff: String, level: int, stage: int, wave: int) -> void:
	_ensure_battle_system()
	battle_system.dev_set_battle_position(diff, level, stage, wave)

#===================================================================================================
# Skills API (wrappers)
#===================================================================================================

func skills_auto_enabled() -> bool:
	_ensure_battle_system()
	return battle_system.skills_auto_enabled()

func set_skills_auto_enabled(enabled: bool) -> void:
	_ensure_battle_system()
	battle_system.set_skills_auto_enabled(enabled)
	# Persist is done on player; keep standard signal
	player_changed.emit()

func get_equipped_active_skill_id(slot: int) -> String:
	_ensure_battle_system()
	return battle_system.get_equipped_active_skill_id(slot)

func get_skill_cooldown_remaining(slot: int) -> float:
	_ensure_battle_system()
	return battle_system.get_skill_cooldown_remaining(slot)

func get_skill_cooldown_total(slot: int) -> float:
	_ensure_battle_system()
	return battle_system.get_skill_cooldown_total(slot)

func request_cast_active_skill(slot: int) -> void:
	_ensure_battle_system()
	battle_system.request_cast_active_skill(slot)

#===================================================================================================
# Combat log API (wrappers)
#===================================================================================================

func combat_log_text() -> String:
	_ensure_battle_system()
	return battle_system.combat_log_text()

func set_combat_log_compact_user(enabled: bool) -> void:
	_ensure_battle_system()
	battle_system.set_combat_log_compact_user(enabled)

func combat_log_compact_effective() -> bool:
	_ensure_battle_system()
	return battle_system.combat_log_compact_effective()

func clear_combat_log() -> void:
	_ensure_battle_system()
	battle_system.clear_combat_log()

func get_combat_log_entries() -> Array[Dictionary]:
	_ensure_battle_system()
	return battle_system.get_combat_log_entries()

func log_combat(category: String, severity: String, message_bbcode: String) -> void:
	_ensure_battle_system()
	battle_system.log_combat(category, severity, message_bbcode)

#===================================================================================================
# Crucible + upgrade system (unchanged)
#===================================================================================================

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

	player_changed.emit()
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

	player_changed.emit()
	return true

func crucible_tick_upgrade_completion() -> void:
	if not crucible_is_upgrading():
		return

	var remaining: int = crucible_upgrade_seconds_remaining()
	if remaining > 0:
		return

	var target: int = player.crucible_upgrade_target_level
	if target <= player.crucible_level:
		player.crucible_upgrade_paid_stages = 0
		player.crucible_upgrade_target_level = 0
		player.crucible_upgrade_finish_unix = 0
		player_changed.emit()
		return

	player.crucible_level = target

	player.crucible_upgrade_paid_stages = 0
	player.crucible_upgrade_target_level = 0
	player.crucible_upgrade_finish_unix = 0

	inventory_event.emit("Crucible upgraded to Lv.%d" % player.crucible_level)
	player_changed.emit()

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

#===================================================================================================

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

func get_enemies_snapshot() -> Array[Dictionary]:
	if battle_system == null:
		return []
	return battle_system.get_enemies_snapshot()

func get_target_enemy_index() -> int:
	if battle_system == null:
		return -1
	return battle_system.get_target_enemy_index()

func dungeon_request_run(dungeon_id: String) -> bool:
	if dungeon_system == null:
		return false
	if not dungeon_system.can_attempt(dungeon_id):
		inventory_event.emit("Not enough dungeon keys.")
		return false

	var lvl: int = dungeon_system.get_current_level(dungeon_id)
	dungeon_run_requested.emit(dungeon_id, lvl)
	inventory_event.emit("Dungeon requested: %s (Level %d)" % [dungeon_id, lvl])
	return true

func dungeon_sweep(dungeon_id: String) -> Dictionary:
	if dungeon_system == null:
		return {}

	var reward: Dictionary = dungeon_system.sweep(dungeon_id)
	if reward.is_empty():
		inventory_event.emit("Sweep unavailable.")
		return {}

	player_changed.emit()
	inventory_event.emit("Swept dungeon and gained: %s" % dungeon_system.reward_to_text(reward))
	return reward

func add_dungeon_keys(dungeon_id: String, amount: int) -> void:
	if dungeon_system == null or amount == 0:
		return
	dungeon_system.add_keys(dungeon_id, amount)
	player_changed.emit()

func _on_dungeon_run_requested(dungeon_id: String, _level: int) -> void:
	begin_dungeon_scene(dungeon_id)

func abort_dungeon_run() -> void:
	if battle_system != null:
		battle_system.abort_dungeon_run()

func clear_popup_root_children() -> void:
	var ui: Control = popup_root()
	for c in ui.get_children():
		c.queue_free()

func begin_dungeon_scene(dungeon_id: String) -> void:
	# Save where we came from so we can return.
	var cs := get_tree().current_scene
	_dungeon_return_scene_path = (cs.scene_file_path if cs != null else "")
	_pending_dungeon_id = dungeon_id

	# Ensure no overlays remain above the new scene.
	clear_popup_root_children()

	# Change to the dungeon-only scene.
	get_tree().change_scene_to_file("res://scenes/ui/DungeonScene.tscn") # <- adjust path to your project

func pop_pending_dungeon_id() -> String:
	var id := _pending_dungeon_id
	_pending_dungeon_id = ""
	return id

func return_from_dungeon_scene() -> void:
	clear_popup_root_children()
	if _dungeon_return_scene_path != "":
		get_tree().change_scene_to_file(_dungeon_return_scene_path)
	else:
		# Fallback if current scene had no file path (rare)
		get_tree().change_scene_to_file("res://scenes/Home.tscn") # <- adjust

func show_dungeon_result_popup(dungeon_id: String, attempted_level: int, success: bool, reward: Dictionary) -> void:
	var ui := popup_root()
	var p := DungeonResultPopup.new()
	p.setup(dungeon_id, attempted_level, success, reward)

	# When results close, reopen the dungeon list panel
	if not p.closed.is_connected(_on_dungeon_result_popup_closed):
		p.closed.connect(_on_dungeon_result_popup_closed)

	ui.add_child(p)

func _on_dungeon_result_popup_closed() -> void:
	open_dungeon_panel()

func open_dungeon_panel() -> void:
	var ui := popup_root()
	var panel := DungeonsPanel.new() # rename if your class_name differs
	ui.add_child(panel)

func can_challenge_wave5() -> bool:
	return battle_system != null and battle_system.can_challenge_wave5()

func challenge_wave5() -> void:
	if battle_system != null:
		battle_system.challenge_wave5()

func offline_capture_pending_on_load(force: bool = false) -> Dictionary:
	if player == null:
		return {"queued": false, "reason": "no_player"}

	# If we already have pending rewards, do not re-simulate (prevents double counting).
	# Dev tools can force a re-simulate.
	if not force and not _offline_pending_dict().is_empty():
		return {"queued": false, "reason": "already_pending"}

	if force:
		player.offline_pending = {}

	var now_unix: int = int(Time.get_unix_time_from_system())
	var last_unix: int = int(player.last_active_unix)

	# Always maintain daily reset bookkeeping
	OfflineRewards.reset_bonus_if_new_day(player, now_unix)

	if last_unix <= 0:
		player.last_active_unix = now_unix
		return {"queued": false, "reason": "no_last_active"}

	var dt: int = now_unix - last_unix
	if dt <= 0:
		player.last_active_unix = now_unix
		return {"queued": false, "reason": "nonpositive_dt", "dt": dt}

	var cap: int = OfflineRewards.offline_cap_seconds_for_player(player, now_unix)
	var capped: int = mini(dt, cap)

	# Require at least 30 seconds before we queue anything
	if capped < 30:
		player.last_active_unix = now_unix
		return {"queued": false, "reason": "too_small", "dt": dt, "cap": cap, "capped": capped}

	# Snapshot battle position used for sim
	var diff: String = String(battle_state.get("difficulty", "Easy"))
	var lvl: int = int(battle_state.get("level", 1))

	var sim: Dictionary = OfflineRewards.offline_simulate_rewards(player.level, diff, lvl, capped)

	var gold_gain: int = int(sim.get("gold", 0))
	var key_gain: int = int(sim.get("keys", 0))
	var xp_gain: int = int(sim.get("xp", 0))

	player.offline_pending = {
		"available": true,
		"raw_seconds": dt,
		"cap_seconds": cap,
		"base_seconds": capped,

		"difficulty": diff,
		"battle_level": lvl,

		"gold": gold_gain,
		"keys": key_gain,
		"xp": xp_gain,

		"bonus_seconds": 0,
		"bonus_gold": 0,
		"bonus_keys": 0,
		"bonus_xp": 0,
	}

	# Advance last_active_unix NOW so we don't re-award next launch.
	player.last_active_unix = now_unix

	return {
		"queued": true,
		"dt": dt,
		"cap": cap,
		"capped": capped,
		"gold": gold_gain,
		"keys": key_gain,
		"xp": xp_gain,
		"diff": diff,
		"level": lvl,
	}

func _offline_pending_dict() -> Dictionary:
	if player == null:
		return {}

	# Works whether offline_pending is a declared var OR a dynamic property.
	var v: Variant = null
	if player.has_method("get"):
		v = player.get("offline_pending")
	else:
		# If PlayerModel is typed and has offline_pending, this is fine.
		v = player.offline_pending

	return v if (v is Dictionary) else {}

func offline_has_pending() -> bool:
	var pend := _offline_pending_dict()
	return not pend.is_empty()

func offline_get_pending() -> Dictionary:
	return _offline_pending_dict()

func offline_apply_bonus_2h() -> Dictionary:
	if not offline_has_pending():
		return {"ok": false, "reason": "no_pending"}

	var now_unix: int = int(Time.get_unix_time_from_system())
	if not OfflineRewards.consume_bonus_use(player, now_unix):
		return {"ok": false, "reason": "limit"}

	var pend: Dictionary = player.offline_pending
	var diff: String = String(pend.get("difficulty", String(battle_state.get("difficulty", "Easy"))))
	var lvl: int = int(pend.get("battle_level", int(battle_state.get("level", 1))))

	var sim: Dictionary = OfflineRewards.offline_simulate_rewards(player.level, diff, lvl, OfflineRewards.OFFLINE_BONUS_SECONDS)

	pend["bonus_seconds"] = int(pend.get("bonus_seconds", 0)) + OfflineRewards.OFFLINE_BONUS_SECONDS
	pend["bonus_gold"] = int(pend.get("bonus_gold", 0)) + int(sim.get("gold", 0))
	pend["bonus_keys"] = int(pend.get("bonus_keys", 0)) + int(sim.get("keys", 0))
	pend["bonus_xp"] = int(pend.get("bonus_xp", 0)) + int(sim.get("xp", 0))

	player.offline_pending = pend
	player_changed.emit()
	SaveManager.save_now()

	return {
		"ok": true,
		"added_seconds": OfflineRewards.OFFLINE_BONUS_SECONDS,
		"gold": int(sim.get("gold", 0)),
		"keys": int(sim.get("keys", 0)),
		"xp": int(sim.get("xp", 0)),
		"uses_remaining": OfflineRewards.bonus_uses_remaining(player, now_unix),
	}

func offline_claim_pending() -> Dictionary:
	if not offline_has_pending():
		return {"ok": false, "reason": "no_pending"}

	var pend: Dictionary = player.offline_pending

	var gold_gain: int = int(pend.get("gold", 0)) + int(pend.get("bonus_gold", 0))
	var key_gain: int = int(pend.get("keys", 0)) + int(pend.get("bonus_keys", 0))
	var xp_gain: int = int(pend.get("xp", 0)) + int(pend.get("bonus_xp", 0))

	if gold_gain != 0:
		player.gold += gold_gain
	if key_gain != 0:
		player.crucible_keys += key_gain

	var levels: int = 0
	if xp_gain > 0:
		levels = player.add_xp(xp_gain)

	# Clear pending so it cannot be claimed twice
	player.offline_pending = {}
	player_changed.emit()
	SaveManager.save_now()

	inventory_event.emit("Offline rewards claimed: +%d gold, +%d keys, +%d XP" % [gold_gain, key_gain, xp_gain])
	if levels > 0:
		inventory_event.emit("Level Up! Lv.%d" % player.level)

	return {"ok": true, "gold": gold_gain, "keys": key_gain, "xp": xp_gain, "levels": levels}
