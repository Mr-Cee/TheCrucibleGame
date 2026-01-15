extends VBoxContainer

@onready var difficulty_label: Label = $DifficultyLabel
@onready var enemy_hp_bar: ProgressBar = $EnemyHPBar
@onready var result_label: Label = get_node_or_null("ResultLabel") as Label

@onready var combat_log_scroll: ScrollContainer = $CombatLogScroll
@onready var combat_log: RichTextLabel = $CombatLogScroll/CombatLog

@onready var log_controls: HBoxContainer = get_node_or_null("LogControls") as HBoxContainer
@onready var log_filter: OptionButton = get_node_or_null("LogControls/LogFilter") as OptionButton
@onready var compact_toggle: CheckButton = get_node_or_null("LogControls/CompactToggle") as CheckButton
@onready var clear_log_button: Button = get_node_or_null("LogControls/ClearLogButton") as Button

# --- Skills row (matches your scene tree) ---
@onready var skills_row: HBoxContainer = get_node_or_null("SkillsRow") as HBoxContainer
@onready var auto_skills_toggle: CheckButton = get_node_or_null("SkillsRow/AutoSkillsToggle") as CheckButton

const SKILL_SLOTS: int = 5
const SKILL_ICON_SIZE: int = 36

var _skill_icon_buttons: Array[Button] = []
var _skill_cd_labels: Array[Label] = []
var _skill_mode_label: Label = null
var _skill_icon_cache: Dictionary = {} # skill_id -> scaled Texture2D

# Combat log state
var _log_filter_mode: String = "all" # all/player/enemy/reward/system
var _log_buf: String = ""
var _log_pinned_to_bottom: bool = true
var _log_programmatic_scroll: bool = false
const LOG_PIN_THRESHOLD_PX: float = 80.0

var _task_overlay: CanvasLayer
var _task_root: Control
var _task_panel: Control
var _task_reposition_queued: bool = false

# Placeholder battlefield visuals (player + enemy squares)
var _battlefield_row: HBoxContainer = null
var _player_square: ColorRect = null
var _enemies_grid: GridContainer = null
var _enemy_squares: Array[Control] = []
var _last_enemy_count: int = -1

const ENEMY_DIR := "res://assets/enemies"
const ENEMY_FALLBACK := preload("res://assets/enemies/enemy_goblin.png")

var _enemy_textures: Array[Texture2D] = []

var _enemy_prev_alive: Array[bool] = []


var _ui_accum: float = 0.0

func _ready() -> void:
	_apply_labels()
	_ensure_skills_row_ui()
	_ensure_task_panel_overlay()
	_ensure_battlefield_ui()


	# --- Combat log setup ---
	combat_log.bbcode_enabled = true

	if _log_buf != "" and not _log_buf.ends_with("\n"):
		_log_buf += "\n"

	# Track whether user has scrolled up (unpinned) or is at bottom (pinned)
	if combat_log_scroll:
		var bar := combat_log_scroll.get_v_scroll_bar()
		if bar and not bar.value_changed.is_connected(_on_log_scroll_value_changed):
			bar.value_changed.connect(_on_log_scroll_value_changed)

	# Controls
	if log_filter:
		log_filter.clear()
		log_filter.add_item("All", 0)
		log_filter.add_item("Player", 1)
		log_filter.add_item("Enemy", 2)
		log_filter.add_item("Rewards", 3)
		log_filter.add_item("System", 4)
		log_filter.item_selected.connect(func(idx: int) -> void:
			match idx:
				0: _log_filter_mode = "all"
				1: _log_filter_mode = "player"
				2: _log_filter_mode = "enemy"
				3: _log_filter_mode = "reward"
				4: _log_filter_mode = "system"
			_log_pinned_to_bottom = true
			_rebuild_log_from_game()
			_request_scroll_bottom()
		)

	if compact_toggle:
		compact_toggle.button_pressed = false
		compact_toggle.toggled.connect(func(on: bool) -> void:
			Game.set_combat_log_compact_user(on)
		)

	if clear_log_button:
		clear_log_button.pressed.connect(func() -> void:
			Game.clear_combat_log()
		)

	# Signals
	if not Game.combat_log_entry_added.is_connected(_on_combat_log_entry_added):
		Game.combat_log_entry_added.connect(_on_combat_log_entry_added)

	if not Game.combat_log_cleared.is_connected(_on_combat_log_cleared):
		Game.combat_log_cleared.connect(_on_combat_log_cleared)

	_rebuild_log_from_game()
	_scroll_log_to_bottom()
	
	#var tp := preload("res://scripts/systems/Tasks/TaskPanel.gd").new()
	#tp.name = "TaskPanel"
#
	## Anchor bottom-left
	#tp.anchor_left = 0.0
	#tp.anchor_right = 0.0
	#tp.anchor_top = 1.0
	#tp.anchor_bottom = 1.0
#
	## Position/size (tune as you like)
	#tp.offset_left = 16
	#tp.offset_right = 16 + 280
	#tp.offset_top = -60
	#tp.offset_bottom = -16
#
	#add_child(tp)

func _process(delta: float) -> void:
	_ui_accum += delta
	if _ui_accum < 0.10:
		return
	_ui_accum = 0.0

	if result_label:
		var s: String = String(Game.battle_runtime.get("status_text", ""))
		result_label.text = s
		result_label.visible = (s != "")

	_apply_labels()
	_apply_enemy_hp()
	_apply_battlefield_ui()
	_apply_skill_row()

func _apply_labels() -> void:
	var diff: String = String(Game.battle_state.get("difficulty", "Easy"))
	var lvl: int = int(Game.battle_state.get("level", 1))
	var stg: int = int(Game.battle_state.get("stage", 1))
	var wav: int = int(Game.battle_state.get("wave", 1))

	difficulty_label.text = "%s - %d - %d (Wave %d/%d)" % [
		diff, lvl, stg, wav, Catalog.BATTLE_WAVES_PER_STAGE
	]

func _apply_enemy_hp() -> void:
	var hp: float = float(Game.battle_runtime.get("enemy_hp", 0.0))
	var hp_max: float = max(1.0, float(Game.battle_runtime.get("enemy_hp_max", 1.0)))

	enemy_hp_bar.max_value = 100.0
	enemy_hp_bar.value = (hp / hp_max) * 100.0

# ---------------- Skill row ----------------

func _scaled_skill_icon(skill_id: String) -> Texture2D:
	if skill_id == "":
		return null
	if _skill_icon_cache.has(skill_id):
		return _skill_icon_cache[skill_id]

	# Prefer catalog/def icon, but fallback to convention path.
	var tex: Texture2D = null
	var d := SkillCatalog.get_def(skill_id)
	if d != null and d.has_method("icon_texture"):
		tex = d.icon_texture()
	if tex == null:
		var p := "res://assets/icons/skills/%s.png" % skill_id
		if ResourceLoader.exists(p):
			tex = load(p) as Texture2D

	if tex == null:
		_skill_icon_cache[skill_id] = null
		return null

	var img := tex.get_image()
	if img == null:
		_skill_icon_cache[skill_id] = tex
		return tex

	img.resize(SKILL_ICON_SIZE, SKILL_ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	var out := ImageTexture.create_from_image(img)
	_skill_icon_cache[skill_id] = out
	return out

func _ensure_skills_row_ui() -> void:
	if skills_row == null:
		return

	# Ensure a left label exists
	if skills_row.get_node_or_null("SkillsLabel") == null:
		var skills_lbl := Label.new()
		skills_lbl.name = "SkillsLabel"
		skills_lbl.text = "Skills"
		skills_lbl.custom_minimum_size = Vector2(52, 0)
		skills_row.add_child(skills_lbl)
		skills_row.move_child(skills_lbl, 0)

	# Create a strip for the 5 slots
	var btn_strip := skills_row.get_node_or_null("SkillButtons") as HBoxContainer
	if btn_strip == null:
		btn_strip = HBoxContainer.new()
		btn_strip.name = "SkillButtons"
		btn_strip.add_theme_constant_override("separation", 8)
		btn_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skills_row.add_child(btn_strip)
		var idx := skills_row.get_node("SkillsLabel").get_index() + 1
		skills_row.move_child(btn_strip, idx)

	# Create buttons + cooldown labels (under icon)
	if _skill_icon_buttons.is_empty():
		for i in range(SKILL_SLOTS):
			var slot_box := VBoxContainer.new()
			slot_box.add_theme_constant_override("separation", 2)
			btn_strip.add_child(slot_box)

			var b := Button.new()
			b.custom_minimum_size = Vector2(SKILL_ICON_SIZE + 18, SKILL_ICON_SIZE + 18)
			b.expand_icon = true
			b.text = ""
			b.disabled = true
			b.pressed.connect(func() -> void:
				if Game != null and Game.has_method("request_cast_active_skill"):
					Game.request_cast_active_skill(i)
			)
			slot_box.add_child(b)
			_skill_icon_buttons.append(b)

			var cd := Label.new()
			cd.text = ""
			cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cd.modulate = Color(0.9, 0.9, 0.9, 1.0)
			slot_box.add_child(cd)
			_skill_cd_labels.append(cd)

	# Spacer to push toggle to the right
	if skills_row.get_node_or_null("SkillSpacer") == null:
		var spacer := Control.new()
		spacer.name = "SkillSpacer"
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skills_row.add_child(spacer)

	# Label explaining toggle
	_skill_mode_label = skills_row.get_node_or_null("SkillModeLabel") as Label
	if _skill_mode_label == null:
		_skill_mode_label = Label.new()
		_skill_mode_label.name = "SkillModeLabel"
		_skill_mode_label.text = "Skill Cast:"
		skills_row.add_child(_skill_mode_label)

	# Ensure toggle exists and is rightmost
	if auto_skills_toggle != null:
		skills_row.move_child(auto_skills_toggle, skills_row.get_child_count() - 2)
		skills_row.move_child(_skill_mode_label, auto_skills_toggle.get_index())

		auto_skills_toggle.toggled.connect(func(v: bool) -> void:
			auto_skills_toggle.text = "Auto" if v else "Manual"
			if Game != null and Game.has_method("set_skills_auto_enabled"):
				Game.set_skills_auto_enabled(v)
			if Game != null and Game.player != null and ("skill_auto" in Game.player):
				Game.player.set("skill_auto", v)
		)

func _apply_skill_row() -> void:
	if skills_row == null or _skill_icon_buttons.is_empty():
		return
	if Game == null or Game.player == null:
		return

	# Determine auto/manual (for enabling manual clicks)
	var auto_on := true
	if Game.has_method("skills_auto_enabled"):
		auto_on = bool(Game.skills_auto_enabled())
	elif "skill_auto" in Game.player:
		auto_on = bool(Game.player.get("skill_auto"))

	if auto_skills_toggle != null:
		auto_skills_toggle.button_pressed = auto_on
		auto_skills_toggle.text = "Auto" if auto_on else "Manual"

	# Read equipped skills directly from PlayerModel (most reliable)
	var eq := Game.player.equipped_active_skills

	for i in range(SKILL_SLOTS):
		var sid: String = ""
		if eq != null and i < eq.size():
			sid = String(eq[i])

		var btn := _skill_icon_buttons[i]
		var cd_lbl := _skill_cd_labels[i]

		if sid == "":
			btn.icon = null
			btn.disabled = true
			btn.tooltip_text = ""
			cd_lbl.text = ""
			continue

		var d := SkillCatalog.get_def(sid)
		btn.icon = SkillCatalog.icon_with_rarity_border(sid, SKILL_ICON_SIZE, 2)

		btn.tooltip_text = (d.display_name + "\n" + d.description) if d != null else sid

		var rem: float = 0.0
		if Game.has_method("get_skill_cooldown_remaining"):
			rem = float(Game.get_skill_cooldown_remaining(i))

		if rem > 0.0:
			btn.disabled = true
			cd_lbl.text = "%.1f" % rem
		else:
			btn.disabled = auto_on
			cd_lbl.text = ""

# ---------------- Combat log ----------------

func _on_combat_log_entry_added(_entry: Dictionary) -> void:
	var was_pinned: bool = _log_pinned_to_bottom
	_rebuild_log_from_game()
	if was_pinned:
		_request_scroll_bottom()

func _on_combat_log_cleared() -> void:
	_log_pinned_to_bottom = true
	_log_buf = ""
	_render_log_text()
	_scroll_log_to_bottom()

func _scroll_log_to_bottom() -> void:
	if combat_log_scroll == null:
		return
	_log_programmatic_scroll = true
	combat_log_scroll.scroll_vertical = 1_000_000_000
	_log_pinned_to_bottom = true
	call_deferred("_end_programmatic_scroll")

func _request_scroll_bottom() -> void:
	call_deferred("_scroll_bottom_pass1")

func _scroll_bottom_pass1() -> void:
	call_deferred("_scroll_bottom_pass2")

func _scroll_bottom_pass2() -> void:
	if combat_log_scroll == null:
		return
	_log_programmatic_scroll = true
	combat_log_scroll.scroll_vertical = 1_000_000_000
	_log_pinned_to_bottom = true
	call_deferred("_end_programmatic_scroll")

func _end_programmatic_scroll() -> void:
	_log_programmatic_scroll = false

func _rebuild_log_from_game() -> void:
	var entries: Array[Dictionary] = Game.get_combat_log_entries()
	var lines: Array[String] = []
	for e in entries:
		var cat: String = String(e.get("cat", "system"))
		if _log_filter_mode != "all" and cat != _log_filter_mode:
			continue
		lines.append(String(e.get("bb", "")))

	_log_buf = "\n".join(lines)
	if _log_buf != "" and not _log_buf.ends_with("\n"):
		_log_buf += "\n"

	_render_log_text()

func _render_log_text() -> void:
	if combat_log == null:
		return

	combat_log.bbcode_enabled = true
	combat_log.add_theme_color_override("default_color", Color(1, 1, 1, 1))
	combat_log.set("scroll_active", false)
	combat_log.clear()

	if combat_log.has_method("parse_bbcode"):
		combat_log.call("parse_bbcode", _log_buf)
	else:
		combat_log.text = _log_buf

func _on_log_scroll_value_changed(_v: float) -> void:
	if _log_programmatic_scroll:
		return
	var bar := combat_log_scroll.get_v_scroll_bar()
	if bar == null:
		return

	# Bottom is (max_value - page), not max_value.
	var page: float = float(bar.page)
	var bottom: float = max(0.0, float(bar.max_value) - page)
	var threshold: float = max(LOG_PIN_THRESHOLD_PX, float(bar.page) * 0.05)
	_log_pinned_to_bottom = (float(bar.value) >= (bottom - threshold))

func _ensure_task_panel_overlay() -> void:
	# Create overlay once
	if _task_overlay == null:
		_task_overlay = CanvasLayer.new()
		_task_overlay.name = "TaskOverlay"
		_task_overlay.layer = 1
		add_child(_task_overlay)

	if _task_root == null:
		_task_root = Control.new()
		_task_root.name = "Root"
		_task_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_task_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		_task_root.offset_left = 0
		_task_root.offset_top = 0
		_task_root.offset_right = 0
		_task_root.offset_bottom = 0
		_task_overlay.add_child(_task_root)

	if _task_panel == null:
		_task_panel = (preload("res://scripts/systems/Tasks/TaskPanel.gd").new() as Control)
		_task_panel.name = "TaskPanel"
		_task_root.add_child(_task_panel)

		# We will position via offsets; keep it top-left anchored
		_task_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)

	# Reposition after layout has run
	_queue_task_panel_reposition()

	# Reposition on screen resize
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_queue_task_panel_reposition):
		vp.size_changed.connect(_queue_task_panel_reposition)

	# Reposition if the skills row layout changes
	if skills_row != null and not skills_row.resized.is_connected(_queue_task_panel_reposition):
		skills_row.resized.connect(_queue_task_panel_reposition)

func _queue_task_panel_reposition() -> void:
	if _task_reposition_queued:
		return
	_task_reposition_queued = true
	call_deferred("_reposition_task_panel")

func _ensure_battlefield_ui() -> void:
	# Create a simple row of squares for player + enemies. Insert under combat log.
	if _battlefield_row != null:
		return

	_battlefield_row = HBoxContainer.new()
	_battlefield_row.name = "BattlefieldRow"
	_battlefield_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battlefield_row.add_theme_constant_override("separation", 12)
	
	_battlefield_row.custom_minimum_size = Vector2(0, 275) # tweak 100–220 to taste
	
	# Let this row take vertical space so its contents can be centered in that gap.
	_battlefield_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_battlefield_row.size_flags_stretch_ratio = 1.0

	# For HBoxContainer, this centers children vertically within the row's height.
	_battlefield_row.alignment = BoxContainer.ALIGNMENT_CENTER

	# Player square
	_player_square = ColorRect.new()
	_player_square.custom_minimum_size = Vector2(32, 32)
	_player_square.color = Color(0.2, 0.9, 0.3, 1.0)
	_player_square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_player_square.tooltip_text = "Player"
	_battlefield_row.add_child(_player_square)
	
	# Spacer to push enemies to the right.
	var spacer := Control.new()
	spacer.name = "BattlefieldSpacer"
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.size_flags_stretch_ratio = 1.5
	_battlefield_row.add_child(spacer)


	# Enemy squares grid
	_enemies_grid = GridContainer.new()
	_enemies_grid.columns = 7
	_enemies_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#_enemies_grid.size_flags_stretch_ratio = 1.0
	_enemies_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_enemies_grid.add_theme_constant_override("h_separation", 6)
	_enemies_grid.add_theme_constant_override("v_separation", 6)
	_battlefield_row.add_child(_enemies_grid)

	# Insert just above the skills row for a "under combat log" feel.
	var insert_before: int = get_child_count()
	if combat_log != null:
		insert_before = combat_log.get_index() + 4
	add_child(_battlefield_row)
	move_child(_battlefield_row, insert_before)

func _rebuild_enemy_squares(count: int) -> void:
	for c in _enemies_grid.get_children():
		c.queue_free()
	_enemy_squares.clear()
	_enemy_prev_alive.clear()
	
	if _enemy_textures.is_empty():
		_load_enemy_textures()

	for i in range(count):
		# Cell holds HP bar + sprite
		var cell := VBoxContainer.new()
		cell.name = "EnemyCell_%d" % i
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_theme_constant_override("separation", 2)

		# --- HP bar (background + fill) ---
		var hp_bar := Control.new()
		hp_bar.name = "HPBar"
		hp_bar.custom_minimum_size = Vector2(48, 6)
		hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var bg := ColorRect.new()
		bg.name = "BG"
		bg.color = Color(0, 0, 0, 0.55)
		bg.anchor_right = 1.0
		bg.anchor_bottom = 1.0
		hp_bar.add_child(bg)

		var fg := ColorRect.new()
		fg.name = "FG"
		fg.color = Color(0.2, 0.9, 0.3, 1.0)
		fg.anchor_bottom = 1.0
		fg.anchor_right = 0.0 # we drive width via offset_right
		fg.offset_right = hp_bar.custom_minimum_size.x
		hp_bar.add_child(fg)

		cell.add_child(hp_bar)

		# --- Enemy sprite ---
		var spr := TextureRect.new()
		spr.name = "Sprite"
		spr.texture = _enemy_textures.pick_random()
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.custom_minimum_size = Vector2(96, 96)
		spr.size = Vector2(32, 32)
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.modulate = Color(1, 1, 1, 1)
		spr.self_modulate = Color(1, 1, 1, 1)

		cell.add_child(spr)

		_enemies_grid.add_child(cell)
		_enemy_squares.append(cell)
		_enemy_prev_alive.append(true)

func _apply_battlefield_ui() -> void:
	if _battlefield_row == null:
		return
	if Game == null:
		return

	var enemies: Array = []
	if Game.has_method("get_enemies_snapshot"):
		enemies = Game.call("get_enemies_snapshot")
	else:
		# Backwards compatibility fallback
		var br: Dictionary = Game.battle_runtime
		if br.has("enemies"):
			enemies = br["enemies"]

	var need_rebuild := _enemy_squares.size() != enemies.size()
	if not need_rebuild and _enemy_squares.size() > 0:
		need_rebuild = not (_enemy_squares[0].has_node("HPBar"))

	if need_rebuild:
		_rebuild_enemy_squares(enemies.size())
	
	_sync_enemy_sprites(enemies, -1)

	# Update colors to reflect alive/target; alpha reflects HP %.
	for i in range(_enemy_squares.size()):
		var rect := _enemy_squares[i]
		if rect == null:
			continue
		var e: Dictionary = enemies[i]
		var hp: float = float(e.get("hp", 0.0))
		var hm: float = max(1.0, float(e.get("hp_max", 1.0)))
		var pct: float = clamp(hp / hm, 0.0, 1.0)
		var alive: bool = bool(e.get("alive", hp > 0.0))
		var is_target: bool = bool(e.get("is_target", false))


		# HP % as transparency cue (pure placeholder)
		#rect.modulate.a = 0.30 + 0.70 * pct

func _reposition_task_panel() -> void:
	_task_reposition_queued = false

	if _task_panel == null or skills_row == null:
		return

	# If layout isn't ready yet, try again next frame
	var sr := skills_row.get_global_rect()
	if sr.size == Vector2.ZERO:
		_queue_task_panel_reposition()
		return

	var margin: float = 8.0
	var min_x: float = 16.0

	# Use the panel's minimum size (TaskPanel.gd should set custom_minimum_size)
	var ps := _task_panel.get_combined_minimum_size()
	if ps == Vector2.ZERO:
		ps = Vector2(320, 48) # fallback only if minimum size isn't set

	# Align with the skills row on X (but keep a minimum left margin)
	var x: float = maxf(min_x, sr.position.x)

	# Place ABOVE the skills row
	var y: float = sr.position.y - ps.y - margin

	# If that would go off-screen, fall back to BELOW the skills row
	if y < margin:
		y = sr.position.y + sr.size.y + margin

	_task_panel.offset_left = x
	_task_panel.offset_right = x + ps.x
	_task_panel.offset_top = y
	_task_panel.offset_bottom = y + ps.y

func _sync_enemy_sprites(enemies: Array[Dictionary], target_idx: int) -> void:
	# Keep tracker sized correctly
	if _enemy_prev_alive.size() != enemies.size():
		_enemy_prev_alive.resize(enemies.size())
		for i in range(_enemy_prev_alive.size()):
			_enemy_prev_alive[i] = true

	for i in range(_enemy_squares.size()):
		var cell := _enemy_squares[i]
		if i >= enemies.size():
			cell.visible = false
			continue

		cell.visible = true

		var hp: float = float(enemies[i].get("hp", 0.0))
		var hp_max: float = maxf(1.0, float(enemies[i].get("hp_max", 1.0)))
		var pct: float = clampf(hp / hp_max, 0.0, 1.0)
		var alive: bool = hp > 0.0
		
		# If already fully faded and still dead, keep hidden.
		if not alive and cell.has_meta("dead_hidden") and bool(cell.get_meta("dead_hidden")):
			cell.visible = false
			continue

		# If alive (new wave/reused slot), ensure it's visible again.
		if alive and cell.has_meta("dead_hidden") and bool(cell.get_meta("dead_hidden")):
			cell.set_meta("dead_hidden", false)
			cell.visible = true
			cell.modulate = Color(1, 1, 1, 1)


		var spr := cell.get_node("Sprite") as TextureRect
		var hp_bar := cell.get_node("HPBar") as Control
		var fg := hp_bar.get_node("FG") as ColorRect

		# Update bar fill width
		var w := maxf(hp_bar.size.x, hp_bar.custom_minimum_size.x)
		fg.offset_right = w * pct

		## Target highlight tint (sprite only)
		#if alive and i == target_idx:
			#spr.self_modulate = Color(1.0, 0.9, 0.6, 1.0)
		#else:
			#spr.self_modulate = Color(1.0, 1.0, 1.0, 1.0)

		# Fade out once when transitioning alive -> dead (fade the whole cell)
		var was_alive := _enemy_prev_alive[i]
		if was_alive and not alive:
			_fade_out_enemy_sprite(cell)

		## If alive (or rebuilt), ensure visible alpha
		#if alive and cell.modulate.a < 0.99:
			#cell.modulate = Color(1, 1, 1, 1)

		_enemy_prev_alive[i] = alive

func _fade_out_enemy_sprite(sq: CanvasItem) -> void:
	# Prevent double-tweening.
	if sq.has_meta("fading") and bool(sq.get_meta("fading")):
		return
	sq.set_meta("fading", true)
	sq.set_meta("dead_hidden", false)
	sq.visible = true

	var t := create_tween()
	t.tween_property(sq, "modulate:a", 0.0, 0.35) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_IN_OUT)

	t.finished.connect(func():
		# Hard-finalize the death: completely hidden.
		sq.modulate.a = 0.0
		sq.visible = false
		sq.set_meta("dead_hidden", true)
		sq.set_meta("fading", false)
	)

func _load_enemy_textures() -> void:
	_enemy_textures.clear()

	var dir := DirAccess.open(ENEMY_DIR)
	if dir == null:
		_enemy_textures.append(ENEMY_FALLBACK)
		return

	dir.list_dir_begin()
	var fn := dir.get_next()
	while fn != "":
		if not dir.current_is_dir():
			var low := fn.to_lower()
			# Ignore .import and only load .png
			if low.ends_with(".png") and not low.ends_with(".png.import"):
				var path := "%s/%s" % [ENEMY_DIR, fn]
				var res := ResourceLoader.load(path)
				if res is Texture2D:
					_enemy_textures.append(res)
		fn = dir.get_next()
	dir.list_dir_end()

	if _enemy_textures.is_empty():
		_enemy_textures.append(ENEMY_FALLBACK)
