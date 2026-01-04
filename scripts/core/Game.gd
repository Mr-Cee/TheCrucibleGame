extends Node
#class_name Game

signal player_changed
signal inventory_event(message:String)

var player: PlayerModel

signal battle_changed

var battle_state: Dictionary = {
	"difficulty": "Easy",
	"level": 1,
	"stage": 1,
	"wave": 1,
	"speed_idx": 0,
}

var crucible_draw_cooldown_base: float = 0.60
var crucible_draw_cooldown_mult: float = 1.0 # battlepass can reduce this, e.g. 0.5

#--------------------------------------------------------
func _ready() -> void:
	SaveManager.load_or_new()
	SaveManager.init_autosave_hooks()

func add_gold(amount:int) -> void:
	player.gold += amount
	emit_signal("player_changed")

func spend_crucible_key() -> bool:
	if player.crucible_keys <= 0:
		return false
	player.crucible_keys -= 1
	emit_signal("player_changed")
	return true

#func equip_item(item:GearItem) -> GearItem:
	#var old:GearItem = player.equipped.get(item.slot, null)
	#player.equipped[item.slot] = item
	#emit_signal("player_changed")
	#return old

func equip_item(item: GearItem) -> GearItem:
	if item == null:
		return null

	var slot: int = int(item.slot)
	var old: GearItem = player.equipped.get(slot, null)

	player.equipped[slot] = item
	player_changed.emit()
	return old
	
func sell_item(item:GearItem) -> int:
	var base := item.item_level * 10
	var mult: float = float(Catalog.RARITY_STAT_MULT.get(item.rarity, 1.0))
	var value := int(round(base * mult))
	add_gold(value)
	emit_signal("inventory_event", "Sold for %d gold" % value)
	return value

func reset_battle_state() -> void:
	battle_state = {
		"difficulty": "Easy",
		"level": 1,
		"stage": 1,
		"wave": 1,
		"speed_idx": 0,
	}
	battle_changed.emit()

func set_battle_state(state: Dictionary) -> void:
	# Defensive copy + defaults
	var d: Dictionary = {}
	d["difficulty"] = String(state.get("difficulty", "Easy"))
	d["level"] = int(state.get("level", 1))
	d["stage"] = int(state.get("stage", 1))
	d["wave"] = int(state.get("wave", 1))
	d["speed_idx"] = int(state.get("speed_idx", 0))

	battle_state = d
	battle_changed.emit()

func patch_battle_state(patch: Dictionary) -> void:
	for k in patch.keys():
		battle_state[k] = patch[k]
	battle_changed.emit()

func crucible_draw_cooldown() -> float:
	return max(0.05, crucible_draw_cooldown_base * crucible_draw_cooldown_mult)
