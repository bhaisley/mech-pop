// Render the seven articulations of each New Challengers instrument with sclang -D.
(
var outdir = thisProcess.nowExecutingPath.dirname.dirname +/+ "sfx/chassis";
var names = [\rivet, \kite, \rook, \coda];
var roles = [\light, \heavy, \hit, \guard, \boost, \ko, \special];
var jobs = List.new, render;
var options = ServerOptions.new.numOutputBusChannels_(1).numInputBusChannels_(0).sampleRate_(48000);
Server.program = Platform.resourceDir +/+ "scsynth";
File.mkdir(outdir);
names.do { |name, i|
    roles.do { |role, j|
        var key = (name ++ "_" ++ role).asSymbol;
        var duration = [0.22,0.39,0.23,0.35,0.33,0.86,0.64][j];
        var base = [184,620,109,276][i] * [1.24,0.80,1.04,1.36,0.93,0.76,1][j];
        var def = SynthDef(key, {
            var seed = RandSeed.ir(1, 6637 + i*13 + j);
            var freq = XLine.kr(base*[1.20,1.55,1.85,1.08,0.70,1.94,0.83][j],
                base*[0.98,0.65,0.78,1.18,1.76,0.28,1.19][j], duration*0.90);
            var env = EnvGen.ar(Env.perc([0.004,0.014,0.001,0.002,0.045,0.005,0.009][j],duration*0.90));
            var noise = WhiteNoise.ar;
            var voice = switch(name,
                \rivet, { // Ratchet teeth driving an electric winch.
                    var teeth = Decay2.ar(Impulse.ar(XLine.kr(41,12,duration)),0.001,0.014);
                    (BPF.ar(noise,2100,0.35)*teeth*2.9) + VarSaw.ar(freq,0,0.18,0.25) + SinOsc.ar(freq*0.50,0,0.23)
                },
                \kite, { // Two separated whistle partials and a cutting, airy edge.
                    SinOsc.ar(freq*(1+SinOsc.kr(9,0,0.012)),0,0.30) + SinOsc.ar(freq*1.51,0,0.15)
                    + BPF.ar(noise,(freq*4.2).clip(800,7500),0.45,0.8)
                },
                \rook, { // A struck gate with inharmonic modes and a short latch.
                    Mix.fill(4,{ |k| SinOsc.ar(freq*[1,2.71,4.16,6.07][k],0,0.49/(k+1))
                        * EnvGen.ar(Env.perc(0.001,duration/(1+0.38*k))) }) + (HPF.ar(noise,1800)*EnvGen.ar(Env.perc(0.001,0.048),levelScale:0.42))
                },
                \coda, { // A drumskin and a bronze bell answer in two strokes.
                    var tap = Impulse.ar(0) + TDelay.ar(Impulse.ar(0),duration*0.31);
                    var skin = Decay2.ar(tap,0.002,duration*0.56);
                    SinOsc.ar(freq*(1+skin*0.35),0,0.5)*skin + (SinOsc.ar(freq*2.39,0,0.24)*skin)
                    + (BPF.ar(noise,1850,0.42)*skin*0.42)
                }
            );
            var hit = if([\heavy,\hit,\ko].includes(role),
                {SinOsc.ar(XLine.kr(176,45,0.15),0,0.44)*EnvGen.ar(Env.perc(0.002,0.17))}, {0});
            Out.ar(0, LPF.ar(HPF.ar((voice*env + hit).tanh,34),14000)*0.86);
        });
        jobs.add([key,def,duration+0.045]);
    };
};
render = { |n|
    if(n == jobs.size) { "Rendered 28 challenger cues.".postln; 0.exit } {
        var job = jobs[n];
        var score = Score([[0,[\d_recv,job[1].asBytes]],[0.002,[\s_new,job[0],1000,0,0]]]);
        score.recordNRT(outputFilePath:outdir +/+ (job[0].asString ++ ".wav"),sampleRate:48000,
            headerFormat:"WAV",sampleFormat:"int16",options:options,duration:job[2],
            action:{ {render.value(n+1)}.defer });
    }
};
render.value(0)
)
