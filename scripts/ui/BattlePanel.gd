extends VBoxContainer

@onready var difficulty_label: Label = $DifficultyLabel
@onready var enemy_hp_bar: ProgressBar = $EnemyHPBar
@onready var battle_area: Control = $BattleArea

# Speed UI lives elsewhere:
@onready var speed_label: Label = $"../CrucibleRow/SpeedBox/SpeedVBox/SpeedLabel"
@onready var speed_button: OptionButton = $"../CrucibleRow/SpeedBox/SpeedVBox/SpeedButton"

# Progression: Difficulty > Level(1..10) > Stage(1..10) > Wave(1..5)
var difficulty_name: String = "Easy"
var level: int = 1
var stage: int = 1
var wave: int = 1

var _wave_time: float = 2.5
var _timer: float = 0.0
var _speed_mult: float = 1.0

func _ready() -> void:
	# Configure the enemy bar as a temporary "wave progress" bar.
	enemy_hp_bar.min_value = 0.0
	enemy_hp_bar.max_value = 100.0
	enemy_hp_bar.value = 0.0

	# Configure speed options
	speed_button.clear()
	speed_button.add_item("1x", 0)
	speed_button.add_item("3x", 1)
	speed_button.add_item("5x", 2)
	speed_button.add_item("10x", 3)
	speed_button.selected = 0
	speed_button.item_selected.connect(_on_speed_selected)
	_sync_speed_label()
	
	_load_from_game_state()


	_refresh_labels()

func _process(delta: float) -> void:
	_timer += delta * _speed_mult
	var pct: float = clampf((_timer / _wave_time) * 100.0, 0.0, 100.0)
	enemy_hp_bar.value = pct

	if _timer >= _wave_time:
		_timer = 0.0
		_complete_wave()

func _complete_wave() -> void:
	# MVP rewards (tune later)
	var gold_gain: int = 5 + (level - 1) * 2 + (stage - 1)
	Game.add_gold(gold_gain)

	var is_boss: bool = (wave == 5)
	if is_boss and RNG.randf() < 0.20:
		Game.player.crucible_keys += 1
		Game.player_changed.emit()

	# Advance wave/stage/level
	wave += 1
	if wave > 5:
		wave = 1
		stage += 1
		if stage > 10:
			stage = 1
			level += 1
			if level > 10:
				level = 1
				difficulty_name = "Hard"

	_refresh_labels()
	
	Game.patch_battle_state({
		"difficulty": difficulty_name,
		"level": level,
		"stage": stage,
		"wave": wave,
	})

func _refresh_labels() -> void:
	var wave_txt := "Boss" if wave == 5 else "Wave %d/5" % wave
	difficulty_label.text = "%s - %d - %d (%s)" % [difficulty_name, level, stage, wave_txt]

func _on_speed_selected(idx: int) -> void:
	match idx:
		0: _speed_mult = 1.0
		1: _speed_mult = 3.0
		2: _speed_mult = 5.0
		3: _speed_mult = 10.0
	_sync_speed_label()
	Game.patch_battle_state({
		"speed_idx": idx,
	})


func _sync_speed_label() -> void:
	if is_instance_valid(speed_label):
		speed_label.text = "Speed: %.0fx" % _speed_mult

func _load_from_game_state() -> void:
	var st: Dictionary = Game.battle_state

	difficulty_name = String(st.get("difficulty", "Easy"))
	level = int(st.get("level", 1))
	stage = int(st.get("stage", 1))
	wave = int(st.get("wave", 1))

	var idx: int = int(st.get("speed_idx", 0))
	idx = clampi(idx, 0, 3)

	# Apply speed selection
	speed_button.selected = idx
	_on_speed_selected(idx) # sets _speed_mult and label
