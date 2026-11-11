"""Audit V51's shipped chart, untouched mechanics/audio, and runtime evidence."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess
ROOT=Path(__file__).resolve().parents[1]
BASE='bcf7955ed8be731c7c7d578771e240a8bea400c3'
def run():
 chart=json.loads((ROOT/'audio/charts/filaments.json').read_text(encoding='utf-8'))
 assert chart['keys']==['H','J','K','L']
 source=ROOT/chart['source'].removeprefix('res://')
 assert hashlib.sha256(source.read_bytes()).hexdigest()==chart['source_sha256']
 events=chart['events'];seen=set();counts={k:0 for k in ['tap','hold','chord']}
 for i,e in enumerate(events):
  assert 0<e['t']<chart['duration'] and e['kind'] in counts
  assert len(e['lanes'])==(2 if e['kind']=='chord' else 1) and len(set(e['lanes']))==len(e['lanes'])
  assert all(isinstance(l,int) and 0<=l<4 for l in e['lanes']);seen.update(e['lanes']);counts[e['kind']]+=1
  assert .3<=e['hold']<=.65 if e['kind']=='hold' else e['hold']==0
  if i+1<len(events):assert events[i+1]['t']-e['t']>=max(.22,e['hold']+.139)
 assert seen=={0,1,2,3} and all(counts.values())
 protected=['audio/arsenal','scripts/arsenal_catalog.gd','scripts/arsenal_loadout.gd','scripts/projectile_visuals.gd','scripts/salvo_patterns.gd','scripts/projectile_fields.gd','scripts/energy_arsenal.gd','scripts/weapon_expression.gd','scripts/run_balance.gd','scripts/enemy_cadence.gd','scripts/contact_swarm.gd','scripts/boss_score.gd','scripts/music.gd','scripts/rhythm_voices.gd','native/crowd']
 tree=subprocess.check_output(['git','ls-tree','-r','-z',BASE,'--',*protected],cwd=ROOT).decode().split('\0')
 expected={}
 for entry in filter(None,tree):
  meta,path=entry.split('\t');expected[path]=meta.split()[2]
 paths=sorted(expected)
 hashes=subprocess.check_output(['git','hash-object','--stdin-paths'],cwd=ROOT,input=('\n'.join(paths)+'\n').encode()).decode().splitlines()
 assert all(expected[p]==h for p,h in zip(paths,hashes)),'Protected gameplay/audio files changed'
 wavs=[p for p in paths if p.endswith('.wav')]
 dynamic=json.loads((ROOT/'audio/instruments/DYNAMICS_MANIFEST.json').read_text(encoding='utf-8'))
 ids=[w['id'] for w in dynamic['weapons']]
 active_wavs=[p for p in wavs if any(p.startswith('audio/arsenal/dynamics/dyn_'+w+'_') or p.startswith('audio/arsenal/notes/inst_'+w+'_') for w in ids)]
 assert len(active_wavs)==288,(len(active_wavs),len(wavs),len(ids))
 report=ROOT/'docs/data-v51';report.mkdir(exist_ok=True)
 reviews={}
 for name in ['chart','live','native']:
  result=json.loads((ROOT/f'tests/results-v51-{name}.json').read_text(encoding='utf-8'))
  assert not result['failures'];reviews[name]=result
  (report/f'{name}.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf-8')
 # Regressions are run in an isolated runtime with the current production scripts.
 for name in ['doctrine','boss']:
  text=(ROOT/f'work/v51-{name}.log').read_text(encoding='utf-8')
  assert 'failures=[]' in text or '"failures":[]' in text
  shutil.copy2(ROOT/f'work/v51-{name}.log',report/f'{name}.log')
 for width in [1280,1920]:
  source=ROOT/f'work/v50-runtime/tests/v51-piano-{width}.png'
  shutil.copy2(source,ROOT/f'docs/screenshots/v51-piano-{width}.png')
 registry=ROOT/'docs/WEAPON_VFX_AUDIO_REFERENCE.md';broken=[]
 for target in re.findall(r'\]\(([^)]+)\)',registry.read_text(encoding='utf-8')):
  if '://' in target or target.startswith('#'):continue
  if target!='data-v51/SUMMARY.json' and not (registry.parent/target.split('#')[0]).exists():broken.append(target)
 assert not broken,broken
 summary={'version':'0.51.0-music-piano','date':'2026-11-11','backup':BASE,'branch':'codex/music-chart-four-keys','source_sha256':chart['source_sha256'],'chart_events':len(events),'chart_forms':counts,'keys':chart['keys'],'estimated_bpm_not_transcription':chart['estimated_bpm'],'protected_files_unchanged':len(paths),'unchanged_active_wavs':len(active_wavs),'unchanged_all_arsenal_wavs':len(wavs),'checks':{k:v['checks'] for k,v in reviews.items()},'regressions':{'doctrine':3433,'boss':140},'scope':'Algorithmic audio arrangement; automated judge/live-clock/Forward+ checks, no human listening or picture approval. Native live check uses dummy/headless audio, not measured physical keyboard/speaker latency. Historical V49 demo/PPT are untouched.'}
 (report/'SUMMARY.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps(summary,ensure_ascii=False))
if __name__=='__main__':run()
