/* ascent.ck
 * Nick Spinale
 * April 14th, 2016
 *
 * This file contains my interfacing composition.
 *
 * It contains a tiny physics simulator for creating the dopler effect.
 *
 * On my little netbook, chuck has a hard time keeping up with the
 * calculations in real time, so the playback is scratchy. One way to
 * get around this is to write it to a .wav file, using spinalenUtil/rec.ck.
 * For example, on the command line, instead of just entering
 *
 *      `chuck ascent.ck`
 *
 * instead enter:
 *
 *      `chuck ascent.ck record.ck`
 *
 * This creates ascent.wav, which does not sound scratchy. However, my
 * computer is particularly bad, so you may not have any issues just running
 * it in real time.
 *
 */

// ---- VECTOR ----
// Class for representing vectors in 2d space

class Vector {

    float x;
    float y;

    fun float distance(Vector u) {
        return Math.sqrt(Math.pow(x + u.x, 2) + Math.pow(y + u.y, 2));
    }

    fun float dot(Vector u) {
        return x * u.x + y * u.y;
    }

    fun float magnitude() {
        return Math.sqrt(x * x + y * y);
    }

    fun Vector multiply(float a) {
        Vector u;
        a * x => u.x;
        a * y => u.y;
        return u;
    }

    fun Vector add(Vector u) {
        Vector v;
        x - u.x => v.x;
        y - u.y => v.y;
        return v;
    }

    fun Vector subtract(Vector u) {
        Vector v;
        x - u.x => v.x;
        y - u.y => v.y;
        return v;
    }

    fun Vector project(Vector u) {
        return multiply(dot(u) / dot(this));
    }

    fun static Vector from_polar(float angle, float mag) {
        Vector u;
        Math.cos(angle) * mag => u.x;
        Math.sin(angle) * mag => u.y;
        return u;
    }

    fun static Vector zero() {
        Vector u;
        0 => u.x;
        0 => u.y;
        return u;
    }
}

// ---- SCIENCE ----
// Class containing most of the simulation logic.

class Science {

    static float speed_of_sound;

    // Return freq for static
    fun static float doppler(Vector pos_static, Vector pos, Vector velocity, float freq) {
        // TODO improve
        pos_static.subtract(pos) @=> Vector connector;
        connector.project(velocity) @=> Vector aligned;
        float rel_velocity;
        if (connector.add(aligned).magnitude() > connector.magnitude()) {
            aligned.magnitude() => rel_velocity;
        } else {
            -aligned.magnitude() => rel_velocity;
        }
        return freq * (speed_of_sound / (speed_of_sound + rel_velocity));
    }

    // Return gain for static
    fun static float fade(Vector pos_static, Vector pos, float gain) {
        return  gain / pos_static.subtract(pos).magnitude();
    }

    fun static Vector vector_velocity(float angular_velocity, float angle, float radius) {
        angle + pi/2 => float new_angle;
        angular_velocity * radius => float mag;
        return Vector.from_polar(new_angle, mag);
    }
}

// For some reason, this needs to be outside the class
340.29 => Science.speed_of_sound;

// ---- EARS ----
// The listener's ears are at these specified points.

class Ears {
    Vector left;
    Vector right;
}

// ---- AGENT ----
// An agent is a moving thing that makes sound, which is
// heard by ears.

class Agent {

    StkInstrument left;
    StkInstrument right;

    float base_gain;
    float base_freq;

    fun void init() {
        left => dac.left;
        right => dac.right;
    }
}

// ---- CIRCLER ----
// Class containing state and step logic for an agent that is moving in a circle

class Circler {

    Agent agent; // gain is at 1 meter away
    Ears ears;
    Vector center;
    float radius;
    int theta; // angle, in 1/1,000,000ths of the whole
    int delta; // change in theta per step
    int step; // in ms

    fun void take_step() {

        theta*2*pi / 1000000.0 => float t;
        (delta*2*pi / 1000000.0) / (step / 1000.0) => float d;
        Science.vector_velocity(d, t, radius) @=> Vector v;

        Vector.from_polar(t, radius).add(center) @=> Vector pos;

        agent.left.noteOn(Science.fade(ears.left, pos, agent.base_gain));
        agent.left.freq(Science.doppler(ears.left, pos, v, agent.base_freq));
        agent.right.noteOn(Science.fade(ears.right, pos, agent.base_gain));
        agent.right.freq(Science.doppler(ears.right, pos, v, agent.base_freq));

        // advance time
        step * 1::ms => now;

        // advance position
        delta +=> theta;
    }
}

// ---- PLAYERS ----
// Classes for sound-making entities that do not move

class AbstractPlayer {
    Vector.zero() @=> Vector @ pos;
    Ears ears;
    float gain;
}

// Sound from a file
class BufDrummer extends AbstractPlayer {

    SndBuf left;
    SndBuf right;

    left.gain(0);
    right.gain(0);

    fun void play() {
        left.gain(Science.fade(ears.left, pos, this.gain));
        right.gain(Science.fade(ears.right, pos, this.gain));

        0 => left.pos;
        0 => right.pos;

        /* <<< left.gain(), right.gain() >>>; */

        left.length() => now;

        left.gain(0);
        right.gain(0);
    }

    fun void feed(float intervals[]) {
        for (0 => int i; i < intervals.cap(); i++) {
            intervals[i] * 500::ms => now;
            spork ~ play();
        }
        // for last note
        1::minute => now;
    }
}

// Sound from and StkInstrument.
// This composition doesn't actually use this class, but it helps to illustrate
// the general model here.
class StkPlayer extends AbstractPlayer {

    StkInstrument left;
    StkInstrument right;

    fun void play(float freq, dur len) {
        left.gain(Science.fade(ears.left, pos, gain));
        right.gain(Science.fade(ears.right, pos, gain));

        freq => left.freq;
        freq => right.freq;
        
        left.noteOn(1);
        right.noteOn(1);

        len => now;

        left.noteOff(1);
        right.noteOff(1);
    }

    fun void feed(float notes[][], float freqs[]) {
        for (0 => int i; i < notes.cap(); i++) {
            notes[i][0] * 1::ms => now;
            play(notes[i][1], notes[i][2] * 1::ms);
        }
        // for last note
        1::minute => now;
    }
}

// ---- PIECE HELPER ----
// Useful shortcut for advancing a certain number of beats

fun void beats(float n) {
    n * .5::second => now;
}

// ---- PIECE ----
// The composition itself

// you are here
Ears ears;
-.5 => ears.left.x;
-6.0 => ears.left.y;
.5 => ears.right.x;
-6.0 => ears.right.y;

// we'll only deal with one Circular, and this function returns it.
fun Circler base_circler() {

    Circler c;

    new Agent @=> c.agent;
    BlowBotl anon1 @=> c.agent.left;
    BlowBotl anon2 @=> c.agent.right;
    .5 => c.agent.base_gain;
    148.02 => c.agent.base_freq;
    c.agent.init();

    ears @=> c.ears;

    Vector.zero() @=> c.center;
    5.0 => c.radius;

    250000 => c.theta;
    1 => c.step;

    return c;
}

// initialize circler
base_circler() @=> Circler @ c;
500 => int start_delta;

// circler speed-up
fun void circle_up() {
    for (start_delta => c.delta; c.delta <= 2000; c.delta++) {
        for (0 => int i; i < 15; i++) {
            c.take_step();
        }
    }
}

// circler consistent spinning
fun void circle_const(int d) {
    d => c.delta;
    while (true) {
        c.take_step();
    }
}

// circler becoming quieter
fun void circle_fade_out() {
    2000 => c.delta;
    while (c.agent.base_gain > .3) {
        for (0 => int i; i < 100; i++) {
            c.take_step();
        }
        .01 -=> c.agent.base_gain;
    }
}

// circler getting louder, faster, then quieter (for end of piece)
fun void circle_build() {
    2000 => c.delta;
    while (c.agent.base_gain < .4) {
        for (0 => int i; i < 2000; i++) {
            c.take_step();
        }
        .1 +=> c.agent.base_gain;
    }
    for (2000 => c.delta; c.delta <= 8000; c.delta++) {
        for (0 => int i; i < 7; i++) {
            c.take_step();
        }
        c.delta++;
    }
    while (c.agent.base_gain > 0) {
        for (0 => int i; i < 100; i++) {
            c.take_step();
        }
        .01 -=> c.agent.base_gain;
    }
}

// circler becoming quieter
fun void circle_down() {
    for (2000 => c.delta; c.delta >= start_delta; c.delta--) {
        for (0 => int i; i < 15; i++) {
            c.take_step();
        }
    }
}

// useful shortcut for constructing drummers
fun void init_drummer(BufDrummer d, float g, float xi, float yi, string file) {
    Vector.zero() @=> d.pos;
    xi => d.pos.x;
    yi => d.pos.y;
    g => d.gain;
    ears @=> d.ears;
    me.dir() + "samples/" + file + ".wav" => d.left.read;
    me.dir() + "samples/" + file + ".wav" => d.right.read;
}

// These are the actual static agents of the composition

BufDrummer bass_l;
BufDrummer bass_r;

init_drummer(bass_l, .2, -1, -6, "bass_mouth");
init_drummer(bass_r, .2,  1, -6, "bass_mouth");

bass_l.left => JCRev j1 => dac.left;
bass_l.right => JCRev j2 => dac.right;
bass_r.left => JCRev j3 => dac.left;
bass_r.right => JCRev j4 => dac.right;

BufDrummer mouthl;
BufDrummer mouthr;

init_drummer(mouthl, .3, -1, -6, "mouth");
init_drummer(mouthr, .3,  1, -6, "mouth");

mouthl.left => JCRev jx1 => dac.left;
mouthl.right => JCRev jx2 => dac.right;
mouthr.left => JCRev jx3 => dac.left;
mouthr.right => JCRev jx4 => dac.right;

BufDrummer glass;
init_drummer(glass, .7, 0, 0, "glass");
glass.left => JCRev jg1 => dac.left;
glass.right => JCRev jg2 => dac.right;

// Shreds for sporking later

fun void circle_do() {
    circle_fade_out();
    circle_const(2000);
}
fun void go_drum1() {
    spork ~ mouthl.feed([0.0, .5, .25, .5, .25, .25, .25]);
    beats(4);
    spork ~ mouthr.feed([0.0, .5, .5, .5, .25]);
    beats(4);
    spork ~ mouthl.feed([0.0, .5, .25, .5, .25, .25, .25]);
    beats(4);
    spork ~ mouthr.feed([0.0, .5, .5, .5, .25]);
    beats(4);
    spork ~ mouthl.feed([0.0, .5, .25, .5]);
    spork ~ mouthr.feed([0.0, 0.25, .5, .5, .25, .25, .5]);
    beats(4);
    spork ~ mouthl.feed([0.0, .5, .25, .5]);
    spork ~ mouthr.feed([0.0, 0.25, .5, .5, .25, .25]);
    beats(4);
}
fun void go_drum() {
    for (0 => int i; i < 8; i++) {
        spork ~ mouthl.feed([0.0, .5, .25, .5]);
        spork ~ mouthr.feed([0.0, 0.25, .5, .5, .5, 1]);
        beats(4);
    }
}
fun void go_bass(int n) {
    for (0 => int i; i < n; i++) {
        spork ~ bass_l.feed([0.0, 2, 1]);
        spork ~ bass_r.feed([.5, 2, 1]);
        beats(4);
        spork ~ bass_l.feed([0.0, 2, 1]);
        spork ~ bass_r.feed([.5, 2, 1]);
        beats(4);
        spork ~ bass_l.feed([0.0, 2, 1]);
        spork ~ bass_r.feed([.5, 2, 1]);
        beats(4);
        spork ~ bass_l.feed([0.0, 2, 1]);
        spork ~ bass_r.feed([.5, 2]);
        beats(4);
    }
}

fun void go_basses() {
    while (true) {
        spork ~ bass_l.feed([1.0/32, 2, 1]);
        spork ~ bass_r.feed([0.0, .5, 1.5]);
        beats(4);
        spork ~ bass_l.feed([0.0, .5, 1.5]);
        spork ~ bass_r.feed([1.0/32, 2, 1]);
        beats(4);
    }
}
fun void go_glasss1() {
    while (true) {
        spork ~ glass.feed([3.0, 1]);
        beats(8);
    }
}
fun void go_glasss2() {
    while (true) {
        spork ~ glass.feed([0.0, 2]);
        beats(1);
        spork ~ glass.play() @=> Shred @ g;
        0::ms => dur len;
        len => now;
        g.exit();
        500::ms - len => now;
        beats(2);
    }
}
fun void go_mouths() {
    while (true) {
        spork ~ mouthl.feed([0.0, .5, .25, .5]);
        spork ~ mouthr.feed([0.0, 0.25, .5, .5, .25, .25, .5]);
        beats(4);
    }
}

// DO THE MUSIC

circle_up();

spork ~ circle_do();
170::ms => now;
spork ~ go_drum1();
beats(24);
spork ~ go_bass(2);
spork ~ go_drum();
beats(32);

spork ~ go_basses() @=> Shred @ basses;
beats(8);
spork ~ go_mouths() @=> Shred @ mouths;
beats(16);
spork ~ go_bass(1);
beats(15);
spork ~ glass.play();
basses.exit();
mouths.exit();
beats(1);

circle_build();

<<< "DONE" >>>;

