"""Verify a cleanly extracted Windows demo, using only its shipped runtime files.

Godot's official release template disallows --script/--main-pack overrides.
Resource/API assertions therefore use the matching editor on the exact shipped
PCK; actual release EXE boots are tested separately under both renderers.
"""
from pathlib import Path
import argparse,json,math,os,struct,subprocess,time,wave,zipfile,hashlib
import psutil

ROOT=Path(__file__).resolve().parents[1]
NAME='GrooveFlight_Demo_v0.49.0_Windows_x64'

def main():
 parser=argparse.ArgumentParser()
 parser.add_argument('--engine',default='D:/Tool/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe')
 args=parser.parse_args()
 archive=ROOT/'dist'/(NAME+'.zip')
 target=ROOT/'work'/('demo-clean-room-'+str(time.time_ns()))
 logs=ROOT/'work/demo-build';logs.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(archive) as z:
  assert z.testzip() is None
  z.extractall(target)
 folder=target/NAME;exe=folder/'GrooveFlightDemo.exe'
 env=os.environ.copy();env['APPDATA']=str(ROOT/'tests'/('profile-'+target.name))
 startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
 report={'archive':{'filename':archive.name,'bytes':archive.stat().st_size,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest()},'clean_extraction':str(folder),'boot_checks':[]}
 def run(command,name,timeout=120,collect_modules=False):
  with (logs/(name+'.log')).open('w',encoding='utf-8') as log:
   process=subprocess.Popen(command,cwd=folder,env=env,stdout=log,stderr=subprocess.STDOUT,startupinfo=startup)
   modules=set();deadline=time.monotonic()+timeout
   while process.poll() is None and time.monotonic()<deadline:
    if collect_modules:
     try:
      modules.update(m.path for m in psutil.Process(process.pid).memory_maps() if 'groove_crowd' in m.path.lower())
     except (psutil.NoSuchProcess,psutil.AccessDenied):pass
    time.sleep(.3)
   if process.poll() is None:process.kill();process.wait();raise RuntimeError(name+' timed out')
  text=(logs/(name+'.log')).read_text(encoding='utf-8',errors='replace')
  # --quit-after is an engine-forced shutdown. Preserve its known resource
  # cleanup diagnostic in the report without classifying it as a boot error.
  errors=[line for line in text.splitlines() if line.startswith('ERROR:')]
  shutdown=[line for line in errors if 'resources still in use at exit' in line]
  assert process.returncode==0 and 'SCRIPT ERROR' not in text and len(errors)==len(shutdown),(name,process.returncode,text[-6000:])
  return {'mode':name,'exit_code':process.returncode,'native_kernel_modules':sorted(modules),'shutdown_diagnostics':shutdown}
 packed=logs/'packed-resources.json'
 run([args.engine,'--headless','--path',str(folder),'--main-pack',str(exe.with_suffix('.pck')),'--script',str(ROOT/'tests/windows_demo_review.gd'),'--','--grooveflight-test','--report='+str(packed)],'packed-resources',150)
 data=json.loads(packed.read_text(encoding='utf-8'));assert not data['failures'] and data['checks']>=350
 report['packed_resources']=data
 for renderer in ['forward_plus','gl_compatibility']:
  result=run([str(exe),'--windowed','--resolution','1280x720','--position','-4000,-2000','--audio-driver','Dummy','--rendering-method',renderer,'--quit-after','300','--','--grooveflight-test'],'release-'+renderer,90,True)
  assert result['native_kernel_modules'],'Release did not load native crowd DLL: '+renderer
  report['boot_checks'].append(result)
 # A legal, generated four-note fixture tests decoding + the shipped ONNX/Python
 # runtime end to end, independently of installed Python packages or source data.
 tone=logs/'recognizer-tone.wav';rate=22050
 with wave.open(str(tone),'wb') as wav:
  wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(rate)
  samples=[]
  for i in range(rate*3):
   t=i/rate;step=min(3,int(t/.75));frequency=[261.6256,329.6276,391.9954,523.2511][step]
   phase=t% .75;gain=min(1.,phase/.015)*min(1.,max(0.,.70-phase)/.08)*.3
   samples.append(int(32767*gain*(math.sin(2*math.pi*frequency*t)+.2*math.sin(4*math.pi*frequency*t))))
  wav.writeframes(struct.pack('<'+'h'*len(samples),*samples))
 request=logs/'recognizer-request.json';output=logs/'recognizer-result.json';status=logs/'recognizer-status.json'
 request.write_text(json.dumps({'path':str(tone),'length':3,'bpm':80,'mode':'poly'}),encoding='utf-8')
 helper=folder/'tools/audio_recognizer/BeatDriftTranscribe/BeatDriftTranscribe.exe'
 run([str(helper),'--request',str(request),'--output',str(output),'--status',str(status)],'offline-recognizer',90)
 transcription=json.loads(output.read_text(encoding='utf-8'));assert transcription['ok'] and transcription['facts']['notes']>0,transcription
 report['offline_recognizer']=transcription['facts']
 (logs/'VERIFICATION.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps({'checks':data['checks'],'boot_modes':[x['mode'] for x in report['boot_checks']],'offline_recognizer':report['offline_recognizer'],'archive':report['archive']},ensure_ascii=False),flush=True)

if __name__=='__main__':main()
