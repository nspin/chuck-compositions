44100.0 => float fr;
1.0 => float h;
0 => float v;
-9.8 / (fr * fr) => float g;

adc => blackhole;

HevyMetl s => dac;

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
        Math.floor((h + 1) * 20) => float key_num;
        440 * Math.pow(2, (key_num - 49) / 12) => s.freq;
        s.noteOn(.7);
        1::ms => now;
    }
}

fun void listen() {
    while (true) {
        adc.last() => float amnt;
        if (amnt > .7) {
            if (amnt > 2) {
                2 => amnt;
            }
            (6.0 / fr) * amnt +=> v;
            1::second => now;
        } else {
            1::samp => now;
        }
    }
}

fun void freq_monitor() {
    while (true) {
        s.freq() => float f;
        500::ms => now;
    }
}

spork ~ ball();
spork ~ fly();
spork ~ listen();
spork ~ freq_monitor();

1::week => now;
