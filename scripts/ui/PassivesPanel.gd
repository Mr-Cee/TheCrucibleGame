extends Control
class_name PassivesPanel

# Passive tree viewer (read-only).
# Unlock state is computed purely from player level + selected class path.

const INDENT_PX := 22

var _expanded: Dictionary = {} # class_def_id -> bool
var _last_class_def_id: String = ""

var _main_panel: PanelContainer
var _content: VBoxContainer


func _ready() -> void:
	top_level = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_ui()

	if Game != null and not Game.player_changed.is_connected(_refresh):
		Game.player_changed.connect(_refresh)

	_refresh()

func _exit_tree() -> void:
	if Game != null and Game.player_changed.is_connected(_refresh):
		Game.player_changed.disconnect(_refresh)

func _build_ui() -> void:
	# Dim background
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.85)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_main_panel = PanelContainer.new()
	_main_panel.custom_minimum_size = Vector2(900, 650)
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_main_panel)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	_main_panel.add_child(root)

	# Header
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(header)

	var title := Label.new()
	title.text = "Class Passives"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	header.add_child(title)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(queue_free)
	header.add_child(close)

	# Scroll area
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_content)

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		queue_free()

func _refresh() -> void:
	_clear_children(_content)

	var p: PlayerModel = Game.player if Game != null else null
	if p == null:
		_add_info("No player loaded.")
		return

	var cur_id := String(p.class_def_id)
	if cur_id == "":
		# fallback display only
		var base: ClassDef = ClassCatalog.base_def_for_class_id(int(p.class_id))
		if base != null:
			cur_id = base.id

	if cur_id == "":
		_add_info("Choose a class to view class passives.")
		return

	if _last_class_def_id != cur_id:
		_expanded.clear()
		_last_class_def_id = cur_id

	var level := int(p.level)
	var path := _class_path(cur_id)
	if path.is_empty():
		_add_info("Unknown class: %s" % cur_id)
		return

	# Default collapse behavior: when advanced, only current expanded.
	for i in range(path.size()):
		var cd: ClassDef = path[i]
		var is_current := (i == path.size() - 1)

		if not _expanded.has(cd.id):
			_expanded[cd.id] = (path.size() == 1) or is_current

		_add_class_block(cd, i, is_current, level, bool(_expanded[cd.id]))

	# Small hint if a choice is available at this level (optional)
	var next := ClassCatalog.next_choices(cur_id, level)
	if next.size() > 0:
		var names: Array[String] = []
		for n in next:
			names.append(n.display_name)
		_add_hint("Advanced class selection available: %s" % ", ".join(names))

func _class_path(leaf_id: String) -> Array[ClassDef]:
	var out: Array[ClassDef] = []
	var cur := leaf_id
	var guard := 0
	while cur != "" and guard < 16:
		guard += 1
		var cd: ClassDef = ClassCatalog.get_def(cur)
		if cd == null:
			break
		out.append(cd)
		cur = cd.parent_id
	out.reverse()
	return out

func _add_class_block(cd: ClassDef, depth: int, is_current: bool, player_level: int, expanded: bool) -> void:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 6)
	_content.add_child(section)

	var head := HBoxContainer.new()
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(head)

	# Indent + tree prefix
	var prefix := Label.new()
	prefix.text = _tree_prefix(depth)
	prefix.custom_minimum_size = Vector2(depth * INDENT_PX + 18, 0)
	head.add_child(prefix)

	var btn := Button.new()
	btn.toggle_mode = true
	btn.button_pressed = expanded
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#btn.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = cd.display_name + ("  (Current)" if is_current else "")
	btn.pressed.connect(func() -> void:
		_expanded[cd.id] = btn.button_pressed
		_refresh()
	)
	head.add_child(btn)

	var passives := ClassPassiveCatalog.passives_for_class(cd.id)
	var unlocked := 0
	for pd in passives:
		if player_level >= int(pd.unlock_level):
			unlocked += 1

	var meta := Label.new()
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	meta.add_theme_font_size_override("font_size", 12)
	meta.modulate = Color(0.85, 0.85, 0.90, 0.9)
	meta.text = "Tier %d • %d/5" % [int(cd.tier), unlocked]
	head.add_child(meta)

	if not expanded:
		return

	for pd in passives:
		_add_passive_row(section, pd, depth + 1, player_level)

func _add_passive_row(parent: VBoxContainer, pd: ClassPassiveDef, depth: int, player_level: int) -> void:
	var unlocked := player_level >= int(pd.unlock_level)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8

	if unlocked:
		sb.bg_color = Color(0.10, 0.14, 0.10, 0.85)
		sb.border_color = Color(0.20, 0.85, 0.30, 0.55)
	else:
		sb.bg_color = Color(0.10, 0.10, 0.12, 0.75)
		sb.border_color = Color(0.55, 0.55, 0.60, 0.35)

	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)

	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)

	var top := HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(top)

	# Indent spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(depth * INDENT_PX, 0)
	top.add_child(spacer)

	# Status dot
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.color = Color(0.25, 1.0, 0.35, 1.0) if unlocked else Color(0.55, 0.55, 0.60, 1.0)
	top.add_child(dot)

	var name := Label.new()
	name.text = pd.display_name
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)

	var right := Label.new()
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right.add_theme_font_size_override("font_size", 12)
	right.text = ("Unlocked • CP +%d" % int(pd.cp_gain)) if unlocked else ("Unlocks at Lv %d • CP +%d" % [int(pd.unlock_level), int(pd.cp_gain)])
	top.add_child(right)

	var desc := Label.new()
	desc.text = pd.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 12)
	if not unlocked:
		desc.modulate = Color(0.85, 0.85, 0.90, 0.75)
	v.add_child(desc)

func _tree_prefix(depth: int) -> String:
	if depth <= 0:
		return ""
	return "   ".repeat(depth - 1) + "└─ "

func _add_info(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(lbl)

func _add_hint(text: String) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.16, 0.75)
	sb.border_color = Color(0.35, 0.45, 0.95, 0.35)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.modulate = Color(0.85, 0.90, 1.0, 0.95)
	card.add_child(lbl)

	_content.add_child(card)

func _clear_children(n: Node) -> void:
	for c in n.get_children():
		c.queue_free()
