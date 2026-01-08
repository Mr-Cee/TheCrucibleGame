extends Resource
class_name ClassDef

@export var id: String = ""                 # e.g. "warrior", "knight"
@export var display_name: String = ""        # UI label
@export var base_class_id: int = 0           # 0/1/2
@export var tier: int = 1
@export var unlock_level: int = 1            # level requirement to choose this class
@export var parent_id: String = ""           # empty for base classes

@export var passive_flat: Stats              # flat stat bonus always applied
@export var granted_passive_skills: Array[String] = []
