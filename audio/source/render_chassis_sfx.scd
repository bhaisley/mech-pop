// MECH POP chassis instruments. Render with sclang -D audio/source/render_chassis_sfx.scd
// Each role excites the same chassis differently. One mono source per cue for game-controlled panning.
(
var root = thisProcess.nowExecutingPath.dirname.dirname.dirname;
var outdir = root +/+ "audio/sfx/chassis";
var names = [\nova, \kuren, \terra, \momo, \shadow, \lumi, \kai, \zero];
var roles = [\light, \heavy, \hit, \guard, \boost, \ko];
var jobs = List.new, render;
var spans = [0.24, 0.42, 0.26, 0.39, 0.34, 0.94];
var centres = [460, 117, 74, 515, 248, 710, 355, 168];
var options = ServerOptions.new.numOutputBusChannels_(1).numInputBusChannels_(0).sampleRate_(48000);
Server.program = Platform.resourceDir +/+ "scsynth";
File.mkdir(outdir);

names.do { |name, i|
    roles.do { |role, j|
        var key = (name ++ "_" ++ role).asSymbol, dur = spans[j];
        var rootHz = centres[i] * [1.16, 0.72, 0.93, 1.27, 0.8, 0.68][j];
        var def = SynthDef(key, {
            var seed = RandSeed.ir(1, 1702 + (101*i) + j);
            var env = EnvGen.ar(Env([0, 1, 0.54, 0], [[0.011,0.019,0.002,0.002,0.035,0.005][j],
                dur*0.23, dur*0.68], [-1, -2, -4]));
            var noise = WhiteNoise.ar, pink = PinkNoise.ar;
            var hz = EnvGen.kr(Env([rootHz * [0.78,0.63,1.86,1.21,0.58,2.10][j],
                rootHz * [1.83,1.55,0.93,1.42,1.63,0.85][j],
                rootHz * [1.10,0.55,0.74,1.18,0.92,0.22][j]], [dur*0.26,dur*0.67], [2,-3]));
            var body, accent, cover, sparks, output;
            body = switch(name,
                \nova, { // Saber edge with a moving formant and two detuned rails.
                    var foil = BPF.ar(noise, (hz*4.8).clip(500,8200), 0.29)*1.8;
                    foil + (VarSaw.ar(hz*[1,1.008], 0, 0.63).sum*0.15) + SinOsc.ar(hz*2, 0, 0.17)
                },
                \kuren, { // A double ignition, followed by a short exhaust rasp.
                    var valve = Decay2.ar(Impulse.ar([28,17,22,33,18,9][j]), 0.001, 0.031);
                    var engine = LPF.ar((LFPulse.ar(hz, 0, 0.26)-0.26)*1.8, hz*6);
                    (engine + (BPF.ar(pink, hz*8, 0.74)*2.7))*(0.2+(valve*0.85))
                },
                \terra, { // Weight of a ram, a squeaking valve and an inharmonic iron bed.
                    var ram = SinOsc.ar(hz, 0, 0.78) + SinOsc.ar(hz*1.48, 0, 0.28);
                    var steel = Ringz.ar(HPF.ar(noise,400)*0.018, hz*[3.31,5.75,9.42], 0.038).sum;
                    ram.tanh + (steel*0.23) + (BPF.ar(pink,hz*15,0.24)*1.2)
                },
                \momo, { // A three-note telemetry chirp through a tiny resonant speaker.
                    var seq = Demand.kr(Impulse.kr(6/dur),0,Dseq([1,1.5,1.25,2,1.67,1],inf));
                    var chip = LFTri.ar(hz*seq) + SinOsc.ar(hz*seq*2.01,0,0.17);
                    chip*(0.18 + (Decay2.ar(Impulse.ar(6/dur),0.003,0.058)*0.60))
                },
                \shadow, { // Phase-folded carrier through an opening and closing band of air.
                    var warp = SinOsc.ar(hz*0.47,0,EnvGen.kr(Env([1.1,5.7,0.6],[dur*0.27,dur*0.51])));
                    var veil = BPF.ar(pink, XLine.kr(560,3400,dur*0.90),0.37);
                    (SinOsc.ar(hz,warp) - SinOsc.ar(hz*1.016,warp+0.64))*0.47 + (veil*1.7)
                },
                \lumi, { // Struck glass with five lightly detuned, independently damping partials.
                    var partials = [1,1.502,2.39,3.04,4.21];
                    Mix.fill(5,{ |k| SinOsc.ar(hz*partials[k], 0, [0.48,0.29,0.17,0.12,0.08][k])
                        * XLine.kr(1,0.025,dur/(1+(k*0.28))) })
                },
                \kai, { // Charge winding above an abrupt, high-frequency rail discharge.
                    var coil = SinOsc.ar(hz*(2.6+EnvGen.kr(Env([0,2.8,-1.3],[0.034,dur*0.63]))),
                        SinOsc.ar(hz*0.6,0,1.35));
                    (coil*0.47) + (HPF.ar(noise,3300)*Decay2.ar(Impulse.ar(0),0.0004,0.058)*0.55)
                },
                \zero, { // Gear teeth catch at accelerating intervals against a formant motor.
                    var teeth = Decay2.ar(Impulse.ar(XLine.kr(69,17,dur*0.76)),0.0007,0.013);
                    var ratchet = ((HPF.ar(noise,900)*0.8) + (Formant.ar(hz,hz*3,hz*1.28)*0.47))*teeth;
                    ratchet + (VarSaw.ar(hz,0,0.18)*0.29)
                }
            );
            sparks = HPF.ar(noise, 1550 + (i*130));
            cover = BPF.ar(noise, XLine.kr(2600+(i*160),720,dur),0.58);
            accent = switch(role,
                \light, { cover*EnvGen.ar(Env.perc(0.012,0.10,0.33)) },
                \heavy, { SinOsc.ar(XLine.kr(145,53,0.16))*EnvGen.ar(Env.perc(0.002,0.26,0.46))
                    + (cover*EnvGen.ar(Env.perc(0.028,0.15,0.60))) },
                \hit, { ((sparks*0.33) + (SinOsc.ar(XLine.kr(220,70,0.09))*0.65))
                    *EnvGen.ar(Env.perc(0.0005,0.135)) },
                \guard, { Mix.fill(3, { |k| SinOsc.ar((740+(i*41))*[1,1.44,2.36][k],
                    0,[0.25,0.15,0.10][k])*EnvGen.ar(Env.perc(0.001,dur/(1+(k*0.4)))) })
                    + (sparks*EnvGen.ar(Env.perc(0.001,0.037,0.30))) },
                \boost, { BPF.ar(pink,XLine.kr(410,2200,dur*0.76),0.8)*EnvGen.ar(Env.perc(0.03,0.24,0.78)) },
                \ko, { ((LPF.ar(pink,XLine.kr(3500,260,0.58))*0.83) + (SinOsc.ar(XLine.kr(134,41,0.44))*0.52))
                    *EnvGen.ar(Env.perc(0.002,0.62)) + (sparks*Decay2.ar(Impulse.ar(13+i),0.001,0.012)
                    *EnvGen.ar(Env.perc(0.07,0.61,0.24))) }
            );
            output = LeakDC.ar(body * env + accent);
            Out.ar(0, LPF.ar(HPF.ar((output*1.32).tanh,32),14000) * 0.81);
        });
        jobs.add([key, def, dur + 0.04]);
    }
};
render = { |n|
    if(n == jobs.size) { "Rendered 48 chassis cues.".postln; 0.exit } {
        var job = jobs[n];
        var score = Score([[0, [\d_recv, job[1].asBytes]], [0.002,[\s_new, job[0],1000,0,0]]]);
        score.recordNRT(outputFilePath: outdir +/+ (job[0].asString ++ ".wav"),
            sampleRate: 48000, headerFormat:"WAV", sampleFormat:"int16", options: options,
            duration: job[2], action: { { render.value(n+1) }.defer });
    }
};
render.value(0)
)
