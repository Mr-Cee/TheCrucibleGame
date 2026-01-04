extends HBoxContainer

signal slot_clicked(slot_id: int, item: GearItem)

@onready var gear_grid: GridContainer = $GearGridPanel/GearGrid
@onready var open_gear_button: Button = $GearPanelArea/GearVBox/OpenGearButton
@onready var gear_panel_label: Label = $GearPanelArea/GearVBox/GearPanelLabel

var _slot_buttons: Array[BaseButton] = []

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
	# Expected children on each SlotButton:
	# BG (Panel) - optional, used for visible slot frame
	# Icon (TextureRect)
	# RarityFrame (TextureRect)
	# LevelLabel (Label)
	# Label (Label)

	var rarity_frame := btn.get_node_or_null("RarityFrame") as TextureRect
	var level_label := btn.get_node_or_null("LevelLabel") as Label
	var name_label := btn.get_node_or_null("Label") as Label
	var icon := btn.get_node_or_null("Icon") as TextureRect

	var is_future: bool = (slot_id == Catalog.GearSlot.MOUNT or slot_id == Catalog.GearSlot.ARTIFACT)

	# Future slots: visible but disabled
	if is_future:
		btn.disabled = true
		if name_label: name_label.text = slot_name
		if level_label: level_label.text = "Soon"
		if rarity_frame:
			rarity_frame.visible = true
			rarity_frame.modulate = Color(0.5, 0.5, 0.5, 1.0)
		if icon: icon.texture = null
		btn.tooltip_text = "%s (Coming Soon)" % slot_name
		return
	else:
		btn.disabled = false

	if item == null:
		if name_label: name_label.text = slot_name
		if level_label: level_label.text = ""
		if rarity_frame: rarity_frame.visible = false
		if icon: icon.texture = null
		btn.tooltip_text = "Empty: %s" % slot_name
		_set_bg_border(btn, Color.WHITE, false, false)

		return

	# Equipped item
	if name_label: name_label.text = slot_name
	if level_label: level_label.text = "Lv.%d" % item.item_level
	if rarity_frame:
		rarity_frame.visible = true
		rarity_frame.modulate = Catalog.RARITY_COLORS.get(item.rarity, Color.WHITE)
	# Icon remains blank until you have art
	btn.tooltip_text = "%s (%s) Lv.%d" % [
		item.display_name(),
		String(Catalog.RARITY_NAMES.get(item.rarity, "")),
		item.item_level
	]
	var c: Color = Catalog.RARITY_COLORS.get(item.rarity, Color.WHITE)
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
