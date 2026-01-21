extends Control
class_name DungeonsPanel

@export var game_node_path: NodePath = NodePath("/root/Game")

var _game: Node = null
var _list_vbox: VBoxContainer = null
var _title_label: Label = null

# New UI refs
var _reset_time_lbl: Label = null
var _ticker: Timer = null

func open() -> void:
	visible = true

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

	_game = get_node_or_null(game_node_path)

	_build_ui()

	# Tick countdown once per second
	_ticker = Timer.new()
	_ticker.wait_time = 1.0
	_ticker.one_shot = false
	_ticker.autostart = true
	_ticker.timeout.connect(_on_tick)
	add_child(_ticker)

	if _game != null and _game.has_signal("player_changed"):
		if not _game.player_changed.is_connected(_refresh):
			_game.player_changed.connect(_refresh)

	_refresh()
	_refresh_reset_time()

func _build_ui() -> void:
	# Dim background
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.60)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.anchor_right = 1
	dim.anchor_bottom = 1

	# Close when clicking outside the panel (on the dim/backdrop)
	dim.gui_input.connect(_on_dim_gui_input)
	add_child(dim)

	# Centered panel
	var center := CenterContainer.new()
	center.anchor_right = 1
	center.anchor_bottom = 1
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 620)
	center.add_child(panel)

	# Panel styling (rounded, subtle border)
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.12, 0.12, 0.12, 0.98)
	panel_sb.corner_radius_top_left = 14
	panel_sb.corner_radius_top_right = 14
	panel_sb.corner_radius_bottom_left = 14
	panel_sb.corner_radius_bottom_right = 14
	panel_sb.set_border_width_all(2)
	panel_sb.border_color = Color(0.25, 0.25, 0.25, 1.0)
	panel.add_theme_stylebox_override("panel", panel_sb)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 14)
	outer.add_theme_constant_override("margin_right", 14)
	outer.add_theme_constant_override("margin_top", 14)
	outer.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(outer)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	outer.add_child(root)

	# Header row (Title + Close)
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Dungeons"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 26)
	header.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	# Top notice (keys auto-replenish + countdown)
	var notice := PanelContainer.new()
	root.add_child(notice)

	var notice_sb := StyleBoxFlat.new()
	notice_sb.bg_color = Color(0.20, 0.12, 0.10, 1.0)
	notice_sb.corner_radius_top_left = 12
	notice_sb.corner_radius_top_right = 12
	notice_sb.corner_radius_bottom_left = 12
	notice_sb.corner_radius_bottom_right = 12
	notice_sb.set_border_width_all(1)
	notice_sb.border_color = Color(0.45, 0.25, 0.15, 1.0)
	notice.add_theme_stylebox_override("panel", notice_sb)

	var notice_m := MarginContainer.new()
	notice_m.add_theme_constant_override("margin_left", 12)
	notice_m.add_theme_constant_override("margin_right", 12)
	notice_m.add_theme_constant_override("margin_top", 10)
	notice_m.add_theme_constant_override("margin_bottom", 10)
	notice.add_child(notice_m)

	var notice_row := HBoxContainer.new()
	notice_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notice_m.add_child(notice_row)

	var hint := Label.new()
	hint.text = "Dungeon Keys will auto-replenish (Daily Reset @ 00:00 UTC)"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_color_override("font_color", Color(0.90, 0.90, 0.90, 1.0))
	notice_row.add_child(hint)

	_reset_time_lbl = Label.new()
	_reset_time_lbl.text = "Time remaining: --:--:--"
	_reset_time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reset_time_lbl.add_theme_color_override("font_color", Color(0.70, 0.95, 0.70, 1.0))
	notice_row.add_child(_reset_time_lbl)

	# List
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(_list_vbox)

func _on_tick() -> void:
	# If your DungeonSystem supports applying the daily reset while online, invoke it here.
	if _game != null and ("dungeon_system" in _game) and _game.dungeon_system != null:
		var ds: Object = _game.dungeon_system
		if ds.has_method("ensure_daily_reset"):
			ds.call("ensure_daily_reset")

	_refresh_reset_time()

func _refresh_reset_time() -> void:
	if _reset_time_lbl == null:
		return
	var left: int = _seconds_until_daily_reset()
	_reset_time_lbl.text = "Time remaining: %s" % _fmt_hms(left)

func _seconds_until_daily_reset() -> int:
	# Prefer DungeonSystem if present; fallback to UTC midnight from unix time.
	var now_unix: int = int(Time.get_unix_time_from_system())

	if _game != null and ("dungeon_system" in _game) and _game.dungeon_system != null:
		var ds: Object = _game.dungeon_system
		if ds.has_method("seconds_until_daily_reset"):
			return maxi(0, int(ds.call("seconds_until_daily_reset")))

	# Fallback: next 00:00 UTC boundary (Unix days)
	const SECONDS_PER_DAY: int = 86400
	var day_key: int = int(now_unix / SECONDS_PER_DAY)
	var next_unix: int = (day_key + 1) * SECONDS_PER_DAY
	return maxi(0, next_unix - now_unix)

func _fmt_hms(seconds: int) -> String:
	seconds = maxi(0, seconds)
	var h: int = seconds / 3600
	seconds %= 3600
	var m: int = seconds / 60
	var s: int = seconds % 60
	return "%02d:%02d:%02d" % [h, m, s]

func _refresh() -> void:
	if _list_vbox == null:
		return

	for c in _list_vbox.get_children():
		c.queue_free()

	for did in DungeonCatalog.all_ids():
		var def := DungeonCatalog.get_def(did)
		if def == null:
			continue

		var cur_level: int = 1
		var key_count: int = 0

		if _game != null and ("dungeon_system" in _game) and _game.dungeon_system != null:
			cur_level = _game.dungeon_system.get_current_level(did)
			key_count = _game.dungeon_system.get_key_count(did)

		_list_vbox.add_child(_build_dungeon_card(did, def, cur_level, key_count))

func _build_dungeon_card(dungeon_id: String, def: DungeonDef, cur_level: int, key_count: int) -> Control:
	var card := PanelContainer.new()

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.16, 0.18, 1.0)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.set_border_width_all(1)
	sb.border_color = Color(0.28, 0.28, 0.32, 1.0)
	card.add_theme_stylebox_override("panel", sb)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	card.add_child(m)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	m.add_child(row)

	# Badge (placeholder; later you can swap to an icon TextureRect)
	var badge := ColorRect.new()
	badge.custom_minimum_size = Vector2(56, 56)
	badge.color = _badge_color_for_dungeon(dungeon_id)
	row.add_child(badge)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)
	row.add_child(mid)

	var name := Label.new()
	name.text = def.display_name
	name.add_theme_font_size_override("font_size", 18)
	mid.add_child(name)

	var sub := Label.new()
	sub.text = "Level %d" % cur_level
	sub.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82, 1.0))
	mid.add_child(sub)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_theme_constant_override("separation", 6)
	row.add_child(right)

	var key_lbl := Label.new()
	key_lbl.text = "%s: %d" % [def.key_display_name, key_count]
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(key_lbl)

	var enter := Button.new()
	enter.text = "Enter"
	enter.custom_minimum_size = Vector2(150, 42)
	enter.pressed.connect(_on_dungeon_pressed.bind(dungeon_id))
	_style_enter_button(enter)
	right.add_child(enter)

	return card

func _badge_color_for_dungeon(dungeon_id: String) -> Color:
	# Simple heuristic until you add per-dungeon icon + theme data.
	var s := dungeon_id.to_lower()
	if s.contains("crucible"):
		return Color(0.55, 0.30, 0.10, 1.0) # warm/orange
	if s.contains("molten") or s.contains("fire"):
		return Color(0.65, 0.18, 0.12, 1.0)
	if s.contains("ice") or s.contains("frost"):
		return Color(0.18, 0.35, 0.60, 1.0)
	return Color(0.25, 0.25, 0.35, 1.0)

func _style_enter_button(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.55, 0.20, 1.0)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	b.add_theme_stylebox_override("normal", sb)

	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = Color(0.22, 0.65, 0.24, 1.0)
	b.add_theme_stylebox_override("hover", sb_h)

	var sb_p := sb.duplicate() as StyleBoxFlat
	sb_p.bg_color = Color(0.15, 0.45, 0.17, 1.0)
	b.add_theme_stylebox_override("pressed", sb_p)

	b.add_theme_color_override("font_color", Color(1, 1, 1, 1))

func _on_dungeon_pressed(dungeon_id: String) -> void:
	var popup := DungeonInfoPopup.new()
	Game.popup_root().add_child(popup)
	popup.open_for_dungeon(_game, dungeon_id)

func _on_close_pressed() -> void:
	queue_free()

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		queue_free()
		accept_event()
