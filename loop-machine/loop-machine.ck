/*
 * loop-machine.ck
 * Nick Spinale
 * May 24, 2016
 */

// Frame rate constant
second / samp => float frate;

// Array-backed list
class ArrayList {
    float arr[];
    0 => int size;
    fun void init(int cap) {
        float new_arr[cap];
        new_arr @=> arr;
    }
    fun int getSize() {
        return size;
    }
    fun void append(float val) {
        if (size >= arr.cap()) {
            float new_arr[size * 2];
            for (0 => int i; i < size; i++) {
                new_arr[i] @=> arr[i];
            }
            new_arr @=> arr;
        }
        val => arr[size];
        size++;
    }
    fun float index(int i) {
        return arr[i];
    }
}

// Mutable beat
class Beat {
    dur beat;
    fun void set(dur b) {
        b => beat;
    }
    fun dur get() {
        return beat;
    }
    fun void waitFor() {
        beat - (now % beat) => now;
    }
    fun void increase() {
        beat + 20::ms => beat;
    }
    fun void decrease() {
        beat - 20::ms => beat;
    }
}

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

// A register contains sound data, with some extra properties.
// It can be recorded to, played back, and looped.
class Register {

    int name;
    ArrayList samps;

    Shred @ recording;
    Shred @ playing;
    Shred @ looping;

    // dummy1 controls output to the 'out' passed to init,
    // dummy2 controls output to dac.
    Impulse im => JCRev rev => PitShift p => Gain g;

    Gain normal;
    g => Gain noDist => normal;
    QuadDist dist;
    g => dist.in;
    dist.out => Gain yesDist => normal;

    g => Gain looper => dac;

    1.0 => p.shift;
    1.0 => p.mix;
    0 => rev.mix;
    1 => float speed;
    0 => int distOn;

    fun void init(int i, UGen out) {
        i => name;
        normal => out;
        looper.gain(0);
        yesDist.gain(0);
        samps.init(1);
        samps.append(1.0);
        dist.opts(100, .1);
    }

    fun int isEmpty() {
        return samps == null;
    };

    fun int isLooping() {
        return looping != null;
    };

    fun void setPitch(int x) {
        [ 5.0/3  // 0 - unison (safety)
        , 1.0    // 1 - unison
        , 6.0/5  // 2 - 3m
        , 5.0/4  // 3 - 3
        , 4.0/3  // 4 - 4
        , 3.0/2  // 5 - 5
        , 16.0/9 // 6 - 7m
        , 15.0/8 // 7 - 7
        , 2.0    // 8 - octave up
        , 0.5    // 9 - octave down
        ] @=> float shifts[];
        shifts[x] => p.shift;
    }

    fun void toggleDist() {
        if (distOn) {
            yesDist.gain(0.0);
            noDist.gain(1.0);
            false => distOn;
        } else {
            noDist.gain(0.0);
            yesDist.gain(1.0);
            true => distOn;
        }
    }

    fun void setGain(int x) {
        (x $ float) / 5.0 => g.gain;
    }

    fun void setReverb(int x) {
        (x $ float) / 20.0 => rev.mix;
    }

    fun void setSpeed(int x) {
        Math.pow(2, (x - 5) $ float) => speed;
    }

    fun void record(UGen in) {
        while (true) {
            samps.append(in.last());
            speed * 1::samp => now;
        }
    }
    fun void stopRec() {
        if (recording != null) {
            recording.exit();
        }
    }
    fun void startRec(UGen in) {
        stopRec();
        ArrayList new_samps;
        new_samps @=> samps;
        samps.init(10 * (frate $ int));
        spork ~ record(in) @=> recording;
        1::week => now; // There has to be a better way
    }
    fun void startFeedback(Beat beat, UGen in) {
        beat.waitFor();
        startRec(in);
    }

    fun void play() {
        for (0 => int i; i < samps.getSize(); i++) {
            im.next(samps.index(i));
            speed * 1::samp => now;
        }
    }
    fun void stopPlay() {
        if (playing != null) {
            playing.exit();
        }
    }
    fun void startPlay() {
        stopPlay();
        spork ~ play() @=> playing;
        1::week => now; // There has to be a better way
    }

    fun void loop(Beat beat) {
        do {
            beat.waitFor();
            play();
        } while (true);
    }
    fun void stopLoop() {
        normal.gain(1);
        looper.gain(0);
        if (looping != null) {
            looping.exit();
            null => looping;
        }
    }
    fun void startLoop(Beat beat) {
        stopLoop();
        normal.gain(0);
        looper.gain(1);
        spork ~ loop(beat) @=> looping;
        1::week => now; // There has to be a better way
    }
}

// MidMsg extended for convenience
class HidMsgMore extends HidMsg {
    fun int isNumber() {
        return 48 <= ascii && ascii <= 57;
    }
    fun int isNumberDown() {
        return isButtonDown() && isNumber();
    }
    fun int isLetter() {
        return 65 <= ascii && ascii <= 90;
    }
    fun int isLetterUp() {
        return isButtonUp() && isLetter();
    }
    fun int isLetterDown() {
        return isButtonDown() && isLetter();
    }
    fun int getNumber() {
        return ascii - 48;
    }
    fun int getRegister() {
        return ascii - 65;
    }
    fun int is(int a) {
        return a == ascii;
    }
    fun int isDown(int a) {
        return isButtonDown() && is(a);
    }
    fun int isUp(int a) {
        return isButtonUp() && is(a);
    }
}

// Hacky way of implementing an enum for the UI automaton.
// Interestingly, static variables aren't initialized until and instance of
// the class is declared. This makes no sense.
class UIState {
    0 => static int base;
    7 => static int recording;
    1 => static int exNumRegForGain;
    2 => static int exRegForGain;
    3 => static int exNumRegForReverb;
    4 => static int exRegForReverb;
    5 => static int exRegLoop;
    6 => static int exRegToFeedback;
    9 => static int exNumClear;
   10 => static int exNumRegSpeed;
   11 => static int exRegSpeed;
   12 => static int exNumRegPitch;
   13 => static int exRegPitch;
   14 => static int exRegDist;
} UIState THIS_SHOULD_NOT_BE_NECESSARY;

// Enum of keystrokes
class Keys {
    96 => static int record; // `
    45 => static int clearLoop; // -
    61 => static int feedback; // =
    91 => static int tempoDown; // [
    93 => static int tempoUp; // ]
    92 => static int u0; // \
    59 => static int gain; // ;
    39 => static int reverb; // '
    44 => static int speed; // ,
    46 => static int pitch; // .
    47 => static int toggleDist; // /
} Keys THIS_SHOULD_ALSO_NOT_BE_NECESSARY;

// Main soundboard class
class SoundBoard {

    UGen in;
    UGen out;

    Beat beat;
    beat.set(480::ms);

    Register registers[26];
    Register loops[10];

    fun void init(UGen i, UGen o) {
        i @=> in;
        o @=> out;
        for (0 => int i; i < registers.cap(); i++) {
            registers[i].init(i, out);
        }
        for (0 => int i; i < loops.cap(); i++) {
            null => loops[i];
        }
    }

    // Bits of state for UI
    UIState.base => int state;
    int newGain;
    int newReverb;
    int newSpeed;
    int newPitch;
    int loopIndex;
    -1 => int feedingInto;

    // UI automaton
    fun void process(HidMsgMore msg) {
        if (state == UIState.base) {
            if (msg.isLetterDown()) {
                spork ~ registers[msg.getRegister()].startPlay();
            } else if (msg.isNumberDown()) {
                msg.getNumber() => loopIndex;
                UIState.exRegLoop => state;
            } else if (msg.isDown(Keys.tempoUp)) {
                beat.decrease();
            } else if (msg.isDown(Keys.tempoDown)) {
                beat.increase();
            } else if (msg.isDown(Keys.clearLoop)) {
                UIState.exNumClear => state;
            } else if (msg.isDown(Keys.record)) {
                UIState.recording => state;
            } else if (msg.isDown(Keys.gain)) {
                UIState.exNumRegForGain => state;
            } else if (msg.isDown(Keys.reverb)) {
                UIState.exNumRegForReverb => state;
            } else if (msg.isDown(Keys.speed)) {
                UIState.exNumRegSpeed => state;
            } else if (msg.isDown(Keys.toggleDist)) {
                UIState.exRegDist => state;
            } else if (msg.isDown(Keys.pitch)) {
                UIState.exNumRegPitch => state;
            } else if (msg.isDown(Keys.feedback)) {
                if (feedingInto > 0) {
                    registers[feedingInto].stopRec();
                    -1 => feedingInto;
                } else {
                    UIState.exRegToFeedback => state;
                }
            }
        } else if (state == UIState.recording) {
            if (msg.isUp(Keys.record)) {
                UIState.base => state;
            } else if (msg.isLetterDown()) {
                spork ~ registers[msg.getRegister()].startRec(in);
            } else if (msg.isLetterUp()) {
                registers[msg.getRegister()].stopRec();
            }
        } else if (state == UIState.exNumRegForGain && msg.isNumberDown()) {
            msg.getNumber() => newGain;
            UIState.exRegForGain => state;
        } else if (state == UIState.exRegForGain && msg.isLetterDown()) {
            registers[msg.getRegister()].setGain(newGain);
            UIState.base => state;
        } else if (state == UIState.exNumRegForReverb && msg.isNumberDown()) {
            msg.getNumber() => newReverb;
            UIState.exRegForReverb => state;
        } else if (state == UIState.exRegForReverb && msg.isLetterDown()) {
            registers[msg.getRegister()].setReverb(newReverb);
            UIState.base => state;
        } else if (state == UIState.exRegToFeedback && msg.isLetterDown()) {
            msg.getRegister() => feedingInto;
            spork ~ registers[feedingInto].startFeedback(beat, out);
            UIState.base => state;
        } else if (state == UIState.exNumRegSpeed && msg.isNumberDown()) {
            msg.getNumber() => newSpeed;
            UIState.exRegSpeed => state;
        } else if (state == UIState.exRegSpeed && msg.isLetterDown()) {
            registers[msg.getRegister()].setSpeed(newSpeed);
            UIState.base => state;
        } else if (state == UIState.exRegLoop && msg.isLetterDown()) {
            if (loops[loopIndex] != null) {
                loops[loopIndex].stopLoop();
            }
            registers[msg.getRegister()] @=> loops[loopIndex];
            spork ~ registers[msg.getRegister()].startLoop(beat);
            UIState.base => state;
        } else if (state == UIState.exNumClear && msg.isNumberDown()) {
            if (loops[msg.getNumber()] != null) {
                loops[msg.getNumber()].stopLoop();
            }
            null @=> loops[msg.getNumber()];
            UIState.base => state;
        } else if (state == UIState.exNumRegPitch && msg.isNumberDown()) {
            msg.getNumber() => newPitch;
            UIState.exRegPitch => state;
        } else if (state == UIState.exRegDist && msg.isLetterDown()) {
            registers[msg.getRegister()].toggleDist();
            UIState.base => state;
        } else if (state == UIState.exRegPitch && msg.isLetterDown()) {
            registers[msg.getRegister()].setPitch(newPitch);
            UIState.base => state;
        }
    }

    // Execute UI automaton
    fun void listen() {
        Hid hi;
        HidMsgMore msg;
        if (!hi.openKeyboard(0)) {
            me.exit();
        }
        while (true) {
            hi => now;
            while (hi.recv(msg)) {
                process(msg);
            }
        }
    }
}

// Main action

adc => Gain in => blackhole;
Gain out => dac;

SoundBoard sb;
sb.init(in, out);
sb.listen();
