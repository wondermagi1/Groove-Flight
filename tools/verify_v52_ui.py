"""Archive current UI checks and prove the presentation-only scope against backup."""
from pathlib import Path
import json,subprocess,shutil,re
ROOT=Path(__file__).resolve().parents[1]
BASE='c22af8bd6b7b3cfc90fb9129ebf0d5cc45bbc635'
ALLOWED={f'scripts/{n}.gd' for n in ['ui','arsenal_screen','rhythm_tiles','fleet_picker','solar_map','weapon_codex','composer_screen','ui_materials']}
def run():
 changed=subprocess.check_output(['git','diff','--name-only',BASE,'--','scripts','audio','assets','native','shaders','scenes'],cwd=ROOT).decode().splitlines()
 assert set(changed)<=ALLOWED,changed
 tree=subprocess.check_output(['git','ls-tree','-r','-z',BASE,'--','scripts','audio','native','shaders','scenes'],cwd=ROOT).decode().split('\0')
 expected={}
 for entry in filter(None,tree):
  meta,path=entry.split('\t')
  if path not in ALLOWED:expected[path]=meta.split()[2]
 paths=sorted(expected)
 hashes=subprocess.check_output(['git','hash-object','--stdin-paths'],cwd=ROOT,input=('\n'.join(paths)+'\n').encode()).decode().splitlines()
 assert len(paths)==len(hashes) and all(expected[p]==h for p,h in zip(paths,hashes)),'Non-UI production inputs changed'
 report=ROOT/'docs/data-v52';report.mkdir(exist_ok=True);stage=ROOT/'work/v50-runtime/tests'
 reviews={}
 for name,filename in [('ui','results-v52-ui'),('chart','results-v51-chart'),('live','results-v51-live'),('native','results-v51-native')]:
  result=json.loads((stage/(filename+'.json')).read_text(encoding='utf-8'));assert not result['failures'];reviews[name]=result
  (report/(name+'.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
 for path in reviews['ui']['captures']:
  name=Path(path).name;shutil.copy2(stage/name,ROOT/'docs/screenshots'/name)
 summary={'version':'0.52.0-ui-harmony','date':'2026-11-11','backup':BASE,'branch':'codex/ui-harmony','checks':{k:v['checks'] for k,v in reviews.items()},'native_renderer':reviews['ui']['renderer'],'unchanged_non_ui_files':len(expected),'unchanged_all_arsenal_wavs':len([p for p in paths if p.startswith('audio/arsenal/') and p.endswith('.wav')]),'unchanged_active_weapons':24,'unchanged_active_wavs':288,'main_rhythm_gate_chart_voices_bgm_background_native':'unchanged byte content via Git blob hashes','screenshots':len(reviews['ui']['captures']),'scope':'Neutral UI materials, hierarchy and presentation only. Actual Forward+ screenshots reviewed for layout; test combat uses acquired equipment and direct-fire visual fixtures. Existing rhythm/transport input tests remain mandatory. No performance or subjective music approval claim; historical demo and user presentation untouched.'}
 (report/'SUMMARY.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(summary,ensure_ascii=False))
 for filename in ['docs/V52_UI_HARMONY.md','docs/WEAPON_VFX_AUDIO_REFERENCE.md']:
  doc=ROOT/filename
  for target in re.findall(r'\]\(([^)]+)\)',doc.read_text(encoding='utf-8')):
   if '://' in target or target.startswith('#'):continue
   assert (doc.parent/target.split('#')[0]).exists(),target
if __name__=='__main__':run()
