extends Control
class_name DungeonsPanel

@export var game_node_path: NodePath = NodePath("/root/Game")

var _game: Node = null
var _list_vbox: VBoxContainer = null
var _title_label: Label = null

func open() -> void:
	visible = true

func _ready() -> void:
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP

	_game = get_node_or_null(game_node_path)

	_build_ui()

	if _game != null and _game.has_signal("player_changed"):
		if not _game.player_changed.is_connected(_refresh):
			_game.player_changed.connect(_refresh)

	_refresh()

func _build_ui() -> void:
	# Dim background
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.anchor_right = 1
	dim.anchor_bottom = 1
	
	# Close when clicking outside the panel (on the dim/backdrop)
	dim.gui_input.connect(_on_dim_gui_input)
	
	add_child(dim)

	# Centered panel
	var center := CenterContainer.new()
	center.anchor_right = 1
	center.anchor_bottom = 1
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 560)
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	# Header
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Dungeons"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 20)
	header.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	# List
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_list_vbox)

func _refresh() -> void:
	if _list_vbox == null:
		return

	for c in _list_vbox.get_children():
		c.queue_free()

	for did in DungeonCatalog.all_ids():
		var def := DungeonCatalog.get_def(did)
		if def == null:
			continue

		var cur_level: int = 1
		var key_count: int = 0

		if _game != null and ("dungeon_system" in _game) and _game.dungeon_system != null:
			cur_level = _game.dungeon_system.get_current_level(did)
			key_count = _game.dungeon_system.get_key_count(did)

		var btn := Button.new()
		btn.text = "%s  |  Level %d  |  %s: %d" % [def.display_name, cur_level, def.key_display_name, key_count]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_dungeon_pressed.bind(did))
		_list_vbox.add_child(btn)

func _on_dungeon_pressed(dungeon_id: String) -> void:
	var popup := DungeonInfoPopup.new()
	Game.popup_root().add_child(popup)
	popup.open_for_dungeon(_game, dungeon_id)

func _on_close_pressed() -> void:
	queue_free()

func _on_dim_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		queue_free()
		accept_event()
