// chuck this with other shreds to record to file
// example> chuck foo.ck bar.ck record.ck

// arguments: record:<filename>

// get name
me.arg(0) => string filename;
if( filename.length() == 0 ) "foo.wav" => filename;

// pull samples from the dac
dac => WvOut w => blackhole;
// this is the output file name
filename => w.wavFilename;
<<<"writing to file:", "'" + w.filename() + "'">>>;

// temporary workaround to automatically close file on remove-shred
null @=> w;

// infinite time loop...
// ctrl-c will stop it, or modify to desired duration
while (true) 1::second => now;
