extends VBoxContainer

@onready var difficulty_label: Label = $DifficultyLabel
@onready var enemy_hp_bar: ProgressBar = $EnemyHPBar

var _ui_accum: float = 0.0

func _ready() -> void:
	_apply_labels()

func _process(delta: float) -> void:
	_ui_accum += delta
	if _ui_accum < 0.10:
		return
	_ui_accum = 0.0

	_apply_labels()
	_apply_enemy_hp()

func _apply_labels() -> void:
	var diff: String = String(Game.battle_state.get("difficulty", "Easy"))
	var lvl: int = int(Game.battle_state.get("level", 1))
	var stg: int = int(Game.battle_state.get("stage", 1))
	var wav: int = int(Game.battle_state.get("wave", 1))

	difficulty_label.text = "%s - %d - %d (Wave %d/%d)" % [
		diff, lvl, stg, wav, Catalog.BATTLE_WAVES_PER_STAGE
	]

func _apply_enemy_hp() -> void:
	var hp: float = float(Game.battle_runtime.get("enemy_hp", 0.0))
	var hp_max: float = max(1.0, float(Game.battle_runtime.get("enemy_hp_max", 1.0)))

	enemy_hp_bar.max_value = 100.0
	enemy_hp_bar.value = (hp / hp_max) * 100.0
