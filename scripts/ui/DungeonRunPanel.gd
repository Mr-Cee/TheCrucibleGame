extends Control
class_name DungeonRunPanel

var _title: Label
var _p_bar: ProgressBar
var _e_bar: ProgressBar
var _p_lbl: Label
var _e_lbl: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 520)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	root.add_child(_title)

	_p_lbl = Label.new()
	root.add_child(_p_lbl)

	_p_bar = ProgressBar.new()
	_p_bar.max_value = 100
	_p_bar.value = 100
	root.add_child(_p_bar)

	_e_lbl = Label.new()
	root.add_child(_e_lbl)

	_e_bar = ProgressBar.new()
	_e_bar.max_value = 100
	_e_bar.value = 100
	root.add_child(_e_bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)

	var leave := Button.new()
	leave.text = "Leave"
	leave.pressed.connect(_on_leave_pressed)
	row.add_child(leave)

	# Wire signals
	Game.dungeon_started.connect(_on_dungeon_started)
	Game.dungeon_finished.connect(_on_dungeon_finished)

func _process(_delta: float) -> void:
	# Pull from Game’s battle_runtime (dungeon uses the same battle loop)
	var pr: Dictionary = Game.battle_runtime

	var p_hp: float = float(pr.get("player_hp", 0.0))
	var p_max: float = max(1.0, float(pr.get("player_hp_max", 1.0)))
	_p_bar.max_value = p_max
	_p_bar.value = p_hp
	_p_lbl.text = "Player HP: %d / %d" % [int(round(p_hp)), int(round(p_max))]

	var e_hp: float = float(pr.get("enemy_hp", 0.0))
	var e_max: float = max(1.0, float(pr.get("enemy_hp_max", 1.0)))
	_e_bar.max_value = e_max
	_e_bar.value = e_hp

	var enemy_name: String = String(pr.get("enemy_name", "Boss"))
	_e_lbl.text = "%s HP: %d / %d" % [enemy_name, int(round(e_hp)), int(round(e_max))]

func _on_dungeon_started(dungeon_id: String, level: int) -> void:
	var def := DungeonCatalog.get_def(dungeon_id)
	if def != null:
		_title.text = "%s - Level %d" % [def.display_name, level]
	else:
		_title.text = "Dungeon - Level %d" % level

func _on_dungeon_finished(_dungeon_id: String, _attempted_level: int, _success: bool, _reward: Dictionary) -> void:
	queue_free()

func _on_leave_pressed() -> void:
	Game.abort_dungeon_run()
