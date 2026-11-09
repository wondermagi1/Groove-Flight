"""Visual polish may not change combat,source audio or numerical crowd assets."""
from pathlib import Path
import hashlib,json,subprocess
R=Path(__file__).resolve().parents[1]
BASE='059ceb2ebc096766db743fcf0a0abc63f26796a1'
def old(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=R)
def main():
 before=json.loads(old('audio/weapon_codex.json'));samples={};failures=[]
 for row in before['weapons']:
  for entry in row['samples']:samples[entry['path'].removeprefix('res://')]=entry['sha256']
  for entry in row['dynamics']['layers']:samples[entry['file']]=entry['sha256']
 for path,sha in samples.items():
  if hashlib.sha256((R/path).read_bytes()).hexdigest()!=sha:failures.append(path)
 stable=['main','arsenal_loadout','arsenal_catalog','combat_doctrines','fleet_catalog','run_balance','enemy_maneuver','enemy_arrival','projectile_fields','weapon_emission','weapon_visuals','weapon_render','energy_arsenal','energy_growth','music','salvo_patterns']
 paths=['scripts/'+name+'.gd' for name in stable]+['native/crowd/crowd.cpp','native/crowd/crowd.gdextension','native/crowd/groove_crowd.windows.x86_64.dll']
 for path in paths:
  current=(R/path).read_bytes();previous=old(path)
  # Git stores these sources as LF;an untouched CRLF checkout is equivalent.
  if not path.endswith('.dll'):current=current.replace(b'\r\n',b'\n');previous=previous.replace(b'\r\n',b'\n')
  if current!=previous:failures.append(path)
 weapons=json.loads((R/'docs/data-v44/weapon-selection.json').read_text(encoding='utf-8'))['weapons']
 if weapons!=json.loads(old('docs/data-v43/weapon-selection.json'))['weapons']:failures.append('Production weapon profile changed')
 report={'baseline':BASE,'old_wavs_verified':len(samples),'unchanged_weapon_profiles':len(weapons),'unchanged_files':paths,'comparison':'WAV/DLL raw SHA/bytes;source content normalized to Git LF line endings','failures':failures}
 (R/'docs/data-v44/asset-preservation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
 print('preserved WAVs',len(samples),'weapon profiles',len(weapons),'combat files',len(paths),'failures',len(failures));assert not failures,failures
if __name__=='__main__':main()
