extends Resource
class_name TaskState

@export var current_task_id: String = ""
@export var progress: int = 0
@export var required: int = 0

# How many times each task has been completed historically (never decreases).
@export var tiers: Dictionary = {} # String -> int

# Absolute guardrail to ensure requirements never go down even if you rebalance base/step later.
@export var max_required_seen: Dictionary = {} # String -> int

static func _dict_to_int_map(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[str(k)] = int(d[k])
	return out

func to_dict() -> Dictionary:
	return {
		"current_task_id": current_task_id,
		"progress": progress,
		"required": required,
		"tiers": tiers,
		"max_required_seen": max_required_seen,
	}

static func from_dict(d: Dictionary) -> TaskState:
	var s := TaskState.new()
	s.current_task_id = str(d.get("current_task_id", ""))
	s.progress = int(d.get("progress", 0))
	s.required = int(d.get("required", 0))
	s.tiers = _dict_to_int_map(d.get("tiers", {}))
	s.max_required_seen = _dict_to_int_map(d.get("max_required_seen", {}))
	return s
