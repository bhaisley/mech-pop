/* Original MECH POP 0.2.0 ability cues. SuperCollider 3.14.1 / 48 kHz.
   Render: sclang -D audio/source/render_expansion_sfx.scd
   Deterministic synthesized sources; no recordings or sampled songs.
*/
(
var root = thisProcess.nowExecutingPath.dirname.dirname.dirname;
var output = root +/+ "audio/sfx";
var definitions, cues, renderCue;
var options = ServerOptions.new.numOutputBusChannels_(2).numInputBusChannels_(0).sampleRate_(48000);
Server.program = "/Applications/SuperCollider.app/Contents/Resources/scsynth";
File.mkdir(output);
definitions = [
    SynthDef(\phaseWarp, { |out=0|
        var seed = RandSeed.ir(1, 2041);
        var pitch = EnvGen.kr(Env([1800, 290, 1450], [0.045, 0.14], [-5, 2]));
        var env = EnvGen.kr(Env.perc(0.001, 0.38, 1, -6));
        var tone = SinOsc.ar(pitch + SinOsc.ar(83, 0, 130)) * 0.31;
        var air = BPF.ar(WhiteNoise.ar, pitch * 1.7, 0.32) * 0.23;
        Out.ar(out, Pan2.ar(LeakDC.ar((tone + air) * env), 0));
    }),
    SynthDef(\prismTone, { |out=0|
        var seed = RandSeed.ir(1, 2042);
        var env = EnvGen.kr(Env.perc(0.004, 0.55, 1, -5));
        var bell = SinOsc.ar([1174.66, 1760.0, 2354.0], 0, [0.24, 0.13, 0.04]).sum;
        var glass = BPF.ar(WhiteNoise.ar, 4200, 0.18) * EnvGen.kr(Env.perc(0.001, 0.06)) * 0.20;
        Out.ar(out, Pan2.ar(bell * env + glass, 0));
    }),
    SynthDef(\railBurst, { |out=0|
        var seed = RandSeed.ir(1, 2043);
        var body = SinOsc.ar(XLine.kr(320, 55, 0.13), 0, 0.38) * EnvGen.kr(Env.perc(0.001, 0.42, 1, -7));
        var crack = HPF.ar(WhiteNoise.ar, 1800) * EnvGen.kr(Env.perc(0.0003, 0.026, 0.27, -6));
        var beam = SinOsc.ar(XLine.kr(3100, 490, 0.24) + SinOsc.ar(130, 0, 420), 0, 0.15) * EnvGen.kr(Env.perc(0.001, 0.29));
        Out.ar(out, Pan2.ar(LeakDC.ar((body + crack + beam).tanh), 0));
    }),
    SynthDef(\railRise, { |out=0|
        var env = EnvGen.kr(Env([0, 0.15, 0.21, 0], [0.012, 0.16, 0.065], [-3, 2, -4]));
        var pitch = XLine.kr(380, 1370, 0.22);
        var tone = SinOsc.ar(pitch + SinOsc.ar(77, 0, 85));
        Out.ar(out, Pan2.ar(tone * env, 0));
    }),
    SynthDef(\switchRatchet, { |out=0|
        var seed = RandSeed.ir(1, 2044);
        var env = EnvGen.kr(Env.perc(0.001, 0.36, 1, -7));
        var ticks = Decay2.ar(Impulse.ar(43), 0.0006, 0.02) * HPF.ar(WhiteNoise.ar, 1800) * 0.35;
        var motor = SinOsc.ar(XLine.kr(780, 210, 0.11), 0, 0.32);
        var ring = SinOsc.ar(1567.98, 0, 0.12) * EnvGen.kr(Env.perc(0.016, 0.20));
        Out.ar(out, Pan2.ar(LeakDC.ar((ticks + motor) * env + ring), 0));
    })
];
cues = [["phase", \phaseWarp, 0.52], ["prism", \prismTone, 0.72], ["rail", \railBurst, 0.62], ["rail_charge", \railRise, 0.32], ["switch", \switchRatchet, 0.52]];
renderCue = { |index|
    if(index >= cues.size) {
        "MECH POP expansion SFX complete: five original cues".postln;
        0.exit;
    } {
        var cue = cues[index];
        var commands = List.new;
        definitions.do { |definition| commands.add([0.0, [\d_recv, definition.asBytes]]) };
        commands.add([0.0, [\g_new, 1, 0, 0]]);
        commands.add([0.005, [\s_new, cue[1], 1000, 0, 1]]);
        Score(commands.asArray).recordNRT(outputFilePath: output +/+ (cue[0] ++ ".wav"), sampleRate: 48000, headerFormat: "WAV", sampleFormat: "int24", options: options, duration: cue[2], action: { { renderCue.value(index + 1) }.defer });
    };
};
renderCue.value(0);
)
