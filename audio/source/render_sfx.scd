/* MECH★POP original synthesis. SuperCollider 3.14.1, 48 kHz, offline.
   No third-party recordings, melodic quotations, or model weights are used.
   Invoke: sclang -D audio/source/render_sfx.scd
*/
(
var root = thisProcess.nowExecutingPath.dirname.dirname.dirname;
var output = root +/+ "audio/sfx";
var definitions, cues, renderCue;
var options = ServerOptions.new.numOutputBusChannels_(2).numInputBusChannels_(0).sampleRate_(48000);
Server.program = "/Applications/SuperCollider.app/Contents/Resources/scsynth";
File.mkdir(output);

definitions = [
    SynthDef(\metal, { |out=0, amp=0.45, freq=150, weight=0.5, variant=0|
        var punch = SinOsc.ar(XLine.kr(freq * 3.6, freq * 0.46, 0.055), 0,
            EnvGen.kr(Env.perc(0.0005, 0.15 + (weight * 0.13), 0.8, -7)));
        var strike = HPF.ar(WhiteNoise.ar, 800) * EnvGen.kr(Env.perc(0.0002, 0.021, 0.7, -9));
        var ring = DynKlank.ar(`[[1, 1.93, 3.71, 5.17] * (freq * 2.8 + variant),
            [0.65, 0.27, 0.15, 0.07], [0.14, 0.11, 0.08, 0.06] * (1 + weight)], strike * 0.05);
        var grit = BPF.ar(PinkNoise.ar, 2100 + (variant * 7), 0.7) * EnvGen.kr(Env.perc(0.002, 0.08 + weight * 0.16, 0.5, -6));
        var signal = (punch * weight + ring + strike * 0.7 + grit).tanh * amp;
        Out.ar(out, Pan2.ar(LeakDC.ar(signal), 0));
    }),
    SynthDef(\servo, { |out=0, amp=0.3, freq=700, direction=1, duration=0.24|
        var sweep = XLine.kr(freq * (0.55 + direction * 0.1), freq * (1.8 - direction * 0.2), duration);
        var envelope = EnvGen.kr(Env([0, 0.7, 0.5, 0], [0.016, duration * 0.5, duration * 0.5], [-2, 1, -4]));
        var signal = BPF.ar(WhiteNoise.ar, sweep * 3, 0.35) * 0.8;
        signal = signal + SinOsc.ar(sweep + SinOsc.ar(67, 0, 45), 0, 0.22);
        Out.ar(out, Pan2.ar(signal * envelope * amp, 0));
    }),
    SynthDef(\spring, { |out=0, amp=0.36, freq=480|
        var envelope = EnvGen.kr(Env.perc(0.001, 0.25, 1, -6));
        var pitch = EnvGen.kr(Env([freq * 2.2, freq * 0.61, freq], [0.018, 0.17], [-5, -3]));
        var body = SinOsc.ar(pitch + SinOsc.ar(34, 0, 65) * envelope);
        var click = HPF.ar(WhiteNoise.ar, 3200) * EnvGen.kr(Env.perc(0.0002, 0.013));
        Out.ar(out, Pan2.ar((body * envelope * 0.7 + click * 0.3).tanh * amp, 0));
    }),
    SynthDef(\chime, { |out=0, amp=0.22, freq=880, duration=0.24|
        var env = EnvGen.kr(Env.perc(0.003, duration, 1, -6));
        var signal = SinOsc.ar(freq, 0, 0.75) + SinOsc.ar(freq * 2.01, 0, 0.16) + SinOsc.ar(freq * 3.97, 0, 0.06);
        Out.ar(out, Pan2.ar(signal * env * amp, 0));
    }),
    SynthDef(\debris, { |out=0, amp=0.18, duration=0.42, freq=1800|
        var dust = BPF.ar(PinkNoise.ar, XLine.kr(freq * 1.7, freq * 0.6, duration), 0.5);
        var taps = Decay2.ar(Impulse.ar(37), 0.001, 0.012) * HPF.ar(WhiteNoise.ar, 2700);
        var envelope = EnvGen.kr(Env.perc(0.001, duration, 1, -5));
        Out.ar(out, Pan2.ar((dust * 0.6 + taps * 0.4) * envelope * amp, 0));
    }),
    SynthDef(\corebass, { |out=0, amp=0.43|
        var env = EnvGen.kr(Env.perc(0.001, 0.78, 1, -6));
        var freq = XLine.kr(190, 41, 0.13);
        var signal = SinOsc.ar(freq) + LPF.ar(WhiteNoise.ar, XLine.kr(5000, 300, 0.4)) * 0.6;
        Out.ar(out, Pan2.ar((signal * env).tanh * amp, 0));
    })
];

cues = List.new;
3.do { |i|
    cues.add(["hit_light_%".format(i+1), 0.42, [[0, \metal, [\amp, 0.50, \freq, 185 + i*17, \weight, 0.40, \variant, i*13]]]]);
    cues.add(["hit_heavy_%".format(i+1), 0.62, [[0, \metal, [\amp, 0.65, \freq, 104 + i*9, \weight, 0.92]], [0.026, \debris, [\amp, 0.19, \duration, 0.35]]]]);
};
cues.add(["part_pop", 0.76, [[0, \metal, [\amp, 0.55, \freq, 210, \weight, 0.55]], [0.025, \spring, [\amp, 0.40, \freq, 525]], [0.095, \chime, [\freq, 1318.51, \amp, 0.17]], [0.13, \debris, [\amp, 0.12, \duration, 0.36]]]]);
cues.add(["snap", 0.6, [[0, \servo, [\amp, 0.17, \freq, 1150, \duration, 0.075]], [0.064, \metal, [\amp, 0.35, \freq, 285, \weight, 0.23]], [0.085, \chime, [\freq, 1046.5, \amp, 0.23]], [0.14, \chime, [\freq, 1567.98, \amp, 0.23]]]]);
cues.add(["core_pop", 1.3, [[0, \corebass, [\amp, 0.61]], [0, \metal, [\amp, 0.51, \freq, 82, \weight, 1]], [0.06, \spring, [\amp, 0.36, \freq, 330]], [0.16, \debris, [\amp, 0.28, \duration, 0.67]], [0.22, \chime, [\freq, 659.25, \amp, 0.23, \duration, 0.36]], [0.30, \chime, [\freq, 987.77, \amp, 0.23, \duration, 0.36]], [0.39, \chime, [\freq, 1318.51, \amp, 0.25, \duration, 0.50]]]]);
cues.add(["blade", 0.46, [[0, \servo, [\amp, 0.51, \freq, 1180, \duration, 0.19]], [0.07, \chime, [\amp, 0.08, \freq, 1760, \duration, 0.16]]]]);
cues.add(["burst", 0.51, [[0, \servo, [\amp, 0.2, \freq, 420, \duration, 0.09]], [0.065, \metal, [\amp, 0.6, \freq, 135, \weight, 0.72]], [0.08, \debris, [\amp, 0.29, \duration, 0.25, \freq, 2900]]]]);
cues.add(["cannon", 0.91, [[0, \corebass, [\amp, 0.44]], [0, \metal, [\amp, 0.62, \freq, 88, \weight, 1]], [0.025, \debris, [\amp, 0.24, \duration, 0.5, \freq, 2400]]]]);
cues.add(["halo", 0.65, [[0, \servo, [\amp, 0.17, \freq, 1550, \duration, 0.17]], [0.035, \chime, [\freq, 1318.51, \amp, 0.24]], [0.14, \chime, [\freq, 1975.53, \amp, 0.17]]]]);
cues.add(["jump", 0.38, [[0, \servo, [\amp, 0.22, \freq, 470, \duration, 0.18]], [0, \metal, [\amp, 0.16, \freq, 180, \weight, 0.30]]]]);
cues.add(["boost", 0.40, [[0, \servo, [\amp, 0.29, \freq, 850, \duration, 0.24]], [0.015, \debris, [\amp, 0.17, \duration, 0.22, \freq, 3500]]]]);
cues.add(["land", 0.33, [[0, \metal, [\amp, 0.31, \freq, 115, \weight, 0.46]], [0.01, \debris, [\amp, 0.09, \duration, 0.18]]]]);
cues.add(["ui_move", 0.18, [[0, \chime, [\amp, 0.19, \freq, 1174.66, \duration, 0.08]]]]);
cues.add(["ui_confirm", 0.40, [[0, \chime, [\amp, 0.24, \freq, 1046.5, \duration, 0.12]], [0.055, \chime, [\amp, 0.24, \freq, 1567.98, \duration, 0.20]]]]);
cues.add(["warning", 0.59, [[0, \chime, [\amp, 0.19, \freq, 783.99, \duration, 0.15]], [0.15, \chime, [\amp, 0.19, \freq, 739.99, \duration, 0.16]]]]);
cues.add(["ready", 0.36, [[0, \chime, [\amp, 0.28, \freq, 659.25, \duration, 0.17]], [0, \metal, [\amp, 0.13, \freq, 150, \weight, 0.5]]]]);
cues.add(["go", 0.78, [[0, \metal, [\amp, 0.41, \freq, 180, \weight, 0.7]], [0, \chime, [\amp, 0.24, \freq, 1046.5, \duration, 0.22]], [0.07, \chime, [\amp, 0.22, \freq, 1318.51, \duration, 0.22]], [0.14, \chime, [\amp, 0.24, \freq, 1567.98, \duration, 0.36]]]]);
cues.add(["victory", 1.8, [[0, \chime, [\freq, 523.25, \amp, 0.24, \duration, 0.3]], [0.16, \chime, [\freq, 659.25, \amp, 0.24, \duration, 0.3]], [0.32, \chime, [\freq, 783.99, \amp, 0.24, \duration, 0.3]], [0.53, \chime, [\freq, 1046.5, \amp, 0.29, \duration, 0.8]], [0.53, \chime, [\freq, 659.25, \amp, 0.12, \duration, 0.8]], [0.53, \metal, [\amp, 0.18, \freq, 130, \weight, 0.45]]]]);

renderCue = { |index|
    if(index >= cues.size) {
        "MECH POP SFX render complete".postln;
        0.exit;
    } {
        var cue = cues[index];
        var commands = List.new;
        definitions.do { |definition| commands.add([0.0, [\d_recv, definition.asBytes]]) };
        commands.add([0.0, [\g_new, 1, 0, 0]]);
        cue[2].do { |layer, i|
            commands.add([layer[0] + 0.005, [\s_new, layer[1], 1000 + i, 0, 1] ++ layer[2]]);
        };
        "Rendering %".format(cue[0]).postln;
        Score(commands.asArray).recordNRT(
            outputFilePath: output +/+ (cue[0] ++ ".wav"),
            sampleRate: 48000, headerFormat: "WAV", sampleFormat: "int24",
            options: options, duration: cue[1],
            action: { { renderCue.value(index + 1) }.defer }
        );
    };
};
renderCue.value(0);
)
