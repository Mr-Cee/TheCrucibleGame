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

var _log_filter_mode: String = "all" # all/player/enemy/reward/system

var _log_buf: String = ""
var _log_pinned_to_bottom: bool = true
var _log_programmatic_scroll: bool = false
const LOG_PIN_THRESHOLD_PX: float = 80.0

var _ui_accum: float = 0.0

func _ready() -> void:
	_apply_labels()
	
	# --------------------------------------------------
	# --- Combat log setup ---
	combat_log.bbcode_enabled = true

	if _log_buf != "" and not _log_buf.ends_with("\n"):
		_log_buf += "\n"
	
	# Track whether user has scrolled up (unpinned) or is at bottom (pinned)
	if combat_log_scroll:
		var bar := combat_log_scroll.get_v_scroll_bar()
		if bar and not bar.value_changed.is_connected(_on_log_scroll_value_changed):
			bar.value_changed.connect(_on_log_scroll_value_changed)

	# On first open, assume pinned and snap to bottom
	_log_pinned_to_bottom = true
	_scroll_log_to_bottom()

	
	# Controls (if present)
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

	# Listen to new structured signal (preferred)
	if Game.combat_log_entry_added.is_connected(_on_combat_log_entry_added) == false:
		Game.combat_log_entry_added.connect(_on_combat_log_entry_added)

	Game.combat_log_cleared.connect(func() -> void:
		_log_pinned_to_bottom = true
		_log_buf = ""
		_render_log_text()
		_scroll_log_to_bottom()
	)
	
	_rebuild_log_from_game()
	_scroll_log_to_bottom()



	# --------------------------------------------------

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

func _on_combat_log_entry_added(_entry: Dictionary) -> void:
	var was_pinned: bool = _log_pinned_to_bottom
	_rebuild_log_from_game()
	if was_pinned:
		_request_scroll_bottom()

func _scroll_log_to_bottom() -> void:
	if combat_log_scroll == null:
		return

	_log_programmatic_scroll = true
	combat_log_scroll.scroll_vertical = 1_000_000_000
	
	_log_pinned_to_bottom = true
	call_deferred("_end_programmatic_scroll")

func _request_scroll_bottom() -> void:
	# Defer twice so the ScrollContainer updates after text/layout changes.
	call_deferred("_scroll_bottom_pass1")

func _scroll_bottom_pass1() -> void:
	call_deferred("_scroll_bottom_pass2")

func _scroll_bottom_pass2() -> void:
	if combat_log_scroll == null:
		return

	_log_programmatic_scroll = true
	# ScrollContainer clamps, so a huge number reliably lands at bottom
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
		# Fallback: assign plain text
		combat_log.text = _log_buf

func _on_log_scroll_value_changed(_v: float) -> void:
	if _log_programmatic_scroll:
		return
	var bar := combat_log_scroll.get_v_scroll_bar()
	if bar == null:
		return

	# In Godot, bottom is (max_value - page), not max_value.
	var page: float = float(bar.page)
	var bottom: float = max(0.0, float(bar.max_value) - page)

	var threshold: float = max(LOG_PIN_THRESHOLD_PX, float(bar.page) * 0.05) # 5% of viewport
	_log_pinned_to_bottom = (float(bar.value) >= (bottom - threshold))
