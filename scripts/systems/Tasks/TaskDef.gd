extends Resource
class_name TaskDef

enum Kind {
	KILL_ENEMIES,
	CRUCIBLE_DRAWS,
	SKILL_DRAWS,
	LEVEL_UPS,
}

@export var id: String = ""
@export var kind: Kind = Kind.KILL_ENEMIES

# Requirement growth:
@export var base_required: int = 25
@export var step_required: int = 10

func required_for_tier(tier: int) -> int:
	# Tier is how many times THIS task has been completed historically.
	return max(1, base_required + step_required * max(0, tier))

func format_text(progress: int, required: int) -> String:
	match kind:
		Kind.KILL_ENEMIES:
			return "Kill %d/%d enemies" % [progress, required]
		Kind.CRUCIBLE_DRAWS:
			return "Draw %d/%d times from the Crucible" % [progress, required]
		Kind.SKILL_DRAWS:
			return "Draw %d/%d times from the Skill Generator" % [progress, required]
		Kind.LEVEL_UPS:
			# progress will be the player's current level (capped for display)
			return "Level up to %d (%d/%d)" % [required, progress, required]
		_:
			return "%d/%d" % [progress, required]
