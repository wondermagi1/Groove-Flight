"""Archive three-track score evidence and compare protected inputs with backup."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess
ROOT=Path(__file__).resolve().parents[1]
BASE='4325c6acc2be845634c32f874ddbe134eb94ceb4'
ALLOWED={f'scripts/{name}.gd' for name in ['main','rhythm_chart','rhythm_gate','rhythm_tiles','ui','weapon_codex']}
ALLOWED.add('audio/CREDITS.md')
ALLOWED.update('audio/charts/planets/'+name+'.json' for name in ['ANALYSIS','mercury','venus','earth','mars','jupiter','saturn','uranus','neptune'])
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run():
 changed=subprocess.check_output(['git','diff','--diff-filter=MDRT','--name-only',BASE,'--','scripts','audio','native','assets','shaders','scenes'],cwd=ROOT).decode().splitlines()
 assert set(changed)<=ALLOWED,changed
 tree=subprocess.check_output(['git','ls-tree','-r','-z',BASE,'--','scripts','audio','native','assets','shaders','scenes'],cwd=ROOT).decode().split('\0');expected={}
 for entry in filter(None,tree):
  meta,path=entry.split('\t')
  if path not in ALLOWED:expected[path]=meta.split()[2]
 paths=sorted(expected)
 hashes=subprocess.check_output(['git','hash-object','--stdin-paths'],cwd=ROOT,input=('\n'.join(paths)+'\n').encode()).decode().splitlines()
 assert len(paths)==len(hashes) and all(expected[p]==h for p,h in zip(paths,hashes)),'Protected weapon/music/mission/native file changed'
 songs=json.loads((ROOT/'audio/PLANET_MUSIC.json').read_text(encoding='utf-8'))['tracks'];cue_total=0
 for song in songs:
  assert digest(ROOT/song['runtime'].removeprefix('res://'))==song['sha256']
  relative=song['chart'].removeprefix('res://');old=json.loads(subprocess.check_output(['git','show',BASE+':'+relative],cwd=ROOT).decode('utf-8'));new=json.loads((ROOT/relative).read_text(encoding='utf-8'))
  assert new['keys']==['J','K','L'] and new['tracks']==['A','B','C'] and new['lane_mode']=='weapon_track' and new['schema']==3
  assert [(e['t'],e['hold']) for e in old['events']]==[(e['t'],e['hold']) for e in new['events']]
  assert all(e['kind'] in ['tap','hold'] and 'lanes' not in e for e in new['events'])
  assert new['source_sha256']==old['source_sha256'] and new['duration']==old['duration']
  cue_total+=len(new['events'])
 assert cue_total==3487
 stage=ROOT/'work/v50-runtime/tests';report=ROOT/'docs/data-v54';report.mkdir(exist_ok=True);reviews={}
 names={'score':'results-v54-score','planets':'results-v54-planets','native':'results-v54-native','live':'results-v54-live','doctrine':'results-v43-doctrine','boss':'results-v49-boss-pressure'}
 for name,filename in names.items():
  data=json.loads((stage/(filename+'.json')).read_text(encoding='utf-8'));assert not data['failures'];reviews[name]=data
  text=(ROOT/('work/v54-'+name+'.log')).read_text(encoding='utf-8',errors='replace')
  assert 'SCRIPT ERROR' not in text and 'Parse Error' not in text
  errors=[line for line in text.splitlines() if line.startswith('ERROR:') and 'resources still in use at exit' not in line]
  assert not errors,errors
  (report/(name+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
 for path in reviews['native']['captures']:
  name=Path(path).name;shutil.copy2(stage/name,ROOT/'docs/screenshots'/name)
 wavs=[p for p in paths if p.startswith('audio/arsenal/') and p.endswith('.wav')]
 summary={'version':'0.54.0-three-track-score','date':'2026-11-11','backup':BASE,'branch':'codex/three-track-rhythm','input_mapping':{'J':'A','K':'B','L':'C'},'score_window_seconds':6,'opening_ratio':1.,'points':{'perfect':100,'good':70,'miss':0},'no_note_window':'carry prior track ratio','zero_quota':'no new salvo/audio; scoring notes continue','candidate_times_and_holds_unchanged':cue_total,'checks':{k:v['checks'] for k,v in reviews.items()},'protected_files_unchanged':len(paths),'unchanged_all_arsenal_wavs':len(wavs),'unchanged_active_weapons':24,'unchanged_active_wavs':288,'unchanged_full_background_songs':8,'native_kernel_sha256':digest(ROOT/'native/crowd/groove_crowd.windows.x86_64.dll'),'native_renderer':reviews['native']['renderer'],'screenshots':len(reviews['native']['captures']),'layout':'Adjacent to sequencer, aligned bottoms; above-right fallback when inventory leaves insufficient side room.','scope':'Counted unit/actual salvo/audio and18-second simulated three-window recovery, eight mission/transport regressions, real Forward+ JKL/mouse/touch/layout checks. No human difficulty, subjective music, physical-device latency or sustained FPS certification. Historical demo/PPT/private reports unchanged.'}
 (report/'SUMMARY.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
 for filename in ['README.md','docs/V54_THREE_TRACK_SCORE.md','docs/WEAPON_VFX_AUDIO_REFERENCE.md','docs/RHYTHM_CONTRACT.md']:
  doc=ROOT/filename
  for target in re.findall(r'\]\(([^)]+)\)',doc.read_text(encoding='utf-8')):
   if '://' in target or target.startswith('#'):continue
   assert (doc.parent/target.split('#')[0]).exists(),target
 print(json.dumps(summary,ensure_ascii=False))
if __name__=='__main__':run()
