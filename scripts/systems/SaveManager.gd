extends Node
#class_name SaveManager

const SAVE_PATH: String = "user://savegame.json"
const SAVE_VERSION: int = 1

# Debounced autosave
var _save_pending: bool = false
var _save_timer: Timer

func _ready() -> void:
	_ensure_timer()

func init_autosave_hooks() -> void:
	if Game.player_changed.is_connected(request_save):
		return
	if not Game.battle_changed.is_connected(request_save):
		Game.battle_changed.connect(request_save)	
		
	Game.player_changed.connect(request_save)
	_log("Autosave hooks initialized (player_changed -> request_save).")

func _ensure_timer() -> void:
	if _save_timer != null and is_instance_valid(_save_timer):
		return

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.4
	_save_timer.timeout.connect(_on_save_timer_timeout)
	add_child(_save_timer)
	
func request_save() -> void:
	_ensure_timer()
	_save_pending = true
	_save_timer.start()

func save_now() -> void:
	_ensure_timer()
	_save_pending = false
	
	var now_unix: int = int(Time.get_unix_time_from_system())
	if Game.player != null:
		Game.player.last_active_unix = now_unix


	if Game.player == null:
		_log("save_now: Game.player is null; skipping.")
		return

	var root: Dictionary = {
		"v": SAVE_VERSION,
		"player": Game.player.to_dict(),
		"battle": Game.battle_state,
	}

	var json_text: String = JSON.stringify(root, "\t", true)

	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		_log("Failed to open for write: %s (err=%s)" % [_save_path_abs(), str(FileAccess.get_open_error())])
		return

	f.store_string(json_text)
	f.flush()
	#_log("Saved %d bytes -> %s" % [json_text.length(), _save_path_abs()])

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_or_new() -> void:
	_log("Load requested. path=%s exists=%s" % [_save_path_abs(), str(has_save())])

	if not has_save():
		_new_game()
		return

	var text: String = FileAccess.get_file_as_string(SAVE_PATH)
	if text.is_empty():
		_new_game()
		return

	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save parse failed; starting new game.")
		_new_game()
		return

	var root: Dictionary = parsed
	var v: int = int(root.get("v", 0))

	# Simple version gate (expand later with migrations)
	if v != SAVE_VERSION:
		push_warning("Save version mismatch (%d != %d); starting new game." % [v, SAVE_VERSION])
		_new_game()
		return

	var pvar: Variant = root.get("player", null)
	if pvar == null or typeof(pvar) != TYPE_DICTIONARY:
		push_warning("Missing player data; starting new game.")
		_new_game()
		return

	var p_dict: Dictionary = pvar
	
	Game.player = PlayerModel.from_dict(p_dict)

	var bvar: Variant = root.get("battle", null)
	if bvar != null and typeof(bvar) == TYPE_DICTIONARY:
		Game.set_battle_state(bvar as Dictionary)
	else:
		Game.reset_battle_state()

	# Apply offline rewards BEFORE announcing player_changed (so UI shows the updated values)
	var summary: Dictionary = Game.apply_offline_rewards_on_load()
	Game.player_changed.emit()

	# Persist immediately so offline rewards can't be re-applied on next launch
	if bool(summary.get("applied", false)):
		save_now()

	_log("Loaded save OK.")

func _new_game() -> void:
	Game.player = PlayerModel.new()
	# Require the player to choose a class before combat starts.
	Game.player.class_id = -1
	Game.reset_battle_state()
	Game.player_changed.emit()
	_log("No valid save found; created new game.")
	save_now()  # immediate initial save

func _on_save_timer_timeout() -> void:
	if _save_pending:
		save_now()

func _notification(what: int) -> void:
	# Desktop quit request
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_now()

	# Mobile: save when app is being suspended/backgrounded
	if what == MainLoop.NOTIFICATION_APPLICATION_PAUSED:
		save_now()

	# Useful on many platforms (focus lost)
	if what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_now()

func _save_path_abs() -> String:
	return ProjectSettings.globalize_path(SAVE_PATH)

func _log(msg: String) -> void:
	print("[SaveManager] %s" % msg)
