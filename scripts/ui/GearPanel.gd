extends HBoxContainer

signal slot_clicked(slot_id: int, item: GearItem)

@onready var gear_grid: GridContainer = $GearGridPanel/GearGrid
@onready var open_gear_button: Button = $GearPanelArea/GearVBox/OpenGearButton
@onready var gear_panel_label: Label = $GearPanelArea/GearVBox/GearPanelLabel

var _slot_buttons: Array[BaseButton] = []

const GEAR_ICON_DIR := "res://assets/icons/UI/gear"
const GEAR_ICON_FALLBACK: Texture2D = preload("res://assets/icons/UI/gear/default_icon.png")

const GEAR_ICON_BOX_SIZE := 44.0
const GEAR_ICON_BOX_PAD_X := 8.0
const GEAR_ICON_BG_PAD := 4.0

var _gear_icon_cache: Dictionary = {} # key -> Texture2D

const GEAR_ICON_DEFAULT: Texture2D = preload("res://assets/icons/UI/gear/default_icon.png")
const ICON_BG_NODE_NAME := "IconBG"

# File keys expected in res://assets/icons/UI/gear/<key>.png
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


# Your desired order
const SLOT_ORDER: Array[int] = [
	Catalog.GearSlot.WEAPON,
	Catalog.GearSlot.HELMET,
	Catalog.GearSlot.SHOULDERS,
	Catalog.GearSlot.CHEST,
	Catalog.GearSlot.GLOVES,
	Catalog.GearSlot.BELT,
	Catalog.GearSlot.LEGS,
	Catalog.GearSlot.BOOTS,
	Catalog.GearSlot.RING,
	Catalog.GearSlot.BRACELET,
	Catalog.GearSlot.MOUNT,     # future
	Catalog.GearSlot.ARTIFACT,  # future
]

var _legendary_id_cache: int = -2 # -2 = unknown, -1 = not found


func _ready() -> void:
	_slot_buttons.clear()
	for child in gear_grid.get_children():
		if child is BaseButton:
			_slot_buttons.append(child)
			
	for btn in _slot_buttons:
		_ensure_icon_box(btn)

	# Connect slot taps once
	for btn in _slot_buttons:
		btn.pressed.connect(func() -> void:
			_on_slot_pressed(btn)
		)

	open_gear_button.pressed.connect(_on_open_gear_pressed)

	Game.player_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	gear_panel_label.text = "Gear Panel"

	for i in range(_slot_buttons.size()):
		var btn := _slot_buttons[i]

		if i >= SLOT_ORDER.size():
			btn.visible = false
			continue

		btn.visible = true

		var slot_id: int = SLOT_ORDER[i]
		btn.set_meta("gear_slot_id", slot_id)

		var slot_name: String = String(Catalog.GEAR_SLOT_NAMES.get(slot_id, "Slot"))
		var item: GearItem = Game.player.equipped.get(slot_id, null)

		_apply_slot_visuals(btn, slot_name, item, slot_id)

func _apply_slot_visuals(btn: BaseButton, slot_name: String, item: GearItem, slot_id: int) -> void:
	var rarity_frame := btn.get_node_or_null("RarityFrame") as TextureRect
	var level_label := btn.get_node_or_null("LevelLabel") as Label
	var name_label := btn.get_node_or_null("Label") as Label
	var icon := btn.get_node_or_null("Icon") as TextureRect
	var icon_bg := btn.get_node_or_null("IconBG") as Panel

	var is_future: bool = (slot_id == Catalog.GearSlot.MOUNT or slot_id == Catalog.GearSlot.ARTIFACT)

	# Always ensure sizing/clipping so icons can’t explode.
	_ensure_icon_box(btn)

	# Always show a slot icon (even if empty), like LoM.
	if icon:
		icon.texture = _load_slot_icon(slot_name)

	# Future slots: disabled + greyed
	if is_future:
		btn.disabled = true
		if name_label: name_label.text = slot_name
		if level_label: level_label.text = "Soon"
		if rarity_frame:
			rarity_frame.visible = true
			rarity_frame.modulate = Color(0.5, 0.5, 0.5, 1.0)
		if icon:
			icon.modulate = Color(1, 1, 1, 0.35)
		if icon_bg:
			icon_bg.visible = true
			var sbf := icon_bg.get_theme_stylebox("panel") as StyleBoxFlat
			if sbf:
				sbf = sbf.duplicate(true) as StyleBoxFlat
				sbf.bg_color = Color(0.25, 0.25, 0.25, 0.55)
				icon_bg.add_theme_stylebox_override("panel", sbf)

		btn.tooltip_text = "%s (Coming Soon)" % slot_name
		return

	btn.disabled = false

	# Empty slot: no rarity background, dim icon
	if item == null:
		if name_label: name_label.text = slot_name
		if level_label: level_label.text = ""
		if rarity_frame: rarity_frame.visible = false
		if icon:
			icon.modulate = Color(1, 1, 1, 0.40)
		if icon_bg:
			icon_bg.visible = false

		btn.tooltip_text = "Empty: %s" % slot_name
		_set_bg_border(btn, Color.WHITE, false, false)
		return

	# Equipped item: rarity background behind icon + normal alpha
	if name_label: name_label.text = slot_name
	if level_label: level_label.text = "Lv.%d" % item.item_level
	if icon:
		icon.modulate = Color(1, 1, 1, 1)

	var c: Color = Catalog.RARITY_COLORS.get(item.rarity, Color.WHITE)

	if icon_bg:
		icon_bg.visible = true
		var sb := icon_bg.get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			sb = sb.duplicate(true) as StyleBoxFlat
			# Slightly softened rarity fill (reads nicer behind icon)
			sb.bg_color = Color(c.r, c.g, c.b, 0.85)
			sb.border_color = Color(0, 0, 0, 0.35)
			icon_bg.add_theme_stylebox_override("panel", sb)

	if rarity_frame:
		# If you still want this, keep it; otherwise you can hide it now.
		rarity_frame.visible = true
		rarity_frame.modulate = c

	btn.tooltip_text = "%s (%s) Lv.%d" % [
		item.display_name(),
		String(Catalog.RARITY_NAMES.get(item.rarity, "")),
		item.item_level
	]

	var pulse: bool = bool(Catalog.RARITY_PULSE.get(item.rarity, false))
	_set_bg_border(btn, c, true, pulse)

func _on_slot_pressed(btn: BaseButton) -> void:
	var slot_id: int = int(btn.get_meta("gear_slot_id", -1))
	if slot_id == -1:
		return

	var item: GearItem = Game.player.equipped.get(slot_id, null)
	emit_signal("slot_clicked", slot_id, item)

func _on_open_gear_pressed() -> void:
	print("Open Gear pressed (todo: open full gear screen / drawer)")

func _set_bg_border(btn: BaseButton, color: Color, enabled: bool, pulse: bool = false) -> void:

	var bg := btn.get_node_or_null("BG") as Panel
	if bg == null:
		return

	var base_sb: StyleBox = bg.get_theme_stylebox("panel")
	var sb: StyleBoxFlat

	if base_sb != null and base_sb is StyleBoxFlat:
		sb = (base_sb as StyleBoxFlat).duplicate(true) as StyleBoxFlat
	else:
		sb = StyleBoxFlat.new()
		sb.bg_color = Color(0.15, 0.15, 0.15, 1.0)
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8

	# Store the stylebox so the tween can modify it
	bg.set_meta("sb_flat", sb)

	if enabled:
		# Thicker border
		var w := 4
		sb.border_width_left = w
		sb.border_width_top = w
		sb.border_width_right = w
		sb.border_width_bottom = w
		sb.border_color = color

		# Glow via shadow
		sb.shadow_size = 12
		sb.shadow_offset = Vector2.ZERO

		# If pulsing, tween the shadow alpha; otherwise set a fixed glow.
		bg.set_meta("glow_color", color)
		if pulse:
			_start_glow_pulse(bg, color)
		else:
			_stop_glow_pulse(bg)
			_set_glow_alpha(bg, 0.55)

	else:
		sb.border_width_left = 0
		sb.border_width_top = 0
		sb.border_width_right = 0
		sb.border_width_bottom = 0

		sb.shadow_size = 0
		sb.shadow_offset = Vector2.ZERO

		_stop_glow_pulse(bg)

	bg.add_theme_stylebox_override("panel", sb)

func _legendary_rarity_id() -> int:
	if _legendary_id_cache != -2:
		return _legendary_id_cache

	_legendary_id_cache = -1
	for k in Catalog.RARITY_NAMES.keys():
		if String(Catalog.RARITY_NAMES[k]).to_lower() == "legendary":
			_legendary_id_cache = int(k)
			break
	return _legendary_id_cache

func _stop_glow_pulse(bg: Panel) -> void:
	var tw: Tween = bg.get_meta("glow_tween", null)
	if tw != null:
		tw.kill()
	bg.set_meta("glow_tween", null)
	bg.set_meta("glow_key", "")

func _set_glow_alpha(bg: Panel, alpha: float) -> void:
	var sb: StyleBoxFlat = bg.get_meta("sb_flat", null)
	if sb == null:
		return
	var base_color: Color = bg.get_meta("glow_color", Color.WHITE)
	var glow := base_color
	glow.a = alpha
	sb.shadow_color = glow
	bg.add_theme_stylebox_override("panel", sb)

func _start_glow_pulse(bg: Panel, base_color: Color) -> void:
	var key := base_color.to_html(false)
	var existing_key: String = bg.get_meta("glow_key", "")
	var tw: Tween = bg.get_meta("glow_tween", null)

	# If already pulsing with same color, do nothing.
	if tw != null and tw.is_running() and existing_key == key:
		return

	_stop_glow_pulse(bg)

	bg.set_meta("glow_color", base_color)
	bg.set_meta("glow_key", key)

	# Two-phase pulse (up then down), looping
	var t := create_tween()
	t.set_loops()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_method(_set_glow_alpha.bind(bg), 0.25, 0.70, 0.55)
	t.tween_method(_set_glow_alpha.bind(bg), 0.70, 0.25, 0.55)

	bg.set_meta("glow_tween", t)

func _load_gear_icon_for_slot(slot_id: int) -> Texture2D:
	var key: String = String(SLOT_ICON_KEYS.get(slot_id, ""))
	if key == "":
		return GEAR_ICON_DEFAULT

	var p := "%s/%s.png" % [GEAR_ICON_DIR, key]
	if ResourceLoader.exists(p):
		var t := load(p)
		if t is Texture2D:
			return t as Texture2D

	return GEAR_ICON_DEFAULT

func _ensure_icon_bg(btn: BaseButton, icon: TextureRect) -> Panel:
	if btn == null or icon == null:
		return null

	var bg := btn.get_node_or_null(ICON_BG_NODE_NAME) as Panel
	if bg != null:
		return bg

	bg = Panel.new()
	bg.name = ICON_BG_NODE_NAME
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Match the Icon's anchors/offsets so it sits exactly behind it.
	bg.anchor_left = icon.anchor_left
	bg.anchor_top = icon.anchor_top
	bg.anchor_right = icon.anchor_right
	bg.anchor_bottom = icon.anchor_bottom
	bg.offset_left = icon.offset_left
	bg.offset_top = icon.offset_top
	bg.offset_right = icon.offset_right
	bg.offset_bottom = icon.offset_bottom

	# Stylebox stored once and mutated later
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.set_border_width_all(2)
	sb.border_color = Color(0, 0, 0, 0.35)
	sb.bg_color = Color(0, 0, 0, 0.12)
	bg.add_theme_stylebox_override("panel", sb)
	bg.set_meta("sb_flat", sb)

	btn.add_child(bg)
	btn.move_child(bg, icon.get_index()) # ensure bg is behind icon

	return bg

func _set_icon_bg_color(bg: Panel, c: Color) -> void:
	if bg == null:
		return
	var sb: StyleBoxFlat = bg.get_meta("sb_flat", null)
	if sb == null:
		return

	# Strong rarity background like LoM, but keep border readable
	var fill := c
	fill.a = 1.0
	sb.bg_color = fill
	sb.border_color = fill.darkened(0.35)

	bg.add_theme_stylebox_override("panel", sb)

func _slot_icon_key(slot_name: String) -> String:
	# "Atk Spd" -> "atk_spd" etc.
	var k := slot_name.strip_edges().to_lower()
	k = k.replace(" ", "_")
	k = k.replace("-", "_")
	return k

func _load_slot_icon(slot_name: String) -> Texture2D:
	var key := _slot_icon_key(slot_name)
	if _gear_icon_cache.has(key):
		return _gear_icon_cache[key]

	var path := "%s/%s.png" % [GEAR_ICON_DIR, key]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		tex = GEAR_ICON_FALLBACK

	_gear_icon_cache[key] = tex
	return tex

func _ensure_icon_box(btn: BaseButton) -> void:
	# Make sure children cannot draw outside the slot button.
	if btn is Control:
		(btn as Control).clip_contents = true

	var icon := btn.get_node_or_null("Icon") as TextureRect
	if icon == null:
		return

	# Clamp icon rendering (prevents “texture decides min size” issues).
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(GEAR_ICON_BOX_SIZE, GEAR_ICON_BOX_SIZE)

	# Force an explicit rect for the icon box (left side, vertically centered).
	icon.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	icon.offset_left = GEAR_ICON_BOX_PAD_X
	icon.offset_right = GEAR_ICON_BOX_PAD_X + GEAR_ICON_BOX_SIZE
	icon.offset_top = -GEAR_ICON_BOX_SIZE * 0.5
	icon.offset_bottom =  GEAR_ICON_BOX_SIZE * 0.5

	# Create / configure IconBG behind the icon.
	var icon_bg := btn.get_node_or_null("IconBG") as Panel
	if icon_bg == null:
		icon_bg = Panel.new()
		icon_bg.name = "IconBG"
		icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon_bg)
		# Keep it behind the Icon
		btn.move_child(icon_bg, icon.get_index())

	icon_bg.clip_contents = true
	icon_bg.set_anchors_preset(Control.PRESET_CENTER_LEFT)

	var bg_w := GEAR_ICON_BOX_SIZE + (GEAR_ICON_BG_PAD * 2.0)
	var bg_h := GEAR_ICON_BOX_SIZE + (GEAR_ICON_BG_PAD * 2.0)

	icon_bg.offset_left = max(0.0, GEAR_ICON_BOX_PAD_X - GEAR_ICON_BG_PAD)
	icon_bg.offset_right = icon_bg.offset_left + bg_w
	icon_bg.offset_top = -bg_h * 0.5
	icon_bg.offset_bottom = bg_h * 0.5

	# Default style (will be recolored per-item)
	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.set_border_width_all(2)
	sb.border_color = Color(0, 0, 0, 0.35)
	sb.bg_color = Color(0, 0, 0, 0.0)
	icon_bg.add_theme_stylebox_override("panel", sb)
