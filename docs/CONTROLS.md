# Controls and local players — 0.2.0 preview

| Action | Keyboard | Controller physical position |
| --- | --- | --- |
| Move / directional attack | WASD | Left stick or D-pad |
| Jump / double jump | Space | South: A / Cross |
| Light | J | West: X / Square |
| Breaker | K | North: Y / Triangle |
| Equipped weapon special | L | East: B / Circle |
| Dodge / air boost | Shift | Left shoulder: LB / L1 |
| Salvage / swap | E | Right shoulder: RB / R1 |
| Pause | Esc | Start / Options |

Tap jump for a short hop, hold for a taller jump. Down+jump drops through upper platforms. Up+breaker launches upward; down+breaker pressures shells. An empty weapon arm disables its Special while preserving the chassis's light, breaker, jump and dodge.

The HUD shows actual Core health, the current weapon and shell, their condition, and score. Yellow components are cracked. A nearby loose component produces a Salvage prompt for human players. A steal changes the host's visible part and its Special; donor identity is preserved. Core damage cannot finish a fighter until its shell is gone.

## Menus and joining

Enter or A/Cross activates a focused menu button. Tab / Shift+Tab and arrow keys navigate. In the local setup, the controller stick or D-pad moves between all four character cards, their Input buttons, Arena, Bots, Back and Launch. Down moves from a character to its Input button, then to the bottom options; Up reverses that path. Navigation highlights a field without changing it. A/Cross enters the field; left/right changes a character or difficulty, and A/Cross or B/Circle returns to navigation. In the arena list, choose a map with the stick/D-pad and A/Cross; B/Circle returns to setup. B/Circle from the setup overview returns to the title.

Start performs one action per press: **join → ready → launch**. For a solo controller focused on P1, the first Start takes the default keyboard/touch seat and leaves three bots. A later controller joins a free slot. Every joined controller player must be ready before launch. Changing that player's character or input assignment clears its ready state. Each pad retains its cursor and can edit its own character and bots, while another human's character is protected.

Each player's **Input** button opens a list of **Bot**, **Keyboard**, **Touch** on iPad, and connected **Controller 1**, **Controller 2**, etc. Use the stick/D-pad to browse, A/Cross to assign, and B/Circle or Escape to cancel; clicks and touch work too. Browsing keeps existing assignments intact. Assigning an input to another player makes its previous player a bot and clears held commands. Controller numbers identify connected controllers independently of player numbers. For example, P1 can be Bot while Controller 1 plays P2. A disconnected controller disappears from the list.

Keyboard A/D still cycles the keyboard player's character outside the input picker. Mouse/touch character arrows remain available. Watch mode makes every slot a bot. One keyboard and one touch player can coexist with controllers; no second shared-keyboard preset is included.

In network lobbies, each controller's left/right changes its assigned character. Down reaches common options; the room leader may change the arena and unclaimed bot characters. Start readies the local party, then lets the leader launch when parties are ready. Connect extra local controllers before hosting/joining to reserve their slots.

## Settings and recovery

Settings save in Godot's local `user://settings.cfg` (normally `~/Library/Application Support/Godot/app_userdata/MECH★POP/settings.cfg`). They include master/music/SFX/UI volumes, rumble, screen shake, a global radial stick dead zone, keyboard bindings and controller-model button profiles. The six action buttons are remappable; controller movement uses the left stick/D-pad. Prompts describe physical positions because controller letter labels differ by brand.

A remap is collected one action at a time and committed only when complete. Escape cancels without changing saved controls. Duplicate inputs are rejected. Start/Back/Guide and developer function keys are reserved. Restore Default Controls removes custom bindings and returns dead zone to 20%.

Offline focus loss clears held commands and pauses. In a network round it releases only the local party's input while the match continues. A lost controller pauses and identifies its player; Resume remains blocked until reconnection or explicit Bot Takeover. The dead numeric device ID is released while paused. Reconnect the matching model, or press Start on a replacement, then resume. Real multi-pad hotplug behavior still needs testing on physical devices; the tested routing/lifecycle scenarios use injected events.

## Developer tools

F1 toggles the hidden overlay. The following keys work only while it is enabled:

| Key | Action |
| --- | --- |
| F2 / F3 | POP P1's arm / shell |
| F4 | Drop P3's current arm near P1 for a pickup test |
| F5 | Force a P1 Core Pop credited to P2 |
| F6 | Toggle P1 between keyboard and bot |
| F7 | Toggle quarter-speed simulation |
| F8 | Advance one 120 Hz simulation step and freeze |
| F9 | Toggle P1 hit invulnerability |
| F10 | Cycle bot difficulty in the current match |
| F11 | Freeze / unfreeze simulation without a menu |

The overlay shows authoritative hit/hurt shapes, frame rate, tick, parts, projectiles, camera size and bot level. On Macs where the top row controls hardware functions, hold Fn/Globe with the function key. Debug setup captures must be labeled as such; the release's selected battle captures use ordinary four-bot gameplay.

## iPad touch preparation

The left thumb stick moves and aims directional breakers. Right-side buttons provide Jump, Light, Break, Special, Dodge and Salvage; the upper-right pause button works without a keyboard. Holding Jump and steering while attacking uses separate touch pointers. The four portrait cards remain at the bottom. Touch controls only the player explicitly assigned Touch, independently of keyboard and controllers. When no player uses Touch, the combat buttons hide while the pause button remains available. Touch has simulated pointer coverage; physical touch and controller recovery coverage is recorded separately in IPAD_SETUP.md.


## Local and remote parties

Play with Friends offers Local Wi-Fi and Internet rooms. Connect local controllers before hosting/joining to reserve the party together. The total remains four fighters, including bots; each party changes only its own character choices. Internet rooms require the same HTTPS server address and a six-character code. The first connected party leads the room. See [networking](NETWORKING.md) for readiness, reconnect reservations and current hardware/hosting checks.
