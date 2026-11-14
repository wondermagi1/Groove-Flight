"""Archive Perfect/driver/talent checks and protect the underlying game inputs."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess
ROOT=Path(__file__).resolve().parents[1]
BASE='8bc289aa7caf06b6c95a0abbf16918ac7907dfbd'
ALLOWED={f'scripts/{name}.gd' for name in ['arsenal_loadout','fleet_catalog','fleet_picker','main','rhythm_gate','rhythm_score','rhythm_tiles']}
ALLOWED.update(['audio/CREDITS.md','audio/MUSIC_FIRST_POLICY.json'])
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def old(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT).decode('utf-8')
def body(source,name):return re.search(r'^func '+name+r'\([^\n]*\n.*?(?=^func |\Z)',source,re.M|re.S).group(0).strip()
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
 assert len(paths)==len(hashes) and all(expected[p]==h for p,h in zip(paths,hashes)),'Protected input changed'
 unchanged={}
 for path,names in {'scripts/main.gd':['shot','update_bullets','update_enemies','boss_step','split_projectile'],'scripts/arsenal_loadout.gd':['trigger','_stats_for','make_shop','add_boon']}.items():
  before=old(path);after=(ROOT/path).read_text(encoding='utf-8')
  for name in names:
   assert body(before,name)==body(after,name),(path,name)
   unchanged[path+':'+name]=hashlib.sha256(body(after,name).encode()).hexdigest()
 # Actual launch geometry/damage is unchanged except explicitly retired pilot buffs.
 before=old('scripts/main.gd');after=(ROOT/'scripts/main.gd').read_text(encoding='utf-8')
 for name in ['fire_weapon','full_salvo_count']:
  strip=lambda text:re.sub(r'^\tif selected_pilot==[^\n]*\n','',text,flags=re.M)
  assert strip(body(before,name))==strip(body(after,name)),name
 songs=json.loads((ROOT/'audio/PLANET_MUSIC.json').read_text(encoding='utf-8'))['tracks'];cues=0
 for song in songs:
  assert digest(ROOT/song['runtime'].removeprefix('res://'))==song['sha256']
  cues+=len(json.loads((ROOT/song['chart'].removeprefix('res://')).read_text(encoding='utf-8'))['events'])
 assert len(songs)==8 and cues==3487
 stage=ROOT/'work/v50-runtime/tests';out=ROOT/'docs/data-v57';out.mkdir(exist_ok=True);reviews={};warnings={}
 names={'score':'results-v57-score','native':'results-v57-native','live':'results-v57-live','planets':'results-v54-planets','base_regression':'results-v56-score'}
 for name,filename in names.items():
  data=json.loads((stage/(filename+'.json')).read_text(encoding='utf-8'));assert not data['failures'];reviews[name]=data
  logname='v56_music_first_review' if name=='base_regression' else name
  log=(ROOT/('work/v57-'+logname+'.log')).read_text(encoding='utf-8',errors='replace')
  assert 'SCRIPT ERROR' not in log and 'Parse Error' not in log
  errors=[line for line in log.splitlines() if line.startswith('ERROR:') and 'resources still in use at exit' not in line]
  assert not errors,errors
  warnings[name]=[line for line in log.splitlines() if line.startswith('WARNING:')]
  (out/(name+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
 for source in reviews['native']['captures']:
  name=Path(source).name;shutil.copy2(stage/name,ROOT/'docs/screenshots'/name)
 assert all(row['voices']==0 for row in reviews['live']['planets'])
 summary={'version':'0.57.0-perfect-pilots','date':'2026-11-14','backup':BASE,'branch':'codex/perfect-rewards-pilots','ordinary_combo':'all successful grades; separate from Perfect chain','default_perfect_thresholds':[10,25,50,100],'tier_bonuses':[.05,.10,.15,.20],'ammo':'previous6second base accuracy * (1+current earned reward), cap1.2; class count caps remain; opening base1.0','pilots':['echo:2.8s pre-read','volt:8/20/40/80 thresholds','mender:one chain guard per6s with real grades','nova:hold45/85ms+180ms tail','rime:up to10percent linger4combat seconds, no self refresh'],'retired_pilot_physical_buffs':['echo extra salvo','volt dash damage/count','mender pickup heal','nova downbeat damage','rime timed shield'],'talents':{'initial_points':2,'distinct_clear_points':1,'max_points':6,'nodes':6,'respec':'free; hangar only; next run; sanitized config roundtrip tested'},'unchanged_active_weapon_catalogue':24,'unchanged_songs':8,'unchanged_source_cues':cues,'archived_weapon_wavs_unchanged':len([p for p in paths if p.startswith('audio/arsenal/') and p.endswith('.wav')]),'protected_files_unchanged':len(paths),'core_functions_unchanged':unchanged,'native_kernel_sha256':digest(ROOT/'native/crowd/groove_crowd.windows.x86_64.dll'),'checks':{k:v['checks'] for k,v in reviews.items()},'warnings':warnings,'renderer':reviews['native']['renderer'],'captures':reviews['native']['captures'],'visual_review':'Native1280/1920, reward120percent/protectedMiss, readouts and scrollable hangar with pinned confirm/free reset inspected. Controlled milestone fixture is not a human play achievement.','scope':'Reward/pilot/talent unit and actual-count checks, isolated real config roundtrip, music-first base/8planet mission regression, live song/clock pause/loop and no weapon voices, native inputs and UI. No human listening, progression difficulty or sustained FPS certification; historical Demo/PPT/private reports excluded.'}
 (out/'SUMMARY.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
 for filename in ['README.md','docs/V57_PERFECT_REWARDS_PILOTS.md','docs/RHYTHM_CONTRACT.md','docs/WEAPON_VFX_AUDIO_REFERENCE.md','docs/WEAPON_DEVELOPMENT_STANDARD.md']:
  doc=ROOT/filename
  for target in re.findall(r'\]\(([^)]+)\)',doc.read_text(encoding='utf-8')):
   if '://' in target or target.startswith('#'):continue
   assert (doc.parent/target.split('#')[0]).exists(),target
 print(json.dumps({k:summary[k] for k in ['version','checks','protected_files_unchanged','archived_weapon_wavs_unchanged']},ensure_ascii=False))
if __name__=='__main__':run()
