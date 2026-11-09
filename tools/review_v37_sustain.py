"""Measure actual held-body energy and export before/after salvo auditions."""
from pathlib import Path
import io,json,subprocess,wave,hashlib
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
RATE=22050
def load(raw):
    with wave.open(io.BytesIO(raw)) as f:
        assert f.getframerate()==RATE and f.getnchannels()==1 and f.getsampwidth()==2
        return np.frombuffer(f.readframes(f.getnframes()),'<i2').astype(float)/32768
def save(path,x):
    with wave.open(str(path),'wb') as f:
        f.setparams((1,2,RATE,0,'NONE','not compressed'));f.writeframes(np.rint(np.clip(x,-.98,.98)*32767).astype('<i2').tobytes())
def stats(x):
    energy=np.cumsum(x*x)
    return {'seconds':len(x)/RATE,'t95_energy_seconds':float(np.searchsorted(energy,energy[-1]*.95)/RATE),'onset_300ms_rms':float(np.sqrt(np.mean(x[:round(.3*RATE)]**2))),'body_600_1300ms_rms':float(np.sqrt(np.mean(x[round(.6*RATE):round(1.3*RATE)]**2))) if len(x)>=round(1.3*RATE) else None,'peak':float(np.max(np.abs(x)))}
def main():
    out=ROOT/'docs/data-v37';audio=ROOT/'docs/audio-v37';out.mkdir(exist_ok=True);audio.mkdir(exist_ok=True)
    manifest=json.loads((ROOT/'audio/instruments/DYNAMICS_MANIFEST.json').read_text(encoding='utf-8'))
    old=json.loads((ROOT/'audio/instruments/archives/DYNAMICS_MANIFEST-before-v37.json').read_text(encoding='utf-8'))
    previous={w['id']:w for w in old['weapons']};review=[];preserved=0;changed=0;clips={}
    for w in manifest['weapons']:
        for layer,baseline in zip(w['layers'],previous[w['id']]['layers']):
            raw=(ROOT/layer['file']).read_bytes();digest=hashlib.sha256(raw).hexdigest();assert digest==layer['sha256']
            if digest==baseline['sha256']:preserved+=1;continue
            assert layer.get('sustained_salvo') and layer['strength'] in [2,3]
            before_raw=subprocess.run(['git','show','31ed97e:'+layer['file']],capture_output=True,check=True).stdout
            a=load(before_raw);b=load(raw);before=stats(a);after=stats(b)
            gain=20*np.log10(after['onset_300ms_rms']/before['onset_300ms_rms'])+w['balance_db']-previous[w['id']]['balance_db']
            assert 2.9<gain<3.1 and 2.1<after['seconds']<3.4
            assert after['t95_energy_seconds']>before['t95_energy_seconds']*1.2
            assert after['body_600_1300ms_rms']>.005 and after['peak']<=.321
            assert b[0]==0 and b[-1]==0
            assert layer['root_midi']==baseline['root_midi']
            review.append({'id':w['id'],'strength':layer['strength'],'before':before,'after':after,'effective_onset_gain_db':float(gain),'acoustic_sustain_layer':layer.get('acoustic_sustain_layer')});changed+=1
            if layer['strength']==3:clips[w['id']]=(a,b)
    assert changed==20 and preserved==56
    # Original composer samples must remain exact.
    original=json.loads((ROOT/'audio/instruments/MANIFEST.json').read_text(encoding='utf-8'));original_count=0
    for w in original['instruments']:
        for layer in w['samples']:
            assert hashlib.sha256((ROOT/layer['file']).read_bytes()).hexdigest()==layer['sha256'];original_count+=1
    blocks=[];timeline=[]
    for kind in ['scatter_prism','tidal_weave','firefly_rain']:
        for name,x in zip(['before','after'],clips[kind]):
            # Equal onset RMS makes the added body easier to compare.
            x=x*(.045/max(1e-12,np.sqrt(np.mean(x[:round(.3*RATE)]**2))))
            block=np.zeros(round(3.6*RATE));block[:len(x)]=x;blocks.append(block)
            timeline.append({'weapon':kind,'version':name,'start_seconds':(len(blocks)-1)*3.6,'onset_rms':.045})
    save(audio/'sustained-voices-before-after.wav',np.concatenate(blocks))
    (audio/'sustained-voices-before-after.json').write_text(json.dumps({'scope':'Three acoustic examples,old then new,3.6s per sound. Onset300ms RMS matched;body/decay deliberately differ. Single-source offline timbre review,not captured gameplay.','timeline':timeline},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    result={'verified_layers':20,'failures':[],'changed_performance_layers':changed,'preserved_performance_layers':preserved,'preserved_composer_pitch_samples':original_count,'scope':'Changed20strong/verystrong layers:exact hash/mono PCM,3dB effective attack increase,2.1–3.4s file duration,T95atleast20%later,nonzero600–1300ms held body,peak/root/click-free endpoints;56other layers and152pitch samples exact. Measurements do not certify subjective sound quality.','layers':review}
    (out/'sustain-review.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('PASS20sustained layers,56other performances and152pitch samples preserved')
    print('T95range',min(x['after']['t95_energy_seconds'] for x in review),max(x['after']['t95_energy_seconds'] for x in review))
if __name__=='__main__':main()
