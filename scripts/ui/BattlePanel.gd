extends VBoxContainer

@onready var difficulty_label: Label = $DifficultyLabel
@onready var enemy_hp_bar: ProgressBar = $EnemyHPBar
@onready var result_label: Label = get_node_or_null("ResultLabel") as Label

@onready var combat_log_scroll: ScrollContainer = $CombatLogScroll
@onready var combat_log: RichTextLabel = $CombatLogScroll/CombatLog
var _log_buf: String = ""


var _ui_accum: float = 0.0

func _ready() -> void:
	_apply_labels()
	
	# --------------------------------------------------
	# --- Combat log setup ---
	combat_log.bbcode_enabled = true

	_log_buf = Game.combat_log_text()
	if _log_buf != "" and not _log_buf.ends_with("\n"):
		_log_buf += "\n"

	_log_buf += "[b]Combat log connected[/b]\n"
	_render_log()
	
	print("CombatLog size: ", combat_log.size, " visible: ", combat_log.visible)

	Game.combat_log_added.connect(_on_combat_log_added)
	call_deferred("_scroll_log_to_bottom")
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

func _on_combat_log_added(line: String) -> void:
	_log_buf += line + "\n"
	_render_log()
	call_deferred("_scroll_log_to_bottom")


func _scroll_log_to_bottom() -> void:
	if combat_log_scroll == null:
		return
	var bar := combat_log_scroll.get_v_scroll_bar()
	if bar:
		combat_log_scroll.scroll_vertical = int(bar.max_value)

func _render_log() -> void:
	if combat_log == null:
		return

	# Make sure it’s visible
	combat_log.visible = true
	combat_log.modulate = Color(1, 1, 1, 1)

	# Force readable colors (different Godot versions use different theme keys)
	combat_log.add_theme_color_override("default_color", Color(1, 1, 1, 1))
	combat_log.add_theme_color_override("font_color", Color(1, 1, 1, 1))

	# Disable RichTextLabel's internal scrolling if it exists (prevents "dots"/double scroll)
	combat_log.set("scroll_active", false)
	combat_log.set("scroll_following", false)

	# Render BBCode safely
	combat_log.call("clear")
	if combat_log.has_method("parse_bbcode"):
		combat_log.call("parse_bbcode", _log_buf)
	else:
		# Fallback: show plain text if bbcode parsing isn't available
		combat_log.text = _strip_bbcode(_log_buf)

func _strip_bbcode(s: String) -> String:
	var out := s
	# very simple tag removal
	out = out.replace("[b]", "").replace("[/b]", "")
	out = out.replace("[color=", "").replace("[/color]", "")
	out = out.replace("]", "")
	return out
