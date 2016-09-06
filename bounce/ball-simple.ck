44100.0 => float fr;
1.0 => float h;
0 => float v;
-9.8 / (fr * fr) => float g;

adc => blackhole;

SinOsc s => dac;
.5 => s.gain;

SndBuf b => dac;
me.dir() + "bounce.wav" => b.read;
b.gain(0);

fun void bounce() {
    0 => b.pos;
    b.gain(v / 4 * fr);
    250::ms => now;
}

fun void ball() {
    while (true) {
        if (h < 0) {
            -h => h;
            -.8 * v => v;
            spork ~ bounce();
        } else {
            v +=> h;
            g +=> v;
        }
        1::samp => now;
    }
}

fun void fly() {
    while (true) {
        440 * Math.pow(2, ((h + 1) * 20 - 49) / 12) => s.freq;
        1::ms => now;
    }
}

fun void listen() {
    while (true) {
        if (adc.last() > .8) {
            5.0 / fr +=> v;
            1::second => now;
        } else {
            1::samp => now;
        }
    }
}

spork ~ ball();
spork ~ fly();
spork ~ listen();

1::week => now;