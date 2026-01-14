extends Node
class_name TaskSystem

signal changed

var _player # PlayerModel (kept untyped here to avoid compile issues if your class_name differs)
var _state: TaskState

var _tasks: Array[TaskDef] = []
var _task_map: Dictionary = {} # id -> TaskDef
var _sequence: Array[String] = [] # ordered ids

var _rewards: Array[RewardDef] = []
var _rng := RandomNumberGenerator.new()

func setup(player_model) -> void:
	_player = player_model
	_rng.randomize()

	_build_default_tasks()
	_build_default_rewards()

	_load_state_from_player()
	_sanitize_and_initialize_state()

	emit_signal("changed")

# -------------------------
# Public query helpers
# -------------------------
func current_text() -> String:
	var def := _current_task()
	if def == null:
		return ""

	var progress := _state.progress
	if def.kind == TaskDef.Kind.LEVEL_UPS and _player != null:
		progress = min(int(_player.level), _state.required)

	return def.format_text(progress, _state.required)


func is_complete() -> bool:
	var def := _current_task()
	if def == null:
		return false

	if def.kind == TaskDef.Kind.LEVEL_UPS:
		if _player == null:
			return false
		return int(_player.level) >= _state.required

	return _state.required > 0 and _state.progress >= _state.required


# -------------------------
# Event hooks
# -------------------------
func notify_enemy_killed(count: int = 1) -> void:
	_notify(TaskDef.Kind.KILL_ENEMIES, count)

func notify_crucible_drawn(count: int = 1) -> void:
	_notify(TaskDef.Kind.CRUCIBLE_DRAWS, count)

func notify_skill_drawn(count: int = 1) -> void:
	_notify(TaskDef.Kind.SKILL_DRAWS, count)

func notify_level_up(count: int = 1) -> void:
	var def := _current_task()
	if def == null or def.kind != TaskDef.Kind.LEVEL_UPS:
		return
	if _player == null:
		return

	# Store capped level purely for display purposes
	_state.progress = min(int(_player.level), _state.required)

	_persist_to_player()
	emit_signal("changed")

# -------------------------
# Claim + advance
# -------------------------
func claim_reward_if_complete() -> Dictionary:
	if not is_complete():
		return {}

	var reward := _roll_reward()
	_apply_reward(reward)

	_increment_tier(_state.current_task_id)
	_advance_to_next_task()

	_persist_to_player()
	emit_signal("changed")
	return reward

func reward_to_text(reward: Dictionary) -> String:
	var kind := int(reward.get("kind", -1))
	var amt := int(reward.get("amount", 0))
	match kind:
		RewardDef.Kind.CRUCIBLE_KEYS: return "%d Crucible Key(s)" % amt
		RewardDef.Kind.TIME_VOUCHERS: return "%d Time Voucher(s)" % amt
		RewardDef.Kind.SKILL_TICKETS: return "%d Skill Ticket(s)" % amt
		RewardDef.Kind.CRYSTALS: return "%d Crystal(s)" % amt
		_: return "Reward"

# -------------------------
# Internals
# -------------------------
func _notify(expected_kind: int, amount: int) -> void:
	var def := _current_task()
	if def == null or def.kind != expected_kind:
		return
	if is_complete():
		return

	_state.progress = min(_state.required, _state.progress + max(0, amount))
	_persist_to_player()
	emit_signal("changed")

func _current_task() -> TaskDef:
	return _task_map.get(_state.current_task_id, null)

func _task_index(id: String) -> int:
	for i in range(_sequence.size()):
		if _sequence[i] == id:
			return i
	return -1

func _advance_to_next_task() -> void:
	var idx := _task_index(_state.current_task_id)
	if idx < 0:
		_state.current_task_id = _sequence[0]
	else:
		_state.current_task_id = _sequence[(idx + 1) % _sequence.size()]

	_state.progress = 0
	_state.required = _compute_required(_state.current_task_id)

func _increment_tier(task_id: String) -> void:
	var t := int(_state.tiers.get(task_id, 0))
	_state.tiers[task_id] = t + 1

func _compute_required(task_id: String) -> int:
	var def: TaskDef = _task_map.get(task_id, null)
	if def == null:
		return 1

	var tier := int(_state.tiers.get(task_id, 0))
	var req := def.required_for_tier(tier)

	# Guardrail: never decrease requirement, even if base/step changes later.
	var prev_max := int(_state.max_required_seen.get(task_id, 0))
	if req < prev_max:
		req = prev_max
	else:
		_state.max_required_seen[task_id] = req

	return max(1, req)

func _sanitize_and_initialize_state() -> void:
	if _sequence.is_empty():
		# Should not happen, but avoid crashes.
		_state.current_task_id = ""
		_state.progress = 0
		_state.required = 1
		_persist_to_player()
		return

	if _state.current_task_id == "" or not _task_map.has(_state.current_task_id):
		_state.current_task_id = _sequence[0]

	_state.required = _compute_required(_state.current_task_id)
	_state.progress = clamp(_state.progress, 0, _state.required)
	
	var def := _current_task()
	if def != null and def.kind == TaskDef.Kind.LEVEL_UPS and _player != null:
		_state.progress = min(int(_player.level), _state.required)
	else:
		_state.progress = clamp(_state.progress, 0, _state.required)

	_persist_to_player()

func _load_state_from_player() -> void:
	# Expecting PlayerModel to store a Dictionary called task_state (added in section 2).
	var raw: Dictionary = {}
	if _player != null and "task_state" in _player:
		raw = _player.task_state
	_state = TaskState.from_dict(raw)

func _persist_to_player() -> void:
	if _player == null:
		return
	if "task_state" in _player:
		_player.task_state = _state.to_dict()

# -------------------------
# Default catalogs (easy to extend)
# -------------------------
func _build_default_tasks() -> void:
	_tasks.clear()
	_task_map.clear()
	_sequence.clear()

	_add_task("kill_enemies", TaskDef.Kind.KILL_ENEMIES, 25, 10)
	_add_task("crucible_draws", TaskDef.Kind.CRUCIBLE_DRAWS, 5, 2)
	_add_task("skill_draws", TaskDef.Kind.SKILL_DRAWS, 3, 1)
	_add_task("level_ups", TaskDef.Kind.LEVEL_UPS, 10, 1)


func _add_task(id: String, kind: int, base_req: int, step_req: int) -> void:
	var t := TaskDef.new()
	t.id = id
	t.kind = kind
	t.base_required = base_req
	t.step_required = step_req

	_tasks.append(t)
	_task_map[id] = t
	_sequence.append(id)

func _build_default_rewards() -> void:
	_rewards.clear()

	# Tune weights/amounts as you like:
	_add_reward(RewardDef.Kind.CRUCIBLE_KEYS, 1, 3, 45)
	_add_reward(RewardDef.Kind.TIME_VOUCHERS, 1, 2, 20)
	_add_reward(RewardDef.Kind.SKILL_TICKETS, 1, 2, 20)
	_add_reward(RewardDef.Kind.CRYSTALS, 10, 40, 15)

func _add_reward(kind: int, min_amt: int, max_amt: int, weight: int) -> void:
	var r := RewardDef.new()
	r.kind = kind
	r.min_amount = min_amt
	r.max_amount = max_amt
	r.weight = weight
	_rewards.append(r)

func _roll_reward() -> Dictionary:
	var total := 0
	for r in _rewards:
		total += max(0, r.weight)

	if total <= 0:
		return {"kind": RewardDef.Kind.CRYSTALS, "amount": 1}

	var pick := _rng.randi_range(1, total)
	var running := 0
	for r in _rewards:
		running += max(0, r.weight)
		if pick <= running:
			return {"kind": r.kind, "amount": r.roll_amount(_rng)}

	return {"kind": RewardDef.Kind.CRYSTALS, "amount": 1}

func _apply_reward(reward: Dictionary) -> void:
	var kind := int(reward.get("kind", -1))
	var amount := int(reward.get("amount", 0))
	if amount <= 0 or _player == null:
		return

	# Strongly recommended: route through a single PlayerModel method so rewards
	# don’t care about your internal currency field names.
	if "add_task_reward" in _player:
		_player.add_task_reward(kind, amount)
		return

	# Fallback: map to fields (rename these to match your PlayerModel).
	match kind:
		RewardDef.Kind.CRUCIBLE_KEYS:
			if "crucible_keys" in _player: _player.crucible_keys += amount
		RewardDef.Kind.TIME_VOUCHERS:
			if "time_vouchers" in _player: _player.time_vouchers += amount
		RewardDef.Kind.SKILL_TICKETS:
			if "skill_tickets" in _player: _player.skill_tickets += amount
		RewardDef.Kind.CRYSTALS:
			if "crystals" in _player: _player.crystals += amount
