# Release validation

The **native 0.2.0 preview, build 16**, shipped with eight fighters, sixteen interchangeable equipment parts and five arenas. Its release tag preserves that native build’s source. The complete private development record also retains failed investigations and raw device diagnostics.

## Cannon Duel browser release 0.3.0

- Chrome completed the practice duel using the one-handed layout, rebound keys, simulated Gamepad API input and touch events in a phone-sized viewport. Each run broke Terra’s cannon, displayed the named pickup, stole it, missed a shot, waited for the ready cue, then landed the shot. Replay and return to four-player Pop Rush also passed.
- A four-player browser round showed a one-point loss on an uncredited fall and a shared damage tie. Replaying a credited ring-out, an exposed-core KO and a nonzero damage tiebreak checked the corresponding score messages and results.
- Two browser clients played a private-room match over loopback. Both received the same scores, damage totals and winner, then launched a rematch.
- Godot passed 11 duel checks, 62 network-state checks, 89 combat-system checks and 112 arena checks. Eight three-minute bot matches completed across the eight arenas.
- The first-time playtest is open. Give five new players the hangar without coaching. Ask each to take Terra’s cannon and hit him with it, then explain who scored the last point after a Pop Rush round. Record the device, where each player hesitated and whether they did both unaided. The target is four of five, with one-handed WASD and a physical controller represented.

## Native build 16 checks

| Check | Result |
| --- | --- |
| Controller setup and input selection | 68 generated-event checks pass |
| Touch, keyboard and controller routing | 20 generated-input checks pass |
| Front-end lifecycle | 19 checks pass |
| Combat, equipment and input systems | 89 checks pass |
| Network state | 56 checks pass |
| Native four-client Internet-room service | Four matching clients; version, capacity, expiry and clean disconnect checks pass |
| macOS packaging | Executable/PCK hashes, archive integrity and extracted deep/strict signature verification pass |
| iPad build | Development-signed, installed and successfully launched |
| Physical Mac selector test | User confirms P1 fights as a bot while Controller 1 operates P2 |
| Physical iPad selector test | User confirms switching among Touch, Bot and Xbox controller inputs |

## Three.js browser edition

Chrome played a full three-minute match and a rematch through the hangar. The full round recorded eight armor breaks, 23 equipment attachments and 26 Core Pops. Each of the five arenas launched with its moving platform, and all eight models appeared in the selector. The equipment check covered all 648 combinations of eight chassis, nine arm states and nine shell states, including empty sockets.

Phone-sized Chrome viewports covered portrait and landscape layouts, touch movement and action buttons. Simulated Gamepad API input covered movement, attacks, pause and resume. Physical mobile browser and controller testing remains open.

Two browser clients created and joined a private room through the build 16 native authority on loopback. They selected a mech and arena, readied, finished a shortened round with matching final state digests and launched a rematch.

## Earlier native and hardware coverage

- Build 10 completed full Mac–iPad LAN matches and rematches in both host directions with matching final state and scores.
- A capture-free 1,900-second iPad content rotation covered all eight fighters and five arenas. It reported no script or equipment-ownership errors, with a minimum one-second ordinary-fight rate of 59.20 fps.
- The user confirmed Xbox menu/join, movement, combat actions, salvage and pause/resume on iPad build 13, then subsequent controller setup improvements.
- Build 14 completed two native three-minute Internet rounds/rematch across separate connections. Final acknowledgements matched; p95 RTT was 317 ms on Mac and 284 ms on iPad. This used generated input and a temporary endpoint, which was stopped afterward.

These results identify their tested builds. Automated input and recorded images are not claims of hands-on controls, and recording a video is not a performance measurement.

## Open checks and limits

- Broader physical touch combat, multiple controllers on one device, and background/reconnection behavior.
- Detailed Mac controller action coverage and an earlier macOS controller-opening diagnostic. A sampled controller wait while the Mac was later found locked does not establish a persistent post-unlock freeze.
- Human listening to each new music loop and repeated loop transitions. The user has reported clear music and combat sound during iPad gameplay.
- Human-rated Internet responsiveness/recovery and a persistent hosted service.
- An earlier native LAN client hang remains unexplained despite later passing rotations and real Mac–iPad rounds.
- Linux and Windows exports have not been hardware-validated. The provided Mac download is ad-hoc signed and not notarized; iPad signing is device/team-specific.

Please report the game build, device/controller, arena and steps that reproduce an issue. Avoid including account credentials, signing profiles, private network addresses or device identifiers in a public report.
