extends Control
class_name SkillsPanel

const SLOTS: int = 5
const ICON_SIZE: int = 48

const SLOT_ICON_SIZE: int = 84
const GRID_ICON_SIZE: int = 84
const GRID_COLUMNS: int = 5

const TILE_W: int = 110
const TILE_H: int = 164

const ICON_STACK_H: int = 116
const PROGRESS_H: int = 16
const INNER_MARGIN: int = 6


const TILE_MIN_SIZE := Vector2(128, 164)
const PROG_H: int = 18

# Warmer / “LoM-ish” palette (tweak freely)
const COL_PANEL_BG := Color(0.16, 0.14, 0.13, 0.98)
const COL_PANEL_BORDER := Color(0.55, 0.45, 0.30, 1.0)
const COL_TILE_BG := Color(0.20, 0.18, 0.17, 1.0)
const COL_TILE_BORDER := Color(0.38, 0.33, 0.28, 1.0)
const COL_TILE_BORDER_SEL := Color(1.00, 0.84, 0.35, 1.0)

const COL_PB_BG := Color(0.12, 0.11, 0.10, 1.0)
const COL_PB_FILL := Color(0.22, 0.70, 0.32, 1.0)

const COL_TEXT := Color(0.95, 0.95, 0.95, 1.0)
const COL_TEXT_MUTED := Color(0.82, 0.80, 0.78, 1.0)
const COL_TEXT_LOCKED := Color(1.00, 0.55, 0.55, 1.0)


var _active_slot_idx: int = -1

var _slot_strip: HBoxContainer = null
var _skills_grid: GridContainer = null
var _set_label: Label = null


var _slot_btns: Array[Button] = []
var _slot_selected_skill: Array[String] = [] # per-slot skill id ("" = empty)

# Custom picker overlay (replaces OptionButton dropdown)
var _picker_layer: Control = null
var _picker_panel: PanelContainer = null
var _picker_title: Label = null
var _picker_list: ItemList = null
var _picker_slot_idx: int = -1

var _skill_ids: Array[String] = [] # option index -> skill_id (0 reserved for empty)
var _icon_cache: Dictionary = {}   # skill_id -> Texture2D (scaled)

var _slot_last_selected: Array[int] = []
var _status_label: Label = null
var _upgrade_all_btn: Button = null
var _quick_equip_btn: Button = null


var _hover_tip: PanelContainer = null
var _hover_tip_lbl: Label = null
var _hover_layer: CanvasLayer = null
var _popup_hover_popup: PopupMenu = null
var _popup_hover_index: int = -1

var testNum: int = 1

func _ready() -> void:
	top_level = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	Game.player_changed.connect(_on_player_changed)
	_build()
	# Defer centering until controls have a real size.
	call_deferred("_center_panel")

func _on_player_changed() -> void:
	refresh_ui()

func refresh_ui() -> void:
	# Clear any cached icons so the UI can rebuild if needed.
	_icon_cache.clear()

	if has_method("_refresh_from_player"):
		call("_refresh_from_player")
	if has_method("_rebuild_skill_grid"):
		call("_rebuild_skill_grid")


	# These exist in your newer SkillsPanel versions; safe-call so this file still compiles.
	if has_method("_refresh_upgrade_all_visibility"):
		call("_refresh_upgrade_all_visibility")
	if has_method("_refresh_option_unlock_states"):
		call("_refresh_option_unlock_states")
	if has_method("_refresh_quick_equip_state"):
		call("_refresh_quick_equip_state")


# ---------------- Tooltip helpers ----------------

func _rarity_name_for_def(def: SkillDef) -> String:
	if def == null:
		return "Common"

	# If rarity hasn't been implemented yet, default safely.
	if not ("rarity" in def):
		return "Common"

	var r: int = int(def.get("rarity"))
	match r:
		0: return "Common"
		1: return "Uncommon"
		2: return "Rare"
		3: return "Legendary"
		4: return "Mythical"
	return "Common"

func _tooltip_for_skill(skill_id: String) -> String:
	if skill_id == "":
		return "Empty slot."
	var def: SkillDef = SkillCatalog.get_def(skill_id)
	if def == null:
		return skill_id

	var lv: int = _player_skill_level(skill_id)
	var prog: int = _player_skill_progress(skill_id)
	var req: int = _copies_required_for_next_level(lv)
	
	# Example: Level 1 (0/2) after upgrading from 0->1
	# For Level 0 it will show Level 0 (0/1) and indicate locked.
	var lock_txt := "LOCKED\n" if lv <= 0 else ""
	return "%s%s\nRarity: %s\nLevel: %d (%d/%d)\nCooldown: %.1fs\n\n%s" % [
		lock_txt,
		def.display_name,
		_rarity_name_for_def(def),
		lv, prog, req,
		float(def.cooldown),
		def.description
	]

func _player_skill_level(skill_id: String) -> int:
	if Game.player == null:
		return 0
	if Game.player.has_method("ensure_active_skills_initialized"):
		Game.player.call("ensure_active_skills_initialized")
	var d: Variant = Game.player.get("skill_levels")
	if typeof(d) != TYPE_DICTIONARY:
		return 0
	return int((d as Dictionary).get(skill_id, 0))

func _player_skill_progress(skill_id: String) -> int:
	if Game.player == null:
		return 0
	if Game.player.has_method("ensure_active_skills_initialized"):
		Game.player.call("ensure_active_skills_initialized")
	var d: Variant = Game.player.get("skill_progress")
	if typeof(d) != TYPE_DICTIONARY:
		return 0
	return int((d as Dictionary).get(skill_id, 0))

func _copies_required_for_next_level(level: int) -> int:
	return maxi(1, level + 1)

func _ensure_hover_tooltip_ui() -> void:
	if _hover_tip != null:
		return

	# Put the hover tooltip on its own CanvasLayer so it renders ABOVE PopupMenus.
	_hover_layer = CanvasLayer.new()
	_hover_layer.layer = 200
	add_child(_hover_layer)

	_hover_tip = PanelContainer.new()
	_hover_tip.name = "HoverTip"
	_hover_tip.visible = false
	_hover_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_tip.z_index = 10_000
	_hover_layer.add_child(_hover_tip)

	_hover_tip_lbl = Label.new()
	_hover_tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hover_tip_lbl.custom_minimum_size = Vector2(320, 0)
	_hover_tip.add_child(_hover_tip_lbl)

func _hide_hover_tip() -> void:
	if _hover_tip != null:
		_hover_tip.visible = false

func _show_hover_tip(text: String) -> void:
	if _hover_tip == null:
		return
	_hover_tip_lbl.text = text
	_hover_tip.visible = true
	call_deferred("_position_hover_tip")

func _position_hover_tip() -> void:
	if _hover_tip == null or not _hover_tip.visible:
		return

	var vp := get_viewport_rect().size
	var m := get_viewport().get_mouse_position()

	# Force a reasonable size measurement
	_hover_tip.reset_size()
	var sz := _hover_tip.size
	if sz == Vector2.ZERO:
		sz = _hover_tip.get_combined_minimum_size()

	var pos := m + Vector2(14, 14)
	if pos.x + sz.x > vp.x - 8:
		pos.x = vp.x - sz.x - 8
	if pos.y + sz.y > vp.y - 8:
		pos.y = vp.y - sz.y - 8
	pos.x = max(pos.x, 8)
	pos.y = max(pos.y, 8)

	_hover_tip.position = pos

func _on_skill_popup_id_focused(id: int) -> void:
	# id is the item_id you assigned in opt.add_item(..., id)
	if id == 0:
		_show_hover_tip(_tooltip_for_skill(""))
		return
	if id < 0 or id >= _skill_ids.size():
		_hide_hover_tip()
		return

	var sid := _skill_ids[id]
	_show_hover_tip(_tooltip_for_skill(sid))

func _on_skill_popup_index_focused(index: int, popup: PopupMenu) -> void:
	var id := popup.get_item_id(index)
	_on_skill_popup_id_focused(id)

func _popup_index_at_position(popup: PopupMenu) -> int:
	# Window-local mouse position (this is the key fix).
	var pos: Vector2 = popup.get_mouse_position()
	
	# Prefer built-in helper if available.
	if popup.has_method("get_item_index_at_position"):
		var v: Variant = popup.call("get_item_index_at_position", pos)
		return int(v)

	# Fallback: scan item rects (also in popup-local coords).
	if popup.has_method("get_item_rect"):
		var n: int = popup.get_item_count()
		for i in range(n):
			var rv: Variant = popup.call("get_item_rect", i)
			if rv is Rect2:
				var r: Rect2 = rv
				if r.has_point(pos):
					return i

	return -1

func _on_skill_popup_window_input(event: InputEvent, popup: PopupMenu) -> void:
	if event is InputEventMouseMotion:
		var idx: int = _popup_index_at_position(popup)
	
		print("pos=", popup.get_mouse_position(), " size=", popup.size, " idx=", _popup_index_at_position(popup))
		if idx < 0:
			_hide_hover_tip()
			return

		_on_skill_popup_id_focused(popup.get_item_id(idx))

		# Keep tooltip following mouse
		if _hover_tip != null and _hover_tip.visible:
			_position_hover_tip()

	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_hide_hover_tip()

# ---------------- Icon helpers ----------------

func _scaled_icon_for_skill_id(sid: String) -> Texture2D:
	if sid == "":
		return null
	if _icon_cache.has(sid):
		return _icon_cache[sid]

	var tex: Texture2D = null
	var d := SkillCatalog.get_def(sid)
	if d != null and d.has_method("icon_texture"):
		tex = d.icon_texture()

	# Fallback by convention
	if tex == null:
		var p := "res://assets/icons/skills/%s.png" % sid
		if ResourceLoader.exists(p):
			tex = load(p) as Texture2D

	if tex == null:
		_icon_cache[sid] = null
		return null

	var img := tex.get_image()
	if img == null:
		_icon_cache[sid] = tex
		return tex

	img.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	var out := ImageTexture.create_from_image(img)
	_icon_cache[sid] = out
	return out

# ---------------- UI ----------------

func _build() -> void:
	# Fullscreen overlay
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_gui_input)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "MainPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(720, 760)
	add_child(panel)
	
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = COL_PANEL_BG
	panel_sb.corner_radius_top_left = 14
	panel_sb.corner_radius_top_right = 14
	panel_sb.corner_radius_bottom_left = 14
	panel_sb.corner_radius_bottom_right = 14
	panel_sb.set_border_width_all(2)
	panel_sb.border_color = COL_PANEL_BORDER
	panel.add_theme_stylebox_override("panel", panel_sb)


	_ensure_hover_tooltip_ui()

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.offset_left = 12
	root.offset_right = -12
	root.offset_top = 12
	root.offset_bottom = -12
	panel.add_child(root)

	# ---------------- Header (Skill + close) ----------------
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(header)

	var title := Label.new()
	title.text = "Skill"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	header.add_child(title)

	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(44, 34)
	close.pressed.connect(queue_free)
	header.add_child(close)

	# ---------------- Set row ----------------
	var set_row := HBoxContainer.new()
	set_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_row.add_theme_constant_override("separation", 10)
	root.add_child(set_row)

	_set_label = Label.new()
	_set_label.text = "Set 1"
	_set_label.add_theme_font_size_override("font_size", 18)
	set_row.add_child(_set_label)

	var set_spacer := Control.new()
	set_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_row.add_child(set_spacer)

	# Optional: placeholder “swap” button (like screenshot)
	var swap_btn := Button.new()
	swap_btn.text = "⇄"
	swap_btn.custom_minimum_size = Vector2(44, 34)
	swap_btn.disabled = true # enable later when you implement multiple sets
	set_row.add_child(swap_btn)

	# ---------------- Slot strip (5 boxes) ----------------
	_slot_strip = HBoxContainer.new()
	_slot_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_strip.add_theme_constant_override("separation", 10)
	root.add_child(_slot_strip)

	_slot_btns.clear()
	_slot_selected_skill.clear()
	for i in range(SLOTS):
		_slot_selected_skill.append("")

	for slot_idx in range(SLOTS):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(SLOT_ICON_SIZE + 26, SLOT_ICON_SIZE + 26)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_slot_button_pressed.bind(slot_idx))
		_slot_strip.add_child(btn)
		_slot_btns.append(btn)


	# ---------------- Status label ----------------
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.modulate = Color(1.0, 0.7, 0.7, 1.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)

	# ---------------- Skill grid (scrollable) ----------------
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_skills_grid = GridContainer.new()
	_skills_grid.columns = GRID_COLUMNS
	_skills_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_skills_grid)

	# Build options list once (IMPORTANT: index 0 must be "")
	_skill_ids = [""]
	_icon_cache.clear()
	
	_skills_grid.add_theme_constant_override("h_separation", 10)
	_skills_grid.add_theme_constant_override("v_separation", 10)


	var all: Array[String] = SkillCatalog.all_active_ids()
	all.sort_custom(Callable(self, "_skill_less"))
	for id in all:
		_skill_ids.append(id)
		
	# ---------------- Action buttons row (Quick Equip + Upgrade) ----------------
	var actions := HBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 14)
	root.add_child(actions)

	_quick_equip_btn = Button.new()
	_quick_equip_btn.text = "Quick Equip"
	_quick_equip_btn.custom_minimum_size = Vector2(0, 58)
	_quick_equip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quick_equip_btn.pressed.connect(_on_quick_equip_pressed)
	_apply_action_button_style(
		_quick_equip_btn,
		Color(0.20, 0.45, 0.85, 1.0),   # bg
		Color(0.55, 0.75, 1.0, 1.0),    # border
		Color(0.24, 0.50, 0.90, 1.0),   # hover
		Color(0.16, 0.38, 0.75, 1.0)    # pressed
	)
	actions.add_child(_quick_equip_btn)

	# Recreate/move your upgrade button here (right side)
	_upgrade_all_btn = Button.new()
	_upgrade_all_btn.text = "Upgrade" # keep your wording
	_upgrade_all_btn.custom_minimum_size = Vector2(0, 58)
	_upgrade_all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_all_btn.pressed.connect(_on_upgrade_all_pressed)
	_apply_action_button_style(
		_upgrade_all_btn,
		Color(0.22, 0.22, 0.24, 1.0),
		Color(0.45, 0.45, 0.50, 1.0),
		Color(0.26, 0.26, 0.29, 1.0),
		Color(0.18, 0.18, 0.20, 1.0)
	)
	actions.add_child(_upgrade_all_btn)


	# Footer (keep your existing buttons if you want)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	root.add_child(footer)

	var gen := Button.new()
	gen.text = "Generator"
	gen.pressed.connect(func() -> void:
		var p := SkillGeneratorPanel.new()
		if p.has_signal("closed"):
			p.connect("closed", Callable(self, "refresh_ui"))
		Game.popup_root().add_child(p)
	)
	footer.add_child(gen)

	var passives_btn := Button.new()
	passives_btn.text = "Passives"
	passives_btn.pressed.connect(func() -> void:
		var pp := PassivesPanel.new()
		Game.popup_root().add_child(pp)
	)
	footer.add_child(passives_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	var close2 := Button.new()
	close2.text = "Close"
	close2.pressed.connect(queue_free)
	footer.add_child(close2)

	# Apply current equipped skills into UI + build grid
	_refresh_from_player()
	_refresh_slot_strip_styles()
	_rebuild_skill_grid()
	_refresh_upgrade_all_visibility()
	_refresh_quick_equip_state()


func _refresh_from_player() -> void:
	if Game.player == null:
		return
	if Game.player.has_method("ensure_active_skills_initialized"):
		Game.player.call("ensure_active_skills_initialized")

	var eq: Array = []
	var eqv: Variant = Game.player.get("equipped_active_skills")
	if typeof(eqv) == TYPE_ARRAY:
		eq = eqv as Array

	while eq.size() < SLOTS:
		eq.append("")

	for i in range(SLOTS):
		var sid: String = String(eq[i]) if i < eq.size() else ""
		_slot_selected_skill[i] = sid
		_update_slot_button(i, sid)

	_refresh_upgrade_all_visibility()

func _center_panel() -> void:
	var panel := get_node_or_null("MainPanel") as Control
	if panel == null:
		return

	# Force it to its minimum size; keeps it consistent across resolutions.
	panel.size = panel.custom_minimum_size

	# Center in viewport (top_level ensures viewport coords).
	var vp := get_viewport_rect().size
	panel.position = (vp - panel.size) * 0.5

func _rarity_rank(skill_id: String) -> int:
	var def: SkillDef = SkillCatalog.get_def(skill_id)
	if def == null:
		return 0
	if not ("rarity" in def):
		return 0
	return int(def.get("rarity"))

func _display_name_for(skill_id: String) -> String:
	var def: SkillDef = SkillCatalog.get_def(skill_id)
	if def == null:
		return skill_id
	return String(def.display_name)

func _skill_less(a: String, b: String) -> bool:
	var ra := _rarity_rank(a)
	var rb := _rarity_rank(b)
	if ra != rb:
		return ra < rb # Common -> Mythical
	var na := _display_name_for(a).to_lower()
	var nb := _display_name_for(b).to_lower()
	if na != nb:
		return na < nb
	# final tie-breaker
	return a < b

func _rarity_header_text(r: int) -> String:
	match r:
		0: return "— Common —"
		1: return "— Uncommon —"
		2: return "— Rare —"
		3: return "— Legendary —"
		4: return "— Mythical —"
	return "— Common —"

func _find_item_index_by_id(opt: OptionButton, wanted_id: int) -> int:
	for i in range(opt.item_count):
		if opt.get_item_id(i) == wanted_id:
			return i
	return -1

func _update_slot_button(slot_idx: int, sid: String) -> void:
	if slot_idx < 0 or slot_idx >= _slot_btns.size():
		return
	var btn: Button = _slot_btns[slot_idx]
	if btn == null:
		return

	btn.add_theme_font_size_override("font_size", 32)
	btn.add_theme_color_override("font_color", COL_TEXT)

	if sid == "":
		btn.text = "+"
		btn.icon = null
		btn.tooltip_text = "Empty slot. Select this slot, then pick a skill below."
	else:
		btn.text = ""
		btn.icon = SkillCatalog.icon_with_rarity_border(sid, SLOT_ICON_SIZE, 2)
		btn.tooltip_text = _tooltip_for_skill(sid)

func _on_slot_button_pressed(slot_idx: int) -> void:
	_active_slot_idx = slot_idx
	_refresh_slot_strip_styles()

	if _status_label != null:
		_status_label.text = "Select a skill below to equip into Slot %d." % (slot_idx + 1)

func _ensure_skill_picker_ui() -> void:
	if _picker_layer != null:
		return

	_picker_layer = Control.new()
	_picker_layer.name = "SkillPickerLayer"
	_picker_layer.top_level = true
	_picker_layer.visible = false
	_picker_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_picker_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_skill_picker()
	)
	_picker_layer.add_child(dim)

	_picker_panel = PanelContainer.new()
	_picker_panel.custom_minimum_size = Vector2(760, 540)
	_picker_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_picker_layer.add_child(_picker_panel)

	var root := VBoxContainer.new()
	root.offset_left = 12
	root.offset_right = -12
	root.offset_top = 12
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 10)
	_picker_panel.add_child(root)

	_picker_title = Label.new()
	_picker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_picker_title.add_theme_font_size_override("font_size", 20)
	root.add_child(_picker_title)

	_picker_list = ItemList.new()
	_picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker_list.select_mode = ItemList.SELECT_SINGLE
	_picker_list.item_clicked.connect(_on_picker_item_clicked)
	_picker_list.item_activated.connect(_on_picker_item_activated)
	root.add_child(_picker_list)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(_close_skill_picker)
	root.add_child(close)

	call_deferred("_center_skill_picker_panel")

func _center_skill_picker_panel() -> void:
	if _picker_panel == null:
		return
	var vp := get_viewport_rect().size
	_picker_panel.size = _picker_panel.custom_minimum_size
	_picker_panel.position = (vp - _picker_panel.size) * 0.5

func _open_skill_picker(slot_idx: int) -> void:
	_ensure_skill_picker_ui()
	_picker_slot_idx = slot_idx
	_picker_title.text = "Select Skill for Slot %d" % (slot_idx + 1)
	_rebuild_skill_picker_list()
	_picker_layer.visible = true
	call_deferred("_center_skill_picker_panel")

func _close_skill_picker() -> void:
	if _picker_layer == null:
		_picker_slot_idx = -1
		return
	_picker_layer.visible = false
	_picker_slot_idx = -1

func _rebuild_skill_picker_list() -> void:
	if _picker_list == null:
		return

	_picker_list.clear()

	# (Empty)
	_picker_list.add_item("(Empty)")
	var empty_i: int = _picker_list.item_count - 1
	_picker_list.set_item_metadata(empty_i, "")
	_picker_list.set_item_tooltip(empty_i, _tooltip_for_skill(""))

	var last_rarity: int = -1

	for idx in range(1, _skill_ids.size()):
		var sid: String = _skill_ids[idx]
		var r: int = _rarity_rank(sid)

		if r != last_rarity:
			last_rarity = r
			_picker_list.add_item(_rarity_header_text(r))
			var header_i: int = _picker_list.item_count - 1
			_picker_list.set_item_selectable(header_i, false)
			_picker_list.set_item_disabled(header_i, true)

		var def := SkillCatalog.get_def(sid)
		var nm: String = def.display_name if def != null else sid
		var icon := SkillCatalog.icon_with_rarity_border(sid, ICON_SIZE, 2)

		_picker_list.add_item(nm, icon)
		var item_i: int = _picker_list.item_count - 1
		_picker_list.set_item_metadata(item_i, sid)
		_picker_list.set_item_tooltip(item_i, _tooltip_for_skill(sid))

		var lv: int = _player_skill_level(sid)
		if lv <= 0:
			_picker_list.set_item_selectable(item_i, false)
			_picker_list.set_item_disabled(item_i, true)

	# Highlight current selection (best-effort)
	if _picker_slot_idx >= 0 and _picker_slot_idx < _slot_selected_skill.size():
		var cur: String = _slot_selected_skill[_picker_slot_idx]
		if cur == "":
			_picker_list.select(0)
		else:
			for i in range(_picker_list.item_count):
				var md: Variant = _picker_list.get_item_metadata(i)
				if typeof(md) == TYPE_STRING and String(md) == cur:
					_picker_list.select(i)
					break

func _on_picker_item_clicked(index: int, _pos: Vector2, button_index: int) -> void:
	if button_index != MOUSE_BUTTON_LEFT:
		return
	_apply_picker_index(index)

func _on_picker_item_activated(index: int) -> void:
	_apply_picker_index(index)

func _apply_picker_index(index: int) -> void:
	if _picker_slot_idx < 0:
		return
	if _picker_list == null:
		return
	if index < 0 or index >= _picker_list.item_count:
		return

	var md: Variant = _picker_list.get_item_metadata(index)
	if typeof(md) != TYPE_STRING:
		return
	var sid: String = String(md)

	_apply_skill_to_slot(_picker_slot_idx, sid)

func _apply_skill_to_slot(slot_idx: int, sid: String) -> void:
	if Game.player == null:
		return
	if Game.player.has_method("ensure_active_skills_initialized"):
		Game.player.call("ensure_active_skills_initialized")

	if _status_label != null:
		_status_label.text = ""

	# Locked cannot be equipped
	if sid != "":
		var lv: int = _player_skill_level(sid)
		if lv <= 0:
			if _status_label != null:
				_status_label.text = "That skill is locked (Level 0). Draw it to unlock."
			return

	# Enforce uniqueness
	if sid != "":
		for i in range(SLOTS):
			if i == slot_idx:
				continue
			if _slot_selected_skill[i] == sid:
				if _status_label != null:
					var def := SkillCatalog.get_def(sid)
					var nm := def.display_name if def != null else sid
					_status_label.text = "You can only equip one copy of %s." % nm
				return

	# Write to player
	var eq: Array = []
	var eqv: Variant = Game.player.get("equipped_active_skills")
	if typeof(eqv) == TYPE_ARRAY:
		eq = eqv as Array
	while eq.size() < SLOTS:
		eq.append("")

	eq[slot_idx] = sid
	Game.player.set("equipped_active_skills", eq)

	# Update local + UI
	_slot_selected_skill[slot_idx] = sid
	_update_slot_button(slot_idx, sid)

	SaveManager.save_now()
	Game.player_changed.emit()

	_refresh_upgrade_all_visibility()
	#_close_skill_picker()

# ---------------- Upgrades ----------------

func _can_upgrade_skill(skill_id: String) -> bool:
	if skill_id == "":
		return false
	var lv: int = _player_skill_level(skill_id)
	var prog: int = _player_skill_progress(skill_id)
	var req: int = _copies_required_for_next_level(lv)
	return prog >= req

func _can_upgrade_any() -> bool:
	# _skill_ids[0] is "".
	for i in range(1, _skill_ids.size()):
		var sid: String = _skill_ids[i]
		if _can_upgrade_skill(sid):
			return true
	return false

func _refresh_upgrade_all_visibility() -> void:
	if _upgrade_all_btn == null:
		return
	_upgrade_all_btn.visible = true
	_upgrade_all_btn.disabled = not _can_upgrade_any()


func _refresh_option_unlock_states() -> void:
	# With the custom picker, we rebuild the list on open.
	# Here we only refresh slot button tooltips.
	for i in range(SLOTS):
		var sid: String = _slot_selected_skill[i]
		_update_slot_button(i, sid)

func _on_upgrade_all_pressed() -> void:
	if Game.player == null:
		return
	if Game.player.has_method("ensure_active_skills_initialized"):
		Game.player.call("ensure_active_skills_initialized")

	# Pull dict references, but write back via set() after mutation.
	var levels_v: Variant = Game.player.get("skill_levels")
	var prog_v: Variant = Game.player.get("skill_progress")
	if typeof(levels_v) != TYPE_DICTIONARY or typeof(prog_v) != TYPE_DICTIONARY:
		return

	var levels: Dictionary = levels_v as Dictionary
	var prog: Dictionary = prog_v as Dictionary

	var total_levels_gained: int = 0
	var skills_upgraded: int = 0

	for i in range(1, _skill_ids.size()):
		var sid: String = _skill_ids[i]
		var lv: int = int(levels.get(sid, 0))
		var p: int = int(prog.get(sid, 0))
		var gained: int = 0

		while true:
			var req: int = _copies_required_for_next_level(lv)
			if p < req:
				break
			p -= req
			lv += 1
			gained += 1

		if gained > 0:
			skills_upgraded += 1
			total_levels_gained += gained
			levels[sid] = lv
			prog[sid] = p

	# Persist back to player
	Game.player.set("skill_levels", levels)
	Game.player.set("skill_progress", prog)

	if _status_label != null:
		if total_levels_gained > 0:
			_status_label.text = "Upgraded %d level(s) across %d skill(s)." % [total_levels_gained, skills_upgraded]
		else:
			_status_label.text = ""

	SaveManager.save_now()
	Game.player_changed.emit()

	# Refresh UI states (unlocking/tooltip updates and button visibility)
	_refresh_option_unlock_states()
	_refresh_upgrade_all_visibility()

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		queue_free()
		accept_event()

func _refresh_slot_strip_styles() -> void:
	for i in range(_slot_btns.size()):
		var btn: Button = _slot_btns[i]
		if btn == null:
			continue

		var selected := (i == _active_slot_idx)

		var sb_n := StyleBoxFlat.new()
		sb_n.bg_color = COL_TILE_BG
		sb_n.corner_radius_top_left = 10
		sb_n.corner_radius_top_right = 10
		sb_n.corner_radius_bottom_left = 10
		sb_n.corner_radius_bottom_right = 10
		sb_n.set_border_width_all(3 if selected else 1)
		sb_n.border_color = COL_TILE_BORDER_SEL if selected else COL_TILE_BORDER

		var sb_h := sb_n.duplicate() as StyleBoxFlat
		sb_h.bg_color = COL_TILE_BG.lightened(0.06)

		var sb_p := sb_n.duplicate() as StyleBoxFlat
		sb_p.bg_color = COL_TILE_BG.darkened(0.06)

		btn.add_theme_stylebox_override("normal", sb_n)
		btn.add_theme_stylebox_override("hover", sb_h)
		btn.add_theme_stylebox_override("pressed", sb_p)
		btn.add_theme_stylebox_override("disabled", sb_n)

func _rebuild_skill_grid() -> void:
	if _skills_grid == null:
		return

	for c in _skills_grid.get_children():
		c.queue_free()

	# Add a "Clear" tile so the user can empty a slot.
	_skills_grid.add_child(_make_skill_tile("", true))

	for idx in range(1, _skill_ids.size()):
		var sid: String = _skill_ids[idx]
		_skills_grid.add_child(_make_skill_tile(sid, false))

func _style_progress_bar(pb: ProgressBar) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = COL_PB_BG
	bg.corner_radius_top_left = 6
	bg.corner_radius_top_right = 6
	bg.corner_radius_bottom_left = 6
	bg.corner_radius_bottom_right = 6

	var fill := StyleBoxFlat.new()
	fill.bg_color = COL_PB_FILL
	fill.corner_radius_top_left = 6
	fill.corner_radius_top_right = 6
	fill.corner_radius_bottom_left = 6
	fill.corner_radius_bottom_right = 6

	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fill)

func _make_skill_tile(sid: String, is_clear_tile: bool) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = TILE_MIN_SIZE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.clip_contents = true
	btn.focus_mode = Control.FOCUS_NONE

	# Base tile style (warm, like screenshot)
	var selected_border := false
	# Optional: highlight if this skill is currently equipped in any slot
	if sid != "" and _slot_selected_skill.has(sid):
		selected_border = true

	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = COL_TILE_BG
	sb_n.corner_radius_top_left = 12
	sb_n.corner_radius_top_right = 12
	sb_n.corner_radius_bottom_left = 12
	sb_n.corner_radius_bottom_right = 12
	sb_n.set_border_width_all(2 if selected_border else 1)
	sb_n.border_color = COL_TILE_BORDER_SEL if selected_border else COL_TILE_BORDER

	var sb_h := sb_n.duplicate() as StyleBoxFlat
	sb_h.bg_color = COL_TILE_BG.lightened(0.06)

	var sb_p := sb_n.duplicate() as StyleBoxFlat
	sb_p.bg_color = COL_TILE_BG.darkened(0.06)

	btn.add_theme_stylebox_override("normal", sb_n)
	btn.add_theme_stylebox_override("hover", sb_h)
	btn.add_theme_stylebox_override("pressed", sb_p)
	btn.add_theme_stylebox_override("disabled", sb_n)

	btn.pressed.connect(_on_skill_tile_pressed.bind(sid))

	# Content should NOT steal clicks from the button
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", INNER_MARGIN)
	m.add_theme_constant_override("margin_right", INNER_MARGIN)
	m.add_theme_constant_override("margin_top", INNER_MARGIN)
	m.add_theme_constant_override("margin_bottom", INNER_MARGIN)
	btn.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.add_child(v)

	# --- Icon stack (bigger + reserved height) ---
	var icon_stack := Control.new()
	icon_stack.custom_minimum_size = Vector2(0, ICON_STACK_H)
	icon_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon_stack)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_stack.add_child(center)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(GRID_ICON_SIZE, GRID_ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center.add_child(icon)

	# Plus overlay (top-right)
	var plus := Label.new()
	plus.text = "+"
	plus.add_theme_font_size_override("font_size", 18)
	plus.modulate = Color(1, 1, 1, 0.85)
	plus.anchor_left = 1
	plus.anchor_right = 1
	plus.anchor_top = 0
	plus.anchor_bottom = 0
	plus.offset_right = -2
	plus.offset_left = plus.offset_right - 18
	plus.offset_top = 0
	plus.offset_bottom = plus.offset_top + 18
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_stack.add_child(plus)

	# Level badge INSIDE the icon (bottom-left)
	var lv_badge := Label.new()
	lv_badge.name = "LvBadge"
	lv_badge.text = ""
	lv_badge.add_theme_font_size_override("font_size", 12)
	lv_badge.modulate = Color(0.95, 0.95, 0.95, 1.0)
	lv_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv_badge.anchor_left = 0
	lv_badge.anchor_right = 0
	lv_badge.anchor_top = 1
	lv_badge.anchor_bottom = 1
	lv_badge.offset_left = 4
	lv_badge.offset_right = 44
	lv_badge.offset_bottom = -4
	lv_badge.offset_top = lv_badge.offset_bottom - 16

	var badge_bg := StyleBoxFlat.new()
	badge_bg.bg_color = Color(0, 0, 0, 0.55)
	badge_bg.corner_radius_top_left = 6
	badge_bg.corner_radius_top_right = 6
	badge_bg.corner_radius_bottom_left = 6
	badge_bg.corner_radius_bottom_right = 6
	lv_badge.add_theme_stylebox_override("normal", badge_bg)
	lv_badge.add_theme_constant_override("padding_left", 6)
	lv_badge.add_theme_constant_override("padding_right", 6)
	icon_stack.add_child(lv_badge)

	# Push progress bar lower
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	v.add_child(gap)

	# --- Progress bar (bigger + full width) ---
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(116, PROGRESS_H)
	pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pb.show_percentage = false
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pb)

	# Overlay progress text ON the bar
	var pb_text := Label.new()
	pb_text.name = "PBText"
	pb_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	pb_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pb_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pb_text.add_theme_font_size_override("font_size", 12)
	pb_text.modulate = Color(1, 1, 1, 0.95)
	pb_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_child(pb_text)

	# ----- Apply per-tile data -----
	btn.custom_minimum_size = Vector2(TILE_W, TILE_H)

	if is_clear_tile:
		icon.texture = null
		plus.visible = false
		lv_badge.visible = false
		pb_text.text = ""
		pb.min_value = 0
		pb.max_value = 1
		pb.value = 0
		btn.tooltip_text = "Clear the selected slot."
		return btn

	# Normal skill tile
	icon.texture = SkillCatalog.icon_with_rarity_border(sid, GRID_ICON_SIZE, 2)

	var lv: int = _player_skill_level(sid)
	var prog: int = _player_skill_progress(sid)
	var req: int = _copies_required_for_next_level(lv)

	if lv <= 0:
		btn.disabled = true
		lv_badge.visible = false
		pb.min_value = 0
		pb.max_value = 1
		pb.value = 0
		pb_text.text = ""
		btn.tooltip_text = _tooltip_for_skill(sid)
	else:
		lv_badge.visible = true
		lv_badge.text = "Lv.%d" % lv

		pb.min_value = 0
		pb.max_value = req
		pb.value = clampi(prog, 0, req)
		pb_text.text = "%d/%d" % [clampi(prog, 0, req), req]

		btn.tooltip_text = _tooltip_for_skill(sid)

	return btn

func _on_skill_tile_pressed(sid: String) -> void:
	if _active_slot_idx < 0:
		if _status_label != null:
			_status_label.text = "Select a slot first."
		return

	# Clear tile
	if sid == "":
		_apply_skill_to_slot(_active_slot_idx, "")
		return

	_apply_skill_to_slot(_active_slot_idx, sid)

func _apply_action_button_style(btn: Button, bg: Color, border: Color, hover_bg: Color, pressed_bg: Color) -> void:
	btn.add_theme_font_size_override("font_size", 20)

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", sb)

	var sb_hover: StyleBoxFlat = sb.duplicate()
	sb_hover.bg_color = hover_bg
	btn.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed: StyleBoxFlat = sb.duplicate()
	sb_pressed.bg_color = pressed_bg
	btn.add_theme_stylebox_override("pressed", sb_pressed)

	var sb_disabled: StyleBoxFlat = sb.duplicate()
	sb_disabled.bg_color = Color(bg.r, bg.g, bg.b, 0.35)
	sb_disabled.border_color = Color(border.r, border.g, border.b, 0.35)
	btn.add_theme_stylebox_override("disabled", sb_disabled)

func _qe_skill_less(a: String, b: String) -> bool:
	# Higher rarity first, then higher level, then higher progress, then name.
	var ra := _rarity_rank(a)
	var rb := _rarity_rank(b)
	if ra != rb:
		return ra > rb

	var la := _player_skill_level(a)
	var lb := _player_skill_level(b)
	if la != lb:
		return la > lb

	var pa := _player_skill_progress(a)
	var pb := _player_skill_progress(b)
	if pa != pb:
		return pa > pb

	return a < b

func _count_unlocked_active_skills() -> int:
	var n := 0
	for i in range(1, _skill_ids.size()):
		var sid := _skill_ids[i]
		if _player_skill_level(sid) > 0:
			n += 1
	return n

func _refresh_quick_equip_state() -> void:
	if _quick_equip_btn == null:
		return
	_quick_equip_btn.disabled = (_count_unlocked_active_skills() <= 0)

func _on_quick_equip_pressed() -> void:
	if Game.player == null:
		return
	if Game.player.has_method("ensure_active_skills_initialized"):
		Game.player.call("ensure_active_skills_initialized")

	# Pull equipped
	var eq: Array = []
	var eqv: Variant = Game.player.get("equipped_active_skills")
	if typeof(eqv) == TYPE_ARRAY:
		eq = eqv as Array
	while eq.size() < SLOTS:
		eq.append("")

	# Collect unlocked candidates
	var candidates: Array[String] = []
	for i in range(1, _skill_ids.size()):
		var sid := _skill_ids[i]
		if _player_skill_level(sid) > 0:
			candidates.append(sid)

	if candidates.is_empty():
		if _status_label != null:
			_status_label.text = "No unlocked skills to equip yet."
		return

	candidates.sort_custom(Callable(self, "_qe_skill_less"))

	# Decide whether we’re filling empties or replacing all
	var empty_slots: Array[int] = []
	for i in range(SLOTS):
		if String(eq[i]) == "":
			empty_slots.append(i)

	var replacing_all := false
	if empty_slots.is_empty():
		replacing_all = true
		empty_slots.clear()
		for i in range(SLOTS):
			eq[i] = ""
			empty_slots.append(i)

	# Track already-used skills so we don’t duplicate
	var used := {}
	if not replacing_all:
		for i in range(SLOTS):
			var cur := String(eq[i])
			if cur != "":
				used[cur] = true

	# Fill slots
	var filled := 0
	var slot_ptr := 0
	for sid in candidates:
		if slot_ptr >= empty_slots.size():
			break
		if used.has(sid):
			continue

		var sidx := empty_slots[slot_ptr]
		slot_ptr += 1

		eq[sidx] = sid
		used[sid] = true
		filled += 1

	# Save/apply
	Game.player.set("equipped_active_skills", eq)
	SaveManager.save_now()
	Game.player_changed.emit()

	if _status_label != null:
		if replacing_all:
			_status_label.text = "Quick Equip: equipped %d skill(s)." % filled
		else:
			_status_label.text = "Quick Equip: filled %d empty slot(s)." % filled
