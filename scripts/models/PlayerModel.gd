extends Resource
class_name PlayerModel

enum ClassId { WARRIOR, MAGE, ARCHER }

signal leveled_up(levels_gained: int)


# ============ General Player Vars ========================
@export var character_name: String = ""
@export var class_id: int = ClassId.WARRIOR
@export var level: int = 1
@export var xp: int = 0
@export var gold: int = 0
@export var crystals: int = 0
@export var diamonds: int = 0
@export var time_vouchers: int = 0
@export var equipped := {
	Catalog.GearSlot.WEAPON: null,
	Catalog.GearSlot.HELMET: null,
	Catalog.GearSlot.SHOULDERS: null,
	Catalog.GearSlot.CHEST: null,
	Catalog.GearSlot.GLOVES: null,
	Catalog.GearSlot.BELT: null,
	Catalog.GearSlot.LEGS: null,
	Catalog.GearSlot.BOOTS: null,
	Catalog.GearSlot.RING: null,
	Catalog.GearSlot.BRACELET: null,
	Catalog.GearSlot.MOUNT: null,
	Catalog.GearSlot.ARTIFACT: null,
}
@export var deferred_gear: Array[Dictionary] = []

@export var failed_wave5_boss: Dictionary = {} # stage_key -> true


# =======================
# Combat Power (CP) tuning
# =======================
const CP_SCALE: float = 100.0
# CP_SCALE=100 makes early CP ~10k instead of ~100 and prevents tiny upgrades showing 0.

const CP_SKILL_BASE_BY_RARITY := {
	Catalog.Rarity.COMMON: 4.0,
	Catalog.Rarity.UNCOMMON: 6.0,
	Catalog.Rarity.RARE: 10.0,
	Catalog.Rarity.UNIQUE: 16.0,
	Catalog.Rarity.MYTHIC: 25.0,
	Catalog.Rarity.LEGENDARY: 40.0,
	Catalog.Rarity.IMMORTAL: 60.0,
	Catalog.Rarity.SUPREME: 85.0,
	Catalog.Rarity.AUROUS: 120.0,
	Catalog.Rarity.ETERNAL: 170.0,
}

const CP_SKILL_LEVEL_GROWTH: float = 1.22
const CP_SKILL_ACTIVE_MULT: float = 1.20
const CP_SKILL_PASSIVE_MULT: float = 1.00

# =============== Skill Generator ====================
@export var skill_tickets: int = 0
@export var skill_gen_level: int = 1
@export var skill_gen_xp: int = 0
@export var skill_ad_draws_used_today: int = 0
@export var skill_ad_draws_day_key: int = 0

# =============== Crucible =======================
@export var crucible_batch: int = 1
@export var crucible_rarity_min: int = Catalog.Rarity.COMMON
@export var crucible_auto_sell_below: bool = true
@export var crucible_keys: int = 10
@export var crucible_level: int = 1
# Crucible upgrade persistence
var crucible_upgrade_paid_stages: int = 0
var crucible_upgrade_target_level: int = 0 # 0 means "not upgrading"
var crucible_upgrade_finish_unix: int = 0  # unix seconds; 0 means "no timer running"

# ============== Unlocks ==================
@export var premium_offline_unlocked: bool = false          # permanent bundle (+2h cap)
@export var battlepass_expires_unix: int = 0                # temporary (+2h cap while active)
@export var last_active_unix: int = 0

# ============== Class / Skills (MVP) ==================

# Tracks the player's selected node in the class tree (e.g. "warrior", "knight", etc.)
@export var class_def_id: String = ""
const ACTIVE_SKILL_SLOTS: int = 5
@export var skill_auto: bool = true
@export var equipped_active_skills: Array[String] = []  # length 5
@export var equipped_passive_skills: Array[String] = []     #list of skill_ids(passive)
@export var skill_levels: Dictionary = {}               # skill_id -> level (int)
@export var skill_progress: Dictionary = {}              # skill_id -> int copies toward next level

# ====================== Tasks ==========================
var task_state: Dictionary = {}

# ================== Dungeons =================================
# ============== Dungeons =======================
@export var dungeon_keys: Dictionary = {}     # dungeon_id -> key count
@export var dungeon_levels: Dictionary = {}   # dungeon_id -> current level (next attempt), starts at 1
@export var dungeon_daily_reset_day_key: int = 0   # UTC day key = unix / 86400

# Tracks the last UTC day index we applied the dungeon daily reset for. # (UTC day index = floor(unix_time / 86400))
var dungeon_last_reset_day: int = -1

# =================================================================================================

func to_dict() -> Dictionary:
	var eq_out: Dictionary = {}
	for k in equipped.keys():
		var slot_id: int = int(k)
		var item: GearItem = equipped.get(slot_id, null)
		eq_out[str(slot_id)] = item.to_dict() if item != null else null

	return {
		"character_name": character_name,
		"gold": gold,
		"diamonds": diamonds,
		"crystals": crystals,
		"time_vouchers": time_vouchers,
		"level": level,
		"xp": xp,
		"class_id": class_id,
		"class_def_id": class_def_id,
		"skill_levels": skill_levels,
		"skill_progress": skill_progress,
		"equipped_active_skills": equipped_active_skills,
		"equipped_passive_skills": equipped_passive_skills,
		"skill_auto": skill_auto,
		"crucible_keys": crucible_keys,
		"crucible_level": crucible_level,
		"skill_tickets": skill_tickets,
		"skill_gen_level": skill_gen_level,
		"skill_gen_xp": skill_gen_xp,
		"skill_ad_draws_used_today": skill_ad_draws_used_today,
		"skill_ad_draws_day_key": skill_ad_draws_day_key,
		"equipped": eq_out,
		"deferred_gear": deferred_gear,
		"crucible_batch": crucible_batch,
		"crucible_rarity_min": crucible_rarity_min,
		"crucible_auto_sell_below": crucible_auto_sell_below,
		"crucible_upgrade_paid_stages": crucible_upgrade_paid_stages,
		"crucible_upgrade_target_level": crucible_upgrade_target_level,
		"crucible_upgrade_finish_unix": crucible_upgrade_finish_unix,
		"last_active_unix": last_active_unix,
		#Unlocks
		"premium_offline_unlocked": premium_offline_unlocked,
		"battlepass_expires_unix": battlepass_expires_unix,
		"task_state": task_state,
		"dungeon_keys": dungeon_keys,
		"dungeon_levels": dungeon_levels,
		"dungeon_daily_reset_day_key": dungeon_daily_reset_day_key,
		"dungeon_last_reset_day": dungeon_last_reset_day,
		"failed_wave5_boss": failed_wave5_boss,
	}

static func from_dict(d: Dictionary) -> PlayerModel:
	var p := PlayerModel.new()
	p.character_name = String(d.get("character_name", ""))
	p.gold = int(d.get("gold", 0))
	p.diamonds = int(d.get("diamonds", 0))
	p.crystals = int(d.get("crystals", 0))
	p.time_vouchers = int(d.get("time_vouchers", 0))
	p.level = int(d.get("level", 1))
	p.xp = int(d.get("xp", 0))
	p.class_id = int(d.get("class_id", 0))
	p.class_def_id = String(d.get("class_def_id", ""))
	
	p.skill_auto = bool(d.get("skill_auto", true))
	
	var fwb: Variant = d.get("failed_wave5_boss", {})
	p.failed_wave5_boss = {}
	if typeof(fwb) == TYPE_DICTIONARY:
		# Duplicate to avoid sharing the same Dictionary reference from the save blob.
		p.failed_wave5_boss = (fwb as Dictionary).duplicate(true)


	var eav: Variant = d.get("equipped_active_skills", [])
	p.equipped_active_skills = []
	if typeof(eav) == TYPE_ARRAY:
		for v in (eav as Array):
			p.equipped_active_skills.append(String(v))

	# support legacy misspelling if it exists
	var slv: Variant = d.get("skill_levels", null)
	if slv == null:
		slv = d.get("skill_levls", {})
	p.skill_levels = slv as Dictionary if typeof(slv) == TYPE_DICTIONARY else {}

	var spv: Variant = d.get("skill_progress", {})
	p.skill_progress = spv as Dictionary if typeof(spv) == TYPE_DICTIONARY else {}

	p.ensure_active_skills_initialized()


	
	p.crucible_keys = int(d.get("crucible_keys", 0))
	p.crucible_level = int(d.get("crucible_level", 1))
	p.crucible_batch = int(d.get("crucible_batch", 1))
	p.crucible_rarity_min = int(d.get("crucible_rarity_min", Catalog.Rarity.COMMON))
	p.crucible_auto_sell_below = bool(d.get("crucible_auto_sell_below", true))
	p.crucible_upgrade_paid_stages = int(d.get("crucible_upgrade_paid_stages", 0))
	p.crucible_upgrade_target_level = int(d.get("crucible_upgrade_target_level", 0))
	p.crucible_upgrade_finish_unix = int(d.get("crucible_upgrade_finish_unix", 0))
	p.last_active_unix = int(d.get("last_active_unix", 0))
	p.premium_offline_unlocked = bool(d.get("premium_offline_unlocked", false))
	p.battlepass_expires_unix = int(d.get("battlepass_expires_unix", 0))
	p.skill_tickets = int(d.get("skill_tickets", 0))
	p.skill_gen_level = int(d.get("skill_gen_level", 1))
	p.skill_gen_xp = int(d.get("skill_gen_xp", 0))
	p.skill_ad_draws_used_today = int(d.get("skill_ad_draws_used_today", 0))
	p.skill_ad_draws_day_key = int(d.get("skill_ad_draws_day_key", 0))
	p.ensure_skill_generator_initialized()
	p.task_state = d.get("task_state", {})
	
	# Dungeons
	var dk: Variant = d.get("dungeon_keys", {})
	p.dungeon_keys = dk as Dictionary if typeof(dk) == TYPE_DICTIONARY else {}
	var dl: Variant = d.get("dungeon_levels", {})
	p.dungeon_levels = dl as Dictionary if typeof(dl) == TYPE_DICTIONARY else {}
	p.dungeon_daily_reset_day_key = int(d.get("dungeon_daily_reset_day_key", 0))
	p.dungeon_last_reset_day = int(d.get("dungeon_last_reset_day", -1))


	var dg: Variant = d.get("deferred_gear", [])
	p.deferred_gear = []
	if typeof(dg) == TYPE_ARRAY:
		for v in dg:
			if v != null and typeof(v) == TYPE_DICTIONARY:
				p.deferred_gear.append(v as Dictionary)


	# Ensure equipped exists for all slots
	p.equipped = {}
	for slot_id in Catalog.GEAR_SLOT_NAMES.keys():
		p.equipped[int(slot_id)] = null

	var eqv: Variant = d.get("equipped", {})
	if typeof(eqv) == TYPE_DICTIONARY:
		var eqd: Dictionary = eqv
		for sk in eqd.keys():
			var slot: int = int(sk)
			var iv: Variant = eqd[sk]
			if iv == null:
				p.equipped[slot] = null
			elif typeof(iv) == TYPE_DICTIONARY:
				p.equipped[slot] = GearItem.from_dict(iv as Dictionary)
				
	p.ensure_class_and_skills_initialized()
	# Ensure name exists for older saves / new games.
	p.ensure_name_initialized()
	return p

func _obj_has_prop(o: Object, prop: String) -> bool:
	if o == null:
		return false
	for p in o.get_property_list():
		if String(p.get("name", "")) == prop:
			return true
	return false

func _obj_get(o: Object, prop: String, default_val):
	return o.get(prop) if _obj_has_prop(o, prop) else default_val

func _skill_rarity_id(sd: Object) -> int:
	# Try a few common property names; fall back to Common.
	var r = _obj_get(sd, "rarity", null)
	if r != null:
		if typeof(r) == TYPE_INT:
			return int(r)
		if typeof(r) == TYPE_STRING:
			var rs := String(r).to_lower()
			for k in Catalog.RARITY_NAMES.keys():
				if String(Catalog.RARITY_NAMES[k]).to_lower() == rs:
					return int(k)

	r = _obj_get(sd, "rarity_id", null)
	if r != null and typeof(r) == TYPE_INT:
		return int(r)

	# If a skill uses a numeric tier (1..N), map roughly upward.
	var tier = _obj_get(sd, "tier", null)
	if tier != null and typeof(tier) == TYPE_INT:
		var t: int = int(tier)
		# 1 common, 2 uncommon, 3 rare, 4 unique, ...
		var map := [
			Catalog.Rarity.COMMON,
			Catalog.Rarity.UNCOMMON,
			Catalog.Rarity.RARE,
			Catalog.Rarity.UNIQUE,
			Catalog.Rarity.MYTHIC,
			Catalog.Rarity.LEGENDARY,
			Catalog.Rarity.IMMORTAL,
			Catalog.Rarity.SUPREME,
			Catalog.Rarity.AUROUS,
			Catalog.Rarity.ETERNAL,
		]
		return map[clampi(t - 1, 0, map.size() - 1)]

	return int(Catalog.Rarity.COMMON)

func _gather_unlocked_skill_ids_for_cp() -> Array[String]:
	# "Unlocked" = level > 0 in skill_levels, plus class-granted passives.
	var seen := {}
	var out: Array[String] = []

	# All leveled/unlocked skills
	if skill_levels != null:
		for k in skill_levels.keys():
			var sid := String(k)
			if sid == "" or seen.has(sid):
				continue
			if int(skill_levels.get(sid, 0)) <= 0:
				continue
			seen[sid] = true
			out.append(sid)

	# Class-granted passives (count as unlocked for CP, even if not in skill_levels)
	var cd: ClassDef = ClassCatalog.get_def(class_def_id)
	if cd != null and cd.granted_passive_skills != null:
		for sid0 in cd.granted_passive_skills:
			var sid := String(sid0)
			if sid == "" or seen.has(sid):
				continue
			seen[sid] = true
			out.append(sid)

	return out

func _combat_power_from_skills() -> float:
	var total: float = 0.0
	var ids := _gather_unlocked_skill_ids_for_cp()

	for sid in ids:
		var sd: SkillDef = SkillCatalog.get_def(sid)
		if sd == null:
			continue

		var lvl: int = maxi(1, int(skill_levels.get(sid, 1)))
		var rar: int = _skill_rarity_id(sd)

		var base: float = float(CP_SKILL_BASE_BY_RARITY.get(rar, 4.0))
		var level_mult: float = pow(CP_SKILL_LEVEL_GROWTH, float(lvl - 1))

		# Active vs Passive weighting if the SkillDef exposes "type"
		var t = _obj_get(sd, "type", null)
		var kind_mult: float = 1.0
		if t != null:
			# SkillDef.SkillType.PASSIVE is typically 1; safe compare if enum exists
			if int(t) == int(SkillDef.SkillType.PASSIVE):
				kind_mult = CP_SKILL_PASSIVE_MULT
			else:
				kind_mult = CP_SKILL_ACTIVE_MULT
		else:
			# If we can't tell, treat as active-ish (more exciting)
			kind_mult = CP_SKILL_ACTIVE_MULT

		total += base * level_mult * kind_mult

	return total

func base_stats() -> Stats:
	var s := Stats.new()

	# Simple class baselines; tune later.
	match int(class_id):
		ClassId.WARRIOR:
			s.hp = 120
			s.def = 12
			s.atk = 8
			# Optional flavor:
			# s.block = 1

		ClassId.MAGE:
			s.hp = 80
			s.def = 6
			s.atk = 12
			# Optional flavor:
			# s.skill_crit_chance = 2
			# s.crit_chance = 1

		ClassId.ARCHER:
			s.hp = 100
			s.def = 9
			s.atk = 10
			# Optional flavor:
			s.atk_spd = 0.05
			# s.avoidance = 1

	# Growth per level (MVP)
	s.hp += (level - 1) * 8
	s.def += (level - 1) * 0.8
	s.atk += (level - 1) * 1.0

	return s

func total_stats() -> Stats:
	var s := base_stats()
	
	#ensure fields exist for older saves / new players
	ensure_class_and_skills_initialized()
	
	#Add class + passive skill flat bonuses
	s.add(passive_stats_from_class_and_skills())
	
	#Gear
	for slot in equipped.keys():
		var item:GearItem = equipped[slot]
		if item != null:
			s.add(item.stats)
			
	
	return s

func combat_power() -> int:
	var s := total_stats()

	# Use FINAL values so % bonuses actually matter in CP.
	var hp_v: float = s.final_hp_value()
	var atk_v: float = s.final_atk_value()
	var def_v: float = s.final_def_value()
	var spd_v: float = s.final_atk_spd_value()

	var cp := 0.0

	# Core stats
	cp += hp_v * 0.20
	cp += def_v * 2.0
	cp += atk_v * 6.0
	cp += spd_v * 20.0

	# Advanced stats
	cp += (s.block + s.avoidance) * 10.0
	cp += (s.crit_chance + s.combo_chance) * 8.0

	cp += (s.crit_res + s.ignore_evasion) * 6.0
	cp += (s.basic_atk_mult + s.final_dmg_boost_pct) * 3.0
	cp += (s.basic_atk_dmg_res + s.final_dmg_res_pct) * 3.0
	cp += (s.skill_crit_chance + s.skill_crit_dmg) * 2.0
	cp += (s.skill_dmg_res + s.boss_dmg_res) * 2.0
	cp += (s.boss_dmg) * 2.0
	cp += (s.regen) * 10.0

	# Skills contribute to CP (unlocked + class-granted passives)
	cp += _combat_power_from_skills()

	# Scale up to “big numbers” and reduce 0-gain incidents.
	var scaled: float = cp * CP_SCALE

	# Ceil helps small positive gains show up more often than round.
	return maxi(0, int(ceil(scaled)))

func xp_required_for_next_level() -> int:
	# Simple exponential curve (tune later).
	# Level 1 -> 2 should be quick; later levels ramp.
	return int(round(50.0 * pow(1.18, float(level - 1))))

func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0

	var levels_gained: int = 0
	xp += amount

	while true:
		var need: int = xp_required_for_next_level()
		if xp < need:
			break
		xp -= need
		level += 1
		levels_gained += 1

	if levels_gained > 0:
		leveled_up.emit(levels_gained)

	return levels_gained

func battlepass_active(now_unix: int) -> bool:
	return battlepass_expires_unix > now_unix

func ensure_active_skills_initialized() -> void:
	# Equipped slots: always 5, empty by default
	if equipped_active_skills == null:
		equipped_active_skills = []
	while equipped_active_skills.size() < ACTIVE_SKILL_SLOTS:
		equipped_active_skills.append("")
	if equipped_active_skills.size() > ACTIVE_SKILL_SLOTS:
		equipped_active_skills = equipped_active_skills.slice(0, ACTIVE_SKILL_SLOTS)

	# Dicts
	if skill_levels == null:
		skill_levels = {}
	if skill_progress == null:
		skill_progress = {}

	# All skills default to level 0 (locked) and 0 progress
	var all_ids: Array[String] = SkillCatalog.all_active_ids()
	for sid in all_ids:
		if not skill_levels.has(sid):
			skill_levels[sid] = 0
		if not skill_progress.has(sid):
			skill_progress[sid] = 0

	# Sanitize equipped: must be unlocked + no duplicates
	var seen: Dictionary = {}
	for i in range(ACTIVE_SKILL_SLOTS):
		var sid: String = String(equipped_active_skills[i])
		if sid == "":
			continue
		if SkillCatalog.get_def(sid) == null:
			equipped_active_skills[i] = ""
			continue
		var lvl: int = int(skill_levels.get(sid, 0))
		if lvl <= 0:
			equipped_active_skills[i] = ""
			continue
		if seen.has(sid):
			equipped_active_skills[i] = ""
			continue
		seen[sid] = true

# For compatibility with Home.gd's existing call
func ensure_class_and_skills_initialized() -> void:
	# Always ensure containers exist / sized correctly
	ensure_active_skills_initialized()

	# If class not chosen yet, don't force a class_def_id
	if int(class_id) < 0:
		return

	# Ensure class_def_id exists (required for advanced class milestones)
	if class_def_id == "":
		var base_def: ClassDef = ClassCatalog.base_def_for_class_id(int(class_id))
		if base_def != null:
			class_def_id = base_def.id

	# Seed starter skills if none are unlocked
	var any_unlocked := false
	for sid in SkillCatalog.all_active_ids():
		if int(skill_levels.get(sid, 0)) > 0:
			any_unlocked = true
			break

	if not any_unlocked:
		var seed: Dictionary = SkillCatalog.starting_skill_levels_for_class(int(class_id))
		for sid in seed.keys():
			skill_levels[sid] = int(seed[sid])

	# Seed starter loadout if nothing is equipped
	var has_equipped := false
	for s in equipped_active_skills:
		if String(s) != "":
			has_equipped = true
			break
		if not has_equipped:
			equipped_active_skills = SkillCatalog.starting_active_loadout_for_class(int(class_id))

	# Seed passives if needed
	if equipped_passive_skills == null:
		equipped_passive_skills = []
	if equipped_passive_skills.is_empty():
		equipped_passive_skills = SkillCatalog.starting_passives_for_class(int(class_id))

	# Re-sanitize equipped lists after seeding
	ensure_active_skills_initialized()

func set_skill_level(skill_id: String, lvl: int) -> void:
	if skill_id == "":
		return
	lvl = maxi(0, lvl)
	if lvl <= 0:
		skill_levels.erase(skill_id)
	else:
		skill_levels[skill_id] = lvl
		
func _unique_skill_ids(ids: Array[String]) -> Array[String]:
	var seen := {}
	var out: Array[String] = []
	for id in ids:
		if id == "" or seen.has(id):
			continue
		seen[id] = true
		out.append(id)
	return out
	
func passive_stats_from_class_and_skills() -> Stats:
	#Flat passive from the select class node + passice skills (equipped + granted)
	var out := Stats.new()
	
	#Class passice flat
	var cd: ClassDef = ClassCatalog.get_def(class_def_id)
	if cd != null and cd.passive_flat != null:
		out.add(cd.passive_flat)
		
	#Class-granted passive skills + equipped passive skills
	var passives: Array[String] = []
	if cd != null and cd.granted_passive_skills.size() > 0:
		passives.append_array(cd.granted_passive_skills)
	passives.append_array(equipped_passive_skills)
	
	for sid in _unique_skill_ids(passives):
		var sd: SkillDef = SkillCatalog.get_def(sid)
		if sd == null:
			continue
		if sd.type != SkillDef.SkillType.PASSIVE:
			continue
		if sd.passive_flat == null:
			continue
		var lvl: int = maxi(1, get_skill_level(sid))
		out.add(sd.passive_flat.scaled(float(lvl)))
		
	return out

# ----------------- Character Name -----------------
func ensure_name_initialized() -> void:
	if character_name.strip_edges() != "":
		return
	character_name = generate_random_adventurer_name()
	
static func generate_random_adventurer_name() -> String:
	# "Adventurer XXXXXXXXXX" where X is a digit
	# Note: True uniqueness on name server/world is requires backend validation
	# This local generator is collision-resistant for a single-player save
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	
	# Use time_ random to reduce collision risk; keep exactly 10 digits
	var t: int = int(Time.get_unix_time_from_system()) # seconds
	var n: int = int(((t * 100000) + (rng.randi() % 100000)) % 10000000000)
	var digits := "%010d" % n
	return "Adventurer " + digits
	
func base_class_display_name() -> String:
	match int(class_id):
		ClassId.WARRIOR: return "Warrior"
		ClassId.MAGE: return "Mage"
		ClassId.ARCHER: return "Archer"
	return "Unknown"
	
func current_class_name_display() -> String:
	# If you have advanced classes enabled (class_def_id + ClassCatalog), show the advanced name
	# Otherwise fall back to base class name
	# (If your project already has class_def_id, this will work as is)
	if "class_def_id" in self:
		var cid: String = String(get("class_def_id"))
		if cid != "":
			var cd: ClassDef = ClassCatalog.get_def(cid)
			if cd != null:
				return cd.display_name
	return base_class_display_name()

func get_skill_level(skill_id: String) -> int:
	ensure_active_skills_initialized()
	return int(skill_levels.get(skill_id, 0))

func get_skill_progress(skill_id: String) -> int:
	ensure_active_skills_initialized()
	return int(skill_progress.get(skill_id, 0))

func copies_required_for_next_level(skill_id: String) -> int:
	# Level 0 -> 1 requires 1 copy
	# Level 1 -> 2 requires 2 copies
	# Level 2 -> 3 requires 4 copies
	var lvl: int = get_skill_level(skill_id)
	return maxi(1, lvl * 2)

func add_skill_copies(skill_id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	ensure_active_skills_initialized()
	if SkillCatalog.get_def(skill_id) == null:
		return

	var lvl: int = int(skill_levels.get(skill_id, 0))
	var prog: int = int(skill_progress.get(skill_id, 0)) + amount

	# If locked, first copy unlocks the skill (consumes 1 copy)
	if lvl <= 0 and prog > 0:
		lvl = 1
		prog -= 1
		skill_levels[skill_id] = lvl

	skill_progress[skill_id] = prog

func can_upgrade_skill(skill_id: String) -> bool:
	ensure_active_skills_initialized()
	if SkillCatalog.get_def(skill_id) == null:
		return false
	var req: int = copies_required_for_next_level(skill_id)
	return int(skill_progress.get(skill_id, 0)) >= req

func upgrade_skill_once(skill_id: String) -> bool:
	ensure_active_skills_initialized()
	if not can_upgrade_skill(skill_id):
		return false
	var req: int = copies_required_for_next_level(skill_id)
	var prog: int = int(skill_progress.get(skill_id, 0))
	var lvl: int = int(skill_levels.get(skill_id, 0))

	skill_progress[skill_id] = prog - req
	skill_levels[skill_id] = lvl + 1
	return true

func upgrade_skill_max(skill_id: String) -> int:
	# Useful later when a big gacha pull gives multiple copies.
	var upgraded: int = 0
	while upgrade_skill_once(skill_id):
		upgraded += 1
	return upgraded

func ensure_skill_generator_initialized() -> void:
	if skill_gen_level <= 0:
		skill_gen_level = 1
	if skill_gen_xp < 0:
		skill_gen_xp = 0
	if skill_ad_draws_used_today < 0:
		skill_ad_draws_used_today = 0
	if skill_ad_draws_day_key < 0:
		skill_ad_draws_day_key = 0

func ensure_skill_generator_daily_reset(now_unix: int) -> void:
	ensure_skill_generator_initialized()
	var day_key: int = int(floor(float(now_unix) / 86400.0))
	if day_key != skill_ad_draws_day_key:
		skill_ad_draws_day_key = day_key
		skill_ad_draws_used_today = 0

func skill_gen_xp_required_for_next_level() -> int:
	# Simple ramp; tune later
	return 50 + ((skill_gen_level - 1) * 25)

func add_skill_generator_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	ensure_skill_generator_initialized()
	var gained: int = 0
	skill_gen_xp += amount
	while true:
		var need: int = skill_gen_xp_required_for_next_level()
		if skill_gen_xp < need:
			break
		skill_gen_xp -= need
		skill_gen_level += 1
		gained += 1
	return gained

func add_task_reward(kind: int, amount: int) -> void:
	match kind:
		RewardDef.Kind.CRUCIBLE_KEYS:
			crucible_keys += amount
		RewardDef.Kind.TIME_VOUCHERS:
			time_vouchers += amount
		RewardDef.Kind.SKILL_TICKETS:
			skill_tickets += amount
		RewardDef.Kind.CRYSTALS:
			crystals += amount

func has_failed_wave5_boss(stage_key: String) -> bool:
	return bool(failed_wave5_boss.get(stage_key, false))

func set_failed_wave5_boss(stage_key: String, failed: bool) -> void:
	if failed:
		failed_wave5_boss[stage_key] = true
	else:
		failed_wave5_boss.erase(stage_key)
