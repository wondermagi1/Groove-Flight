"""Verify doctrine routing changes preserve V42 weapon/audio/motion assets."""
from pathlib import Path
import hashlib,json,subprocess
R=Path(__file__).resolve().parents[1]
BASE='42187dc343a9cdf6bac51a2d27acb2349b8c55fc'
def previous(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=R)
def main():
 old=json.loads(previous('audio/weapon_codex.json'));samples={};failures=[]
 for row in old['weapons']:
  for entry in row['samples']:samples[entry['path'].removeprefix('res://')]=entry['sha256']
  for entry in row['dynamics']['layers']:samples[entry['file']]=entry['sha256']
 for path,sha in samples.items():
  if hashlib.sha256((R/path).read_bytes()).hexdigest()!=sha:failures.append(path)
 before=json.loads(previous('docs/data-v42/weapon-selection.json'))['weapons']
 after=json.loads((R/'docs/data-v43/weapon-selection.json').read_text(encoding='utf-8'))['weapons']
 if before!=after:failures.append('Production weapon profiles changed')
 retained=['scripts/projectile_fields.gd','scripts/energy_arsenal.gd','scripts/energy_growth.gd','scripts/weapon_visuals.gd','scripts/weapon_render.gd','scripts/salvo_patterns.gd','scripts/run_balance.gd','scripts/enemy_formations.gd']
 tracked=set(subprocess.check_output(['git','ls-tree','-r','--name-only',BASE],cwd=R,text=True).splitlines())
 retained=[p for p in retained if p in tracked]
 retained += [p for p in tracked if p.startswith('native/') and p.endswith(('.dll','.gdextension'))]
 for path in retained:
  if (R/path).read_bytes()!=previous(path):failures.append(path)
 report={'baseline':BASE,'old_wavs_verified':len(samples),'unchanged_weapon_profiles':len(before),'unchanged_files':retained,'failures':failures}
 (R/'docs/data-v43/asset-preservation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
 print('WAVs',len(samples),'weapon profiles',len(before),'failures',len(failures));assert not failures,failures
if __name__=='__main__':main()
