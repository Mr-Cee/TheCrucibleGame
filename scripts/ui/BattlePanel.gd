extends VBoxContainer

@onready var difficulty_label: Label = $DifficultyLabel
@onready var enemy_hp_bar: ProgressBar = $EnemyHPBar

# Optional (only if you have it in this node). If you don't, that's fine.
@onready var rewards_label: Label = get_node_or_null("RewardsLabel") as Label
@onready var enemy_label: Label = get_node_or_null("EnemyLabel") as Label

var _wave_time: float = 2.5
var _timer: float = 0.0

func _ready() -> void:
	# Keep UI synced if something else patches battle_state (speedbox, load, etc.)
	if not Game.battle_changed.is_connected(_on_battle_changed):
		Game.battle_changed.connect(_on_battle_changed)

	_apply_state_to_ui()

func _process(delta: float) -> void:
	var speed_mult: float = _speed_mult_from_state()
	_timer += delta * speed_mult

	# For now, we treat this bar like "wave progress" until real HP combat is wired.
	if enemy_hp_bar:
		enemy_hp_bar.value = clampf((_timer / _wave_time) * 100.0, 0.0, 100.0)

	if _timer >= _wave_time:
		_timer = 0.0
		_complete_wave()

func _speed_mult_from_state() -> float:
	var idx: int = int(Game.battle_state.get("speed_idx", 0))
	match idx:
		0: return 1.0
		1: return 3.0
		2: return 5.0
		3: return 10.0
		_: return 1.0

func _complete_wave() -> void:
	var difficulty: String = String(Game.battle_state.get("difficulty", "Easy"))
	var level: int = int(Game.battle_state.get("level", 1))
	var stage: int = int(Game.battle_state.get("stage", 1))
	var wave: int = int(Game.battle_state.get("wave", 1))

	var is_boss: bool = (wave == 5)

	# Rewards every wave + boss bonus on wave 5
	var gold_gain: int = Catalog.battle_gold_for_wave(difficulty, level, stage, wave, is_boss)
	var key_gain: int = Catalog.battle_keys_for_wave(difficulty, level, stage, wave, is_boss)
	Game.add_battle_rewards(gold_gain, key_gain)

	if rewards_label:
		rewards_label.text = "Last: +%d gold, +%d keys%s" % [
			gold_gain,
			key_gain,
			(" (boss)" if is_boss else "")
		]

	# Advance wave/stage/level/difficulty
	wave += 1
	if wave > 5:
		wave = 1
		stage += 1
		if stage > 10:
			stage = 1
			level += 1
			if level > 10:
				level = 1
				difficulty = "Hard" # expand later

	# Persist progression via Game (autosave hooks listen to battle_changed)
	Game.patch_battle_state({
		"difficulty": difficulty,
		"level": level,
		"stage": stage,
		"wave": wave,
	})

	_apply_state_to_ui()

func _apply_state_to_ui() -> void:
	var difficulty: String = String(Game.battle_state.get("difficulty", "Easy"))
	var level: int = int(Game.battle_state.get("level", 1))
	var stage: int = int(Game.battle_state.get("stage", 1))
	var wave: int = int(Game.battle_state.get("wave", 1))

	if difficulty_label:
		difficulty_label.text = "%s - %d - %d (Wave %d/5)" % [difficulty, level, stage, wave]

	if enemy_label:
		enemy_label.text = ("Boss approaching..." if wave == 5 else "Enemy wave...")

func _on_battle_changed() -> void:
	_apply_state_to_ui()
