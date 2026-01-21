extends Control
class_name DungeonResultPopup

signal closed

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _rewards_box: VBoxContainer
var _ok_btn: Button

var _pending_dungeon_id: String = ""
var _pending_level: int = 0
var _pending_success: bool = false
var _pending_reward: Dictionary = {}

func setup(dungeon_id: String, attempted_level: int, success: bool, reward: Dictionary) -> void:
	_pending_dungeon_id = dungeon_id
	_pending_level = attempted_level
	_pending_success = success
	_pending_reward = reward.duplicate(true)

	if is_inside_tree():
		_apply()

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Dim
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.95)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_gui_input)
	add_child(_dim)

	# Center wrapper
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(460, 260)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	root.add_child(_title)

	_subtitle = Label.new()
	_subtitle.add_theme_font_size_override("font_size", 13)
	_subtitle.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	root.add_child(_subtitle)

	var divider := HSeparator.new()
	root.add_child(divider)

	_rewards_box = VBoxContainer.new()
	_rewards_box.add_theme_constant_override("separation", 6)
	_rewards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_rewards_box)

	var footer := HBoxContainer.new()
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(footer)

	_ok_btn = Button.new()
	_ok_btn.text = "OK"
	_ok_btn.custom_minimum_size = Vector2(140, 40)
	_ok_btn.pressed.connect(_close)
	footer.add_child(_ok_btn)

	_apply()

func _apply() -> void:
	if _title == null:
		return

	var dungeon_name: String = _pretty_id(_pending_dungeon_id)
	var lvl: int = maxi(1, _pending_level)

	if _pending_success:
		_title.text = "Dungeon Complete"
		_subtitle.text = "%s — Level %d" % [dungeon_name, lvl]
	else:
		_title.text = "Dungeon Failed"
		_subtitle.text = "%s — Level %d" % [dungeon_name, lvl]

	# Clear rewards list
	for c in _rewards_box.get_children():
		c.queue_free()

	if _pending_reward.is_empty():
		var none := Label.new()
		none.text = "No rewards earned."
		none.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
		_rewards_box.add_child(none)
		return

	# Build rewards
	for key in _pending_reward.keys():
		var k: String = String(key)
		var v: int = int(_pending_reward[key])

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rewards_box.add_child(row)

		var name := Label.new()
		name.text = "%s:" % _pretty_id(k)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name)

		var val := Label.new()
		val.text = "+%d" % v
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.add_theme_font_size_override("font_size", 16)
		row.add_child(val)

func _pretty_id(id: String) -> String:
	var s: String = id.strip_edges()
	s = s.replace("_", " ").replace("-", " ")
	return s.capitalize()

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (not event.pressed) and event.button_index == MOUSE_BUTTON_LEFT:
		_close()
		accept_event()

func _close() -> void:
	closed.emit()
	queue_free()
