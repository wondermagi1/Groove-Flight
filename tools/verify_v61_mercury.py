"""V61 evidence archive: nonlinear ammo, bounded growth, Mercury relay and star sea."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess
from PIL import Image,ImageStat
R=Path(__file__).resolve().parents[1]
BASE='21c8f31bfab3a64e4cf3834873968a55ff11e08e'
ALLOWED={f'scripts/{n}.gd' for n in ['run_balance','rhythm_score','arsenal_loadout','arsenal_screen','planet_mission','mission_hud','main']}
ALLOWED|={'audio/MUSIC_FIRST_POLICY.json','shaders/cyber_battlefield.gdshader'}
CERT='ERROR: Failed to read the root certificate store.'
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def run():
 protected=['scripts','audio','assets','shaders','native','scenes']
 changed=subprocess.check_output(['git','diff','--diff-filter=MDRT','--name-only',BASE,'--',*protected],cwd=R).decode().splitlines();assert set(changed)<=ALLOWED,changed
 tree=subprocess.check_output(['git','ls-tree','-r','-z',BASE,'--',*protected],cwd=R).decode().split('\0');expected={}
 for entry in filter(None,tree):
  meta,path=entry.split('\t')
  if path not in ALLOWED:expected[path]=meta.split()[2]
 paths=sorted(expected);hashes=subprocess.check_output(['git','hash-object','--stdin-paths'],cwd=R,input=('\n'.join(paths)+'\n').encode()).decode().splitlines()
 assert len(paths)==len(hashes) and all(expected[p]==h for p,h in zip(paths,hashes))
 stage=R/'work/v50-runtime/tests';out=R/'docs/data-v61';out.mkdir(exist_ok=True);reviews={};notices={}
 files={'score':('v61-score','score'),'base':('v61-base','base'),'balance':('v61-balance','balance'),'missions':('v61-missions','v61_missions_review'),'native':('v61-native','native'),'compat':('v61-compat','compat'),'live':('v57-live','live')}
 for key,(filename,logname) in files.items():
  data=json.loads((stage/f'results-{filename}.json').read_text(encoding='utf-8'));assert not data['failures'],data['failures']
  log=(R/f'work/v61-{logname}.log').read_text(encoding='utf-8',errors='replace');assert 'SCRIPT ERROR' not in log and 'Parse Error' not in log
  errors=[line for line in log.splitlines() if line.startswith('ERROR:')];assert all(line==CERT for line in errors),errors
  notices[key]=[line for line in log.splitlines() if line.startswith(('ERROR:','WARNING:'))];reviews[key]=data
  (out/f'{key}.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
 for key in ['native','compat']:
  for source in reviews[key]['captures']:
   name=Path(source).name;shutil.copy2(stage/name,R/'docs/screenshots'/name)
 assert reviews['native']['renderer']=='forward_plus' and reviews['compat']['renderer']=='gl_compatibility'
 assert all(p['voices']==0 for p in reviews['live']['planets'])
 balance=reviews['balance'];assert len(balance['cases'])==3 and len(balance['boss_samples'])==3
 assert balance['cases'][0]['alive']>0 and balance['cases'][0]['projectiles']<balance['cases'][1]['projectiles']*.45
 assert balance['cases'][0]['near130_seconds']>balance['cases'][1]['near130_seconds']
 assert balance['boss_samples'][0]['direct_damage']<balance['boss_samples'][1]['direct_damage']*.6
 songs=json.loads((R/'audio/PLANET_MUSIC.json').read_text(encoding='utf-8'))['tracks'];cues=0
 for song in songs:
  assert digest(R/song['runtime'].removeprefix('res://'))==song['sha256']
  cues+=len(json.loads((R/song['chart'].removeprefix('res://')).read_text(encoding='utf-8'))['events'])
 assert len(songs)==8 and cues==3487
 patch=(100,260,550,590);luma=[]
 for version in ['v60-art-1920','v61-mercury-navigation-1920']:
  mean=ImageStat.Stat(Image.open(R/f'docs/screenshots/{version}.png').convert('RGB').crop(patch)).mean
  luma.append(sum(a*b for a,b in zip(mean,[.2126,.7152,.0722])))
 assert luma[1]>luma[0]+5.,luma
 summary={'version':'0.61.0-mercury-rhythm','date':'2026-11-17','backup':BASE,'checks':{k:d['checks'] for k,d in reviews.items()},'accuracy_ammo_curve':balance['curve'],'growth':'Counts remain linear. Attribute damage1+.5P/(100+P)+.25Power/(100+Power);negative penalties retained. Level+.30. Bonus>100percent diminishes. Volume multiplier sqrt(base_count/max(base_count,full_count)) applies before accuracy; no low-score refund.','ordinary_wave_hp':[1,1.08,1.2,1.36,1.55,1.78,2.04],'boss_hp':[30000,32000,34000,36000,39000,42000,45000,48000],'boss_scope':'Provisional global numeric calibration after damage-growth change; Mercury contact diagnostic only. Other planets still need dedicated stage and Boss playtests.','mercury':'3wave-gated samples at1/3/5;first360distance;160radius/.8combat seconds,can move while sampling;safe placement;original2.5Drelay/number/progressring;2line66px objective HUD and offscreen distance arrow avoids piano','background':'Brighter smooth blue/violet galactic band and dense stable stars; original graphic cyber planet retained; no photo textures or BGM transport changes.','background_patch_luminance_0to255':{'rect':patch,'before':luma[0],'after':luma[1]},'protected_files':len(paths),'preserved_active_weapon_sources':24,'preserved_full_songs':8,'preserved_cues':cues,'native_kernel_sha256':digest(R/'native/crowd/groove_crowd.windows.x86_64.dll'),'environment_notices':notices,'scope':'Controlled production-hit/clearance/input/render/transport checks. Diagnostic script uses6Lv3weapons,192targets,scripted movement and invulnerable observer,not campaign win rate or human double-hand workload acceptance. Boss direct damage excludes fixed16percent node structural loss.','next':['Full Mercury playtest and refined hand-authored song patterns','Mercury Boss readable phases','Venus escort,then each planet in order']}
 (out/'SUMMARY.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
 for filename in ['README.md','docs/V61_MERCURY_RHYTHM_BALANCE.md','docs/WEAPON_VFX_AUDIO_REFERENCE.md','docs/RHYTHM_CONTRACT.md','docs/DEVELOPMENT_QUEUE.md']:
  p=R/filename
  for target in re.findall(r'\]\(([^)]+)\)',p.read_text(encoding='utf-8')):
   if '://' not in target and not target.startswith('#'):assert (p.parent/target.split('#')[0]).exists(),target
 print(json.dumps({'version':summary['version'],'checks':summary['checks'],'protected':len(paths),'sky_luma':luma},ensure_ascii=False))
if __name__=='__main__':run()
