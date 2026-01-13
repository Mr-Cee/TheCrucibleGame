extends Window

@onready var title_label: Label = $VBox/TitleLabel
@onready var status_label: Label = $VBox/StatusLabel
@onready var progress_label: Label = $VBox/ProgressLabel
@onready var upgrade_progress: ProgressBar = $VBox/UpgradeProgress
@onready var time_label: Label = $VBox/TimeLabel
#@onready var pay_button: Button = $VBox/ButtonsRow/PayButton
@onready var close_button: Button = $VBox/ButtonsRow/CloseButton

@onready var odds_header: Label = $VBox/OddsHeader
@onready var odds_grid: GridContainer = $VBox/OddsScroll/OddsGrid

@onready var payment_bar: HBoxContainer = $VBox/PaymentRow/PaymentBar
@onready var pay_button: Button = $VBox/PaymentRow/PayButton

@onready var voucher_label: Label = $VBox/VoucherRow/VoucherLabel
@onready var use_voucher_button: Button = $VBox/VoucherRow/UseVoucherButton




var _ui_timer: Timer

var _odds_curr_labels: Dictionary = {}
var _odds_next_labels: Dictionary = {}
var _odds_name_panels: Dictionary = {}

var _payment_segments: Array[Panel] = []


#===================================================================================================

func _ready() -> void:
	title_label.text = "Crucible Upgrade"

	pay_button.pressed.connect(_on_pay_pressed)
	close_button.pressed.connect(func() -> void: visible = false)
	use_voucher_button.pressed.connect(_on_use_voucher_pressed)

	Game.player_changed.connect(_refresh)
	
	_build_odds_table()

	_ui_timer = Timer.new()
	_ui_timer.wait_time = 0.5
	_ui_timer.one_shot = false
	_ui_timer.timeout.connect(_refresh)
	add_child(_ui_timer)

	_refresh()

func popup_and_refresh() -> void:
	_refresh()
	popup_centered(Vector2i(520, 380))
	_ui_timer.start()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if not visible and _ui_timer:
			_ui_timer.stop()

func _refresh() -> void:
	# Apply completion if timer finished while popup closed
	Game.crucible_tick_upgrade_completion()

	var lvl: int = Game.player.crucible_level
	var req: int = Game.crucible_required_payment_stages(lvl)
	var paid: int = Game.player.crucible_upgrade_paid_stages
	
	_ensure_payment_segments(req)
	_set_payment_segments_filled(paid, req)
	
	voucher_label.text = "Time Vouchers: %d" % int(Game.player.time_vouchers)

	# Default state
	use_voucher_button.disabled = true
	use_voucher_button.text = "Use Time Vouchers"
	
	#$VBox/VoucherRow.visible = Game.crucible_is_upgrading()


	# Enable only while upgrading and vouchers exist
	if Game.crucible_is_upgrading() and Game.player.time_vouchers > 0:
		use_voucher_button.disabled = false
	elif Game.crucible_is_upgrading() and Game.player.time_vouchers <= 0:
		use_voucher_button.disabled = true
		use_voucher_button.text = "No vouchers"


	status_label.text = "Current: Lv.%d" % lvl

	# Always refresh odds first so the table is never blank on open
	_refresh_odds()

	# --- Upgrading state ---
	if Game.crucible_is_upgrading():
		
		
		var remaining: int = Game.crucible_upgrade_seconds_remaining()

		var total: int = Game.crucible_upgrade_time_seconds(lvl)
		total = max(1, total)
		var elapsed: int = clamp(total - remaining, 0, total)

		progress_label.text = "Upgrading: Lv.%d → Lv.%d" % [lvl, Game.player.crucible_upgrade_target_level]

		upgrade_progress.visible = true
		time_label.visible = true
		upgrade_progress.min_value = 0
		upgrade_progress.max_value = total
		upgrade_progress.value = elapsed

		time_label.text = "Time remaining: %s" % _fmt_time(remaining)
		_set_payment_segments_filled(req, req) # show paid bar full while upgrading
		pay_button.text = "Upgrading..."
		pay_button.disabled = true
		return

	# Not upgrading
	upgrade_progress.visible = false
	time_label.visible = false
	pay_button.disabled = false

	# --- Payment stage state ---
	if paid < req:
		var cost: int = Game.crucible_stage_cost_gold(lvl, paid)
		progress_label.text = "Payment: %d / %d" % [paid, req]
		pay_button.text = "Pay (%d gold)" % cost
		pay_button.disabled = false
		return

	# Fully paid, ready to start timer
	var secs: int = Game.crucible_upgrade_time_seconds(lvl)
	progress_label.text = "Paid (%d/%d). Upgrade time: %s" % [paid, req, _fmt_time(secs)]
	pay_button.text = "Upgrade"

func _on_pay_pressed() -> void:
	# One button handles both “Pay next stage” and “Start upgrade”
	if Game.crucible_is_upgrading():
		return

	var lvl: int = Game.player.crucible_level
	var req: int = Game.crucible_required_payment_stages(lvl)
	var paid: int = Game.player.crucible_upgrade_paid_stages

	if paid < req:
		Game.crucible_pay_one_upgrade_stage()
	else:
		Game.crucible_start_upgrade_timer()

	_refresh()

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

func _build_odds_table() -> void:
	# Clear previous
	for c in odds_grid.get_children():
		c.queue_free()

	_odds_curr_labels.clear()
	_odds_next_labels.clear()
	_odds_name_panels.clear()

	# Header row
	var h0 := Label.new()
	h0.text = ""
	odds_grid.add_child(h0)

	var h1 := Label.new()
	h1.text = "Current"
	odds_grid.add_child(h1)

	var h2 := Label.new()
	h2.text = "Next"
	odds_grid.add_child(h2)

	# Rows per rarity
	for rarity in Catalog.RARITY_DISPLAY_ORDER:
		var rarity_name: String = String(Catalog.RARITY_NAMES.get(rarity, "Rarity"))
		var color: Color = Catalog.RARITY_COLORS.get(rarity, Color.WHITE)

		# Name cell as a tinted panel
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(color.r, color.g, color.b, 0.18)
		sb.border_color = color
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		panel.add_theme_stylebox_override("panel", sb)

		var name_lbl := Label.new()
		name_lbl.text = rarity_name
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		panel.add_child(name_lbl)
		odds_grid.add_child(panel)

		var curr_lbl := Label.new()
		curr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		odds_grid.add_child(curr_lbl)

		var next_lbl := Label.new()
		next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		odds_grid.add_child(next_lbl)

		_odds_name_panels[rarity] = panel
		_odds_curr_labels[rarity] = curr_lbl
		_odds_next_labels[rarity] = next_lbl
		
		h0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		curr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		next_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _refresh_odds() -> void:
	var cur_level: int = Game.player.crucible_level
	var next_level: int = cur_level + 1

	# If currently upgrading, show the actual target as "Next"
	if Game.crucible_is_upgrading():
		next_level = int(Game.player.crucible_upgrade_target_level)

	odds_header.text = "Odds (Lv.%d → Lv.%d)" % [cur_level, next_level]

	var cur_odds: Dictionary = Catalog.crucible_rarity_odds(cur_level)
	var next_odds: Dictionary = Catalog.crucible_rarity_odds(next_level)

	for rarity in Catalog.RARITY_DISPLAY_ORDER:
		var unlock: int = Catalog.crucible_rarity_unlock_level(int(rarity))
		var curr_lbl := _odds_curr_labels.get(rarity, null) as Label
		var next_lbl := _odds_next_labels.get(rarity, null) as Label

		var curr_locked: bool = cur_level < unlock
		var next_locked: bool = next_level < unlock

		if curr_lbl:
			if curr_locked:
				curr_lbl.text = "Locked"
				curr_lbl.modulate = Color(0.7, 0.7, 0.7, 1.0)
			else:
				var p: float = float(cur_odds.get(rarity, 0.0)) * 100.0
				curr_lbl.text = "%.2f%%" % p
				curr_lbl.modulate = Color(1, 1, 1, 1)

		if next_lbl:
			if next_locked:
				next_lbl.text = "Locked"
				next_lbl.modulate = Color(0.7, 0.7, 0.7, 1.0)
			else:
				var p2: float = float(next_odds.get(rarity, 0.0)) * 100.0
				next_lbl.text = "%.2f%%" % p2
				next_lbl.modulate = Color(1, 1, 1, 1)

func _ensure_payment_segments(required: int) -> void:
	# Rebuild only if needed
	if _payment_segments.size() == required:
		return

	# Clear old
	for c in payment_bar.get_children():
		c.queue_free()
	_payment_segments.clear()

	# Build new segments
	for i in range(required):
		var seg := Panel.new()
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.size_flags_vertical = Control.SIZE_FILL

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.20, 0.20, 0.20, 1.0) # unfilled color
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0.10, 0.10, 0.10, 1.0)
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4

		seg.add_theme_stylebox_override("panel", sb)
		payment_bar.add_child(seg)
		_payment_segments.append(seg)

func _set_payment_segments_filled(filled: int, required: int) -> void:
	# Visual treatment: filled segments are green-ish; unfilled are dark.
	# (We can later theme this to match your art style.)
	filled = clampi(filled, 0, required)

	for i in range(required):
		var seg := _payment_segments[i]
		var sb := seg.get_theme_stylebox("panel") as StyleBoxFlat
		if sb == null:
			continue
		var sb2 := sb.duplicate(true) as StyleBoxFlat

		if i < filled:
			sb2.bg_color = Color(0.25, 0.65, 0.30, 1.0) # filled
			sb2.border_color = Color(0.18, 0.45, 0.22, 1.0)
		else:
			sb2.bg_color = Color(0.20, 0.20, 0.20, 1.0) # unfilled
			sb2.border_color = Color(0.10, 0.10, 0.10, 1.0)

		seg.add_theme_stylebox_override("panel", sb2)

func _on_use_voucher_pressed() -> void:
	# Open the voucher selection popup (owned by Home)
	var home := get_tree().current_scene
	if home and home.has_method("open_voucher_popup"):
		home.call("open_voucher_popup")
