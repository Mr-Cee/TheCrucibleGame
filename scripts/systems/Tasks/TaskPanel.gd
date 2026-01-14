extends PanelContainer
class_name TaskPanel

@export var game_node_path: NodePath = NodePath("/root/Game")

var _task_system = null
var _label: Label

var _sb_incomplete: StyleBoxFlat
var _sb_complete: StyleBoxFlat
var _sb_disabled: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_ui()
	_apply_panel_style()

	var game := get_node_or_null(game_node_path)
	if game != null and "task_system" in game:
		_task_system = game.task_system

	if _task_system != null and not _task_system.changed.is_connected(_refresh):
		_task_system.changed.connect(_refresh)

	_refresh()

func _build_ui() -> void:
	custom_minimum_size = Vector2(320, 48)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.text = ""
	add_child(_label)

func _apply_panel_style() -> void:
	_sb_incomplete = _make_style(Color(0, 0, 0, 0.55), Color(0.8, 0.2, 0.2, 0.95))
	_sb_complete = _make_style(Color(0, 0, 0, 0.55), Color(0.2, 1.0, 0.2, 0.95))
	_sb_disabled = _make_style(Color(0, 0, 0, 0.35), Color(0.5, 0.5, 0.5, 0.6))

	add_theme_stylebox_override("panel", _sb_incomplete)

	# Label font sizing (this is on the Label, not inherited)
	_label.add_theme_font_size_override("font_size", 15)

func _make_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border

	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2

	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8

	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

func _refresh() -> void:
	if _task_system == null:
		_label.text = ""
		return

	_label.text = _task_system.current_text()

	var complete: bool = _task_system.is_complete()
	if complete:
		_label.modulate = Color(0.2, 1.0, 0.2) # green text
		add_theme_stylebox_override("panel", _sb_complete)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	else:
		_label.modulate = Color(1.0, 0.2, 0.2) # red text
		add_theme_stylebox_override("panel", _sb_incomplete)
		mouse_default_cursor_shape = Control.CURSOR_ARROW

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_claim()

func _try_claim() -> void:
	if _task_system == null:
		return
	if not _task_system.is_complete():
		return

	var reward: Dictionary = _task_system.claim_reward_if_complete()
	if reward.is_empty():
		return

	# Optional: replace with your toast system later
	print("Task reward: ", _task_system.reward_to_text(reward))
