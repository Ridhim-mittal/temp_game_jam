extends RefCounted
## Everything the player can unlock in the 2.5D game: the skill tree
## (bought with Ink Points, earned by clearing rooms) and the shop (bought
## with Lumens, dropped by monsters). Edit names, prices and numbers here;
## clearing_player.gd reads the effects through Profile.

## Three branches, each a chain: a skill needs the one before it.
## effect keys are read by clearing_player.gd (_apply_loadout).
const SKILLS := {
	# Blade
	"keen_nib": {"name": "Keen Nib", "branch": "blade", "tier": 0, "cost": 1,
		"desc": "Your swings reach 20% further.", "effect": {"reach_mult": 1.2}},
	"heavy_ending": {"name": "Heavy Ending", "branch": "blade", "tier": 1, "cost": 1,
		"desc": "The third hit of a combo deals +1 damage.", "effect": {"finisher_bonus": 1}},
	"pogo_master": {"name": "Pogo Master", "branch": "blade", "tier": 2, "cost": 2,
		"desc": "Strikes from the air bounce higher and deal +1 damage.", "effect": {"aerial_bonus": 1, "pogo_mult": 1.25}},
	"ink_wave": {"name": "Ink Wave", "branch": "blade", "tier": 3, "cost": 2,
		"desc": "The combo finisher flings a wave of ink that cuts through monsters.", "effect": {"ink_wave": true}},
	# Ember
	"deep_ember": {"name": "Deep Ember", "branch": "ember", "tier": 0, "cost": 1,
		"desc": "+25 Ember fuel; your glow reaches further.", "effect": {"fuel_bonus": 25.0}},
	"kindling": {"name": "Kindling", "branch": "ember", "tier": 1, "cost": 1,
		"desc": "Hits stoke the Ember 50% more.", "effect": {"fuel_hit_mult": 1.5}},
	"wide_flash": {"name": "Wide Flash", "branch": "ember", "tier": 2, "cost": 2,
		"desc": "Flash reaches 35% further and costs 5 less.", "effect": {"flash_radius_mult": 1.35, "flash_cost_delta": -5.0}},
	"second_wind": {"name": "Second Wind", "branch": "ember", "tier": 3, "cost": 2,
		"desc": "Heal in half the time for 8 less fuel.", "effect": {"heal_time_mult": 0.5, "heal_cost_delta": -8.0}},
	# Ink (body)
	"thick_ink": {"name": "Thick Ink", "branch": "ink", "tier": 0, "cost": 1,
		"desc": "+1 ink drop of health.", "effect": {"health_bonus": 1}},
	"quick_feet": {"name": "Quick Feet", "branch": "ink", "tier": 1, "cost": 1,
		"desc": "Run 12% faster.", "effect": {"speed_mult": 1.12}},
	"long_dash": {"name": "Long Dash", "branch": "ink", "tier": 2, "cost": 2,
		"desc": "Dashes go 35% further and cool down faster.", "effect": {"dash_mult": 1.35, "dash_cd_mult": 0.7}},
	"last_drop": {"name": "Last Drop", "branch": "ink", "tier": 3, "cost": 2,
		"desc": "Once per room, a hit that would end you leaves you on one drop.", "effect": {"last_drop": true}},
}

const BRANCHES := [
	["blade", "BLADE", Color(0.95, 0.85, 0.75)],
	["ember", "EMBER", Color(1.0, 0.62, 0.22)],
	["ink", "INK", Color(0.55, 0.65, 1.0)],
]

## Ink Points for clearing a room the first time (default 1).
const ROOM_POINTS := {"arena": 3}

## Shop items. slot: weapon / armor / cosmetic. price in Lumens (0 = owned
## from the start). effect keys as for skills; look keys restyle Vesper.
const ITEMS := {
	# Weapons
	"nib": {"name": "Nib-Sword", "slot": "weapon", "price": 0,
		"desc": "The pen that drew you. Balanced.", "effect": {},
		"look": {"blade_length": 36.0, "grip": Color(1.0, 0.58, 0.14), "slash_rim": Color(1.0, 0.58, 0.14)}},
	"quill": {"name": "Quill Rapier", "slot": "weapon", "price": 40,
		"desc": "Swings 25% faster, reaches a little shorter.", "effect": {"swing_mult": 0.75, "reach_mult": 0.9},
		"look": {"blade_length": 44.0, "grip": Color(0.55, 0.85, 1.0), "slash_rim": Color(0.45, 0.85, 1.0)}},
	"brush": {"name": "Brush Maul", "slot": "weapon", "price": 70,
		"desc": "+1 damage and a wider swing, but 30% slower.", "effect": {"damage_bonus": 1, "radius_mult": 1.25, "swing_mult": 1.3},
		"look": {"blade_length": 30.0, "grip": Color(0.9, 0.2, 0.25), "slash_rim": Color(1.0, 0.25, 0.3)}},
	"compass": {"name": "Compass Edge", "slot": "weapon", "price": 55,
		"desc": "Every hit stokes the Ember twice as much.", "effect": {"fuel_hit_mult": 2.0},
		"look": {"blade_length": 38.0, "grip": Color(1.0, 0.85, 0.3), "slash_rim": Color(1.0, 0.85, 0.3)}},
	# Armor
	"paper": {"name": "Paper Cloak", "slot": "armor", "price": 0,
		"desc": "Vesper's own cloak. No protection to speak of.", "effect": {},
		"look": {"cloak": Color(0.14, 0.11, 0.16), "cloak_rim": Color(0.36, 0.3, 0.42)}},
	"cardboard": {"name": "Cardboard Vest", "slot": "armor", "price": 45,
		"desc": "+1 ink drop of health.", "effect": {"health_bonus": 1},
		"look": {"cloak": Color(0.55, 0.4, 0.26), "cloak_rim": Color(0.75, 0.6, 0.4)}},
	"blotter": {"name": "Blotter Coat", "slot": "armor", "price": 50,
		"desc": "Soaks up hits: 60% longer safety after being hurt.", "effect": {"invuln_mult": 1.6},
		"look": {"cloak": Color(0.16, 0.22, 0.45), "cloak_rim": Color(0.35, 0.45, 0.8)}},
	"wax": {"name": "Wax-Seal Mantle", "slot": "armor", "price": 80,
		"desc": "The first hit in every room cracks the seal instead of you.", "effect": {"seal": true},
		"look": {"cloak": Color(0.45, 0.08, 0.1), "cloak_rim": Color(0.8, 0.25, 0.25)}},
	# Cosmetics
	"classic": {"name": "Classic", "slot": "cosmetic", "price": 0,
		"desc": "Red scarf, as first drawn.", "effect": {},
		"look": {"scarf": Color(0.92, 0.3, 0.2), "mask": Color(0.98, 0.96, 0.9)}},
	"midnight": {"name": "Midnight Scarf", "slot": "cosmetic", "price": 15,
		"desc": "A scarf dyed in the deep blue of the Margins.", "effect": {},
		"look": {"scarf": Color(0.25, 0.35, 0.9), "mask": Color(0.92, 0.94, 1.0)}},
	"sunflower": {"name": "Sunflower", "slot": "cosmetic", "price": 20,
		"desc": "Bright as the Lit Pages.", "effect": {},
		"look": {"scarf": Color(1.0, 0.82, 0.2), "mask": Color(1.0, 0.97, 0.88)}},
	"emerald": {"name": "Shrine Green", "slot": "cosmetic", "price": 20,
		"desc": "The green of the Writer's lamp.", "effect": {},
		"look": {"scarf": Color(0.25, 0.7, 0.5), "mask": Color(0.95, 0.98, 0.94)}},
	"ghost": {"name": "Ghost Draft", "slot": "cosmetic", "price": 35,
		"desc": "Pale as an unlit plank. Spooky.", "effect": {},
		"look": {"scarf": Color(0.85, 0.9, 1.0), "mask": Color(0.8, 0.86, 0.95)}},
	"ink_blot": {"name": "Ink Blot", "slot": "cosmetic", "price": 30,
		"desc": "Black scarf, inked mask. Very serious.", "effect": {},
		"look": {"scarf": Color(0.1, 0.08, 0.14), "mask": Color(0.75, 0.73, 0.8)}},
}

const SLOTS := [["weapon", "WEAPONS"], ["armor", "ARMOR"], ["cosmetic", "LOOKS"]]
const STARTING := {"weapon": "nib", "armor": "paper", "cosmetic": "classic"}
