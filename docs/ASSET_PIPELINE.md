# Asset-generation bible and production pipeline

This is the specification to establish consistency before generating production assets. No new character art or models have been generated in Phase 0.

## Common sheet contract

Create one controlled construction sheet per playable chassis: orthographic front and side at matching scale, rear three-quarter view, flat palette, exploded head/core/arms/legs/weapon/shell layout, expression strip and intact/cracked/missing-slot states. Show detached parts with the same connector and silhouette as their equipped versions. Keep reference lighting neutral so paint and shadow are separable.

Start with Nova to lock common scale and construction language, then produce Terra and the cannon to test extremes, then Momo and Kuren. Review each before more variants. Image generation is appropriate for development sheets and key art; it is not the source of independent animation frames, exact geometry, UI labels or socket transforms.

Use the available image-generation capability with the supplied reference and an approved preceding sheet. Request GPT Image 2 where the available tool actually exposes that model; record the returned model/provenance accurately rather than assuming a model from the request. If views disagree, resolve the construction in Blender and use its turntable renders as the next reference. Do not multiply inconsistent generations.

## Character construction specifications

Heights below are relative game scene units, not a claim about canonical real-world scale.

| Specification | Nova | Kuren | Terra | Momo |
| --- | --- | --- | --- | --- |
| Height / head share | 1.80 / ~40% | 1.72 / ~39% | 2.10 / ~35% | 1.62 / ~42% |
| Permanent landmarks | Swept crescent fins, pointed boots, narrow waist | Offset vent crest, forward chest, heel jets | Broad shoulders, square jaw plate, planted feet | Split antennae, round cheeks, petal boots |
| Front view | Clean white central face, cyan slanted eyes, blue outer fins | Red cheeks, narrow luminous eyes, dark recessed vents | Heavy olive collar, lime inset eye visor, reinforced knees | Large pink/blue eye screens, white center face, symmetrical cheek pods |
| Side view | Swept back head/heel lines, compact backpack | Forward lean, hot rear vents, spring-like ankle stance | Deep chest, flat back armor, wide foot contact | Rounded head, small torso, clear hover nozzle below backpack |
| Rear / three-quarter | Paired fin roots and cool vents | Heat sink channels and small exhaust cluster | Broad mechanical hatch and two exposed piston guards | Circular service hatch, petal stabilizers and small halo emitter |
| Head | One crest family; no borrowed mecha insignia | Angular brow plus asymmetrical vent motif | Recessed jaw/visor, compact antenna | Rounded cheeks plus two soft-edged antenna prongs |
| Torso / Core | Diamond core behind removable fin chest plate | Furnace diamond behind vent plate | Large central core behind bulwark plate | Small bright diamond behind halo plate |
| Permanent off-hand / legs | Left wrist edge and compact athletic legs | Left punch tool, knee guards and burst heels | Left grabbing hand, reinforced pistons and wide feet | Left tether emitter, small hovering boots |
| Right detachable arm | Arc Blade forearm, long cyan cutting edge | Burst Knuckle forearm, vented striking block | Pile Cannon forearm, oversized barrel and recoil sleeve | Halo Caster forearm, rounded bell with drone launch ring |
| Shell | Swept fin breastplate | Vented breastplate | Broad bulwark chest plate | Rounded halo chest plate |
| Expression / personality | Focused eyes, precise nod, satisfied blade flourish | Impatient foot bounce, angry vents, defiant fist pump | Deliberate head turn, shoulder settle, tiny proud nod | Cheerful eyes, quick surprised glance, confident wink |
| Cracked / missing | Cyan fissure and exposed dark socket | Orange flicker and smoking coupling | Lime fracture and broad sparking connector | Pink broken ring and tiny exposed service socket |

All sheets include the full detached forearm, not just the projectile barrel. The missing state shows the stump connector. The shell off-state exposes an unmistakable core behind a remaining structural frame. Art cannot change collider size implicitly.

## Blender to Godot

Use repeatable Blender Python scripts for base meshes, naming, material assignment, socket checks, batch turntable renders and exports. Save curated `.blend` sources so hand refinements remain editable; never overwrite manual refinement by blindly rerunning a generator. Separate procedural construction, final authored source and exported runtime assets.

Rigid mechanical rigs use a shared bone/socket naming convention, with chassis-specific proportions and poses. Arms and shells are independent mesh objects. Attach donor assemblies through named `weapon_arm` and `shell` sockets with per-chassis adapters and additive grip/stance poses. Keep donor meshes at intentional size; do not solve every collision by arbitrary scaling.

Export explicit glTF 2.0 `.glb` files with baked animation clips and material IDs. Author final toon materials in Godot, rather than expecting Blender shaders to transfer. Export weapons and shells as separate scenes; keep shared rig base and character-specific animation libraries separate. Test names, transforms, normals, units and clip durations on re-import.

Minimum animation inventory: idle/run/stop/turn, jump/rise/fall/land, dodge/boost, light chain, heavy variants, module attack, hit reactions, POP surprise, attach, Core warning, defeat, drop-in and victory. Share base transitions but preserve character timing and poses. Weapon attacks use chassis stance overlays so the cannon's recoil looks different on Terra and Momo.

## Organization after approval

```text
art_source/characters/      approved sheets and editable Blender sources
art_source/stage/           Sky Port source geometry and layer artwork
assets/characters/         exported rigs, parts, textures and portraits
audio/sfx/                 production effects and variant families
audio/music/               selected master, game loop and stings
characters/                chassis scenes and typed data resources
stages/                    collision/path data and stage presentation scenes
ui/                        menus, HUD, fonts and branding
vfx/                       reusable feedback scenes and materials
scripts/                   input, simulation, combat, equipment, bots, match
tools/                     repeatable build/export/audio/validation tools
docs/reference/            original brief and supplied concept image
work/                      ignored experiments and intermediate renders
```

Asset records contain source path, version/hash, author or generator, prompt/workflow and seed when available, edits, export tool/version, intended use, license/terms and approval state. Promote selected candidates into production deliberately. Runtime builds include only referenced production content and required notices, not entire reference/experiment folders.
