extends Node
class_name OfflineRewards

# --- Offline rewards tuning ---
const OFFLINE_BASE_CAP_SECONDS: int = 8 * 60 * 60
const OFFLINE_BATTLEPASS_BONUS_SECONDS: int = 2 * 60 * 60
const OFFLINE_PREMIUM_BONUS_SECONDS: int = 2 * 60 * 60

const OFFLINE_MAX_SECONDS: int = 8 * 60 * 60  # base cap (entitlements add on top)
const OFFLINE_KEYS_MULT: float = 0.30         # 30% of normal key rate while offline

# Estimated time to clear ONE wave offline (seconds).
const OFFLINE_WAVE_SECONDS_BASE: float = 10.0
const OFFLINE_WAVE_SECONDS_PER_DIFFICULTY: float = 1.25
const OFFLINE_WAVE_SECONDS_PER_LEVEL: float = 0.40

# --- Rewarded-ad offline bonus rules ---
const OFFLINE_BONUS_SECONDS: int = 2 * 60 * 60
const OFFLINE_BONUS_DAILY_LIMIT: int = 3

static func gmt_day_id(unix_time: int) -> int:
	# Unix time is already UTC; day boundary is 00:00 GMT.
	return int(floor(float(unix_time) / 86400.0))

static func reset_bonus_if_new_day(p: Object, now_unix: int) -> void:
	if p == null:
		return

	var day := gmt_day_id(now_unix)

	# First-time initialization
	if not ("offline_bonus_day_id" in p):
		p.offline_bonus_day_id = day
		p.offline_bonus_uses = 0
		return

	if int(p.offline_bonus_day_id) != day:
		p.offline_bonus_day_id = day
		p.offline_bonus_uses = 0

static func bonus_uses_remaining(p: Object, now_unix: int) -> int:
	reset_bonus_if_new_day(p, now_unix)
	var used := int(p.offline_bonus_uses)
	return max(0, OFFLINE_BONUS_DAILY_LIMIT - used)

static func can_use_bonus(p: Object, now_unix: int) -> bool:
	return bonus_uses_remaining(p, now_unix) > 0

static func consume_bonus_use(p: Object, now_unix: int) -> bool:
	if p == null:
		return false
	reset_bonus_if_new_day(p, now_unix)
	if int(p.offline_bonus_uses) >= OFFLINE_BONUS_DAILY_LIMIT:
		return false
	p.offline_bonus_uses = int(p.offline_bonus_uses) + 1
	return true

static func offline_cap_seconds_for_player(p: Object, now_unix: int) -> int:
	var cap: int = OFFLINE_BASE_CAP_SECONDS

	if p != null:
		# These are already in your PlayerModel (per your earlier notes)
		if bool(p.premium_offline_unlocked):
			cap += OFFLINE_PREMIUM_BONUS_SECONDS
		if int(p.battlepass_expires_unix) > now_unix:
			cap += OFFLINE_BATTLEPASS_BONUS_SECONDS

	return cap

static func offline_estimated_wave_seconds(diff: String, level: int) -> float:
	level = max(1, level)
	var di: int = Catalog.battle_difficulty_index(diff)

	var t: float = OFFLINE_WAVE_SECONDS_BASE
	t += OFFLINE_WAVE_SECONDS_PER_DIFFICULTY * float(di)
	t += OFFLINE_WAVE_SECONDS_PER_LEVEL * float(level - 1)

	return max(3.5, t)

static func offline_simulate_rewards(player_level: int, diff: String, level: int, seconds: int) -> Dictionary:
	# True simulation:
	# - NO battle progression changes
	# - stage/wave ignored
	seconds = maxi(0, seconds)
	level = maxi(1, level)

	var wave_sec: float = offline_estimated_wave_seconds(diff, level)
	var waves: int = int(floor(float(seconds) / wave_sec))
	if waves <= 0:
		return {"gold": 0, "keys": 0, "xp": 0}

	# Use your existing per-wave reward formulas, but fix stage=1 wave=1 and is_boss=false
	var gold_per_wave: int = Catalog.battle_gold_for_wave(diff, level, 1, 1, false)
	var keys_per_wave: int = Catalog.battle_keys_for_wave(diff, level, 1, 1, false)

	# Keys are reduced offline
	var keys_f: float = float(keys_per_wave) * float(waves) * OFFLINE_KEYS_MULT

	# XP modest
	var di: int = Catalog.battle_difficulty_index(diff)
	var xp_per_wave: float = 1.0 + 0.25 * float(di) + 0.10 * float(level - 1)
	var xp_total: int = int(round(xp_per_wave * float(waves)))

	return {
		"gold": gold_per_wave * waves,
		"keys": int(floor(keys_f)),
		"xp": xp_total,
		"waves": waves,
	}
