extends Control

@onready var speed_label: Label = $SpeedVBox/SpeedLabel
@onready var speed_button: OptionButton = $SpeedVBox/SpeedButton

var _suppress_select_signal: bool = false

func _ready() -> void:
	# Defensive: ensure nodes exist
	if speed_button == null:
		push_error("SpeedBox: SpeedButton not found at $SpeedVBox/SpeedButton")
		return

	_build_speed_options()

	# When player changes speed via UI
	speed_button.item_selected.connect(_on_speed_selected)

	# Keep UI updated if battle_state changes elsewhere (load/save, etc.)
	Game.battle_changed.connect(_sync_from_state)

	# Initial sync
	_sync_from_state()

func _build_speed_options() -> void:
	speed_button.clear()
	speed_button.add_item("1x", 0)
	speed_button.add_item("3x", 1)
	speed_button.add_item("5x", 2)
	speed_button.add_item("10x", 3)

	# Optional label
	if speed_label != null:
		speed_label.text = "Speed"

func _on_speed_selected(idx: int) -> void:
	if _suppress_select_signal:
		return

	# Persist selected speed idx in battle_state
	Game.patch_battle_state({"speed_idx": idx})

func _sync_from_state() -> void:
	if speed_button == null:
		return

	var idx: int = int(Game.battle_state.get("speed_idx", 0))
	idx = clampi(idx, 0, speed_button.item_count - 1)

	# Avoid firing item_selected when we update programmatically
	_suppress_select_signal = true
	speed_button.selected = idx
	_suppress_select_signal = false
