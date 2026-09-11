const fs=require('fs');
const rate=24000, seconds=60, count=rate*seconds;
const report=[];
for(const kind of ['ocean','rain','forest']) {
  let seed=kind==='ocean'?721:kind==='rain'?913:227;
  const random=()=>{seed=(Math.imul(seed,1664525)+1013904223)>>>0;return seed/2147483648-1;};
  const wav=Buffer.alloc(44+count*2);
  wav.write('RIFF');wav.writeUInt32LE(wav.length-8,4);wav.write('WAVEfmt ',8);wav.writeUInt32LE(16,16);
  wav.writeUInt16LE(1,20);wav.writeUInt16LE(1,22);wav.writeUInt32LE(rate,24);wav.writeUInt32LE(rate*2,28);
  wav.writeUInt16LE(2,32);wav.writeUInt16LE(16,34);wav.write('data',36);wav.writeUInt32LE(count*2,40);
  let low=0, mid=0, mean=0, power=0, peak=0;
  for(let i=0;i<count;i++) {
    const t=i/rate, white=random();low=.987*low+.013*white;mid=.7*mid+.3*white;
    const tide=.36+.64*Math.pow((1+Math.sin(2*Math.PI*t/15))/2,1.7);
    let sample=kind==='ocean'?(low*3+mid*.4)*tide*.38:
      kind==='rain'?(white*.11+mid*.27+low*.5):
      (low*3.2+mid*.13)*(.5+.3*Math.sin(2*Math.PI*t/20)+.15*Math.sin(2*Math.PI*t/12));
    // Smooth endpoints avoid clicks at loop boundaries; the asset is explicitly synthetic.
    const fade=Math.min(1,i/(rate*.16),(count-1-i)/(rate*.16));
    sample=Math.max(-.72,Math.min(.72,sample))*Math.max(0,fade);
    wav.writeInt16LE(Math.round(sample*32767),44+i*2);mean+=sample;power+=sample*sample;peak=Math.max(peak,Math.abs(sample));
  }
  fs.writeFileSync('entry/src/main/resources/rawfile/ambient_'+kind+'.wav',wav);
  report.push({kind,seconds,sampleRate:rate,peak,rms:Math.sqrt(power/count),dc:mean/count,seamDifference:Math.abs(wav.readInt16LE(44)-wav.readInt16LE(wav.length-2))});
}
fs.writeFileSync('verification/ambient-audio-quality.json',JSON.stringify(report,null,2));
console.log(report);
