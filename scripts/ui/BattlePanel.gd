extends VBoxContainer

@onready var difficulty_label: Label = $DifficultyLabel
@onready var enemy_hp_bar: ProgressBar = $EnemyHPBar
@onready var result_label: Label = get_node_or_null("ResultLabel") as Label
@onready var challenge_button: Button = get_node_or_null("ChallengeButton") as Button

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

var _dock: VBoxContainer = null
var _skill_cast_row: HBoxContainer = null

const DOCK_LEFT_MARGIN: float = 16.0
const DOCK_BOTTOM_OFFSET: float = 400.0 # tweak until it sits right above your Speed dropdown
const DOCK_SEPARATION: int = 6


# Placeholder battlefield visuals (player + enemy squares)
var _battlefield_row: HBoxContainer = null
#var _player_square: ColorRect = null
#var _enemies_grid: GridContainer = null
var _battlefield_canvas: Control = null
var _enemy_squares: Array[Control] = []
var _last_enemy_count: int = -1

# Layout tuning
const PLAYER_X_FRAC: float = 0.18          # player center at ~18% of canvas width (move left/right here)
const PLAYER_GROUND_PAD: float = 6.0

const ENEMY_PACK_X_FRAC: float = 0.52      # enemy pack center at ~78% of canvas width
const ENEMY_COLS: int = 3                  # enemies arranged in 3 columns
const ENEMY_X_SPACING: float = 56.0        # horizontal spacing between enemies
const ENEMY_Y_SPACING: float = 34.0        # vertical stagger between rows (smaller => more overlap)

const ENEMY_JITTER_X: float = 32.0         # random +/- x offset per enemy (stable per wave)
const ENEMY_JITTER_Y: float = 14.0         # random +/- y offset per enemy (stable per wave)

var _enemy_jitter: Array[Vector2] = []
var _enemy_layout_key: String = ""

const ENEMY_MIN_GAP_PX: float = 80.0   # distance between player center and enemy pack center
const ENEMY_LERP: float = 0.18          # movement smoothing (one-liner lerp factor)

const ENEMY_SPAWN_OFFSCREEN_PAD_PX: float = 80.0  # how far off the right edge they start
const ENEMY_SPAWN_STAGGER_PX: float = 18.0        # optional: spreads their start X a bit

const ENEMY_ENTER_STAGGER_SEC: float = 0.28        # delay between each enemy starting to move
const ENEMY_ENTER_DURATION_SEC: float = 2.1       # how long each enemy takes to reach position (bigger = slower)
const ENEMY_FOLLOW_LERP: float = 0.08              # after they arrive, how gently they follow layout changes

var _enemy_enter_t0_ms: int = 0


const ENEMY_DIR := "res://assets/enemies"
const ENEMY_FALLBACK := preload("res://assets/enemies/enemy_goblin.png")
const MINION_SPR_SCALE: float = 0.12          # your current tuned value
const BOSS_SPR_SCALE_MULT: float = 1.75       # pick 1.5–2.0 to taste
var _enemy_textures: Array[Texture2D] = []
var _enemy_prev_alive: Array[bool] = []

const PLAYER_TEX_WARRIOR: Texture2D = preload("res://assets/player/warrior.png")
const PLAYER_TEX_MAGE: Texture2D = preload("res://assets/player/mage.png")
const PLAYER_TEX_ARCHER: Texture2D = preload("res://assets/player/archer.png")
var _player_sprite: TextureRect = null
var _player_sprite_key: String = ""

var _challenge_row: HBoxContainer = null
var _challenge_button: Button = null


var _ui_accum: float = 0.0

func _ready() -> void:
	_apply_labels()
	_ensure_skills_row_ui()
	_ensure_task_panel_overlay()
	_ensure_battlefield_ui()
	_ensure_challenge_button_ui()
	_apply_challenge_button()
	
	# Give the combat log the vertical space by default.
	if combat_log_scroll != null:
		combat_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		combat_log_scroll.size_flags_stretch_ratio = 4.0
		# Optional safety minimum so it never collapses too small:
		combat_log_scroll.custom_minimum_size.y = 220



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

func _process(delta: float) -> void:
	## Update battlefield positions every frame for smooth approach
	if Game != null and Game.has_method("get_enemies_snapshot") and _battlefield_canvas != null:
		var enemies: Array[Dictionary] = Game.get_enemies_snapshot()
		if _enemy_squares.size() == enemies.size() and _enemy_squares.size() > 0:
			_layout_battlefield(enemies.size())


	
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
	_apply_challenge_button()

func _apply_labels() -> void:
	var diff: String = String(Game.battle_state.get("difficulty", "Easy"))
	var lvl: int = int(Game.battle_state.get("level", 1))
	var stg: int = int(Game.battle_state.get("stage", 1))
	var wav: int = int(Game.battle_state.get("wave", 1))

	if _is_endless_mode_ui():
		difficulty_label.text = "%s - %d - %d" % [diff, lvl, stg]
	else:
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
		
		_ensure_bottom_left_dock()


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
	if _battlefield_row != null:
		return

	_battlefield_row = HBoxContainer.new()
	_battlefield_row.name = "BattlefieldRow"
	_battlefield_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Reserve enough height for sprites; don't steal log space.
	_battlefield_row.custom_minimum_size = Vector2(0, 150)
	_battlefield_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_battlefield_row.size_flags_stretch_ratio = 0.0

	# Free-layout battlefield canvas (full width)
	_battlefield_canvas = Control.new()
	_battlefield_canvas.name = "BattlefieldCanvas"
	_battlefield_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battlefield_canvas.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_battlefield_canvas.custom_minimum_size = Vector2(0, 150)
	_battlefield_canvas.clip_contents = true
	_battlefield_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battlefield_row.add_child(_battlefield_canvas)

	# Player sprite (added to canvas)
	_player_sprite = TextureRect.new()
	_player_sprite.name = "PlayerSprite"
	_player_sprite.custom_minimum_size = Vector2(100, 100)
	_player_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_player_sprite_key = _player_sprite_key_from_player()
	_player_sprite.texture = _player_texture_for_key(_player_sprite_key)

	_battlefield_canvas.add_child(_player_sprite)

	# Insert just above the skills row
	var insert_before: int = get_child_count()
	if combat_log != null:
		insert_before = combat_log.get_index() + 4
	add_child(_battlefield_row)
	move_child(_battlefield_row, insert_before)

func _ensure_challenge_button_ui() -> void:
	if _challenge_row != null:
		return

	# Row centered, full width
	_challenge_row = HBoxContainer.new()
	_challenge_row.name = "ChallengeRow"
	_challenge_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_challenge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_challenge_row.custom_minimum_size = Vector2(0, 34)

	# Reuse existing scene button if present, otherwise create it.
	if challenge_button == null:
		challenge_button = Button.new()
		challenge_button.name = "ChallengeButton"
		challenge_button.text = "Challenge"

	# Make it the small pill style
	challenge_button.focus_mode = Control.FOCUS_NONE
	challenge_button.custom_minimum_size = Vector2(128, 28)
	challenge_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_challenge_button_theme(challenge_button)

	# Ensure it is parented under the row (not directly under the panel)
	var p := challenge_button.get_parent()
	if p != null:
		p.remove_child(challenge_button)
	_challenge_row.add_child(challenge_button)

	# Insert row directly under HP bar
	add_child(_challenge_row)
	if enemy_hp_bar != null:
		move_child(_challenge_row, enemy_hp_bar.get_index() + 1)

	# Wire once
	if not challenge_button.pressed.is_connected(_on_challenge_pressed):
		challenge_button.pressed.connect(_on_challenge_pressed)

	# Default hidden; driven by _apply_challenge_button()
	_challenge_row.visible = false
	challenge_button.disabled = true

func _apply_challenge_button_theme(b: Button) -> void:
	# Typography
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", Color8(255, 240, 240))
	b.add_theme_color_override("font_hover_color", Color8(255, 255, 255))
	b.add_theme_color_override("font_pressed_color", Color8(255, 255, 255))
	b.add_theme_color_override("font_disabled_color", Color8(220, 220, 220))

	# Normal
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color8(190, 45, 45)
	normal.border_color = Color8(95, 15, 15)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 3
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_left = 12
	normal.corner_radius_bottom_right = 12
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4

	# Hover
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color8(215, 55, 55)

	# Pressed
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color8(155, 35, 35)
	pressed.border_width_bottom = 2

	# Disabled
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color8(120, 60, 60)
	disabled.border_color = Color8(70, 40, 40)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)

func _is_endless_mode_ui() -> bool:
	# Endless mode = boss was attempted/failed and the Challenge button is available.
	return _can_challenge_wave5_ui()

func _can_challenge_wave5_ui() -> bool:
	if Game == null:
		return false

	# Preferred: Game proxies BattleSystem methods (recommended).
	if Game.has_method("can_challenge_wave5"):
		return bool(Game.call("can_challenge_wave5"))

	# Fallback: if Game exposes battle_system directly.
	var bs: Variant = null
	if Game.has_method("get"):
		bs = Game.get("battle_system")
	if bs != null and (bs as Object).has_method("can_challenge_wave5"):
		return bool((bs as Object).call("can_challenge_wave5"))

	return false

func _apply_challenge_button() -> void:
	if _challenge_row == null or challenge_button == null:
		return

	var can := _can_challenge_wave5_ui()
	_challenge_row.visible = can
	challenge_button.disabled = not can

func _on_challenge_pressed() -> void:
	if Game == null:
		return

	# Preferred: Game proxies to BattleSystem.
	if Game.has_method("challenge_wave5"):
		Game.call("challenge_wave5")
		return

	# Fallback: direct battle_system call if exposed.
	var bs: Variant = null
	if Game.has_method("get"):
		bs = Game.get("battle_system")
	if bs != null and (bs as Object).has_method("challenge_wave5"):
		(bs as Object).call("challenge_wave5")

func _rebuild_enemy_squares(count: int) -> void:
	# Clear existing enemy cells
	for c in _enemy_squares:
		if is_instance_valid(c):
			c.queue_free()
	_enemy_squares.clear()
	_enemy_prev_alive.clear()

	if _enemy_textures.is_empty():
		_load_enemy_textures()

	var is_boss: bool = _is_boss_visual()

	var scale_mult: float = (BOSS_SPR_SCALE_MULT if is_boss else 1.0)
	var sprite_size: Vector2 = (Vector2(132, 132) if is_boss else Vector2(92, 92))

	for i in range(count):
		var cell := VBoxContainer.new()
		cell.name = "EnemyCell_%d" % i
		cell.add_theme_constant_override("separation", 2)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# HP bar
		var hp_bar := Control.new()
		hp_bar.name = "HPBar"
		hp_bar.custom_minimum_size = Vector2(48, 10)
		if is_boss:
			hp_bar.custom_minimum_size.x *= scale_mult

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
		fg.anchor_right = 0.0
		fg.offset_right = hp_bar.custom_minimum_size.x
		hp_bar.add_child(fg)

		cell.add_child(hp_bar)

		# Sprite
		var spr := TextureRect.new()
		spr.name = "Sprite"
		spr.texture = _enemy_textures.pick_random()
		spr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spr.custom_minimum_size = sprite_size
		spr.size = sprite_size
		spr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cell.add_child(spr)

		# Add to canvas (IMPORTANT)
		_battlefield_canvas.add_child(cell)

		_enemy_squares.append(cell)
		_enemy_prev_alive.append(true)

func _apply_battlefield_ui() -> void:
	if _battlefield_row == null:
		return
	if Game == null:
		return
		
	if _player_sprite != null:
		var k := _player_sprite_key_from_player()
		if k != _player_sprite_key:
			_player_sprite_key = k
			_player_sprite.texture = _player_texture_for_key(k)


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
	_layout_battlefield(enemies.size())

	
	# Apply positions (this is where the x_norm -> x_px “one-liner” belongs)
	#_apply_enemy_positions(enemies)


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

func _reposition_task_panel() -> void:
	_task_reposition_queued = false
	if _dock == null:
		return

	# Ensure dock has a valid size (layout pass)
	var ds := _dock.get_combined_minimum_size()
	if ds == Vector2.ZERO:
		_queue_task_panel_reposition()
		return

	var vp := get_viewport()
	if vp == null:
		return
	var vps := vp.get_visible_rect().size

	var x: float = DOCK_LEFT_MARGIN
	var y: float = vps.y - DOCK_BOTTOM_OFFSET - ds.y

	# Clamp to keep it on-screen
	y = clampf(y, 8.0, vps.y - ds.y - 8.0)

	_dock.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_dock.offset_left = x
	_dock.offset_top = y
	_dock.offset_right = x + ds.x
	_dock.offset_bottom = y + ds.y

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
		if not is_instance_valid(sq):
			return
		if not (sq is CanvasItem):
			return

		sq.modulate = Color(sq.modulate.r, sq.modulate.g, sq.modulate.b, 0.0)
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

func _ensure_bottom_left_dock() -> void:
	if _dock != null:
		return
	if _task_root == null:
		return

	_dock = VBoxContainer.new()
	_dock.name = "BottomLeftDock"
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.add_theme_constant_override("separation", DOCK_SEPARATION)
	_task_root.add_child(_dock)

	# --- Skill Cast row (above skills buttons) ---
	_skill_cast_row = HBoxContainer.new()
	_skill_cast_row.name = "SkillCastRow"
	_skill_cast_row.add_theme_constant_override("separation", 8)
	_dock.add_child(_skill_cast_row)

	# Reuse or create the label
	if _skill_mode_label == null:
		_skill_mode_label = Label.new()
		_skill_mode_label.name = "SkillModeLabel"
		_skill_mode_label.text = "Skill Cast:"
	_skill_cast_row.add_child(_skill_mode_label)

	# Move the existing toggle into the cast row
	if auto_skills_toggle != null and auto_skills_toggle.get_parent() != _skill_cast_row:
		var oldp := auto_skills_toggle.get_parent()
		if oldp != null:
			oldp.remove_child(auto_skills_toggle)
		_skill_cast_row.add_child(auto_skills_toggle)

	# --- Skills row (buttons) ---
	if skills_row != null and skills_row.get_parent() != _dock:
		# Remove the spacer that pushes everything to the right
		var sp := skills_row.get_node_or_null("SkillSpacer")
		if sp != null:
			sp.queue_free()

		# If SkillModeLabel was previously inserted into SkillsRow, remove it
		var lbl_in_row := skills_row.get_node_or_null("SkillModeLabel")
		if lbl_in_row != null:
			skills_row.remove_child(lbl_in_row)

		# Reparent the skills row into the dock
		var srp := skills_row.get_parent()
		if srp != null:
			srp.remove_child(skills_row)
		_dock.add_child(skills_row)

	# --- Task panel (below skills) ---
	if _task_panel != null and _task_panel.get_parent() != _dock:
		var tp := _task_panel.get_parent()
		if tp != null:
			tp.remove_child(_task_panel)
		_dock.add_child(_task_panel)

func _player_sprite_key_from_player() -> String:
	if Game == null or Game.player == null:
		return "warrior"

	# Prefer the class tree id if you use it (advanced classes).
	var def_id: String = ""
	# PlayerModel.get() only accepts one argument (property name).
	if Game.player.has_method("get"):
		var v: Variant = Game.player.get("class_def_id")
		if v != null:
			def_id = String(v)
	def_id = def_id.to_lower()


	# Heuristic mapping for advanced classes (adjust names as needed).
	if def_id != "":
		if def_id.contains("archer") or def_id.contains("ranger") or def_id.contains("hunter"):
			return "archer"
		if def_id.contains("mage") or def_id.contains("wizard") or def_id.contains("sorc"):
			return "mage"
		if def_id.contains("warrior") or def_id.contains("knight") or def_id.contains("paladin") or def_id.contains("berserk"):
			return "warrior"

	# Fallback to base class_id enum.
	var cid: int = 0
	if Game.player.has_method("get"):
		var cv: Variant = Game.player.get("class_id")
		if cv != null:
			cid = int(cv)

	match cid:
		PlayerModel.ClassId.ARCHER:
			return "archer"
		PlayerModel.ClassId.MAGE:
			return "mage"
		_:
			return "warrior"

func _player_texture_for_key(k: String) -> Texture2D:
	match k:
		"archer": return PLAYER_TEX_ARCHER
		"mage": return PLAYER_TEX_MAGE
		_: return PLAYER_TEX_WARRIOR

func _current_layout_key(enemy_count: int) -> String:
	var diff: String = String(Game.battle_state.get("difficulty", "Easy"))
	var lvl: int = int(Game.battle_state.get("level", 1))
	var stg: int = int(Game.battle_state.get("stage", 1))
	var wav: int = int(Game.battle_state.get("wave", 1))
	var boss: int = (1 if _is_boss_visual() else 0)

	return "%s|%d|%d|%d|%d|%d" % [diff, lvl, stg, wav, enemy_count, boss]

func _ensure_enemy_jitter(enemy_count: int) -> void:
	var key := _current_layout_key(enemy_count)

	# New layout context (new wave/stage/etc.) => restart walk-in.
	if key != _enemy_layout_key:
		_enemy_enter_t0_ms = Time.get_ticks_msec()
		for c in _enemy_squares:
			if is_instance_valid(c) and c.has_meta("arrived"):
				c.remove_meta("arrived")

	if key == _enemy_layout_key and _enemy_jitter.size() == enemy_count:
		return

	_enemy_layout_key = key
	_enemy_jitter.resize(enemy_count)

	var rng := RandomNumberGenerator.new()
	rng.seed = abs(key.hash())

	for i in range(enemy_count):
		var jx := rng.randf_range(-ENEMY_JITTER_X, ENEMY_JITTER_X)
		var jy := rng.randf_range(-ENEMY_JITTER_Y, ENEMY_JITTER_Y)
		_enemy_jitter[i] = Vector2(jx, jy)

func _layout_battlefield(enemy_count: int) -> void:
	if _battlefield_canvas == null:
		return

	var cs := _battlefield_canvas.get_rect().size
	if cs.x <= 10.0 or cs.y <= 10.0:
		return

	var ground_y := cs.y - PLAYER_GROUND_PAD

	# --- Player ---
	var player_center_x: float = cs.x * PLAYER_X_FRAC
	if _player_sprite != null:
		var psz := _player_sprite.custom_minimum_size
		var px := player_center_x - (psz.x * 0.5)
		var py := ground_y - psz.y
		var ppos := Vector2(clampf(px, 0.0, cs.x - psz.x), clampf(py, 0.0, cs.y - psz.y))
		_player_sprite.position = ppos
		player_center_x = ppos.x + (psz.x * 0.5)

	# --- Enemies pack (stagger + jitter) ---
	_ensure_enemy_jitter(enemy_count)

	# Pack center: closer to player, but never closer than ENEMY_MIN_GAP_PX
	var pack_center_x := cs.x * ENEMY_PACK_X_FRAC
	pack_center_x = maxf(pack_center_x, player_center_x + ENEMY_MIN_GAP_PX)

	for i in range(mini(enemy_count, _enemy_squares.size())):
		var cell := _enemy_squares[i]
		if cell == null:
			continue

		var ms := cell.get_combined_minimum_size()
		if ms == Vector2.ZERO:
			ms = Vector2(96, 110)

		var col := i % ENEMY_COLS
		var row := i / ENEMY_COLS

		var base_x := pack_center_x + (float(col) - float(ENEMY_COLS - 1) * 0.5) * ENEMY_X_SPACING
		var base_y := (ground_y - ms.y) - float(row) * ENEMY_Y_SPACING

		var pos := Vector2(base_x - ms.x * 0.5, base_y) + _enemy_jitter[i]

				# Keep on-screen
		pos.x = clampf(pos.x, 0.0, cs.x - ms.x)
		pos.y = clampf(pos.y, 0.0, cs.y - ms.y)

		# --- Time-based walk-in (staggered) ---
		var elapsed := float(Time.get_ticks_msec() - _enemy_enter_t0_ms) / 1000.0
		var delay := float(i) * ENEMY_ENTER_STAGGER_SEC

		# t goes 0->1 over ENEMY_ENTER_DURATION_SEC, starting after 'delay'
		var t := clampf((elapsed - delay) / ENEMY_ENTER_DURATION_SEC, 0.0, 1.0)

		# Smoothstep easing (gentler, more "walk" than linear)
		t = t * t * (3.0 - 2.0 * t)

		# Off-screen start X (slightly staggered so they don't all emerge from exact same point)
		var start_x := cs.x + ENEMY_SPAWN_OFFSCREEN_PAD_PX + float(i) * ENEMY_SPAWN_STAGGER_PX

		# During entrance, force X from offscreen -> target; keep Y at target (no vertical sliding)
		if t < 1.0:
			var x := lerpf(start_x, pos.x, t)
			cell.position = Vector2(x, pos.y)
			cell.set_meta("arrived", false)
		else:
			# Arrived: snap once, then gently follow in case layout changes (resize, etc.)
			if not cell.has_meta("arrived") or not bool(cell.get_meta("arrived")):
				cell.position = pos
				cell.set_meta("arrived", true)
			else:
				cell.position = cell.position.lerp(pos, ENEMY_FOLLOW_LERP)

func _is_boss_visual() -> bool:
	# Prefer runtime truth, not the wave number.
	var is_boss: bool = bool(Game.battle_runtime.get("is_boss", false))

	# If Challenge is available, we’re in the post-fail endless loop.
	# Endless should look like normal enemy packs (not boss visuals).
	if _can_challenge_wave5_ui():
		is_boss = false

	return is_boss
