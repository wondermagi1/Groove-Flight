"""Measured sample verification and playable,level-matched V36 reviews."""
from pathlib import Path
import hashlib,json,wave
import numpy as np
from scipy.signal import welch
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT=Path(__file__).resolve().parents[1]
RATE=22050
def load(path):
    with wave.open(str(path)) as f:
        rate=f.getframerate(); channels=f.getnchannels()
        return np.frombuffer(f.readframes(f.getnframes()),'<i2').reshape(-1,channels).astype(float)/32768,rate
def save(path,data,rate=RATE):
    path.parent.mkdir(parents=True,exist_ok=True)
    data=np.asarray(data)
    with wave.open(str(path),'wb') as f:
        f.setparams((1 if data.ndim==1 else data.shape[1],2,rate,0,'NONE','not compressed'))
        f.writeframes(np.rint(np.clip(data,-.98,.98)*32767).astype('<i2').tobytes())
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def dump(path,data): path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def main():
    audio=ROOT/'docs/audio-v36'; data=ROOT/'docs/data-v36'; audio.mkdir(exist_ok=True); data.mkdir(exist_ok=True)
    manifest=json.loads((ROOT/'audio/instruments/DYNAMICS_MANIFEST.json').read_text(encoding='utf-8'))
    review=[]
    for weapon in manifest['weapons']:
        layers=[]; pcm=[]
        for layer in weapon['layers']:
            path=ROOT/layer['file'];x,rate=load(path);x=x[:,0];pcm.append(x)
            assert rate==RATE and digest(path)==layer['sha256'] and x[0]==0 and x[-1]==0
            freq,power=welch(x[:round(.15*RATE)],rate,nperseg=1024)
            layers.append({'strength':layer['strength'],'label':layer['label'],'seconds':len(x)/rate,'peak':float(np.max(np.abs(x))),'onset_300ms_rms':float(np.sqrt(np.mean(x[:round(.3*RATE)]**2))),'first150ms_spectral_centroid_hz':float(np.sum(freq*power)/np.sum(power))})
        residuals=[]
        for a,b in zip(pcm,pcm[1:]):
            n=min(len(a),len(b),round(.15*RATE));a=a[:n];b=b[:n]
            best_gain=np.dot(a,b)/np.dot(a,a)
            residuals.append(float(np.linalg.norm(b-best_gain*a)/np.linalg.norm(b)))
        assert min(residuals)>.025,'scaled-copy performance: '+weapon['id']
        assert all(a['onset_300ms_rms']<b['onset_300ms_rms'] for a,b in zip(layers,layers[1:]))
        review.append({'id':weapon['id'],'layers':layers,'adjacent_best_gain_copy_residual':residuals})
    # Timbre review deliberately removes the production loudness differences.
    examples=['pulse','beam','firefly_rain']; timeline=[]; blocks=[]
    fig,axes=plt.subplots(3,1,figsize=(11,8),layout='constrained')
    for ax,kind in zip(axes,examples):
        for strength in range(4):
            x,rate=load(ROOT/f'audio/arsenal/dynamics/dyn_{kind}_{strength}.wav');x=x[:,0]
            x*=.04/max(1e-12,np.sqrt(np.mean(x[:round(.3*RATE)]**2)))
            block=np.zeros(round(1.7*RATE));block[:len(x)]=x;blocks.append(block)
            timeline.append({'id':kind,'strength':strength,'start':(len(blocks)-1)*1.7,'normalization':'first300ms RMS=.04,not a perceptual loudness certification'})
            f,p=welch(x[:round(.15*RATE)],RATE,nperseg=2048)
            ax.semilogx(f[1:],10*np.log10(p[1:]+1e-12),label=['pp','p','mf','f'][strength])
        ax.set(title=kind,xlim=(80,8000),ylim=(-110,-25),ylabel='Power / Hz (dB)');ax.legend();ax.grid(alpha=.2)
    axes[-1].set_xlabel('Frequency (Hz)');fig.savefig(audio/'equal-level-spectra.png',dpi=140);plt.close(fig)
    save(audio/'timbre-equal-level-20s.wav',np.concatenate(blocks))
    dump(audio/'timbre-equal-level-20s.json',{'scope':'Three instrument examples,pp/p/mf/f four performances each at1.7s spacing. First300ms RMS matched so tone/envelope differences can be heard without the original dynamic gain difference. Not captured gameplay or human loudness matching.','timeline':timeline})
    # Production renderer exported identical events for both18second halves.
    halves=[];stats=[]
    for name in ['flat','expressive']:
        x,rate=load(ROOT/f'work/v36/{name}.wav');assert rate==RATE and len(x)==18*RATE
        gain=10**(-25/20)/np.sqrt(np.mean(x*x));x*=gain;halves.append(x)
        stats.append({'name':name,'gain':float(gain),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(x*x)))),'peak':float(np.max(np.abs(x)))})
    assert max(v['peak'] for v in stats)<.95
    save(audio/'phrases-before-after-36s.wav',np.concatenate(halves))
    dump(audio/'phrases-before-after-36s.json',{'scope':'0–18s V35fixed single samples,18–36s V36independent performance layers. Same weapon events and positions,weapon-only production PCM. Both halves matched to-25dBFS RMS. Not live gameplay capture.','halves':stats,'events':'docs/data-v36/audition-events.json'})
    # Same user video; reference-only waveform evidence,not a new game source.
    source=ROOT/'audio/library/groove_core/working/weapon_ballistic_volume_ramp/extracted_audio.wav';x,rate=load(source);mono=x.mean(1)
    reference=[]
    for i,start in enumerate([.610,1.610,2.610,3.610]):
        clip=x[round(start*rate):round((start+.42)*rate)];name=f'reference-note-{i+1}.wav';save(audio/name,clip,rate)
        f,p=welch(clip.mean(1),rate,nperseg=2048)
        reference.append({'start':start,'end':start+.42,'file':'docs/audio-v36/'+name,'rms':float(np.sqrt(np.mean(clip*clip))),'spectral_centroid_hz':float(np.sum(f*p)/np.sum(p))})
    dump(data/'reference-comparison.json',{'source':'武器实弹的 音乐声音（由轻到重）.mp4','container_sha256':digest(ROOT/'audio/library/groove_core/raw/weapon_ballistic_volume_ramp/武器实弹的 音乐声音（由轻到重）.mp4'),'pcm_sha256':digest(source),'full_duration':len(x)/rate,'method':'First four regularly spaced source events,exact stereo PCM slices,no gain or filtering. Spectra and energy are measured;neither prove four clean velocity recordings nor rule out different pitches or mixed sounds. Use as user-provided reference,not installed weapon assets.','clips':reference})
    dump(data/'sample-review.json',{'scope':'76independently rendered performances,first150ms comparison after least-squares scalar gain removal. Nonzero residual disproves a gain-only copy but does not certify subjective realism. No claim of four independent acoustic recordings.','weapons':review})
    print('Verified76layers; minimum adjacent gain-copy residual',min(min(w['adjacent_best_gain_copy_residual']) for w in review));print('36second comparison',stats)
if __name__=='__main__':main()
