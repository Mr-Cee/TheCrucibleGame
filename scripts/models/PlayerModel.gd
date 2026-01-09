extends Resource
class_name PlayerModel

enum ClassId { WARRIOR, MAGE, ARCHER }

@export var character_name: String = ""
@export var class_id: int = ClassId.WARRIOR
@export var level: int = 1
@export var xp: int = 0
@export var gold: int = 0
@export var crystals: int = 0
@export var diamonds: int = 0

@export var time_vouchers: int = 0

@export var crucible_keys: int = 10
@export var crucible_level: int = 1

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

@export var crucible_batch: int = 1
@export var crucible_rarity_min: int = Catalog.Rarity.COMMON
@export var crucible_auto_sell_below: bool = true

@export var last_active_unix: int = 0

# ============== Unlocks ==================
@export var premium_offline_unlocked: bool = false          # permanent bundle (+2h cap)
@export var battlepass_expires_unix: int = 0                # temporary (+2h cap while active)

# ============== Class / Skills (MVP) ==================
# Tracks the player's selected node in the class tree (e.g. "warrior", "knight", etc.)
@export var class_def_id: String = ""

@export var skill_levels: Dictionary = {}                   #skill_id -> int (>=1)
@export var equipped_active_skills: Array[String] = []      #List of skill_ids(active)
@export var equipped_passive_skills: Array[String] = []     #list of skill_ids(passive)

# Crucible upgrade persistence
var crucible_upgrade_paid_stages: int = 0
var crucible_upgrade_target_level: int = 0 # 0 means "not upgrading"
var crucible_upgrade_finish_unix: int = 0  # unix seconds; 0 means "no timer running"

func base_stats() -> Stats:
	var s := Stats.new()
	# Simple class baselines; tune later. :contentReference[oaicite:3]{index=3}
	match class_id:
		ClassId.WARRIOR:
			s.hp = 120
			s.def = 12
			s.atk = 8
			s.str = 5
		ClassId.MAGE:
			s.hp = 80
			s.def = 6
			s.atk = 12
			s.int_ = 5
		ClassId.ARCHER:
			s.hp = 100
			s.def = 9
			s.atk = 10
			s.agi = 5
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
			
	#global stat synergies per document
	#Conversion RatesL
	s.hp += s.str * 5.0
	s.atk += s.str * 0.5
	s.atk += s.int_ * 0.6
	s.atk += s.agi * 0.55
	s.atk_spd += s.agi * 0.05
	
	return s

func combat_power() -> int:
	# CP formula (MVP): weighted sum. Tune as we balance.
	var s := total_stats()
	var cp := 0.0
	cp += s.hp * 0.20
	cp += s.def * 2.0
	cp += s.atk * 6.0
	cp += s.str * 4.0
	cp += s.int_ * 4.0
	cp += s.agi * 4.0
	cp += s.atk_spd * 20.0
	cp += (s.block + s.avoidance) * 10.0
	cp += (s.crit_chance + s.combo_chance) * 8.0
	return int(round(cp))

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
		"equipped_active_skills": equipped_active_skills,
		"equipped_passive_skills": equipped_passive_skills,
		"crucible_keys": crucible_keys,
		"crucible_level": crucible_level,
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
	
	var slv: Variant = d.get("skill_levels", {})
	p.skill_levels = {}
	if typeof(slv) == TYPE_DICTIONARY:
		p.skill_levels = slv as Dictionary
		
	var eas: Variant = d.get("equipped_active_skills", [])
	p.equipped_active_skills = []
	if typeof(eas) == TYPE_ARRAY:
		for v in eas:
			if v != null:
				p.equipped_active_skills.append(String(v))	
	var eps: Variant = d.get("equipped_passive_skills", [])
	p.equipped_passive_skills = []
	if typeof(eps) == TYPE_ARRAY:
		for v in eps:
			if v!= null:
				p.equipped_passive_skills.append(String(v))
				
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

	return levels_gained

func battlepass_active(now_unix: int) -> bool:
	return battlepass_expires_unix > now_unix

func ensure_class_and_skills_initialized() -> void:
	if int(class_id) < 0:
		return
	#call this after loading or creating a new player
	if class_def_id == "":
		var base_def: ClassDef = ClassCatalog.base_def_for_class_id(class_id)
		if base_def != null:
			class_def_id = base_def.id
			
	#seed starter skills if missing (new save or older save)
	if skill_levels.is_empty():
		skill_levels = SkillCatalog.starting_skill_levels_for_class(class_id)
		
	if equipped_active_skills.is_empty():
		equipped_active_skills = SkillCatalog.starting_active_loadout_for_class(class_id)
		
	if equipped_passive_skills.is_empty():
		equipped_passive_skills = SkillCatalog.starting_passives_for_class(class_id)
		
func get_skill_level(skill_id: String) -> int:
	if skill_id == "":
		return 0
	return int(skill_levels.get(skill_id, 0))

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
