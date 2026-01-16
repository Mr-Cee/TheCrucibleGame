extends Control

# Top HUD
@onready var name_label: Label = $RootMargin/RootVBox/TopHUDRow/CharacterHUD/CharacterVBox/NameLabel
@onready var hp_bar: ProgressBar = $RootMargin/RootVBox/TopHUDRow/CharacterHUD/CharacterVBox/HPBar
@onready var xp_bar: ProgressBar = $RootMargin/RootVBox/TopHUDRow/CharacterHUD/CharacterVBox/XPBar
@onready var cp_label: Label = $RootMargin/RootVBox/TopHUDRow/CharacterHUD/CharacterVBox/CPLabel

@onready var name_button: Button = $RootMargin/RootVBox/TopHUDRow/CharacterHUD/CharacterVBox/HeaderRow/NameButton
@onready var class_level_label: Label = $RootMargin/RootVBox/TopHUDRow/CharacterHUD/CharacterVBox/HeaderRow/ClassLevelLabel

@onready var gold_label: Label = $RootMargin/RootVBox/TopHUDRow/CurrencyHUD/CurrencyVBox/GoldLabel
@onready var diamonds_label: Label = $RootMargin/RootVBox/TopHUDRow/CurrencyHUD/CurrencyVBox/DiamondsLabel
@onready var crystals_label: Label = $RootMargin/RootVBox/TopHUDRow/CurrencyHUD/CurrencyVBox/CrystalsLabel

# Crucible UI
@onready var crucible_panel: PanelContainer = $RootMargin/RootVBox/CrucibleRow/CruciblePanel
@onready var upgrade_button: Button = $RootMargin/RootVBox/CrucibleRow/CrucibleSideButtons/UpgradeButton
@onready var filter_button: Button = $RootMargin/RootVBox/CrucibleRow/CrucibleSideButtons/FilterButton

#Crucible Upgrade Popup
@onready var crucible_upgrade_popup: Window = $CrucibleUpgradePopup


# Compare Popup
@onready var compare_popup: Window = $ComparePopup
@onready var new_item_label: RichTextLabel = $ComparePopup/RootVBox/CardsRow/LeftCol/NewCard/Margin/NewItemLabel
@onready var equipped_item_label: RichTextLabel = $ComparePopup/RootVBox/CardsRow/RightCol/EquippedCard/Margin/EquippedItemLabel

@onready var equip_button: Button = $ComparePopup/RootVBox/CardsRow/LeftCol/LeftButtonsRow/EquipButton
@onready var sell_button: Button = $ComparePopup/RootVBox/CardsRow/LeftCol/LeftButtonsRow/SellButton
@onready var close_button: Button = $ComparePopup/RootVBox/CardsRow/LeftCol/LeftButtonsRow/CloseButton


@onready var gear_strip: HBoxContainer = $RootMargin/RootVBox/GearStrip

@onready var auto_popup: Window = $AutoPopup
@onready var batch_option: OptionButton = $AutoPopup/VBox/RowBatch/BatchOption
@onready var lock_info_label: Label = $AutoPopup/VBox/LockInfoLabel
@onready var rarity_option: OptionButton = $AutoPopup/VBox/RowRarity/RarityOption
@onready var auto_sell_check: CheckButton = $AutoPopup/VBox/AutoSellCheck
@onready var cooldown_label: Label = $AutoPopup/VBox/CooldownLabel
@onready var auto_close_button: Button = $AutoPopup/VBox/CloseButton
@onready var auto_status_label: Label = $AutoPopup/VBox/AutoStatusLabel
@onready var start_stop_button: Button = $AutoPopup/VBox/StartStopButton

@onready var voucher_popup: Window = $VoucherPopup
@onready var vp_info_label: Label = $VoucherPopup/VBox/InfoLabel
@onready var vp_count_edit: LineEdit = $VoucherPopup/VBox/Row/CountEdit
@onready var vp_use_label: Label = $VoucherPopup/VBox/UseLabel

@onready var vp_minus: Button = $VoucherPopup/VBox/Row/MinusButton
@onready var vp_plus: Button = $VoucherPopup/VBox/Row/PlusButton
@onready var vp_max: Button = $VoucherPopup/VBox/Row/MaxButton

@onready var vp_use: Button = $VoucherPopup/VBox/ButtonsRow/UseButton
@onready var vp_cancel: Button = $VoucherPopup/VBox/ButtonsRow/CancelButton

@onready var dev_popup: Window = $DevPopup

@onready var skills_button: Button = $RootMargin/RootVBox/TownNav/TownNavRow/SkillsBtn
#@onready var passive_test_btn: Button = $RootMargin/RootVBox/TownNav/TownNavRow/PassiveTest



#----------------------------------------------------------------

signal compare_resolved


var _crucible := CrucibleSystem.new()

enum PopupMode { COMPARE, DETAILS }
var _popup_mode: int = PopupMode.COMPARE
var _pending_item: GearItem
var _pending_item_from_deferred: bool = false
var _equipped_snapshot: GearItem
var _details_slot_id: int = -1

const BATCH_CHOICES: Array[int] = [1, 2, 4, 6, 8, 10]
const BATCH_UNLOCK_LEVEL := { 2: 4, 4: 6, 6: 10, 8: 12, 10: 15 }

# Display order (independent of enum numeric IDs)
const RARITY_ORDER: Array[int] = [
	Catalog.Rarity.COMMON,
	Catalog.Rarity.UNCOMMON,
	Catalog.Rarity.RARE,
	Catalog.Rarity.UNIQUE,
	Catalog.Rarity.LEGENDARY,
	Catalog.Rarity.MYTHIC,
	Catalog.Rarity.IMMORTAL,
	Catalog.Rarity.SUPREME,
	Catalog.Rarity.AUROUS,
	Catalog.Rarity.ETERNAL,
]
var _auto_running: bool = false
var _auto_cancel_token: int = 0

var _vp_count: int = 0

var _batch_running: bool = false

var _hud_ui_accum: float = 0.0
var _class_select_overlay: Control = null

func _fmt_mmss(seconds: int) -> String:
	seconds = max(0, seconds)
	var m: int = seconds / 60
	var s: int = seconds % 60
	return "%d:%02d" % [m, s]

var _dev_tap_count: int = 0
var _dev_tap_deadline_ms: int = 0

const DEV_TAPS_REQUIRED: int = 7
const DEV_TAP_WINDOW_MS: int = 1500

var _class_selected_id: int = -1
var _class_confirm_btn: Button = null
var _class_hint_lbl: Label = null
var _class_cards: Dictionary = {} # class_id -> PanelContainer

const RENAME_COST_CRYSTALS := 1000

var _rename_overlay: Control = null
var _rename_line: LineEdit = null
var _rename_status: Label = null
var _rename_confirm: Button = null

# Crucible Art UI (replaces panel + draw button)
@onready var crucible_row: Control = $RootMargin/RootVBox/CrucibleRow
const CRUCIBLE_TEX := preload("res://assets/UI/crucible.png")
const CRUCIBLE_SHEET_TEX := preload("res://assets/UI/crucible_spritesheet.png")
const CRUCIBLE_IDLE_TEX := preload("res://assets/UI/crucible.png")

const CRUCIBLE_SHEET_COLS := 5
const CRUCIBLE_SHEET_ROWS := 5
const CRUCIBLE_FRAME_COUNT := 24
const CRUCIBLE_FRAME_SIZE := Vector2i(256, 256) # 1280/5

const CRUCIBLE_FPS := 18.0 # tweak to taste               # animation speed

var _crucible_click_frames: Array[Texture2D] = []
var _crucible_animating: bool = false


var _crucible_art_vbox: VBoxContainer = null
var _crucible_art_btn: TextureButton = null
var _crucible_keys_count_label: Label = null
var _crucible_btn_base_scale: Vector2 = Vector2.ONE
var _crucible_click_tween: Tween = null


func _on_skills_pressed() -> void:
	var p := SkillsPanel.new()
	Game.popup_root().add_child(p)

func _refresh_skill_buttons() -> void:
	for i in range(5):
		var btn: Button = get_node("SkillBtn%d" % (i + 1))
		var id := Game.get_equipped_active_skill_id(i)
		if id == "":
			btn.text = "(Empty)"
			btn.disabled = true
			continue

		var def := SkillCatalog.get_def(id)
		var name := def.display_name if def != null else id

		var rem := Game.get_skill_cooldown_remaining(i)
		if rem > 0.0:
			btn.text = "%s\n%.1fs" % [name, rem]
			btn.disabled = true
		else:
			btn.text = name
			btn.disabled = false
#-------------------------------------------------------------------------

func _ready() -> void:
	# Existing connections...
	Game.inventory_event.connect(_on_inventory_event)
	equip_button.pressed.connect(_on_equip_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	close_button.pressed.connect(_on_close_pressed)
	skills_button.pressed.connect(_on_skills_pressed)
	dev_popup.visible = false
	
	$RootMargin/RootVBox/BattleSection/SkillsRow/AutoSkillsToggle.button_pressed = Game.skills_auto_enabled()
	$RootMargin/RootVBox/BattleSection/SkillsRow/AutoSkillsToggle.toggled.connect(func(v: bool) -> void:
		Game.set_skills_auto_enabled(v)
	)
	if cp_label:
		cp_label.gui_input.connect(_on_cp_label_gui_input)

	
	# Connect Crucible draw signal
	if crucible_panel.has_signal("draw_pressed"):
		crucible_panel.connect("draw_pressed", _on_crucible_draw_pressed)
	else:
		push_warning("CruciblePanel has no draw_pressed signal. Is CruciblePanel.gd attached to the node?")
	_setup_crucible_art_ui()
	_build_crucible_click_frames()
	_set_crucible_button_texture(CRUCIBLE_IDLE_TEX)

	compare_popup.visible = false

	# Connect GearStrip signal (slot clicks)
	if gear_strip.has_signal("slot_clicked"):
		gear_strip.connect("slot_clicked", _on_gear_slot_clicked)

	filter_button.pressed.connect(_on_filter_pressed)
	auto_close_button.pressed.connect(func() -> void: auto_popup.visible = false)

	batch_option.item_selected.connect(_on_batch_selected)
	rarity_option.item_selected.connect(_on_rarity_selected)
	auto_sell_check.toggled.connect(_on_auto_sell_toggled)
	start_stop_button.pressed.connect(_on_start_stop_auto_pressed)
	
	
	#Crucible Upgrade Popup
	upgrade_button.pressed.connect(func() -> void:
		crucible_upgrade_popup.call("popup_and_refresh")
	)

	auto_popup.visible = false
	filter_button.toggle_mode = true
	
	_update_auto_indicator()
	
	voucher_popup.visible = false

	vp_minus.pressed.connect(func() -> void: _vp_adjust(-1))
	vp_plus.pressed.connect(func() -> void: _vp_adjust(1))
	
	vp_max.pressed.connect(_vp_set_max)

	vp_use.pressed.connect(_vp_apply)
	vp_cancel.pressed.connect(func() -> void: voucher_popup.visible = false)

	vp_count_edit.text_submitted.connect(func(_t:String) -> void: _vp_from_edit())
	vp_count_edit.focus_exited.connect(_vp_from_edit)

	# If your CruciblePanel emits draw_pressed, keep that hookup as you already have it
	# ... plus your existing HUD refresh hookup ...
	Game.player_changed.connect(_refresh_hud_nonbattle)
	_refresh_hud_nonbattle()
	
	Game.player_changed.connect(_refresh_character_header)
	_refresh_character_header()
	name_button.pressed.connect(_open_rename_popup)
	
	# Force class selection before battle begins (new games only).
	call_deferred("_maybe_prompt_class_selection")
	
	call_deferred("_maybe_prompt_advanced_class_selection")
	Game.player_changed.connect(func() -> void:
		call_deferred("_maybe_prompt_advanced_class_selection")
	)

func _process(delta: float) -> void:
	_hud_ui_accum += delta
	if _hud_ui_accum < 0.10:
		return
	_hud_ui_accum = 0.0

	if not is_instance_valid(hp_bar):
		return

	var phpmax_raw: float = float(Game.battle_runtime.get("player_hp_max", 0.0))
	if phpmax_raw <= 0.0:
		# Battle not initialized yet; don't stomp the bar.
		return

	var php: float = float(Game.battle_runtime.get("player_hp", 0.0))
	var phpmax: float = max(1.0, phpmax_raw)

	hp_bar.max_value = 100.0
	hp_bar.value = (php / phpmax) * 100.0

func _on_gear_slot_clicked(slot_id: int, item: GearItem) -> void:
	# Ignore future slots (they’re disabled anyway, but safe)
	_details_slot_id = slot_id
	show_details(slot_id, item)

func show_details(slot_id: int, item: GearItem) -> void:
	_popup_mode = PopupMode.DETAILS
	_pending_item = null
	_equipped_snapshot = item

	new_item_label.bbcode_enabled = true
	equipped_item_label.bbcode_enabled = true

	var slot_name: String = String(Catalog.GEAR_SLOT_NAMES.get(slot_id, "Slot"))

	# In details mode we show the item on the left and leave "Equipped" blank
	if item == null:
		new_item_label.text = "[b]%s:[/b]\n(None)" % slot_name
		equipped_item_label.text = ""
		#unequip_button.visible = false
	else:
		new_item_label.text = "[b]%s:[/b]\n%s" % [slot_name, item.to_bbcode()]
		equipped_item_label.text = ""
		#unequip_button.visible = true

	# Buttons: details mode has no equip/sell
	equip_button.visible = false
	sell_button.visible = false
	close_button.visible = true

	compare_popup.popup_centered(Vector2i(520, 420))

func _calc_item_cp_for_slot(slot_id: int, item: GearItem) -> int:
	if item == null:
		return 0

	var p: PlayerModel = Game.player
	if p == null:
		return 0

	var saved: GearItem = p.equipped.get(slot_id, null)

	# CP with slot empty
	p.equipped[slot_id] = null
	var base_cp: int = int(p.combat_power())

	# CP with candidate item equipped
	p.equipped[slot_id] = item
	var with_cp: int = int(p.combat_power())

	# Restore original
	p.equipped[slot_id] = saved

	return with_cp - base_cp

func show_compare(item: GearItem, from_deferred: bool = false) -> void:
	_popup_mode = PopupMode.COMPARE
	_pending_item = item
	_pending_item_from_deferred = from_deferred
	_details_slot_id = -1

	_equipped_snapshot = Game.player.equipped.get(item.slot, null)

	new_item_label.bbcode_enabled = true
	equipped_item_label.bbcode_enabled = true

	# --- CP calculations (slot contribution) ---
	var new_cp: int = _calc_item_cp_for_slot(item.slot, item)
	var eq_cp: int = 0
	if _equipped_snapshot != null:
		eq_cp = _calc_item_cp_for_slot(item.slot, _equipped_snapshot)

	var delta: int = new_cp - eq_cp

	# Build single-line CP text with colored delta
	var cp_line: String = "[b]CP:[/b] %d" % new_cp
	if  delta != 0:
		var col: String = "00ff66" if delta > 0 else "ff4444"
		var sign: String = "+" if delta > 0 else ""
		cp_line += " [color=#%s](%s%d)[/color]" % [col, sign, delta]
	elif _equipped_snapshot != null and delta == 0:
		cp_line += " [color=#bbbbbb](+0)[/color]"

	# --- Build BBCode text ---
	new_item_label.text = "[b]New:[/b]\n%s\n%s" % [cp_line, item.to_bbcode()]

	if _equipped_snapshot != null:
		equipped_item_label.text = "[b]Equipped:[/b]\n[b]CP:[/b] %d\n%s" % [
			eq_cp,
			_equipped_snapshot.to_bbcode()
		]
	else:
		equipped_item_label.text = "[b]Equipped:[/b]\n[b]CP:[/b] 0\n(None)"

	# Buttons: compare mode uses equip/sell
	equip_button.visible = true
	sell_button.visible = true
	close_button.visible = true

	compare_popup.popup_centered(Vector2i(520, 420))

func _show_compare_and_wait(item: GearItem, from_deferred: bool = false) -> void:
	show_compare(item, from_deferred)
	await compare_resolved

func _on_equip_pressed() -> void:
	if _pending_item == null:
		return

	# If this item came from deferred queue, consuming it is correct because
	# equipping it is a real decision.
	if _pending_item_from_deferred:
		_consume_deferred_head()
		_pending_item_from_deferred = false

	var old := Game.equip_item(_pending_item)

	# If we swapped something out, continue comparing the old item (not deferred yet).
	if old != null:
		show_compare(old, false)
		return

	# Done
	compare_popup.visible = false
	emit_signal("compare_resolved")

func _on_sell_pressed() -> void:
	if _pending_item == null:
		return

	if _pending_item_from_deferred:
		_consume_deferred_head()
		_pending_item_from_deferred = false

	Game.sell_item(_pending_item)
	compare_popup.visible = false
	emit_signal("compare_resolved")

func _on_unequip_pressed() -> void:
	if _popup_mode != PopupMode.DETAILS:
		return
	if _details_slot_id == -1:
		return

	# Unequip = set slot to null
	Game.player.equipped[_details_slot_id] = null
	Game.player_changed.emit()
	compare_popup.visible = false

func _on_close_pressed() -> void:
	if _pending_item != null:
		# If it was already deferred, keep it deferred.
		# If it was a fresh roll/swap, enqueue it.
		if not _pending_item_from_deferred:
			_enqueue_deferred(_pending_item)
			Game.inventory_event.emit("Saved item for later. Resolve it before drawing again.")
			# Important: stop auto so it doesn't spam the same item
			_stop_auto_draw()

	compare_popup.visible = false
	emit_signal("compare_resolved")

func _on_inventory_event(msg: String) -> void:
	print(msg)
	
func _refresh_hud_nonbattle() -> void:
	var p := Game.player

	if is_instance_valid(name_label):
		name_label.text = "Hero"
	if is_instance_valid(cp_label):
		cp_label.text = "CP: %d" % p.combat_power()

	# DO NOT touch hp_bar here. HP is driven by battle_runtime in _process().

	if is_instance_valid(xp_bar):
		xp_bar.min_value = 0
		xp_bar.max_value = Game.player.xp_required_for_next_level()
		xp_bar.value = Game.player.xp

	if is_instance_valid(gold_label):
		gold_label.text = "Gold: %d" % p.gold
	if is_instance_valid(diamonds_label):
		diamonds_label.text = "Diamonds: %d" % p.diamonds
	if is_instance_valid(crystals_label):
		crystals_label.text = "Crystals: %d" % p.crystals

	var pending: int = 0
	if "deferred_gear" in p:
		pending = int(p.deferred_gear.size())

	if is_instance_valid(crucible_panel) and crucible_panel.has_method("set_crucible_hud"):
		crucible_panel.call("set_crucible_hud", p.crucible_keys, p.crucible_level, int(p.crucible_batch), pending)
	
	if is_instance_valid(_crucible_keys_count_label):
		_crucible_keys_count_label.text = str(int(p.crucible_keys))


func _on_crucible_draw_pressed() -> void:
	# Manual draw stops auto
	_stop_auto_draw()

	# If there is a deferred item, resolve it first (no keys spent)
	if _has_deferred_item():
		await _show_compare_and_wait(_peek_deferred_item(), true)
		return

	var p := Game.player
	var batch: int = int(p.crucible_batch)
	if not _is_batch_unlocked(batch, p.crucible_level):
		batch = 1

	var spent: int = Game.spend_crucible_keys(batch)

	if spent <= 0:
		Game.inventory_event.emit("No keys available.")
		return
		
	if "task_system" in Game and Game.task_system != null:
		Game.task_system.notify_crucible_drawn(spent)


	# Generate all items and queue them for decisions
	var to_queue: Array[GearItem] = []
	for i in range(spent):
		var item: GearItem = _crucible.roll_item_for_player(p)
		to_queue.append(item)

		var xp_gain: int = Catalog.crucible_xp_for_draw(p.level, item.item_level, item.rarity)
		var levels: int = Game.player.add_xp(xp_gain)
		if levels > 0:
			Game.inventory_event.emit("Level Up! Lv.%d" % Game.player.level)

	# Emit once after the whole batch to avoid spamming save/UI
	Game.player_changed.emit()

	_enqueue_deferred_many(to_queue)

	# Show first queued item immediately
	await _show_compare_and_wait(_peek_deferred_item(), true)

func _run_batch_draw(batch: int, token: int) -> void:
	var p := Game.player
	var min_rarity: int = int(p.crucible_rarity_min)
	var auto_sell: bool = bool(p.crucible_auto_sell_below)

	# If we already have a deferred item, resolve it first (no new keys spent).
	if _has_deferred_item():
		# Don’t animate/show if auto was cancelled.
		if not _auto_running or token != _auto_cancel_token:
			return
		await _await_crucible_click_anim_if_possible()
		# Re-check after awaiting animation.
		if not _auto_running or token != _auto_cancel_token:
			return
		await _show_compare_and_wait(_peek_deferred_item(), true)
		return

	# Spend the whole batch up front.
	if not _auto_running or token != _auto_cancel_token:
		return

	var spent: int = Game.spend_crucible_keys(batch)
	if spent <= 0:
		Game.inventory_event.emit("Auto stopped: no keys.")
		_stop_auto_draw()
		return
		
	# Always animate the crucible for an auto batch, even if no compare window will appear.
	if not _auto_running or token != _auto_cancel_token:
		return
	await _await_crucible_click_anim_if_possible()
	if not _auto_running or token != _auto_cancel_token:
		return

	if "task_system" in Game and Game.task_system != null:
		Game.task_system.notify_crucible_drawn(spent)

	# Generate items immediately; enqueue ONLY the ones we intend to show.
	var to_queue: Array[GearItem] = []

	for i in range(spent):
		if not _auto_running or token != _auto_cancel_token:
			return

		var item: GearItem = _crucible.roll_item_for_player(p)

		# XP per draw
		var xp_gain: int = Catalog.crucible_xp_for_draw(p.level, item.item_level, item.rarity)
		var levels: int = Game.player.add_xp(xp_gain)
		Game.player_changed.emit()
		if levels > 0:
			Game.inventory_event.emit("Level Up! Lv.%d" % Game.player.level)

		var meets: bool = _rarity_meets_threshold(item.rarity, min_rarity)

		if meets:
			to_queue.append(item)
		else:
			# Below filter: never show when a filter is active.
			# If auto-sell: sell; otherwise silently skip (discard).
			if auto_sell:
				Game.sell_item(item)

	# Enqueue all decision items.
	if to_queue.size() > 0:
		_enqueue_deferred_many(to_queue)

	# Present the next deferred item (if any), and wait for a decision.
	if _has_deferred_item():
		if not _auto_running or token != _auto_cancel_token:
			return
		await _show_compare_and_wait(_peek_deferred_item(), true)



func _run_auto_loop(token: int) -> void:
	# Continuous auto: keep drawing batches until stopped or out of keys.
	while _auto_running and token == _auto_cancel_token:
		var p := Game.player
		var batch: int = int(p.crucible_batch)

		# Enforce locks; if locked, fallback to 1
		if not _is_batch_unlocked(batch, int(p.crucible_level)):
			batch = 1

		# If no keys, stop auto
		if int(p.crucible_keys) <= 0:
			Game.inventory_event.emit("Auto stopped: no keys.")
			_stop_auto_draw()
			return

		# Run one batch instantly (no per-item cooldown)
		await _run_batch_draw(batch, token)

		if not _auto_running or token != _auto_cancel_token:
			return

		# Cooldown BETWEEN batches (applies to batch=1 as well)
		var cd: float = float(Game.crucible_draw_cooldown())
		cd = max(0.05, cd)
		await get_tree().create_timer(cd).timeout

func _rarity_meets_threshold(rarity_id: int, min_rarity_id: int) -> bool:
	var r_idx := RARITY_ORDER.find(rarity_id)
	var m_idx := RARITY_ORDER.find(min_rarity_id)
	if r_idx == -1 or m_idx == -1:
		# If unknown, be conservative and show it
		return true
	return r_idx >= m_idx

func _on_filter_pressed() -> void:
	if _auto_running:
		_stop_auto_draw()
	
	_refresh_auto_popup()
	_update_auto_popup_status()
	auto_popup.popup_centered(Vector2i(560, 360))

func _refresh_auto_popup() -> void:
	var p := Game.player
	var cl: int = p.crucible_level

	# Cooldown display (read-only for now)
	cooldown_label.text = "Cooldown: %.2fs" % Game.crucible_draw_cooldown()

	# Batch option
	batch_option.clear()
	for i in range(BATCH_CHOICES.size()):
		var b := BATCH_CHOICES[i]
		batch_option.add_item("%dx" % b, b)

		var req: int = int(BATCH_UNLOCK_LEVEL.get(b, 0))
		var locked := (req > 0 and cl < req)
		batch_option.get_popup().set_item_disabled(i, locked)

	# Select current batch, fallback to 1 if locked
	var desired_batch: int = int(p.crucible_batch)
	if not _is_batch_unlocked(desired_batch, cl):
		desired_batch = 1
		p.crucible_batch = 1
		Game.player_changed.emit()

	_select_option_by_id(batch_option, desired_batch)

	# Lock info text
	lock_info_label.text = "Unlocks: 2@Lv4, 4@Lv6, 6@Lv10, 8@Lv12, 10@Lv15 (Crucible Lv.%d)" % cl

	# Rarity option
	rarity_option.clear()
	for rid in RARITY_ORDER:
		var name := String(Catalog.RARITY_NAMES.get(rid, "Rarity"))
		rarity_option.add_item(name, int(rid))

	_select_option_by_id(rarity_option, int(p.crucible_rarity_min))

	auto_sell_check.button_pressed = bool(p.crucible_auto_sell_below)

func _is_batch_unlocked(batch: int, crucible_level: int) -> bool:
	var req: int = int(BATCH_UNLOCK_LEVEL.get(batch, 0))
	return req == 0 or crucible_level >= req

func _select_option_by_id(opt: OptionButton, id: int) -> void:
	for i in range(opt.item_count):
		if opt.get_item_id(i) == id:
			opt.selected = i
			return
	# fallback
	opt.selected = 0

func _on_batch_selected(index: int) -> void:
	var p := Game.player
	var chosen: int = batch_option.get_item_id(index)
	if not _is_batch_unlocked(chosen, p.crucible_level):
		# snap back
		_refresh_auto_popup()
		return
	p.crucible_batch = chosen
	Game.player_changed.emit()

func _on_rarity_selected(index: int) -> void:
	Game.player.crucible_rarity_min = rarity_option.get_item_id(index)
	Game.player_changed.emit()

func _on_auto_sell_toggled(on: bool) -> void:
	Game.player.crucible_auto_sell_below = on
	Game.player_changed.emit()

func _update_auto_popup_status() -> void:
	if _auto_running:
		auto_status_label.text = "Auto: ON"
		start_stop_button.text = "Stop Auto"
	else:
		auto_status_label.text = "Auto: OFF"
		start_stop_button.text = "Start Auto"
		
	_update_auto_indicator()

func _stop_auto_draw() -> void:
	if not _auto_running:
		return
	_auto_running = false
	_auto_cancel_token += 1
	_update_auto_popup_status()

func _start_auto_draw() -> void:
	if _auto_running:
		return

	_auto_running = true
	_auto_cancel_token += 1
	_update_auto_popup_status()

	var token := _auto_cancel_token

	if _has_deferred_item():
		await _await_crucible_click_anim_if_possible()
		await _show_compare_and_wait(_peek_deferred_item(), true)
		if not _auto_running or token != _auto_cancel_token:
			return


	_run_auto_loop(token) # fire-and-forget (async)

func _on_start_stop_auto_pressed() -> void:
	if _auto_running:
		_stop_auto_draw()
	else:
		# Refresh UI in case something is locked/unlocked since last open
		_refresh_auto_popup()
		_start_auto_draw()
		
	#Close the popup when starting auto
	auto_popup.visible = false

func _has_deferred_item() -> bool:
	return Game.player.deferred_gear.size() > 0

func _peek_deferred_item() -> GearItem:
	var d: Dictionary = Game.player.deferred_gear[0]
	return GearItem.from_dict(d)

func _consume_deferred_head() -> void:
	if Game.player.deferred_gear.size() > 0:
		Game.player.deferred_gear.remove_at(0)
		Game.player_changed.emit() # triggers save

func _enqueue_deferred(item: GearItem) -> void:
	# Prevent accidentally enqueuing null
	if item == null:
		return
	Game.player.deferred_gear.append(item.to_dict())
	Game.player_changed.emit() # triggers save

func _enqueue_deferred_many(items: Array[GearItem]) -> void:
	if items.is_empty():
		return
	for it in items:
		Game.player.deferred_gear.append(it.to_dict())
	Game.player_changed.emit()

func _update_auto_indicator() -> void:
	# Highlight the button while auto is running
	filter_button.button_pressed = _auto_running

	# Optional: also adjust text/tooltip for clarity
	if _auto_running:
		filter_button.text = "Auto: ON"
		filter_button.tooltip_text = "Auto is running. Tap to open settings (auto will stop)."
	else:
		filter_button.text = "Auto"
		filter_button.tooltip_text = "Auto/Filter settings"

func open_voucher_popup() -> void:
	if not Game.crucible_is_upgrading():
		Game.inventory_event.emit("No active upgrade to speed up.")
		return

	_vp_count = 0
	_vp_refresh_ui()
	voucher_popup.popup_centered(Vector2i(520, 260))

func _vp_seconds_remaining() -> int:
	return int(Game.crucible_upgrade_seconds_remaining())

func _vp_vouchers_owned() -> int:
	return int(Game.player.time_vouchers)

func _vp_needed_to_finish() -> int:
	var remain: int = _vp_seconds_remaining()
	if remain <= 0:
		return 0
	var per: int = int(Game.TIME_VOUCHER_SECONDS) # if TIME_VOUCHER_SECONDS is in Game
	if per <= 0:
		per = 300
	# Ceil division
	return int((remain + per - 1) / per)

func _vp_set_count(new_count: int) -> void:
	var owned: int = _vp_vouchers_owned()
	_vp_count = clampi(new_count, 0, owned)
	_vp_refresh_ui()

func _vp_adjust(delta: int) -> void:
	_vp_set_count(_vp_count + delta)

func _vp_set_max() -> void:
	var need: int = _vp_needed_to_finish()
	var owned: int = _vp_vouchers_owned()
	_vp_set_count(mini(need, owned))

func _vp_from_edit() -> void:
	var t := vp_count_edit.text.strip_edges()
	var n: int = 0
	if t.is_valid_int():
		n = int(t)
	_vp_set_count(n)

func _vp_refresh_ui() -> void:
	var remain: int = _vp_seconds_remaining()
	var owned: int = _vp_vouchers_owned()
	var need: int = _vp_needed_to_finish()

	vp_info_label.text = "Remaining: %s  |  You have: %d vouchers  |  Need: %d" % [
		_fmt_mmss(remain), owned, need
	]

	vp_count_edit.text = str(_vp_count)

	var speedup_secs: int = _vp_count * 300
	vp_use_label.text = "Speed Up: %s" % _fmt_mmss(speedup_secs)

	# Disable Use if nothing selected or no upgrade
	vp_use.disabled = (_vp_count <= 0 or not Game.crucible_is_upgrading())

	# Disable +/- appropriately
	vp_minus.disabled = (_vp_count <= 0)
	vp_plus.disabled = (_vp_count >= owned)

	# Max disabled if already at max or nothing needed
	var max_target: int = mini(need, owned)
	vp_max.disabled = (max_target <= 0 or _vp_count == max_target)

func _vp_apply() -> void:
	if _vp_count <= 0:
		return
	if not Game.crucible_is_upgrading():
		voucher_popup.visible = false
		return

	var used: int = Game.use_time_voucher_on_crucible(_vp_count)
	if used <= 0:
		_vp_refresh_ui()
		return

	# Refresh in case the upgrade completed
	_vp_count = 0
	_vp_refresh_ui()

	# If upgrade completed, close popup
	if not Game.crucible_is_upgrading():
		voucher_popup.visible = false

func _on_cp_label_gui_input(ev: InputEvent) -> void:
	var pressed: bool = false

	if ev is InputEventMouseButton:
		pressed = ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT
	elif ev is InputEventScreenTouch:
		pressed = ev.pressed

	if not pressed:
		return

	var now: int = Time.get_ticks_msec()
	if now > _dev_tap_deadline_ms:
		_dev_tap_count = 0

	_dev_tap_count += 1
	_dev_tap_deadline_ms = now + DEV_TAP_WINDOW_MS

	if _dev_tap_count >= DEV_TAPS_REQUIRED:
		_dev_tap_count = 0
		if dev_popup and dev_popup.has_method("popup_and_refresh"):
			dev_popup.call("popup_and_refresh")
		elif dev_popup:
			dev_popup.popup_centered(Vector2i(620, 360))

func _maybe_prompt_class_selection() -> void:
	if _class_select_overlay != null:
		return
	if Game.player == null:
		return
	if int(Game.player.class_id) >= 0:
		return

	_class_selected_id = -1
	_class_cards.clear()

	# Full-screen modal overlay
	_class_select_overlay = Control.new()
	_class_select_overlay.name = "ClassSelectOverlay"
	_class_select_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_class_select_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_class_select_overlay.focus_mode = Control.FOCUS_ALL
	#add_child(_class_select_overlay)
	Game.popup_root().add_child(_class_select_overlay)
	_class_select_overlay.grab_focus()

	# Dim background
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.80)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_class_select_overlay.add_child(dim)

	# Main shell panel
	var shell := PanelContainer.new()
	shell.anchor_left = 0.5
	shell.anchor_right = 0.5
	shell.anchor_top = 0.5
	shell.anchor_bottom = 0.5
	shell.offset_left = -520
	shell.offset_right = 520
	shell.offset_top = -310
	shell.offset_bottom = 310
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	_class_select_overlay.add_child(shell)

	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = Color(0.10, 0.10, 0.10, 0.98)
	shell_style.corner_radius_top_left = 10
	shell_style.corner_radius_top_right = 10
	shell_style.corner_radius_bottom_left = 10
	shell_style.corner_radius_bottom_right = 10
	shell_style.set_border_width_all(1)
	shell_style.border_color = Color(0.20, 0.20, 0.20, 1.0)
	shell.add_theme_stylebox_override("panel", shell_style)

	var root := VBoxContainer.new()
	root.offset_left = 18
	root.offset_right = -18
	root.offset_top = 14
	root.offset_bottom = -14
	shell.add_child(root)

	var title := Label.new()
	title.text = "Choose Your Starting Class"
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "This determines your base stat multipliers"
	subtitle.modulate = Color(0.85, 0.85, 0.85, 1.0)
	root.add_child(subtitle)

	root.add_child(HSeparator.new())

	var cards_row := HBoxContainer.new()
	cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_row.add_theme_constant_override("separation", 14)
	root.add_child(cards_row)

	# Warrior (orange)
	var war := _make_class_card(
		PlayerModel.ClassId.WARRIOR,
		"Warrior",
		"Frontline bruiser with high durability.",
		_advances_at_25_text(PlayerModel.ClassId.WARRIOR),
		1.40, 1.30, 0.85,
		Color(1.00, 0.55, 0.20, 1.0)
	)
	cards_row.add_child(war)
	_class_cards[PlayerModel.ClassId.WARRIOR] = war

	# Mage (purple)
	var mag := _make_class_card(
		PlayerModel.ClassId.MAGE,
		"Mage",
		"High damage caster with low defenses.",
		_advances_at_25_text(PlayerModel.ClassId.MAGE),
		0.85, 0.80, 1.40,
		Color(0.72, 0.42, 1.00, 1.0)
	)
	cards_row.add_child(mag)
	_class_cards[PlayerModel.ClassId.MAGE] = mag

	# Archer (green)
	var arc := _make_class_card(
		PlayerModel.ClassId.ARCHER,
		"Archer",
		"Balanced ranged damage with speed and flexibility.",
		_advances_at_25_text(PlayerModel.ClassId.ARCHER),
		1.10, 1.00, 1.10,
		Color(0.30, 1.00, 0.55, 1.0)
	)
	cards_row.add_child(arc)
	_class_cards[PlayerModel.ClassId.ARCHER] = arc

	root.add_child(HSeparator.new())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)

	_class_hint_lbl = Label.new()
	_class_hint_lbl.text = "Select a class, then confirm."
	_class_hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_class_hint_lbl)

	_class_confirm_btn = Button.new()
	_class_confirm_btn.text = "Confirm"
	_class_confirm_btn.disabled = true
	_class_confirm_btn.pressed.connect(func() -> void:
		if _class_selected_id >= 0:
			_choose_class(_class_selected_id)
	)
	footer.add_child(_class_confirm_btn)

	_refresh_class_card_styles()

func _choose_class(class_id: int) -> void:
	if Game.player == null:
		return

	Game.player.class_id = class_id

	# If your skills/class framework exists, reset and seed it for the chosen base class.
	# (This prevents “carrying” warrior starter skills into mage, etc.)
	if Game.player.has_method("ensure_class_and_skills_initialized"):
		if "class_def_id" in Game.player:
			var base_def: ClassDef = ClassCatalog.base_def_for_class_id(class_id)
			Game.player.class_def_id = base_def.id if base_def != null else ""

		# These properties exist in your skill framework—leave if present in your project.
		if Game.player.has_method("set"): # always true, but harmless
			# If these properties exist, clearing them forces reseed.
			if Game.player.get("skill_levels") != null:
				Game.player.skill_levels = {}
			if Game.player.get("equipped_active_skills") != null:
				Game.player.equipped_active_skills = []
			if Game.player.get("equipped_passive_skills") != null:
				Game.player.equipped_passive_skills = []
		Game.player.ensure_class_and_skills_initialized()

	# Start battle normally from a clean baseline
	Game.reset_battle_state()
	Game.player_changed.emit()
	SaveManager.save_now()

	if _class_select_overlay != null:
		_class_select_overlay.queue_free()
		_class_select_overlay = null

func _unhandled_input(event: InputEvent) -> void:
	if _class_select_overlay == null:
		return

	# Swallow escape / cancel so the popup cannot be dismissed.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()

func _make_class_card(class_id: int, name: String, blurb: String, advances: String,
		hp_mult: float, armor_mult: float, dmg_mult: float, accent: Color) -> PanelContainer:

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.12, 0.12, 0.12, 1.0)
	st.corner_radius_top_left = 10
	st.corner_radius_top_right = 10
	st.corner_radius_bottom_left = 10
	st.corner_radius_bottom_right = 10
	st.set_border_width_all(2)
	st.border_color = accent

	card.set_meta("accent", accent)
	card.set_meta("base_style", st)
	card.add_theme_stylebox_override("panel", st)

	var v := VBoxContainer.new()
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 12
	v.offset_bottom = -12
	card.add_child(v)

	var header := Label.new()
	header.text = name
	header.add_theme_font_size_override("font_size", 18)
	v.add_child(header)

	var desc := Label.new()
	desc.text = blurb
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.modulate = Color(0.90, 0.90, 0.90, 1.0)
	v.add_child(desc)

	var adv := Label.new()
	adv.text = advances
	adv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	adv.modulate = Color(0.85, 0.85, 0.85, 1.0)
	v.add_child(adv)

	v.add_child(HSeparator.new())

	var mult := Label.new()
	mult.text = "HP x%.2f  |  Armor x%.2f  |  Damage x%.2f" % [hp_mult, armor_mult, dmg_mult]
	mult.modulate = Color(0.92, 0.92, 0.92, 1.0)
	v.add_child(mult)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	var select_btn := Button.new()
	select_btn.text = "Select"
	select_btn.pressed.connect(func() -> void:
		_class_selected_id = class_id
		_class_confirm_btn.disabled = false
		_refresh_class_card_styles()
	)
	v.add_child(select_btn)

	return card

func _show_advanced_class_popup(current_name: String, required_level: int, choices: Array[ClassDef]) -> void:
	_class_selected_id = -1
	_class_cards.clear()

	# Full-screen modal overlay
	_class_select_overlay = Control.new()
	_class_select_overlay.name = "AdvancedClassSelectOverlay"
	_class_select_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_class_select_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_class_select_overlay.focus_mode = Control.FOCUS_ALL
	#add_child(_class_select_overlay)
	Game.popup_root().add_child(_class_select_overlay)
	_class_select_overlay.grab_focus()

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.80)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_class_select_overlay.add_child(dim)

	var shell := PanelContainer.new()
	shell.anchor_left = 0.5
	shell.anchor_right = 0.5
	shell.anchor_top = 0.5
	shell.anchor_bottom = 0.5
	shell.offset_left = -520
	shell.offset_right = 520
	shell.offset_top = -310
	shell.offset_bottom = 310
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	_class_select_overlay.add_child(shell)

	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = Color(0.10, 0.10, 0.10, 0.98)
	shell_style.corner_radius_top_left = 10
	shell_style.corner_radius_top_right = 10
	shell_style.corner_radius_bottom_left = 10
	shell_style.corner_radius_bottom_right = 10
	shell_style.set_border_width_all(1)
	shell_style.border_color = Color(0.20, 0.20, 0.20, 1.0)
	shell.add_theme_stylebox_override("panel", shell_style)

	var root := VBoxContainer.new()
	root.offset_left = 18
	root.offset_right = -18
	root.offset_top = 14
	root.offset_bottom = -14
	shell.add_child(root)

	var title := Label.new()
	title.text = "Choose Your Advanced Class (Lv %d)" % required_level
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Current: %s" % current_name
	subtitle.modulate = Color(0.85, 0.85, 0.85, 1.0)
	root.add_child(subtitle)

	root.add_child(HSeparator.new())

	var cards_row := HBoxContainer.new()
	cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_row.add_theme_constant_override("separation", 14)
	root.add_child(cards_row)

	# Build one card per available choice
	for i in range(choices.size()):
		var cd: ClassDef = choices[i]
		var accent := _accent_for_base_class(cd.base_class_id, i)
		var card := _make_advanced_class_card(cd, accent)
		cards_row.add_child(card)
		_class_cards[cd.id] = card

	root.add_child(HSeparator.new())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)

	_class_hint_lbl = Label.new()
	_class_hint_lbl.text = "Select a class, then confirm."
	_class_hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_class_hint_lbl)

	_class_confirm_btn = Button.new()
	_class_confirm_btn.text = "Confirm"
	_class_confirm_btn.disabled = true
	_class_confirm_btn.pressed.connect(func() -> void:
		_choose_advanced_class()
	)
	footer.add_child(_class_confirm_btn)

	_refresh_advanced_card_styles()

func _refresh_class_card_styles() -> void:
	for cid in _class_cards.keys():
		var card: PanelContainer = _class_cards[cid]
		var accent: Color = card.get_meta("accent")
		var st: StyleBoxFlat = card.get_meta("base_style")

		if int(cid) == _class_selected_id:
			st.set_border_width_all(3)
			st.bg_color = Color(0.14, 0.14, 0.14, 1.0)
		else:
			st.set_border_width_all(2)
			st.bg_color = Color(0.11, 0.11, 0.11, 1.0)

		st.border_color = accent
		card.add_theme_stylebox_override("panel", st)

func _advances_at_25_text(base_class_id: int) -> String:
	var base_def: ClassDef = ClassCatalog.base_def_for_class_id(base_class_id)
	if base_def == null:
		return "Advances at Lv 25: —"

	# We want the preview for level 25 even though player level is 1 here.
	var choices: Array[ClassDef] = ClassCatalog.next_choices(base_def.id, 25)
	if choices.is_empty():
		return "Advances at Lv 25: —"

	var names := PackedStringArray()
	for c in choices:
		names.append(c.display_name)

	return "Advances at Lv 25: " + " or ".join(names)

func _maybe_prompt_advanced_class_selection() -> void:
	# Don’t interrupt an existing class popup
	if _class_select_overlay != null:
		return
	if Game.player == null:
		return

	# Starting class selection still takes priority
	if int(Game.player.class_id) < 0:
		return

	# Ensure class_def_id exists/valid
	if Game.player.has_method("ensure_class_and_skills_initialized"):
		Game.player.ensure_class_and_skills_initialized()

	var current_id := String(Game.player.class_def_id)
	if current_id == "":
		return

	var choices: Array[ClassDef] = ClassCatalog.next_choices(current_id, int(Game.player.level))
	if choices.is_empty():
		return

	# We have a pending advancement choice.
	var required_level := 999999
	for c in choices:
		required_level = mini(required_level, int(c.unlock_level))

	var current_def: ClassDef = ClassCatalog.get_def(current_id)
	var current_name := current_def.display_name if current_def != null else "Class"

	_show_advanced_class_popup(current_name, required_level, choices)

# Small blurb mapping (extend as you like; fallback is fine)
const CLASS_BLURBS := {
	"knight": "Armored defender focused on durability.",
	"berserker": "Relentless brawler who thrives on offense.",
	"sorcerer": "Arcane specialist with explosive power.",
	"warlock": "Dark caster with sustain and curses.",
	"ranger": "Precision hunter with speed and control.",
	"rogue": "Elusive striker relying on agility and evasion.",
}

func _make_advanced_class_card(cd: ClassDef, accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.12, 0.12, 0.12, 1.0)
	st.corner_radius_top_left = 10
	st.corner_radius_top_right = 10
	st.corner_radius_bottom_left = 10
	st.corner_radius_bottom_right = 10
	st.set_border_width_all(2)
	st.border_color = accent

	card.set_meta("accent", accent)
	card.set_meta("base_style", st)
	card.add_theme_stylebox_override("panel", st)

	var v := VBoxContainer.new()
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 12
	v.offset_bottom = -12
	card.add_child(v)

	var header := Label.new()
	header.text = cd.display_name
	header.add_theme_font_size_override("font_size", 18)
	v.add_child(header)

	var blurb := Label.new()
	blurb.text = CLASS_BLURBS.get(cd.id, "An advanced specialization path.")
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.modulate = Color(0.90, 0.90, 0.90, 1.0)
	v.add_child(blurb)

	var adv := Label.new()
	adv.text = _next_advancement_text(cd)
	adv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	adv.modulate = Color(0.85, 0.85, 0.85, 1.0)
	v.add_child(adv)

	var bonus := Label.new()
	bonus.text = _class_bonus_text(cd)
	bonus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bonus.modulate = Color(0.92, 0.92, 0.92, 1.0)
	v.add_child(bonus)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	var select_btn := Button.new()
	select_btn.text = "Select"
	select_btn.pressed.connect(func() -> void:
		_class_confirm_btn.disabled = false
		_class_confirm_btn.set_meta("selected_def_id", cd.id)
		_refresh_advanced_card_styles()
	)

	v.add_child(select_btn)

	return card

func _refresh_advanced_card_styles() -> void:
	var selected_def_id := ""
	if _class_confirm_btn != null and _class_confirm_btn.has_meta("selected_def_id"):
		selected_def_id = String(_class_confirm_btn.get_meta("selected_def_id"))

	for def_id in _class_cards.keys():
		var card: PanelContainer = _class_cards[def_id]
		var accent: Color = card.get_meta("accent")
		var st: StyleBoxFlat = card.get_meta("base_style")

		if String(def_id) == selected_def_id:
			st.set_border_width_all(3)
			st.bg_color = Color(0.14, 0.14, 0.14, 1.0)
		else:
			st.set_border_width_all(2)
			st.bg_color = Color(0.11, 0.11, 0.11, 1.0)

		st.border_color = accent
		card.add_theme_stylebox_override("panel", st)

func _choose_advanced_class() -> void:
	if Game.player == null:
		return
	if _class_confirm_btn == null or not _class_confirm_btn.has_meta("selected_def_id"):
		return

	var chosen_id := String(_class_confirm_btn.get_meta("selected_def_id"))
	Game.player.class_def_id = chosen_id

	SaveManager.save_now()
	Game.player_changed.emit()

	if _class_select_overlay != null:
		_class_select_overlay.queue_free()
		_class_select_overlay = null

	# If they skipped milestones, immediately prompt for the next required tier.
	call_deferred("_maybe_prompt_advanced_class_selection")

func _next_advancement_text(cd: ClassDef) -> String:
	# Find earliest child unlock level (usually 50 or 75). If none, final tier.
	var next_unlock := 999999
	for c in ClassCatalog.children_of(cd.id):
		next_unlock = mini(next_unlock, int(c.unlock_level))


	if next_unlock == 999999:
		return "Final tier: no further advancements."

	var next_choices: Array[ClassDef] = ClassCatalog.next_choices(cd.id, next_unlock)
	if next_choices.is_empty():
		return "Advances at Lv %d: —" % next_unlock

	var names := PackedStringArray()
	for n in next_choices:
		names.append(n.display_name)

	return "Advances at Lv %d: %s" % [next_unlock, " or ".join(names)]

func _class_bonus_text(cd: ClassDef) -> String:
	# Summarize flat passive stats if present
	if cd.passive_flat == null:
		return "Bonuses: —"

	var s: Stats = cd.passive_flat
	var parts := PackedStringArray()

	# These fields match what your game already uses (hp/atk/def/str/int_/agi/etc.)
	if s.hp != 0: parts.append("HP %+d" % int(s.hp))
	if s.atk != 0: parts.append("ATK %+d" % int(s.atk))
	if s.def != 0: parts.append("Armor %+d" % int(s.def))
	if s.str != 0: parts.append("STR %+d" % int(s.str))
	if s.int_ != 0: parts.append("INT %+d" % int(s.int_))
	if s.agi != 0: parts.append("AGI %+d" % int(s.agi))
	if s.atk_spd != 0: parts.append("Atk Spd %+0.2f" % float(s.atk_spd))
	if s.crit_chance != 0: parts.append("Crit %+d%%" % int(s.crit_chance))
	if s.combo_chance != 0: parts.append("Combo %+d%%" % int(s.combo_chance))
	if s.block != 0: parts.append("Block %+d%%" % int(s.block))
	if s.avoidance != 0: parts.append("Avoid %+d%%" % int(s.avoidance))
	if s.regen != 0: parts.append("Regen %+0.2f/s" % float(s.regen))

	return "Bonuses: " + ", ".join(parts)

func _accent_for_base_class(base_class_id: int, variant_index: int) -> Color:
	# Keep the same color identity as starter popup; slight variation per card.
	match base_class_id:
		PlayerModel.ClassId.WARRIOR:
			return Color(1.00, 0.55 + 0.08 * variant_index, 0.20, 1.0)
		PlayerModel.ClassId.MAGE:
			return Color(0.72, 0.42 + 0.06 * variant_index, 1.00, 1.0)
		PlayerModel.ClassId.ARCHER:
			return Color(0.30, 1.00, 0.55 + 0.06 * variant_index, 1.0)
	return Color(0.9, 0.9, 0.9, 1.0)

func _refresh_character_header() -> void:
	if Game.player == null:
		return

	# Ensure random name exists (older saves/new games)
	Game.player.ensure_name_initialized()

	name_button.text = Game.player.character_name
	class_level_label.text = "%s  Lv %d" % [Game.player.current_class_name_display(), int(Game.player.level)]

func _open_rename_popup() -> void:
	if _rename_overlay != null:
		return
	if Game.player == null:
		return

	_rename_overlay = Control.new()
	_rename_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rename_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_rename_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.75)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_rename_overlay.add_child(dim)

	var shell := PanelContainer.new()
	shell.anchor_left = 0.5
	shell.anchor_right = 0.5
	shell.anchor_top = 0.5
	shell.anchor_bottom = 0.5
	shell.offset_left = -260
	shell.offset_right = 260
	shell.offset_top = -140
	shell.offset_bottom = 140
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	_rename_overlay.add_child(shell)

	var root := VBoxContainer.new()
	root.offset_left = 16
	root.offset_right = -16
	root.offset_top = 14
	root.offset_bottom = -14
	shell.add_child(root)

	var title := Label.new()
	title.text = "Change Character Name"
	title.add_theme_font_size_override("font_size", 18)
	root.add_child(title)

	var info := Label.new()
	info.text = "Cost: %d crystals" % RENAME_COST_CRYSTALS
	root.add_child(info)

	_rename_line = LineEdit.new()
	_rename_line.placeholder_text = "Enter new name"
	_rename_line.text = Game.player.character_name
	root.add_child(_rename_line)

	_rename_status = Label.new()
	_rename_status.text = ""
	_rename_status.modulate = Color(1, 0.7, 0.7, 1)
	root.add_child(_rename_status)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	root.add_child(buttons)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_close_rename_popup)
	buttons.add_child(cancel)

	_rename_confirm = Button.new()
	_rename_confirm.text = "Confirm"
	buttons.add_child(_rename_confirm)

	# Wire validation and confirm
	_rename_line.text_changed.connect(func(_t: String) -> void:
		_rename_validate()
	)
	_rename_validate()

	_rename_confirm.pressed.connect(func() -> void:
		_rename_validate()
		if _rename_confirm.disabled:
			return

		var proposed := _rename_line.text.strip_edges()
		Game.player.crystals -= RENAME_COST_CRYSTALS
		Game.player.character_name = proposed

		SaveManager.save_now()
		Game.player_changed.emit()
		_close_rename_popup()
	)

func _close_rename_popup() -> void:
	if _rename_overlay != null:
		_rename_overlay.queue_free()
		_rename_overlay = null

func _rename_validate() -> void:
	if Game.player == null or _rename_line == null or _rename_status == null or _rename_confirm == null:
		return

	var proposed := _rename_line.text.strip_edges()

	if proposed.length() < 3:
		_rename_status.text = "Name must be at least 3 characters."
		_rename_confirm.disabled = true
		return

	if proposed.length() > 24:
		_rename_status.text = "Name must be 24 characters or less."
		_rename_confirm.disabled = true
		return

	if Game.player.crystals < RENAME_COST_CRYSTALS:
		_rename_status.text = "Not enough crystals."
		_rename_confirm.disabled = true
		return

	# Placeholder for server uniqueness validation/reservation goes here.
	_rename_status.text = ""
	_rename_confirm.disabled = false

func _popup_layer() -> CanvasLayer:
	var layer := get_node_or_null("PopupLayer") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "PopupLayer"
		layer.layer = 20
		add_child(layer)
	return layer

# ----------------------- Crucible Art UI------------------------------------------------------

func _setup_crucible_art_ui() -> void:
	if _crucible_art_vbox != null:
		return

	# Hide the legacy crucible panel (and its draw button/batch text).
	if is_instance_valid(crucible_panel):
		crucible_panel.visible = false

	_crucible_art_vbox = VBoxContainer.new()
	_crucible_art_vbox.name = "CrucibleArtVBox"
	_crucible_art_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crucible_art_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_crucible_art_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_crucible_art_vbox.add_theme_constant_override("separation", 8)

	_crucible_art_btn = TextureButton.new()
	_crucible_art_btn.name = "CrucibleArtButton"
	_crucible_art_btn.texture_normal = CRUCIBLE_TEX
	_crucible_art_btn.texture_pressed = CRUCIBLE_TEX
	_crucible_art_btn.texture_hover = CRUCIBLE_TEX
	_crucible_art_btn.texture_disabled = CRUCIBLE_TEX
	_crucible_art_btn.ignore_texture_size = true
	_crucible_art_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_crucible_art_btn.custom_minimum_size = Vector2(260, 260) # tweak to taste
	_crucible_art_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_crucible_art_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_crucible_art_btn.tooltip_text = "Draw"
	_crucible_art_btn.pressed.connect(_on_crucible_art_pressed)
	_crucible_art_vbox.add_child(_crucible_art_btn)
	_crucible_btn_base_scale = _crucible_art_btn.scale

	_crucible_keys_count_label = Label.new()
	_crucible_keys_count_label.name = "CrucibleKeysCount"
	_crucible_keys_count_label.text = "0"
	_crucible_keys_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crucible_keys_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_crucible_keys_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_crucible_keys_count_label.add_theme_font_size_override("font_size", 22)
	_crucible_art_vbox.add_child(_crucible_keys_count_label)

	# Insert into the crucible row where the panel would have been.
	var insert_before: int = crucible_row.get_child_count()
	if is_instance_valid(crucible_panel):
		insert_before = crucible_panel.get_index()
	crucible_row.add_child(_crucible_art_vbox)
	crucible_row.move_child(_crucible_art_vbox, insert_before)

func _on_crucible_art_pressed() -> void:
	# Prevent double presses while animating.
	if _crucible_animating:
		return

	await _play_crucible_click_anim()
	_on_crucible_draw_pressed() # this will open the compare window AFTER animation

func _build_crucible_click_frames() -> void:
	_crucible_click_frames.clear()

	for i in range(CRUCIBLE_FRAME_COUNT):
		var col: int = i % CRUCIBLE_SHEET_COLS
		var row: int = i / CRUCIBLE_SHEET_COLS

		# Safety: don't exceed declared rows
		if row >= CRUCIBLE_SHEET_ROWS:
			break

		var atlas := AtlasTexture.new()
		atlas.atlas = CRUCIBLE_SHEET_TEX
		atlas.region = Rect2i(
			col * CRUCIBLE_FRAME_SIZE.x,
			row * CRUCIBLE_FRAME_SIZE.y,
			CRUCIBLE_FRAME_SIZE.x,
			CRUCIBLE_FRAME_SIZE.y
		)
		_crucible_click_frames.append(atlas)

	# Fallback safety
	if _crucible_click_frames.is_empty():
		_crucible_click_frames.append(CRUCIBLE_IDLE_TEX)

func _set_crucible_button_texture(tex: Texture2D) -> void:
	_crucible_art_btn.texture_normal = tex
	_crucible_art_btn.texture_hover = tex
	_crucible_art_btn.texture_pressed = tex
	_crucible_art_btn.texture_disabled = tex

func _play_crucible_click_anim() -> void:
	if _crucible_animating:
		return
	_crucible_animating = true
	_crucible_art_btn.disabled = true

	var dt: float = 1.0 / maxf(1.0, CRUCIBLE_FPS)
	for tex in _crucible_click_frames:
		_set_crucible_button_texture(tex)
		await get_tree().create_timer(dt).timeout

	_set_crucible_button_texture(CRUCIBLE_IDLE_TEX)
	_crucible_art_btn.disabled = false
	_crucible_animating = false

func _await_crucible_click_anim_if_possible() -> void:
	# If you ever open Home without the art button, or before frames are built, skip safely.
	if not is_instance_valid(_crucible_art_btn):
		return
	if _crucible_click_frames == null or _crucible_click_frames.is_empty():
		return

	# If another animation is running, wait for it to finish instead of skipping.
	while _crucible_animating:
		await get_tree().process_frame

	await _play_crucible_click_anim()
