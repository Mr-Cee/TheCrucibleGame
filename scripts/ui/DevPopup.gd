extends Window

@onready var give_select: OptionButton = $VBox/GiveRow/GiveSelect
@onready var amount_edit: LineEdit = $VBox/GiveRow/AmountEdit
@onready var give_button: Button = $VBox/GiveRow/GiveButton

@onready var diff_select: OptionButton = $VBox/BattleRow/DifficultySelect
@onready var level_spin: SpinBox = $VBox/BattleRow/LevelSpin
@onready var stage_spin: SpinBox = $VBox/BattleRow/StageSpin
@onready var wave_spin: SpinBox = $VBox/BattleRow/WaveSpin
@onready var set_battle_button: Button = $VBox/BattleRow/SetBattleButton
@onready var battle_preview: Label = $VBox/BattlePreview

@onready var level_spin_box: SpinBox = $VBox/LevelSelectRow/LevelSpinBox
@onready var set_level_btn: Button = $VBox/LevelSelectRow/SetLevelButton

var _offline_row: HBoxContainer
var _offline_hours: SpinBox
var _offline_mins: SpinBox
var _offline_apply: Button
var _offline_hint: Label


@onready var close_button: Button = $VBox/CloseButton

# Keep these as IDs so we can map them cleanly.
const GIVE_ITEMS: Array[Dictionary] = [
	{"id":"gold", "label":"Gold"},
	{"id":"xp", "label":"XP"},
	{"id":"time_vouchers", "label":"Time Vouchers"},
	{"id":"diamonds", "label":"Diamonds"},
	{"id":"crystals", "label":"Crystals"},
	{"id":"crucible_keys", "label":"Crucible Keys"},
	{"id":"battlepass_30d", "label":"Battle Pass (30d offline cap +2h)"},
	{"id":"premium_offline", "label":"Premium Offline Bundle (2h Permanent)"}
]

func _ready() -> void:
	title = "Dev Tools"
	close_button.pressed.connect(func() -> void: visible = false)

	_build_give_dropdown()
	give_button.pressed.connect(_on_give_pressed)

	_build_difficulty_dropdown()
	set_battle_button.pressed.connect(_on_set_battle_pressed)

	amount_edit.text = "100"
	amount_edit.placeholder_text = "Amount"
	
	if Game.player != null:
		level_spin_box.value = int(Game.player.level)

	level_spin.step = 1
	stage_spin.step = 1
	wave_spin.step = 1
	level_spin.value_changed.connect(func(_v: float) -> void: _refresh_battle_preview())
	stage_spin.value_changed.connect(func(_v: float) -> void: _refresh_battle_preview())
	wave_spin.value_changed.connect(func(_v: float) -> void: _refresh_battle_preview())
	diff_select.item_selected.connect(func(_i: int) -> void: _refresh_battle_preview())
	set_level_btn.pressed.connect(_on_set_level_pressed)

	_refresh_from_game()
	_build_offline_controls()

func popup_and_refresh() -> void:
	_refresh_from_game()
	popup_centered(Vector2i(620, 360))

func _refresh_from_game() -> void:
	# Battle ranges (use Catalog tuning)
	level_spin.min_value = 1
	level_spin.max_value = float(Catalog.BATTLE_LEVELS_PER_DIFFICULTY)

	stage_spin.min_value = 1
	stage_spin.max_value = float(Catalog.BATTLE_STAGES_PER_LEVEL)

	wave_spin.min_value = 1
	wave_spin.max_value = float(Catalog.BATTLE_WAVES_PER_STAGE)

	# Current battle position
	var diff: String = String(Game.battle_state.get("difficulty", "Easy"))
	var lvl: int = int(Game.battle_state.get("level", 1))
	var stg: int = int(Game.battle_state.get("stage", 1))
	var wav: int = int(Game.battle_state.get("wave", 1))

	# Select correct difficulty
	var idx: int = _find_option_index(diff_select, diff)
	if idx >= 0:
		diff_select.select(idx)

	level_spin.value = lvl
	stage_spin.value = stg
	wave_spin.value = wav

	_refresh_battle_preview()

func _build_give_dropdown() -> void:
	give_select.clear()
	for i in range(GIVE_ITEMS.size()):
		give_select.add_item(String(GIVE_ITEMS[i]["label"]), i)

func _build_difficulty_dropdown() -> void:
	diff_select.clear()
	for i in range(Catalog.BATTLE_DIFFICULTY_ORDER.size()):
		diff_select.add_item(String(Catalog.BATTLE_DIFFICULTY_ORDER[i]), i)

func _find_option_index(ob: OptionButton, text: String) -> int:
	for i in range(ob.item_count):
		if ob.get_item_text(i) == text:
			return i
	return -1

func _parse_amount() -> int:
	var t := amount_edit.text.strip_edges()
	if not t.is_valid_int():
		return 0
	return int(t)

func _on_give_pressed() -> void:
	var amt: int = _parse_amount()
	if amt == 0:
		Game.inventory_event.emit("Dev: invalid amount.")
		return

	var choice_idx: int = give_select.get_selected_id()
	choice_idx = clampi(choice_idx, 0, GIVE_ITEMS.size() - 1)
	var id: String = String(GIVE_ITEMS[choice_idx]["id"])

	# XP: use add_xp so leveling happens correctly
	if id == "xp":
		var levels: int = Game.player.add_xp(amt)
		Game.player_changed.emit()
		if levels > 0:
			Game.inventory_event.emit("Dev: +%d XP (Lv %d)" % [amt, Game.player.level])
		else:
			Game.inventory_event.emit("Dev: +%d XP" % amt)
		return

	# Direct typed fields for consumables/currencies
	match id:
		"gold":
			Game.player.gold += amt
		"time_vouchers":
			Game.player.time_vouchers += amt
		"diamonds":
			Game.player.diamonds += amt
		"crystals":
			Game.player.crystals += amt
		"crucible_keys":
			Game.player.crucible_keys += amt
		"battlepass_30d":
			var now_unix: int = int(Time.get_unix_time_from_system())
			var days: int = 30
			Game.player.battlepass_expires_unix = now_unix + days * 24 * 60 * 60
			Game.inventory_event.emit("Dev: Battle Pass active for 30 days.")
		"premium_offline":
			Game.player.premium_offline_unlocked = true
			Game.inventory_event.emit("Dev: Premium Offline Bundle unlocked.")

		_:
			Game.inventory_event.emit("Dev: unknown give id '%s'" % id)
			return

	Game.player_changed.emit()
	Game.inventory_event.emit("Dev: +%d %s" % [amt, id])

func _refresh_battle_preview() -> void:
	var diff: String = diff_select.get_item_text(diff_select.selected)
	var lvl: int = int(level_spin.value)
	var stg: int = int(stage_spin.value)
	var wav: int = int(wave_spin.value)

	battle_preview.text = "Preview: %s - Lv %d - Stage %d - Wave %d" % [diff, lvl, stg, wav]

func _on_set_battle_pressed() -> void:
	var diff: String = diff_select.get_item_text(diff_select.selected)
	var lvl: int = int(level_spin.value)
	var stg: int = int(stage_spin.value)
	var wav: int = int(wave_spin.value)

	# Clamp to Catalog limits for safety
	lvl = clampi(lvl, 1, Catalog.BATTLE_LEVELS_PER_DIFFICULTY)
	stg = clampi(stg, 1, Catalog.BATTLE_STAGES_PER_LEVEL)
	wav = clampi(wav, 1, Catalog.BATTLE_WAVES_PER_STAGE)

	# Use a dedicated Game function so combat resets cleanly.
	if Game.has_method("dev_set_battle_position"):
		Game.call("dev_set_battle_position", diff, lvl, stg, wav)
	else:
		# Fallback: patch state only
		Game.patch_battle_state({
			"difficulty": diff,
			"level": lvl,
			"stage": stg,
			"wave": wav,
		})

	Game.inventory_event.emit("Dev: set battle to %s %d-%d W%d" % [diff, lvl, stg, wav])

func _build_offline_controls() -> void:
	# Build UI dynamically so you don't need to edit the DevPopup scene.
	var vbox := $VBox as VBoxContainer
	if vbox == null:
		return

	# Avoid building twice (hot reload, etc.)
	if vbox.get_node_or_null("OfflineRow") != null:
		return

	_offline_row = HBoxContainer.new()
	_offline_row.name = "OfflineRow"
	_offline_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = "Offline:"
	_offline_row.add_child(title)

	_offline_hours = SpinBox.new()
	_offline_hours.min_value = 0
	_offline_hours.max_value = 24
	_offline_hours.step = 1
	_offline_hours.value = 8
	_offline_hours.custom_minimum_size = Vector2(70, 0)
	_offline_row.add_child(_offline_hours)

	var h_lbl := Label.new()
	h_lbl.text = "h"
	_offline_row.add_child(h_lbl)

	_offline_mins = SpinBox.new()
	_offline_mins.min_value = 0
	_offline_mins.max_value = 59
	_offline_mins.step = 1
	_offline_mins.value = 0
	_offline_mins.custom_minimum_size = Vector2(70, 0)
	_offline_row.add_child(_offline_mins)

	var m_lbl := Label.new()
	m_lbl.text = "m"
	_offline_row.add_child(m_lbl)

	_offline_apply = Button.new()
	_offline_apply.text = "Apply"
	_offline_apply.pressed.connect(_on_apply_offline_pressed)
	_offline_row.add_child(_offline_apply)

	_offline_hint = Label.new()
	_offline_hint.text = ""
	_offline_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offline_row.add_child(_offline_hint)

	# Insert it just above CloseButton for a clean layout
	var close_idx := vbox.get_children().find(close_button)
	if close_idx >= 0:
		vbox.add_child(_offline_row)
		vbox.move_child(_offline_row, close_idx)
	else:
		vbox.add_child(_offline_row)

	# Live preview hint
	_offline_hours.value_changed.connect(func(_v: float) -> void: _update_offline_hint())
	_offline_mins.value_changed.connect(func(_v: float) -> void: _update_offline_hint())
	_update_offline_hint()

func _update_offline_hint() -> void:
	if _offline_hint == null:
		return
	var secs: int = int(_offline_hours.value) * 3600 + int(_offline_mins.value) * 60
	var now_unix: int = int(Time.get_unix_time_from_system())
	var cap: int = OfflineRewards.offline_cap_seconds_for_player(Game.player, now_unix)

	if secs > cap:
		_offline_hint.text = "Capped at %dh %dm" % [cap / 3600, (cap % 3600) / 60]
	else:
		_offline_hint.text = ""

func _on_apply_offline_pressed() -> void:
	if Game.player == null:
		Game.inventory_event.emit("Dev: no player.")
		return

	var secs: int = int(_offline_hours.value) * 3600 + int(_offline_mins.value) * 60
	if secs <= 0:
		Game.inventory_event.emit("Dev: offline time must be > 0.")
		return

	# IMPORTANT: clear any existing pending so the dev tool can re-run repeatedly
	Game.player.offline_pending = {}

	var now_unix: int = int(Time.get_unix_time_from_system())
	Game.player.last_active_unix = now_unix - secs

	# Queue rewards (force=true bypasses "already_pending" protection)
	var summary: Dictionary = Game.offline_capture_pending_on_load(true)

	# Save + refresh
	Game.player_changed.emit()
	_refresh_from_game()
	SaveManager.save_now()

	if Game.offline_has_pending():
		var p := OfflinePopup.new()
		p.setup(Game.offline_get_pending())
		Game.popup_root().add_child(p)
		Game.inventory_event.emit("Dev: offline rewards queued.")
	else:
		Game.inventory_event.emit("Dev: no offline rewards queued (%s)." % String(summary.get("reason", "unknown")))

func _on_set_level_pressed() -> void:
	if Game.player == null:
		return
	Game.dev_set_character_level(int(level_spin_box.value), true)

func _offline_cap_seconds() -> int:
	# Base cap
	var cap: int = int(Catalog.OFFLINE_MAX_SECONDS)

	# Add +2h for active battle pass, +2h for premium bundle (matches your design)
	# (If your project later centralizes this in OfflineRewards, you can swap this out.)
	if Game.player == null:
		return cap

	var now_unix: int = int(Time.get_unix_time_from_system())

	if "premium_offline_unlocked" in Game.player and bool(Game.player.premium_offline_unlocked):
		cap += 2 * 3600

	if "battlepass_expires_unix" in Game.player and int(Game.player.battlepass_expires_unix) > now_unix:
		cap += 2 * 3600

	return cap

func _open_offline_popup_via_home() -> void:
	# DevPopup is a child of Home, so walk up and call Home's private opener.
	# This is important because Home wires up "dismissed" -> chest icon behavior.
	var n: Node = self
	while n != null:
		if n.has_method("_open_offline_popup"):
			n.call("_open_offline_popup")
			return
		n = n.get_parent()

	# Fallback: open directly if Home isn't found
	if Game.has_method("offline_get_pending") and Game.has_method("popup_root"):
		var p := OfflinePopup.new()
		p.setup(Game.offline_get_pending())
		Game.popup_root().add_child(p)

func _fmt_mmss(seconds: int) -> String:
	seconds = maxi(0, seconds)
	var m: int = seconds / 60
	var s: int = seconds % 60
	return "%d:%02d" % [m, s]
