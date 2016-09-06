/* interactive.ck
 * Nick Spinale
 * May 24, 2016
 */

// CONSTANTS
second / samp => float frate;

class Monitor extends FFT {

    float est_freq, est_gain;

    fun void monitor() {

        while(true) {

            upchuck().fvals() @=> float arr[];
            0 => float max_i;
            0 => float max_v;

            for(int i; i < arr.cap(); i++) {
                if(arr[i] > max_v) {
                    arr[i] => max_v;
                    i => max_i;
                }
            }
            
            (max_i / size() * frate) => est_freq;
            max_v / .25 => est_gain;
            
            (size()/2)::samp => now;
        }
    }
}


SndBuf b => PoleZero dcblock => Monitor m => blackhole;
"drumpf.wav" => b.read;
// synthesis
SinOsc s => JCRev r => dac;

spork ~ m.monitor();

.05 => r.mix;
.99 => dcblock.blockZero;
1024 => m.size;

Windowing.hamming(m.size()) => m.window;


// interpolate
float target_freq, curr_freq, target_gain, curr_gain;
spork ~ ramp_stuff();


fun void ramp_stuff()
{
    0.025 => float slew;
    
    while( true )
    {
        /* target_freq => s.freq; */
        /* target_gain => s.gain; */
        (m.est_freq - curr_freq) * 5 * slew + curr_freq => curr_freq => s.freq;
        (m.est_gain - curr_gain) * slew + curr_gain => curr_gain => s.gain;
        0.0025::second => now;
    }
}
/* // interpolation */
/* fun void ramp_stuff() */
/* { */
/*     // mysterious 'slew' */
/*     0.025 => float slew; */
    
/*     // infinite time loop */
/*     while( true ) */
/*     { */
/*         (target_freq - curr_freq) * 5 * slew + curr_freq => curr_freq => s.freq; */
/*         (target_gain - curr_gain) * slew + curr_gain => curr_gain => s.gain; */
/*         0.0025::second => now; */
/*     } */
/* } */
1::minute => now;
