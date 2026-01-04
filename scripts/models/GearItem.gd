extends Resource
class_name GearItem

@export var slot: int = 0
@export var rarity: int = 0
@export var item_level: int = 1
@export var stats: Stats = Stats.new()

func display_name() -> String:
	return "%s Lv.%d" % [Catalog.GEAR_SLOT_NAMES.get(slot, "Gear"), item_level]

func to_bbcode() -> String:
	var title := "%s (%s)" % [display_name(), Catalog.RARITY_NAMES.get(rarity, "")]
	var out := Catalog.rarity_to_bbcode(rarity, title) + "\n"
	for line in stats.to_lines():
		out += "• %s\n" % line
	return out.strip_edges()


func to_dict() -> Dictionary:
	return {
		"slot": slot,
		"item_level": item_level,
		"rarity": rarity,
		"stats": stats.to_dict() if stats != null else {},
	}

static func from_dict(d: Dictionary) -> GearItem:
	var it := GearItem.new()
	it.slot = int(d.get("slot", 0))
	it.item_level = int(d.get("item_level", 1))
	it.rarity = int(d.get("rarity", 0))

	var svar: Variant = d.get("stats", {})
	if typeof(svar) == TYPE_DICTIONARY:
		it.stats = Stats.from_dict(svar as Dictionary)
	else:
		it.stats = Stats.new()

	return it
