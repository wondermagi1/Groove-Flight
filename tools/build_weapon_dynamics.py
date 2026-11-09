"""Build independent velocity/articulation performances; preserve152 pitch WAVs.

All note rendering uses the existing licensed acoustic SF2 and offline TSF.
These are synthesized performances of sampled instruments,not four new recordings.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,wave
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
    parser=argparse.ArgumentParser()
    parser.add_argument('--ids',help='Comma-separated weapons;unselected sample bytes and metadata are preserved.')
    parser.add_argument('--strengths',default='0,1,2,3',help='Strength indices to render.')
    args=parser.parse_args()
    policy_path=ROOT/'audio/instruments/WEAPON_DYNAMICS.json'
    policy=json.loads(policy_path.read_text(encoding='utf-8'))
    palette=json.loads((ROOT/'audio/instruments/CHAMBER_PALETTE.json').read_text(encoding='utf-8'))
    old=json.loads((ROOT/'audio/instruments/MANIFEST.json').read_text(encoding='utf-8'))
    records={w['id']:w for w in old['instruments']}
    selected=set(args.ids.split(',')) if args.ids else {w['id'] for w in palette['weapons']}
    strengths={int(s) for s in args.strengths.split(',')}
    assert selected <= set(records) and strengths <= {0,1,2,3}
    manifest_path=ROOT/'audio/instruments/DYNAMICS_MANIFEST.json'
    existing={w['id']:w for w in json.loads(manifest_path.read_text(encoding='utf-8'))['weapons']} if manifest_path.exists() else {}
    source=ROOT/'work/instrument-sources'; font=source/'GeneralUser-GS.sf2'
    assert digest(font)==old['soundfont_sha256']
    exe=source/'render_instrument_note.exe'
    subprocess.run(['E:/MinGW/bin/gcc.exe','-O2','-std=c99','-I',str(source),str(ROOT/'tools/render_instrument_note.c'),'-o',str(exe),'-lm'],check=True)
    output=[]
    for entry in palette['weapons']:
        assert entry['instrument_family'] in palette['allowed_families'] and entry['bank']==0 and entry['program'] in palette.get('allowed_programs',[0,1,40,41,42,46])
        layers=[]
        for index,level in enumerate(policy['levels']):
            if entry['id'] not in selected or index not in strengths:
                layers.append(existing[entry['id']]['layers'][index]);continue
            hold=entry['hold']*level['hold_scale']; release=entry['release']*level['release_scale']
            sustained=policy.get('sustained_salvos',{})
            base_profile=sustained.get('profiles',{}).get(entry['id'])
            profile=base_profile if index in sustained.get('strengths',[]) else None
            fixed_duration=base_profile if base_profile and 'duration_seconds' in base_profile else None
            if profile:
                hold=profile['hold']*(.94 if index==2 else 1.06)
                release=profile['release']*(.95 if index==2 else 1.05)
            if fixed_duration:
                hold=fixed_duration['hold_seconds'];release=fixed_duration['duration_seconds']-hold
            attack=entry['attack_ms']*level['attack_scale']
            cutoff=min(8500,entry['lowpass_hz']*level['cutoff_scale'])
            raw=source/'dynamic-note.f32'
            # TSF's CLI truncates time to frames;avoid a binary float dropping
            # one frame from an explicitly requested fixed-duration voice.
            render_hold=str((round(hold*RATE)+.0001)/RATE) if fixed_duration else str(hold)
            render_release=str((round(release*RATE)+.0001)/RATE) if fixed_duration else str(release)
            command=[str(exe),str(font),'0',str(entry['program']),str(entry['root_midi']),render_hold,render_release,str(raw),str(level['velocity'])]
            if entry['instrument_family']=='strings': command.append(str(level['bow_attack_ms']/1000))
            result=subprocess.run(command,capture_output=True,text=True,check=True)
            x=np.fromfile(raw,dtype='<f4').astype(np.float64)
            # Preserve the true source onset; trim only leading near-silence.
            active=np.flatnonzero(np.abs(x)>np.max(np.abs(x))*.002)
            if not fixed_duration:x=x[max(0,int(active[0])-22):]
            x=sosfilt(butter(2,cutoff,fs=RATE,output='sos'),x)
            # Shape existing acoustic harmonics; no added oscillator/layer.
            split=max(220,440*2**((entry['root_midi']-69)/12)*1.8)
            low=sosfilt(butter(1,split,fs=RATE,output='sos'),x)
            x=low+(x-low)*10**(level['harmonic_tilt_db']/20); x-=x.mean()
            if profile and 'sustain_program' in profile:
                # A licensed bowed acoustic note holds the plucked attack's
                # exact pitch;this is one composed voice,not another trigger.
                body_raw=source/'dynamic-body.f32'
                body_command=[str(exe),str(font),'0',str(profile['sustain_program']),str(entry['root_midi']),render_hold,render_release,str(body_raw),str(.60 if index==2 else .80),'0.025']
                subprocess.run(body_command,capture_output=True,text=True,check=True)
                body=np.fromfile(body_raw,dtype='<f4').astype(np.float64)
                body=sosfilt(butter(2,min(6500,cutoff),fs=RATE,output='sos'),body)
                reference_rms=np.sqrt(np.mean(x[:round(.3*RATE)]**2))
                window_start=.4 if hold>=.6 else hold*.40
                window_end=.9 if hold>=.6 else hold*.90
                body_rms=np.sqrt(np.mean(body[round(window_start*RATE):round(window_end*RATE)]**2))
                body*=reference_rms*profile['sustain_mix']/max(1e-12,body_rms)
                onset=profile.get('sustain_onset_seconds',.06);fade_seconds=profile.get('sustain_fade_seconds',.22)
                fade=np.sin(np.clip((np.arange(len(body))/RATE-onset)/fade_seconds,0,1)*np.pi/2)**2
                body*=fade
                n=min(len(x),len(body));x[:n]+=body[:n]
            if profile:
                time=np.arange(len(x))/RATE
                swell=np.sin(np.clip(time/hold,0,1)*np.pi/2)**2
                swell*=np.cos(np.clip((time-hold)/release,0,1)*np.pi/2)**2
                x*=1+sustained['body_swell']*swell
            n=min(len(x),round(attack*RATE/1000)); x[:n]*=np.sin(np.linspace(0,np.pi/2,n))**2
            n=min(len(x),round(.035*RATE)); x[-n:]*=np.cos(np.linspace(0,np.pi/2,n))**2
            target=records[entry['id']]['samples'][0]['attack_300ms_rms']*level['rms_ratio']
            if profile: target*=10**(sustained['onset_gain_db']/20)
            gain=min(.32/np.max(np.abs(x)),target/max(1e-12,np.sqrt(np.mean(x[:round(.3*RATE)]**2))))
            x*=gain
            path=ROOT/f'audio/arsenal/dynamics/dyn_{entry["id"]}_{index}.wav'; save(path,x)
            sidecar=path.with_suffix('.wav.import')
            if sidecar.exists():
                text=sidecar.read_text(encoding='utf-8')
                sidecar.write_text(text.replace('compress/mode=2','compress/mode=0'),encoding='utf-8')
            layers.append({'strength':index,'label':level['label'],'file':path.relative_to(ROOT).as_posix(),'sha256':digest(path),'root_midi':entry['root_midi'],'program':entry['program'],'velocity':level['velocity'],'hold':hold,'release':release,'attack_ms':attack,'cutoff_hz':cutoff,'harmonic_tilt_db':level['harmonic_tilt_db'],'tone_split_hz':split,'seconds':len(x)/RATE,'peak':float(np.max(np.abs(x))),'rms':float(np.sqrt(np.mean(x*x))),'attack_300ms_rms':float(np.sqrt(np.mean(x[:round(.3*RATE)]**2))),'preset':result.stdout.strip(),'normalization_gain':float(gain)})
            if profile:layers[-1].update(sustained_salvo=True,body_swell=sustained['body_swell'],requested_onset_gain_db=sustained['onset_gain_db'])
            if fixed_duration:layers[-1]['duration_seconds']=fixed_duration['duration_seconds']
            if profile and 'sustain_program' in profile:layers[-1].update(acoustic_sustain_layer={"program":profile['sustain_program'],"root_midi":entry['root_midi'],"mix":profile['sustain_mix'],"onset_seconds":profile.get('sustain_onset_seconds',.06),"fade_seconds":profile.get('sustain_fade_seconds',.22)})
        output.append({'id':entry['id'],'instrument':entry['instrument'],'family':entry['instrument_family'],'balance_db':policy['balance_db'][entry['id']],'layers':layers})
        if entry['id'] in policy.get('sustained_salvos',{}).get('profiles',{}):output[-1]['performance_instrument']=policy['sustained_salvos']['profiles'][entry['id']]['voice_label']
        print(entry['id'],[round(s['attack_300ms_rms'],4) for s in layers],flush=True)
    manifest={k:old[k] for k in ['source','homepage','license','soundfont_sha256','renderer','renderer_sha256','format']}
    manifest.update(revision=policy['revision'],policy_sha256=digest(policy_path),renderer_driver_sha256=digest(ROOT/'tools/render_instrument_note.c'),scope='76independent same-root performances;source velocity zones,envelope/hold/release/lowpass and optional same-root bowed acoustic body for sustained salvos. Not four independent acoustic recordings. Original152 pitch samples untouched;no added oscillator,drum,electronic layer,pitch shift or time stretching.',weapons=output)
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Built',len(selected)*len(strengths),'performance layers;others preserved')
if __name__=='__main__': main()
