extends RefCounted
## Everything the player can buy in Quire's shop (shop.gd; B anywhere, the
## pause menu, or Quire's stall in the Spine), paid in coins: the gold Lumens
## picked up in the 2D levels and the dark-silver coins the Margins' monsters
## drop (Profile.lumens): weapons, weapon upgrades, hats,
## scarves, cloaks and armor. Edit names, prices and numbers here; both
## players (scripts/player/player.gd and clearing_player.gd) read them
## through Profile.
##
## SKILLS / BRANCHES / ROOM_POINTS are the retired skill tree (skill_tree.gd,
## unhooked): nothing reads them any more.

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

## Shop items. slot: weapon / armor / cosmetic (scarves) / hat / cloak.
## price in Lumen coins (0 = owned from the start). `effect` keys are read by
## the players' loadouts (multipliers multiply, numbers add, flags OR);
## `look` keys restyle Vesper in both modes.
## Weapons also name their `special`: what holding attack and letting go
## does (both modes; player.gd / clearing_player.gd), and `master` is what
## the third upgrade (MASTERWORK) adds to it. `retired` items stay valid in
## old saves but are not sold.
const ITEMS := {
	# Weapons
	"nib": {"name": "Nib-Sword", "slot": "weapon", "price": 0,
		"desc": "The pen that drew you. Balanced.", "effect": {},
		"special": "wave", "special_name": "INK WAVE",
		"special_desc": "Hold attack, let go: a wave of ink cuts through everything in a line.",
		"master": "The wave hits for +2 and flies further.",
		"look": {"weapon": "nib", "blade_length": 36.0, "grip": Color(1.0, 0.58, 0.14), "slash_rim": Color(1.0, 0.58, 0.14)}},
	"quill": {"name": "Quill Rapier", "slot": "weapon", "price": 25,
		"desc": "A long feather blade. Swings 25% faster, reaches a little shorter.", "effect": {"swing_mult": 0.75, "reach_mult": 0.9},
		"special": "darts", "special_name": "QUILL VOLLEY",
		"special_desc": "Hold attack, let go: three quills fly out in a fan and pierce everything.",
		"master": "Five quills instead of three.",
		"look": {"weapon": "quill", "blade_length": 44.0, "grip": Color(0.55, 0.85, 1.0), "slash_rim": Color(0.45, 0.85, 1.0)}},
	"brush": {"name": "Brush Maul", "slot": "weapon", "price": 32,
		"desc": "A fat ink brush. +1 damage and a wider swing, but 30% slower.", "effect": {"damage_bonus": 1, "radius_mult": 1.25, "swing_mult": 1.3},
		"special": "slam", "special_name": "INK SLAM",
		"special_desc": "Hold attack, let go: slam the ground; a ring of ink throws back everything round you.",
		"master": "A wider ring that hits for +1.",
		"look": {"weapon": "brush", "blade_length": 30.0, "grip": Color(0.9, 0.2, 0.25), "slash_rim": Color(1.0, 0.25, 0.3)}},
	"corkscrew": {"name": "Corkscrew Nib", "slot": "weapon", "price": 45,
		"desc": "The twisted pen-drill. Quick, short thrusts.", "effect": {"swing_mult": 0.85, "reach_mult": 0.85},
		"special": "drill", "special_name": "PEN-DRILL",
		"special_desc": "Hold attack to spin like a drill, dragging monsters in and grinding them. Let go to burst them outward.",
		"master": "Drags from further away; the burst hits for +2.",
		"look": {"weapon": "corkscrew", "blade_length": 38.0, "grip": Color(0.62, 0.4, 0.22), "slash_rim": Color(0.75, 0.78, 0.85)}},
	"prism": {"name": "Prism Saber", "slot": "weapon", "price": 52,
		"desc": "The light refractor. Its hits dazzle (longer stun), and it cuts what the dark hides.", "effect": {"reach_mult": 1.1},
		"special": "sweep", "special_name": "BLINDING SWEEP",
		"special_desc": "Hold attack, let go: a rainbow sweep blinds everything in front and turns the Haunting Lamp's light away.",
		"master": "A wider sweep that blinds twice as long.",
		"look": {"weapon": "prism", "blade_length": 40.0, "grip": Color(0.2, 0.22, 0.3), "slash_rim": Color(0.55, 1.0, 0.95)}},
	"lantern": {"name": "Lantern Flail", "slot": "weapon", "price": 40,
		"desc": "A lantern on a chain. Long reach, a little slow.", "effect": {"reach_mult": 1.3, "swing_mult": 1.15},
		"special": "whirl", "special_name": "LANTERN WHIRL",
		"special_desc": "Hold attack to whirl the lantern round you: it hits all it passes, and its light makes sketches solid and shows hidden things. Burns Ember.",
		"master": "A wider, brighter orbit that hits for +1.",
		"look": {"weapon": "lantern", "blade_length": 34.0, "grip": Color(1.0, 0.75, 0.3), "slash_rim": Color(1.0, 0.8, 0.35)}},
	"compass": {"name": "Compass Edge", "slot": "weapon", "price": 55, "retired": true,
		"desc": "Every hit stokes the Ember twice as much.", "effect": {"fuel_hit_mult": 2.0},
		"special": "wave", "special_name": "INK WAVE",
		"special_desc": "Hold attack, let go: a wave of ink cuts through everything in a line.",
		"master": "The wave hits for +2 and flies further.",
		"look": {"weapon": "nib", "blade_length": 38.0, "grip": Color(1.0, 0.85, 0.3), "slash_rim": Color(1.0, 0.85, 0.3)}},
	# Armor (2.5D: ink drops; 2D: +20 health a drop)
	"paper": {"name": "Paper Cloak", "slot": "armor", "price": 0,
		"desc": "No protection to speak of.", "effect": {}, "look": {}},
	"cardboard": {"name": "Cardboard Vest", "slot": "armor", "price": 28,
		"desc": "+1 ink drop of health.", "effect": {"health_bonus": 1}, "look": {}},
	"blotter": {"name": "Blotter Coat", "slot": "armor", "price": 32,
		"desc": "Soaks up hits: 60% longer safety after being hurt.", "effect": {"invuln_mult": 1.6}, "look": {}},
	"wax": {"name": "Wax-Seal Mantle", "slot": "armor", "price": 48,
		"desc": "The first hit in every room or level cracks the seal instead of you.", "effect": {"seal": true}, "look": {}},
	# Hats: the hat and its band
	"topper": {"name": "Black Topper", "slot": "hat", "price": 0,
		"desc": "As first drawn: black, with a red band.", "effect": {},
		"look": {"hat": Color(0.12, 0.1, 0.13), "band": Color(0.85, 0.22, 0.16)}},
	"crimson_hat": {"name": "Crimson Topper", "slot": "hat", "price": 8,
		"desc": "Red as the Red Pen's ink. A black band.", "effect": {},
		"look": {"hat": Color(0.55, 0.09, 0.11), "band": Color(0.08, 0.06, 0.08)}},
	"ivory_hat": {"name": "Ivory Topper", "slot": "hat", "price": 10,
		"desc": "Paper white. Very clean, for the Gutter.", "effect": {},
		"look": {"hat": Color(0.9, 0.87, 0.8), "band": Color(0.12, 0.1, 0.13)}},
	"navy_hat": {"name": "Midnight Topper", "slot": "hat", "price": 8,
		"desc": "Deep blue with a gold band.", "effect": {},
		"look": {"hat": Color(0.12, 0.16, 0.38), "band": Color(0.95, 0.75, 0.25)}},
	"moss_hat": {"name": "Inkwood Topper", "slot": "hat", "price": 8,
		"desc": "Mossy green, a cream band.", "effect": {},
		"look": {"hat": Color(0.2, 0.32, 0.2), "band": Color(0.9, 0.85, 0.7)}},
	"plum_hat": {"name": "Plum Topper", "slot": "hat", "price": 10,
		"desc": "Plum purple with a pale gold band.", "effect": {},
		"look": {"hat": Color(0.36, 0.18, 0.42), "band": Color(0.95, 0.8, 0.4)}},
	"ember_hat": {"name": "Ember Band", "slot": "hat", "price": 15,
		"desc": "Black, and a band that glows like the Ember.", "effect": {},
		"look": {"hat": Color(0.1, 0.08, 0.1), "band": Color(1.0, 0.62, 0.22)}},
	# Scarves (slot "cosmetic", kept for old saves)
	"classic": {"name": "Classic", "slot": "cosmetic", "price": 0,
		"desc": "Red scarf, as first drawn.", "effect": {},
		"look": {"scarf": Color(0.92, 0.3, 0.2), "mask": Color(0.98, 0.96, 0.9)}},
	"midnight": {"name": "Midnight Scarf", "slot": "cosmetic", "price": 8,
		"desc": "A scarf dyed in the deep blue of the Margins.", "effect": {},
		"look": {"scarf": Color(0.25, 0.35, 0.9), "mask": Color(0.92, 0.94, 1.0)}},
	"sunflower": {"name": "Sunflower", "slot": "cosmetic", "price": 10,
		"desc": "Bright as the Lit Pages.", "effect": {},
		"look": {"scarf": Color(1.0, 0.82, 0.2), "mask": Color(1.0, 0.97, 0.88)}},
	"emerald": {"name": "Shrine Green", "slot": "cosmetic", "price": 10,
		"desc": "The green of the Writer's lamp.", "effect": {},
		"look": {"scarf": Color(0.25, 0.7, 0.5), "mask": Color(0.95, 0.98, 0.94)}},
	"ghost": {"name": "Ghost Draft", "slot": "cosmetic", "price": 16,
		"desc": "Pale as an unlit plank. Spooky.", "effect": {},
		"look": {"scarf": Color(0.85, 0.9, 1.0), "mask": Color(0.8, 0.86, 0.95)}},
	"ink_blot": {"name": "Ink Blot", "slot": "cosmetic", "price": 15,
		"desc": "Black scarf, inked mask. Very serious.", "effect": {},
		"look": {"scarf": Color(0.1, 0.08, 0.14), "mask": Color(0.75, 0.73, 0.8)}},
	# Cloaks
	"ink_cloak": {"name": "Ink Cloak", "slot": "cloak", "price": 0,
		"desc": "Vesper's own: ink black with a violet lining.", "effect": {},
		"look": {"cloak": Color(0.14, 0.11, 0.16), "cloak_rim": Color(0.36, 0.3, 0.42)}},
	"violet_cloak": {"name": "Traveler's Violet", "slot": "cloak", "price": 10,
		"desc": "The muted purple of the first sketches.", "effect": {},
		"look": {"cloak": Color(0.44, 0.4, 0.53), "cloak_rim": Color(0.3, 0.27, 0.36)}},
	"red_cloak": {"name": "Red Pen Cloak", "slot": "cloak", "price": 15,
		"desc": "Corrections red. Bold.", "effect": {},
		"look": {"cloak": Color(0.5, 0.1, 0.12), "cloak_rim": Color(0.75, 0.3, 0.3)}},
	"green_cloak": {"name": "Inkwood Green", "slot": "cloak", "price": 10,
		"desc": "The green of the dead sketches' wood.", "effect": {},
		"look": {"cloak": Color(0.16, 0.3, 0.24), "cloak_rim": Color(0.3, 0.48, 0.38)}},
	"blue_cloak": {"name": "Drowned Blue", "slot": "cloak", "price": 10,
		"desc": "Wet-ink blue, from the Drowned Margin.", "effect": {},
		"look": {"cloak": Color(0.14, 0.2, 0.42), "cloak_rim": Color(0.3, 0.42, 0.72)}},
	"sepia_cloak": {"name": "Old Paper", "slot": "cloak", "price": 15,
		"desc": "Yellowed like a page left in the sun.", "effect": {},
		"look": {"cloak": Color(0.58, 0.48, 0.34), "cloak_rim": Color(0.78, 0.68, 0.5)}},
}

## The weapon upgrades, bought in order for each weapon (shop UPGRADES tab).
## The third one's text is the weapon's own `master`.
const UPGRADES := [
	{"name": "SHARPENED", "price": 12, "desc": "+1 damage on every hit."},
	{"name": "QUICK HAND", "price": 24, "desc": "Its special charges 40% faster."},
	{"name": "MASTERWORK", "price": 40, "desc": ""},
]

## Shop tabs: [slot, title]. "upgrade" lists the weapons you own.
const SLOTS := [["weapon", "WEAPONS"], ["upgrade", "UPGRADES"], ["hat", "HATS"], ["cosmetic", "SCARVES"],
	["cloak", "CLOAKS"], ["armor", "ARMOR"]]
const STARTING := {"weapon": "nib", "armor": "paper", "cosmetic": "classic", "hat": "topper", "cloak": "ink_cloak"}
