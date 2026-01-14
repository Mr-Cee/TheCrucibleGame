extends Node
class_name ClassPassiveCatalog

# Class passive catalog. Built on-demand.
# Slot 1 is the signature mechanic; slots 2-5 are stat bonuses unlocked every 5 levels from that class's entry level.

static var _defs: Dictionary = {}        # passive_id -> ClassPassiveDef
static var _by_class: Dictionary = {}    # class_def_id -> Array[ClassPassiveDef]

const CP_BY_TIER := {
	1: [0, 30, 10, 15, 20, 25],
	2: [0, 60, 25, 35, 45, 55],
	3: [0, 100, 45, 60, 75, 90],
	4: [0, 150, 70, 95, 120, 145],
}

const HP_BY_TIER := {
	1: [0.0, 0.0, 40.0, 60.0, 90.0, 130.0],
	2: [0.0, 0.0, 70.0, 110.0, 170.0, 240.0],
	3: [0.0, 0.0, 110.0, 170.0, 260.0, 360.0],
	4: [0.0, 0.0, 160.0, 240.0, 360.0, 520.0],
}

const ATK_BY_TIER := {
	1: [0.0, 0.0, 2.0, 3.0, 5.0, 7.0],
	2: [0.0, 0.0, 4.0, 6.0, 9.0, 13.0],
	3: [0.0, 0.0, 6.0, 9.0, 14.0, 20.0],
	4: [0.0, 0.0, 9.0, 13.0, 20.0, 28.0],
}

const DEF_BY_TIER := {
	1: [0.0, 0.0, 3.0, 5.0, 7.0, 10.0],
	2: [0.0, 0.0, 6.0, 9.0, 13.0, 18.0],
	3: [0.0, 0.0, 9.0, 13.0, 19.0, 26.0],
	4: [0.0, 0.0, 13.0, 19.0, 28.0, 38.0],
}

const ATTR_BY_TIER := {
	1: [0.0, 0.0, 2.0, 3.0, 4.0, 6.0],
	2: [0.0, 0.0, 4.0, 5.0, 7.0, 10.0],
	3: [0.0, 0.0, 6.0, 8.0, 11.0, 15.0],
	4: [0.0, 0.0, 9.0, 12.0, 16.0, 22.0],
}

const APS_BY_TIER := {
	1: [0.0, 0.0, 0.02, 0.03, 0.05, 0.07],
	2: [0.0, 0.0, 0.03, 0.05, 0.07, 0.1],
	3: [0.0, 0.0, 0.04, 0.06, 0.09, 0.12],
	4: [0.0, 0.0, 0.05, 0.08, 0.11, 0.15],
}

const CRIT_CH_BY_TIER := {
	1: [0.0, 0.0, 2.0, 3.0, 4.0, 5.0],
	2: [0.0, 0.0, 3.0, 4.0, 6.0, 8.0],
	3: [0.0, 0.0, 4.0, 6.0, 8.0, 11.0],
	4: [0.0, 0.0, 5.0, 7.0, 10.0, 14.0],
}

const CRIT_DMG_BY_TIER := {
	1: [0.0, 0.0, 10.0, 15.0, 20.0, 30.0],
	2: [0.0, 0.0, 15.0, 25.0, 35.0, 50.0],
	3: [0.0, 0.0, 20.0, 35.0, 50.0, 70.0],
	4: [0.0, 0.0, 30.0, 45.0, 65.0, 90.0],
}

const COMBO_CH_BY_TIER := {
	1: [0.0, 0.0, 3.0, 5.0, 7.0, 10.0],
	2: [0.0, 0.0, 5.0, 7.0, 10.0, 14.0],
	3: [0.0, 0.0, 7.0, 10.0, 14.0, 20.0],
	4: [0.0, 0.0, 10.0, 14.0, 20.0, 28.0],
}

const COMBO_DMG_BY_TIER := {
	1: [0.0, 0.0, 10.0, 15.0, 25.0, 35.0],
	2: [0.0, 0.0, 15.0, 25.0, 35.0, 50.0],
	3: [0.0, 0.0, 20.0, 35.0, 50.0, 70.0],
	4: [0.0, 0.0, 30.0, 45.0, 65.0, 90.0],
}

const BLOCK_BY_TIER := {
	1: [0.0, 0.0, 2.0, 3.0, 4.0, 6.0],
	2: [0.0, 0.0, 4.0, 6.0, 8.0, 11.0],
	3: [0.0, 0.0, 6.0, 8.0, 11.0, 15.0],
	4: [0.0, 0.0, 8.0, 11.0, 15.0, 20.0],
}

const AVOID_BY_TIER := {
	1: [0.0, 0.0, 2.0, 3.0, 4.0, 6.0],
	2: [0.0, 0.0, 4.0, 6.0, 8.0, 11.0],
	3: [0.0, 0.0, 6.0, 8.0, 11.0, 15.0],
	4: [0.0, 0.0, 8.0, 11.0, 15.0, 20.0],
}

const COUNTER_CH_BY_TIER := {
	1: [0.0, 0.0, 3.0, 5.0, 7.0, 10.0],
	2: [0.0, 0.0, 5.0, 7.0, 10.0, 14.0],
	3: [0.0, 0.0, 7.0, 10.0, 14.0, 20.0],
	4: [0.0, 0.0, 10.0, 14.0, 20.0, 28.0],
}

const COUNTER_DMG_BY_TIER := {
	1: [0.0, 0.0, 15.0, 25.0, 35.0, 50.0],
	2: [0.0, 0.0, 25.0, 40.0, 55.0, 80.0],
	3: [0.0, 0.0, 35.0, 55.0, 80.0, 110.0],
	4: [0.0, 0.0, 50.0, 80.0, 110.0, 160.0],
}

const REGEN_BY_TIER := {
	1: [0.0, 0.0, 0.2, 0.35, 0.5, 0.75],
	2: [0.0, 0.0, 0.35, 0.6, 0.85, 1.25],
	3: [0.0, 0.0, 0.55, 0.9, 1.3, 1.9],
	4: [0.0, 0.0, 0.8, 1.3, 1.9, 2.7],
}

const ROMAN := ["I", "II", "III", "IV"]

const STAT_NOUN := {
	"hp": "Vitality",
	"atk": "Might",
	"def": "Fortitude",
	"str": "Strength",
	"int": "Intellect",
	"agi": "Agility",
	"atk_spd": "Swiftness",
	"crit_chance": "Killer Instinct",
	"crit_dmg": "Lethality",
	"combo_chance": "Combo Mastery",
	"combo_dmg": "Combo Power",
	"block": "Shieldcraft",
	"avoidance": "Evasion",
	"counter_chance": "Retaliation",
	"counter_dmg": "Counter Force",
	"regen": "Regeneration",
}

const CLASS_IDS: Array[String] = ["warrior", "knight", "berserker", "paladin", "sentinel", "warlord", "bloodreaver", "crusader", "templar", "bulwark", "ironclad", "warmaster", "conqueror", "slaughterlord", "dreadknight", "mage", "sorcerer", "warlock", "archmage", "spellblade", "hexer", "necromancer", "arcanist", "elementalist", "battlemage", "magus_assassin", "curse_lord", "void_scholar", "lich", "deathcaller", "archer", "ranger", "rogue", "sharpshooter", "beastmaster", "assassin", "shadowdancer", "deadeye", "sniper", "primal_warden", "wildcaller", "nightblade", "phantom", "bladedancer", "umbral_stalker"]

const SIGNATURES := {
	"warrior": {
		"name": "Frontline Endurance",
		"desc": "When you take damage, gain Resolve for 6s (+2 DEF per stack, stacks up to 8; refresh on hit).",
		"effect_key": "resolve_on_damage",
		"params": {
			"duration": 6.0,
			"def_per_stack": 2.0,
			"max_stacks": 8,
			"internal_cd": 0.3,
		},
	},
	"knight": {
		"name": "Shield Oath",
		"desc": "At the start of each enemy, gain a shield worth 20% of your max HP.",
		"effect_key": "shield_on_spawn",
		"params": {
			"shield_pct_max_hp": 0.2,
		},
	},
	"berserker": {
		"name": "Rage Engine",
		"desc": "While fighting, your ATK and Attack Speed ramp up each second (resets between enemies).",
		"effect_key": "rage_ramp",
		"params": {
			"atk_mult_per_sec": 0.01,
			"aps_mult_per_sec": 0.005,
			"max_duration": 30.0,
		},
	},
	"paladin": {
		"name": "Sacred Pulse",
		"desc": "Every 10s, heal for 6% max HP and gain an equal shield.",
		"effect_key": "sacred_pulse",
		"params": {
			"interval": 10.0,
			"heal_pct_max_hp": 0.06,
			"shield_pct_max_hp": 0.06,
		},
	},
	"sentinel": {
		"name": "Thorns of Iron",
		"desc": "Reflect 18% of post-mitigation damage back to the enemy.",
		"effect_key": "thorns_reflect",
		"params": {
			"reflect_pct_post_mit": 0.18,
		},
	},
	"warlord": {
		"name": "Momentum Orders",
		"desc": "Combos grant Momentum stacks: +2% ATK per stack for 8s (up to 10 stacks).",
		"effect_key": "momentum_orders",
		"params": {
			"combo_stack_atk_pct": 0.02,
			"max_stacks": 10,
			"duration": 8.0,
		},
	},
	"bloodreaver": {
		"name": "Crimson Contract",
		"desc": "Gain 10% lifesteal, but crits cost 2% max HP.",
		"effect_key": "crimson_contract",
		"params": {
			"lifesteal_pct": 0.1,
			"self_damage_pct_max_hp_on_crit": 0.02,
		},
	},
	"crusader": {
		"name": "Aegis of Faith",
		"desc": "When dropping below 40% HP, gain a large shield and DEF boost (once per enemy).",
		"effect_key": "aegis_threshold",
		"params": {
			"hp_threshold_pct": 0.4,
			"shield_pct_max_hp": 0.3,
			"def_mult": 1.2,
			"duration": 10.0,
			"cooldown": 20.0,
		},
	},
	"templar": {
		"name": "Holy Smite",
		"desc": "Every 10s, your next hit deals bonus damage and applies Vulnerability for 6s.",
		"effect_key": "holy_smite_cycle",
		"params": {
			"interval": 10.0,
			"bonus_damage_mult": 1.2,
			"vuln_pct": 0.12,
			"vuln_duration": 6.0,
		},
	},
	"bulwark": {
		"name": "Unyielding Wall",
		"desc": "No single hit can deal more than 10% of your max HP.",
		"effect_key": "damage_cap",
		"params": {
			"max_hit_pct_max_hp": 0.1,
		},
	},
	"ironclad": {
		"name": "Counterguard",
		"desc": "Blocking triggers a counterattack dealing 80% ATK (2s internal cooldown).",
		"effect_key": "counter_on_block",
		"params": {
			"counter_damage_mult": 0.8,
			"internal_cd": 2.0,
		},
	},
	"warmaster": {
		"name": "War Banner",
		"desc": "Enemy defeats grant a stacking banner buff: +1% ATK and +1% DEF per stack for 15s.",
		"effect_key": "war_banner_stacks",
		"params": {
			"stack_atk_pct": 0.01,
			"stack_def_pct": 0.01,
			"max_stacks": 20,
			"duration": 15.0,
		},
	},
	"conqueror": {
		"name": "Relentless Advance",
		"desc": "If you avoid taking damage, your ATK ramps up over time (resets when hit).",
		"effect_key": "relentless_advance",
		"params": {
			"ramp_atk_pct_per_sec": 0.01,
			"max_ramp_pct": 0.25,
			"reset_on_hit": true,
		},
	},
	"slaughterlord": {
		"name": "Harvest of Flesh",
		"desc": "Enemy defeats heal you for 12% max HP and empower your lifesteal for 8s.",
		"effect_key": "harvest_of_flesh",
		"params": {
			"on_kill_heal_pct_max_hp": 0.12,
			"next_enemy_lifesteal_pct": 0.15,
			"duration": 8.0,
		},
	},
	"dreadknight": {
		"name": "Dread Aura",
		"desc": "Your presence weakens enemies (-8% enemy ATK) and inflicts periodic shadow damage.",
		"effect_key": "dread_aura",
		"params": {
			"enemy_atk_reduction_pct": 0.08,
			"dot_dps_mult": 0.12,
			"tick": 3.0,
		},
	},
	"mage": {
		"name": "Arcane Surge",
		"desc": "Casting an active skill grants Arcane Surge: +8% ATK for 6s (3s cooldown).",
		"effect_key": "arcane_surge",
		"params": {
			"on_skill_atk_pct": 0.08,
			"duration": 6.0,
			"internal_cd": 3.0,
		},
	},
	"sorcerer": {
		"name": "Overload",
		"desc": "Critical hits have a chance to fire an extra bolt for 60% damage.",
		"effect_key": "crit_echo_bolt",
		"params": {
			"proc_chance": 0.35,
			"bolt_damage_mult": 0.6,
		},
	},
	"warlock": {
		"name": "Curse of Decay",
		"desc": "Enemies suffer a stacking curse that increases your DoT damage over time.",
		"effect_key": "curse_of_decay",
		"params": {
			"dot_dps_mult": 0.1,
			"stack_per_sec": 1,
			"max_stacks": 10,
			"duration": 12.0,
		},
	},
	"archmage": {
		"name": "Time Dilation",
		"desc": "Every 12s, reduce other skill cooldowns and gain a short Attack Speed burst.",
		"effect_key": "time_dilation",
		"params": {
			"interval": 12.0,
			"cdr_seconds": 1.0,
			"aps_pct": 0.08,
			"duration": 6.0,
		},
	},
	"spellblade": {
		"name": "Spellstrike",
		"desc": "After casting a skill, your next basic hit deals bonus damage and gains +10% crit chance (5s window).",
		"effect_key": "spellstrike",
		"params": {
			"window": 5.0,
			"after_skill_next_hit_bonus_mult": 0.7,
			"crit_pp": 10.0,
		},
	},
	"hexer": {
		"name": "Withering Hex",
		"desc": "Every 10s, apply a brief Weaken + Armor Break effect.",
		"effect_key": "withering_hex",
		"params": {
			"interval": 10.0,
			"weaken_pct": 0.1,
			"armor_break_pct": 0.1,
			"duration": 6.0,
		},
	},
	"necromancer": {
		"name": "Bone Servant",
		"desc": "Summon a servant that strikes periodically; defeats empower it for the next enemy.",
		"effect_key": "bone_servant",
		"params": {
			"pet_interval": 3.0,
			"pet_damage_mult": 0.35,
			"on_kill_pet_ramp_pct": 0.05,
			"max_ramp": 0.5,
		},
	},
	"arcanist": {
		"name": "Arcane Penetration",
		"desc": "Your skills partially ignore enemy DEF and apply a short Vulnerability.",
		"effect_key": "arcane_penetration",
		"params": {
			"skill_ignore_def_pct": 0.2,
			"vuln_pct": 0.08,
			"vuln_duration": 5.0,
		},
	},
	"elementalist": {
		"name": "Elemental Cycle",
		"desc": "Rotate elemental afflictions (Slow → Weaken → Vulnerability) while fighting.",
		"effect_key": "elemental_cycle",
		"params": {
			"cycle_interval": 8.0,
			"duration": 5.0,
			"effects": [{
				"type": "slow",
				"mag": 0.25,
			}, {
				"type": "weaken",
				"mag": 0.18,
			}, {
				"type": "vuln",
				"mag": 0.12,
			}],
		},
	},
	"battlemage": {
		"name": "Runic Armor",
		"desc": "A portion of damage taken converts into a temporary shield (up to a cap).",
		"effect_key": "runic_armor",
		"params": {
			"damage_to_shield_pct": 0.12,
			"shield_cap_pct_max_hp": 0.25,
		},
	},
	"magus_assassin": {
		"name": "Blink Strike",
		"desc": "Every 14s, briefly evade and empower your next hit (guaranteed crit).",
		"effect_key": "blink_strike",
		"params": {
			"interval": 14.0,
			"avoid_duration": 1.2,
			"next_hit_bonus_mult": 1.1,
			"guaranteed_crit": true,
		},
	},
	"curse_lord": {
		"name": "Absolute Curse",
		"desc": "Vulnerability ramps up the longer an enemy survives (capped).",
		"effect_key": "absolute_curse",
		"params": {
			"vuln_ramp_pct_per_sec": 0.01,
			"max_vuln_pct": 0.3,
		},
	},
	"void_scholar": {
		"name": "Reality Tear",
		"desc": "Periodically deal true damage based on enemy max HP.",
		"effect_key": "reality_tear",
		"params": {
			"interval": 10.0,
			"true_damage_pct_enemy_hp": 0.04,
		},
	},
	"lich": {
		"name": "Phylactery",
		"desc": "Once per enemy, fatal damage instead revives you at 35% HP (long cooldown).",
		"effect_key": "phylactery",
		"params": {
			"revive_hp_pct": 0.35,
			"cooldown": 45.0,
		},
	},
	"deathcaller": {
		"name": "Swarmcaller",
		"desc": "Your DoT ticks can summon a swarm hit for bonus damage.",
		"effect_key": "swarmcaller",
		"params": {
			"proc_chance_on_dot_tick": 0.25,
			"swarm_hit_mult": 0.45,
		},
	},
	"archer": {
		"name": "Tactical Footwork",
		"desc": "Avoiding an attack grants +10% Attack Speed for 6s.",
		"effect_key": "tactical_footwork",
		"params": {
			"on_avoid_aps_pct": 0.1,
			"duration": 6.0,
		},
	},
	"ranger": {
		"name": "Hunter's Mark",
		"desc": "At the start of each enemy, apply Vulnerability for 6s.",
		"effect_key": "hunters_mark",
		"params": {
			"start_vuln_pct": 0.1,
			"duration": 6.0,
		},
	},
	"rogue": {
		"name": "Vanish",
		"desc": "Every 12s, briefly evade and empower your next hit for bonus damage.",
		"effect_key": "vanish",
		"params": {
			"interval": 12.0,
			"avoid_duration": 1.5,
			"next_hit_bonus_mult": 0.8,
		},
	},
	"sharpshooter": {
		"name": "Bullseye Focus",
		"desc": "Critical hits grant Focus: +2% crit chance per stack for 10s (up to 12 stacks).",
		"effect_key": "bullseye_focus",
		"params": {
			"crit_stack_crit_pp": 2.0,
			"crit_stack_max": 12,
			"duration": 10.0,
		},
	},
	"beastmaster": {
		"name": "Companion Strike",
		"desc": "A companion attacks periodically; casting skills hastens it briefly.",
		"effect_key": "companion_strike",
		"params": {
			"pet_interval": 4.0,
			"pet_damage_mult": 0.5,
			"on_skill_pet_aps_pct": 0.12,
			"duration": 6.0,
		},
	},
	"assassin": {
		"name": "Ambush",
		"desc": "Your first hit against each enemy is a guaranteed crit and applies Vulnerability.",
		"effect_key": "ambush",
		"params": {
			"first_hit_crit": true,
			"vuln_pct": 0.12,
			"vuln_duration": 5.0,
		},
	},
	"shadowdancer": {
		"name": "Shadow Poison",
		"desc": "Your hits build a stacking poison DoT during combat.",
		"effect_key": "shadow_poison",
		"params": {
			"dot_dps_mult": 0.08,
			"stack_on_hit": 1,
			"max_stacks": 12,
			"duration": 10.0,
		},
	},
	"deadeye": {
		"name": "Headshot",
		"desc": "Deal increased damage to low-health enemies (below 30% HP).",
		"effect_key": "headshot",
		"params": {
			"execute_threshold_pct": 0.3,
			"bonus_damage_mult": 0.35,
		},
	},
	"sniper": {
		"name": "Charged Shot",
		"desc": "Every 12s, fire a massive shot that partially ignores DEF.",
		"effect_key": "charged_shot",
		"params": {
			"interval": 12.0,
			"bonus_damage_mult": 2.0,
			"ignore_def_pct": 0.4,
		},
	},
	"primal_warden": {
		"name": "Guardian Bond",
		"desc": "Start each enemy with a shield; while shielded, the enemy deals less damage.",
		"effect_key": "guardian_bond",
		"params": {
			"start_shield_pct_max_hp": 0.18,
			"enemy_atk_reduction_pct_while_shield": 0.1,
		},
	},
	"wildcaller": {
		"name": "Pack Tactics",
		"desc": "Companion hits grant Combo Chance stacks for 10s (up to 15 stacks).",
		"effect_key": "pack_tactics",
		"params": {
			"pet_hit_combo_pp": 2.0,
			"max_stacks": 15,
			"duration": 10.0,
		},
	},
	"nightblade": {
		"name": "Execution Chain",
		"desc": "Enemy defeats empower your next enemy: bonus damage and a cooldown reset.",
		"effect_key": "execution_chain",
		"params": {
			"on_kill_reset_cd_one": true,
			"next_enemy_bonus_mult": 0.2,
			"duration": 8.0,
		},
	},
	"phantom": {
		"name": "Phase Shift",
		"desc": "Every 15s, become briefly untouchable and gain a short damage burst.",
		"effect_key": "phase_shift",
		"params": {
			"interval": 15.0,
			"avoid_duration": 1.0,
			"damage_bonus_pct": 0.25,
			"duration": 5.0,
		},
	},
	"bladedancer": {
		"name": "Blade Flurry",
		"desc": "Combos empower your flurries: bonus damage and Attack Speed for a short time.",
		"effect_key": "blade_flurry",
		"params": {
			"combo_bonus_dmg_pct": 0.2,
			"on_combo_aps_pct": 0.06,
			"duration": 6.0,
		},
	},
	"umbral_stalker": {
		"name": "Umbral Mark",
		"desc": "After 5 hits, mark the enemy to suffer shadow damage; you gain crit chance vs marked.",
		"effect_key": "umbral_mark",
		"params": {
			"mark_hits": 5,
			"mark_duration": 8.0,
			"dot_dps_mult": 0.14,
			"crit_pp_vs_marked": 12.0,
		},
	},
}

const STAT_PLANS := {
	"warrior": [["hp"], ["def"], ["block"], ["str"]],
	"knight": [["def"], ["hp"], ["block"], ["regen"]],
	"berserker": [["atk"], ["atk_spd"], ["crit_chance"], ["str"]],
	"paladin": [["hp"], ["def"], ["regen"], ["block"]],
	"sentinel": [["def"], ["hp"], ["counter_chance"], ["counter_dmg"]],
	"warlord": [["atk"], ["combo_chance"], ["str"], ["atk_spd"]],
	"bloodreaver": [["atk"], ["crit_chance"], ["crit_dmg"], ["hp"]],
	"crusader": [["hp"], ["def"], ["block"], ["regen"]],
	"templar": [["atk"], ["crit_chance"], ["block"], ["atk_spd"]],
	"bulwark": [["hp"], ["def"], ["block"], ["hp"]],
	"ironclad": [["counter_chance"], ["counter_dmg"], ["def"], ["hp"]],
	"warmaster": [["atk"], ["hp"], ["combo_chance"], ["crit_chance"]],
	"conqueror": [["atk"], ["atk_spd"], ["combo_chance"], ["crit_dmg"]],
	"slaughterlord": [["atk"], ["crit_chance"], ["hp"], ["regen"]],
	"dreadknight": [["def"], ["atk"], ["hp"], ["crit_chance"]],
	"mage": [["int"], ["atk"], ["crit_chance"], ["crit_dmg"]],
	"sorcerer": [["crit_chance"], ["crit_dmg"], ["int"], ["atk"]],
	"warlock": [["int"], ["hp"], ["regen"], ["def"]],
	"archmage": [["int"], ["atk"], ["crit_chance"], ["atk_spd"]],
	"spellblade": [["atk"], ["def"], ["atk_spd"], ["crit_dmg"]],
	"hexer": [["int"], ["crit_chance"], ["def"], ["hp"]],
	"necromancer": [["int"], ["hp"], ["regen"], ["atk"]],
	"arcanist": [["int"], ["atk"], ["crit_chance"], ["crit_dmg"]],
	"elementalist": [["int"], ["atk"], ["atk_spd"], ["crit_chance"]],
	"battlemage": [["hp"], ["def"], ["atk"], ["atk_spd"]],
	"magus_assassin": [["crit_chance"], ["crit_dmg"], ["atk_spd"], ["avoidance"]],
	"curse_lord": [["int"], ["atk"], ["regen"], ["crit_chance"]],
	"void_scholar": [["int"], ["atk"], ["crit_dmg"], ["atk_spd"]],
	"lich": [["hp"], ["def"], ["int"], ["regen"]],
	"deathcaller": [["int"], ["atk"], ["combo_chance"], ["atk_spd"]],
	"archer": [["agi"], ["atk_spd"], ["crit_chance"], ["combo_chance"]],
	"ranger": [["agi"], ["atk_spd"], ["crit_chance"], ["atk"]],
	"rogue": [["avoidance"], ["crit_chance"], ["atk_spd"], ["atk"]],
	"sharpshooter": [["crit_chance"], ["crit_dmg"], ["atk"], ["atk_spd"]],
	"beastmaster": [["hp"], ["atk"], ["atk_spd"], ["combo_chance"]],
	"assassin": [["crit_chance"], ["crit_dmg"], ["avoidance"], ["atk"]],
	"shadowdancer": [["avoidance"], ["atk_spd"], ["combo_chance"], ["crit_chance"]],
	"deadeye": [["crit_chance"], ["crit_dmg"], ["atk"], ["atk_spd"]],
	"sniper": [["atk"], ["crit_dmg"], ["crit_chance"], ["atk_spd"]],
	"primal_warden": [["hp"], ["def"], ["block"], ["atk"]],
	"wildcaller": [["atk"], ["atk_spd"], ["combo_chance"], ["crit_chance"]],
	"nightblade": [["crit_chance"], ["crit_dmg"], ["combo_chance"], ["atk_spd"]],
	"phantom": [["avoidance"], ["atk_spd"], ["crit_chance"], ["atk"]],
	"bladedancer": [["atk_spd"], ["combo_chance"], ["avoidance"], ["atk"]],
	"umbral_stalker": [["atk"], ["atk_spd"], ["crit_chance"], ["combo_chance"]],
}

static func get_def(id: String) -> ClassPassiveDef:
	_ensure_built()
	return _defs.get(id, null)

static func passives_for_class(class_def_id: String) -> Array[ClassPassiveDef]:
	_ensure_built()
	var arr_v: Variant = _by_class.get(class_def_id, [])
	var out: Array[ClassPassiveDef] = []
	if typeof(arr_v) == TYPE_ARRAY:
		for p in (arr_v as Array):
			if p != null: out.append(p as ClassPassiveDef)
	out.sort_custom(func(a: ClassPassiveDef, b: ClassPassiveDef) -> bool: return a.slot < b.slot)
	return out

static func all_defs() -> Array[ClassPassiveDef]:
	_ensure_built()
	var out: Array[ClassPassiveDef] = []
	for v in _defs.values():
		if v != null: out.append(v as ClassPassiveDef)
	out.sort_custom(func(a: ClassPassiveDef, b: ClassPassiveDef) -> bool: return a.id < b.id)
	return out

static func passives_for_path(class_def_id: String) -> Array[ClassPassiveDef]:
	# Collects passives for this class and all ancestors (useful for a tree UI).
	_ensure_built()
	var out: Array[ClassPassiveDef] = []
	var cur: String = class_def_id
	while cur != "":
		out.append_array(passives_for_class(cur))
		var cd: ClassDef = ClassCatalog.get_def(cur)
		if cd == null:
			break
		cur = cd.parent_id
	return out

static func _ensure_built() -> void:
	if _defs.size() > 0:
		return
	# Ensure class catalog is initialized
	ClassCatalog.get_def("warrior")
	for cid in CLASS_IDS:
		_build_for_class(String(cid))

static func _cp_for(tier: int, slot: int) -> int:
	var arr_v: Variant = CP_BY_TIER.get(tier, CP_BY_TIER.get(1, [0, 0, 0, 0, 0, 0]))
	if typeof(arr_v) != TYPE_ARRAY:
		return 0
	var arr: Array = arr_v as Array
	if slot < 0 or slot >= arr.size():
		return 0
	return int(arr[slot])

static func _tbl_val(tbl: Dictionary, tier: int, slot: int) -> float:
	var arr_v: Variant = tbl.get(tier, tbl.get(1, []))
	if typeof(arr_v) != TYPE_ARRAY:
		return 0.0
	var arr: Array = arr_v as Array
	if slot < 0 or slot >= arr.size():
		return 0.0
	return float(arr[slot])

static func _stat_value(stat_key: String, tier: int, slot: int) -> float:
	match stat_key:
		"hp": return _tbl_val(HP_BY_TIER, tier, slot)
		"atk": return _tbl_val(ATK_BY_TIER, tier, slot)
		"def": return _tbl_val(DEF_BY_TIER, tier, slot)
		"str", "int", "agi": return _tbl_val(ATTR_BY_TIER, tier, slot)
		"atk_spd": return _tbl_val(APS_BY_TIER, tier, slot)
		"crit_chance": return _tbl_val(CRIT_CH_BY_TIER, tier, slot)
		"crit_dmg": return _tbl_val(CRIT_DMG_BY_TIER, tier, slot)
		"combo_chance": return _tbl_val(COMBO_CH_BY_TIER, tier, slot)
		"combo_dmg": return _tbl_val(COMBO_DMG_BY_TIER, tier, slot)
		"block": return _tbl_val(BLOCK_BY_TIER, tier, slot)
		"avoidance": return _tbl_val(AVOID_BY_TIER, tier, slot)
		"counter_chance": return _tbl_val(COUNTER_CH_BY_TIER, tier, slot)
		"counter_dmg": return _tbl_val(COUNTER_DMG_BY_TIER, tier, slot)
		"regen": return _tbl_val(REGEN_BY_TIER, tier, slot)
	return 0.0

static func _apply_stat(s: Stats, stat_key: String, v: float) -> void:
	match stat_key:
		"hp": s.hp = v
		"atk": s.atk = v
		"def": s.def = v
		"str": s.str = v
		"int": s.int_ = v
		"agi": s.agi = v
		"atk_spd": s.atk_spd = v
		"crit_chance": s.crit_chance = v
		"crit_dmg": s.crit_dmg = v
		"combo_chance": s.combo_chance = v
		"combo_dmg": s.combo_dmg = v
		"block": s.block = v
		"avoidance": s.avoidance = v
		"counter_chance": s.counter_chance = v
		"counter_dmg": s.counter_dmg = v
		"regen": s.regen = v

static func _format_stat_line(stat_key: String, v: float) -> String:
	match stat_key:
		"atk_spd": return "+%d%% Attack Speed" % int(round(v * 100.0))
		"regen": return "+%.2f Regen/s" % v
		"str": return "+%d STR" % int(round(v))
		"int": return "+%d INT" % int(round(v))
		"agi": return "+%d AGI" % int(round(v))
		"hp": return "+%d HP" % int(round(v))
		"atk": return "+%d ATK" % int(round(v))
		"def": return "+%d DEF" % int(round(v))
		"crit_chance": return "+%d%% Crit Chance" % int(round(v))
		"crit_dmg": return "+%d%% Crit Damage" % int(round(v))
		"combo_chance": return "+%d%% Combo Chance" % int(round(v))
		"combo_dmg": return "+%d%% Combo Damage" % int(round(v))
		"block": return "+%d%% Block" % int(round(v))
		"avoidance": return "+%d%% Avoid" % int(round(v))
		"counter_chance": return "+%d%% Counter Chance" % int(round(v))
		"counter_dmg": return "+%d%% Counter Damage" % int(round(v))
	return "+%s %s" % [str(v), stat_key]

static func _register(def: ClassPassiveDef) -> void:
	_defs[def.id] = def
	if not _by_class.has(def.class_def_id):
		_by_class[def.class_def_id] = []
	var arr_v: Variant = _by_class.get(def.class_def_id, [])
	if typeof(arr_v) == TYPE_ARRAY:
		(arr_v as Array).append(def)

static func _mk(id: String, class_def_id: String, slot: int, unlock_level: int, name: String, desc: String, cp_gain: int, flat_stats: Stats, effect_key: String, params: Dictionary) -> ClassPassiveDef:
	var d: ClassPassiveDef = ClassPassiveDef.new()
	d.id = id
	d.class_def_id = class_def_id
	d.slot = slot
	d.unlock_level = unlock_level
	d.display_name = name
	d.description = desc
	d.cp_gain = cp_gain
	d.flat_stats = flat_stats
	d.effect_key = effect_key
	d.params = params
	return d

static func _build_for_class(class_def_id: String) -> void:
	var cd: ClassDef = ClassCatalog.get_def(class_def_id)
	if cd == null:
		return
	var tier: int = int(cd.tier)
	var entry_level: int = int(cd.unlock_level)
	var sig_v: Variant = SIGNATURES.get(class_def_id, null)
	if typeof(sig_v) != TYPE_DICTIONARY:
		return
	var sig: Dictionary = sig_v as Dictionary
	var sig_name: String = String(sig.get("name", "Signature"))
	var sig_desc: String = String(sig.get("desc", ""))
	var sig_key: String = String(sig.get("effect_key", ""))
	var sig_params: Dictionary = {}
	var sp_v: Variant = sig.get("params", {})
	if typeof(sp_v) == TYPE_DICTIONARY:
		sig_params = sp_v as Dictionary

	# Slot 1 (signature)
	var sig_id: String = "%s_sig" % class_def_id
	_register(_mk(sig_id, class_def_id, 1, entry_level, sig_name, sig_desc, _cp_for(tier, 1), null, sig_key, sig_params))

	# Slots 2-5 (stats)
	var plan_v: Variant = STAT_PLANS.get(class_def_id, [])
	if typeof(plan_v) != TYPE_ARRAY:
		return
	var plan: Array = plan_v as Array
	for i in range(4):
		var slot: int = i + 2
		var unlock_level: int = entry_level + (slot - 1) * 5
		var entry_v: Variant = plan[i] if i < plan.size() else []
		if typeof(entry_v) != TYPE_ARRAY:
			continue
		var keys: Array = entry_v as Array
		var stats: Stats = Stats.new()
		var desc_parts: Array[String] = []
		var noun_parts: Array[String] = []
		for k in keys:
			var sk: String = String(k)
			var v: float = _stat_value(sk, tier, slot)
			_apply_stat(stats, sk, v)
			desc_parts.append(_format_stat_line(sk, v))
			noun_parts.append(String(STAT_NOUN.get(sk, sk)))

		var roman: String = ROMAN[i] if i < ROMAN.size() else str(i + 1)
		var noun_join: String = " & ".join(noun_parts)
		var name: String = "%s %s %s" % [cd.display_name, noun_join, roman]
		var desc: String = "Gain " + ", ".join(desc_parts) + "."
		var pid: String = "%s_stat_%d" % [class_def_id, slot]
		_register(_mk(pid, class_def_id, slot, unlock_level, name, desc, _cp_for(tier, slot), stats, "", {}))
