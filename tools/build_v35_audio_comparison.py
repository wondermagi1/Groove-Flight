"""Offline same-event before/after review; does not modify production assets."""
from pathlib import Path
from fractions import Fraction
import json, subprocess, wave
import numpy as np
from scipy.signal import resample_poly

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/audio-v35'
RATE=22050
SECONDS=15
FRAMES=RATE*SECONDS

def read(path):
    with wave.open(str(path),'rb') as w:
        sr,ch=w.getframerate(),w.getnchannels()
        a=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(np.float64).reshape(-1,ch)/32768.
    if sr!=RATE:
        ratio=Fraction(RATE,sr); a=resample_poly(a,ratio.numerator,ratio.denominator,axis=0)
    return np.repeat(a,2,axis=1) if ch==1 else a

def write(path,a):
    with wave.open(str(path),'wb') as w:
        w.setnchannels(2);w.setsampwidth(2);w.setframerate(RATE)
        w.writeframes(np.rint(a*32767).astype('<i2').tobytes())

def main():
    events=json.loads((ROOT/'docs/data-v35/audition-events.json').read_text(encoding='utf-8'))
    assert len(events['before_drums'])==16 and len(events['after_drums'])==12
    raw=subprocess.check_output(['ffmpeg','-hide_banner','-loglevel','error','-ss','60','-t',str(SECONDS),'-i',str(ROOT/'audio/authorized/scott_buckley/filaments.ogg'),'-ac','2','-ar',str(RATE),'-f','f32le','pipe:1'])
    background=np.frombuffer(raw,dtype='<f4').astype(np.float64).reshape(-1,2)[:FRAMES]
    sources={k:read(ROOT/f'audio/authorized/feedback/{k}.wav') for k in ['kill_low_strong','kill_low_soft','kill_low_round']}
    parts=[]
    for phase in ['before','after']:
        weapon=read(ROOT/f'work/v35/weapon-{phase}.wav')[:FRAMES]*10**(-2/20)*.58
        hits=events[phase+'_drums'];drums=np.zeros((FRAMES,2))
        for hit in hits:
            at=round(hit['at']*RATE);source=sources[hit['sample']];n=min(len(source),FRAMES-at)
            drums[at:at+n]+=source[:n]*10**(hit['volume']/20)
        duck=np.zeros(FRAMES)
        if phase=='after':
            active=np.zeros(FRAMES,dtype=bool)
            for e in events['notes']:active[round(e['at']*RATE):min(FRAMES,round((e['at']+.24)*RATE))]=True
            for e in hits:active[round(e['at']*RATE):min(FRAMES,round((e['at']+.32)*RATE))]=True
            level=0.;attack=np.exp(-1/(RATE*.035));release=np.exp(-1/(RATE*.38))
            for i,on in enumerate(active):
                target=-3. if on else 0.;factor=attack if target<level else release
                level=target+(level-target)*factor;duck[i]=level
        a=(weapon+drums+background*10**(-10/20)*.48*10**(duck[:,None]/20))*.75
        fade=round(.03*RATE);a[:fade]*=np.linspace(0,1,fade)[:,None];a[-fade:]*=np.linspace(1,0,fade)[:,None]
        parts.append(a)
    rms=[np.sqrt(np.mean(a*a)) for a in parts]
    crest=[np.max(np.abs(a))/v for a,v in zip(parts,rms)]
    target=min(10**(-24/20),.88/max(crest))
    parts=[a*target/v for a,v in zip(parts,rms)]
    write(OUT/'combat-before-after-30s.wav',np.concatenate(parts))
    result={'scope':'Offline same starter equipment and20kill clusters with old/current weapon charge and drum scheduler traces; original/current voices,slower quieter drum tails and smooth background space. Same before/after15s Filaments excerpt. Both halves RMS-matched,not live gameplay capture or subjective listening acceptance.',
        'before_seconds':[0,15],'after_seconds':[15,30],'sample_rate':RATE,'channels':2,'matched_rms_dbfs':float(20*np.log10(target)),
        'peaks':[float(np.max(np.abs(a))) for a in parts],'weapon_events_before':len(events['before_notes']),'weapon_events_after':len(events['notes']),
        'drums_before':len(events['before_drums']),'drums_after':len(events['after_drums']),
        'category_levels_before_matching':{'master':.75,'music':.48,'weapons':.58,'kill':1.},
        'credits':'Filaments by Scott Buckley,CC BY4.0. See CREDITS.md. Instrument and recorded feedback sources retain their existing credits.'}
    (OUT/'combat-before-after-30s.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result))
if __name__=='__main__':main()
