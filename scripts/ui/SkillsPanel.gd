extends Control
class_name SkillsPanel

const SLOTS: int = 5
const ICON_SIZE: int = 48

var _slot_opts: Array[OptionButton] = []
var _skill_ids: Array[String] = [] # option index -> skill_id (0 reserved for empty)
var _icon_cache: Dictionary = {}   # skill_id -> Texture2D (scaled)

var _slot_last_selected: Array[int] = []
var _status_label: Label = null
var _upgrade_all_btn: Button = null


func _ready() -> void:
	top_level = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	Game.player_changed.connect(_on_player_changed)
	_build()
	# Defer centering until controls have a real size.
	call_deferred("_center_panel")

func _on_player_changed() -> void:
	refresh_ui()

func refresh_ui() -> void:
	# Clear any cached icons so the UI can rebuild if needed.
	_icon_cache.clear()

	if has_method("_refresh_from_player"):
		call("_refresh_from_player")

	# These exist in your newer SkillsPanel versions; safe-call so this file still compiles.
	if has_method("_refresh_upgrade_all_visibility"):
		call("_refresh_upgrade_all_visibility")
	if has_method("_refresh_option_unlock_states"):
		call("_refresh_option_unlock_states")

# ---------------- Tooltip helpers ----------------

func _rarity_name_for_def(def: SkillDef) -> String:
	if def == null:
		return "Common"

	# If rarity hasn't been implemented yet, default safely.
	if not ("rarity" in def):
		return "Common"

	var r: int = int(def.get("rarity"))
	match r:
		0: return "Common"
		1: return "Uncommon"
		2: return "Rare"
		3: return "Legendary"
		4: return "Mythical"
	return "Common"

func _tooltip_for_skill(skill_id: String) -> String:
	if skill_id == "":
		return "Empty slot."
	var def: SkillDef = SkillCatalog.get_def(skill_id)
	if def == null:
		return skill_id

	var lv: int = _player_skill_level(skill_id)
	var prog: int = _player_skill_progress(skill_id)
	var req: int = _copies_required_for_next_level(lv)

	# Example: Level 1 (0/2) after upgrading from 0->1
	# For Level 0 it will show Level 0 (0/1) and indicate locked.
	var lock_txt := "LOCKED\n" if lv <= 0 else ""
	return "%s%s\nRarity: %s\nLevel: %d (%d/%d)\nCooldown: %.1fs\n\n%s" % [
		lock_txt,
		def.display_name,
		_rarity_name_for_def(def),
		lv, prog, req,
		float(def.cooldown),
		def.description
	]

func _player_skill_level(skill_id: String) -> int:
	if Game.player == null:
		return 0
	if Game.player.has_method("ensure_active_skills_initialized"):
		Game.player.call("ensure_active_skills_initialized")
	var d: Variant = Game.player.get("skill_levels")
	if typeof(d) != TYPE_DICTIONARY:
		return 0
	return int((d as Dictionary).get(skill_id, 0))

func _player_skill_progress(skill_id: String) -> int:
	if Game.player == null:
		return 0
	if Game.player.has_method("ensure_active_skills_initialized"):
		Game.player.call("ensure_active_skills_initialized")
	var d: Variant = Game.player.get("skill_progress")
	if typeof(d) != TYPE_DICTIONARY:
		return 0
	return int((d as Dictionary).get(skill_id, 0))

func _copies_required_for_next_level(level: int) -> int:
	return maxi(1, level + 1)

# ---------------- Icon helpers ----------------

func _scaled_icon_for_skill_id(sid: String) -> Texture2D:
	if sid == "":
		return null
	if _icon_cache.has(sid):
		return _icon_cache[sid]

	var tex: Texture2D = null
	var d := SkillCatalog.get_def(sid)
	if d != null and d.has_method("icon_texture"):
		tex = d.icon_texture()

	# Fallback by convention
	if tex == null:
		var p := "res://assets/icons/skills/%s.png" % sid
		if ResourceLoader.exists(p):
			tex = load(p) as Texture2D

	if tex == null:
		_icon_cache[sid] = null
		return null

	var img := tex.get_image()
	if img == null:
		_icon_cache[sid] = tex
		return tex

	img.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	var out := ImageTexture.create_from_image(img)
	_icon_cache[sid] = out
	return out

# ---------------- UI ----------------

func _build() -> void:
	# Fullscreen overlay
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "MainPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(640, 550) # same as your -320..320 and -240..240
	add_child(panel)


	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.offset_left = 10
	root.offset_right = -10
	root.offset_top = 10
	root.offset_bottom = -10
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
	
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.modulate = Color(1.0, 0.7, 0.7, 1.0)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)


	# Scrollable list so Close never gets pushed off-screen
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var grid := VBoxContainer.new()
	grid.add_theme_constant_override("separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	# Build options list once (IMPORTANT: index 0 must be "")
	_skill_ids = [""]
	_icon_cache.clear()

	var all: Array[String] = SkillCatalog.all_active_ids()
	all.sort_custom(Callable(self, "_skill_less"))
	for id in all:
		_skill_ids.append(id)


	_slot_opts.clear()
	
	_slot_last_selected = []
	for _i in range(SLOTS):
		_slot_last_selected.append(0)


	for slot_idx in range(SLOTS):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		grid.add_child(row)

		var lbl := Label.new()
		lbl.text = "Slot %d" % (slot_idx + 1)
		lbl.custom_minimum_size = Vector2(70, 0)
		row.add_child(lbl)

		var opt := OptionButton.new()
		opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		opt.custom_minimum_size = Vector2(0, ICON_SIZE + 12)
		opt.tooltip_text = "Empty slot."
		row.add_child(opt)
		_slot_opts.append(opt)

		# Build items + icons + tooltips + rarity headers
		opt.clear()
		opt.add_item("(Empty)", 0)
		var popup := opt.get_popup()
		popup.set_item_tooltip(0, _tooltip_for_skill(""))

		var last_rarity: int = -1

		# _skill_ids[0] is "", and ids from 1.. are already sorted by rarity then name
		for idx in range(1, _skill_ids.size()):
			var sid: String = _skill_ids[idx]
			var r: int = _rarity_rank(sid)

			# Insert header when rarity changes
			if r != last_rarity:
				last_rarity = r
				opt.add_item(_rarity_header_text(r), -1) # id -1 for header
				var header_i := opt.item_count - 1
				opt.set_item_disabled(header_i, true)
				# Optional: a small tooltip on headers (or leave blank)
				popup.set_item_tooltip(header_i, "")

			# Actual selectable skill entry
			var def := SkillCatalog.get_def(sid)
			opt.add_item(def.display_name if def != null else sid, idx)

			var icon := SkillCatalog.icon_with_rarity_border(sid, ICON_SIZE, 2)
			if icon != null:
				opt.set_item_icon(opt.item_count - 1, icon)

			popup.set_item_tooltip(opt.item_count - 1, _tooltip_for_skill(sid))
		
			var item_i := opt.item_count - 1
			var lv: int = _player_skill_level(sid)
			if lv <= 0:
				opt.set_item_disabled(item_i, true)


		# Signal is item_selected(index:int)
		opt.item_selected.connect(_on_slot_selected.bind(slot_idx))

	# Apply current equipped skills into UI
	_refresh_from_player()

	# Footer
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	root.add_child(footer)
	
	var gen := Button.new()
	gen.text = "Generator"
	gen.pressed.connect(func() -> void:
		var p := SkillGeneratorPanel.new()

		# When generator closes, refresh this skills panel immediately
		if p.has_signal("closed"):
			p.connect("closed", Callable(self, "refresh_ui"))

		get_tree().root.add_child(p)
	)
	footer.add_child(gen)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	
	_upgrade_all_btn = Button.new()
	_upgrade_all_btn.text = "Upgrade All"
	_upgrade_all_btn.visible = false
	_upgrade_all_btn.pressed.connect(_on_upgrade_all_pressed)
	footer.add_child(_upgrade_all_btn)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(queue_free)
	footer.add_child(close)
	
	_refresh_upgrade_all_visibility()

func _refresh_from_player() -> void:
	if Game.player == null:
		return
	if Game.player.has_method("ensure_active_skills_initialized"):
		Game.player.call("ensure_active_skills_initialized")

	var eq: Array = []
	var eqv: Variant = Game.player.get("equipped_active_skills")
	if typeof(eqv) == TYPE_ARRAY:
		eq = eqv as Array

	while eq.size() < SLOTS:
		eq.append("")

	for i in range(SLOTS):
		var sid := String(eq[i]) if i < eq.size() else ""
		var skill_idx: int = _skill_ids.find(sid)
		if skill_idx < 0:
			skill_idx = 0

		var opt := _slot_opts[i]
		var item_index: int = _find_item_index_by_id(opt, skill_idx)
		if item_index < 0:
			item_index = 0

		opt.select(item_index)
		opt.tooltip_text = _tooltip_for_skill(sid)
		if i < _slot_last_selected.size():
			_slot_last_selected[i] = item_index

			
	# After any refresh, update button visibility (in case progress changed elsewhere)
	_refresh_upgrade_all_visibility()

# index = selected OptionButton item index, slot_idx passed via bind()
func _on_slot_selected(index: int, slot_idx: int) -> void:
	if Game.player == null:
		return
	if Game.player.has_method("ensure_active_skills_initialized"):
		Game.player.call("ensure_active_skills_initialized")

	if _status_label != null:
		_status_label.text = ""

	# ------------------------------------------------------------
	# FIX: resolve selection via OptionButton item_id (headers shift indices)
	# index = popup item index
	# item_id = we set this when adding items (idx for skills, -1 for headers, 0 for empty)
	# ------------------------------------------------------------
	if slot_idx < 0 or slot_idx >= _slot_opts.size():
		return
	var opt := _slot_opts[slot_idx]
	if opt == null:
		return
	if index < 0 or index >= opt.item_count:
		return

	var item_id: int = opt.get_item_id(index)

	# Header rows are id -1 (disabled, but guard anyway)
	if item_id == -1:
		var prev_idx: int = 0
		if slot_idx >= 0 and slot_idx < _slot_last_selected.size():
			prev_idx = _slot_last_selected[slot_idx]
		opt.set_block_signals(true)
		opt.select(prev_idx)
		opt.set_block_signals(false)
		return

	# Resolve to skill id (0 = empty)
	var sid: String = ""
	if item_id > 0 and item_id < _skill_ids.size():
		sid = _skill_ids[item_id]
	# If item_id is 0, sid stays "" meaning empty
	# ------------------------------------------------------------

	# Locked (level 0) cannot be equipped
	if sid != "":
		var lv: int = _player_skill_level(sid)
		if lv <= 0:
			opt.set_block_signals(true)
			opt.select(0) # empty item index is always 0
			opt.set_block_signals(false)
			if _status_label != null:
				_status_label.text = "That skill is locked (Level 0). Draw it to unlock."
			return

	# Read current equipped array
	var eq: Array = []
	var eqv: Variant = Game.player.get("equipped_active_skills")
	if typeof(eqv) == TYPE_ARRAY:
		eq = eqv as Array
	while eq.size() < SLOTS:
		eq.append("")

	# Enforce uniqueness (ignore empty)
	if sid != "":
		for i in range(SLOTS):
			if i == slot_idx:
				continue
			if String(eq[i]) == sid:
				if _status_label != null:
					var def := SkillCatalog.get_def(sid)
					var nm := def.display_name if def != null else sid
					_status_label.text = "You can only equip one copy of %s." % nm

				var prev := 0
				if slot_idx >= 0 and slot_idx < _slot_last_selected.size():
					prev = _slot_last_selected[slot_idx]

				if opt != null:
					opt.set_block_signals(true)
					opt.select(prev) # prev is a popup item index
					opt.set_block_signals(false)
				return

	# Apply selection
	eq[slot_idx] = sid
	Game.player.set("equipped_active_skills", eq)

	# Update slot tooltip immediately
	opt.tooltip_text = _tooltip_for_skill(sid)

	# Remember last valid selection (store the popup item index)
	if slot_idx >= 0 and slot_idx < _slot_last_selected.size():
		_slot_last_selected[slot_idx] = index

	SaveManager.save_now()
	Game.player_changed.emit()

	_refresh_upgrade_all_visibility()

func _center_panel() -> void:
	var panel := get_node_or_null("MainPanel") as Control
	if panel == null:
		return

	# Force it to its minimum size; keeps it consistent across resolutions.
	panel.size = panel.custom_minimum_size

	# Center in viewport (top_level ensures viewport coords).
	var vp := get_viewport_rect().size
	panel.position = (vp - panel.size) * 0.5

func _rarity_rank(skill_id: String) -> int:
	var def: SkillDef = SkillCatalog.get_def(skill_id)
	if def == null:
		return 0
	if not ("rarity" in def):
		return 0
	return int(def.get("rarity"))

func _display_name_for(skill_id: String) -> String:
	var def: SkillDef = SkillCatalog.get_def(skill_id)
	if def == null:
		return skill_id
	return String(def.display_name)

func _skill_less(a: String, b: String) -> bool:
	var ra := _rarity_rank(a)
	var rb := _rarity_rank(b)
	if ra != rb:
		return ra < rb # Common -> Mythical
	var na := _display_name_for(a).to_lower()
	var nb := _display_name_for(b).to_lower()
	if na != nb:
		return na < nb
	# final tie-breaker
	return a < b

func _rarity_header_text(r: int) -> String:
	match r:
		0: return "— Common —"
		1: return "— Uncommon —"
		2: return "— Rare —"
		3: return "— Legendary —"
		4: return "— Mythical —"
	return "— Common —"

func _find_item_index_by_id(opt: OptionButton, wanted_id: int) -> int:
	for i in range(opt.item_count):
		if opt.get_item_id(i) == wanted_id:
			return i
	return -1


# ---------------- Upgrades ----------------

func _can_upgrade_skill(skill_id: String) -> bool:
	if skill_id == "":
		return false
	var lv: int = _player_skill_level(skill_id)
	var prog: int = _player_skill_progress(skill_id)
	var req: int = _copies_required_for_next_level(lv)
	return prog >= req

func _can_upgrade_any() -> bool:
	# _skill_ids[0] is "".
	for i in range(1, _skill_ids.size()):
		var sid: String = _skill_ids[i]
		if _can_upgrade_skill(sid):
			return true
	return false

func _refresh_upgrade_all_visibility() -> void:
	if _upgrade_all_btn == null:
		return
	_upgrade_all_btn.visible = _can_upgrade_any()

func _refresh_option_unlock_states() -> void:
	# Enable/disable dropdown entries based on updated levels and refresh tooltips.
	for opt in _slot_opts:
		if opt == null:
			continue
		var popup := opt.get_popup()
		for item_index in range(opt.item_count):
			var item_id: int = opt.get_item_id(item_index)
			# id -1 = header, 0 = empty, >=1 maps to _skill_ids
			if item_id <= 0:
				continue
			if item_id >= _skill_ids.size():
				continue
			var sid: String = _skill_ids[item_id]
			var lv: int = _player_skill_level(sid)
			opt.set_item_disabled(item_index, lv <= 0)
			popup.set_item_tooltip(item_index, _tooltip_for_skill(sid))

func _on_upgrade_all_pressed() -> void:
	if Game.player == null:
		return
	if Game.player.has_method("ensure_active_skills_initialized"):
		Game.player.call("ensure_active_skills_initialized")

	# Pull dict references, but write back via set() after mutation.
	var levels_v: Variant = Game.player.get("skill_levels")
	var prog_v: Variant = Game.player.get("skill_progress")
	if typeof(levels_v) != TYPE_DICTIONARY or typeof(prog_v) != TYPE_DICTIONARY:
		return

	var levels: Dictionary = levels_v as Dictionary
	var prog: Dictionary = prog_v as Dictionary

	var total_levels_gained: int = 0
	var skills_upgraded: int = 0

	for i in range(1, _skill_ids.size()):
		var sid: String = _skill_ids[i]
		var lv: int = int(levels.get(sid, 0))
		var p: int = int(prog.get(sid, 0))
		var gained: int = 0

		while true:
			var req: int = _copies_required_for_next_level(lv)
			if p < req:
				break
			p -= req
			lv += 1
			gained += 1

		if gained > 0:
			skills_upgraded += 1
			total_levels_gained += gained
			levels[sid] = lv
			prog[sid] = p

	# Persist back to player
	Game.player.set("skill_levels", levels)
	Game.player.set("skill_progress", prog)

	if _status_label != null:
		if total_levels_gained > 0:
			_status_label.text = "Upgraded %d level(s) across %d skill(s)." % [total_levels_gained, skills_upgraded]
		else:
			_status_label.text = ""

	SaveManager.save_now()
	Game.player_changed.emit()

	# Refresh UI states (unlocking/tooltip updates and button visibility)
	_refresh_option_unlock_states()
	_refresh_upgrade_all_visibility()
