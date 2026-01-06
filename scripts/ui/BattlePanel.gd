extends VBoxContainer

@onready var stage_label: Label = $HeaderRow/StageLabel
@onready var wave_label: Label = $HeaderRow/WaveLabel
@onready var speed_button: OptionButton = $HeaderRow/SpeedButton
@onready var manual_toggle: CheckButton = $HeaderRow/ManualToggle

@onready var enemy_label: Label = $EnemyLabel
@onready var progress: ProgressBar = $Progress
@onready var rewards_label: Label = $RewardsLabel

func _ready() -> void:
	# Populate speeds
	speed_button.clear()
	speed_button.add_item("1x", 0)
	speed_button.add_item("3x", 1)
	speed_button.add_item("5x", 2)
	speed_button.add_item("10x", 3)

	speed_button.item_selected.connect(_on_speed_selected)
	manual_toggle.toggled.connect(_on_manual_toggled)

	Game.battle_changed.connect(_refresh)
	Game.player_changed.connect(_refresh)

	_refresh()

func _refresh() -> void:
	var diff: String = String(Game.battle_state.get("difficulty", "Easy"))
	var lvl: int = int(Game.battle_state.get("level", 1))
	var stage: int = int(Game.battle_state.get("stage", 1))
	var wave: int = int(Game.battle_state.get("wave", 1))
	var speed_idx: int = int(Game.battle_state.get("speed_idx", 0))

	stage_label.text = "%s - %d - %d" % [diff, lvl, stage]
	wave_label.text = "Wave %d / 5" % wave

	var en: String = String(Game.battle_runtime.get("enemy_name", "Enemy"))
	var is_boss: bool = bool(Game.battle_runtime.get("is_boss", false))
	enemy_label.text = "%s%s" % [en, (" (Boss)" if is_boss else "")]

	var hp: float = float(Game.battle_runtime.get("enemy_hp", 0.0))
	var hp_max: float = max(1.0, float(Game.battle_runtime.get("enemy_hp_max", 1.0)))
	progress.value = (hp / hp_max) * 100.0

	speed_button.selected = clampi(speed_idx, 0, 3)

func _on_speed_selected(idx: int) -> void:
	Game.patch_battle_state({"speed_idx": idx})

func _on_manual_toggled(on: bool) -> void:
	Game.patch_battle_state({"manual_skills": on})
