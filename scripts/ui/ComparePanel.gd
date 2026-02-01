extends Control
class_name ComparePanel

signal equip_pressed
signal sell_pressed
signal close_pressed

# -------------------- Tunables --------------------
const SHELL_W := 740
const SHELL_H := 760

# -------------------- Palette (LoM-ish parchment) --------------------
const COL_DIM := Color(0, 0, 0, 0.55)

const COL_SHELL_BG := Color(0.94, 0.91, 0.82, 1.0)   # parchment
const COL_BORDER   := Color(0.55, 0.46, 0.32, 1.0)   # warm brown
const COL_LINE     := Color(0.78, 0.69, 0.52, 1.0)   # divider line

const COL_CARD_BG     := Color(0.98, 0.97, 0.93, 1.0)
const COL_CARD_BORDER := Color(0.70, 0.60, 0.44, 1.0)

const COL_TEXT_DARK  := Color(0.18, 0.14, 0.10, 1.0)
const COL_TEXT_MUTED := Color(0.38, 0.32, 0.26, 1.0)
const COL_VALUE_GOLD := Color(0.62, 0.48, 0.24, 1.0)

# Section “ribbons”
const COL_EQUIPPED_ACCENT := Color(0.80, 0.74, 0.60, 1.0) # tan ribbon
const COL_NEW_ACCENT      := Color(0.80, 0.24, 0.18, 1.0) # red ribbon

# Up/down indicators (warmer tones)
const COL_UP   := Color(0.20, 0.70, 0.28, 1.0)
const COL_DOWN := Color(0.78, 0.18, 0.16, 1.0)

# Buttons
const COL_BTN_SELL_BG    := Color(0.78, 0.25, 0.20, 1.0)
const COL_BTN_SELL_BR    := Color(0.55, 0.14, 0.12, 1.0)
const COL_BTN_EQUIP_BG   := Color(0.26, 0.62, 0.31, 1.0)
const COL_BTN_EQUIP_BR   := Color(0.15, 0.40, 0.18, 1.0)
const COL_BTN_CLOSE_BG   := Color(0.80, 0.74, 0.60, 1.0)
const COL_BTN_CLOSE_BR   := Color(0.55, 0.46, 0.32, 1.0)

const COL_NAME_BASE := Color(0.16, 0.12, 0.09, 1.0) # darker than COL_TEXT_DARK

# --- Gear icon box ---
const GEAR_ICON_DIR := "res://assets/icons/UI/gear"
const GEAR_ICON_DEFAULT: Texture2D = preload("res://assets/icons/UI/gear/default_icon.png")
const GEAR_ICON_BOX_SIZE := 64
const GEAR_ICON_BOX_PAD := 6


# Stat list to display (extend freely)
const STAT_DEFS := [
	{"k":"hp", "n":"HP", "t":"int"},
	{"k":"atk", "n":"ATK", "t":"int"},
	{"k":"def", "n":"DEF", "t":"int"},
	{"k":"atk_spd", "n":"Atk Spd", "t":"pct_or_float"},
	{"k":"crit_chance", "n":"Crit Rate", "t":"pct"},
	{"k":"avoidance", "n":"Evasion", "t":"pct"},
	{"k":"block", "n":"Block", "t":"pct"},
	{"k":"combo_chance", "n":"Combo", "t":"pct"},
	{"k":"counter_chance", "n":"Counterstrike", "t":"pct"},
	{"k":"boss_dmg", "n":"Boss DMG", "t":"pct"},
	{"k":"final_dmg_boost_pct", "n":"Final DMG", "t":"pct"},
]

# -------------------- State --------------------
var _new_item: GearItem = null
var _eq_item: GearItem = null
var _new_cp: int = 0
var _eq_cp: int = 0
var _delta_cp: int = 0
var _pending_refresh: bool = false
var _want_compare_mode: bool = true
var _pending_title: String = ""


# -------------------- Nodes --------------------
var _shell: PanelContainer
var _title_lbl: Label
var _btn_x: Button

var _eq_name: Label
var _eq_cp_lbl: Label
var _eq_stats: VBoxContainer

var _new_name: Label
var _new_cp_lbl: Label
var _new_stats: VBoxContainer

var _btn_sell: Button
var _btn_equip: Button
var _btn_close: Button

var _eq_icon_box: PanelContainer
var _eq_icon_tex: TextureRect

var _new_icon_box: PanelContainer
var _new_icon_tex: TextureRect

var _eq_section_hdr: Control
var _eq_card: PanelContainer
var _new_section_hdr: Control
var _new_card: PanelContainer

var _eq_section: VBoxContainer
var _new_section: VBoxContainer

var _context_slot_id: int = -1


const SLOT_ICON_KEYS := {
	Catalog.GearSlot.WEAPON: "weapon",
	Catalog.GearSlot.HELMET: "helmet",
	Catalog.GearSlot.SHOULDERS: "shoulders",
	Catalog.GearSlot.CHEST: "chest",
	Catalog.GearSlot.GLOVES: "gloves",
	Catalog.GearSlot.BELT: "belt",
	Catalog.GearSlot.LEGS: "legs",
	Catalog.GearSlot.BOOTS: "boots",
	Catalog.GearSlot.RING: "ring",
	Catalog.GearSlot.BRACELET: "bracelet",
	Catalog.GearSlot.MOUNT: "mount",
	Catalog.GearSlot.ARTIFACT: "artifact",
}



func _ready() -> void:
	name = "ComparePanel"

	top_level = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

	# Dim
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = COL_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# Shell
	_shell = PanelContainer.new()
	_shell.anchor_left = 0.5
	_shell.anchor_right = 0.5
	_shell.anchor_top = 0.5
	_shell.anchor_bottom = 0.5
	_shell.offset_left = -SHELL_W * 0.5
	_shell.offset_right = SHELL_W * 0.5
	_shell.offset_top = -SHELL_H * 0.5
	_shell.offset_bottom = SHELL_H * 0.5
	_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shell)

	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = COL_SHELL_BG
	shell_style.corner_radius_top_left = 14
	shell_style.corner_radius_top_right = 14
	shell_style.corner_radius_bottom_left = 14
	shell_style.corner_radius_bottom_right = 14
	shell_style.set_border_width_all(2)
	shell_style.border_color = COL_BORDER
	shell_style.shadow_size = 12
	shell_style.shadow_color = Color(0, 0, 0, 0.18)
	shell_style.shadow_offset = Vector2(0, 6)
	_shell.add_theme_stylebox_override("panel", shell_style)


	var root := VBoxContainer.new()
	root.offset_left = 18
	root.offset_right = -18
	root.offset_top = 14
	root.offset_bottom = -14
	_shell.add_child(root)

	# Header row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	root.add_child(header_row)

	_title_lbl = Label.new()
	_title_lbl.text = "Gear Compare"
	_title_lbl.modulate = COL_TEXT_DARK
	_title_lbl.add_theme_font_size_override("font_size", 22)
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(_title_lbl)

	_btn_x = Button.new()
	_btn_x.text = "X"
	_btn_x.custom_minimum_size = Vector2(42, 36)
	_btn_x.pressed.connect(func() -> void:
		emit_signal("close_pressed")
	)
	header_row.add_child(_btn_x)

	root.add_child(_make_hr())

	# Scroll body (for long stat lists)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

# Equipped section (wrapped)
	_eq_section = VBoxContainer.new()
	_eq_section.add_theme_constant_override("separation", 10)
	body.add_child(_eq_section)

	_eq_section.add_child(_make_section_header("Current Gear", COL_EQUIPPED_ACCENT))
	var eq_card := _make_card(COL_EQUIPPED_ACCENT)
	_eq_section.add_child(eq_card)
	var eq_inner := eq_card.get_node("InnerMargin/Inner") as VBoxContainer
	

# --- Equipped header row: icon box + text ---
	var eq_top := HBoxContainer.new()
	eq_top.add_theme_constant_override("separation", 12)
	eq_inner.add_child(eq_top)

	var eq_icon_pack := _make_gear_icon_box()
	_eq_icon_box = eq_icon_pack[0]
	_eq_eq_icon_style_seed(_eq_icon_box) # optional helper for border consistency (see below)
	_eq_icon_tex = eq_icon_pack[1]
	eq_top.add_child(_eq_icon_box)

	var eq_text := VBoxContainer.new()
	eq_text.add_theme_constant_override("separation", 2)
	eq_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eq_top.add_child(eq_text)

	_eq_name = Label.new()
	_eq_name.add_theme_font_size_override("font_size", 20)
	_eq_name.add_theme_constant_override("outline_size", 2)
	_eq_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.12))
	eq_text.add_child(_eq_name)

	_eq_cp_lbl = Label.new()
	_eq_cp_lbl.modulate = COL_TEXT_MUTED
	eq_text.add_child(_eq_cp_lbl)


	eq_inner.add_child(_make_hr())
	_eq_stats = VBoxContainer.new()
	_eq_stats.add_theme_constant_override("separation", 6)
	eq_inner.add_child(_eq_stats)


# New section (wrapped)
	_new_section = VBoxContainer.new()
	_new_section.add_theme_constant_override("separation", 10)
	body.add_child(_new_section)

	_new_section.add_child(_make_section_header("NEW", COL_NEW_ACCENT))
	var new_card := _make_card(COL_NEW_ACCENT)
	_new_section.add_child(new_card)
	var new_inner := new_card.get_node("InnerMargin/Inner") as VBoxContainer


# --- New header row: icon box + text ---
	var new_top := HBoxContainer.new()
	new_top.add_theme_constant_override("separation", 12)
	new_inner.add_child(new_top)

	var new_icon_pack := _make_gear_icon_box()
	_new_icon_box = new_icon_pack[0]
	_eq_eq_icon_style_seed(_new_icon_box) # optional helper for border consistency (see below)
	_new_icon_tex = new_icon_pack[1]
	new_top.add_child(_new_icon_box)

	var new_text := VBoxContainer.new()
	new_text.add_theme_constant_override("separation", 2)
	new_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_top.add_child(new_text)

	_new_name = Label.new()
	_new_name.add_theme_font_size_override("font_size", 20)
	_new_name.add_theme_constant_override("outline_size", 2)
	_new_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.12))
	new_text.add_child(_new_name)

	_new_cp_lbl = Label.new()
	_new_cp_lbl.modulate = COL_TEXT_MUTED
	new_text.add_child(_new_cp_lbl)


	new_inner.add_child(_make_hr())
	_new_stats = VBoxContainer.new()
	_new_stats.add_theme_constant_override("separation", 6)
	new_inner.add_child(_new_stats)

	root.add_child(HSeparator.new())

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 14)
	root.add_child(btn_row)

	_btn_sell = Button.new()
	_btn_sell.text = "Sell"
	_btn_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_sell.custom_minimum_size = Vector2(0, 54)
	_btn_sell.pressed.connect(func() -> void: emit_signal("sell_pressed"))
	btn_row.add_child(_btn_sell)

	_btn_equip = Button.new()
	_btn_equip.text = "Equip"
	_btn_equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_equip.custom_minimum_size = Vector2(0, 54)
	_btn_equip.pressed.connect(func() -> void: emit_signal("equip_pressed"))
	btn_row.add_child(_btn_equip)

	_btn_close = Button.new()
	_btn_close.text = "Close"
	_btn_close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_close.custom_minimum_size = Vector2(0, 54)
	_btn_close.pressed.connect(func() -> void: emit_signal("close_pressed"))
	btn_row.add_child(_btn_close)
	
	_style_action_button(_btn_sell,  COL_BTN_SELL_BG,  COL_BTN_SELL_BR,  Color(0.98, 0.97, 0.93, 1.0))
	_style_action_button(_btn_equip, COL_BTN_EQUIP_BG, COL_BTN_EQUIP_BR, Color(0.98, 0.97, 0.93, 1.0))
	_style_action_button(_btn_close, COL_BTN_CLOSE_BG, COL_BTN_CLOSE_BR, COL_TEXT_DARK)
	
	_style_action_button(_btn_x, COL_BTN_CLOSE_BG, COL_BTN_CLOSE_BR, COL_TEXT_DARK)
	_btn_x.custom_minimum_size = Vector2(46, 36)



	# Default: compare mode (Sell/Equip visible, Close hidden)
	if _pending_refresh:
		_apply_pending()
	else:
		_set_mode_compare(true)
		_refresh()


func configure_compare(new_item: GearItem, equipped_item: GearItem, new_cp: int, eq_cp: int, delta_cp: int) -> void:
	_context_slot_id = int(new_item.slot) if new_item != null else -1
	_new_item = new_item
	_eq_item = equipped_item
	_new_cp = new_cp
	_eq_cp = eq_cp
	_delta_cp = delta_cp

	_want_compare_mode = true
	_pending_title = ""
	_pending_refresh = true

	if is_node_ready():
		_apply_pending()

func configure_details(title: String, item: GearItem, cp: int, slot_id: int = -1) -> void:
	_context_slot_id = slot_id

	# DETAILS should be single-card: use Current Gear section
	_eq_item = item
	_eq_cp = cp

	_new_item = null
	_new_cp = 0
	_delta_cp = 0

	_want_compare_mode = false
	_pending_title = title
	_pending_refresh = true

	if is_node_ready():
		_apply_pending()


# -------------------- UI helpers --------------------

func _set_mode_compare(is_compare: bool) -> void:
	_want_compare_mode = is_compare
	if _btn_sell == null:
		return

	_btn_sell.visible = is_compare
	_btn_equip.visible = is_compare
	_btn_close.visible = not is_compare

	# Hide the NEW section in details mode
	if _new_section != null:
		_new_section.visible = is_compare

func _apply_pending() -> void:
	_set_mode_compare(_want_compare_mode)

	if _title_lbl != null:
		if _pending_title != "":
			_title_lbl.text = _pending_title
		elif _want_compare_mode:
			_title_lbl.text = "Gear Compare"

	_pending_refresh = false
	_refresh()

func _make_section_header(text: String, accent: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var pill := PanelContainer.new()
	var st := StyleBoxFlat.new()

	var is_new := (accent == COL_NEW_ACCENT)

	st.bg_color = accent
	st.corner_radius_top_left = 10
	st.corner_radius_top_right = 10
	st.corner_radius_bottom_left = 10
	st.corner_radius_bottom_right = 10
	st.set_border_width_all(2)
	st.border_color = (COL_BTN_SELL_BR if is_new else COL_BORDER)

	pill.add_theme_stylebox_override("panel", st)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	pill.add_child(m)

	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = (Color(0.98, 0.97, 0.93, 1.0) if is_new else COL_TEXT_DARK)
	lbl.add_theme_font_size_override("font_size", 16)
	m.add_child(lbl)

	row.add_child(pill)
	row.add_child(Control.new())
	return row

func _make_card(_accent: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var st := StyleBoxFlat.new()
	st.bg_color = COL_CARD_BG
	st.corner_radius_top_left = 10
	st.corner_radius_top_right = 10
	st.corner_radius_bottom_left = 10
	st.corner_radius_bottom_right = 10
	st.set_border_width_all(2)
	st.border_color = COL_CARD_BORDER
	st.shadow_size = 6
	st.shadow_color = Color(0, 0, 0, 0.10)
	st.shadow_offset = Vector2(0, 3)
	pc.add_theme_stylebox_override("panel", st)

	var inner := MarginContainer.new()
	inner.name = "InnerMargin"
	inner.add_theme_constant_override("margin_left", 14)
	inner.add_theme_constant_override("margin_right", 14)
	inner.add_theme_constant_override("margin_top", 12)
	inner.add_theme_constant_override("margin_bottom", 12)
	pc.add_child(inner)

	var v := VBoxContainer.new()
	v.name = "Inner"
	v.add_theme_constant_override("separation", 6)
	inner.add_child(v)

	return pc

func _refresh() -> void:
	# Reset title when in compare mode
	if _btn_sell.visible:
		_title_lbl.text = "Gear Compare"

	# Equipped
	if _eq_item != null:
		_eq_name.text = _item_display_name(_eq_item)
		_eq_name.modulate = _name_color_for_item(_eq_item)
		_eq_cp_lbl.text = "CP: %d" % _eq_cp
		_update_gear_icon(_eq_icon_box, _eq_icon_tex, _eq_item)
		_build_stats(_eq_stats, _eq_item, _new_item, false)
	else:
		_eq_name.text = "(None Equipped)"
		_eq_name.modulate = COL_TEXT_MUTED
		_eq_cp_lbl.text = "CP: 0"
		_clear_children(_eq_stats)
		_update_gear_icon(_eq_icon_box, _eq_icon_tex, null)

	

	# New
	if _new_item != null:
		_new_name.text = _item_display_name(_new_item)
		_new_name.modulate = _name_color_for_item(_new_item)

		var line := "CP: %d" % _new_cp
		if _btn_sell.visible and _delta_cp != 0:
			line += "  (%s%d)" % ["+" if _delta_cp > 0 else "", _delta_cp]
			_new_cp_lbl.text = line
			_new_cp_lbl.modulate = COL_UP if _delta_cp > 0 else COL_DOWN
		else:
			_new_cp_lbl.text = line
			_new_cp_lbl.modulate = COL_TEXT_MUTED
		_update_gear_icon(_new_icon_box, _new_icon_tex, _new_item)
		_build_stats(_new_stats, _new_item, _eq_item, true)
	else:
		_new_name.text = "(No Item)"
		_new_name.modulate = COL_TEXT_MUTED
		_new_cp_lbl.text = "CP: 0"
		_new_cp_lbl.modulate = COL_TEXT_MUTED
		_clear_children(_new_stats)
		_update_gear_icon(_new_icon_box, _new_icon_tex, null)

	
func _build_stats(parent_vbox: VBoxContainer, a: GearItem, b: GearItem, show_arrows: bool) -> void:
	_clear_children(parent_vbox)

	for sd in STAT_DEFS:
		var k := String(sd["k"])
		var label := String(sd["n"])
		var typ := String(sd["t"])

		var av := _stat_value(a, k)
		var bv := _stat_value(b, k)

		# Hide if both are zero (keeps the panel clean)
		if absf(av) < 0.00001 and absf(bv) < 0.00001:
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		parent_vbox.add_child(row)

		var k_lbl := Label.new()
		k_lbl.text = label
		k_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		k_lbl.modulate = COL_TEXT_DARK
		row.add_child(k_lbl)

		var arrow_lbl := Label.new()
		arrow_lbl.text = ""
		arrow_lbl.custom_minimum_size = Vector2(18, 0)
		arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(arrow_lbl)

		var v_lbl := Label.new()
		v_lbl.text = _format_stat(av, typ)
		v_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v_lbl.modulate = COL_VALUE_GOLD
		row.add_child(v_lbl)

		if show_arrows and b != null:
			if av > bv + 0.00001:
				arrow_lbl.text = "▲"
				arrow_lbl.modulate = COL_UP
			elif av < bv - 0.00001:
				arrow_lbl.text = "▼"
				arrow_lbl.modulate = COL_DOWN
			else:
				arrow_lbl.text = ""
				arrow_lbl.modulate = Color(0, 0, 0, 0)
		else:
			arrow_lbl.text = ""
			arrow_lbl.modulate = Color(0, 0, 0, 0)

func _format_stat(v: float, typ: String) -> String:
	match typ:
		"int":
			return str(int(round(v)))
		"pct":
			var p := v
			# allow either 0.15 (15%) or 15 (15%)
			if absf(p) <= 1.0:
				p *= 100.0
			return "%0.2f%%" % p
		"pct_or_float":
			# if <= 1 treat as percent, else raw float
			if absf(v) <= 1.0:
				return "%0.2f%%" % (v * 100.0)
			return "%0.2f" % v
		_:
			return "%0.2f" % v

func _to_string_safe(v: Variant) -> String:
	if v == null:
		return ""
	if v is String:
		return v
	if v is StringName:
		return String(v)
	return str(v)

func _get_string_field(obj: Object, key: String) -> String:
	if obj == null:
		return ""

	# If there's a method with this name (e.g., display_name()), call it.
	if obj.has_method(key):
		return _to_string_safe(obj.call(key))

	# Otherwise, try property lookup.
	if obj.has_method("get"):
		var v: Variant = obj.get(key)

		# Godot can return a Callable when the key matches a method name.
		if v is Callable:
			var c: Callable = v as Callable
			if c.is_valid():
				return _to_string_safe(c.call())
			return ""

		return _to_string_safe(v)

	return ""

func _item_display_name(item: GearItem) -> String:
	if item == null:
		return "(None)"

	var rarity := _rarity_name(item)

	var base_name: String = ""
	base_name = _get_string_field(item, "display_name")

	if base_name == "":
		base_name = _get_string_field(item, "name")

	# Optional fallback for Resources
	if base_name == "":
		base_name = _get_string_field(item, "resource_name")

	if base_name == "":
		base_name = "Item"

	return "[%s] %s" % [rarity, base_name]

func _rarity_name(item: GearItem) -> String:
	if item == null:
		return "Common"
	# Prefer your Catalog mapping if available
	if "RARITY_NAMES" in Catalog:
		return String(Catalog.RARITY_NAMES.get(int(item.rarity), "Common"))
	# Fallback
	return str(int(item.rarity))

func _rarity_color(item: GearItem) -> Color:
	if item == null:
		return COL_TEXT_MUTED

	var r := int(item.rarity)

	# Preferred: use Catalog.RARITY_COLORS mapping (covers all your rarities)
	if "RARITY_COLORS" in Catalog:
		var v: Variant = Catalog.RARITY_COLORS.get(r, null)
		if v is Color:
			return v as Color

	# Fallback (safe)
	return COL_TEXT_MUTED

func _stat_value(item: GearItem, key: String) -> float:
	if item == null:
		return 0.0

	# 1) direct property
	if item.has_method("get"):
		var direct: Variant = item.get(key)
		if direct != null:
			return float(direct)

	# 2) common containers: stats / flat / passive / modifiers
	var containers: Array[String] = ["stats", "flat", "flat_stats", "passive_flat", "mods", "bonuses"]
	for c: String in containers:
		if not item.has_method("get"):
			break

		var blob: Variant = item.get(c)
		if blob == null:
			continue

		if blob is Dictionary:
			var d: Dictionary = blob as Dictionary
			var vv: Variant = d.get(key, 0.0)
			return float(vv)

		if blob is Object:
			var obj: Object = blob as Object
			if obj.has_method("get"):
				var vv2: Variant = obj.get(key)
				if vv2 != null:
					return float(vv2)

	return 0.0

func _clear_children(n: Node) -> void:
	for ch in n.get_children():
		ch.queue_free()

func _make_hr() -> Control:
	var r := ColorRect.new()
	r.color = COL_LINE
	r.custom_minimum_size = Vector2(0, 2)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _style_action_button(btn: Button, bg: Color, border: Color, text_col: Color) -> void:
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", text_col)

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10

	btn.add_theme_stylebox_override("normal", sb)

	var sb_h := sb.duplicate() as StyleBoxFlat
	sb_h.bg_color = bg.lightened(0.06)
	btn.add_theme_stylebox_override("hover", sb_h)

	var sb_p := sb.duplicate() as StyleBoxFlat
	sb_p.bg_color = bg.darkened(0.08)
	btn.add_theme_stylebox_override("pressed", sb_p)

	var sb_d := sb.duplicate() as StyleBoxFlat
	sb_d.bg_color = Color(bg.r, bg.g, bg.b, 0.45)
	sb_d.border_color = Color(border.r, border.g, border.b, 0.45)
	btn.add_theme_stylebox_override("disabled", sb_d)

func _name_color_for_item(item: GearItem) -> Color:
	# Use rarity as a tint, but force readability on parchment.
	var rc := _rarity_color(item)
	# Mix towards a dark base so Common/gray becomes readable.
	# (0.55 means 55% dark base, 45% rarity tint)
	var out := COL_NAME_BASE.lerp(rc, 0.45)
	out.a = 1.0
	return out

func _make_gear_icon_box() -> Array:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(GEAR_ICON_BOX_SIZE, GEAR_ICON_BOX_SIZE)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var st := StyleBoxFlat.new()
	st.bg_color = COL_CARD_BORDER # will be overridden per-item
	st.corner_radius_top_left = 12
	st.corner_radius_top_right = 12
	st.corner_radius_bottom_left = 12
	st.corner_radius_bottom_right = 12
	st.set_border_width_all(2)
	st.border_color = COL_BORDER
	box.add_theme_stylebox_override("panel", st)
	box.set_meta("sb", st) # store for later edits

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", GEAR_ICON_BOX_PAD)
	m.add_theme_constant_override("margin_right", GEAR_ICON_BOX_PAD)
	m.add_theme_constant_override("margin_top", GEAR_ICON_BOX_PAD)
	m.add_theme_constant_override("margin_bottom", GEAR_ICON_BOX_PAD)
	box.add_child(m)

	@warning_ignore("shadowed_variable_base_class")
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
	m.add_child(tr)

	return [box, tr]

# Optional: keeps border visually consistent even for bright rarity colors.
func _eq_eq_icon_style_seed(box: PanelContainer) -> void:
	if box == null:
		return
	var sb: Variant = box.get_meta("sb") if box.has_meta("sb") else null
	if sb is StyleBoxFlat:
		var st := sb as StyleBoxFlat
		st.border_color = COL_BORDER

@warning_ignore("shadowed_variable_base_class")
func _update_gear_icon(box: PanelContainer, tr: TextureRect, item: GearItem) -> void:
	if box == null or tr == null:
		return

	# Background = rarity color (or muted if none)
	var bg := COL_TEXT_MUTED
	if item != null:
		bg = _rarity_color(item)
	bg.a = 1.0

	# Apply style without recreating styleboxes
	var sb: Variant = box.get_meta("sb") if box.has_meta("sb") else null
	if sb is StyleBoxFlat:
		var st := sb as StyleBoxFlat
		st.bg_color = bg
		# Slightly deepen border based on bg so it reads well
		st.border_color = COL_BORDER if item == null else bg.darkened(0.35)

	tr.texture = _gear_icon_texture(item)

func _gear_icon_texture(item: GearItem) -> Texture2D:
	# Empty item: still try to show slot icon if we know the slot.
	if item == null:
		if _context_slot_id != -1:
			var k0 := _slot_icon_key_from_slot_id(_context_slot_id)
			var p0 := "%s/%s.png" % [GEAR_ICON_DIR, k0]
			if ResourceLoader.exists(p0):
				var t0 := load(p0)
				if t0 is Texture2D:
					return t0 as Texture2D
		return GEAR_ICON_DEFAULT

	# 1) Direct texture hook (if you add it later)
	if item.has_method("icon_texture"):
		var t: Variant = item.call("icon_texture")
		if t is Texture2D:
			return t as Texture2D

	# 2) Your existing string-field probing
	var key := ""
	var candidates := [
		"gear_icon", "icon_id", "icon_key", "icon", "slot", "slot_id",
		"gear_slot", "gear_type", "type", "category", "equip_slot"
	]
	for c in candidates:
		key = _get_string_field(item, c)
		if key != "":
			break

	key = _normalize_icon_key(key)

	# If the “key” is numeric (like slot id), translate it.
	if key != "" and key.is_valid_int():
		key = _slot_icon_key_from_slot_id(int(key))

	# 3) Slot-based fallback (fixes your default-icon issue)
	if key == "" and _context_slot_id != -1:
		key = _slot_icon_key_from_slot_id(_context_slot_id)

	if key != "":
		var p := "%s/%s.png" % [GEAR_ICON_DIR, key]
		if ResourceLoader.exists(p):
			var tex := load(p)
			if tex is Texture2D:
				return tex as Texture2D

	return GEAR_ICON_DEFAULT

func _normalize_icon_key(s: String) -> String:
	var out := s.strip_edges().to_lower()
	if out == "":
		return ""
	out = out.replace(" ", "_").replace("-", "_")
	return out

func _gear_slot_id_from_item(item: GearItem) -> int:
	if item == null or not item.has_method("get"):
		return -1

	var keys := ["slot_id", "gear_slot_id", "gear_slot", "equip_slot", "slot"]
	for k in keys:
		var v: Variant = item.get(k)
		if v == null:
			continue

		if typeof(v) == TYPE_INT:
			return int(v)

		if v is String or v is StringName:
			var s := String(v)
			if s.is_valid_int():
				return int(s)

			# Match by name against Catalog.GEAR_SLOT_NAMES
			var sn := _normalize_icon_key(s)
			for sid in Catalog.GEAR_SLOT_NAMES.keys():
				if _normalize_icon_key(String(Catalog.GEAR_SLOT_NAMES[sid])) == sn:
					return int(sid)

	return -1

func _gear_icon_key_from_item(item: GearItem) -> String:
	if item == null:
		return ""

	# 1) Explicit fields (best)
	var explicit := ["gear_icon", "icon_key", "icon_id", "icon"]
	for f in explicit:
		var k := _normalize_icon_key(_get_string_field(item, f))
		if k != "" and ResourceLoader.exists("%s/%s.png" % [GEAR_ICON_DIR, k]):
			return k

	# 2) Slot-based fallback (this fixes your “equipped uses default icon” bug)
	var sid := _gear_slot_id_from_item(item)
	if sid != -1:
		var slot_name := String(Catalog.GEAR_SLOT_NAMES.get(sid, ""))
		var k2 := _normalize_icon_key(slot_name)
		if k2 != "" and ResourceLoader.exists("%s/%s.png" % [GEAR_ICON_DIR, k2]):
			return k2

	# 3) Other fuzzy fields (optional)
	var other := ["type", "category"]
	for f in other:
		var k3 := _normalize_icon_key(_get_string_field(item, f))
		if k3 != "" and ResourceLoader.exists("%s/%s.png" % [GEAR_ICON_DIR, k3]):
			return k3

	return ""

func _slot_icon_key_from_slot_id(slot_id: int) -> String:
	if SLOT_ICON_KEYS.has(slot_id):
		return String(SLOT_ICON_KEYS[slot_id])

	var slot_name := String(Catalog.GEAR_SLOT_NAMES.get(slot_id, ""))
	return _normalize_icon_key(slot_name)
