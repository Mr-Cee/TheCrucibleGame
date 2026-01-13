extends Node
class_name SkillCatalog

# Code-driven active skill catalog (universal skills).
# Passive skills will be handled separately later.

static var _defs: Dictionary = {} # id -> SkillDef

const RARITY_BY_ID := {
	# ------------------------
	# Common (simple baseline)
	# ------------------------
	"arcane_bolt": SkillDef.SkillRarity.COMMON,
	"power_strike": SkillDef.SkillRarity.COMMON,
	"rapid_shot": SkillDef.SkillRarity.COMMON,
	"piercing_arrow": SkillDef.SkillRarity.COMMON,
	"healing_surge": SkillDef.SkillRarity.COMMON,
	"barrier": SkillDef.SkillRarity.COMMON,
	"battle_cry": SkillDef.SkillRarity.COMMON,
	"iron_skin": SkillDef.SkillRarity.COMMON,
	"frost_lance": SkillDef.SkillRarity.COMMON,
	"poisoned_blade": SkillDef.SkillRarity.COMMON,

	# ------------------------
	# Uncommon (multi-hit / stronger utility)
	# ------------------------
	"whirlwind": SkillDef.SkillRarity.UNCOMMON,
	"flame_wave": SkillDef.SkillRarity.UNCOMMON,
	"rejuvenation": SkillDef.SkillRarity.UNCOMMON,
	"guardian_wall": SkillDef.SkillRarity.UNCOMMON,
	"marked_prey": SkillDef.SkillRarity.UNCOMMON,
	"shatter_armor": SkillDef.SkillRarity.UNCOMMON,
	"adrenaline_rush": SkillDef.SkillRarity.UNCOMMON,
	"smoke_bomb": SkillDef.SkillRarity.UNCOMMON,

	# ------------------------
	# Rare (meaningful CC / debuff / sustain)
	# ------------------------
	"meteor_fragment": SkillDef.SkillRarity.RARE,
	"thunderclap": SkillDef.SkillRarity.RARE,
	"concussive_shot": SkillDef.SkillRarity.RARE,
	"hex_of_frailty": SkillDef.SkillRarity.RARE,
	"life_drain": SkillDef.SkillRarity.RARE,
	"deadly_focus": SkillDef.SkillRarity.RARE,
	"crippling_blow": SkillDef.SkillRarity.RARE,

	# ------------------------
	# Legendary (very strong effects / multi-value)
	# ------------------------
	"shadow_bleed": SkillDef.SkillRarity.LEGENDARY,
	"time_snare": SkillDef.SkillRarity.LEGENDARY,
	"second_wind": SkillDef.SkillRarity.LEGENDARY,

	# ------------------------
	# Mythical (game-changing utility)
	# ------------------------
	"arcane_overload": SkillDef.SkillRarity.MYTHICAL,
}

static var _icon_cache_plain: Dictionary = {}   # key -> Texture2D
static var _icon_cache_border: Dictionary = {}  # key -> Texture2D

static func _add_def(id: String, name: String, desc: String, cd: float, effect: SkillDef.EffectType,
		power: float, hits: int = 1, duration: float = 0.0, magnitude: float = 0.0, secondary_power: float = 0.0) -> void:
	var d := SkillDef.new()
	d.id = id
	d.display_name = name
	d.description = desc
	d.rarity = RARITY_BY_ID.get(id, SkillDef.SkillRarity.COMMON)
	d.icon_path = "res://assets/icons/skills/%s.png" % id
	d.cooldown = cd
	d.effect = effect
	d.power = power
	d.hits = hits
	d.duration = duration
	d.magnitude = magnitude
	d.secondary_power = secondary_power
	_defs[id] = d

static func _ensure_built() -> void:
	if _defs.size() > 0:
		return

	# ------------------------------
	# Damage / Burst
	# ------------------------------
	_add_def("arcane_bolt", "Arcane Bolt",
		"Fire a focused bolt of energy dealing moderate damage.",
		10.0, SkillDef.EffectType.DAMAGE, 2.0)

	_add_def("power_strike", "Power Strike",
		"A crushing strike that deals heavy damage.",
		12.0, SkillDef.EffectType.DAMAGE, 2.6)

	_add_def("rapid_shot", "Rapid Shot",
		"Fire a quick volley, dealing multiple smaller hits.",
		11.0, SkillDef.EffectType.MULTI_HIT, 0.95, 3)

	_add_def("meteor_fragment", "Meteor Fragment",
		"Call down a fragment from above for high burst damage.",
		18.0, SkillDef.EffectType.DAMAGE, 3.4)

	_add_def("whirlwind", "Whirlwind",
		"Spin and strike repeatedly, dealing several hits.",
		16.0, SkillDef.EffectType.MULTI_HIT, 0.85, 5)

	_add_def("piercing_arrow", "Piercing Arrow",
		"A piercing shot that briefly reduces enemy defense.",
		14.0, SkillDef.EffectType.ARMOR_BREAK, 1.8, 1, 6.0, 0.25)

	# ------------------------------
	# DoT / Attrition
	# ------------------------------
	_add_def("flame_wave", "Flame Wave",
		"Burn the enemy, dealing damage and applying a short burn.",
		14.0, SkillDef.EffectType.DOT, 1.5, 1, 6.0, 0.0, 0.35)

	_add_def("poisoned_blade", "Poisoned Blade",
		"Slash and poison the enemy, applying a lingering toxin.",
		13.0, SkillDef.EffectType.DOT, 1.25, 1, 7.0, 0.0, 0.30)

	_add_def("shadow_bleed", "Shadow Bleed",
		"Strike from the shadows and cause bleeding over time.",
		15.0, SkillDef.EffectType.DOT, 1.35, 1, 8.0, 0.0, 0.28)

	_add_def("life_drain", "Life Drain",
		"Drain life from the enemy: deal damage and heal for a portion dealt.",
		16.0, SkillDef.EffectType.LIFE_DRAIN, 1.9, 1, 0.0, 0.35)

	# ------------------------------
	# Crowd Control / Debuffs
	# ------------------------------
	_add_def("frost_lance", "Frost Lance",
		"Impale with frost, dealing damage and slowing enemy attacks.",
		12.0, SkillDef.EffectType.SLOW, 1.6, 1, 5.0, 0.30)

	_add_def("thunderclap", "Thunderclap",
		"A stunning shockwave that deals damage and briefly stuns.",
		17.0, SkillDef.EffectType.STUN, 1.7, 1, 1.5)

	_add_def("concussive_shot", "Concussive Shot",
		"A heavy shot that deals damage and briefly stuns.",
		15.0, SkillDef.EffectType.STUN, 1.5, 1, 1.2)

	_add_def("hex_frailty", "Hex of Frailty",
		"Curse the enemy, reducing their damage for a short time.",
		14.0, SkillDef.EffectType.WEAKEN, 0.0, 1, 7.0, 0.22)

	_add_def("marked_prey", "Marked Prey",
		"Mark the enemy, increasing the damage they take.",
		13.0, SkillDef.EffectType.VULNERABILITY, 0.0, 1, 7.0, 0.20)

	_add_def("time_snare", "Time Snare",
		"Distort time to slow enemy attacks significantly.",
		18.0, SkillDef.EffectType.SLOW, 0.0, 1, 6.0, 0.40)

	# ------------------------------
	# Healing / Shielding
	# ------------------------------
	_add_def("healing_surge", "Healing Surge",
		"Instantly restore a chunk of health.",
		12.0, SkillDef.EffectType.HEAL, 0.22)

	_add_def("rejuvenation", "Rejuvenation",
		"Heal over time for a short duration.",
		15.0, SkillDef.EffectType.HOT, 0.0, 1, 8.0, 0.0, 0.035)

	_add_def("barrier", "Barrier",
		"Gain a protective shield that absorbs damage.",
		14.0, SkillDef.EffectType.SHIELD, 0.22)

	_add_def("guardian_wall", "Guardian Wall",
		"A stronger shield with a slightly longer cooldown.",
		18.0, SkillDef.EffectType.SHIELD, 0.30)

	_add_def("second_wind", "Second Wind",
		"Heal and gain a small shield.",
		16.0, SkillDef.EffectType.SHIELD, 0.14)

	# ------------------------------
	# Self Buffs
	# ------------------------------
	_add_def("battle_cry", "Battle Cry",
		"Increases your attack for a short duration.",
		16.0, SkillDef.EffectType.BUFF_ATK, 0.0, 1, 8.0, 0.20)

	_add_def("iron_skin", "Iron Skin",
		"Increases your defense for a short duration.",
		16.0, SkillDef.EffectType.BUFF_DEF, 0.0, 1, 8.0, 0.30)

	_add_def("adrenaline_rush", "Adrenaline Rush",
		"Increases your attack speed for a short duration.",
		15.0, SkillDef.EffectType.BUFF_APS, 0.0, 1, 7.0, 0.25)

	_add_def("smoke_bomb", "Smoke Bomb",
		"Increases your chance to avoid attacks for a short duration.",
		18.0, SkillDef.EffectType.BUFF_AVOID, 0.0, 1, 6.0, 12.0)

	_add_def("deadly_focus", "Deadly Focus",
		"Increases your critical chance for a short duration.",
		18.0, SkillDef.EffectType.BUFF_CRIT, 0.0, 1, 6.0, 10.0)

	# ------------------------------
	# Utility
	# ------------------------------
	_add_def("arcane_overload", "Arcane Overload",
		"Reduce the remaining cooldown of your other equipped skills.",
		20.0, SkillDef.EffectType.COOLDOWN_REDUCE_OTHERS, 2.0)

	# Two hybrid/control skills to round out the set
	_add_def("crippling_blow", "Crippling Blow",
		"Deal damage and weaken the enemy's damage output.",
		17.0, SkillDef.EffectType.WEAKEN, 1.3, 1, 6.0, 0.18)

	_add_def("shatter_armor", "Shatter Armor",
		"Deal damage and significantly reduce enemy defense.",
		19.0, SkillDef.EffectType.ARMOR_BREAK, 1.4, 1, 6.0, 0.35)

static func get_def(id: String) -> SkillDef:
	_ensure_built()
	return _defs.get(id, null)

static func all_active_ids() -> Array[String]:
	_ensure_built()
	var out: Array[String] = []
	for k in _defs.keys():
		var sd: SkillDef = _defs[k]
		if sd != null and sd.type == SkillDef.SkillType.ACTIVE:
			out.append(String(k))
	out.sort()
	return out

static func starter_loadout() -> Array[String]:
	# Pick 5 universal skills that cover damage/CC/heal/shield/utility.
	return [
		"",
		"",
		"",
		"",
		""
	]

######========= BACKWARDS COMPATIBILITY CODE++++++++++###############
static func starting_skill_levels_for_class(_class_id: int) -> Dictionary:
	# Universal active skills MVP: grant all active skills at level 1.
	# Passive skills will be handled later, so we grant none here.
	_ensure_built()
	var out: Dictionary = {}
	for sid in all_active_ids():
		out[sid] = 1
	return out

static func starting_active_loadout_for_class(_class_id: int) -> Array[String]:
	# Universal starter loadout (5 slots). You can tweak this set anytime.
	return starter_loadout()

static func starting_passives_for_class(_class_id: int) -> Array[String]:
	# Passive system later. For now, start with none.
	return []
	
# ---------------- Icon helpers (shared by ALL UIs) ----------------

static func _base_icon(skill_id: String) -> Texture2D:
	var d: SkillDef = get_def(skill_id)
	if d == null:
		return null
	var tex: Texture2D = d.icon_texture()
	if tex != null:
		return tex
	# fallback by convention
	var p := "res://assets/icons/skills/%s.png" % skill_id
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	return null

static func icon_scaled(skill_id: String, size: int) -> Texture2D:
	# Cached resized icon (no border)
	var key := "%s|%d" % [skill_id, size]
	if _icon_cache_plain.has(key):
		return _icon_cache_plain[key]
	var tex := _base_icon(skill_id)
	if tex == null:
		_icon_cache_plain[key] = null
		return null
	var img := tex.get_image()
	if img == null:
		_icon_cache_plain[key] = tex
		return tex
	img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	var out := ImageTexture.create_from_image(img)
	_icon_cache_plain[key] = out
	return out

static func icon_with_rarity_border(skill_id: String, size: int, border_px: int = 2) -> Texture2D:
	# Cached border-framed icon (rarity color)
	var key := "%s|%d|%d" % [skill_id, size, border_px]
	if _icon_cache_border.has(key):
		return _icon_cache_border[key]

	var def: SkillDef = get_def(skill_id)
	if def == null:
		_icon_cache_border[key] = null
		return null

	var inner: int = maxi(1, int(size) - (int(border_px) * 2))
	var inner_tex := icon_scaled(skill_id, inner)
	if inner_tex == null:
		_icon_cache_border[key] = null
		return null

	var border_color: Color = SkillDef.rarity_color(int(def.rarity))

	var out_img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	out_img.fill(Color(0, 0, 0, 0))

	# Draw border (thickness = border_px)
	for t in range(border_px):
	# top/bottom
		for x in range(size):
			out_img.set_pixel(x, t, border_color)
			out_img.set_pixel(x, size - 1 - t, border_color)
		# left/right
		for y in range(size):
			out_img.set_pixel(t, y, border_color)
			out_img.set_pixel(size - 1 - t, y, border_color)

	# Blit icon inside border
	var inner_img := inner_tex.get_image()
	if inner_img != null:
		out_img.blit_rect(inner_img, Rect2i(0, 0, inner, inner), Vector2i(border_px, border_px))

	var out_tex := ImageTexture.create_from_image(out_img)
	_icon_cache_border[key] = out_tex
	return out_tex

static func generator_rarity_weights(level: int) -> Dictionary:
	# returns {"rarities":[int...], "weights":[float...]}
	# Common > Uncommon > Rare > Legendary > Mythical
	if level <= 1:
		return {"rarities":[0,1], "weights":[90.0,10.0]}
	if level == 2:
		return {"rarities":[0,1,2], "weights":[80.0,18.0,2.0]}
	if level == 3:
		return {"rarities":[0,1,2], "weights":[70.0,25.0,5.0]}
	if level == 4:
		return {"rarities":[0,1,2,3], "weights":[60.0,28.0,10.0,2.0]}
	if level == 5:
		return {"rarities":[0,1,2,3,4], "weights":[50.0,30.0,15.0,4.0,1.0]}
	if level == 6:
		return {"rarities":[0,1,2,3,4], "weights":[40.0,30.0,20.0,8.0,2.0]}
	# 7+
	return {"rarities":[0,1,2,3,4], "weights":[30.0,30.0,25.0,12.0,3.0]}

static func generator_odds_text(level: int) -> String:
	var d: Dictionary = generator_rarity_weights(level)
	var r: Array = d["rarities"]
	var w: Array = d["weights"]
	var lines: Array[String] = []
	for i in range(r.size()):
		var rn := int(r[i])
		var pct := float(w[i])
		var name := "Common"
		match rn:
			0: name = "Common"
			1: name = "Uncommon"
			2: name = "Rare"
			3: name = "Legendary"
			4: name = "Mythical"
		lines.append("%s: %.1f%%" % [name, pct])
	return "\n".join(lines)

static func _ids_by_rarity(rarity: int) -> Array[String]:
	_ensure_built()
	var out: Array[String] = []
	for k in _defs.keys():
		var sid: String = String(k)
		var def: SkillDef = _defs[sid]
		var r: int = 0
		if def != null and ("rarity" in def):
			r = int(def.get("rarity"))
		if r == rarity:
			out.append(sid)
	return out

static func roll_generator_rarity(level: int) -> int:
	var d: Dictionary = generator_rarity_weights(level)
	var rarities: Array = d["rarities"]
	var weights: Array = d["weights"]
	var total: float = 0.0
	for ww in weights:
		total += float(ww)
	if total <= 0.0:
		return 0
	var roll: float = (RNG as RNGService).randf() * total
	var acc: float = 0.0
	for i in range(weights.size()):
		acc += float(weights[i])
		if roll <= acc:
			return int(rarities[i])
	return int(rarities[rarities.size() - 1])

static func roll_skill_for_generator(level: int) -> String:
	_ensure_built()
	var r: int = roll_generator_rarity(level)

	# Try chosen rarity, then degrade if no skills exist (safety)
	for rr in range(r, -1, -1):
		var ids: Array[String] = _ids_by_rarity(rr)
		if ids.size() > 0:
			var idx: int = (RNG as RNGService).randi_range(0, ids.size() - 1)
			return ids[idx]

	# Absolute fallback
	var all := all_active_ids()
	if all.size() == 0:
		return ""
	return all[(RNG as RNGService).randi_range(0, all.size() - 1)]
