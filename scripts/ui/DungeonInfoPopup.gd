extends Control
class_name DungeonInfoPopup

var _game: Node = null
var _dungeon_id: String = ""

var _status_label: Label = null
var _attempt_btn: Button = null
var _sweep_btn: Button = null

func open_for_dungeon(game: Node, dungeon_id: String) -> void:
	_game = game
	_dungeon_id = dungeon_id
	visible = true
	_refresh()

func _ready() -> void:
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Dim
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.anchor_right = 1
	dim.anchor_bottom = 1
	add_child(dim)
	
	dim.gui_input.connect(_on_dim_gui_input)

	# Center panel
	var center := CenterContainer.new()
	center.anchor_right = 1
	center.anchor_bottom = 1
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 420)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var title := Label.new()
	title.text = "Dungeon"
	title.add_theme_font_size_override("font_size", 18)
	root.add_child(title)

	var desc := Label.new()
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.text = ""
	desc.name = "DescLabel"
	root.add_child(desc)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = ""
	root.add_child(_status_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	root.add_child(buttons)

	_attempt_btn = Button.new()
	_attempt_btn.text = "Attempt"
	_attempt_btn.pressed.connect(_on_attempt_pressed)
	buttons.add_child(_attempt_btn)

	_sweep_btn = Button.new()
	_sweep_btn.text = "Sweep"
	_sweep_btn.pressed.connect(_on_sweep_pressed)
	buttons.add_child(_sweep_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_close_pressed)
	buttons.add_child(close_btn)

func _refresh() -> void:
	if _dungeon_id == "":
		return

	var def := DungeonCatalog.get_def(_dungeon_id)
	if def == null:
		_status_label.text = "Unknown dungeon."
		_attempt_btn.disabled = true
		_sweep_btn.disabled = true
		return

	var desc_label := get_node_or_null("**/DescLabel") as Label
	if desc_label != null:
		desc_label.text = def.description

	var cur_level: int = 1
	var last_completed: int = 0
	var key_count: int = 0
	var reward_cur: Dictionary = {}
	var reward_prev: Dictionary = {}

	if _game != null and ("dungeon_system" in _game) and _game.dungeon_system != null:
		cur_level = _game.dungeon_system.get_current_level(_dungeon_id)
		last_completed = _game.dungeon_system.get_last_completed_level(_dungeon_id)
		key_count = _game.dungeon_system.get_key_count(_dungeon_id)
		reward_cur = _game.dungeon_system.reward_for_level(_dungeon_id, cur_level)
		reward_prev = _game.dungeon_system.reward_for_level(_dungeon_id, maxi(1, last_completed))

	var ds: DungeonSystem = null
	if _game != null:
		ds = _game.get("dungeon_system") as DungeonSystem

	var reward_cur_text: String = "None"
	if ds != null and not reward_cur.is_empty():
		reward_cur_text = ds.reward_to_text(reward_cur)

	var reward_prev_text: String = "None"
	if ds != null and last_completed > 0 and not reward_prev.is_empty():
		reward_prev_text = ds.reward_to_text(reward_prev)


	_status_label.text = "Current Level: %d\nLast Completed: %d\n%s: %d\n\nWin Reward: %s\nSweep Reward: %s" % [
		cur_level, last_completed, def.key_display_name, key_count, reward_cur_text, reward_prev_text
	]

	_attempt_btn.disabled = (key_count <= 0)
	_sweep_btn.disabled = (key_count <= 0 or last_completed <= 0)

func _on_attempt_pressed() -> void:
	# Step 1 behavior: emit a request so your UI/scene manager can swap to the dungeon battle scene later.
	if _game == null:
		return
	if "dungeon_request_run" in _game:
		var ok: bool = _game.dungeon_request_run(_dungeon_id)
		if not ok:
			_refresh()
			return

	# Close the popup for now
	queue_free()

func _on_sweep_pressed() -> void:
	if _game == null:
		return
	if "dungeon_sweep" in _game:
		_game.dungeon_sweep(_dungeon_id)
	_refresh()
	queue_free()

func _on_close_pressed() -> void:
	queue_free()

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		queue_free()
		accept_event()
