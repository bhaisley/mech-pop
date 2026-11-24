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
		}
	}
};
