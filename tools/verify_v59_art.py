"""Archive native rhythm-art review; protect every gameplay/audio input."""
from pathlib import Path
import hashlib,json,shutil,subprocess
R=Path(__file__).resolve().parents[1]
BASE='2ca15935d1f1ac2305d178857e1a01bb3e416fe5'
ALLOWED={'scripts/rhythm_tiles.gd','scripts/arsenal_screen.gd'}
def run():
 tree=subprocess.check_output(['git','ls-tree','-r','-z',BASE,'--','scripts','audio','assets','shaders','native','scenes'],cwd=R).decode().split('\0')
 expected={}
 for row in filter(None,tree):
  meta,path=row.split('\t')
  if path not in ALLOWED:expected[path]=meta.split()[2]
 paths=sorted(expected)
 hashes=subprocess.check_output(['git','hash-object','--stdin-paths'],cwd=R,input=('\n'.join(paths)+'\n').encode()).decode().splitlines()
 assert all(expected[p]==h for p,h in zip(paths,hashes))
 out=R/'docs/data-v59';out.mkdir(exist_ok=True);reviews={};notices={}
 for name in ['score','native']:
  data=json.loads((R/f'work/v50-runtime/tests/results-v59-{name}.json').read_text(encoding='utf-8'));assert not data['failures']
  log=(R/f'work/v59-{name}.log').read_text(encoding='utf-8');assert 'SCRIPT ERROR' not in log and 'Parse Error' not in log
  errors=[line for line in log.splitlines() if line.startswith('ERROR:')];assert all(line=='ERROR: Failed to read the root certificate store.' for line in errors)
  notices[name]=errors;reviews[name]=data;(out/f'{name}.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
 for source in reviews['native']['captures']:
  name=Path(source).name;shutil.copy2(R/'work/v50-runtime/tests'/name,R/'docs/screenshots'/name)
 for row in reviews['native']['geometry']:assert row['area_fraction']<=.081 and row['runway']>=238
 summary={'version':'0.59.0-rhythm-art','date':'2026-11-17','backup':BASE,'checks':{key:value['checks'] for key,value in reviews.items()},'geometry':reviews['native']['geometry'],'dock':'fixed bottom-right,18px inset','notes':'original vector cut-glass taps/gold ribbons/lilac equal-deadline links; held heads pinned to receptor; no score changes','lookahead':'unchanged2.2s / Echo2.8s; larger spatial runway is not a larger judgement window','protected_files':len(paths),'preserved_songs':8,'preserved_cues':3487,'preserved_active_weapons':24,'environment_notices':notices,'verification_scope':'Offline native Forward+ render/input and score checks; root-certificate startup error recorded, no network functionality certified.'}
 (out/'SUMMARY.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(summary,ensure_ascii=False))
if __name__=='__main__':run()
