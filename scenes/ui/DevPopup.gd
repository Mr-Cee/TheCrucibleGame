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

@onready var close_button: Button = $VBox/CloseButton

# Keep these as IDs so we can map them cleanly.
const GIVE_ITEMS: Array[Dictionary] = [
	{"id":"gold", "label":"Gold"},
	{"id":"xp", "label":"XP"},
	{"id":"time_vouchers", "label":"Time Vouchers"},
	{"id":"diamonds", "label":"Diamonds"},
	{"id":"crystals", "label":"Crystals"},
	{"id":"crucible_keys", "label":"Crucible Keys"},
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

	level_spin.step = 1
	stage_spin.step = 1
	wave_spin.step = 1
	level_spin.value_changed.connect(func(_v: float) -> void: _refresh_battle_preview())
	stage_spin.value_changed.connect(func(_v: float) -> void: _refresh_battle_preview())
	wave_spin.value_changed.connect(func(_v: float) -> void: _refresh_battle_preview())
	diff_select.item_selected.connect(func(_i: int) -> void: _refresh_battle_preview())

	_refresh_from_game()

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
