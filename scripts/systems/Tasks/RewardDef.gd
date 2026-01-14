extends Resource
class_name RewardDef

enum Kind {
	CRUCIBLE_KEYS,
	TIME_VOUCHERS,
	SKILL_TICKETS,
	CRYSTALS,
}

@export var kind: Kind = Kind.CRYSTALS
@export var min_amount: int = 1
@export var max_amount: int = 1
@export var weight: int = 1

func roll_amount(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(min_amount, max_amount)
