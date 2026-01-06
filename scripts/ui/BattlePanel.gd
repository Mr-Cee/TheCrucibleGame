extends VBoxContainer  # or VBoxContainer / PanelContainer, whichever node it is attached to

@onready var difficulty_label: Label = $DifficultyLabel
@onready var enemy_hp_bar: ProgressBar = $EnemyHPBar

var _hp_ui_accum: float = 0.0


func _ready() -> void:
	Game.battle_changed.connect(_refresh)
	_refresh()
	
func _process(delta: float) -> void:
	_hp_ui_accum += delta
	if _hp_ui_accum < 0.10:
		return
	_hp_ui_accum = 0.0

	# Enemy HP
	var ehp: float = float(Game.battle_runtime.get("enemy_hp", 0.0))
	var ehpmax: float = max(1.0, float(Game.battle_runtime.get("enemy_hp_max", 1.0)))
	enemy_hp_bar.max_value = 100.0
	enemy_hp_bar.value = (ehp / ehpmax) * 100.0
	

func _refresh() -> void:
	var diff: String = String(Game.battle_state.get("difficulty", "Easy"))
	var lvl: int = int(Game.battle_state.get("level", 1))
	var stage: int = int(Game.battle_state.get("stage", 1))
	var wave: int = int(Game.battle_state.get("wave", 1))

	difficulty_label.text = "%s - %d - %d  |  Wave %d/5" % [diff, lvl, stage, wave]

	var hp: float = float(Game.battle_runtime.get("enemy_hp", 0.0))
	var hp_max: float = max(1.0, float(Game.battle_runtime.get("enemy_hp_max", 1.0)))
	enemy_hp_bar.value = (hp / hp_max) * 100.0
