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

#----------------------------------------------------------------

signal compare_resolved


var _crucible := CrucibleSystem.new()

enum PopupMode { COMPARE, DETAILS }
var _popup_mode: int = PopupMode.COMPARE

var _pending_item: GearItem
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

	auto_popup.visible = false



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

func show_compare(item: GearItem) -> void:
	_popup_mode = PopupMode.COMPARE
	_pending_item = item
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
	#unequip_button.visible = false
	close_button.visible = true

	compare_popup.popup_centered(Vector2i(520, 420))

#func _on_equip_pressed() -> void:
	#if _popup_mode != PopupMode.COMPARE:
		#return
	#if _pending_item == null:
		#return
#
	#var old := Game.equip_item(_pending_item)
	#if old != null:
		#show_compare(old)
	#else:
		#compare_popup.visible = false
		#
	#compare_popup.visible = false
	#emit_signal("compare_resolved")

func _on_equip_pressed() -> void:
	# Only valid in compare mode (if you have modes)
	# if _popup_mode != PopupMode.COMPARE: return

	if _pending_item == null:
		return

	var old := Game.equip_item(_pending_item)

	# IMPORTANT:
	# If we swapped something out, we keep the popup open and immediately compare the old item.
	# Do NOT emit compare_resolved here, because the user still needs to decide what to do with the swapped-out item.
	if old != null:
		show_compare(old)
		return

	# No previous item in the slot: compare flow is finished.
	compare_popup.visible = false
	emit_signal("compare_resolved")

func _on_sell_pressed() -> void:
	if _popup_mode != PopupMode.COMPARE:
		return
	if _pending_item == null:
		return

	Game.sell_item(_pending_item)
	compare_popup.visible = false
	
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
	compare_popup.visible = false
	# IMPORTANT: without inventory, "Close" must not silently discard the item.
	# MVP: treat Close as Sell (or you can disable Close later).
	if _pending_item != null:
		Game.sell_item(_pending_item)
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
	if is_instance_valid(crucible_panel) and crucible_panel.has_method("set_keys_text"):
		crucible_panel.call("set_keys_text", p.crucible_keys, p.crucible_level)

var _batch_running: bool = false

#func _on_crucible_draw_pressed() -> void:
	#if _batch_running:
		#return
#
	#var p := Game.player
	#var batch: int = int(p.crucible_batch)
	#if not _is_batch_unlocked(batch, p.crucible_level):
		#batch = 1
		#p.crucible_batch = 1
		#Game.player_changed.emit()
#
	#_batch_running = true
	#await _run_batch_draw(batch)
	#_batch_running = false

func _on_crucible_draw_pressed() -> void:
	# Manual draw always cancels auto
	_stop_auto_draw()

	if not Game.spend_crucible_key():
		Game.inventory_event.emit("No keys available.")
		return

	var item := _crucible.roll_item_for_player(Game.player)

	# Manual draw ignores filters: always show the compare popup
	await _show_compare_and_wait(item)

#func _run_batch_draw(batch: int) -> void:
	#var p := Game.player
	#var min_rarity: int = int(p.crucible_rarity_min)
	#var auto_sell: bool = bool(p.crucible_auto_sell_below)
#
	#for i in range(batch):
		## Spend one key per draw
		#if not Game.spend_crucible_key():
			#Game.inventory_event.emit("No keys available.")
			#return
#
		#var item := _crucible.roll_item_for_player(p)
#
		## Filter: auto-sell below threshold
		#if auto_sell and item.rarity != min_rarity and not _rarity_meets_threshold(item.rarity, min_rarity):
			#Game.sell_item(item)
		#elif auto_sell and not _rarity_meets_threshold(item.rarity, min_rarity):
			## below threshold and auto_sell ON
			#Game.sell_item(item)
		#elif _rarity_meets_threshold(item.rarity, min_rarity):
			## Show player anything threshold+
			#await _show_compare_and_wait(item)
		#else:
			## If auto-sell is off and below threshold, still show it (MVP choice)
			#await _show_compare_and_wait(item)
#
		## Cooldown between draws
		#await get_tree().create_timer(Game.crucible_draw_cooldown()).timeout

func _run_batch_draw(batch: int, token: int) -> void:
	var p := Game.player
	var min_rarity: int = int(p.crucible_rarity_min)
	var auto_sell: bool = bool(p.crucible_auto_sell_below)

	for i in range(batch):
		if not _auto_running or token != _auto_cancel_token:
			return

		if not Game.spend_crucible_key():
			Game.inventory_event.emit("Auto stopped: no keys.")
			_stop_auto_draw()
			return

		var item := _crucible.roll_item_for_player(p)

		var meets := _rarity_meets_threshold(item.rarity, min_rarity)

		if meets:
			# Show anything that meets filter threshold
			await _show_compare_and_wait(item)
		else:
			# Below threshold: sell if enabled, otherwise still show
			if auto_sell:
				Game.sell_item(item)
			else:
				await _show_compare_and_wait(item)

		# Cooldown between draws (battlepass-ready)
		if not _auto_running or token != _auto_cancel_token:
			return
		await get_tree().create_timer(Game.crucible_draw_cooldown()).timeout

func _rarity_meets_threshold(rarity_id: int, min_rarity_id: int) -> bool:
	var r_idx := RARITY_ORDER.find(rarity_id)
	var m_idx := RARITY_ORDER.find(min_rarity_id)
	if r_idx == -1 or m_idx == -1:
		# If unknown, be conservative and show it
		return true
	return r_idx >= m_idx

func _on_filter_pressed() -> void:
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

func _show_compare_and_wait(item: GearItem) -> void:
	show_compare(item)
	await compare_resolved

func _update_auto_popup_status() -> void:
	if _auto_running:
		auto_status_label.text = "Auto: ON"
		start_stop_button.text = "Stop Auto"
	else:
		auto_status_label.text = "Auto: OFF"
		start_stop_button.text = "Start Auto"

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
	_run_auto_loop(_auto_cancel_token) # fire-and-forget (async)

func _on_start_stop_auto_pressed() -> void:
	if _auto_running:
		_stop_auto_draw()
	else:
		# Refresh UI in case something is locked/unlocked since last open
		_refresh_auto_popup()
		_start_auto_draw()

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
