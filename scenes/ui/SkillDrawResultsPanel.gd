extends Control
class_name SkillDrawResultsPanel

const ICON_SIZE: int = 64
var _panel: PanelContainer = null
var _grid: GridContainer = null
var _awards: Array[String] = []

func _ready() -> void:
	top_level = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	_build()
	call_deferred("_center_panel")

func set_awards(awards: Array[String]) -> void:
	_awards = awards
	if _grid != null:
		_rebuild_grid()

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.65)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.name = "MainPanel"
	_panel.custom_minimum_size = Vector2(720, 520)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var root := VBoxContainer.new()
	root.offset_left = 12
	root.offset_right = -12
	root.offset_top = 12
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 10)
	_panel.add_child(root)

	var title := Label.new()
	title.text = "Skills Awarded"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_grid = GridContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	root.add_child(footer)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(queue_free)
	footer.add_child(close)

	_rebuild_grid()

func _center_panel() -> void:
	if _panel == null:
		return
	var vp := get_viewport_rect().size
	_panel.size = _panel.custom_minimum_size
	_panel.position = (vp - _panel.size) * 0.5

func _rebuild_grid() -> void:
	if _grid == null:
		return

	# Clear
	for c in _grid.get_children():
		c.queue_free()

	var n: int = _awards.size()
	if n <= 0:
		_grid.columns = 1
		var lbl := Label.new()
		lbl.text = "No awards."
		_grid.add_child(lbl)
		return

	# Column choice
	if n <= 5:
		_grid.columns = 5
	elif n <= 10:
		_grid.columns = 5
	else:
		_grid.columns = 7 # 35 = 7x5

	for sid in _awards:
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var tex := SkillCatalog.icon_with_rarity_border(sid, ICON_SIZE, 2)
		tr.texture = tex
		_grid.add_child(tr)
