"""Archive V60 native art/input evidence and protect music, weapons and physics."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess
R=Path(__file__).resolve().parents[1]
BASE='2e5f29d77733f88ebe98661ab4d1024d5c59c36a'
ALLOWED={f'scripts/{name}.gd' for name in ['arsenal_catalog','arsenal_loadout','arsenal_screen','catalog','fleet_art','fleet_batch','fleet_picker','item_art','main','planet_backdrop_assets','rhythm_tiles','solar_map','ui','ui_materials','weapon_codex']}
CERT='ERROR: Failed to read the root certificate store.'
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def run():
 protected=['scripts','audio','assets','shaders','native','scenes']
 changed=subprocess.check_output(['git','diff','--diff-filter=MDRT','--name-only',BASE,'--',*protected],cwd=R).decode().splitlines()
 assert set(changed)<=ALLOWED,changed
 tree=subprocess.check_output(['git','ls-tree','-r','-z',BASE,'--',*protected],cwd=R).decode().split('\0');expected={}
 for row in filter(None,tree):
  meta,path=row.split('\t')
  if path not in ALLOWED:expected[path]=meta.split()[2]
 paths=sorted(expected)
 hashes=subprocess.check_output(['git','hash-object','--stdin-paths'],cwd=R,input=('\n'.join(paths)+'\n').encode()).decode().splitlines()
 assert len(paths)==len(hashes) and all(expected[p]==h for p,h in zip(paths,hashes))
 before=subprocess.check_output(['git','show',BASE+':scripts/arsenal_catalog.gd'],cwd=R).decode('utf-8').replace('\r\n','\n')
 after=(R/'scripts/arsenal_catalog.gd').read_text(encoding='utf-8')
 assert before[:before.index('static func _build_mods()')]==after[:after.index('static func _build_mods()')],'Weapon catalogue definition changed'
 assert before[before.index('static func _upgrade_trajectories()'):]==after[after.index('static func _upgrade_trajectories()'):],'Weapon movement/growth overrides changed'
 source=(R/'scripts/main.gd').read_text(encoding='utf-8');ui=(R/'scripts/ui.gd').read_text(encoding='utf-8')
 for token in ['func overload(','overload_until','charge_kill','var charge:','KEY_E]']:assert token not in source,token
 assert 'overload_label' not in ui and 'overload_bar' not in ui
 assert 'charge_kill' not in after and 'charge_kill' not in (R/'scripts/arsenal_loadout.gd').read_text(encoding='utf-8')
 backdrop=(R/'shaders/cyber_battlefield.gdshader').read_text(encoding='utf-8')
 assert 'sampler2D' not in backdrop and 'texture(' not in backdrop,'Photographic sampling remains active'
 fonts=json.loads((R/'assets/fonts/SOURCES.json').read_text(encoding='utf-8'))
 for font in fonts['sources']:assert digest(R/'assets/fonts'/font['file'])==font['sha256']
 out=R/'docs/data-v60';out.mkdir(exist_ok=True);reviews={};notices={}
 names={'score':('v60-score','score'),'base_regression':('v56-score','v56_music_first_review'),'native':('v60-native','native'),'compat':('v60-compat','compat'),'live':('v57-live','live')}
 for name,(filename,logname) in names.items():
  data=json.loads((R/f'work/v50-runtime/tests/results-{filename}.json').read_text(encoding='utf-8'));assert not data['failures'],data['failures']
  log=(R/f'work/v60-{logname}.log').read_text(encoding='utf-8',errors='replace')
  assert 'SCRIPT ERROR' not in log and 'Parse Error' not in log
  errors=[line for line in log.splitlines() if line.startswith('ERROR:')];assert all(line==CERT for line in errors),errors
  notices[name]=errors;reviews[name]=data;(out/f'{name}.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
 assert reviews['native']['renderer']=='forward_plus' and reviews['compat']['renderer']=='gl_compatibility'
 for name in ['native','compat']:
  for source in reviews[name]['captures']:
   filename=Path(source).name;shutil.copy2(R/'work/v50-runtime/tests'/filename,R/'docs/screenshots'/filename)
 assert all(row['voices']==0 for row in reviews['live']['planets'])
 songs=json.loads((R/'audio/PLANET_MUSIC.json').read_text(encoding='utf-8'))['tracks'];cues=0
 for song in songs:
  assert digest(R/song['runtime'].removeprefix('res://'))==song['sha256']
  cues+=len(json.loads((R/song['chart'].removeprefix('res://')).read_text(encoding='utf-8'))['events'])
 assert len(songs)==8 and cues==3487
 summary={'version':'0.60.0-cyberpunk','date':'2026-11-17','backup':BASE,'branch':'codex/cyberpunk-interface','checks':{name:data['checks'] for name,data in reviews.items()},'protected_files':len(paths),'unchanged_active_weapon_definitions':24,'unchanged_songs':8,'unchanged_cues':3487,'native_kernel_sha256':digest(R/'native/crowd/groove_crowd.windows.x86_64.dll'),'rhythm_dock':reviews['native']['geometry'],'art':'Original procedural cyber orbital city, cel panels and neon circuits, no photographic samplers; shared near-black/violet minimal chrome; white text; fleet colour facets','typefaces':['Oxanium titles with CJK fallback','JetBrains Mono numbers','System CJK body'],'font_license':'Bundled original fonts, OFL1.1, sources and hashes verified; CJK system fonts not redistributed','overload_removed':['E action and legacy mapping','charge/active state','kill-charge channel','activation/heal/clear rounds/area damage','extra2projectiles and1.75damage','HUD/key binding/tutorial/result captions','five item charging rules and archived overload perk; charge-only dynamo replaced with0.06HP/sec regeneration'],'renderers':['forward_plus','gl_compatibility'],'environment_notices':notices,'verification_scope':'Native render/input and offline OGG/clock/score regression; root certificate-store initialization error is recorded, OS certificates not changed. Screenshots are controlled fixtures, not human art acceptance, exact beat transcription or sustained campaign FPS certification.','preserved_private_artifacts':'Historical Demo/PPT and private course reports excluded.'}
 (out/'SUMMARY.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
 for filename in ['README.md','docs/V60_CYBERPUNK_UI.md','docs/RHYTHM_CONTRACT.md','docs/WEAPON_VFX_AUDIO_REFERENCE.md','CREDITS.md']:
  p=R/filename
  for target in re.findall(r'\]\(([^)]+)\)',p.read_text(encoding='utf-8')):
   if '://' not in target and not target.startswith('#'):assert (p.parent/target.split('#')[0]).exists(),target
 print(json.dumps({key:summary[key] for key in ['version','checks','protected_files','unchanged_active_weapon_definitions','unchanged_songs']},ensure_ascii=False))
if __name__=='__main__':run()
