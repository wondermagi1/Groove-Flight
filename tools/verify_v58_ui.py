"""Archive compact-UI evidence and prove that gameplay/audio inputs were preserved."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess
ROOT=Path(__file__).resolve().parents[1]
BASE='71f77be7c9f2a3bde08f01694f45a1730ef00555'
ALLOWED={f'scripts/{name}.gd' for name in ['arsenal_screen','fleet_picker','mission_hud','rhythm_tiles','solar_map','ui','ui_materials','weapon_codex']}
CERT='ERROR: Failed to read the root certificate store.'
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def run():
 protected=['scripts','audio','native','assets','shaders','scenes']
 changed=subprocess.check_output(['git','diff','--diff-filter=MDRT','--name-only',BASE,'--',*protected],cwd=ROOT).decode().splitlines()
 assert set(changed)<=ALLOWED,changed
 tree=subprocess.check_output(['git','ls-tree','-r','-z',BASE,'--',*protected],cwd=ROOT).decode().split('\0');expected={}
 for entry in filter(None,tree):
  meta,path=entry.split('\t')
  if path not in ALLOWED:expected[path]=meta.split()[2]
 paths=sorted(expected)
 hashes=subprocess.check_output(['git','hash-object','--stdin-paths'],cwd=ROOT,input=('\n'.join(paths)+'\n').encode()).decode().splitlines()
 assert len(paths)==len(hashes) and all(expected[p]==h for p,h in zip(paths,hashes)),'Gameplay/audio/native/art input changed during UI pass'
 stage=ROOT/'work/v50-runtime/tests';out=ROOT/'docs/data-v58';out.mkdir(exist_ok=True);reviews={};notices={}
 names={'score':'results-v58-score','native':'results-v58-native','live':'results-v57-live'}
 for name,filename in names.items():
  data=json.loads((stage/(filename+'.json')).read_text(encoding='utf-8'));assert not data['failures'];reviews[name]=data
  log=(ROOT/('work/v58-'+name+'.log')).read_text(encoding='utf-8',errors='replace');assert 'SCRIPT ERROR' not in log and 'Parse Error' not in log
  # This Windows startup error is recorded, not counted as network validation.
  # These checks load local assets only. Reject every other engine ERROR.
  errors=[line for line in log.splitlines() if line.startswith('ERROR:') and line!=CERT]
  assert not errors,errors
  notices[name]=[line for line in log.splitlines() if line.startswith('WARNING:') or line==CERT]
  (out/(name+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
 comparisons=[]
 for row in reviews['native']['geometry']:
  w,h=row['viewport'];pw,ph=row['panel'];old_w=min(460.,max(330.,w*.24));old_h=min(468.,max(368.,h*.43))
  assert pw*ph/(w*h)<=.06 and row['runway']>=140
  comparisons.append({**row,'previous_panel':[old_w,old_h],'panel_area_reduction':1.-pw*ph/(old_w*old_h)})
 for source in reviews['native']['captures']:
  name=Path(source).name;shutil.copy2(stage/name,ROOT/'docs/screenshots'/name)
 assert len(comparisons)==6 and all(row['voices']==0 for row in reviews['live']['planets'])
 source=(ROOT/'scripts/rhythm_tiles.gd').read_text(encoding='utf-8')
 assert 'tooltip_text=""' in source
 for removed in ['本段 %','音乐键 %','后结算','下一段全武器弹量','PERFECT链 · 奖励','get("hold_perfect"']:
  assert removed not in source,removed
 songs=json.loads((ROOT/'audio/PLANET_MUSIC.json').read_text(encoding='utf-8'))['tracks'];cues=0
 for song in songs:
  assert digest(ROOT/song['runtime'].removeprefix('res://'))==song['sha256']
  cues+=len(json.loads((ROOT/song['chart'].removeprefix('res://')).read_text(encoding='utf-8'))['events'])
 assert len(songs)==8 and cues==3487
 summary={'version':'0.58.0-compact-ui','date':'2026-11-17','backup':BASE,'branch':'codex/compact-rhythm-ui','checks':{k:v['checks'] for k,v in reviews.items()},'piano_geometry':comparisons,'head_height':12,'bottom_key_height':32,'pointer_tolerance_y':5,'permanent_labels':'J/K/L,combo and ammo percent only; grade/reward transient; no explanatory tooltip/footer','combat_sequencer_max':[620,104],'mission_card':[276,48],'gameplay_inputs_unchanged':len(paths),'preserved_active_weapons':24,'preserved_full_songs':8,'preserved_chart_cues':cues,'preserved_archived_wavs':len([p for p in paths if p.startswith('audio/arsenal/') and p.endswith('.wav')]),'native_kernel_sha256':digest(ROOT/'native/crowd/groove_crowd.windows.x86_64.dll'),'native_renderer':reviews['native']['renderer'],'captures':reviews['native']['captures'],'environment_notices':notices,'notice_scope':'Windows engine reports root certificate-store initialization error. Offline local asset/input/render/OGG checks completed; no HTTPS or certificate functionality certified and no system certificate changes made.','visual_review':'Compact battle1280/1920, note/hold/grades/rewards, hidden sequence/inventory fallback, neutral title/hangar/codex/solar/settings inspected. Controlled test fixtures, not human difficulty or long-run FPS acceptance.','next_development_order':['Mercury gameplay','Boss combat'],'next_development_status':'Queued only; no gameplay/Boss balance implemented in UI pass. Historical Demo/PPT/private reports excluded.'}
 (out/'SUMMARY.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
 for filename in ['README.md','docs/V58_COMPACT_UI.md','docs/WEAPON_VFX_AUDIO_REFERENCE.md','docs/RHYTHM_CONTRACT.md','docs/DEVELOPMENT_QUEUE.md']:
  doc=ROOT/filename
  for target in re.findall(r'\]\(([^)]+)\)',doc.read_text(encoding='utf-8')):
   if '://' in target or target.startswith('#'):continue
   assert (doc.parent/target.split('#')[0]).exists(),target
 print(json.dumps({k:summary[k] for k in ['version','checks','gameplay_inputs_unchanged','preserved_archived_wavs']},ensure_ascii=False))
if __name__=='__main__':run()
