"""Audit shipped V53 songs/charts, preserved weapons, and isolated runtime evidence.

Run the Godot tests in an imported isolated tree before invoking this archive step.
It does not build or overwrite any historical demo or presentation.
"""
from pathlib import Path
import hashlib,json,re,shutil,subprocess

ROOT=Path(__file__).resolve().parents[1]
BASE='6a91158058c12d063c7bf5f6fef971cd1f43cc28'
ALLOWED={f'scripts/{n}.gd' for n in ['main','ui','rhythm_chart','rhythm_gate','rhythm_tiles','planet_catalog','solar_map','contact_swarm','enemy_arrival','fleet_batch']}
ALLOWED.add('audio/CREDITS.md')

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run():
 manifest=json.loads((ROOT/'audio/PLANET_MUSIC.json').read_text(encoding='utf-8'))
 rows=manifest['tracks'];assert len(rows)==8 and len({r['planet'] for r in rows})==8 and len({r['sha256'] for r in rows})==8
 song_facts=[];all_cues=0
 for row in rows:
  source=ROOT/row['runtime'].removeprefix('res://');assert digest(source)==row['sha256']
  assert row['artist']=='Scott Buckley' and row['license']=='CC BY 4.0' and row['source_page'].startswith('https://www.scottbuckley.com.au/library/')
  assert row['credit'] in (ROOT/'audio/authorized/scott_buckley/planets/LICENSE.md').read_text(encoding='utf-8')
  chart=json.loads((ROOT/row['chart'].removeprefix('res://')).read_text(encoding='utf-8'))
  assert chart['source']==row['runtime'] and chart['source_sha256']==row['sha256'] and abs(chart['duration']-row['duration'])<.001
  assert chart['planet']==row['planet'] and chart['keys']==['H','J','K','L']
  events=chart['events'];seen=set();counts={k:0 for k in ['tap','hold','chord']};gaps=[]
  for i,e in enumerate(events):
   assert 0<e['t']<chart['duration'] and e['kind'] in counts
   assert len(e['lanes'])==(2 if e['kind']=='chord' else 1) and len(set(e['lanes']))==len(e['lanes'])
   assert all(isinstance(l,int) and 0<=l<4 for l in e['lanes']);seen.update(e['lanes']);counts[e['kind']]+=1
   assert .3<=e['hold']<=.65 if e['kind']=='hold' else e['hold']==0
   if i+1<len(events):
    gap=events[i+1]['t']-e['t'];gaps.append(gap)
    assert gap>=max(.22,e['hold']+.139),[row['planet'],i,gap,e['hold']]
  assert seen=={0,1,2,3} and all(counts.values()) and max(gaps)<1.
  assert chart['duration']-events[-1]['t']+events[0]['t']>events[-1]['hold']+.139
  song_facts.append({'planet':row['planet'],'song':row['title'],'duration':row['duration'],'bytes':source.stat().st_size,'sha256':row['sha256'],'candidates':len(events),'forms':counts,'max_internal_gap':round(max(gaps),4)})
  all_cues+=len(events)
 assert len(list((ROOT/'audio/authorized/scott_buckley/planets').glob('*.ogg')))==7,'Unused candidate song in production assets'
 # Added V53 resources become tracked after the implementation commit. Audit
 # existing-input mutations separately so this command remains replayable.
 changed=subprocess.check_output(['git','diff','--diff-filter=MDRT','--name-only',BASE,'--','scripts','audio','assets','native','shaders','scenes'],cwd=ROOT).decode().splitlines()
 assert set(changed)<=ALLOWED,changed
 tree=subprocess.check_output(['git','ls-tree','-r','-z',BASE,'--','scripts','audio','assets','native','shaders','scenes'],cwd=ROOT).decode().split('\0')
 expected={}
 for entry in filter(None,tree):
  meta,path=entry.split('\t')
  if path not in ALLOWED:expected[path]=meta.split()[2]
 paths=sorted(expected)
 hashes=subprocess.check_output(['git','hash-object','--stdin-paths'],cwd=ROOT,input=('\n'.join(paths)+'\n').encode()).decode().splitlines()
 assert len(paths)==len(hashes) and all(expected[p]==h for p,h in zip(paths,hashes)),'Unapproved production input changed'
 all_wavs=[p for p in paths if p.startswith('audio/arsenal/') and p.endswith('.wav')]
 voices=json.loads((ROOT/'audio/instruments/DYNAMICS_MANIFEST.json').read_text(encoding='utf-8'))['weapons'];ids=[w['id'] for w in voices]
 active=[p for p in all_wavs if any(p.startswith('audio/arsenal/dynamics/dyn_'+w+'_') or p.startswith('audio/arsenal/notes/inst_'+w+'_') for w in ids)]
 assert len(ids)==24 and len(active)==288
 report=ROOT/'docs/data-v53';report.mkdir(exist_ok=True);stage=ROOT/'work/v50-runtime/tests';reviews={}
 for name,filename in [('planets','results-v53-planets'),('chart','results-v51-chart'),('live','results-v53-live'),('native','results-v53-native'),('keys','results-v51-native'),('doctrine','results-v43-doctrine'),('boss','results-v49-boss-pressure')]:
  result=json.loads((stage/(filename+'.json')).read_text(encoding='utf-8'));assert not result['failures'];reviews[name]=result
  (report/(name+'.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
  log=ROOT/('work/v53-'+name+'.log')
  if log.is_file():
   text=log.read_text(encoding='utf-8',errors='replace');assert 'SCRIPT ERROR' not in text and 'Parse Error' not in text
 for path in reviews['native']['captures']:
  name=Path(path).name;shutil.copy2(stage/name,ROOT/'docs/screenshots'/name)
 (report/'songs.json').write_text(json.dumps(song_facts,ensure_ascii=False,indent=2),encoding='utf-8')
 shutil.copy2(ROOT/'audio/charts/planets/ANALYSIS.json',report/'chart-analysis.json')
 summary={'version':'0.53.0-planet-scores','date':'2026-11-11','backup':BASE,'branch':'codex/planet-music-identities','planet_songs':8,'objective_types':8,'total_candidate_cues':all_cues,'checks':{k:v['checks'] for k,v in reviews.items()},'unchanged_production_files':len(paths),'unchanged_all_arsenal_wavs':len(all_wavs),'unchanged_active_weapons':24,'unchanged_active_wavs':len(active),'unchanged_native_kernel_sha256':digest(ROOT/'native/crowd/groove_crowd.windows.x86_64.dll'),'native_renderer':reviews['native']['renderer'],'screenshots':len(reviews['native']['captures']),'reviewed_layouts':['venus-1920','uranus-1280-120','piano-hit-1920','calibration-1920','routes-1920'],'scope':'Real objective state/contacts/damage/wave continuity; local-beat/onset gameplay arrangements, full-song transport and Forward+ visual checks. No human music approval, exact transcription, physical device-latency, full-run balance or sustained FPS certification. Historical demo/PPT not rebuilt or edited.'}
 (report/'SUMMARY.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
 for filename in ['README.md','CREDITS.md','audio/CREDITS.md','docs/V53_PLANET_SCORES_MISSIONS.md','docs/WEAPON_VFX_AUDIO_REFERENCE.md']:
  doc=ROOT/filename
  for target in re.findall(r'\]\(([^)]+)\)',doc.read_text(encoding='utf-8')):
   if '://' in target or target.startswith('#'):continue
   assert (doc.parent/target.split('#')[0]).exists(),target
 print(json.dumps(summary,ensure_ascii=False))
if __name__=='__main__':run()
