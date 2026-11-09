"""Build independent velocity/articulation performances; preserve152 pitch WAVs.

All note rendering uses the existing licensed acoustic SF2 and offline TSF.
These are synthesized performances of sampled instruments,not four new recordings.
"""
from pathlib import Path
import hashlib,json,subprocess,wave
import numpy as np
from scipy.signal import butter,sosfilt

ROOT=Path(__file__).resolve().parents[1]
RATE=22050
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def save(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(path),'wb') as f:
        f.setparams((1,2,RATE,0,'NONE','not compressed'))
        f.writeframes(np.rint(np.clip(data,-.98,.98)*32767).astype('<i2').tobytes())
def main():
    policy_path=ROOT/'audio/instruments/WEAPON_DYNAMICS.json'
    policy=json.loads(policy_path.read_text(encoding='utf-8'))
    palette=json.loads((ROOT/'audio/instruments/CHAMBER_PALETTE.json').read_text(encoding='utf-8'))
    old=json.loads((ROOT/'audio/instruments/MANIFEST.json').read_text(encoding='utf-8'))
    records={w['id']:w for w in old['instruments']}
    source=ROOT/'work/instrument-sources'; font=source/'GeneralUser-GS.sf2'
    assert digest(font)==old['soundfont_sha256']
    exe=source/'render_instrument_note.exe'
    subprocess.run(['E:/MinGW/bin/gcc.exe','-O2','-std=c99','-I',str(source),str(ROOT/'tools/render_instrument_note.c'),'-o',str(exe),'-lm'],check=True)
    output=[]
    for entry in palette['weapons']:
        assert entry['instrument_family'] in ['piano','strings','harp'] and entry['bank']==0 and entry['program'] in [0,1,40,41,42,46]
        layers=[]
        for index,level in enumerate(policy['levels']):
            hold=entry['hold']*level['hold_scale']; release=entry['release']*level['release_scale']
            attack=entry['attack_ms']*level['attack_scale']
            cutoff=min(8500,entry['lowpass_hz']*level['cutoff_scale'])
            raw=source/'dynamic-note.f32'
            command=[str(exe),str(font),'0',str(entry['program']),str(entry['root_midi']),str(hold),str(release),str(raw),str(level['velocity'])]
            if entry['instrument_family']=='strings': command.append(str(level['bow_attack_ms']/1000))
            result=subprocess.run(command,capture_output=True,text=True,check=True)
            x=np.fromfile(raw,dtype='<f4').astype(np.float64)
            # Preserve the true source onset; trim only leading near-silence.
            active=np.flatnonzero(np.abs(x)>np.max(np.abs(x))*.002)
            x=x[max(0,int(active[0])-22):]
            x=sosfilt(butter(2,cutoff,fs=RATE,output='sos'),x)
            # Shape existing acoustic harmonics; no added oscillator/layer.
            split=max(220,440*2**((entry['root_midi']-69)/12)*1.8)
            low=sosfilt(butter(1,split,fs=RATE,output='sos'),x)
            x=low+(x-low)*10**(level['harmonic_tilt_db']/20); x-=x.mean()
            n=min(len(x),round(attack*RATE/1000)); x[:n]*=np.sin(np.linspace(0,np.pi/2,n))**2
            n=min(len(x),round(.035*RATE)); x[-n:]*=np.cos(np.linspace(0,np.pi/2,n))**2
            target=records[entry['id']]['samples'][0]['attack_300ms_rms']*level['rms_ratio']
            gain=min(.32/np.max(np.abs(x)),target/max(1e-12,np.sqrt(np.mean(x[:round(.3*RATE)]**2))))
            x*=gain
            path=ROOT/f'audio/arsenal/dynamics/dyn_{entry["id"]}_{index}.wav'; save(path,x)
            sidecar=path.with_suffix('.wav.import')
            if sidecar.exists():
                text=sidecar.read_text(encoding='utf-8')
                sidecar.write_text(text.replace('compress/mode=2','compress/mode=0'),encoding='utf-8')
            layers.append({'strength':index,'label':level['label'],'file':path.relative_to(ROOT).as_posix(),'sha256':digest(path),'root_midi':entry['root_midi'],'program':entry['program'],'velocity':level['velocity'],'hold':hold,'release':release,'attack_ms':attack,'cutoff_hz':cutoff,'harmonic_tilt_db':level['harmonic_tilt_db'],'tone_split_hz':split,'seconds':len(x)/RATE,'peak':float(np.max(np.abs(x))),'rms':float(np.sqrt(np.mean(x*x))),'attack_300ms_rms':float(np.sqrt(np.mean(x[:round(.3*RATE)]**2))),'preset':result.stdout.strip(),'normalization_gain':float(gain)})
        output.append({'id':entry['id'],'instrument':entry['instrument'],'family':entry['instrument_family'],'balance_db':policy['balance_db'][entry['id']],'layers':layers})
        print(entry['id'],[round(s['attack_300ms_rms'],4) for s in layers],flush=True)
    manifest={k:old[k] for k in ['source','homepage','license','soundfont_sha256','renderer','renderer_sha256','format']}
    manifest.update(revision=policy['revision'],policy_sha256=digest(policy_path),renderer_driver_sha256=digest(ROOT/'tools/render_instrument_note.c'),scope='76independent same-root performances; source velocity zones plus individual envelope/hold/release/lowpass. Not four independent acoustic recordings. Original152 pitch samples untouched; no added oscillator,drum,synthetic layer,pitch shift or time stretching.',weapons=output)
    (ROOT/'audio/instruments/DYNAMICS_MANIFEST.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Built',sum(len(w['layers']) for w in output),'performance layers')
if __name__=='__main__': main()
