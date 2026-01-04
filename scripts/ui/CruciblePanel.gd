extends PanelContainer

signal draw_pressed

@onready var keys_label: Label = $VBox/KeysLabel
@onready var draw_button: Button = $VBox/DrawButton

func _ready() -> void:
	draw_button.pressed.connect(func() -> void:
		print("DrawButton pressed") # debug
		emit_signal("draw_pressed")
	)

func set_keys_text(keys: int, crucible_level: int) -> void:
	keys_label.text = "Keys: %d | Crucible Lv.%d" % [keys, crucible_level]
