"""Archive matched render pairs and prove this small art pass is shader-only."""
from pathlib import Path
import hashlib,json,shutil,subprocess
R=Path(__file__).resolve().parents[1]
BASE='0d1087fa9cacbc481cd998de15fb65f15611dcb7'
def run():
 allowed={'shaders/cyber_battlefield.gdshader'};scope=['scripts','audio','assets','native','shaders','scenes']
 changed=subprocess.check_output(['git','diff','--name-only',BASE,'--',*scope],cwd=R).decode().splitlines();assert set(changed)==allowed,changed
 expected={}
 for row in filter(None,subprocess.check_output(['git','ls-tree','-r','-z',BASE,'--',*scope],cwd=R).decode().split('\0')):
  meta,path=row.split('\t')
  if path not in allowed:expected[path]=meta.split()[2]
 paths=sorted(expected);hashes=subprocess.check_output(['git','hash-object','--stdin-paths'],cwd=R,input=('\n'.join(paths)+'\n').encode()).decode().splitlines()
 assert len(paths)==len(hashes) and all(expected[p]==h for p,h in zip(paths,hashes))
 out=R/'docs/data-v62';out.mkdir(exist_ok=True);renders={};notices={}
 for renderer in ['forward_plus','gl_compatibility']:
  stage=R/'work/v50-runtime/tests';data=json.loads((stage/f'results-v62-{renderer}.json').read_text(encoding='utf-8'));assert data['renderer']==renderer
  log=(R/f'work/v62-{renderer}.log').read_text(encoding='utf-8');assert 'SCRIPT ERROR' not in log and 'Parse Error' not in log
  errors=[line for line in log.splitlines() if line.startswith('ERROR:')];assert all(line=='ERROR: Failed to read the root certificate store.' for line in errors),errors
  notices[renderer]=errors;renders[renderer]=data
  for source in data['captures']:
   name=Path(source).name;shutil.copy2(stage/name,R/'docs/screenshots'/name)
  (out/f'{renderer}.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
 summary={'version':'0.62.0-soft-star-sea','date':'2026-11-17','backup':BASE,'protected_runtime_files':len(paths),'change':'One broad softly varying luminous galaxy band; removed multiplicative dark dust mask and intersecting multi-frequency shadows; vignette32percent→14percent. Existing stars and cyber planet retained.','renderers':list(renders),'captures':sum(len(data['captures']) for data in renders.values()),'review':'Matched1080p before/after inspected.720p/1440p,three quality/exposure pairs and alternate planet positions rendered. Gameplay/input/audio/native files unchanged; no gameplay test reruns needed for this art-only pass.','environment_notices':notices,'certificate_scope':'Known Windows certificate-store startup error recorded;local render completed,no system certificate changes.'}
 (out/'SUMMARY.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(summary,ensure_ascii=False))
if __name__=='__main__':run()
