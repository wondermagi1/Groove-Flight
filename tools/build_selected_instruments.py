"""Render the selected twelve instruments, preserving all previous samples."""
from pathlib import Path
import hashlib, json, subprocess, wave
import numpy as np
from repair_recorded_audio_imports import import_sidecar

ROOT=Path(__file__).resolve().parents[1]
SOURCES=ROOT/'work/instrument-sources'
RATE=22050
SCALE=[0,2,3,5,7,8,10,12]
# id, label, bank, GM program, root MIDI, hold, release, old electronic mix
INSTRUMENTS=[
 ('pulse','钢琴',0,0,60,.12,.50,0.),
 ('scatter','军鼓',128,0,38,.05,.35,0.),
 ('beam','小提琴',0,40,60,.30,.40,0.),
 ('missile','底鼓',128,0,36,.05,.40,0.),
 ('nova','中音萨克斯',0,65,60,.20,.34,0.),
 ('chain','颤音琴＋电子泛音',0,11,72,.10,.50,.12),
 ('rail','大提琴',0,42,48,.18,.40,0.),
 ('pulse_needle','钢弦吉他',0,25,60,.10,.50,0.),
 ('scatter_prism','低音通鼓',128,0,41,.05,.50,0.),
 ('beam_split','合成弦乐＋电子光芯',0,50,60,.24,.40,.12),
 ('rail_horizon','低音钢琴',0,0,36,.14,.60,0.),
 ('recorded_heavy','定音鼓',0,47,43,.08,.65,0.),
]

def main():
    exe=SOURCES/'render_instrument_note.exe'
    subprocess.run(['E:/MinGW/bin/gcc.exe','-O2','-std=c99','-I',str(SOURCES),
        str(ROOT/'tools/render_instrument_note.c'),'-o',str(exe),'-lm'],check=True)
    notes=ROOT/'audio/arsenal/notes'; out=ROOT/'audio/instruments';out.mkdir(exist_ok=True)
    font=SOURCES/'GeneralUser-GS.sf2';records=[]; demo=[]
    for wid,label,bank,program,root,hold,release,electronic in INSTRUMENTS:
        sounds=[]; preset=''
        for index,degree in enumerate(SCALE):
            key=root if bank==128 else root+degree
            raw=SOURCES/'note.f32'
            p=subprocess.run([str(exe),str(font),str(bank),str(program),str(key),str(hold),str(release),str(raw)],check=True,capture_output=True,text=True)
            preset=p.stdout.strip(); data=np.fromfile(raw,dtype='<f4').astype(np.float64)
            if electronic:
                with wave.open(str(notes/f'{wid}_{index}.wav'),'rb') as w:
                    old=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(float)/32768.
                n=min(len(old),len(data));data[:n]+=old[:n]*electronic
            peak=float(abs(data).max());assert peak>.001,(wid,index)
            active=np.flatnonzero(abs(data)>peak*.002)
            lead=max(0,int(active[0])-round(.001*RATE)) if len(active) else 0
            data=data[lead:]
            fade=min(round(.014*RATE),len(data));data[-fade:]*=np.linspace(1,0,fade)
            data[:22]*=np.linspace(0,1,22)
            sounds.append(data)
        gain=min(.68/max(abs(x).max() for x in sounds),.12/max(1e-9,float(np.median([np.sqrt(np.mean(x*x)) for x in sounds]))))
        sample_records=[]
        for index,data in enumerate(sounds):
            data*=gain;path=notes/f'inst_{wid}_{index}.wav'
            with wave.open(str(path),'wb') as w:
                w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(np.rint(np.clip(data,-.94,.94)*32767).astype('<i2').tobytes())
            path.with_suffix('.wav.import').write_text(import_sidecar(path),encoding='utf-8',newline='\n')
            sample_records.append({'pitch_index':index,'root_midi':root if bank==128 else root+SCALE[index],
                'file':path.relative_to(ROOT).as_posix(),'seconds':len(data)/RATE,
                'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'peak':float(abs(data).max()),'rms':float(np.sqrt(np.mean(data*data)))})
        record={'id':wid,'instrument':label,'voice':'inst_'+wid,'bank':bank,'program':program,'preset_name':preset,
            'root_midi':root,'percussion':bank==128,'gain':gain,'hold':hold,'release':release,'electronic_mix':electronic,'samples':sample_records}
        records.append(record)
        # Each instrument plays twice at250ms spacing; this is a listening
        # demonstration of independent same-type placement, not a live capture.
        block=np.zeros(round(RATE*1.6));data=sounds[0]
        for at in [0,.25]:
            start=round(at*RATE);n=min(len(data),len(block)-start);block[start:start+n]+=data[:n]*.65
        demo.append(block)
        print(wid,label,preset)
    manifest={'source':'GeneralUser GS 2.0.3','homepage':'https://www.schristiancollins.com/generaluser',
        'license':'GeneralUser GS License v2.0; see GeneralUser-LICENSE.txt',
        'soundfont_sha256':hashlib.sha256(font.read_bytes()).hexdigest(),
        'renderer':'TinySoundFont, MIT','renderer_sha256':hashlib.sha256((SOURCES/'tsf.h').read_bytes()).hexdigest(),
        'format':'mono PCM16 22050Hz','fixed_battle_pitch_index':0,'instruments':records}
    (out/'MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for name in ['GeneralUser-LICENSE.txt','TinySoundFont-LICENSE.txt']:
        (out/name).write_bytes((SOURCES/name).read_bytes())
    preview=np.concatenate(demo);preview=np.tanh(preview)*.9
    dest=ROOT/'docs/audio-v19';dest.mkdir(exist_ok=True)
    with wave.open(str(dest/'twelve-instruments.wav'),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(RATE);w.writeframes(np.rint(preview*32767).astype('<i2').tobytes())
    print('Rendered',len(records)*8,'samples; previous synth and recorded files preserved')

if __name__=='__main__': main()
