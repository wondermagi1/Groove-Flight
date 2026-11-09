"""Verify old audio and allowed V42 balance exceptions against uploaded V41."""
from pathlib import Path
import hashlib,json,subprocess
R=Path(__file__).resolve().parents[1]
BASE='8516717b8f03211f264160bf98dec6fe366a1fdb'
def old(path):return json.loads(subprocess.check_output(['git','show',BASE+':'+path],cwd=R))
def main():
 samples={};failures=[]
 for row in old('audio/weapon_codex.json')['weapons']:
  for s in row['samples']:samples[s['path'].removeprefix('res://')]=s['sha256']
  for s in row['dynamics']['layers']:samples[s['file']]=s['sha256']
 for path,sha in samples.items():
  if hashlib.sha256((R/path).read_bytes()).hexdigest()!=sha:failures.append(path)
 current={w['id']:w for w in json.loads((R/'docs/data-v42/weapon-selection.json').read_text(encoding='utf-8'))['weapons']}
 exceptions={'beam':{'damage':12.},'kaleidoscope':{'charge':4,'count':96}}
 fields=['family','damage','count','speed','life','spread','pierce','explosion','homing','bounces','charge','width','rarity','cost','voice','instrument','sample_root','visual_class','emission','color']
 for row in old('docs/data-v41/weapon-selection.json')['weapons']:
  for key in fields:
   expected=exceptions.get(row['id'],{}).get(key,row.get(key))
   if current[row['id']].get(key)!=expected:failures.append(row['id']+'/'+key)
 report={'baseline':BASE,'old_wavs_verified':len(samples),'allowed_weapon_changes':exceptions,'failures':failures}
 (R/'docs/data-v42/asset-preservation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
 print('old WAVs',len(samples),'failures',len(failures));assert not failures,failures
if __name__=='__main__':main()
