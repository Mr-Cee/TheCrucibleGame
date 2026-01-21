extends Control
class_name DungeonsPanel

@export var game_node_path: NodePath = NodePath("/root/Game")

# Asset paths provided by you
const PATH_RIBBON: String = "res://assets/panels/ribbon_dungeons.png"
const PATH_KEY_DUNGEON_CRUCIBLE: String = "res://assets/icons/UI/keys/dungeon_key_crucible.png"
const PATH_KEY_CRUCIBLE: String = "res://assets/icons/UI/keys/crucible_key_main.png"
const PATH_BANNER_CRUCIBLE_WARDEN: String = "res://assets/panels/dungeon_banner_crucible_warden.png"

var _tex_ribbon: Texture2D = null
var _tex_dungeon_key_crucible: Texture2D = null
var _tex_crucible_key: Texture2D = null
var _tex_banner_crucible: Texture2D = null

var _game: Node = null

var _list_vbox: VBoxContainer = null
var _reset_time_lbl: Label = null
var _ticker: Timer = null

func _ready() -> void:
	#top_level = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP

	_game = get_node_or_null(game_node_path)

	_load_textures()
	_build_ui()

	# Tick countdown once per second (lightweight)
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

func _load_textures() -> void:
	_tex_ribbon = _safe_load_tex(PATH_RIBBON)
	_tex_dungeon_key_crucible = _safe_load_tex(PATH_KEY_DUNGEON_CRUCIBLE)
	_tex_crucible_key = _safe_load_tex(PATH_KEY_CRUCIBLE)
	_tex_banner_crucible = _safe_load_tex(PATH_BANNER_CRUCIBLE_WARDEN)

func _safe_load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

# ================================================================================================
# UI
# ================================================================================================

func _build_ui() -> void:
	# Dim background
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.60)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_gui_input)
	add_child(dim)

	# Centered panel
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 680)
	center.add_child(panel)

	# Panel styling
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.10, 0.10, 0.11, 0.98)
	panel_sb.corner_radius_top_left = 16
	panel_sb.corner_radius_top_right = 16
	panel_sb.corner_radius_bottom_left = 16
	panel_sb.corner_radius_bottom_right = 16
	panel_sb.set_border_width_all(2)
	panel_sb.border_color = Color(0.25, 0.25, 0.28, 1.0)
	panel.add_theme_stylebox_override("panel", panel_sb)

	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 16)
	outer.add_theme_constant_override("margin_right", 16)
	outer.add_theme_constant_override("margin_top", 14)
	outer.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(outer)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	outer.add_child(root)

	# Ribbon header (with close button overlaid)
	root.add_child(_build_ribbon_header())

	# Top notice (keys auto-replenish + countdown)
	root.add_child(_build_reset_notice())

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

func _build_ribbon_header() -> Control:
	var header := Control.new()
	header.custom_minimum_size = Vector2(0, 86)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Ribbon image (no title text)
	if _tex_ribbon != null:
		var ribbon := TextureRect.new()
		ribbon.texture = _tex_ribbon
		ribbon.set_anchors_preset(Control.PRESET_FULL_RECT)
		ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ribbon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(ribbon)

	# Close button (top-right)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(44, 36)
	close_btn.anchor_left = 1
	close_btn.anchor_right = 1
	close_btn.anchor_top = 0
	close_btn.anchor_bottom = 0
	close_btn.offset_right = -4
	close_btn.offset_left = close_btn.offset_right - 44
	close_btn.offset_top = 6
	close_btn.offset_bottom = close_btn.offset_top + 36
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	return header

func _build_reset_notice() -> Control:
	var notice := PanelContainer.new()

	var notice_sb := StyleBoxFlat.new()
	notice_sb.bg_color = Color(0.18, 0.12, 0.08, 1.0)
	notice_sb.corner_radius_top_left = 12
	notice_sb.corner_radius_top_right = 12
	notice_sb.corner_radius_bottom_left = 12
	notice_sb.corner_radius_bottom_right = 12
	notice_sb.set_border_width_all(1)
	notice_sb.border_color = Color(0.55, 0.35, 0.18, 1.0)
	notice.add_theme_stylebox_override("panel", notice_sb)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	notice.add_child(m)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(row)

	var hint := Label.new()
	hint.text = "Dungeon Keys will auto-replenish (Daily Reset @ 00:00 UTC)"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 1.0))
	row.add_child(hint)

	_reset_time_lbl = Label.new()
	_reset_time_lbl.text = "Time remaining: --:--:--"
	_reset_time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_reset_time_lbl.add_theme_color_override("font_color", Color(0.70, 0.95, 0.70, 1.0))
	row.add_child(_reset_time_lbl)

	return notice

# ================================================================================================
# Ticker / reset countdown
# ================================================================================================

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

# ================================================================================================
# Content
# ================================================================================================

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
		var reward_preview: Dictionary = {}
		
		var key_cap: int = 5

		if _game != null and ("dungeon_system" in _game) and _game.dungeon_system != null:
			var ds: Object = _game.dungeon_system
			if ds.has_method("get_current_level"):
				cur_level = int(ds.call("get_current_level", did))
			if ds.has_method("get_key_count"):
				key_count = int(ds.call("get_key_count", did))
			if ds.has_method("daily_key_cap"):
				key_cap = int(ds.call("daily_key_cap", did))
			# Reward preview for current level (optional but nice)
			if ds.has_method("reward_for_level"):
				reward_preview = ds.call("reward_for_level", did, cur_level)
				
		

		_list_vbox.add_child(_build_dungeon_card(did, def, cur_level, key_count, key_cap))


func _build_dungeon_card(dungeon_id: String, def: DungeonDef, cur_level: int, key_count: int, key_cap: int) -> Control:
	var card := PanelContainer.new()

	# Card base style
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.15, 0.17, 1.0)
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.set_border_width_all(1)
	sb.border_color = Color(0.28, 0.28, 0.32, 1.0)
	card.add_theme_stylebox_override("panel", sb)

	# Stack for optional background banner
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(0, 108)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(stack)

	# Banner only for Crucible Warden dungeon slot (adjust your ID check if needed)
	if _is_crucible_warden_dungeon(dungeon_id) and _tex_banner_crucible != null:
		var banner := TextureRect.new()
		banner.texture = _tex_banner_crucible
		banner.set_anchors_preset(Control.PRESET_FULL_RECT)
		banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(banner)

		# Slight dark overlay for readability
		var overlay := ColorRect.new()
		overlay.color = Color(0, 0, 0, 0.25)
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(overlay)

	# Foreground content margin
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)
	stack.add_child(m)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	m.add_child(row)

	# MIDDLE: name only (removes "Crucible Key Dungeon" / "Level #"/extra subtext)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 2)
	row.add_child(mid)

	# RIGHT: keys (icon + number only) + reward + enter button
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_theme_constant_override("separation", 6)
	row.add_child(right)

	# Keys row (dungeon key icon + count ONLY)
	var keys_row := HBoxContainer.new()
	keys_row.size_flags_horizontal = Control.SIZE_SHRINK_END
	keys_row.add_theme_constant_override("separation", 8)
	right.add_child(keys_row)

	var key_icon := TextureRect.new()
	key_icon.texture = _key_icon_for_dungeon(dungeon_id)
	key_icon.custom_minimum_size = Vector2(64, 48) # bigger
	key_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	key_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	key_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keys_row.add_child(key_icon)

	var key_lbl := Label.new()
	key_lbl.text = "%d/%d" % [key_count, key_cap]		# no "Crucible Dungeon Key:"
	key_lbl.add_theme_font_size_override("font_size", 16)
	key_lbl.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96, 1.0))
	keys_row.add_child(key_lbl)

	# Enter button (level/details shown in the popup after clicking Enter)
	var enter := Button.new()
	enter.text = "Enter"
	enter.custom_minimum_size = Vector2(160, 44)
	enter.pressed.connect(_on_dungeon_pressed.bind(dungeon_id))
	_style_enter_button(enter)
	right.add_child(enter)

	return card

func _reward_amount_from_dict(reward: Dictionary, key: String) -> int:
	if reward == null or reward.is_empty():
		return 0
	if reward.has(key):
		return int(reward[key])
	return 0

func _is_crucible_warden_dungeon(dungeon_id: String) -> bool:
	var s := dungeon_id.to_lower()
	# Match whichever ID you used for this dungeon; these heuristics catch common variants.
	return s.contains("crucible") or s.contains("warden")

func _key_icon_for_dungeon(dungeon_id: String) -> Texture2D:
	# For now, you only provided the crucible dungeon key image.
	# When you add more dungeons, you can add per-dungeon icons here.
	if _is_crucible_warden_dungeon(dungeon_id) and _tex_dungeon_key_crucible != null:
		return _tex_dungeon_key_crucible
	return _tex_dungeon_key_crucible

func _badge_color_for_dungeon(dungeon_id: String) -> Color:
	var s := dungeon_id.to_lower()
	if s.contains("crucible"):
		return Color(0.55, 0.30, 0.10, 1.0)
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

# ================================================================================================
# Actions
# ================================================================================================

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
