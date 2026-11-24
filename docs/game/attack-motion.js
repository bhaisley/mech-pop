/* Each row describes the loaded stance, contact silhouette and follow-through.
   Aim is an angle above screen-forward. The simulation supplies all timing. */
(() => {
  'use strict';
  const profiles = {
    cut: {aim: [85, 5, -48], shoulder: [-.75, -1.28, -.45], turn: [-.44, .51, .75], lean: [.08, -.10, -.08]},
    backcut: {aim: [-56, 9, 68], shoulder: [.20, -1.04, -1.46], turn: [-.62, .43, .70], lean: [.07, -.11, -.02]},
    jab: {aim: [26, 0, -6], shoulder: [.32, -1.56, -1.18], turn: [-.54, .50, .58], lean: [.08, -.12, -.08]},
    sweep: {aim: [148, 12, -58], shoulder: [-1.72, -1.38, -.46], turn: [-.95, .67, .92], lean: [.19, -.26, -.23]},
    drive: {aim: [52, 1, -19], shoulder: [.62, -1.67, -1.31], turn: [-.85, .75, .88], lean: [.20, -.29, -.20]},
    uppercut: {aim: [-66, 49, 109], shoulder: [.50, -1.64, -2.42], turn: [-.83, .48, .71], lean: [-.15, .09, .17]},
    slam: {aim: [132, -40, -80], shoulder: [-2.56, -1.25, -.37], turn: [-.50, .68, .93], lean: [.22, -.31, -.35]},
    clinch: {aim: [48, 3, 57], shoulder: [-.15, -1.72, -1.96], turn: [-.41, .36, .52], lean: [.14, -.29, .14]},
    rush: {aim: [31, 0, -4], shoulder: [.70, -1.82, -1.54], turn: [-.99, .88, .94], lean: [.22, -.38, -.29]},
    phase: {aim: [-85, 24, 82], shoulder: [.48, -1.64, -2.08], turn: [-.99, .74, 1.02], lean: [-.18, -.31, -.15]},
    fire: {aim: [0, 17, 4], shoulder: [-1.19, -.54, -.94], turn: [.26, -.29, .12], lean: [-.11, .32, .08]},
    cast: {aim: [69, 5, 21], shoulder: [-.79, -1.61, -1.25], turn: [-.58, .48, .63], lean: [.12, -.18, -.06]},
    toss: {aim: [142, 30, -12], shoulder: [-2.01, -1.49, -.75], turn: [-.70, .53, .79], lean: [.17, -.25, -.16]},
    guard: {aim: [94, -34, -53], shoulder: [-1.61, -1.27, -.94], turn: [-.34, .33, .46], lean: [.14, -.17, -.16]}
  };
  const saturate = n => Math.max(0, Math.min(1, n));
  const smooth = n => {
    const t = saturate(n);
    return t * t * (3 - 2 * t);
  };

  function style(id, definition, weapon, serial) {
    if (definition.delivery === 'rail' || definition.delivery === 'cannon')
      return 'fire';
    if (definition.delivery === 'snare')
      return 'toss';
    if (definition.delivery === 'repair' || definition.delivery === 'field')
      return id === 'drive_guard' ? 'guard' : 'cast';
    if (definition.delivery === 'blink')
      return 'phase';
    if (definition.kind === 'rise')
      return 'uppercut';
    if (definition.kind === 'slam')
      return 'slam';
    if (id === 'terra_clinch')
      return 'clinch';
    if (id === 'burst_rush' || id === 'drive_strike')
      return 'rush';
    const blade = weapon === 'arc_blade' || weapon === 'phase_talon';
    if (definition.kind === 'light')
      return blade ? (serial % 2 ? 'cut' : 'backcut') : 'jab';
    return blade ? 'sweep' : 'drive';
  }

  function sample(fighter) {
    const definition = MechCatalog.moves[fighter.moveId];
    if (!definition)
      return null;
    const {startup, active, recovery} = definition;
    const age = fighter.attack * (startup + active + recovery);
    const id = style(fighter.moveId, definition, fighter.weapon[0], fighter.serial);
    const windup = saturate(age / startup), activeTime = saturate((age - startup) / active);
    const recoveryTime = saturate((age - startup - active) / recovery);
    // Contact can freeze on the first active tick. Melee must already reach its
    // target on that tick. A gun stays braced until its projectile actually fires.
    const release = id === 'fire' ? smooth((age - startup) / .025) : smooth((windup - .74) / .26);
    const settle = 1 - smooth((recoveryTime - .16) / .84);
    const follow = smooth((activeTime - .20) / .80);
    const wind = (.14 + .86 * smooth(windup / .64)) * (1 - release);
    const strike = release * (1 - follow) * settle, finish = release * follow * settle;
    return {
      id,
      profile: profiles[id],
      definition,
      age,
      windup,
      activeTime,
      recoveryTime,
      charging: age < startup,
      wind,
      strike,
      finish,
      weight: wind + strike + finish
    };
  }

  function channel(values, motion) {
    return values[0] * motion.wind + values[1] * motion.strike + values[2] * motion.finish;
  }
  window.MechAttacks = {sample, style, channel};
})();
