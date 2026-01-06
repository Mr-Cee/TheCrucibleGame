extends Control

# Top HUD
@onready var name_label: Label = $RootMargin/RootVBox/TopHUDRow/CharacterHUD/CharacterVBox/NameLabel
@onready var hp_bar: ProgressBar = $RootMargin/RootVBox/TopHUDRow/CharacterHUD/CharacterVBox/HPBar
@onready var xp_bar: ProgressBar = $RootMargin/RootVBox/TopHUDRow/CharacterHUD/CharacterVBox/XPBar
@onready var cp_label: Label = $RootMargin/RootVBox/TopHUDRow/CharacterHUD/CharacterVBox/CPLabel

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

func _fmt_mmss(seconds: int) -> String:
	seconds = max(0, seconds)
	var m: int = seconds / 60
	var s: int = seconds % 60
	return "%d:%02d" % [m, s]


#-------------------------------------------------------------------------

func _ready() -> void:
	# Existing connections...
	Game.inventory_event.connect(_on_inventory_event)
	equip_button.pressed.connect(_on_equip_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	#unequip_button.pressed.connect(_on_unequip_pressed)
	close_button.pressed.connect(_on_close_pressed)
	
	# Connect Crucible draw signal
	if crucible_panel.has_signal("draw_pressed"):
		crucible_panel.connect("draw_pressed", _on_crucible_draw_pressed)
	else:
		push_warning("CruciblePanel has no draw_pressed signal. Is CruciblePanel.gd attached to the node?")
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
	Game.player_changed.connect(_refresh_hud)
	_refresh_hud()

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

func show_compare(item: GearItem, from_deferred: bool = false) -> void:
	_popup_mode = PopupMode.COMPARE
	_pending_item = item
	_pending_item_from_deferred = from_deferred
	_details_slot_id = -1

	_equipped_snapshot = Game.player.equipped.get(item.slot, null)

	new_item_label.bbcode_enabled = true
	equipped_item_label.bbcode_enabled = true

	new_item_label.text = "[b]New:[/b]\n" + item.to_bbcode()
	if _equipped_snapshot != null:
		equipped_item_label.text = "[b]Equipped:[/b]\n" + _equipped_snapshot.to_bbcode()
	else:
		equipped_item_label.text = "[b]Equipped:[/b]\n(None)"

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
	
func _refresh_hud() -> void:
	var p := Game.player

	# If you have these nodes in your HUD, update them. If not, remove the lines.
	if is_instance_valid(name_label):
		name_label.text = "Hero"
	if is_instance_valid(cp_label):
		cp_label.text = "CP: %d" % p.combat_power()

	# Placeholder bars until you wire real HP/XP
	if is_instance_valid(hp_bar):
		hp_bar.min_value = 0
		hp_bar.max_value = 100
		hp_bar.value = 100

	if is_instance_valid(xp_bar):
		xp_bar.min_value = 0
		xp_bar.max_value = 100
		xp_bar.value = float((p.level * 7) % 100)

	if is_instance_valid(gold_label):
		gold_label.text = "Gold: %d" % p.gold
	if is_instance_valid(diamonds_label):
		diamonds_label.text = "Diamonds: %d" % p.diamonds
	if is_instance_valid(crystals_label):
		crystals_label.text = "Crystals: %d" % p.crystals

	# Update CruciblePanel label
	#if is_instance_valid(crucible_panel) and crucible_panel.has_method("set_keys_text"):
	var pending: int = 0
	if "deferred_gear" in p:
		pending = int(p.deferred_gear.size())

	crucible_panel.call("set_crucible_hud", p.crucible_keys, p.crucible_level, int(p.crucible_batch), pending)

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

	# Generate all items and queue them for decisions
	var to_queue: Array[GearItem] = []
	for i in range(spent):
		to_queue.append(_crucible.roll_item_for_player(p))

	_enqueue_deferred_many(to_queue)

	# Show first queued item immediately
	await _show_compare_and_wait(_peek_deferred_item(), true)

#func _on_crucible_draw_pressed() -> void:
	## Manual draw always stops auto
	#_stop_auto_draw()
#
	## If there is a deferred item, resolve it first (no key spent)
	#if _has_deferred_item():
		#var it := _peek_deferred_item()
		#await _show_compare_and_wait(it, true)
		#return
#
	## Normal draw
	#if not Game.spend_crucible_key():
		#Game.inventory_event.emit("No keys available.")
		#return
#
	#var item := _crucible.roll_item_for_player(Game.player)
	#await _show_compare_and_wait(item, false)

func _run_batch_draw(batch: int, token: int) -> void:
	var p := Game.player
	var min_rarity: int = int(p.crucible_rarity_min)
	var auto_sell: bool = bool(p.crucible_auto_sell_below)

	# If we already have a deferred item, resolve it first (no new keys spent).
	if _has_deferred_item():
		await _show_compare_and_wait(_peek_deferred_item(), true)
		return

	# Spend the whole batch up front (this is what makes "2 keys at once" feel correct).
	var spent: int = Game.spend_crucible_keys(batch)
	if spent <= 0:
		Game.inventory_event.emit("Auto stopped: no keys.")
		_stop_auto_draw()
		return

	# Generate items; queue those that require player decision, auto-sell the rest.
	var to_queue: Array[GearItem] = []

	for i in range(spent):
		if not _auto_running or token != _auto_cancel_token:
			return

		var item := _crucible.roll_item_for_player(p)
		var meets := _rarity_meets_threshold(item.rarity, min_rarity)

		if meets:
			# Show/decide later (queued)
			to_queue.append(item)
		else:
			# Below threshold
			if auto_sell:
				Game.sell_item(item)
			else:
				# Auto-sell off: player must decide, so queue it too
				to_queue.append(item)

		# Cooldown between draws (battlepass-ready)
		if i < spent - 1:
			await get_tree().create_timer(Game.crucible_draw_cooldown()).timeout

	# Enqueue all decision items (persisted via player_changed/save).
	if to_queue.size() > 0:
		_enqueue_deferred_many(to_queue)

	# Immediately present the next deferred item (if any), and wait for a decision.
	if _has_deferred_item() and _auto_running and token == _auto_cancel_token:
		await _show_compare_and_wait(_peek_deferred_item(), true)

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

	# If there is a deferred item, resolve it first (auto stays ON unless user stops it).
	if _has_deferred_item():
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

func _run_auto_loop(token: int) -> void:
	# Continuous auto: keep drawing batches until stopped or out of keys.
	while _auto_running and token == _auto_cancel_token:
		var p := Game.player
		var batch: int = int(p.crucible_batch)

		# Enforce locks; if locked, fallback to 1
		if not _is_batch_unlocked(batch, p.crucible_level):
			batch = 1

		# If no keys, stop auto
		if p.crucible_keys <= 0:
			Game.inventory_event.emit("Auto stopped: no keys.")
			_stop_auto_draw()
			return

		# Run one batch
		await _run_batch_draw(batch, token)

		# Small delay between batches so it doesn’t “instantly restart”
		if not _auto_running or token != _auto_cancel_token:
			return
		await get_tree().create_timer(0.10).timeout

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
