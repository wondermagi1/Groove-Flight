"""V54: beat-tracked timing/hold cues for three equipment-bound scoring lanes.

This is an algorithmic gameplay arrangement, not exact instrument transcription.
Original full audio and all weapon samples are untouched. Requires numpy/scipy.
"""
from pathlib import Path
import argparse,hashlib,json,shutil,subprocess
import numpy as np
from scipy.ndimage import gaussian_filter1d,median_filter
from scipy.signal import fftconvolve,find_peaks
ROOT=Path(__file__).resolve().parents[1]
def track_beats(novelty,frame_seconds):
 ac=fftconvolve(novelty-novelty.mean(),(novelty-novelty.mean())[::-1],mode='full')[len(novelty)-1:]
 lags=np.arange(round(.39/frame_seconds),round(.91/frame_seconds))
 period_frames=int(lags[np.argmax(ac[lags])]);period=period_frames*frame_seconds
 # Dynamic-programming beat path follows local onsets instead of placing one
 # free-running global grid across an expressive orchestral performance.
 envelope=novelty/max(1e-8,float(np.percentile(novelty,85)))
 score=np.zeros(len(envelope));previous=np.full(len(envelope),-1,dtype=np.int32)
 offsets=np.arange(round(period_frames*.70),round(period_frames*1.31)+1)
 penalty=55.*np.log(offsets/period_frames)**2
 for i in range(len(envelope)):
  valid=offsets<=i
  if np.any(valid):
   parents=i-offsets[valid];values=score[parents]*.98-penalty[valid];which=int(np.argmax(values))
   if values[which]>0:previous[i]=parents[which];score[i]=values[which]
  score[i]+=min(5.,float(envelope[i]))
 tail=max(0,len(score)-round(2.5/frame_seconds));cursor=tail+int(np.argmax(score[tail:]))
 beats=[]
 while cursor>=0:beats.append(cursor*frame_seconds);cursor=int(previous[cursor])
 beats=sorted(beats)
 if not beats:beats=[.25]
 while beats[0]>.2+period:beats.insert(0,beats[0]-period)
 while beats[-1]<len(novelty)*frame_seconds-period:beats.append(beats[-1]+period)
 return np.array(beats),period
def build(row,ffmpeg):
 source=ROOT/row['runtime'].removeprefix('res://');rate=11025;width=1024;hop=256;dt=hop/rate
 audio=np.frombuffer(subprocess.check_output([ffmpeg,'-v','error','-i',str(source),'-f','f32le','-ac','1','-ar',str(rate),'-']),dtype='<f4')
 windows=np.lib.stride_tricks.sliding_window_view(audio,width)[::hop]
 spec=np.empty((len(windows),width//2+1),dtype=np.float32)
 for i in range(0,len(windows),1024):spec[i:i+1024]=np.abs(np.fft.rfft(windows[i:i+1024]*np.hanning(width),axis=1))
 frequencies=np.fft.rfftfreq(width,1/rate);band=(frequencies>=80)&(frequencies<4500)
 log=np.log1p(spec[:,band]*20.);flux=gaussian_filter1d(np.maximum(np.diff(log,axis=0,prepend=log[:1]),0.).sum(axis=1),.7)
 baseline=median_filter(flux,size=129,mode='nearest');onset=flux/np.maximum(baseline,np.percentile(flux,45)*.3+1e-5)
 beats,period=track_beats(np.maximum(onset-.85,0.),dt);rms=np.sqrt(np.mean(windows**2,axis=1))
 peaks,_=find_peaks(onset,distance=round(.18/dt),prominence=.75,height=1.4)
 onset_times=np.maximum(0.,peaks*dt+width*.5/rate-.025)
 duration=len(audio)/rate;selected=[]
 def candidate(t,beat,origin):
  frame=min(len(onset)-1,max(0,round(t/dt)));strength=float(onset[frame])
  selected.append({'t':t,'beat':beat,'frame':frame,'strength':strength,'origin':origin})
 for i,center in enumerate(beats):
  t=center+width*.5/rate-.025
  nearest=int(np.argmin(abs(onset_times-t))) if len(onset_times) else -1
  if nearest>=0 and abs(float(onset_times[nearest])-t)<.075:t=float(onset_times[nearest]);origin='beat_onset'
  else:origin='tracked_beat'
  if .18<t<duration-.5:candidate(t,float(i),origin)
  if i+1<len(beats):
   middle=(center+beats[i+1])*.5+width*.5/rate-.025
   nearest=int(np.argmin(abs(onset_times-middle))) if len(onset_times) else -1
   if nearest>=0 and abs(float(onset_times[nearest])-middle)<.055 and .18<middle<duration-.5:
    frame=int(peaks[nearest])
    if onset[frame]>=1.8:candidate(float(onset_times[nearest]),i+.5,'audible_subdivision')
 # Minimum spacing and sparse-gap repair retain readable gestures and bounded
 # weapon deferral. Repairs stay on subdivisions of neighbouring tracked beats.
 thin=[]
 for e in sorted(selected,key=lambda e:e['strength'],reverse=True):
  if all(abs(e['t']-other['t'])>=.235 for other in thin):thin.append(e)
 thin.sort(key=lambda e:e['t'])
 for a,b in list(zip(thin,thin[1:])):
  if b['t']-a['t']>.95:
   t=(a['t']+b['t'])*.5;frame=min(len(onset)-1,round(t/dt))
   thin.append({'t':t,'beat':(a['beat']+b['beat'])*.5,'frame':frame,'strength':float(onset[frame]),'origin':'beat_subdivision'})
 thin.sort(key=lambda e:e['t'])
 accent=np.quantile([e['strength'] for e in thin],.72)
 events=[];meter=7 if row['planet']=='uranus' else 4;phrase_size=meter*2;skip=set()
 for i,e in enumerate(thin):
  if i in skip:continue
  phrase=int(e['beat'])//phrase_size;position=int(e['beat'])%phrase_size
  kind='tap';hold=0.
  gap=thin[i+1]['t']-e['t'] if i+1<len(thin) else duration-e['t']
  after=min(len(rms)-1,e['frame']+round(.3/dt));sustain=float(rms[after])>=float(rms[e['frame']])*.64
  if row['planet']=='saturn' and position in [2,6] and sustain and i+2<len(thin) and thin[i+1]['strength']<accent and thin[i+2]['t']-e['t']>=.48:
   hold=round(min(.65,thin[i+2]['t']-e['t']-.145),3);kind='hold';skip.add(i+1)
  elif position in [meter-1,phrase_size-1] and gap>=.48 and sustain:
   hold=round(min(.65,gap-.145,max(.3,period*.5)),3);kind='hold'
  strong=bool(position in [0,meter,phrase_size-1] and e['strength']>=accent and e['origin'] in ['beat_onset','audible_subdivision'])
  events.append({'t':round(e['t'],4),'kind':kind,'hold':hold,'strength':round(min(e['strength'],12),3),'origin':e['origin'],'beat':round(e['beat'],3),'measure':int(e['beat']//meter),'phrase':phrase,'accent':position in [0,meter] or strong})
 counts={kind:sum(e['kind']==kind for e in events) for kind in ['tap','hold']}
 chart={'schema':3,'planet':row['planet'],'id':row['id'],'title':row['title'],'artist':row['artist'],'source':row['runtime'],'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'duration':round(duration,6),'estimated_bpm':round(60/period,3),'meter':('7/8' if meter==7 else '4-pulse arrangement'),'keys':['J','K','L'],'tracks':['A','B','C'],'lane_mode':'weapon_track','method':'dynamic-programming local beat path, nearby audible onset anchors and sustained phrase endings; input lane follows actual equipment track','events':events}
 out=ROOT/'audio/charts/planets';out.mkdir(exist_ok=True);(out/(row['planet']+'.json')).write_text(json.dumps(chart,ensure_ascii=False,separators=(',',':')),encoding='utf-8')
 report={'planet':row['planet'],'title':row['title'],'duration':chart['duration'],'bpm_estimate':chart['estimated_bpm'],'counts':counts,'cue_count':len(events),'max_gap':max(b['t']-a['t'] for a,b in zip(events,events[1:])),'audible_anchors':sum(e['origin'] in ['beat_onset','audible_subdivision'] for e in events),'source_sha256':chart['source_sha256'],'claim':'Automatic beat/phrase gameplay arrangement. No exact instrumental MIDI or human listening approval claim.'}
 print(json.dumps(report,ensure_ascii=False),flush=True);return report
def run():
 parser=argparse.ArgumentParser();parser.add_argument('--planet');args=parser.parse_args()
 rows=json.loads((ROOT/'audio/PLANET_MUSIC.json').read_text(encoding='utf-8'))['tracks'];reports=[]
 for row in rows:
  if not args.planet or row['planet']==args.planet:reports.append(build(row,shutil.which('ffmpeg')))
 out=ROOT/'audio/charts/planets/ANALYSIS.json'
 if args.planet and out.exists():
  old=json.loads(out.read_text(encoding='utf-8'))['reports'];by_id={r['planet']:r for r in old};by_id.update({r['planet']:r for r in reports});reports=list(by_id.values())
 out.write_text(json.dumps({'revision':'v54','reports':reports},ensure_ascii=False,indent=2),encoding='utf-8')
if __name__=='__main__':run()
