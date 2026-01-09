extends Control
class_name SkillsPanel

# Simple skills management screen:
# - Choose 5 active skills to equip for battle.
# - Uses OptionButtons (drop-downs) for now (can be reskinned later).

const SLOTS: int = 5

var _slot_opts: Array[OptionButton] = []
var _skill_ids: Array[String] = [] # option index -> skill_id (index 0 reserved for empty)

func _ready() -> void:
	_build()

func _build() -> void:
	# Overlay
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.anchor_left = 0
	dim.anchor_top = 0
	dim.anchor_right = 1
	dim.anchor_bottom = 1
	add_child(dim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -320
	panel.offset_top = -240
	panel.offset_right = 320
	panel.offset_bottom = 240
	add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	var title := Label.new()
	title.text = "Active Skills"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	root.add_child(title)

	var hint := Label.new()
	hint.text = "Equip up to 5 active skills. In Auto mode, skills will fire sequentially as they come off cooldown."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)

	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 8)
	root.add_child(grid)

	# Build options list once
	_skill_ids = [""]
	var all := SkillCatalog.all_active_ids()
	for id in all:
		_skill_ids.append(id)

	_slot_opts.clear()

	for i in range(SLOTS):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		grid.add_child(row)

		var lbl := Label.new()
		lbl.text = "Slot %d" % (i + 1)
		lbl.custom_minimum_size = Vector2(70, 0)
		row.add_child(lbl)

		var opt := OptionButton.new()
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(opt)
		_slot_opts.append(opt)

		opt.add_item("(Empty)", 0)
		for idx in range(1, _skill_ids.size()):
			var sid := _skill_ids[idx]
			var d := SkillCatalog.get_def(sid)
			opt.add_item(d.display_name if d != null else sid, idx)

		opt.item_selected.connect(_on_slot_selected.bind(i))

	# Load current selections
	_refresh_from_player()

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	root.add_child(footer)

	footer.add_spacer(1)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(queue_free)
	footer.add_child(close)

func _refresh_from_player() -> void:
	if Game.player == null:
		return
	if Game.player.has_method("ensure_active_skills_initialized"):
		Game.player.call("ensure_active_skills_initialized")

	var eq: Array = Game.player.get("equipped_active_skills")
	if eq == null:
		return

	for i in range(SLOTS):
		var sid := ""
		if i < eq.size():
			sid = String(eq[i])

		var idx := _skill_ids.find(sid)
		if idx < 0:
			idx = 0
		_slot_opts[i].select(idx)

func _on_slot_selected(option_idx: int, slot: int) -> void:
	if Game.player == null:
		return
	if Game.player.has_method("ensure_active_skills_initialized"):
		Game.player.call("ensure_active_skills_initialized")

	var eq: Array = Game.player.get("equipped_active_skills")
	if eq == null:
		return

	var sid := ""
	if option_idx >= 0 and option_idx < _skill_ids.size():
		sid = _skill_ids[option_idx]

	# Ensure array size
	while eq.size() < SLOTS:
		eq.append("")

	eq[slot] = sid
	Game.player.set("equipped_active_skills", eq)
	Game.player_changed.emit()
