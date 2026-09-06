# Runtime architecture — 0.1.0

Godot 4.7.2 Standard, typed GDScript, Forward+/Metal on the tested Mac. Combat is an authoritative 2D simulation presented with actual 3D meshes under an orthographic camera. Animation does not decide whether an attack hits.

## Frame and coordinate flow

`PlayerInputRouter` owns one keyboard/device ID or bot source per slot. It produces `FighterCommand` objects. `BotBrain` produces the same command format, with difficulty-dependent delays and no damage multiplier.

At 120 Hz, `MatchSession` advances the stage, reads commands, steps all four `Fighter` controllers, snapshots eligible melee/projectile contacts, resolves them, resolves salvage transactions, then advances equipment lifecycle and match scoring. Snapshotting contacts before damage allows intended simultaneous trades. An attack instance remembers its victims; swept projectile rectangles prevent fast shots skipping targets. Gravity, acceleration, coyote/buffer windows, dodge limits, hitstop and attack timing live in simulation/data.

A hundred simulation units equal one presentation unit: `(x, y)` becomes `(x / 100, -y / 100, 0)`. `SimStage.PLATFORMS` supplies both collision anchors and 3D deck dimensions. The moving ferry advances from the same simulation clock. `MechView` interpolates the previous/current positions, animates named rig pivots and mirrors the facing direction. `BattleCamera` frames living fighters and bounds its movement, zoom and shake.

## Data and ownership

`characters/*.tres` define four `MechData` chassis with independent movement and basic attacks. `modules/*.tres` define four weapon arms and four shells. `AttackData` contains startup, active/recovery windows, hit rectangle, Core damage, component strain, launch, stun and breaker behavior. Global component strain scale is 0.18 in this release; the resource's unscaled number is the authored strain budget.

`EquipmentStore` owns a registry of `PartInstance` identities. An instance is equipped, loose, claimed or retired; the slot and loose body reference the same identity. Breaking removes it from the fighter before creating its physical salvage body. Claims are collected before resolution; equal-distance ties rotate priority. An interrupted claim releases the reservation. Commit removes the loose body, optionally drops the previous part, and changes the host's actual Special. A truly broken part receives one 50% fresh coupler; swapping does not repeatedly heal it.

There are at most eight loose parts and four fighters with two equipped slots each. Loose parts expire, receive at most one offstage recall, and are retired from the registry. Core Pops drop the weapon and retire the shell; a reboot creates the native kit. Momo's repair budget is finite. No arbitrary inventory copying or unlimited rebuild healing exists.

## Presentation and lifecycle

Blender source exports named pivots and sockets in GLB: Head, Torso/Core, Hips, LeftArm, LeftLeg, RightLeg, WeaponSocket and ShellSocket. `RigFactory` caches scenes/materials and applies toon shading and inverted-hull outlines. Weapon size is preserved across hosts, making Terra's cannon visibly oversized on Momo. `MechView` drives anticipation, swing/recovery, running, dodge, landing, expression, damage and attachment poses.

`BattleView` owns part/projectile visuals and capped bursts, arcs, rings and callouts. `BattleHUD` exposes the actual Core and component state, scores and nearby salvage prompt. `SoundDirector` uses 24 prioritized effect voices, spacing limits, separate buses, a master limiter, music ducking and optional gamepad rumble. Headless tests do not start audio playback.

`app.gd` coordinates title, selection, intro, battle, pause, results and settings. `FrontEnd` owns menu presentation. Returning to the hangar frees the previous simulation, view and HUD. Settings use Godot's local `user://settings.cfg`; no credentials or network services are used at runtime.

The simulation is not advertised as cross-platform deterministic. There is no networking, rollback or portable replay protocol in this slice.
