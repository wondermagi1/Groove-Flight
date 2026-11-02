from pathlib import Path
import os,subprocess,sys,json,time
root=Path(__file__).resolve().parents[1]
work=root/'work/v11-test-logs';work.mkdir(parents=True,exist_ok=True)
engine=Path(os.environ.get('GODOT_PATH','D:/Tool/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'))
results=[]
gpu='--gpu' in sys.argv
movie='--movie' in sys.argv
forward='--forward' in sys.argv
for name in [x for x in sys.argv[1:] if x not in ['--gpu','--movie','--forward']]:
 env=os.environ.copy();env['APPDATA']=str(root/'tests'/('profile-v11-'+name))
 args=[str(engine)]+(['--rendering-method','forward_plus' if forward else 'gl_compatibility','--position','-4000,-2000','--resolution','1920x1080','--windowed'] if gpu else ['--headless'])+['--path',str(root),'--script','res://tests/'+name+'.gd','--','--beatdrift-test']
 if movie and name=='v11_native_sample': args[1:1]=['--write-movie',str(root/'work/v11-final-native.avi'),'--fixed-fps','30']
 start=time.time()
 try:
  p=subprocess.run(args,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=480 if name=='v11_native_sample' else 240)
  log=p.stdout+'\n'+p.stderr
  (work/(name+'.log')).write_text(log,encoding='utf-8')
  print(name,'EXIT',p.returncode,'%.1fs'%(time.time()-start),flush=True)
  print('\n'.join(x for x in log.splitlines() if 'Error' in x or 'ERROR' in x or 'Parse' in x)[:5000],flush=True)
  script_errors=[x for x in log.splitlines() if 'SCRIPT ERROR' in x or 'Parse Error' in x]
  results.append({'test':name,'exit':p.returncode or (1 if script_errors else 0),'seconds':time.time()-start,'script_errors':script_errors,'warnings':[x for x in log.splitlines() if 'WARNING:' in x or 'ERROR:' in x]})
 except subprocess.TimeoutExpired as e:
  print(name,'TIMEOUT',flush=True);results.append({'test':name,'exit':124})
(work/'latest-run.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
sys.exit(1 if any(x['exit'] for x in results) else 0)
