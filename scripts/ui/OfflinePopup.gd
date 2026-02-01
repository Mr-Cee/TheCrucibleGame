extends Control
class_name OfflinePopup

signal closed
signal dismissed   # closed via X (player postponed claiming)
signal claimed     # closed via Claim (rewards consumed)


# -------------------- Tunables --------------------
const SHELL_W := 640
const SHELL_H := 760

# -------------------- Palette (LoM-ish parchment) --------------------
const COL_DIM := Color(0, 0, 0, 0.55)

const COL_SHELL_BG := Color(0.94, 0.91, 0.82, 1.0)
const COL_BORDER   := Color(0.55, 0.46, 0.32, 1.0)
const COL_LINE     := Color(0.78, 0.69, 0.52, 1.0)

const COL_CARD_BG     := Color(0.98, 0.97, 0.93, 1.0)
const COL_CARD_BORDER := Color(0.70, 0.60, 0.44, 1.0)

const COL_TEXT_DARK  := Color(0.18, 0.14, 0.10, 1.0)
const COL_TEXT_MUTED := Color(0.38, 0.32, 0.26, 1.0)

const COL_BTN_BONUS_BG  := Color(0.24, 0.44, 0.82, 1.0)
const COL_BTN_BONUS_BR  := Color(0.14, 0.26, 0.52, 1.0)
const COL_BTN_CLAIM_BG  := Color(0.26, 0.62, 0.31, 1.0)
const COL_BTN_CLAIM_BR  := Color(0.15, 0.40, 0.18, 1.0)
const COL_BTN_CLOSE_BG  := Color(0.80, 0.74, 0.60, 1.0)
const COL_BTN_CLOSE_BR  := Color(0.55, 0.46, 0.32, 1.0)

const COL_TIME_GREEN := Color(0.20, 0.55, 0.26, 1.0)

# Icons (safe-load; OK if missing)
const PATH_ICON_GOLD := "res://assets/icons/UI/currency/gold.png"
const PATH_ICON_KEYS := "res://assets/icons/UI/keys/crucible_key_main.png"
const PATH_ICON_XP   := "res://assets/icons/UI/currency/exp.png"


# -------------------- State --------------------
var _pending: Dictionary = {}

# -------------------- Nodes --------------------
var _shell: PanelContainer
var _title_lbl: Label
var _btn_x: Button

var _time_val: Label

var _gold_val: Label
var _gold_rate: Label
var _keys_val: Label
var _keys_rate: Label
var _xp_val: Label
var _xp_rate: Label

var _btn_bonus: Button
var _bonus_uses_lbl: Label
var _btn_claim: Button

func setup(pending: Dictionary) -> void:
	_pending = pending.duplicate(true)
	if is_node_ready():
		_refresh()

func _ready() -> void:
	name = "OfflinePopup"

	# IMPORTANT: do NOT use top_level here; it can cause unexpected positioning
	# top_level = true

	# Fullscreen overlay (match DungeonsPanel behavior)
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
	dim.offset_left = 0
	dim.offset_top = 0
	dim.offset_right = 0
	dim.offset_bottom = 0
	dim.color = COL_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	# Center wrapper (this is the "drop-in" centering fix)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 0
	center.offset_top = 0
	center.offset_right = 0
	center.offset_bottom = 0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# Shell (now centered automatically)
	_shell = PanelContainer.new()
	_shell.custom_minimum_size = Vector2(SHELL_W, SHELL_H)
	_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_shell)

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
	_title_lbl.text = "Offline Reward"
	_title_lbl.modulate = COL_TEXT_DARK
	_title_lbl.add_theme_font_size_override("font_size", 24)
	_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(_title_lbl)

	_btn_x = Button.new()
	_btn_x.text = "X"
	_btn_x.custom_minimum_size = Vector2(46, 36)
	_btn_x.pressed.connect(func() -> void:
		emit_signal("dismissed")
		emit_signal("closed")
		queue_free()
	)

	header.add_child(_btn_x)
	_style_action_button(_btn_x, COL_BTN_CLOSE_BG, COL_BTN_CLOSE_BR, COL_TEXT_DARK, 18)

	root.add_child(_make_hr())

	# Offline time block
	var time_box := _make_card()
	root.add_child(time_box)
	var time_inner := time_box.get_node("InnerMargin/Inner") as VBoxContainer

	var t1 := Label.new()
	t1.text = "Offline Time"
	t1.modulate = COL_TEXT_MUTED
	t1.add_theme_font_size_override("font_size", 16)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_inner.add_child(t1)

	_time_val = Label.new()
	_time_val.text = "00:00"
	_time_val.modulate = COL_TIME_GREEN
	_time_val.add_theme_font_size_override("font_size", 30)
	_time_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_inner.add_child(_time_val)

	# Reward row
	var reward_box := _make_card()
	root.add_child(reward_box)
	var reward_inner := reward_box.get_node("InnerMargin/Inner") as VBoxContainer

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_inner.add_child(row)

	var gold_col := _make_reward_column(_safe_load_tex(PATH_ICON_GOLD), "Gold")
	_gold_val = gold_col["val"]
	_gold_rate = gold_col["rate"]
	row.add_child(gold_col["node"])

	var keys_col := _make_reward_column(_safe_load_tex(PATH_ICON_KEYS), "Keys")
	_keys_val = keys_col["val"]
	_keys_rate = keys_col["rate"]
	row.add_child(keys_col["node"])

	var xp_col := _make_reward_column(_safe_load_tex(PATH_ICON_XP), "XP")
	_xp_val = xp_col["val"]
	_xp_rate = xp_col["rate"]
	row.add_child(xp_col["node"])

	# Spacer / future grid area (keeps the layout close to your screenshot)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(filler)

	root.add_child(_make_hr())

	# Buttons row (Bonus left, Claim right)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 14)
	root.add_child(btn_row)

	var bonus_wrap := VBoxContainer.new()
	bonus_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bonus_wrap.add_theme_constant_override("separation", 4)
	btn_row.add_child(bonus_wrap)

	_btn_bonus = Button.new()
	_btn_bonus.text = "2H Bonus"
	_btn_bonus.custom_minimum_size = Vector2(0, 56)
	_btn_bonus.pressed.connect(_on_bonus_pressed)
	bonus_wrap.add_child(_btn_bonus)
	_style_action_button(_btn_bonus, COL_BTN_BONUS_BG, COL_BTN_BONUS_BR, Color(0.98, 0.97, 0.93, 1.0), 22)

	_bonus_uses_lbl = Label.new()
	_bonus_uses_lbl.text = "(0/3)"
	_bonus_uses_lbl.modulate = COL_TEXT_MUTED
	_bonus_uses_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_wrap.add_child(_bonus_uses_lbl)

	_btn_claim = Button.new()
	_btn_claim.text = "Claim"
	_btn_claim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_claim.custom_minimum_size = Vector2(0, 56)
	_btn_claim.pressed.connect(_on_claim_pressed)
	btn_row.add_child(_btn_claim)
	_style_action_button(_btn_claim, COL_BTN_CLAIM_BG, COL_BTN_CLAIM_BR, Color(0.98, 0.97, 0.93, 1.0), 22)

	_refresh()

func _on_claim_pressed() -> void:
	var res := Game.offline_claim_pending()
	if bool(res.get("ok", false)):
		emit_signal("claimed")
		emit_signal("closed")
		queue_free()


func _on_bonus_pressed() -> void:
	# Must watch rewarded ad. If Ads autoload not present, succeed immediately (dev-friendly).
	var now_unix: int = int(Time.get_unix_time_from_system())
	if not OfflineRewards.can_use_bonus(Game.player, now_unix):
		Game.inventory_event.emit("2H Bonus limit reached (resets at 00:00 GMT).")
		_refresh()
		return

	_btn_bonus.disabled = true
	_show_rewarded_ad("offline_bonus", func(success: bool) -> void:
		_btn_bonus.disabled = false
		if not success:
			Game.inventory_event.emit("Ad not completed.")
			_refresh()
			return

		var r := Game.offline_apply_bonus_2h()
		if not bool(r.get("ok", false)):
			Game.inventory_event.emit("2H Bonus unavailable.")
		# Pull updated pending from player
		_pending = Game.offline_get_pending().duplicate(true)
		_refresh()
	)

func _show_rewarded_ad(placement: String, done: Callable) -> void:
	var ads := get_tree().root.get_node_or_null("Ads")
	if ads != null and ads.has_method("show_rewarded"):
		# Expected signature: show_rewarded(placement: String, done: Callable)
		ads.call("show_rewarded", placement, done)
		return

	# Dev fallback: auto-succeed
	done.call(true)

# -------------------- Rendering --------------------

func _refresh() -> void:
	# Pull latest if we weren't setup explicitly
	if _pending.is_empty() and Game != null and Game.has_method("offline_get_pending"):
		_pending = Game.offline_get_pending()

	var base_sec: int = int(_pending.get("base_seconds", 0))
	var bonus_sec: int = int(_pending.get("bonus_seconds", 0))
	var total_sec: int = base_sec + bonus_sec

	_time_val.text = _fmt_clock(total_sec) # shows m:ss or h:mm:ss

	var gold: int = int(_pending.get("gold", 0)) + int(_pending.get("bonus_gold", 0))
	var keys: int = int(_pending.get("keys", 0)) + int(_pending.get("bonus_keys", 0))
	var xp: int = int(_pending.get("xp", 0)) + int(_pending.get("bonus_xp", 0))

	_gold_val.text = _fmt_compact_number(gold)
	_keys_val.text = _fmt_compact_number(keys)
	_xp_val.text = _fmt_compact_number(xp)

	_gold_rate.text = _rate_per_min(gold, total_sec)
	_keys_rate.text = _rate_per_hour(keys, total_sec)
	_xp_rate.text = _rate_per_hour(xp, total_sec)

	# Bonus uses (shown as used/3)
	var now_unix: int = int(Time.get_unix_time_from_system())
	OfflineRewards.reset_bonus_if_new_day(Game.player, now_unix)
	var used := int(Game.player.offline_bonus_uses)
	_bonus_uses_lbl.text = "(%d/%d)" % [used, OfflineRewards.OFFLINE_BONUS_DAILY_LIMIT]

	var remaining := OfflineRewards.bonus_uses_remaining(Game.player, now_unix)
	_btn_bonus.disabled = (remaining <= 0)

	# If there is nothing to claim (rare), disable claim
	_btn_claim.disabled = (gold == 0 and keys == 0 and xp == 0)

func _fmt_hhmm(seconds: int) -> String:
	seconds = max(0, seconds)
	var h: int = seconds / 3600
	var m: int = (seconds % 3600) / 60
	return "%d:%02d" % [h, m]

func _safe_load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t := load(path)
		if t is Texture2D:
			return t as Texture2D
	return null

func _make_reward_column(icon: Texture2D, title: String) -> Dictionary:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)

	if icon != null:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.custom_minimum_size = Vector2(48, 48)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(tr)

	var ttl := Label.new()
	ttl.text = title
	ttl.modulate = COL_TEXT_MUTED
	ttl.add_theme_font_size_override("font_size", 14)
	top.add_child(ttl)

	var val := Label.new()
	val.text = "0"
	val.modulate = COL_TEXT_DARK
	val.add_theme_font_size_override("font_size", 26)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(val)

	var rate := Label.new()
	rate.text = "0/m"
	rate.modulate = COL_TEXT_MUTED
	rate.add_theme_font_size_override("font_size", 14)
	rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rate)

	return {"node": v, "val": val, "rate": rate}

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

func _fmt_clock(seconds: int) -> String:
	seconds = maxi(0, seconds)
	var h: int = seconds / 3600
	var m: int = (seconds % 3600) / 60
	var s: int = seconds % 60

	# m:ss for < 1 hour, h:mm:ss for >= 1 hour
	if h <= 0:
		return "%d:%02d" % [m, s]
	return "%d:%02d:%02d" % [h, m, s]

func _rate_per_min(amount: int, seconds: int) -> String:
	if seconds <= 0:
		return "—/m"
	var mins: float = float(seconds) / 60.0
	if mins <= 0.0:
		return "—/m"
	var v: int = int(round(float(amount) / mins))
	return "%d/m" % v

func _rate_per_hour(amount: int, seconds: int) -> String:
	if seconds <= 0:
		return "—/h"
	var hrs: float = float(seconds) / 3600.0
	if hrs <= 0.0:
		return "—/h"
	var v: int = int(round(float(amount) / hrs))
	return "%d/h" % v
