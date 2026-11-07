"""Append three offline instruments; never rewrite the existing twelve."""
from pathlib import Path
import hashlib,json,subprocess,wave
import numpy as np
from repair_recorded_audio_imports import import_sidecar

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'work/instrument-sources'
RATE=22050
SCALE=[0,2,3,5,7,8,10,12]
ENTRIES=[('gilded_helix','长笛',73,.18,.38),('weave_cross','钢片琴',8,.08,.62),('crown_orbit','竖琴',46,.08,.68)]

def main():
    path=ROOT/'audio/instruments/MANIFEST.json'
    manifest=json.loads(path.read_text(encoding='utf-8'))
    preserved={s['file']:s['sha256'] for r in manifest['instruments'] if r['id'] not in {e[0] for e in ENTRIES} for s in r['samples']}
    records=[r for r in manifest['instruments'] if r['id'] not in {e[0] for e in ENTRIES}]
    demo=[]
    for wid,label,program,hold,release in ENTRIES:
        sounds=[];preset=''
        for degree in SCALE:
            raw=SOURCE/'v21-note.f32'
            p=subprocess.run([str(SOURCE/'render_instrument_note.exe'),str(SOURCE/'GeneralUser-GS.sf2'),'0',str(program),str(72+degree),str(hold),str(release),str(raw)],check=True,capture_output=True,text=True)
            preset=p.stdout.strip();data=np.fromfile(raw,dtype='<f4').astype(np.float64)
            peak=float(abs(data).max());assert peak>.001
            active=np.flatnonzero(abs(data)>peak*.002)
            data=data[max(0,int(active[0])-22):]
            n=min(round(.014*RATE),len(data));data[-n:]*=np.linspace(1,0,n)
            data[:22]*=np.linspace(0,1,22);sounds.append(data)
        gain=min(.68/max(abs(x).max() for x in sounds),.12/max(1e-9,float(np.median([np.sqrt(np.mean(x*x)) for x in sounds]))))
        samples=[]
        for i,data in enumerate(sounds):
            data*=gain;dest=ROOT/f'audio/arsenal/notes/inst_{wid}_{i}.wav'
            with wave.open(str(dest),'wb') as w:
                w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(np.rint(np.clip(data,-.94,.94)*32767).astype('<i2').tobytes())
            dest.with_suffix('.wav.import').write_text(import_sidecar(dest),encoding='utf-8',newline='\n')
            samples.append({'pitch_index':i,'root_midi':72+SCALE[i],'file':dest.relative_to(ROOT).as_posix(),'seconds':len(data)/RATE,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'peak':float(abs(data).max()),'rms':float(np.sqrt(np.mean(data*data)))})
        records.append({'id':wid,'instrument':label,'voice':'inst_'+wid,'bank':0,'program':program,'preset_name':preset,'root_midi':72,'percussion':False,'gain':gain,'hold':hold,'release':release,'electronic_mix':0.,'samples':samples})
        block=np.zeros(round(RATE*1.7))
        for at in [0,.25]:
            start=round(at*RATE);n=min(len(sounds[0]),len(block)-start);block[start:start+n]+=sounds[0][:n]*.65
        demo.append(block);print(wid,preset,flush=True)
    assert all(hashlib.sha256((ROOT/f).read_bytes()).hexdigest()==sha for f,sha in preserved.items())
    manifest['instruments']=records;path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    dest=ROOT/'docs/audio-v21';dest.mkdir(exist_ok=True)
    with wave.open(str(dest/'three-new-instruments.wav'),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(np.rint(np.tanh(np.concatenate(demo))*.9*32767).astype('<i2').tobytes())
    print('24new samples;96previous samples hash-verified unchanged',flush=True)

if __name__=='__main__':main()
