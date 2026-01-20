extends Control
class_name DungeonScene

var _title: Label
var _p_bar: ProgressBar
var _e_bar: ProgressBar
var _p_lbl: Label
var _e_lbl: Label
var _subtitle: Label
var _timer_bar: ProgressBar
var _timer_lbl: Label
var _timer_fill_green: StyleBoxFlat
var _timer_fill_yellow: StyleBoxFlat
var _timer_fill_red: StyleBoxFlat
var _timer_fill_state: int = -1 # 0=green, 1=yellow, 2=red


var _skill_buttons: Array[Button] = []
var _skill_cd_labels: Array[Label] = []
var _skill_name_labels: Array[Label] = []
var _skill_overlay_rects: Array[ColorRect] = []
var _skill_overlay_labels: Array[Label] = []

var _log_label: RichTextLabel

var _player_tex: TextureRect
var _enemy_tex: TextureRect
var _cached_player_sprite_path: String = ""
var _cached_enemy_sprite_path: String = ""
const PLAYER_ART_MAX: Vector2 = Vector2(96, 96)
const ENEMY_ART_MAX: Vector2 = Vector2(350, 350)

# ==================================================================================================

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_ui()

	# Start the dungeon run using the pending dungeon id recorded by Game.
	var dungeon_id: String = Game.pop_pending_dungeon_id()
	if dungeon_id == "":
		# Nothing to run; return safely.
		Game.return_from_dungeon_scene()
		return

	# Ensure battle system exists
	if Game.battle_system == null:
		Game.return_from_dungeon_scene()
		return

	# Start dungeon combat (consumes key, snapshots normal combat, spawns boss).
	var ok: bool = Game.battle_system.start_dungeon_run(dungeon_id)
	if not ok:
		Game.return_from_dungeon_scene()
		return

	# Listen for completion so we can return automatically.
	if not Game.dungeon_finished.is_connected(_on_dungeon_finished):
		Game.dungeon_finished.connect(_on_dungeon_finished)
		
	# Combat log wiring
	if not Game.combat_log_cleared.is_connected(_on_combat_log_cleared):
		Game.combat_log_cleared.connect(_on_combat_log_cleared)

	if not Game.combat_log_entry_added.is_connected(_on_combat_log_entry_added):
		Game.combat_log_entry_added.connect(_on_combat_log_entry_added)

	# Seed current log (dungeon start may have already written lines)
	_on_combat_log_cleared()
	for e in Game.get_combat_log_entries():
		_on_combat_log_entry_added(e)


	# Initial paint
	_refresh()

func _exit_tree() -> void:
	# Avoid dangling signal connections when changing scenes.
	if Game != null and Game.dungeon_finished.is_connected(_on_dungeon_finished):
		Game.dungeon_finished.disconnect(_on_dungeon_finished)
	if Game != null and Game.combat_log_cleared.is_connected(_on_combat_log_cleared):
		Game.combat_log_cleared.disconnect(_on_combat_log_cleared)

	if Game != null and Game.combat_log_entry_added.is_connected(_on_combat_log_entry_added):
		Game.combat_log_entry_added.disconnect(_on_combat_log_entry_added)

func _process(_delta: float) -> void:
	_refresh()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	# Header row
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(header)

	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 2)
	header.add_child(title_stack)

	_title = Label.new()
	_title.text = "Dungeon"
	_title.add_theme_font_size_override("font_size", 20)
	title_stack.add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = ""
	_subtitle.add_theme_font_size_override("font_size", 13)
	_subtitle.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	title_stack.add_child(_subtitle)


	# Player HP
	_p_lbl = Label.new()
	_p_lbl.text = "Player HP"
	root.add_child(_p_lbl)

	_p_bar = ProgressBar.new()
	_p_bar.max_value = 100
	_p_bar.value = 100
	root.add_child(_p_bar)

	# Boss HP
	_e_lbl = Label.new()
	_e_lbl.text = "Boss HP"
	root.add_child(_e_lbl)

	_e_bar = ProgressBar.new()
	_e_bar.max_value = 100
	_e_bar.value = 100
	root.add_child(_e_bar)
	
	# Timer row (centered)
	var timer_center := CenterContainer.new()
	timer_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	root.add_child(timer_center)

	var timer_box := VBoxContainer.new()
	timer_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	timer_box.add_theme_constant_override("separation", 4)
	timer_center.add_child(timer_box)

	_timer_lbl = Label.new()
	_timer_lbl.text = ""
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_box.add_child(_timer_lbl)

	_timer_bar = ProgressBar.new()
	_timer_bar.custom_minimum_size = Vector2(320, 18)
	_timer_bar.min_value = 0
	_timer_bar.max_value = 30
	_timer_bar.value = 30
	_timer_bar.show_percentage = false
	timer_box.add_child(_timer_bar)
	
	# Timer bar styling (background + dynamic fill colors)
	var timer_bg := StyleBoxFlat.new()
	timer_bg.bg_color = Color(0.12, 0.12, 0.12, 1.0)
	timer_bg.corner_radius_top_left = 6
	timer_bg.corner_radius_top_right = 6
	timer_bg.corner_radius_bottom_left = 6
	timer_bg.corner_radius_bottom_right = 6
	_timer_bar.add_theme_stylebox_override("background", timer_bg)


	_timer_fill_green = StyleBoxFlat.new()
	_timer_fill_green.bg_color = Color(0.20, 0.75, 0.25, 1.0)
	_timer_fill_green.corner_radius_top_left = 6
	_timer_fill_green.corner_radius_top_right = 6
	_timer_fill_green.corner_radius_bottom_left = 6
	_timer_fill_green.corner_radius_bottom_right = 6

	_timer_fill_yellow = StyleBoxFlat.new()
	_timer_fill_yellow.bg_color = Color(0.90, 0.75, 0.20, 1.0)
	_timer_fill_yellow.corner_radius_top_left = 6
	_timer_fill_yellow.corner_radius_top_right = 6
	_timer_fill_yellow.corner_radius_bottom_left = 6
	_timer_fill_yellow.corner_radius_bottom_right = 6

	_timer_fill_red = StyleBoxFlat.new()
	_timer_fill_red.bg_color = Color(0.85, 0.20, 0.20, 1.0)
	_timer_fill_red.corner_radius_top_left = 6
	_timer_fill_red.corner_radius_top_right = 6
	_timer_fill_red.corner_radius_bottom_left = 6
	_timer_fill_red.corner_radius_bottom_right = 6

	# Default fill
	_timer_fill_state = -1

	# Portrait row (player left, enemy right)
	var portraits := HBoxContainer.new()
	portraits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portraits.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portraits.add_theme_constant_override("separation", 16)
	root.add_child(portraits)

	# --- Player box (hard cap) ---
	var player_box := Control.new()
	player_box.custom_minimum_size = PLAYER_ART_MAX              # hard cap box size
	player_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	player_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portraits.add_child(player_box)

	_player_tex = TextureRect.new()
	_player_tex.set_anchors_preset(Control.PRESET_FULL_RECT)     # fill the box
	_player_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_player_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_player_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_box.add_child(_player_tex)

	# --- Enemy box (hard cap) ---
	var enemy_box := Control.new()
	enemy_box.custom_minimum_size = ENEMY_ART_MAX                # hard cap box size
	enemy_box.size_flags_horizontal = Control.SIZE_SHRINK_END
	enemy_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portraits.add_child(enemy_box)

	_enemy_tex = TextureRect.new()
	_enemy_tex.set_anchors_preset(Control.PRESET_FULL_RECT)      # fill the box
	_enemy_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_enemy_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_enemy_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy_box.add_child(_enemy_tex)


	# Combat log (EXPANDS to fill remaining space)
	var log_panel := PanelContainer.new()
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.custom_minimum_size = Vector2(0, 220) # ensures a usable height even on small windows
	root.add_child(log_panel)

	var log_margin := MarginContainer.new()
	log_margin.add_theme_constant_override("margin_left", 10)
	log_margin.add_theme_constant_override("margin_right", 10)
	log_margin.add_theme_constant_override("margin_top", 10)
	log_margin.add_theme_constant_override("margin_bottom", 10)
	log_panel.add_child(log_margin)

	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.scroll_active = true          # RichTextLabel scrolls itself
	_log_label.scroll_following = true       # auto-follow newest lines
	_log_label.fit_content = false           # IMPORTANT: allow it to expand
	_log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_margin.add_child(_log_label)

	# Skills bar
	var skills_row := HBoxContainer.new()
	skills_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_row.size_flags_vertical = Control.SIZE_SHRINK_END
	skills_row.add_theme_constant_override("separation", 10)
	root.add_child(skills_row)

	_skill_buttons.clear()
	_skill_cd_labels.clear()

	for slot in range(5):
		var slot_box := VBoxContainer.new()
		slot_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_box.size_flags_vertical = Control.SIZE_SHRINK_END
		slot_box.add_theme_constant_override("separation", 6)
		skills_row.add_child(slot_box)

		var b := Button.new()
		b.text = ""
		b.custom_minimum_size = Vector2(64, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		b.pressed.connect(_on_skill_pressed.bind(slot))
		slot_box.add_child(b)
		_skill_buttons.append(b)

		# Cooldown overlay (covers icon)
		var ov := ColorRect.new()
		ov.color = Color(0, 0, 0, 0.55)
		ov.visible = false
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ov.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(ov)
		_skill_overlay_rects.append(ov)

		var ov_lbl := Label.new()
		ov_lbl.text = ""
		ov_lbl.visible = false
		ov_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ov_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		ov_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ov_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ov_lbl.add_theme_font_size_override("font_size", 18)
		ov_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		b.add_child(ov_lbl)
		_skill_overlay_labels.append(ov_lbl)

		# Name under icon
		var name_lbl := Label.new()
		name_lbl.text = "Empty"
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		name_lbl.add_theme_font_size_override("font_size", 12)
		slot_box.add_child(name_lbl)
		_skill_name_labels.append(name_lbl)

		
	# Bottom row: centered Cancel button
	var bottom := HBoxContainer.new()
	bottom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 10)
	root.add_child(bottom)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(220, 44)
	cancel.pressed.connect(_on_cancel_pressed)

	# Red styling (theme override)
	cancel.add_theme_color_override("font_color", Color(1, 1, 1))
	cancel.add_theme_color_override("font_color_hover", Color(1, 1, 1))
	cancel.add_theme_color_override("font_color_pressed", Color(1, 1, 1))
	cancel.add_theme_color_override("font_color_disabled", Color(1, 1, 1))
	cancel.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	cancel.add_theme_constant_override("outline_size", 2)

	# Button background in red via StyleBoxFlat
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.75, 0.15, 0.15)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	cancel.add_theme_stylebox_override("normal", sb)

	var sb_hover := sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color(0.85, 0.20, 0.20)
	cancel.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed := sb.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = Color(0.65, 0.12, 0.12)
	cancel.add_theme_stylebox_override("pressed", sb_pressed)

	bottom.add_child(cancel)

func _refresh() -> void:
	# Pull combat runtime from Game proxy (BattleSystem-owned).
	var rt: Dictionary = Game.battle_runtime
	
	# Dungeon timer UI
	var t_total: float = float(rt.get("dungeon_time_total", 0.0))
	var t_left: float = float(rt.get("dungeon_time_left", 0.0))

	var has_timer: bool = t_total > 0.0
	_timer_bar.visible = has_timer
	_timer_lbl.visible = has_timer
		
	if has_timer:
		_timer_bar.max_value = t_total
		_timer_bar.value = t_left
		_timer_lbl.text = "Time Left: %ds" % int(ceil(t_left))

		var pct: float = (t_left / t_total) if t_total > 0.0 else 0.0

		var desired: int = 2 # red by default
		if pct >= 0.60:
			desired = 0 # green
		elif pct >= 0.25:
			desired = 1 # yellow

		if desired != _timer_fill_state:
			_timer_fill_state = desired
			match desired:
				0:
					_timer_bar.add_theme_stylebox_override("fill", _timer_fill_green)
				1:
					_timer_bar.add_theme_stylebox_override("fill", _timer_fill_yellow)
				2:
					_timer_bar.add_theme_stylebox_override("fill", _timer_fill_red)



	var p_hp: float = float(rt.get("player_hp", 0.0))
	var p_max: float = max(1.0, float(rt.get("player_hp_max", 1.0)))
	_p_bar.max_value = p_max
	_p_bar.value = p_hp
	_p_lbl.text = "Player HP: %d / %d" % [int(round(p_hp)), int(round(p_max))]

	var e_hp: float = float(rt.get("enemy_hp", 0.0))
	var e_max: float = max(1.0, float(rt.get("enemy_hp_max", 1.0)))
	_e_bar.max_value = e_max
	_e_bar.value = e_hp

	var enemy_name: String = String(rt.get("enemy_name", "Boss"))
	_e_lbl.text = "%s HP: %d / %d" % [enemy_name, int(round(e_hp)), int(round(e_max))]
	
	var did: String = String(rt.get("dungeon_id", ""))
	var dlvl: int = int(rt.get("dungeon_level", 0))

	if did != "" and dlvl > 0:
		_title.text = "%s — Level %d" % [_pretty_id(did), dlvl]
	else:
		_title.text = "Dungeon"

	_subtitle.text = "%s" % enemy_name

	
	# Player art
	var p_path: String = _resolve_player_sprite_path()
	if p_path != _cached_player_sprite_path:
		_cached_player_sprite_path = p_path
		_player_tex.texture = (load(p_path) as Texture2D) if p_path != "" else null

	# Enemy art
	var e_path: String = String(rt.get("enemy_sprite_path", ""))
	if e_path != _cached_enemy_sprite_path:
		_cached_enemy_sprite_path = e_path
		_enemy_tex.texture = (load(e_path) as Texture2D) if e_path != "" else null

	for slot in range(5):
		var id: String = Game.get_equipped_active_skill_id(slot)
		var btn: Button = _skill_buttons[slot]
		var name_lbl: Label = _skill_name_labels[slot]
		var ov: ColorRect = _skill_overlay_rects[slot]
		var ov_lbl: Label = _skill_overlay_labels[slot]

		if id == "":
			btn.icon = null
			btn.disabled = true
			name_lbl.text = "Empty"
			ov.visible = false
			ov_lbl.visible = false
			continue

		var def := SkillCatalog.get_def(id)
		var name_txt: String = (def.display_name if def != null else id)
		name_lbl.text = name_txt

		# Icon with rarity border
		var icon_tex: Texture2D = SkillCatalog.icon_with_rarity_border(id, 52, 2)
		btn.icon = icon_tex

		# Tooltip (optional but useful)
		if def != null:
			btn.tooltip_text = "%s\n\n%s" % [def.display_name, def.description]
		else:
			btn.tooltip_text = name_txt

		var rem: float = Game.get_skill_cooldown_remaining(slot)
		var on_cd: bool = rem > 0.0

		btn.disabled = on_cd
		ov.visible = on_cd
		ov_lbl.visible = on_cd
		if on_cd:
			ov_lbl.text = "%d" % int(ceil(rem))

func _on_skill_pressed(slot: int) -> void:
	Game.request_cast_active_skill(slot)

func _on_cancel_pressed() -> void:
	# End the dungeon early (counts as a fail; key already spent on entry).
	Game.abort_dungeon_run()
	# BattleSystem will emit dungeon_finished, which will return us.
	# If for any reason it doesn't, we still force-return:
	Game.return_from_dungeon_scene()

func _on_dungeon_finished(_dungeon_id: String, _attempted_level: int, _success: bool, _reward: Dictionary) -> void:
	Game.return_from_dungeon_scene()

func _player_sprite_key_from_player() -> String:
	# Default
	if Game == null or Game.player == null:
		return "warrior"

	var def_id: String = ""
	# PlayerModel is a Resource; use safe get
	if Game.player.has_method("get"):
		def_id = String(Game.player.get("class_def_id"))
	def_id = def_id.to_lower()

	if def_id.contains("archer") or def_id.contains("ranger") or def_id.contains("hunter"):
		return "archer"
	if def_id.contains("mage") or def_id.contains("wizard") or def_id.contains("sorc"):
		return "mage"
	return "warrior"

func _resolve_player_sprite_path() -> String:
	var key := _player_sprite_key_from_player()

	# Try common folders (adjust/add if your project uses a different one)
	var dirs: Array[String] = [
		"res://assets/players/",
		"res://assets/player/",
		"res://assets/characters/",
		"res://assets/units/",
	]

	for d in dirs:
		var p := "%s%s.png" % [d, key]
		if ResourceLoader.exists(p):
			return p

	# Fallback: no sprite found
	return ""

func _fit_texrect_to_max(tr: TextureRect, max_size: Vector2) -> void:
	if tr == null or tr.texture == null:
		return
	var tex_size: Vector2 = tr.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var s := minf(max_size.x / tex_size.x, max_size.y / tex_size.y)
	s = min(1.0, s) # never upscale; only downscale
	tr.scale = Vector2(s, s)

func _on_combat_log_cleared() -> void:
	if _log_label != null:
		_log_label.clear()

func _on_combat_log_entry_added(entry: Dictionary) -> void:
	if _log_label == null:
		return
	var bb: String = String(entry.get("bb", ""))
	if bb == "":
		return
	_log_label.append_text(bb)
	_log_label.append_text("\n")

func _scroll_log_to_bottom_deferred() -> void:
	call_deferred("_scroll_log_to_bottom")

func _pretty_id(id: String) -> String:
	var s := id.strip_edges()
	s = s.replace("_", " ").replace("-", " ")
	return s.capitalize()
