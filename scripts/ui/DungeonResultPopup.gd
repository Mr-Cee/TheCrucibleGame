extends Control
class_name DungeonResultPopup

signal closed

# Icons / art
const PATH_CRUCIBLE_KEY_ICON: String = "res://assets/icons/UI/keys/crucible_key_main.png"
const PATH_RIBBON_CONGRATS: String = "res://assets/panels/ribbon_congratulations.png"

var _tex_ribbon_congrats: Texture2D = null

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _tap_lbl: Label
var _grid: GridContainer

# Click-tooltip bubble
var _tip_panel: PanelContainer
var _tip_lbl: Label
var _tip_visible_for_key: String = ""

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

	# Make sure this sits above other UI layers
	z_index = 5000
	z_as_relative = false

	_tex_ribbon_congrats = _safe_load_tex(PATH_RIBBON_CONGRATS)

	# Dim (clicking outside closes)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.85)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_gui_input)
	add_child(_dim)

	# Center wrapper
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Panel (the “rewards panel”)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(560, 360)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_panel)

	# Panel style (warm / celebratory)
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.12, 0.10, 0.08, 0.92)
	panel_sb.corner_radius_top_left = 18
	panel_sb.corner_radius_top_right = 18
	panel_sb.corner_radius_bottom_left = 18
	panel_sb.corner_radius_bottom_right = 18
	panel_sb.set_border_width_all(2)
	panel_sb.border_color = Color(0.55, 0.40, 0.20, 0.90)
	_panel.add_theme_stylebox_override("panel", panel_sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# Ribbon header (top of results panel)
	root.add_child(_build_congrats_ribbon())

	# Fallback title (hidden when ribbon is present)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(1.0, 0.90, 0.60, 1.0))
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	_title.add_theme_constant_override("outline_size", 6)
	root.add_child(_title)

	var reward_center := CenterContainer.new()
	reward_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(reward_center)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	reward_center.add_child(_grid)

	_tap_lbl = Label.new()
	_tap_lbl.text = "Tap outside to continue"
	_tap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tap_lbl.add_theme_font_size_override("font_size", 14)
	_tap_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88, 0.85))
	root.add_child(_tap_lbl)

	# Tooltip bubble (shown on reward click)
	_tip_panel = PanelContainer.new()
	_tip_panel.visible = false
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.z_index = 9999
	_tip_panel.z_as_relative = false
	add_child(_tip_panel)

	var tip_sb := StyleBoxFlat.new()
	tip_sb.bg_color = Color(0.08, 0.08, 0.09, 0.96)
	tip_sb.corner_radius_top_left = 10
	tip_sb.corner_radius_top_right = 10
	tip_sb.corner_radius_bottom_left = 10
	tip_sb.corner_radius_bottom_right = 10
	tip_sb.set_border_width_all(1)
	tip_sb.border_color = Color(0.35, 0.35, 0.38, 1.0)
	_tip_panel.add_theme_stylebox_override("panel", tip_sb)

	var tip_margin := MarginContainer.new()
	tip_margin.add_theme_constant_override("margin_left", 10)
	tip_margin.add_theme_constant_override("margin_right", 10)
	tip_margin.add_theme_constant_override("margin_top", 8)
	tip_margin.add_theme_constant_override("margin_bottom", 8)
	_tip_panel.add_child(tip_margin)

	_tip_lbl = Label.new()
	_tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_lbl.custom_minimum_size = Vector2(220, 0)
	_tip_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
	tip_margin.add_child(_tip_lbl)

	_apply()

func _build_congrats_ribbon() -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, 110)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _tex_ribbon_congrats != null:
		var ribbon := TextureRect.new()
		ribbon.texture = _tex_ribbon_congrats
		ribbon.set_anchors_preset(Control.PRESET_FULL_RECT)
		ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ribbon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(ribbon)

	return wrap

func _apply() -> void:
	if _title == null:
		return

	# Hide fallback title when the ribbon exists
	if _tex_ribbon_congrats != null:
		_title.visible = false
	else:
		_title.visible = true
		_title.text = "Congratulations" if _pending_success else "Result"

	# Clear rewards
	for c in _grid.get_children():
		c.queue_free()

	_hide_tip()

	if _pending_reward.is_empty():
		var none := Label.new()
		none.text = "No rewards earned."
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88, 0.85))
		_grid.add_child(none)
		return

	# Choose columns based on count (1..4)
	var count: int = _pending_reward.keys().size()
	_grid.columns = clampi(count, 1, 4)

	for key in _pending_reward.keys():
		var k: String = String(key)
		var v: int = int(_pending_reward[key])
		_grid.add_child(_build_reward_tile(k, v))

func _build_reward_tile(reward_key: String, amount: int) -> Control:
	var btn := Button.new()
	btn.text = ""
	btn.custom_minimum_size = Vector2(120, 120)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.mouse_filter = Control.MOUSE_FILTER_STOP

	var icon: Texture2D = _reward_icon(reward_key)
	if icon != null:
		btn.icon = icon

	btn.tooltip_text = _reward_tooltip_text(reward_key)
	btn.pressed.connect(_on_reward_pressed.bind(reward_key, btn))

	# Tile style
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.30, 0.18, 0.40, 0.90)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.set_border_width_all(2)
	sb.border_color = Color(0.90, 0.80, 1.00, 0.65)
	btn.add_theme_stylebox_override("normal", sb)

	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.35, 0.22, 0.46, 0.95)
	btn.add_theme_stylebox_override("hover", sb_h)

	var sb_p := sb.duplicate() as StyleBoxFlat
	sb_p.bg_color = Color(0.26, 0.16, 0.36, 0.95)
	btn.add_theme_stylebox_override("pressed", sb_p)

	# Amount overlay (bottom-right)
	var amt := Label.new()
	amt.text = "%d" % amount
	amt.set_anchors_preset(Control.PRESET_FULL_RECT)
	amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amt.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	amt.offset_left = 10
	amt.offset_top = 10
	amt.offset_right = -10
	amt.offset_bottom = -8
	amt.add_theme_font_size_override("font_size", 22)
	amt.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))
	amt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	amt.add_theme_constant_override("outline_size", 5)
	amt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(amt)

	return btn

func _reward_icon(reward_key: String) -> Texture2D:
	match reward_key:
		"crucible_keys":
			return _safe_load_tex(PATH_CRUCIBLE_KEY_ICON)
		_:
			return null

func _reward_tooltip_text(reward_key: String) -> String:
	match reward_key:
		"crucible_keys":
			return "Crucible Key\n\nUsed to draw from the Crucible."
		_:
			return _pretty_id(reward_key)

func _safe_load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _on_reward_pressed(reward_key: String, btn: Control) -> void:
	# Toggle if pressing the same reward
	if _tip_panel.visible and _tip_visible_for_key == reward_key:
		_hide_tip()
		return

	_tip_visible_for_key = reward_key
	_tip_lbl.text = _reward_tooltip_text(reward_key)

	_tip_panel.visible = true
	_tip_panel.reset_size()

	# Position near the clicked reward tile
	var r: Rect2 = btn.get_global_rect()
	var vp: Vector2 = get_viewport_rect().size

	var tip_size: Vector2 = _tip_panel.get_combined_minimum_size()
	var pos := r.position + Vector2(r.size.x * 0.5 - tip_size.x * 0.5, r.size.y + 10)

	if pos.y + tip_size.y > vp.y - 8:
		pos.y = r.position.y - tip_size.y - 10

	pos.x = clampf(pos.x, 8.0, vp.x - tip_size.x - 8.0)
	pos.y = clampf(pos.y, 8.0, vp.y - tip_size.y - 8.0)

	_tip_panel.position = pos

func _hide_tip() -> void:
	_tip_panel.visible = false
	_tip_visible_for_key = ""

func _on_dim_gui_input(event: InputEvent) -> void:
	# Clicking outside the rewards panel closes
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close()
		accept_event()

func _close() -> void:
	_hide_tip()
	closed.emit()
	queue_free()

func _pretty_id(id: String) -> String:
	var s: String = id.strip_edges()
	s = s.replace("_", " ").replace("-", " ")
	return s.capitalize()
