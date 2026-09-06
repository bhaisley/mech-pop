# Combat system

> Design reference. See the [project README](../README.md) for the features and platforms available in the current preview.


All values below are untested starting points, expressed in real time and converted once to 120 Hz ticks.

## Input and movement

Target immediate acceleration, variable jump height, double jump, one directional air boost, fast fall and down+jump through one-way platforms. No ledge-grab state in the first slice; double jump and boost supply recovery. Native recovery never depends on an equipped part.

Begin with an 80 ms input buffer and 80 ms coyote window. Nova's initial top speed is approximately 7.8 scene units/s, with a full first jump around 3.8 units. Tune the other chassis against reach, landing control and recovery safety, not just top speed. Movement starts on the accepted input tick; anticipation belongs to attacks and visible poses.

Light, heavy and special must be distinct. Lights establish pressure and strain parts. Directional heavies risk a readable wind-up to break parts or launch opponents. Special uses the attached weapon. Dodge grants a brief invulnerable interval followed by recovery; it cannot be chained without its cooldown. Terra's heavy clinch provides the slice's command grab, so a separate universal grab button is unnecessary.

Give each chassis a small authored set: a light chain, up/forward/down heavy variants, aerial use of selected moves, its defense and one native weapon special. Reuse poses where they read well; do not multiply attacks solely to fill a move list. Define grounded/airborne availability and cancels explicitly.

## Mechanical integrity

Initial resources: **Core 100, weapon coupler 40, shell 60.** Core is a health bar, not a launch percentage. Knockback is determined by the attack, direction, chassis mass and limited equipment modifiers.

- Strikes damage one component selected by authored contact zones and attack targeting tags. Forward/up breaker attacks favor the arm; downward breaker attacks favor the shell. Expand target zones enough that exact pixel-level limb aiming is unnecessary. Missing targets redirect to the shell, then the exposed core.
- At 25% component integrity, the part visibly cracks and its HUD segment pulses. Light damage can reduce integrity to zero without detachment. A breaker-tagged heavy that leaves integrity at zero causes POP, including when that heavy crosses zero itself.
- Initial component damage: roughly 8 for a light hit, 18 for a heavy. Multi-hit moves have per-target budgets so a single overlap cannot shred every part.
- Hits also deal their authored Core damage. With a shell, only 20% passes through and Core cannot fall below 1. With the shell missing, full damage applies and CORE EXPOSED appears on the body/HUD. Losing the weapon additionally increases exposed Core damage by a modest 15%.
- Core damage starts around 6–10 for light hits and 18–24 for heavy hits. At zero, CORE POP triggers once. Shell replacement covers the core again but does not heal it. A missing arm never disables basic defense or recovery.

These numbers must produce a first visible part break within roughly 15–30 seconds of ordinary engaged play, without a rigged first-hit rule. If shell protection encourages endless defensive repair, lower its protection or repair budget before adding more meters.

**Foundation tuning:** `MatchSession.component_wear_scale = 0.18` multiplies each attack's authored component strain while Core damage remains unchanged. Unscaled strain caused ordinary four-bot breaks in about two seconds and unreadable churn. The revised Arcade sample produced its first break at 14.94 seconds. Keep this explicit match tuning separate from move timings and do not silently rescale the HUD's 40/60 condition meters.

## Hit resolution and fairness

Use authored 2D shapes independent of render meshes. Sweep fast attacks/projectiles between ticks. Collect eligible contacts before resolving outcomes so simultaneous attacks can trade. Deduplicate by attack instance, target and permitted repeat interval. Resolve target selection, damage, break, knockback and elimination as a single ordered combat transaction.

Make hitstun finite and provide a short re-hit safeguard after exhausting a combo budget; tune the exact rule against all four kits. Use grounded/air recovery and limited directional influence to create decisions after launch. Do not introduce hidden bot damage buffs or unavoidable wake-up attacks.

## Impact vocabulary

| Event | Initial feedback target |
| --- | --- |
| Light | 30–50 ms participant hitstop; narrow white contact flash; sharp metal/electric transient |
| Heavy | 65–100 ms participant hitstop; broader directional sparks; squash/recoil; low-frequency layer |
| Component POP | 90–130 ms participant emphasis; actual part separates; yellow salvage cue; iconic metallic snap/pop |
| CORE POP | Brief magenta/ink impact graphic, expanding mechanical confetti and a distinctive audio cadence |

Continue buffering input during hitstop. Keep the other combatants active. Avoid repeatedly freezing the entire match; reserve an optional shared emphasis of at most about 80 ms for a decisive finish when framing remains fair. The shared camera cannot provide truly isolated shake, so most impact motion belongs to the affected rigs and effects; camera shake is small and capped.

Track active fighter bounds with a damped camera dead zone, faster zoom-out and slower zoom-in. Cap zoom to keep bodies readable, use edge arrows for recovery excursions, and never follow decorative debris. CORE POP does not crop surviving opponents to show a cinematic. Intro/results may use more expressive camera moves. Supply reduced shake, reduced flashes and adjustable rumble.
