"""Derive a reproducible gameplay chart from the licensed full Filaments OGG.

Onset/energy/chroma estimates, not a transcription or instrument separation.
Quiet gaps receive beat subdivisions; type/lane choices are game arrangement.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,shutil
import numpy as np
from scipy.ndimage import median_filter,gaussian_filter1d
from scipy.signal import find_peaks,fftconvolve

ROOT=Path(__file__).resolve().parents[1]
def build():
 parser=argparse.ArgumentParser();parser.add_argument('--ffmpeg',default=shutil.which('ffmpeg'));args=parser.parse_args()
 source=ROOT/'audio/authorized/scott_buckley/filaments.ogg';rate=11025;hop=128;width=1024
 raw=subprocess.check_output([args.ffmpeg,'-v','error','-i',str(source),'-f','f32le','-ac','1','-ar',str(rate),'-'])
 audio=np.frombuffer(raw,dtype='<f4');duration=len(audio)/rate
 windows=np.lib.stride_tricks.sliding_window_view(audio,width)[::hop]
 spec=np.empty((len(windows),width//2+1),dtype=np.float32)
 for i in range(0,len(windows),1024):spec[i:i+1024]=np.abs(np.fft.rfft(windows[i:i+1024]*np.hanning(width),axis=1))
 freqs=np.fft.rfftfreq(width,1/rate);musical=(freqs>=80)&(freqs<4500)
 log=np.log1p(spec[:,musical]*20.)
 novelty=np.maximum(np.diff(log,axis=0,prepend=log[:1]),0.).sum(axis=1)
 novelty=gaussian_filter1d(novelty,1.)
 local=median_filter(novelty,size=257,mode='nearest')
 normalized=novelty/np.maximum(local,np.percentile(novelty,45)*.3+1e-5)
 peaks,_=find_peaks(normalized,distance=round(.18*rate/hop),prominence=.9,height=1.5)
 times=np.maximum(0.,(peaks*hop+width*.5)/rate-.025)
 strength=normalized[peaks]
 # A global pulse is used only to fill sparse spaces between audible onsets.
 ac=fftconvolve(novelty-novelty.mean(),(novelty-novelty.mean())[::-1],mode='full')[len(novelty)-1:]
 lags=np.arange(round(.33*rate/hop),round(.8*rate/hop));best=int(lags[np.argmax(ac[lags])]);beat=best*hop/rate
 phase_bins=np.linspace(0,beat,65);hist=np.histogram(times%beat,bins=phase_bins,weights=np.minimum(strength,8.))[0]
 phase=float((phase_bins[np.argmax(hist)]+phase_bins[np.argmax(hist)+1])*.5)
 candidates=[{'t':float(t),'strength':float(s),'origin':'onset','frame':int(frame)} for t,s,frame in zip(times,strength,peaks)]
 # Thin very close candidates by strength so four-finger play stays legible.
 selected=[]
 for e in sorted(candidates,key=lambda e:e['strength'],reverse=True):
  if e['t']>.12 and e['t']<duration-.8 and all(abs(e['t']-q['t'])>=.22 for q in selected):selected.append(e)
 selected.sort(key=lambda e:e['t'])
 grid=np.arange(phase,duration-.5,beat*.5)
 for t in grid:
  if t<.2:continue
  if not selected or min(abs(t-q['t']) for q in selected)>.39:
   selected.append({'t':float(t),'strength':1.,'origin':'beat_fill','frame':min(len(spec)-1,round(t*rate/hop))})
 selected.sort(key=lambda e:e['t'])
 # Low-to-high spectral register maps to H/J/K/L. Chords use a second strong
 # pitch class, but are an arrangement suggestion rather than exact MIDI.
 midi=69+12*np.log2(np.maximum(freqs,1)/440.)
 register=(midi>=45)&(midi<=88)
 pitches=[]
 for e in selected:
  frame=e['frame'];energy=spec[frame:frame+3].mean(axis=0)
  pitches.append(float(np.sum(energy[register]*midi[register])/max(1e-8,energy[register].sum())))
 quantiles=np.quantile(pitches,[.25,.5,.75]);accent=np.quantile([e['strength'] for e in selected],.70)
 rms=np.sqrt(np.mean(windows**2,axis=1));events=[]
 for i,e in enumerate(selected):
  lane=int(np.searchsorted(quantiles,pitches[i]));next_t=selected[i+1]['t'] if i+1<len(selected) else duration
  frame=e['frame'];after=min(len(rms)-1,frame+round(.3*rate/hop))
  sustained=float(rms[after])>=float(rms[frame])*.62
  gap=next_t-e['t'];kind='tap';hold=0.;lanes=[lane]
  if e['origin']=='onset' and gap>=.52 and sustained:
   kind='hold';hold=round(min(.65,max(.3,gap-.14)),3)
  elif e['origin']=='onset' and e['strength']>=accent and i%3!=0:
   energy=spec[frame:frame+3].mean(axis=0);chroma=np.zeros(12)
   for pc in range(12):chroma[pc]=energy[register&(np.round(midi).astype(int)%12==pc)].sum()
   top=np.argsort(chroma)[-2:];second=(lane+1+int(top[0])%3)%4
   kind='chord';lanes=sorted([lane,second])
  events.append({'t':round(e['t'],4),'lanes':lanes,'kind':kind,'hold':hold,'strength':round(min(e['strength'],12),3),'origin':e['origin']})
 out=ROOT/'audio/charts';out.mkdir(exist_ok=True)
 chart={'schema':1,'id':'filaments','title':'Filaments','artist':'Scott Buckley','source':'res://audio/authorized/scott_buckley/filaments.ogg','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'duration':round(duration,6),'estimated_bpm':round(60/beat,3),'keys':['H','J','K','L'],'method':'spectral-flux onsets / local energy sustain / chroma-register arrangement / pulse subdivision gap fill','events':events}
 (out/'filaments.json').write_text(json.dumps(chart,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
 counts={kind:sum(e['kind']==kind for e in events) for kind in ['tap','hold','chord']}
 evidence={'schema':1,'duration':duration,'source_sha256':chart['source_sha256'],'analysis_rate':rate,'window':width,'hop':hop,'estimated_bpm':chart['estimated_bpm'],'counts':counts,'onset_count':sum(e['origin']=='onset' for e in events),'subdivision_count':sum(e['origin']=='beat_fill' for e in events),'min_gap':min(b['t']-a['t'] for a,b in zip(events,events[1:])),'max_gap':max(b['t']-a['t'] for a,b in zip(events,events[1:])),'register_quantiles':quantiles.tolist(),'claim':'Algorithmic arrangement derived from the audio waveform; not exact piano transcription or human-approved beat tracking.'}
 (out/'filaments-analysis.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps(evidence,ensure_ascii=False),flush=True)
if __name__=='__main__':build()
