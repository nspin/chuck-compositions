// Nick Spinale
// May 1, 2016
// MUSC 208
// Parametricity

////////////////
 // DISTORTION //
////////////////

// The main experiment of this composition is finding different functions that
// work well as distortion. This way of using Gain objects for math, along with
// some of the functions I made, were inspired by:
//      electro-music.com/forum/viewtopic.php?t=19287
// Gain objects can combine their inputs in different ways (addition, subraction,
// multiplication, division). Gain objects can be composed together to allow us to
// use them as functions. The functions I've used here are:
//
// QuadDist: f(x) = x / (1 + x^2)
// CubicDist: f(x) = x / (1 + x^3)
// AbsDist: f(x) = x / (1 + |x|)
//
// Through trial and error, I found parameters (basically just input gain)
// that made the various StkInsturments sound interesting.


class QuadDist {

    Gain in;
    Gain out;

    // LOGIC

    // in2 = in^2
    in => Gain in2;
    in => Gain dummy => in2; 
    3 => in2.op; 

    // divisor = 1 + in^2
    in2 => Gain divisor; 
    Step one => divisor; 
    1 => one.next; 

    // result = in / (1 + in^2)
    in => Gain result; 
    divisor => result; 
    4 => result.op; 

    result => out;

    // API

    fun void opts(float in_gain, float out_gain) {
        in_gain => in.gain;
        out_gain => out.gain;
    }
}

class CubicDist {

    Gain in;
    Gain out;

    // LOGIC

    // in3 = in^3
    in => Gain in3;
    in => Gain dummy1 => in3; 
    in => Gain dummy2 => in3; 
    3 => in3.op; 

    // divisor = 1 + in^3
    in3 => Gain divisor; 
    Step one => divisor; 
    1 => one.next; 

    // result = in / (1 + in^3)
    in => Gain result; 
    divisor => result; 
    4 => result.op; 

    result => out;

    // API

    fun void opts(float in_gain, float out_gain) {
        in_gain => in.gain;
        out_gain => out.gain;
    }
}

class AbsDist {

    Gain in;
    Gain out;
    
    // LOGIC

    // abs_in = |in|
    in => FullRect abs_in;

    // divisor = 1 + |in|
    abs_in => Gain divisor; 
    Step one => divisor; 
    1 => one.next; 

    // result = in / (1 + |in|)
    in => Gain result; 
    divisor => result; 
    4 => result.op; 

    result => out;

    // API

    fun void opts(float in_gain, float out_gain) {
        in_gain => in.gain;
        out_gain => out.gain;
    }
}

  //////////////////////
 // MELODY MACHINERY //
//////////////////////

120 => float bmp;
1::minute / bmp => dur beat;

class Note {

    float wait;
    float duration;
    float freq;
    float velocity;

    fun void playOne(StkInstrument stk) {
        freq => stk.freq;
        stk.noteOn(velocity);
        duration * beat => now;
        stk.noteOff(velocity);
    }
}

// Translate piano keys to frequency
fun float freqOf(int key) {
    return Math.pow(2, (key-49.0)/12.0) * 440.0;
}

fun Note note(float wait, float duration, int key, float velocity) {
    Note x;
    wait => x.wait;
    duration => x.duration;
    freqOf(key) => x.freq;
    velocity => x.velocity;
    return x;
}

fun void play(StkInstrument stk, Note ns[]) {
    ns[0].wait => float passed;
    passed * beat => now;
    for (0 => int i; i < ns.cap(); i++) {
        (ns[i].wait - passed) * beat => now;
        ns[i].wait => passed;
        spork ~ ns[i].playOne(stk);
    }
    10::second => now;
}

fun void percuss(SndBuf buf, float sc[], float g) {
    sc[0] => float passed;
    passed * beat => now;
    for (0 => int i; i < sc.cap(); i++) {
        (sc[i] - passed) * beat => now;
        sc[i] => passed;
        buf.gain(g);
        0 => buf.pos;
    }
}


  //////////////////
 // PLAYER STUFF //
//////////////////

// SndBuf extended to allow for viewing various paramters as intrinsic
// to the UGen.
class MoreBuf extends SndBuf {
    Pan2 pan;
    JCRev rev;
    fun void init(string name) {
        0 => rev.mix;
        gain(0);
        me.dir() + "samples/" + name + ".wav" => read;
        this => rev => pan => dac;
    }
}

  /////////////
 // PLAYERS //
/////////////

// Distorted Marimbas

JCRev bwgr => Pan2 bwgp => dac;
.03 => bwgr.mix;
-.6 => bwgp.pan;

JCRev bwgl => Pan2 bwgpl => dac;
.03 => bwgl.mix;
.6 => bwgpl.pan;

QuadDist q1; q1.opts(100, .1); q1.out => bwgr;
QuadDist q2; q2.opts(100, .1); q2.out => bwgr;
QuadDist q3; q3.opts(100, .1); q3.out => bwgl;
QuadDist q4; q4.opts(100, .1); q4.out => bwgl;

BandedWG x => q1.in;
BandedWG y => q2.in;
BandedWG z => q3.in;
BandedWG zz => q3.in;

// Hihat

MoreBuf hh1; hh1.init("hihat");
MoreBuf hh2; hh2.init("hihat");
MoreBuf hh3; hh3.init("hihat");

.7 => hh1.pan.pan;
.7 => hh2.pan.pan;
.7 => hh3.pan.pan;

.3 => hh1.rev.mix;
.2 => hh2.rev.mix;
.1 => hh3.rev.mix;

MoreBuf hh; hh.init("hihat");
.7 => hh.pan.pan;
.1 => hh.rev.mix;

MoreBuf sh; sh.init("analyzed-shorthats");
-.7 => sh.pan.pan;
.05 => sh.rev.mix;

// Other files

MoreBuf snare; snare.init("analyzed-snare");
-.3 => snare.pan.pan;
.01 => snare.rev.mix;

MoreBuf kick; kick.init("analyzed-tap");
0 => kick.pan.pan;
0 => kick.rev.mix;

MoreBuf kic; kic.init("tap");
0 => kic.pan.pan;
0 => kic.rev.mix;


  ///////////
 // SCORE //
///////////

// MOSTLY REDACTED (it was bad)

[ note(0.0, 0, 30, 2)
, note(1.0, 0, 33, 2)
, note(2.5, 0, 33, 2)
] @=> Note aa[];

[ note(0.0, 0, 33, 2)
, note(1.0, 0, 37, 2)
, note(2.5, 0, 37, 2)
] @=> Note bb[];


fun void marim(int meas, Note a[], Note b[]) {
    for (0 => int i; i < meas; i++) {
        spork ~ play(x, a);
        spork ~ play(y, b);
        4 * beat => now;
    }
}

spork ~ marim(8, aa, bb);
8 * beat => now;
