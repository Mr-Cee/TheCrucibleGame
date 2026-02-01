extends Control
class_name CrucibleUpgradePanel

signal closed

# -------------------- Tunables --------------------
const SHELL_W := 620
const SHELL_H := 860

# -------------------- Palette (LoM-ish parchment) --------------------
const COL_DIM := Color(0, 0, 0, 0.55)

const COL_SHELL_BG := Color(0.94, 0.91, 0.82, 1.0)
const COL_BORDER   := Color(0.55, 0.46, 0.32, 1.0)
const COL_LINE     := Color(0.78, 0.69, 0.52, 1.0)

const COL_CARD_BG     := Color(0.98, 0.97, 0.93, 1.0)
const COL_CARD_BORDER := Color(0.70, 0.60, 0.44, 1.0)

const COL_TEXT_DARK  := Color(0.18, 0.14, 0.10, 1.0)
const COL_TEXT_MUTED := Color(0.38, 0.32, 0.26, 1.0)

const COL_BTN_GREEN_BG := Color(0.26, 0.62, 0.31, 1.0)
const COL_BTN_GREEN_BR := Color(0.15, 0.40, 0.18, 1.0)

const COL_BTN_GRAY_BG := Color(0.65, 0.64, 0.60, 1.0)
const COL_BTN_GRAY_BR := Color(0.45, 0.42, 0.36, 1.0)

const COL_BTN_CLOSE_BG := Color(0.80, 0.74, 0.60, 1.0)
const COL_BTN_CLOSE_BR := Color(0.55, 0.46, 0.32, 1.0)

const COL_PROGRESS_BG := Color(0.82, 0.78, 0.70, 1.0)

# Icons
const PATH_ICON_GOLD := "res://assets/icons/UI/currency/gold.png"
const PATH_ICON_VOUCHER := "res://assets/icons/UI/currency/time_ticket.png" # fallback if you don't have a voucher icon

# -------------------- Nodes --------------------
var _shell: PanelContainer
var _title_lbl: Label
#var _btn_x_top: Button

var _gold_lbl: Label
var _vouchers_lbl: Label

var _lvl_lbl: Label

var _upgrade_progress: ProgressBar
var _time_lbl: Label
var _btn_use_vouchers: Button

var _odds_header: Label
var _odds_rows_vbox: VBoxContainer
var _odds_curr_labels: Dictionary = {}
var _odds_next_labels: Dictionary = {}

var _payment_bar: HBoxContainer
var _payment_segments: Array[Panel] = []

var _purchase_btn: Button
var _upgrade_btn: Button
var _btn_x_bottom: Button

var _ui_timer: Timer


# ======================================================================================

func _ready() -> void:
	name = "CrucibleUpgradePanel"
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
	
	# Close when clicking outside the panel
	dim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close()
	)

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
	root.add_theme_constant_override("separation", 10)
	_shell.add_child(root)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	_title_lbl = Label.new()
	_title_lbl.text = "Crucible Upgrade"
	_title_lbl.modulate = COL_TEXT_DARK
	_title_lbl.add_theme_font_size_override("font_size", 24)
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_title_lbl)

	root.add_child(_make_hr())

	# Currency row (gold + vouchers)
	var cur_card := _make_card()
	root.add_child(cur_card)
	var cur_inner := cur_card.get_node("InnerMargin/Inner") as VBoxContainer

	var cur_row := HBoxContainer.new()
	cur_row.add_theme_constant_override("separation", 18)
	cur_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cur_inner.add_child(cur_row)

	var gold_box := _make_icon_stat(_safe_load_tex(PATH_ICON_GOLD), "0")
	_gold_lbl = gold_box["label"]
	cur_row.add_child(_wrap_currency_chip(gold_box["node"]))

	var v_box := _make_icon_stat(_safe_load_tex(PATH_ICON_VOUCHER), "0")
	_vouchers_lbl = v_box["label"]
	cur_row.add_child(_wrap_currency_chip(v_box["node"]))


	# Level row (Current -> Next)
	var lvl_card := _make_card()
	root.add_child(lvl_card)
	var lvl_inner := lvl_card.get_node("InnerMargin/Inner") as VBoxContainer

	_lvl_lbl = Label.new()
	_lvl_lbl.text = "Current Level: 1  »»  Next Level: 2"
	_lvl_lbl.modulate = COL_TEXT_DARK
	_lvl_lbl.add_theme_font_size_override("font_size", 18)
	_lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_inner.add_child(_lvl_lbl)

	# Upgrade progress area (only visible while upgrading)
	_upgrade_progress = ProgressBar.new()
	_upgrade_progress.visible = false
	_upgrade_progress.custom_minimum_size = Vector2(0, 18)
	_upgrade_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lvl_inner.add_child(_upgrade_progress)
	_style_progressbar(_upgrade_progress)

	_time_lbl = Label.new()
	_time_lbl.visible = false
	_time_lbl.text = "Time remaining: 0s"
	_time_lbl.modulate = COL_TEXT_MUTED
	_time_lbl.add_theme_font_size_override("font_size", 14)
	_time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lvl_inner.add_child(_time_lbl)

	_btn_use_vouchers = Button.new()
	_btn_use_vouchers.visible = false
	_btn_use_vouchers.text = "Use Time Vouchers"
	_btn_use_vouchers.custom_minimum_size = Vector2(0, 44)
	_btn_use_vouchers.pressed.connect(_on_use_voucher_pressed)
	lvl_inner.add_child(_btn_use_vouchers)
	_style_action_button(_btn_use_vouchers, COL_BTN_CLOSE_BG, COL_BTN_CLOSE_BR, COL_TEXT_DARK, 18)

	# Odds header
	_odds_header = Label.new()
	_odds_header.text = "Odds"
	_odds_header.modulate = COL_TEXT_DARK
	_odds_header.add_theme_font_size_override("font_size", 18)
	_odds_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_odds_header)

	# Odds list (scroll)
	var odds_card := _make_card()
	root.add_child(odds_card)
	var odds_inner := odds_card.get_node("InnerMargin/Inner") as VBoxContainer
	odds_inner.add_theme_constant_override("separation", 8)

	var odds_header_row := HBoxContainer.new()
	odds_header_row.add_theme_constant_override("separation", 10)
	odds_inner.add_child(odds_header_row)

	var h_name := Label.new()
	h_name.text = ""
	h_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	odds_header_row.add_child(h_name)

	var h_cur := Label.new()
	h_cur.text = "Current"
	h_cur.modulate = COL_TEXT_MUTED
	h_cur.add_theme_font_size_override("font_size", 14)
	h_cur.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_cur.custom_minimum_size = Vector2(120, 0)
	odds_header_row.add_child(h_cur)

	var h_next := Label.new()
	h_next.text = "Next"
	h_next.modulate = COL_TEXT_MUTED
	h_next.add_theme_font_size_override("font_size", 14)
	h_next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_next.custom_minimum_size = Vector2(120, 0)
	odds_header_row.add_child(h_next)

	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, 360)
	odds_inner.add_child(sc)

	_odds_rows_vbox = VBoxContainer.new()
	_odds_rows_vbox.add_theme_constant_override("separation", 8)
	_odds_rows_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_odds_rows_vbox)

	_build_odds_rows()

	# Payment + Purchase section
	root.add_child(_make_hr())

	var pay_wrap := VBoxContainer.new()
	pay_wrap.add_theme_constant_override("separation", 8)
	root.add_child(pay_wrap)

	var pay_title := Label.new()
	pay_title.text = "Upgrade to get advanced gears"
	pay_title.modulate = COL_TEXT_MUTED
	pay_title.add_theme_font_size_override("font_size", 14)
	pay_wrap.add_child(pay_title)

	var pay_row := HBoxContainer.new()
	pay_row.add_theme_constant_override("separation", 12)
	pay_wrap.add_child(pay_row)

	_payment_bar = HBoxContainer.new()
	_payment_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_payment_bar.custom_minimum_size = Vector2(0, 16)
	_payment_bar.add_theme_constant_override("separation", 6)
	pay_row.add_child(_payment_bar)

	_purchase_btn = Button.new()
	_purchase_btn.text = "Purchase"
	_purchase_btn.custom_minimum_size = Vector2(210, 56)
	_purchase_btn.pressed.connect(_on_purchase_pressed)
	pay_row.add_child(_purchase_btn)
	_style_action_button(_purchase_btn, COL_BTN_GREEN_BG, COL_BTN_GREEN_BR, Color(0.98, 0.97, 0.93, 1.0), 20)

	# Big Upgrade button
	_upgrade_btn = Button.new()
	_upgrade_btn.text = "Upgrade"
	_upgrade_btn.custom_minimum_size = Vector2(0, 64)
	_upgrade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	root.add_child(_upgrade_btn)
	_style_action_button(_upgrade_btn, COL_BTN_GRAY_BG, COL_BTN_GRAY_BR, Color(0.98, 0.97, 0.93, 1.0), 22)

	# Bottom center close X (like screenshot)
	_btn_x_bottom = Button.new()
	_btn_x_bottom.text = "X"
	_btn_x_bottom.custom_minimum_size = Vector2(72, 56)
	_btn_x_bottom.pressed.connect(_close)
	root.add_child(_btn_x_bottom)
	_style_action_button(_btn_x_bottom, COL_BTN_CLOSE_BG, COL_BTN_CLOSE_BR, COL_TEXT_DARK, 22)

	# Timer refresh
	_ui_timer = Timer.new()
	_ui_timer.wait_time = 0.5
	_ui_timer.one_shot = false
	_ui_timer.timeout.connect(_refresh)
	add_child(_ui_timer)
	_ui_timer.start()

	# Auto refresh on player change
	if Game != null and not Game.player_changed.is_connected(_refresh):
		Game.player_changed.connect(_refresh)

	_refresh()

func popup_and_refresh() -> void:
	_refresh()

func _exit_tree() -> void:
	if _ui_timer != null:
		_ui_timer.stop()

# ======================================================================================
# Actions
# ======================================================================================

func _close() -> void:
	emit_signal("closed")
	queue_free()

func _on_purchase_pressed() -> void:
	if Game == null or Game.player == null:
		return
	if Game.crucible_is_upgrading():
		return
	Game.crucible_pay_one_upgrade_stage()
	_refresh()

func _on_upgrade_pressed() -> void:
	if Game == null or Game.player == null:
		return
	if Game.crucible_is_upgrading():
		return

	var lvl: int = int(Game.player.crucible_level)
	var req: int = int(Game.crucible_required_payment_stages(lvl))
	var paid: int = int(Game.player.crucible_upgrade_paid_stages)

	if paid < req:
		# Not ready yet
		Game.inventory_event.emit("Pay all stages before upgrading.")
		_refresh()
		return

	Game.crucible_start_upgrade_timer()
	_refresh()

func _on_use_voucher_pressed() -> void:
	var home := get_tree().current_scene
	if home != null and home.has_method("open_voucher_popup"):
		home.call("open_voucher_popup")

# ======================================================================================
# Refresh
# ======================================================================================

func _refresh() -> void:
	if Game == null or Game.player == null:
		return

	# Apply completion if timer finished while UI was closed
	Game.crucible_tick_upgrade_completion()

	# Currency display
	_gold_lbl.text = _fmt_compact_number(int(Game.player.gold))
	_vouchers_lbl.text = str(int(Game.player.time_vouchers))

	# Levels
	var cur_level: int = int(Game.player.crucible_level)
	var next_level: int = cur_level + 1
	if Game.crucible_is_upgrading():
		next_level = int(Game.player.crucible_upgrade_target_level)

	_lvl_lbl.text = "Current Level:%d  »»  Next Level:%d" % [cur_level, next_level]
	_odds_header.text = "Odds (Lv.%d → Lv.%d)" % [cur_level, next_level]

	_refresh_odds(cur_level, next_level)

	# Payment segments + buttons
	var req: int = int(Game.crucible_required_payment_stages(cur_level))
	var paid: int = int(Game.player.crucible_upgrade_paid_stages)

	_ensure_payment_segments(req)
	_set_payment_segments_filled(paid, req)

	# Upgrading state
	if Game.crucible_is_upgrading():
		var remaining: int = int(Game.crucible_upgrade_seconds_remaining())
		var total: int = max(1, int(Game.crucible_upgrade_time_seconds(cur_level)))
		var elapsed: int = clampi(total - remaining, 0, total)

		_upgrade_progress.visible = true
		_time_lbl.visible = true
		_upgrade_progress.min_value = 0
		_upgrade_progress.max_value = total
		_upgrade_progress.value = elapsed
		_time_lbl.text = "Time remaining: %s" % _fmt_time(remaining)

		_btn_use_vouchers.visible = true
		_btn_use_vouchers.disabled = (int(Game.player.time_vouchers) <= 0)

		_purchase_btn.disabled = true
		_purchase_btn.text = "Upgrading..."
		_upgrade_btn.disabled = true
		_upgrade_btn.text = "Upgrading..."
		return

	# Not upgrading
	_upgrade_progress.visible = false
	_time_lbl.visible = false
	_btn_use_vouchers.visible = false

	_upgrade_btn.text = "Upgrade"

	if paid < req:
		var cost: int = int(Game.crucible_stage_cost_gold(cur_level, paid))
		_purchase_btn.disabled = false
		_purchase_btn.text = "Purchase\n%s" % _fmt_compact_number(cost)
		_upgrade_btn.disabled = true
	else:
		_purchase_btn.disabled = true
		_purchase_btn.text = "Paid"
		_upgrade_btn.disabled = false

# ======================================================================================
# Odds Rows
# ======================================================================================

func _build_odds_rows() -> void:
	for c in _odds_rows_vbox.get_children():
		c.queue_free()

	_odds_curr_labels.clear()
	_odds_next_labels.clear()

	for rarity in Catalog.RARITY_DISPLAY_ORDER:
		var row := _make_rarity_row(int(rarity))
		_odds_rows_vbox.add_child(row)

func _make_rarity_row(rarity: int) -> Control:
	var color: Color = Catalog.RARITY_COLORS.get(rarity, Color.WHITE)
	var rarity_name: String = String(Catalog.RARITY_NAMES.get(rarity, "Rarity"))

	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.custom_minimum_size = Vector2(0, 34)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, 0.20)
	sb.set_border_width_all(2)
	sb.border_color = Color(color.r, color.g, color.b, 0.65)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	pc.add_child(h)

	var name_lbl := Label.new()
	name_lbl.text = rarity_name
	name_lbl.modulate = COL_TEXT_DARK
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(name_lbl)

	var curr_lbl := Label.new()
	curr_lbl.text = "0%"
	curr_lbl.modulate = COL_TEXT_DARK
	curr_lbl.add_theme_font_size_override("font_size", 14)
	curr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	curr_lbl.custom_minimum_size = Vector2(120, 0)
	h.add_child(curr_lbl)

	var next_lbl := Label.new()
	next_lbl.text = "0%"
	next_lbl.modulate = COL_TEXT_DARK
	next_lbl.add_theme_font_size_override("font_size", 14)
	next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_lbl.custom_minimum_size = Vector2(120, 0)
	h.add_child(next_lbl)

	_odds_curr_labels[rarity] = curr_lbl
	_odds_next_labels[rarity] = next_lbl

	return pc

func _refresh_odds(cur_level: int, next_level: int) -> void:
	var cur_odds: Dictionary = Catalog.crucible_rarity_odds(cur_level)
	var next_odds: Dictionary = Catalog.crucible_rarity_odds(next_level)

	for rarity in Catalog.RARITY_DISPLAY_ORDER:
		var unlock: int = int(Catalog.crucible_rarity_unlock_level(int(rarity)))

		var curr_lbl := _odds_curr_labels.get(int(rarity), null) as Label
		var next_lbl := _odds_next_labels.get(int(rarity), null) as Label

		var curr_locked := cur_level < unlock
		var next_locked := next_level < unlock

		if curr_lbl != null:
			if curr_locked:
				curr_lbl.text = "Locked"
				curr_lbl.modulate = Color(0.55, 0.55, 0.55, 1.0)
			else:
				var p: float = float(cur_odds.get(int(rarity), 0.0)) * 100.0
				curr_lbl.text = "%.2f%%" % p
				curr_lbl.modulate = COL_TEXT_DARK

		if next_lbl != null:
			if next_locked:
				next_lbl.text = "Locked"
				next_lbl.modulate = Color(0.55, 0.55, 0.55, 1.0)
			else:
				var p2: float = float(next_odds.get(int(rarity), 0.0)) * 100.0
				next_lbl.text = "%.2f%%" % p2
				next_lbl.modulate = COL_TEXT_DARK

# ======================================================================================
# Payment segments
# ======================================================================================

func _ensure_payment_segments(required: int) -> void:
	if _payment_segments.size() == required:
		return

	for c in _payment_bar.get_children():
		c.queue_free()
	_payment_segments.clear()

	for i in range(required):
		var seg := Panel.new()
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.custom_minimum_size = Vector2(0, 14)

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.55, 0.52, 0.46, 1.0) # unfilled
		sb.set_border_width_all(1)
		sb.border_color = Color(0.35, 0.32, 0.28, 1.0)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		seg.add_theme_stylebox_override("panel", sb)

		_payment_bar.add_child(seg)
		_payment_segments.append(seg)

func _set_payment_segments_filled(filled: int, required: int) -> void:
	filled = clampi(filled, 0, required)

	for i in range(required):
		var seg := _payment_segments[i]
		var sb := seg.get_theme_stylebox("panel") as StyleBoxFlat
		if sb == null:
			continue
		var sb2 := sb.duplicate(true) as StyleBoxFlat

		if i < filled:
			sb2.bg_color = Color(0.28, 0.68, 0.34, 1.0)
			sb2.border_color = Color(0.16, 0.40, 0.20, 1.0)
		else:
			sb2.bg_color = Color(0.55, 0.52, 0.46, 1.0)
			sb2.border_color = Color(0.35, 0.32, 0.28, 1.0)

		seg.add_theme_stylebox_override("panel", sb2)

# ======================================================================================
# UI helpers
# ======================================================================================

func _make_card() -> PanelContainer:
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

func _make_hr() -> Control:
	var r := ColorRect.new()
	r.color = COL_LINE
	r.custom_minimum_size = Vector2(0, 2)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _safe_load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t := load(path)
		if t is Texture2D:
			return t as Texture2D
	return null

func _make_icon_stat(icon: Texture2D, value_text: String) -> Dictionary:
	var wrap := HBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if icon != null:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.custom_minimum_size = Vector2(40, 40)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(tr)

	var lbl := Label.new()
	lbl.text = value_text
	lbl.modulate = COL_TEXT_DARK
	lbl.add_theme_font_size_override("font_size", 18)
	wrap.add_child(lbl)

	return {"node": wrap, "label": lbl}

func _style_progressbar(pb: ProgressBar) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = COL_PROGRESS_BG
	bg.corner_radius_top_left = 10
	bg.corner_radius_top_right = 10
	bg.corner_radius_bottom_left = 10
	bg.corner_radius_bottom_right = 10
	pb.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.25, 0.65, 0.30, 1.0)
	fill.corner_radius_top_left = 10
	fill.corner_radius_top_right = 10
	fill.corner_radius_bottom_left = 10
	fill.corner_radius_bottom_right = 10
	pb.add_theme_stylebox_override("fill", fill)

func _style_action_button(btn: Button, bg: Color, border: Color, text_col: Color, font_size: int) -> void:
	btn.add_theme_font_size_override("font_size", font_size)
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

func _fmt_time(seconds: int) -> String:
	if seconds <= 0:
		return "0s"
	var s: int = seconds
	var m: int = s / 60
	s = s % 60
	var h: int = m / 60
	m = m % 60
	if h > 0:
		return "%dh %dm %ds" % [h, m, s]
	if m > 0:
		return "%dm %ds" % [m, s]
	return "%ds" % s

func _fmt_compact_number(value: int) -> String:
	const SUFFIXES := ["", "K", "M", "B", "T", "Q"]

	var sign := ""
	var n: float = float(value)
	if n < 0.0:
		sign = "-"
		n = -n

	var idx: int = 0
	while n >= 1000.0 and idx < SUFFIXES.size() - 1:
		n /= 1000.0
		idx += 1

	if idx > 0:
		var rounded: float = round(n * 10.0) / 10.0
		while rounded >= 1000.0 and idx < SUFFIXES.size() - 1:
			rounded /= 1000.0
			idx += 1
		return sign + ("%0.1f%s" % [rounded, SUFFIXES[idx]])

	return sign + str(int(round(n)))

func _wrap_currency_chip(inner: Control) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.custom_minimum_size = Vector2(0, 44)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.22)  # subtle light fill
	sb.set_border_width_all(2)
	sb.border_color = COL_CARD_BORDER
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	pc.add_theme_stylebox_override("panel", sb)

	# inner is your icon+label HBoxContainer
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_child(inner)

	return pc
