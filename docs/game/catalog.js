window.MechCatalog = {
	"mechs": {
		"nova": {
			"name": "Nova",
			"role": "Balanced",
			"description": "Quick blade arcs. Clean movement. A little bit of everything.",
			"weapon": "arc_blade",
			"shell": "fin_plate",
			"color": "#2875ef",
			"energy": "#54e8ff",
			"height": 180.0,
			"speed": 780.0
		},
		"kuren": {
			"name": "Kuren",
			"role": "Rushdown",
			"description": "Close the gap. Hit hard. Keep the pressure on.",
			"weapon": "burst_knuckle",
			"shell": "vent_shell",
			"color": "#ef3d58",
			"energy": "#ff9f50",
			"height": 170.0,
			"speed": 910.0
		},
		"terra": {
			"name": "Terra",
			"role": "Heavy / Grappler",
			"description": "A huge cannon. A mean clinch. Own the landing zone.",
			"weapon": "pile_cannon",
			"shell": "bulwark",
			"color": "#718b38",
			"energy": "#c7eb53",
			"height": 205.0,
			"speed": 610.0
		},
		"momo": {
			"name": "Momo",
			"role": "Tech / Trickster",
			"description": "Set a snare. Call a repair drone. Make their cannon your cannon.",
			"weapon": "halo_caster",
			"shell": "halo_shell",
			"color": "#f691cc",
			"energy": "#ffe1f0",
			"height": 156.0,
			"speed": 730.0
		},
		"shadow": {
			"name": "Shadow",
			"role": "Trickster",
			"description": "A tell, a blink, a landing strike. Slip around their guard.",
			"weapon": "phase_talon",
			"shell": "mirage_mantle",
			"color": "#494063",
			"energy": "#df74ff",
			"height": 171.0,
			"speed": 865.0
		},
		"lumi": {
			"name": "Lumi",
			"role": "Zoner",
			"description": "Leave a prism in their path. Make space, then own it.",
			"weapon": "prism_emitter",
			"shell": "prism_shell",
			"color": "#f4cd72",
			"energy": "#aceeff",
			"height": 179.0,
			"speed": 685.0
		},
		"kai": {
			"name": "Kai",
			"role": "Glass Cannon",
			"description": "Charge up. Commit to the shot. Huge power, a fragile frame.",
			"weapon": "rail_lance",
			"shell": "flux_frame",
			"color": "#328adc",
			"energy": "#78e9ff",
			"height": 177.0,
			"speed": 835.0
		},
		"zero": {
			"name": "Zero",
			"role": "Wildcard",
			"description": "Change Special with up or down. Stolen gear changes your breaker.",
			"weapon": "switch_driver",
			"shell": "adaptive_shell",
			"color": "#474551",
			"energy": "#ff5c77",
			"height": 174.0,
			"speed": 775.0
		}
	},
	"parts": {
		"arc_blade": {
			"name": "Arc Blade",
			"short": "BLADE",
			"donor": "nova",
			"slot": "weapon_arm",
			"max": 40.0,
			"color": "#2875ef",
			"energy": "#54e8ff"
		},
		"burst_knuckle": {
			"name": "Burst Knuckle",
			"short": "BURST",
			"donor": "kuren",
			"slot": "weapon_arm",
			"max": 40.0,
			"color": "#ef3d58",
			"energy": "#ff9f50"
		},
		"pile_cannon": {
			"name": "Pile Cannon",
			"short": "CANNON",
			"donor": "terra",
			"slot": "weapon_arm",
			"max": 40.0,
			"color": "#718b38",
			"energy": "#c7eb53"
		},
		"halo_caster": {
			"name": "Halo Caster",
			"short": "HALO",
			"donor": "momo",
			"slot": "weapon_arm",
			"max": 40.0,
			"color": "#f691cc",
			"energy": "#ffe1f0"
		},
		"phase_talon": {
			"name": "Phase Talon",
			"short": "TALON",
			"donor": "shadow",
			"slot": "weapon_arm",
			"max": 40.0,
			"color": "#494063",
			"energy": "#df74ff"
		},
		"prism_emitter": {
			"name": "Prism Emitter",
			"short": "PRISM",
			"donor": "lumi",
			"slot": "weapon_arm",
			"max": 40.0,
			"color": "#f4cd72",
			"energy": "#aceeff"
		},
		"rail_lance": {
			"name": "Rail Lance",
			"short": "RAIL",
			"donor": "kai",
			"slot": "weapon_arm",
			"max": 40.0,
			"color": "#328adc",
			"energy": "#78e9ff"
		},
		"switch_driver": {
			"name": "Switch Driver",
			"short": "DRIVER",
			"donor": "zero",
			"slot": "weapon_arm",
			"max": 40.0,
			"color": "#474551",
			"energy": "#ff5c77"
		},
		"fin_plate": {
			"name": "Fin Plate",
			"short": "FIN",
			"donor": "nova",
			"slot": "shell",
			"max": 60.0,
			"color": "#2875ef",
			"energy": "#54e8ff"
		},
		"vent_shell": {
			"name": "Vent Shell",
			"short": "VENT",
			"donor": "kuren",
			"slot": "shell",
			"max": 60.0,
			"color": "#ef3d58",
			"energy": "#ff9f50"
		},
		"bulwark": {
			"name": "Bulwark",
			"short": "WALL",
			"donor": "terra",
			"slot": "shell",
			"max": 60.0,
			"color": "#718b38",
			"energy": "#c7eb53"
		},
		"halo_shell": {
			"name": "Halo Shell",
			"short": "HALO",
			"donor": "momo",
			"slot": "shell",
			"max": 60.0,
			"color": "#f691cc",
			"energy": "#ffe1f0"
		},
		"mirage_mantle": {
			"name": "Mirage Mantle",
			"short": "MIRAGE",
			"donor": "shadow",
			"slot": "shell",
			"max": 60.0,
			"color": "#494063",
			"energy": "#df74ff"
		},
		"prism_shell": {
			"name": "Prism Shell",
			"short": "PRISM",
			"donor": "lumi",
			"slot": "shell",
			"max": 60.0,
			"color": "#f4cd72",
			"energy": "#aceeff"
		},
		"flux_frame": {
			"name": "Flux Frame",
			"short": "FLUX",
			"donor": "kai",
			"slot": "shell",
			"max": 60.0,
			"color": "#328adc",
			"energy": "#78e9ff"
		},
		"adaptive_shell": {
			"name": "Adaptive Shell",
			"short": "ADAPT",
			"donor": "zero",
			"slot": "shell",
			"max": 60.0,
			"color": "#474551",
			"energy": "#ff5c77"
		}
	},
	"stages": {
		"skyport": {
			"name": "Skyport",
			"description": "Open decks and a drifting transit platform.",
			"moving_index": 3,
			"platforms": [
				[
					-1100.0,
					0.0,
					2200.0,
					100.0
				],
				[
					-1000.0,
					-360.0,
					600.0,
					32.0
				],
				[
					400.0,
					-360.0,
					600.0,
					32.0
				],
				[
					-200.0,
					-620.0,
					400.0,
					32.0
				]
			],
			"accent": "#3bccd5",
			"deck": "#e7f4f5",
			"dark": "#213b59",
			"trim": "#ffcd55",
			"sunlight": "#fff0d5",
			"ambient": "#cce7f1"
		},
		"neon_alley": {
			"name": "Neon Alley",
			"description": "Tight rooftops, a high center perch and a roaming signboard.",
			"moving_index": 4,
			"platforms": [
				[
					-980.0,
					0.0,
					1960.0,
					100.0
				],
				[
					-1170.0,
					-300.0,
					480.0,
					32.0
				],
				[
					690.0,
					-280.0,
					480.0,
					32.0
				],
				[
					-290.0,
					-430.0,
					580.0,
					32.0
				],
				[
					-150.0,
					-710.0,
					300.0,
					28.0
				]
			],
			"accent": "#55e7f0",
			"deck": "#434477",
			"dark": "#18243e",
			"trim": "#ff72bf",
			"sunlight": "#ffe7f5",
			"ambient": "#b7d6ff"
		},
		"junk_fields": {
			"name": "Junk Fields",
			"description": "Wide scrap decks and uneven stacks beneath a crane lift.",
			"moving_index": 4,
			"platforms": [
				[
					-1220.0,
					0.0,
					2440.0,
					110.0
				],
				[
					-1000.0,
					-250.0,
					430.0,
					32.0
				],
				[
					-240.0,
					-320.0,
					480.0,
					32.0
				],
				[
					510.0,
					-480.0,
					630.0,
					32.0
				],
				[
					-190.0,
					-650.0,
					380.0,
					32.0
				]
			],
			"accent": "#72e2c9",
			"deck": "#ddac62",
			"dark": "#3c5261",
			"trim": "#f38440",
			"sunlight": "#ffe1b1",
			"ambient": "#d8e7d2"
		},
		"blossom_core": {
			"name": "Blossom Core",
			"description": "Garden terraces around a floating petal lift.",
			"moving_index": 4,
			"platforms": [
				[
					-1030.0,
					0.0,
					2060.0,
					100.0
				],
				[
					-980.0,
					-300.0,
					620.0,
					32.0
				],
				[
					360.0,
					-300.0,
					620.0,
					32.0
				],
				[
					-340.0,
					-650.0,
					680.0,
					32.0
				],
				[
					-160.0,
					-155.0,
					320.0,
					32.0
				]
			],
			"accent": "#73e2c5",
			"deck": "#fff0ed",
			"dark": "#536e84",
			"trim": "#ed98c9",
			"sunlight": "#fff2dd",
			"ambient": "#d9f3e9"
		},
		"reactor_ring": {
			"name": "Reactor Ring",
			"description": "A broad central ring and a fast vertical reactor lift.",
			"moving_index": 4,
			"platforms": [
				[
					-1100.0,
					0.0,
					2200.0,
					100.0
				],
				[
					-1160.0,
					-480.0,
					440.0,
					32.0
				],
				[
					720.0,
					-480.0,
					440.0,
					32.0
				],
				[
					-410.0,
					-310.0,
					820.0,
					32.0
				],
				[
					-225.0,
					-680.0,
					450.0,
					32.0
				]
			],
			"accent": "#52e7ff",
			"deck": "#d5e4eb",
			"dark": "#27344f",
			"trim": "#ff9848",
			"sunlight": "#d9f9ff",
			"ambient": "#bddbf0"
		},
		"tideglass_station": {
			"name": "Tideglass Station",
			"description": "Cross the pressure docks on a fast horizontal shuttle.",
			"moving_index": 4,
			"platforms": [
				[
					-1250.0,
					0.0,
					2500.0,
					100.0
				],
				[
					-1190.0,
					-255.0,
					510.0,
					32.0
				],
				[
					570.0,
					-455.0,
					600.0,
					32.0
				],
				[
					-650.0,
					-645.0,
					505.0,
					32.0
				],
				[
					-220.0,
					-335.0,
					440.0,
					32.0
				]
			],
			"accent": "#5ef2c8",
			"deck": "#a8d4cf",
			"dark": "#174960",
			"trim": "#ffac55",
			"sunlight": "#eaffee",
			"ambient": "#b9e6ed"
		},
		"cinder_foundry": {
			"name": "Cinder Foundry",
			"description": "Four furnace balconies surround a rising casting piston.",
			"moving_index": 5,
			"platforms": [
				[
					-980.0,
					0.0,
					1960.0,
					100.0
				],
				[
					-1050.0,
					-255.0,
					390.0,
					32.0
				],
				[
					660.0,
					-255.0,
					390.0,
					32.0
				],
				[
					-855.0,
					-570.0,
					475.0,
					32.0
				],
				[
					380.0,
					-570.0,
					475.0,
					32.0
				],
				[
					-200.0,
					-360.0,
					400.0,
					32.0
				]
			],
			"accent": "#ff8a42",
			"deck": "#bb9678",
			"dark": "#422c35",
			"trim": "#ffdf71",
			"sunlight": "#ffd89d",
			"ambient": "#edcac1"
		},
		"aurora_relay": {
			"name": "Aurora Relay",
			"description": "Climb the staggered antenna decks or ride the diagonal cable lift.",
			"moving_index": 5,
			"platforms": [
				[
					-1125.0,
					0.0,
					2250.0,
					100.0
				],
				[
					-1180.0,
					-290.0,
					470.0,
					32.0
				],
				[
					-525.0,
					-495.0,
					455.0,
					32.0
				],
				[
					640.0,
					-355.0,
					520.0,
					32.0
				],
				[
					-165.0,
					-745.0,
					350.0,
					30.0
				],
				[
					-165.0,
					-362.0,
					330.0,
					32.0
				]
			],
			"accent": "#99ffd1",
			"deck": "#d4e6ff",
			"dark": "#393650",
			"trim": "#e88bca",
			"sunlight": "#e7fff8",
			"ambient": "#caddff"
		}
	},
	"moves": {
		"nova_light": {
			"kind": "light",
			"weapon": "",
			"delivery": "melee",
			"breaker": false,
			"startup": 0.055,
			"active": 0.075,
			"recovery": 0.16,
			"offset": [
				0.82,
				0.92
			],
			"size": [
				1.45,
				0.78
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"nova_heavy": {
			"kind": "heavy",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.18,
			"active": 0.095,
			"recovery": 0.25,
			"offset": [
				0.88,
				0.9
			],
			"size": [
				1.8,
				1.18
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"nova_uppercut": {
			"kind": "rise",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.14,
			"active": 0.09,
			"recovery": 0.27,
			"offset": [
				0.42,
				1.4
			],
			"size": [
				1.4,
				1.8
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"nova_slam": {
			"kind": "slam",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.2,
			"active": 0.095,
			"recovery": 0.28,
			"offset": [
				0.65,
				0.45
			],
			"size": [
				1.8,
				1.4
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"kuren_light": {
			"kind": "light",
			"weapon": "",
			"delivery": "melee",
			"breaker": false,
			"startup": 0.042,
			"active": 0.065,
			"recovery": 0.135,
			"offset": [
				0.75,
				0.88
			],
			"size": [
				1.25,
				0.92
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"kuren_heavy": {
			"kind": "heavy",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.145,
			"active": 0.085,
			"recovery": 0.23,
			"offset": [
				0.95,
				0.8
			],
			"size": [
				1.5,
				1.1
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"kuren_uppercut": {
			"kind": "rise",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.115,
			"active": 0.09,
			"recovery": 0.25,
			"offset": [
				0.4,
				1.42
			],
			"size": [
				1.2,
				1.75
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"kuren_slam": {
			"kind": "slam",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.16,
			"active": 0.085,
			"recovery": 0.24,
			"offset": [
				0.75,
				0.45
			],
			"size": [
				1.65,
				1.25
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"terra_light": {
			"kind": "light",
			"weapon": "",
			"delivery": "melee",
			"breaker": false,
			"startup": 0.085,
			"active": 0.09,
			"recovery": 0.22,
			"offset": [
				1.0,
				0.9
			],
			"size": [
				1.8,
				1.0
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"terra_clinch": {
			"kind": "heavy",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.235,
			"active": 0.11,
			"recovery": 0.34,
			"offset": [
				0.8,
				0.9
			],
			"size": [
				1.4,
				1.45
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"terra_uppercut": {
			"kind": "rise",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.22,
			"active": 0.11,
			"recovery": 0.34,
			"offset": [
				0.6,
				1.4
			],
			"size": [
				1.8,
				2.1
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"terra_slam": {
			"kind": "slam",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.255,
			"active": 0.12,
			"recovery": 0.35,
			"offset": [
				0.65,
				0.4
			],
			"size": [
				2.45,
				1.45
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"momo_light": {
			"kind": "light",
			"weapon": "",
			"delivery": "melee",
			"breaker": false,
			"startup": 0.06,
			"active": 0.075,
			"recovery": 0.18,
			"offset": [
				1.02,
				0.82
			],
			"size": [
				1.9,
				0.72
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"momo_snare": {
			"kind": "heavy",
			"weapon": "",
			"delivery": "snare",
			"breaker": true,
			"startup": 0.17,
			"active": 0.095,
			"recovery": 0.28,
			"offset": [
				1.05,
				0.65
			],
			"size": [
				1.8,
				1.05
			],
			"radius": [
				0.55,
				0.48
			]
		},
		"momo_uppercut": {
			"kind": "rise",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.14,
			"active": 0.1,
			"recovery": 0.27,
			"offset": [
				0.5,
				1.3
			],
			"size": [
				1.6,
				1.7
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"momo_slam": {
			"kind": "slam",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.185,
			"active": 0.1,
			"recovery": 0.29,
			"offset": [
				0.85,
				0.4
			],
			"size": [
				2.0,
				1.3
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"shadow_light": {
			"kind": "light",
			"weapon": "",
			"delivery": "melee",
			"breaker": false,
			"startup": 0.045,
			"active": 0.075,
			"recovery": 0.155,
			"offset": [
				0.87,
				0.79
			],
			"size": [
				1.5,
				0.85
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"shadow_heavy": {
			"kind": "heavy",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.19,
			"active": 0.09,
			"recovery": 0.27,
			"offset": [
				1.2,
				0.72
			],
			"size": [
				1.7,
				1.15
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"shadow_uppercut": {
			"kind": "rise",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.14,
			"active": 0.1,
			"recovery": 0.29,
			"offset": [
				0.54,
				1.39
			],
			"size": [
				1.28,
				1.95
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"shadow_slam": {
			"kind": "slam",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.205,
			"active": 0.1,
			"recovery": 0.27,
			"offset": [
				0.91,
				0.4
			],
			"size": [
				1.8,
				1.22
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"lumi_light": {
			"kind": "light",
			"weapon": "",
			"delivery": "melee",
			"breaker": false,
			"startup": 0.07,
			"active": 0.085,
			"recovery": 0.2,
			"offset": [
				1.08,
				0.92
			],
			"size": [
				1.92,
				0.85
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"lumi_heavy": {
			"kind": "heavy",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.225,
			"active": 0.12,
			"recovery": 0.3,
			"offset": [
				1.47,
				0.89
			],
			"size": [
				2.32,
				1.28
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"lumi_uppercut": {
			"kind": "rise",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.185,
			"active": 0.11,
			"recovery": 0.29,
			"offset": [
				0.62,
				1.45
			],
			"size": [
				1.83,
				2.02
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"lumi_slam": {
			"kind": "slam",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.24,
			"active": 0.12,
			"recovery": 0.31,
			"offset": [
				0.93,
				0.39
			],
			"size": [
				2.23,
				1.25
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"kai_light": {
			"kind": "light",
			"weapon": "",
			"delivery": "melee",
			"breaker": false,
			"startup": 0.065,
			"active": 0.07,
			"recovery": 0.18,
			"offset": [
				0.96,
				0.91
			],
			"size": [
				1.6,
				0.8
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"kai_heavy": {
			"kind": "heavy",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.24,
			"active": 0.09,
			"recovery": 0.36,
			"offset": [
				1.37,
				0.86
			],
			"size": [
				1.98,
				1.0
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"kai_uppercut": {
			"kind": "rise",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.2,
			"active": 0.09,
			"recovery": 0.35,
			"offset": [
				0.58,
				1.45
			],
			"size": [
				1.48,
				2.11
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"kai_slam": {
			"kind": "slam",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.265,
			"active": 0.095,
			"recovery": 0.34,
			"offset": [
				1.13,
				0.42
			],
			"size": [
				2.08,
				1.25
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"zero_light": {
			"kind": "light",
			"weapon": "",
			"delivery": "melee",
			"breaker": false,
			"startup": 0.055,
			"active": 0.08,
			"recovery": 0.17,
			"offset": [
				0.94,
				0.89
			],
			"size": [
				1.62,
				0.88
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"zero_heavy": {
			"kind": "heavy",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.18,
			"active": 0.1,
			"recovery": 0.27,
			"offset": [
				1.19,
				0.82
			],
			"size": [
				1.8,
				1.2
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"zero_uppercut": {
			"kind": "rise",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.16,
			"active": 0.095,
			"recovery": 0.29,
			"offset": [
				0.58,
				1.4
			],
			"size": [
				1.51,
				1.92
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"zero_slam": {
			"kind": "slam",
			"weapon": "",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.205,
			"active": 0.11,
			"recovery": 0.29,
			"offset": [
				0.97,
				0.4
			],
			"size": [
				1.97,
				1.24
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"zero_scope": {
			"kind": "heavy",
			"weapon": "",
			"delivery": "rail",
			"breaker": true,
			"startup": 0.24,
			"active": 0.06,
			"recovery": 0.32,
			"offset": [
				1.45,
				0.93
			],
			"size": [
				1.5,
				0.75
			],
			"radius": [
				0.3,
				0.2
			]
		},
		"zero_sync": {
			"kind": "heavy",
			"weapon": "",
			"delivery": "repair",
			"breaker": true,
			"startup": 0.22,
			"active": 0.12,
			"recovery": 0.31,
			"offset": [
				0.89,
				0.92
			],
			"size": [
				2.35,
				1.5
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"arc_sweep": {
			"kind": "special",
			"weapon": "arc_blade",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.13,
			"active": 0.17,
			"recovery": 0.29,
			"offset": [
				1.4,
				1.0
			],
			"size": [
				2.8,
				1.45
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"burst_rush": {
			"kind": "special",
			"weapon": "burst_knuckle",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.1,
			"active": 0.2,
			"recovery": 0.33,
			"offset": [
				1.05,
				0.85
			],
			"size": [
				1.9,
				1.35
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"pile_shot": {
			"kind": "special",
			"weapon": "pile_cannon",
			"delivery": "cannon",
			"breaker": true,
			"startup": 0.32,
			"active": 0.06,
			"recovery": 0.45,
			"offset": [
				1.5,
				1.0
			],
			"size": [
				1.5,
				0.95
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"halo_pulse": {
			"kind": "special",
			"weapon": "halo_caster",
			"delivery": "repair",
			"breaker": false,
			"startup": 0.2,
			"active": 0.1,
			"recovery": 0.26,
			"offset": [
				1.1,
				0.9
			],
			"size": [
				2.1,
				1.3
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"phase_cut": {
			"kind": "special",
			"weapon": "phase_talon",
			"delivery": "blink",
			"breaker": true,
			"startup": 0.23,
			"active": 0.09,
			"recovery": 0.31,
			"offset": [
				0.85,
				0.82
			],
			"size": [
				1.5,
				1.32
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"prism_zone": {
			"kind": "special",
			"weapon": "prism_emitter",
			"delivery": "field",
			"breaker": true,
			"startup": 0.24,
			"active": 0.08,
			"recovery": 0.34,
			"offset": [
				1.05,
				0.95
			],
			"size": [
				1.7,
				1.7
			],
			"radius": [
				0.88,
				0.83
			]
		},
		"rail_shot": {
			"kind": "special",
			"weapon": "rail_lance",
			"delivery": "rail",
			"breaker": true,
			"startup": 0.62,
			"active": 0.065,
			"recovery": 0.52,
			"offset": [
				1.65,
				0.98
			],
			"size": [
				1.7,
				0.75
			],
			"radius": [
				0.38,
				0.17
			]
		},
		"drive_strike": {
			"kind": "special",
			"weapon": "switch_driver",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.16,
			"active": 0.17,
			"recovery": 0.28,
			"offset": [
				1.19,
				0.85
			],
			"size": [
				2.08,
				1.28
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"drive_lift": {
			"kind": "rise",
			"weapon": "switch_driver",
			"delivery": "melee",
			"breaker": true,
			"startup": 0.18,
			"active": 0.12,
			"recovery": 0.31,
			"offset": [
				0.63,
				1.47
			],
			"size": [
				1.83,
				2.3
			],
			"radius": [
				0.48,
				0.34
			]
		},
		"drive_guard": {
			"kind": "slam",
			"weapon": "switch_driver",
			"delivery": "field",
			"breaker": true,
			"startup": 0.23,
			"active": 0.1,
			"recovery": 0.32,
			"offset": [
				0.85,
				0.4
			],
			"size": [
				2.0,
				1.45
			],
			"radius": [
				0.81,
				0.65
			]
		}
	}
};
