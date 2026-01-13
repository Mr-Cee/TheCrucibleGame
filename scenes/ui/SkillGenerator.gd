extends Control
class_name SkillGeneratorPanel

const CRYSTALS_PER_TICKET: int = 10
const AD_DRAWS_PER_DAY: int = 3

var _panel: PanelContainer = null
var _status: Label = null
var _lvl_label: Label = null
var _odds_grid: GridContainer = null
var _odds_value_labels: Dictionary = {} # rarity(int) -> Label

var _currency_label: Label = null

var _btn_ad: Button = null
var _btn_10: Button = null
var _btn_35: Button = null

var _confirm: ConfirmationDialog = null
var _pending_draw_count: int = 0
var _pending_ticket_cost: int = 0
var _pending_is_ad: bool = false
var _pending_crystal_cost: int = 0

signal closed

const SKILL_RARITY_ORDER: Array[int] = [0, 1, 2, 3, 4]
const SKILL_RARITY_NAMES := {
	0: "Common",
	1: "Uncommon",
	2: "Rare",
	3: "Legendary",
	4: "Mythical",
}
const SKILL_RARITY_COLORS := {
	0: Color("8a8a8a"), # common gray
	1: Color("2ecc71"), # uncommon green
	2: Color("3498db"), # rare blue
	3: Color("e67e22"), # legendary orange
	4: Color("f1c40f"), # mythical yellow
}


func _ready() -> void:
	top_level = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	_build()
	call_deferred("_center_panel")
	_refresh()

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.name = "MainPanel"
	_panel.custom_minimum_size = Vector2(680, 520)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.08, 0.08, 0.10, 0.98)
	psb.border_color = Color(0.25, 0.25, 0.30, 1.0)
	psb.border_width_left = 2
	psb.border_width_top = 2
	psb.border_width_right = 2
	psb.border_width_bottom = 2
	psb.corner_radius_top_left = 10
	psb.corner_radius_top_right = 10
	psb.corner_radius_bottom_left = 10
	psb.corner_radius_bottom_right = 10
	_panel.add_theme_stylebox_override("panel", psb)


	var root := VBoxContainer.new()
	root.offset_left = 12
	root.offset_right = -12
	root.offset_top = 12
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)

	var title := Label.new()
	title.text = "Skill Generator"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)

	_currency_label = Label.new()
	_currency_label.text = ""
	root.add_child(_currency_label)

	_lvl_label = Label.new()
	_lvl_label.text = ""
	root.add_child(_lvl_label)

	var odds_header := Label.new()
	odds_header.text = "Rarity Odds"
	odds_header.add_theme_font_size_override("font_size", 16)
	root.add_child(odds_header)

	_odds_grid = GridContainer.new()
	_odds_grid.columns = 2
	_odds_grid.add_theme_constant_override("h_separation", 10)
	_odds_grid.add_theme_constant_override("v_separation", 8)
	root.add_child(_odds_grid)

	_build_odds_table()


	_status = Label.new()
	_status.text = ""
	_status.modulate = Color(1.0, 0.7, 0.7, 1.0)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)

	root.add_child(HSeparator.new())

	# Buttons
	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	root.add_child(btns)

	_btn_ad = Button.new()
	_btn_ad.text = "Ad Draw (5)"
	_btn_ad.pressed.connect(func() -> void:
		_try_draw(5, 0, true)
	)
	btns.add_child(_btn_ad)

	_btn_10 = Button.new()
	_btn_10.text = "10 Draw (10 tickets)"
	_btn_10.pressed.connect(func() -> void:
		_try_draw(10, 10, false)
	)
	btns.add_child(_btn_10)

	_btn_35 = Button.new()
	_btn_35.text = "35 Draw (30 tickets)"
	_btn_35.pressed.connect(func() -> void:
		_try_draw(35, 30, false)
	)
	btns.add_child(_btn_35)

	root.add_child(HSeparator.new())

	# Footer
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	root.add_child(footer)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	var close := Button.new()
	close.text = "Back"
	close.pressed.connect(_on_back_pressed)
	footer.add_child(close)

	# Confirmation dialog for “tickets + crystals”
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Confirm Purchase"
	_confirm.confirmed.connect(_on_confirmed_purchase)
	add_child(_confirm)

func _center_panel() -> void:
	if _panel == null:
		return
	var vp := get_viewport_rect().size
	_panel.size = _panel.custom_minimum_size
	_panel.position = (vp - _panel.size) * 0.5

func _refresh() -> void:
	_status.text = ""

	if Game.player == null:
		_currency_label.text = "No player loaded."
		_btn_ad.disabled = true
		_btn_10.disabled = true
		_btn_35.disabled = true
		return

	if Game.player.has_method("ensure_skill_generator_initialized"):
		Game.player.call("ensure_skill_generator_initialized")

	if Game.player.has_method("ensure_skill_generator_daily_reset"):
		var now_unix: int = int(Time.get_unix_time_from_system())
		Game.player.call("ensure_skill_generator_daily_reset", now_unix)

	var tickets: int = int(Game.player.get("skill_tickets"))
	var crystals: int = int(Game.player.get("crystals"))
	_currency_label.text = "Tickets: %d    Crystals: %d" % [tickets, crystals]

	var lvl: int = int(Game.player.get("skill_gen_level"))
	var xp: int = int(Game.player.get("skill_gen_xp"))
	var need: int = 0
	if Game.player.has_method("skill_gen_xp_required_for_next_level"):
		need = int(Game.player.call("skill_gen_xp_required_for_next_level"))
	else:
		need = 50

	_lvl_label.text = "Generator Level: %d    XP: %d/%d" % [lvl, xp, need]

	var odds_txt: String = SkillCatalog.generator_odds_text(lvl)
	_set_odds_from_text(odds_txt)


	var used: int = int(Game.player.get("skill_ad_draws_used_today"))
	var remaining: int = maxi(0, AD_DRAWS_PER_DAY - used)

	_btn_ad.text = "Ad Draw (5) — %d/%d remaining today" % [remaining, AD_DRAWS_PER_DAY]
	_btn_ad.disabled = remaining <= 0

func _try_draw(draw_count: int, ticket_cost: int, is_ad: bool) -> void:
	if Game.player == null:
		return

	if Game.player.has_method("ensure_skill_generator_initialized"):
		Game.player.call("ensure_skill_generator_initialized")

	if Game.player.has_method("ensure_skill_generator_daily_reset"):
		var now_unix: int = int(Time.get_unix_time_from_system())
		Game.player.call("ensure_skill_generator_daily_reset", now_unix)

	_status.text = ""

	if is_ad:
		var used: int = int(Game.player.get("skill_ad_draws_used_today"))
		var remaining: int = maxi(0, AD_DRAWS_PER_DAY - used)
		if remaining <= 0:
			_status.text = "No ad draws remaining today."
			_refresh()
			return
		# No ad integration yet; we simply consume the daily allowance.
		_pending_draw_count = draw_count
		_pending_ticket_cost = 0
		_pending_is_ad = true
		_pending_crystal_cost = 0
		_execute_draw()
		return

	# Ticket draws
	var tickets: int = int(Game.player.get("skill_tickets"))
	var crystals: int = int(Game.player.get("crystals"))
	var missing: int = maxi(0, ticket_cost - tickets)
	var crystal_cost: int = missing * CRYSTALS_PER_TICKET

	if missing == 0:
		_pending_draw_count = draw_count
		_pending_ticket_cost = ticket_cost
		_pending_is_ad = false
		_pending_crystal_cost = 0
		_execute_draw()
		return

	# Need crystals to cover the gap
	if crystals < crystal_cost:
		_status.text = "Not enough tickets. You need %d more tickets (%d crystals), but only have %d crystals." % [
			missing, crystal_cost, crystals
		]
		return

	_pending_draw_count = draw_count
	_pending_ticket_cost = ticket_cost
	_pending_is_ad = false
	_pending_crystal_cost = crystal_cost

	_confirm.dialog_text = "This draw costs %d tickets.\nYou have %d tickets.\nSpend %d crystals to cover the missing %d tickets?" % [
		ticket_cost, tickets, crystal_cost, missing
	]
	_confirm.popup_centered()

func _on_confirmed_purchase() -> void:
	_execute_draw()

func _execute_draw() -> void:
	if Game.player == null:
		return

	# Consume costs
	if _pending_is_ad:
		var used: int = int(Game.player.get("skill_ad_draws_used_today"))
		Game.player.set("skill_ad_draws_used_today", used + 1)
	else:
		var tickets: int = int(Game.player.get("skill_tickets"))
		var crystals: int = int(Game.player.get("crystals"))

		# Spend tickets first, then crystals for missing tickets (if any)
		var to_spend_tickets: int = mini(tickets, _pending_ticket_cost)
		var remaining_cost: int = _pending_ticket_cost - to_spend_tickets
		var spend_crystals: int = remaining_cost * CRYSTALS_PER_TICKET

		if spend_crystals > 0 and crystals < spend_crystals:
			_status.text = "Not enough crystals to complete purchase."
			return

		Game.player.set("skill_tickets", tickets - to_spend_tickets)
		Game.player.set("crystals", crystals - spend_crystals)

	# Roll skills
	if Game.player.has_method("ensure_active_skills_initialized"):
		Game.player.call("ensure_active_skills_initialized")

	var lvl: int = int(Game.player.get("skill_gen_level"))
	var awarded: Array[String] = []
	awarded.resize(0)

	for i in range(_pending_draw_count):
		var sid: String = SkillCatalog.roll_skill_for_generator(lvl)
		if sid == "":
			continue
		awarded.append(sid)
		# Add one copy (progress)
		if Game.player.has_method("add_skill_copies"):
			Game.player.call("add_skill_copies", sid, 1)

	# Level generator by making draws (XP = number of skills drawn)
	if Game.player.has_method("add_skill_generator_xp"):
		Game.player.call("add_skill_generator_xp", _pending_draw_count)

	SaveManager.save_now()
	Game.player_changed.emit()

	# Show results
	var res := SkillDrawResultsPanel.new()
	get_tree().root.add_child(res)
	res.set_awards(awarded)

	_refresh()

func _on_back_pressed() -> void:
	emit_signal("closed")
	# also wake any listeners that rely on player_changed
	Game.player_changed.emit()
	queue_free()

func _build_odds_table() -> void:
	if _odds_grid == null:
		return

	for c in _odds_grid.get_children():
		c.queue_free()

	_odds_value_labels.clear()

	for r in SKILL_RARITY_ORDER:
		var rname: String = String(SKILL_RARITY_NAMES.get(r, "Rarity"))
		var rcol: Color = SKILL_RARITY_COLORS.get(r, Color.WHITE)

		# Name cell with crucible-like tint + border
		var name_panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(rcol.r, rcol.g, rcol.b, 0.18)
		sb.border_color = rcol
		sb.border_width_left = 2
		sb.border_width_top = 2
		sb.border_width_right = 2
		sb.border_width_bottom = 2
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		name_panel.add_theme_stylebox_override("panel", sb)

		var name_lbl := Label.new()
		name_lbl.text = rname
		name_lbl.add_theme_color_override("font_color", Color.WHITE)
		name_panel.add_child(name_lbl)
		_odds_grid.add_child(name_panel)

		# Value cell
		var val_lbl := Label.new()
		val_lbl.text = "0.0%"
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_odds_grid.add_child(val_lbl)
		_odds_value_labels[r] = val_lbl

func _set_odds_from_text(text: String) -> void:
	# Parses lines like "Common: 90.0%"
	var map: Dictionary = {}
	var lines: PackedStringArray = text.split("\n", false)
	for ln in lines:
		var line: String = ln.strip_edges()
		if line == "":
			continue
		var parts: PackedStringArray = line.split(":", false, 2)
		if parts.size() < 2:
			continue
		var name: String = parts[0].strip_edges()
		var rhs: String = parts[1].strip_edges()
		rhs = rhs.replace("%", "").strip_edges()
		var pct: float = 0.0
		if rhs.is_valid_float():
			pct = float(rhs)
		map[name] = pct

	for r in SKILL_RARITY_ORDER:
		var lbl: Label = _odds_value_labels.get(r, null)
		if lbl == null:
			continue
		var rname: String = String(SKILL_RARITY_NAMES.get(r, "Rarity"))
		var pct: float = float(map.get(rname, 0.0))
		lbl.text = "%.1f%%" % pct
