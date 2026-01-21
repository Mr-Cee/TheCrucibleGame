extends Control
class_name DungeonInfoPopup

@export var game_node_path: NodePath = NodePath("/root/Game")

# Key icon you already have
const PATH_KEY_DUNGEON_CRUCIBLE: String = "res://assets/icons/UI/keys/dungeon_key_crucible.png"

var _game: Node = null
var _dungeon_id: String = ""

# UI refs
var _built: bool = false
var _panel: PanelContainer
var _title_lbl: Label
var _difficulty_num: Label
var _reward_lbl: Label
var _key_icon: TextureRect
var _key_lbl: Label
var _attempt_btn: Button
var _sweep_btn: Button

func open_for_dungeon(game: Node, dungeon_id: String) -> void:
	_game = game
	_dungeon_id = dungeon_id
	visible = true

	# UI may not exist yet if called immediately after add_child()
	if _built:
		_refresh()
	else:
		call_deferred("_refresh")

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_ui()
	_built = true

	# If opened before ready, refresh now.
	if _dungeon_id != "":
		_refresh()

func _build_ui() -> void:
	# Dim background
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_gui_input)
	add_child(dim)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Outer popup panel (dark frame)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(520, 650)
	center.add_child(_panel)

	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0.08, 0.08, 0.09, 0.98)
	frame.corner_radius_top_left = 18
	frame.corner_radius_top_right = 18
	frame.corner_radius_bottom_left = 18
	frame.corner_radius_bottom_right = 18
	frame.set_border_width_all(2)
	frame.border_color = Color(0.22, 0.22, 0.26, 1.0)
	_panel.add_theme_stylebox_override("panel", frame)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 18)
	outer.add_theme_constant_override("margin_right", 18)
	outer.add_theme_constant_override("margin_top", 18)
	outer.add_theme_constant_override("margin_bottom", 18)
	_panel.add_child(outer)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	outer.add_child(root)

	# =========================
	# Header ribbon (red)
	# =========================
	var header := PanelContainer.new()
	header.custom_minimum_size = Vector2(0, 72)
	root.add_child(header)

	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color(0.74, 0.18, 0.16, 1.0)
	hsb.corner_radius_top_left = 14
	hsb.corner_radius_top_right = 14
	hsb.corner_radius_bottom_left = 14
	hsb.corner_radius_bottom_right = 14
	hsb.set_border_width_all(2)
	hsb.border_color = Color(0.92, 0.74, 0.35, 1.0)
	header.add_theme_stylebox_override("panel", hsb)

	var header_center := CenterContainer.new()
	header_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	header.add_child(header_center)

	_title_lbl = Label.new()
	_title_lbl.text = "Dungeon"
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 24)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.93, 0.75, 1.0))
	_title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.60))
	_title_lbl.add_theme_constant_override("outline_size", 6)
	header_center.add_child(_title_lbl)

	# =========================
	# “Paper” inner area (beige)
	# =========================
	var paper := PanelContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(paper)

	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.92, 0.88, 0.78, 1.0)
	psb.corner_radius_top_left = 14
	psb.corner_radius_top_right = 14
	psb.corner_radius_bottom_left = 14
	psb.corner_radius_bottom_right = 14
	psb.set_border_width_all(2)
	psb.border_color = Color(0.70, 0.55, 0.32, 1.0)
	paper.add_theme_stylebox_override("panel", psb)

	var paper_m := MarginContainer.new()
	paper_m.add_theme_constant_override("margin_left", 16)
	paper_m.add_theme_constant_override("margin_right", 16)
	paper_m.add_theme_constant_override("margin_top", 16)
	paper_m.add_theme_constant_override("margin_bottom", 16)
	paper.add_child(paper_m)

	var paper_root := VBoxContainer.new()
	paper_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paper_root.add_theme_constant_override("separation", 14)
	paper_m.add_child(paper_root)

	# “Current Difficulty” (replaces select difficulty)
	var diff_title := Label.new()
	diff_title.text = "Current Difficulty"
	diff_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_title.add_theme_font_size_override("font_size", 22)
	diff_title.add_theme_color_override("font_color", Color(0.18, 0.14, 0.10, 1.0))
	paper_root.add_child(diff_title)

	# Big badge number
	var badge_center := CenterContainer.new()
	badge_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper_root.add_child(badge_center)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(150, 120)
	badge_center.add_child(badge)

	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.79, 0.60, 0.32, 1.0)
	bsb.corner_radius_top_left = 18
	bsb.corner_radius_top_right = 18
	bsb.corner_radius_bottom_left = 18
	bsb.corner_radius_bottom_right = 18
	bsb.set_border_width_all(3)
	bsb.border_color = Color(0.62, 0.42, 0.18, 1.0)
	badge.add_theme_stylebox_override("panel", bsb)

	var badge_stack := VBoxContainer.new()
	badge_stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	badge_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_stack.add_theme_constant_override("separation", 0)
	badge.add_child(badge_stack)

	_difficulty_num = Label.new()
	_difficulty_num.text = "1"
	_difficulty_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_difficulty_num.add_theme_font_size_override("font_size", 40)
	_difficulty_num.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_difficulty_num.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_difficulty_num.add_theme_constant_override("outline_size", 5)
	badge_stack.add_child(_difficulty_num)

	var diff_lbl := Label.new()
	diff_lbl.text = "Difficulty"
	diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_lbl.add_theme_font_size_override("font_size", 16)
	diff_lbl.add_theme_color_override("font_color", Color(0.20, 0.15, 0.10, 1.0))
	badge_stack.add_child(diff_lbl)

	# Reward preview line (like “Magic Lamp 225” in the screenshot)
	_reward_lbl = Label.new()
	_reward_lbl.text = ""
	_reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_lbl.add_theme_font_size_override("font_size", 18)
	_reward_lbl.add_theme_color_override("font_color", Color(0.22, 0.18, 0.12, 1.0))
	paper_root.add_child(_reward_lbl)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paper_root.add_child(spacer)

	# Key row (icon + “#/cap”)
	var key_panel := PanelContainer.new()
	key_panel.custom_minimum_size = Vector2(0, 72)
	paper_root.add_child(key_panel)

	var ksb := StyleBoxFlat.new()
	ksb.bg_color = Color(0.28, 0.28, 0.30, 0.85)
	ksb.corner_radius_top_left = 10
	ksb.corner_radius_top_right = 10
	ksb.corner_radius_bottom_left = 10
	ksb.corner_radius_bottom_right = 10
	key_panel.add_theme_stylebox_override("panel", ksb)

	var key_m := MarginContainer.new()
	key_m.add_theme_constant_override("margin_left", 12)
	key_m.add_theme_constant_override("margin_right", 12)
	key_m.add_theme_constant_override("margin_top", 8)
	key_m.add_theme_constant_override("margin_bottom", 8)
	key_panel.add_child(key_m)

	var key_row := HBoxContainer.new()
	key_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_row.add_theme_constant_override("separation", 10)
	key_m.add_child(key_row)

	_key_icon = TextureRect.new()
	_key_icon.custom_minimum_size = Vector2(48, 64)
	_key_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_key_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_key_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_row.add_child(_key_icon)

	_key_lbl = Label.new()
	_key_lbl.text = "0/5"
	_key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key_lbl.add_theme_font_size_override("font_size", 18)
	_key_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
	key_row.add_child(_key_lbl)

	# Buttons row: Sweep Last (blue) and Enter (green)
	var btn_row := HBoxContainer.new()
	btn_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_theme_constant_override("separation", 12)
	paper_root.add_child(btn_row)

	_sweep_btn = Button.new()
	_sweep_btn.text = "Sweep Last"
	_sweep_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sweep_btn.custom_minimum_size = Vector2(0, 50)
	_sweep_btn.pressed.connect(_on_sweep_pressed)
	_style_blue_button(_sweep_btn)
	btn_row.add_child(_sweep_btn)

	_attempt_btn = Button.new()
	_attempt_btn.text = "Enter"
	_attempt_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_attempt_btn.custom_minimum_size = Vector2(0, 50)
	_attempt_btn.pressed.connect(_on_attempt_pressed)
	_style_green_button(_attempt_btn)
	btn_row.add_child(_attempt_btn)

	# Bottom centered close X (outside paper, like screenshot)
	var close_center := CenterContainer.new()
	close_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(close_center)

	var xbtn := Button.new()
	xbtn.text = "X"
	xbtn.custom_minimum_size = Vector2(62, 62)
	xbtn.pressed.connect(_on_close_pressed)
	_style_round_close_button(xbtn)
	close_center.add_child(xbtn)

func _refresh() -> void:
	if not _built:
		return
	if _dungeon_id == "":
		return

	var def := DungeonCatalog.get_def(_dungeon_id)
	if def == null:
		_title_lbl.text = "Unknown Dungeon"
		_difficulty_num.text = "-"
		_reward_lbl.text = ""
		_key_lbl.text = "0/5"
		_attempt_btn.disabled = true
		_sweep_btn.disabled = true
		return

	# Pull runtime values
	var cur_level: int = 1
	var last_completed: int = 0
	var key_count: int = 0
	var key_cap: int = 5
	var reward_cur: Dictionary = {}

	if _game == null:
		_game = get_node_or_null(game_node_path)

	if _game != null and ("dungeon_system" in _game) and _game.dungeon_system != null:
		var ds: Object = _game.dungeon_system
		if ds.has_method("get_current_level"):
			cur_level = int(ds.call("get_current_level", _dungeon_id))
		if ds.has_method("get_last_completed_level"):
			last_completed = int(ds.call("get_last_completed_level", _dungeon_id))
		if ds.has_method("get_key_count"):
			key_count = int(ds.call("get_key_count", _dungeon_id))
		if ds.has_method("daily_key_cap"):
			key_cap = int(ds.call("daily_key_cap", _dungeon_id))
		if ds.has_method("reward_for_level"):
			reward_cur = ds.call("reward_for_level", _dungeon_id, cur_level)

	_title_lbl.text = def.display_name
	_difficulty_num.text = "%d" % cur_level

	# Reward text: best-effort single-line like the screenshot
	_reward_lbl.text = _reward_preview_text(reward_cur)

	# Key icon + count
	_key_icon.texture = _key_icon_for_dungeon(_dungeon_id)
	_key_lbl.text = "%d/%d" % [key_count, key_cap]

	_attempt_btn.disabled = (key_count <= 0)
	_sweep_btn.disabled = (key_count <= 0 or last_completed <= 0)

func _reward_preview_text(reward: Dictionary) -> String:
	if reward == null or reward.is_empty():
		return "No reward"
	# If it’s a single currency, format cleanly.
	var keys := reward.keys()
	if keys.size() == 1:
		var k := String(keys[0])
		var amt := int(reward[k])
		return "%s  %d" % [_pretty_currency_name(k), amt]
	# Otherwise fallback to your existing helper if available.
	if _game != null and ("dungeon_system" in _game) and _game.dungeon_system != null:
		var ds: Object = _game.dungeon_system
		if ds.has_method("reward_to_text"):
			return String(ds.call("reward_to_text", reward))
	return "Reward"

func _pretty_currency_name(id: String) -> String:
	var s := id.replace("_", " ").strip_edges()
	return s.capitalize()

func _key_icon_for_dungeon(dungeon_id: String) -> Texture2D:
	# For now, only your crucible dungeon key icon
	if ResourceLoader.exists(PATH_KEY_DUNGEON_CRUCIBLE):
		return load(PATH_KEY_DUNGEON_CRUCIBLE) as Texture2D
	return null

# =====================
# Button styling helpers
# =====================

func _style_green_button(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.62, 0.24, 1.0)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	b.add_theme_stylebox_override("normal", sb)

	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.24, 0.72, 0.28, 1.0)
	b.add_theme_stylebox_override("hover", sb_h)

	var sb_p := sb.duplicate() as StyleBoxFlat
	sb_p.bg_color = Color(0.17, 0.52, 0.20, 1.0)
	b.add_theme_stylebox_override("pressed", sb_p)

	b.add_theme_color_override("font_color", Color(1, 1, 1, 1))

func _style_blue_button(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.44, 0.78, 1.0)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	b.add_theme_stylebox_override("normal", sb)

	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.24, 0.52, 0.88, 1.0)
	b.add_theme_stylebox_override("hover", sb_h)

	var sb_p := sb.duplicate() as StyleBoxFlat
	sb_p.bg_color = Color(0.16, 0.38, 0.66, 1.0)
	b.add_theme_stylebox_override("pressed", sb_p)

	b.add_theme_color_override("font_color", Color(1, 1, 1, 1))

func _style_round_close_button(b: Button) -> void:
	b.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	b.add_theme_font_size_override("font_size", 26)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.78, 0.20, 0.18, 1.0)
	sb.corner_radius_top_left = 31
	sb.corner_radius_top_right = 31
	sb.corner_radius_bottom_left = 31
	sb.corner_radius_bottom_right = 31
	sb.set_border_width_all(2)
	sb.border_color = Color(0.92, 0.74, 0.35, 1.0)
	b.add_theme_stylebox_override("normal", sb)

	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.86, 0.24, 0.20, 1.0)
	b.add_theme_stylebox_override("hover", sb_h)

	var sb_p := sb.duplicate() as StyleBoxFlat
	sb_p.bg_color = Color(0.70, 0.16, 0.14, 1.0)
	b.add_theme_stylebox_override("pressed", sb_p)

# =====================
# Actions
# =====================

func _on_attempt_pressed() -> void:
	if _game == null:
		_game = get_node_or_null(game_node_path)
	if _game == null:
		return

	if "dungeon_request_run" in _game:
		var ok: bool = _game.dungeon_request_run(_dungeon_id)
		if not ok:
			_refresh()
			return

	queue_free()

func _on_sweep_pressed() -> void:
	if _game == null or _dungeon_id == "":
		return

	# Get sweep level (reward is for last completed)
	var attempted_level: int = 0
	if ("dungeon_system" in _game) and _game.dungeon_system != null and _game.dungeon_system.has_method("get_last_completed_level"):
		attempted_level = int(_game.dungeon_system.call("get_last_completed_level", _dungeon_id))

	# Perform sweep and capture reward
	var reward: Dictionary = {}
	if _game.has_method("dungeon_sweep"):
		var v: Variant = _game.call("dungeon_sweep", _dungeon_id)
		if typeof(v) == TYPE_DICTIONARY:
			reward = v as Dictionary
	elif ("dungeon_system" in _game) and _game.dungeon_system != null and _game.dungeon_system.has_method("sweep"):
		var v2: Variant = _game.dungeon_system.call("sweep", _dungeon_id)
		if typeof(v2) == TYPE_DICTIONARY:
			reward = v2 as Dictionary

	# If sweep didn't happen (no keys / not eligible), just refresh and stay open
	if reward.is_empty():
		_refresh()
		return

	# Close this popup first, then show results on the next frame so it appears on top.
	queue_free()

	if _game.has_method("show_dungeon_result_popup"):
		_game.call_deferred("show_dungeon_result_popup", _dungeon_id, attempted_level, true, reward)
	else:
		# If for some reason show_dungeon_result_popup isn't on _game, use the autoload directly.
		Game.call_deferred("show_dungeon_result_popup", _dungeon_id, attempted_level, true, reward)


func _on_close_pressed() -> void:
	queue_free()

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		queue_free()
		accept_event()
