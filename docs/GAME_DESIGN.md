# Game design

> Design reference. See the [project README](../README.md) for the features and platforms available in the current preview.


Proposed rules and initial tuning; playtests may change values.

## Four chassis, four personalities

| Mech | Body language / movement | Chassis kit retained after part loss | Native detachable weapon |
| --- | --- | --- | --- |
| NOVA — balanced | White/blue crescent silhouette; crisp acceleration and controlled air dash | Short left-wrist energy edge, precise kicks, directional launcher; clean spacing | **Arc Blade:** right-arm energy sweep with a committed advancing finish |
| KUREN — rushdown | Red forward-leaning wedges; fast ground bursts, shorter reach | Left-fist/knee pressure, an on-hit dash cancel with a recovery cost, chasing uppercut | **Burst Knuckle:** explosive forearm rush; generates heat and must cool between bursts |
| TERRA — grappler | Olive fortress shoulders; slow acceleration, stable landings | Left-arm clinch/slam heavy at close range, broad punches, brief armored wind-up; throws beat armor | **Pile Cannon:** huge right forearm cannon, slow telegraph, forceful launch and mass-scaled recoil |
| MOMO — technical | Pink rounded armor and split antennae; floatier fall and controllable hover | Left-hand tether tap, short-lived snare puck heavy, directional defensive hop | **Halo Caster:** right-arm emitter launches a repair drone; a capped pulse repairs slot integrity only |

Nova's descriptor: “Precision in every strike.” Kuren: “Never stop moving.” Terra: “Hit once. Hit hard.” Momo: “Cute is a combat strategy.”

The detachable weapon determines the special button. Chassis movement, light/heavy actions and a character-specific defensive feel stay recognizable when the weapon changes. Native arm loss reveals a connector stump and removes that arm's full weapon action. Basic animations explicitly use permanent limbs; no invisible missing-arm punches.

Momo's repair cannot revive lost components, heal the core or remove pressure instantly. Her traps and hover remain useful with a stolen cannon. Kuren's speed carries Terra's weapon into close-range danger, while the cannon's startup still matters. Terra carrying the Halo Caster becomes hard to dislodge but gives up his cannon pressure.

## Match format: POP RUSH

Default: four-player free-for-all, 180 seconds, any mix of humans and bots. Score +1 for an opponent's CORE POP, −1 for an uncredited self-KO. No points for swapping or merely breaking parts. Ties use total enemy Core damage; an exact tie produces shared winners. Assists appear in results without adding a second scoring system.

Falling beyond the recovery boundary also causes a CORE POP. Credit the last opponent to land a valid hit within five seconds; otherwise it is a self-KO. Respawn takes about two seconds, restores the native chassis loadout and includes a short invulnerability window that ends on attack or salvage. Choose a spawn with low immediate threat. Everyone stays in the match until time expires.

The last 30 seconds change music and visual urgency, not the scoring rules. This avoids downtime, teaches the hook through repeated encounters and keeps the investor walkthrough predictable. Stock modes can follow after the slice.

## Sky Port

Bright ivory transit platforms, cobalt sky, distant peach/lavender city haze, suspended rings, teal signs and cherry-pink planting. World spectacle moves behind the fight. Platform tops have clear light edges and dark undersides. The active combat backdrop is lower contrast than the mechs and effects.

Blockout coordinates below use scene units, with Y up; heights and recovery distances must be playtested together.

| Element | Position / dimensions | Purpose |
| --- | --- | --- |
| Main deck | X −11 to +11, Y 0 | Reliable brawling surface and salvage landing zone |
| Left ledge | X −10 to −4, Y 3.6 | Accessible jump route and short staging area |
| Right ledge | X +4 to +10, Y 3.6 | Symmetrical competitive route |
| Cargo ferry | Width 4, X moves −3 to +3, Y 6.2 | Slow, predictable upper route; one-way collision |
| Recovery space | Approx. X ±18, Y −7.5 to +13 | Time for meaningful offstage recoveries; final values follow movement tuning |

There are no lethal trains, collapsing floors or random hazards. A passing transport, cloud shadows, flags and small service drones make the port feel inhabited. The ferry can be disabled for testing; its visible position and collision share the same authoritative path.

## Session and HUD

Logo sting → Play → select/join → Sky Port splash → four capsule landings → READY? → POP! → match → victory pose and results → rematch. Default to one keyboard player as Nova and three bots across the other playable chassis. Changing a human roster choice updates the suggested bot variety without forbidding duplicate characters.

Character select shows eight names; four unavailable fighters are clearly marked Coming Soon. Selectable cards have portrait, role, personality and three relative stat bars. Human slots select independently; unclaimed slots default to bots with visible difficulty controls. Menus work entirely with a controller or keyboard.

The bottom HUD has four stable player panels: number/shape/color, portrait, score, Core bar, weapon icon and condition, shell icon and condition. A cracked icon communicates break readiness; an empty socket remains visibly empty. Timer sits above the stage. Keep full part names to pickup context and results. The results screen celebrates the winning hybrid loadout, plus parts stolen and Core Pops; debug information is absent.
