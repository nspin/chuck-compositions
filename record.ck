"space-extended.wav" => string filename;
dac => WvOut w => blackhole;
filename => w.wavFilename;
null @=> w;
60 * 133 + 37 => int n;
for (0 => int i; i < n; i++) {
    1::second => now;
}
