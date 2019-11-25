/*
 * space.ck
 * Nick Spinale
 */

Gain sdac => dac;

// Units
1::minute/110.0 => dur beat;
4::beat => dur measure;

// Initialization
(me.args() ? Std.atoi(me.arg(0)) : 0)::measure => dur start;

// For conversion
now => time zero;

// An abstraction for time. Start from anywhere in the composition by specifying
// a measure to start on on the command line.
class Universe {

    start => dur here;

    fun dur ask() {
        return (now % 1::day) + (start - (0::samp < this.here ? this.here : 0::samp));
    }

    fun void adv(dur d) {
        if (0::samp < this.here) {
            if (this.here < d) {
                d - this.here => now;
            }
            d -=> this.here;
        } else {
            d => now;
        }
    }

    fun void goto(dur t) {
        if (0::samp < start) {
            if (t - start + zero > now) {
                (t - start + zero) - now => now;
            }
            start - t => this.here;
        } else {
            (t + zero) - now => now;
        }
    }

    fun void nearest(dur unit) {
        this.adv(unit - ((now + (0::samp < this.here ? this.here : 0::samp)) % unit));
    }

}

// Helpers

fun SndBuf load(string name) {
    SndBuf b;
    me.dir() + "samples/" + name => b.read;
    b.samples() => b.pos;
    return b;
}

fun void play(Universe u, SndBuf b, float points[]) {
    u.ask() => dur here;
    for (0 => int i; i < points.cap(); i++) {
        u.goto(here + points[i]::beat);
        0 => b.pos;
    }
}

fun void play(Universe u, TriOsc s, float points[], int notes[], float last) {
    1 => s.gain;
    u.ask() => dur here;
    for (0 => int i; i < points.cap(); i++) {
        u.goto(here + points[i]::beat);
        Std.mtof(notes[i] + 12) => s.freq;
    }
    u.adv(last::beat);
    0 => s.gain;
}

// Section lengths
2::measure => dur intro;
4::measure => dur drums;

24 => int cutlen;
cutlen::measure => dur cut;

// Score

load("redacted1.aif") @=> SndBuf dsp => sdac;
fun void drum1() {
    Universe u;
    u.adv(intro + drums);
    for (0 => int i; i < cutlen; i++) {
        play(u, dsp, [0.0, .5, 1.25, 2,  2.5]);
        u.nearest(1::measure);
    }
};

load("redacted2.wav") @=> SndBuf dk => sdac;
fun void drum2() {
    Universe u;
    u.adv(intro + drums);
    for (0 => int i; i < cutlen; i++) {
        play(u, dk, [1.0, 3]);
        u.nearest(1::measure);
    }
};

load("redacted3.aif") @=> SndBuf oh => sdac;
fun void hat1() {
    Universe u;
    u.adv(intro);
    u.goto(3::measure + 3::beat);
    0 => oh.pos;
    u.adv(2::measure);
    0 => oh.pos;
};

// BLIT

Blit bl => JCRev r => Pan2 blPan => Gain blGain => Gain blMute => sdac;
.0 => bl.gain;
.05 => r.mix;

fun void blit() {

    Universe u;
    u.adv(intro);

    .2 => bl.gain;

    [ 0, 0, 2, 2, 0, 0, 0, 9
    , 0, 0, 0, 0, 7, 7, 0, 9
    , 0, 0, 2, 2, 9, 9, 0, 9
    , 9, 0, 0, 0, 4, 4, 2, 9
    , 9, 0, 0, 0, 2, 2, 4, 9
    , 9, 0, 0, 0, 4, 4, 2, 9
    , 0, 0, 0, 0, 9, 11, 9, 21
    ] @=> int first[];

    [1, 2, 3, 4, 5, 6, 7] @=> int harms[];

    for (0 => int i; i < first.cap(); i++) {
        harms[i / 8] => bl.harmonics;
        Std.mtof(33 + first[i]) => bl.freq;
        u.adv(.25::beat);
    }

    0 => bl.gain;
    u.adv(2::beat);
    .2 => bl.gain;

    [ 0, 2, 4, 7, 9, 11 ] @=> int notes[];

    for (0 => int i; i < (cutlen + 1) * 4 * 4; i++) {
        Std.mtof(33 + Math.random2(0, 3) * 12 + notes[Math.random2(0, notes.size() - 1)]) => bl.freq;
        Math.random2(1, 5) => bl.harmonics;
        u.adv(.25::beat);
    }

    for (0 => int i; i < 2 * 4 * 4; i++) {
        Std.mtof(33 + Math.random2(0, 3) * 12 + notes[Math.random2(0, notes.size() - 1)]) => bl.freq;
        Math.random2(4, 9) => bl.harmonics;
        u.adv(.25::beat);
    }

    Std.mtof(33 + 12 + 4) => bl.freq;
    10 => bl.harmonics;
    u.adv(1::measure);

}

fun void blitAmp() {
    Universe u;
    u.adv(intro + drums);

    SinOsc amp => blackhole;
    SinOsc pan => blackhole;
    3 * pi/2 => pan.phase;
    1::second/8::measure => amp.freq;
    1::second/8::measure => pan.freq;

    while (true) {
        blPan.pan(.5 * pan.last());
        bl.gain(.1 + .2 * Math.fabs(amp.last()));
        u.adv(1::samp);
    }
}

fun void blitEnd() {
    Universe u;
    u.adv(intro + drums + cut + 5::measure);
    for (0 => int i; i < 64; i++) {
        (64 - i) / 64.0 => blMute.gain;
        u.adv(.125::beat);
    }
}

SndBuf pop;
"special:glot_pop" => pop.read;
pop.samples() => pop.pos;

fun void pops() {

    Universe u;
    for (0 => int i; i < 39 * 4; i++) {
        0 => pop.pos;
        u.adv(1::beat);
    }
    for (0 => int i; i < 4 * 16 * 4; i++) {
        0 => pop.pos;
        u.adv(.25::beat);
    }

}

fun void ctrl1() {

    Universe u;

    pop => BiQuad f => Gain g => JCRev popr => sdac;
    pop => BiQuad f2 => g;
    pop => BiQuad f3 => g;

    0.800 => f.prad; .995 => f2.prad; .995 => f3.prad;
    1 => f.eqzs; 1 => f2.eqzs; 1 => f3.eqzs;
    0.0 => float v => float v2;
    .1 => f.gain; .1 => f2.gain; .01 => f3.gain;
    0.3 => popr.mix;

    while (true) {
        250.0 + Math.sin(v*100.0)*20.0 => v2 => f.pfreq;
        2290.0 + Math.sin(v*200.0)*50.0 => f2.pfreq;
        3010.0 + Math.sin(v*300.0)*80.0 => f3.pfreq;
        v + .05 => v;
        0.2 + Math.sin(v)*.1 => g.gain;
        0.2 + Math.sin(v)*.1 => g.gain;
        1::beat => now;
    }

}

fun void ctrl2() {
    Universe u;
    .5 => pop.rate;
    for (0 => int i; i < 8; i++) {
        .1 + pop.rate() => pop.rate;
        u.adv(1::beat);
    }
    for (0 => int i; i < 16; i++) {
        -.05 + pop.rate() => pop.rate;
        u.adv(1::beat);
    }
    1.3 => pop.rate;
    u.adv(cut);
    for (0 => int i; i < 16; i++) {
        -.05 + pop.rate() => pop.rate;
        u.adv(1::beat);
    }

}

// Realize

spork ~ drum1();
spork ~ drum2();
spork ~ blit();
spork ~ blitAmp();
spork ~ blitEnd();
spork ~ pops();
spork ~ ctrl1();
spork ~ ctrl2();

.6 => sdac.gain;
Universe u;
u.adv(intro + drums + cut + 8::measure);
