extends RefCounted
## All cutscene content for Vesper. Edit the text and art here.
##
## CUTSCENES[id] = list of pages. A page has a paper colour and panels.
## A panel has:
##   rect     [x, y, w, h] in pixels on the 1280x720 page
##   enter    "pop" (default), "slam" or "fade"
##   border   "ink" (default) or "line" (white, for dark pages)
##   draw     list of draw ops, see cutscene_panel.gd `_op` for the full list
##   captions list of {who, text, x, y, w}; x/y/w are 0..1 of the panel
##            who: "writer" (yellow caption), "shaky" (the Writer losing it),
##                 "vesper" (speech bubble), "shade" (black bubble),
##                 "margin" (neutral narration on dark pages)

const CUTSCENES := {
	# ------------------------------------------------------------ OPENING
	"opening": [
		{"paper": "cream", "panels": [
			{"rect": [40, 30, 1200, 300],
			"draw": [
				["bg", "gray"],
				["ground", 0.82, "gray_dark", "ink"],
				["block", 0.80, 0.56, 0.11, 0.07, "gray", "ghost"],
				["block", 0.06, 0.62, 0.09, 0.07, "gray", "ghost"],
				["beam", 0.56, 0.05, 0.56, 0.82, 0.17, "warm"],
				["lamp", 0.56, 0.0, 0.0],
				["block", 0.62, 0.62, 0.09, 0.07, "red", "solid"],
				["vesper", 0.54, 0.82, 1.7, "stand", 1],
			],
			"captions": [
				{"who": "writer", "x": 0.02, "y": 0.07, "w": 0.33,
				"text": "Page one. A clean sheet, a warm lamp, and a small hero named Vesper."},
			]},
			{"rect": [40, 350, 590, 320],
			"draw": [
				["bg", "gray"],
				["beam", 0.3, 0.0, 0.3, 0.75, 0.3, "warm"],
				["block", 0.0, 0.7, 0.2, 0.08, "blue", "solid"],
				["block", 0.2, 0.7, 0.2, 0.08, "blue", "solid"],
				["block", 0.4, 0.7, 0.2, 0.08, "blue", "solid"],
				["block", 0.6, 0.7, 0.2, 0.08, "gray", "ghost"],
				["block", 0.8, 0.7, 0.2, 0.08, "gray", "ghost"],
				["vesper", 0.3, 0.7, 1.5, "stand", 1],
			],
			"captions": [
				{"who": "writer", "x": 0.42, "y": 0.06, "w": 0.55,
				"text": "Where my light falls, the world is real. Solid. In colour."},
				{"who": "writer", "x": 0.42, "y": 0.4, "w": 0.55,
				"text": "Where it doesn't... mind the gap."},
			]},
			{"rect": [650, 350, 590, 320],
			"draw": [
				["bg", "gray"],
				["ground", 0.8, "gray_dark", "ink"],
				["beam", 0.5, 0.0, 0.5, 0.8, 0.26, "warm"],
				["vesper", 0.5, 0.8, 2.2, "wave", 1],
			],
			"captions": [
				{"who": "vesper", "x": 0.04, "y": 0.08, "w": 0.36, "text": "Bit bright up there, isn't it?"},
				{"who": "writer", "x": 0.6, "y": 0.52, "w": 0.38, "text": "Don't worry. I'll keep the light on you."},
			]},
		]},
		{"paper": "cream", "panels": [
			{"rect": [40, 30, 700, 640],
			"draw": [
				["bg", "gray"],
				["rect", 0.66, 0.0, 0.34, 1.0, "black"],
				["ground", 0.84, "gray_dark", "ink"],
				["rect", 0.66, 0.84, 0.34, 0.16, "black"],
				["beam", 0.3, 0.0, 0.3, 0.84, 0.27, "warm"],
				["lamp", 0.3, 0.0, 0.0],
				["vesper", 0.3, 0.84, 1.2, "stand", 1],
				["eyes", 0.7, 0.1, 0.26, 0.8, 9, 7],
				["scribble", 0.82, 0.74, 0.8, 3, "line"],
			],
			"captions": [
				{"who": "writer", "x": 0.03, "y": 0.04, "w": 0.6,
				"text": "And the things in the gutters, between the panels? Scribbles. Crossed-out things."},
				{"who": "writer", "x": 0.03, "y": 0.86, "w": 0.6,
				"text": "The lamp burns them away. They can't touch you here."},
			]},
			{"rect": [760, 30, 480, 640], "border": "line",
			"draw": [
				["bg", "black"],
				["eyes", 0.06, 0.25, 0.88, 0.6, 16, 21],
				["scribble", 0.3, 0.7, 0.9, 11, "line"],
				["scribble", 0.72, 0.52, 0.7, 5, "line"],
				["text", 0.5, 0.92, 9, "...scritch...", "line", -0.08, "black"],
			],
			"captions": [
				{"who": "writer", "x": 0.08, "y": 0.05, "w": 0.84, "text": "Now then. On with the story."},
			]},
		]},
	],

	# ------------------------------------------------------ PAGE 3: THE END
	"page3": [
		{"paper": "cream", "panels": [
			{"rect": [40, 30, 1200, 280],
			"draw": [
				["bg", "gray"],
				["ground", 0.82, "gray_dark", "ink"],
				["beam", 0.2, 0.0, 0.5, 0.82, 0.3, "warm"],
				["lamp", 0.2, 0.0, -0.5],
				["poly", "shadow", [0.52, 0.82, 0.6, 0.82, 0.86, 1.0, 0.66, 1.0]],
				["poly", "shadow", [0.56, 0.52, 0.6, 0.52, 0.8, 0.82, 0.6, 0.82]],
				["block", 0.5, 0.52, 0.07, 0.3, "wood", "solid"],
				["shade", 0.72, 0.9, 0.9],
				["vesper", 0.36, 0.82, 1.5, "stand", 1],
			],
			"captions": [
				{"who": "writer", "x": 0.02, "y": 0.5, "w": 0.26,
				"text": "Page three. Every shadow is a door, and something has found one."},
			]},
			{"rect": [40, 330, 590, 340],
			"draw": [
				["bg", "gray"],
				["ground", 0.84, "gray_dark", "ink"],
				["beam", 0.1, 0.0, 0.25, 0.84, 0.2, "warm"],
				["shade", 0.68, 0.84, 2.0, 0.34, 0.6],
				["vesper", 0.26, 0.84, 1.7, "stand", 1],
				["text", 0.45, 0.42, 30, "WHAM!", "yellow", -0.2, "ink"],
			],
			"captions": [
				{"who": "writer", "x": 0.03, "y": 0.05, "w": 0.6, "text": "Vesper fought. Of course he did. I wrote him brave."},
			]},
			{"rect": [650, 330, 590, 340],
			"draw": [
				["bg", "gray"],
				["ground", 0.84, "gray_dark", "ink"],
				["beam", 0.5, 0.0, 0.5, 0.84, 0.22, "warm"],
				["vesper", 0.5, 0.84, 1.8, "down", 1],
			],
			"captions": [
				{"who": "writer", "x": 0.03, "y": 0.05, "w": 0.7,
				"text": "But this is the page where he falls. It always has been."},
			]},
		]},
		{"paper": "black", "panels": [
			{"rect": [140, 50, 1000, 600], "enter": "slam",
			"draw": [
				["bg", "white"],
				["text", 0.5, 0.36, 82, "THE END", "ink", 0.0, "white"],
				["line", 0.3, 0.52, 0.7, 0.52, "ink", 2],
			]},
			{"rect": [330, 440, 620, 220], "enter": "fade",
			"draw": [
				["bg", "white"],
				["ground", 0.85, "gray", "ink"],
				["vesper", 0.42, 0.85, 1.9, "crawl", 1],
			],
			"captions": [
				{"who": "vesper", "x": 0.58, "y": 0.12, "w": 0.36, "text": "...not yet."},
			]},
		]},
		{"paper": "cream", "panels": [
			{"rect": [40, 30, 580, 640],
			"draw": [
				["bg", "white"],
				["rect", 0.8, 0.0, 0.2, 1.0, "black"],
				["poly", "black", [0.8, 0.52, 0.7, 0.6, 0.76, 0.68, 0.66, 0.76, 0.8, 0.84]],
				["text", 0.4, 0.3, 40, "THE END", "gray", 0.0, "white"],
				["ground", 0.84, "gray", "ink"],
				["rect", 0.8, 0.84, 0.2, 0.16, "black"],
				["vesper", 0.66, 0.84, 1.1, "crawl", 1],
				["eyes", 0.83, 0.1, 0.14, 0.8, 5, 44],
			],
			"captions": [
				{"who": "shaky", "x": 0.04, "y": 0.42, "w": 0.6, "text": "...No. That isn't how this goes."},
				{"who": "shaky", "x": 0.04, "y": 0.56, "w": 0.5, "text": "Get back on the page."},
			]},
			{"rect": [640, 30, 600, 310],
			"draw": [
				["bg", "cream"],
				["vesper", 0.3, 0.9, 3.2, "stand", 1],
				["cross", 0.3, 0.52, 80],
				["hand", 0.48, 0.3, 1.2],
			],
			"captions": [
				{"who": "shaky", "x": 0.48, "y": 0.62, "w": 0.48, "text": "Fine. Then I'll cross you out myself."},
			]},
			{"rect": [640, 360, 600, 310], "border": "line",
			"draw": [
				["bg", "black"],
				["beam", 0.1, 0.0, 0.42, 0.85, 0.18, "burn"],
				["lamp", 0.1, 0.0, -0.45],
				["line", 0.0, 0.85, 1.0, 0.85, "line", 2],
				["vesper", 0.5, 0.85, 1.7, "run", 1],
				["text", 0.34, 0.6, 20, "SSSSS", Color(1.0, 0.5, 0.3), 0.15, "black"],
			],
			"captions": [
				{"who": "margin", "x": 0.4, "y": 0.06, "w": 0.57,
				"text": "The lamp turned. For the first time, the light burned."},
			]},
		]},
	],

	# ---------------------------------------------------- THE SHADE REVEAL
	"reveal": [
		{"paper": "black", "panels": [
			{"rect": [40, 30, 1200, 280], "border": "line",
			"draw": [
				["bg", "black"],
				["line", 0.0, 0.84, 1.0, 0.84, "line", 2],
				["glow", 0.42, 0.62, 150, Color(1.0, 0.6, 0.25)],
				["paper", 0.56, 0.76, 0.8, 0.3],
				["vesper", 0.42, 0.84, 1.6, "torn", 1],
				["circle", 0.455, 0.62, 5, Color(1.0, 0.7, 0.3)],
				["eyes", 0.72, 0.15, 0.25, 0.55, 6, 9],
			],
			"captions": [
				{"who": "margin", "x": 0.02, "y": 0.08, "w": 0.3,
				"text": "Deep in the Margins, among everything the Writer threw away, Vesper found a crumpled draft of page three."},
			]},
			{"rect": [40, 330, 590, 340], "border": "line",
			"draw": [
				["bg", Color(0.9, 0.87, 0.8)],
				["ground", 0.84, "gray", "ink"],
				["rect", 0.0, 0.0, 1.0, 0.2, "white"],
				["line", 0.0, 0.2, 1.0, 0.2, "ink", 4],
				["text", 0.5, 0.1, 22, "THE END", "ink", 0.0, "white"],
				["rect", 0.72, 0.2, 0.28, 0.8, "black"],
				["shade", 0.88, 0.84, 1.5, 0.4, 0.62],
				["vesper", 0.34, 0.84, 1.6, "down", 1],
			],
			"captions": [
				{"who": "margin", "x": 0.03, "y": 0.26, "w": 0.6,
				"text": "From the dark side of the panel, the fight reads differently."},
			]},
			{"rect": [650, 330, 590, 340], "border": "line",
			"draw": [
				["bg", "black"],
				["rect", 0.0, 0.0, 0.3, 1.0, Color(0.9, 0.87, 0.8)],
				["shade", 0.66, 0.9, 2.0, 0.36, 0.66],
				["vesper", 0.3, 0.86, 1.5, "crawl", 1],
			],
			"captions": [
				{"who": "shade", "x": 0.34, "y": 0.05, "w": 0.62,
				"text": "I wasn't dragging you down. I was pulling you OUT."},
			]},
		]},
		{"paper": "black", "panels": [
			{"rect": [40, 30, 580, 640], "border": "line",
			"draw": [
				["bg", "gray"],
				["ground", 0.8, "gray_dark", "ink"],
				["beam", 0.1, 0.0, 0.4, 0.8, 0.34, "warm"],
				["lamp", 0.1, 0.0, -0.45],
				["rect", 0.7, 0.34, 0.3, 0.46, "white"],
				["line", 0.7, 0.34, 0.7, 0.8, "ink", 3],
				["line", 0.7, 0.34, 1.0, 0.34, "ink", 3],
				["text", 0.85, 0.56, 13, "THE END", "ink", 0.0, "white"],
				["line", 0.2, 0.86, 0.62, 0.86, "ink", 1.5],
				["poly", "ink", [0.62, 0.845, 0.66, 0.86, 0.62, 0.875]],
				["vesper", 0.36, 0.8, 1.1, "stand", 1],
			],
			"captions": [
				{"who": "margin", "x": 0.2, "y": 0.87, "w": 0.76,
				"text": "The friendly light had been walking him to that panel since page one."},
			]},
			{"rect": [640, 30, 600, 310], "border": "line",
			"draw": [
				["bg", "black"],
				["line", 0.0, 0.88, 1.0, 0.88, "line", 2],
				["vesper", 0.62, 0.88, 1.5, "ghost", -1],
				["vesper", 0.78, 0.88, 1.9, "ghost", -1],
				["vesper", 0.92, 0.88, 1.3, "ghost", -1],
				["scribble", 0.7, 0.5, 0.8, 8, "line"],
			],
			"captions": [
				{"who": "margin", "x": 0.03, "y": 0.06, "w": 0.5,
				"text": "And the monsters? Look closer. Same cloak. Same eye."},
				{"who": "margin", "x": 0.03, "y": 0.5, "w": 0.5,
				"text": "Every one of them is a Vesper the Writer started and gave up on."},
			]},
			{"rect": [640, 360, 600, 310], "border": "line",
			"draw": [
				["bg", "black"],
				["line", 0.0, 0.88, 1.0, 0.88, "line", 2],
				["glow", 0.3, 0.6, 130, Color(1.0, 0.6, 0.25)],
				["vesper", 0.3, 0.88, 1.9, "torn", 1],
				["circle", 0.36, 0.6, 5, Color(1.0, 0.7, 0.3)],
			],
			"captions": [
				{"who": "vesper", "x": 0.45, "y": 0.4, "w": 0.5, "text": "Then why does the Writer want me dead?"},
			]},
		]},
	],

	# -------------------------------------------------------------- ENDING
	"ending": [
		{"paper": "night", "panels": [
			{"rect": [40, 30, 1200, 360], "border": "line",
			"draw": [
				["bg", "night"],
				["rect", 0.0, 0.7, 1.0, 0.3, "wood"],
				["line", 0.0, 0.7, 1.0, 0.7, "ink", 3],
				["desklamp", 0.2, 0.74, 1.3],
				["beam", 0.265, 0.36, 0.55, 0.86, 0.2, "warm"],
				["poly", "white", [0.4, 0.78, 0.56, 0.76, 0.58, 0.92, 0.38, 0.94]],
				["poly", "white", [0.56, 0.76, 0.72, 0.78, 0.76, 0.94, 0.58, 0.92]],
				["line", 0.56, 0.76, 0.58, 0.92, "ink", 2],
				["text", 0.66, 0.85, 9, "THE END", "gray_dark", 0.05, "white"],
				["pencil", 0.8, 0.88, 110, -0.3],
				["vesper", 0.5, 0.86, 0.45, "stand", 1],
			],
			"captions": [
				{"who": "margin", "x": 0.42, "y": 0.06, "w": 0.55,
				"text": "Vesper climbed out of the last panel, and the world unfolded. A desk. A real lamp. A comic, left open at page three."},
			]},
			{"rect": [40, 410, 590, 260], "border": "line",
			"draw": [
				["bg", "night"],
				["glow", 0.22, 0.5, 200, Color(1.0, 0.85, 0.5)],
				["photo", 0.22, 0.52, 1.25, -0.08],
			],
			"captions": [
				{"who": "writer", "x": 0.42, "y": 0.2, "w": 0.54,
				"text": "I based you on someone. Page three is where I lost them."},
			]},
			{"rect": [650, 410, 590, 260], "border": "line",
			"draw": [
				["bg", "night"],
				["rect", 0.0, 0.8, 1.0, 0.2, "wood_dark"],
				["paper", 0.14, 0.7, 1.0, 0.4],
				["paper", 0.3, 0.74, 0.9, -0.5],
				["paper", 0.22, 0.48, 0.9, 1.2],
				["paper", 0.42, 0.72, 0.8, 0.9],
			],
			"captions": [
				{"who": "writer", "x": 0.5, "y": 0.2, "w": 0.46,
				"text": "I've drawn it a hundred times. I could never finish it."},
			]},
		]},
		{"paper": "night", "panels": [
			{"rect": [40, 30, 580, 640], "border": "line",
			"draw": [
				["bg", "black"],
				["rect", 0.0, 0.88, 1.0, 0.12, "wood_dark"],
				["shade", 0.56, 0.86, 3.0, 0.3, 0.8],
				["vesper", 0.2, 0.88, 0.7, "torn", 1],
			],
			"captions": [
				{"who": "shade", "x": 0.05, "y": 0.04, "w": 0.9,
				"text": "Stay in the dark with me. If the last page is never drawn, nobody has to die."},
			]},
			{"rect": [640, 30, 600, 310], "border": "line",
			"draw": [
				["bg", "night"],
				["rect", 0.0, 0.86, 1.0, 0.14, "wood_dark"],
				["shade", 0.7, 0.86, 1.6],
				["beam", 0.95, 0.0, 0.7, 0.86, 0.2, "warm"],
				["vesper", 0.4, 0.86, 1.5, "torn", 1],
				["text", 0.56, 0.66, 26, "SHNK!", "yellow", -0.15, "ink"],
			],
			"captions": [
				{"who": "margin", "x": 0.03, "y": 0.06, "w": 0.6,
				"text": "The Shade was never a monster. It was the part of the Writer that couldn't let go."},
			]},
			{"rect": [640, 360, 600, 310], "border": "line",
			"draw": [
				["bg", "night"],
				["rect", 0.0, 0.86, 1.0, 0.14, "wood"],
				["beam", 1.0, 0.0, 0.76, 0.86, 0.24, "warm"],
				["vesper", 0.46, 0.86, 1.7, "torn", 1],
			],
			"captions": [
				{"who": "vesper", "x": 0.05, "y": 0.1, "w": 0.4, "text": "It's okay. You can finish it."},
			]},
		]},
		{"paper": "cream", "panels": [
			{"rect": [40, 30, 700, 640], "enter": "fade",
			"draw": [
				["bg", "cream"],
				["glow", 0.42, 0.56, 330, Color(1.0, 0.88, 0.45)],
				["ground", 0.8, Color(0.88, 0.8, 0.62), "ink"],
				["vesper", 0.42, 0.8, 1.7, "wave", 1],
				["hand", 0.74, 0.74, 1.0],
			],
			"captions": [
				{"who": "writer", "x": 0.04, "y": 0.05, "w": 0.6,
				"text": "So I drew the last panel. Not a fall. A goodbye."},
				{"who": "writer", "x": 0.04, "y": 0.86, "w": 0.6,
				"text": "The light was warm again, like on page one."},
			]},
			{"rect": [760, 30, 480, 640], "enter": "fade",
			"draw": [
				["bg", Color(0.2, 0.24, 0.42)],
				["rect", 0.08, 0.06, 0.84, 0.88, "cream"],
				["glow", 0.5, 0.52, 75, Color(1.0, 0.85, 0.4)],
				["text", 0.5, 0.2, 27, "VESPER", "ink", 0.0, "cream"],
				["text", 0.5, 0.29, 9, "Issue #1", "ink", 0.0, "cream"],
				["vesper", 0.5, 0.66, 1.1, "wave", 1],
				["text", 0.5, 0.8, 8, "for you.", "ink", 0.0, "cream"],
				["text", 0.5, 0.88, 7, "THE END", "red", 0.0, "cream"],
			]},
		]},
	],
}
