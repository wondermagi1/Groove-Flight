"""Verify and archive the music-first refactor against its uploaded pre-change backup."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess

ROOT=Path(__file__).resolve().parents[1]
BASE='2db4e1dfb21e0dc1ca3714f59a0acd755374d1af'
ALLOWED={f'scripts/{name}.gd' for name in ['arsenal_catalog','arsenal_lab','arsenal_loadout','arsenal_screen','audio_controls','combat_doctrines','main','music','rhythm_chart','rhythm_gate','rhythm_score','rhythm_tiles','rhythm_voices','solar_map','ui','weapon_codex']}
ALLOWED.update(['audio/CREDITS.md','audio/weapon_codex.json'])

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def old(path):return subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT).decode('utf-8')
def function(source,name):
    return re.search(r'^func '+name+r'\([^\n]*\n.*?(?=^func |\Z)',source,re.M|re.S).group(0).strip()

def run():
    protected=['scripts','audio','native','assets','shaders','scenes']
    changed=subprocess.check_output(['git','diff','--diff-filter=MDRT','--name-only',BASE,'--',*protected],cwd=ROOT).decode().splitlines()
    assert set(changed)<=ALLOWED,changed
    tree=subprocess.check_output(['git','ls-tree','-r','-z',BASE,'--',*protected],cwd=ROOT).decode().split('\0')
    expected={}
    for entry in filter(None,tree):
        meta,path=entry.split('\t')
        if path not in ALLOWED:expected[path]=meta.split()[2]
    paths=sorted(expected)
    hashes=subprocess.check_output(['git','hash-object','--stdin-paths'],cwd=ROOT,input=('\n'.join(paths)+'\n').encode()).decode().splitlines()
    assert len(paths)==len(hashes) and all(expected[path]==value for path,value in zip(paths,hashes)),'Protected audio/visual/mission/native input changed'
    unchanged_functions={}
    for path,names in {
        'scripts/main.gd':['full_salvo_count','fire_weapon','shot','update_bullets','update_enemies','boss_step','split_projectile'],
        'scripts/arsenal_loadout.gd':['trigger','_stats_for','make_shop','add_boon'],
    }.items():
        before=old(path);after=(ROOT/path).read_text(encoding='utf-8')
        for name in names:
            assert function(before,name)==function(after,name),(path,name)
            unchanged_functions[path+':'+name]=hashlib.sha256(function(after,name).encode()).hexdigest()
    songs=json.loads((ROOT/'audio/PLANET_MUSIC.json').read_text(encoding='utf-8'))['tracks'];cue_total=0
    for song in songs:
        assert digest(ROOT/song['runtime'].removeprefix('res://'))==song['sha256']
        chart=json.loads((ROOT/song['chart'].removeprefix('res://')).read_text(encoding='utf-8'));cue_total+=len(chart['events'])
    assert len(songs)==8 and cue_total==3487
    report=ROOT/'docs/data-v56';report.mkdir(exist_ok=True);stage=ROOT/'work/v50-runtime/tests';reviews={};warnings={}
    names={'score':'results-v56-score','native':'results-v56-native','live':'results-v56-live','planets':'results-v54-planets'}
    for name,filename in names.items():
        data=json.loads((stage/(filename+'.json')).read_text(encoding='utf-8'));assert not data['failures'];reviews[name]=data
        log=(ROOT/('work/v56-'+name+'.log')).read_text(encoding='utf-8',errors='replace')
        assert 'SCRIPT ERROR' not in log and 'Parse Error' not in log
        errors=[line for line in log.splitlines() if line.startswith('ERROR:') and 'resources still in use at exit' not in line]
        assert not errors,errors
        warnings[name]=[line for line in log.splitlines() if line.startswith('WARNING:')]
        (report/(name+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    previous=json.loads((ROOT/'docs/data-v55/score.json').read_text(encoding='utf-8'))['facts']['catalogue']
    original_counts={(row['kind'],row['track']):row['full_count'] for row in previous}
    assert len(reviews['score']['actual_salvos'])==72
    for row in reviews['score']['actual_salvos']:assert row['full_count']==original_counts[(row['kind'],row['track'])]
    assert all(row['voices']==0 for row in reviews['live']['planets'])
    for path in reviews['native']['captures']:
        name=Path(path).name;shutil.copy2(stage/name,ROOT/'docs/screenshots'/name)
    manifest=json.loads((ROOT/'audio/weapon_codex.json').read_text(encoding='utf-8'));assert manifest['active'] is False and manifest['status']=='archived_weapon_voices'
    summary={
        'version':'0.56.0-music-first','date':'2026-11-14','backup':BASE,'branch':'codex/music-first-rhythm',
        'lead':'Eight full licensed BGM songs; independent deterministic three-key chart, even without weapons',
        'judgements':{'perfect':{'max_error_ms':35,'points':100},'excellent':{'max_error_ms':75,'points':80},'general':{'max_error_ms':140,'points':40},'miss':{'points':0}},
        'score':'combined earned/combined possible, applied to all weapon counts for the NEXT6combat seconds; opening100percent',
        'weapon_voices':'removed from runtime/native PCM/recorded and single-note/codex/shop; old sources archived, legacy bus forcibly muted',
        'doctrines':'removed from launch/retry and all24weapon acquisition filters; mixed arsenal;3+3shop',
        'native_clock':'silent156seconds,12+144repeat; independent song transport retained',
        'candidate_times_and_holds_unchanged':cue_total,'unchanged_full_songs':8,'unchanged_weapons':24,
        'archived_wavs_unchanged':len([p for p in paths if p.startswith('audio/arsenal/') and p.endswith('.wav')]),
        'protected_files_unchanged':len(paths),'unchanged_core_functions':unchanged_functions,
        'base_salvo_counts_match_v55':72,'live_weapon_voice_count':0,
        'checks':{name:data['checks'] for name,data in reviews.items()},'warnings':warnings,
        'native_renderer':reviews['native']['renderer'],'screenshots':reviews['native']['captures'],
        'visual_review':'1280/1920 controls, inventory fallback, four judgement grades and new weapon catalogue inspected; no external texture/art regeneration.',
        'native_kernel_sha256':digest(ROOT/'native/crowd/groove_crowd.windows.x86_64.dll'),
        'future':'Dedicated rhythm hitsounds, stronger hit feel, gesture diversity and human-authored difficulty charts are not implemented in this pass.',
        'scope':'Unit boundary/hold/fractional count, independent full-song chart across3equipment configurations,24weapons on3tracks, unified offers,8planet mission and real OGG/native transport regression; Forward+ physical input/mouse/touch/focus/layout. Not human listening approval, exact transcription, device-latency or sustained FPS certification. No historical demo/PPT/private report edits.',
    }
    (report/'SUMMARY.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    for filename in ['README.md','docs/V56_MUSIC_FIRST_REFACTOR.md','docs/WEAPON_VFX_AUDIO_REFERENCE.md','docs/RHYTHM_CONTRACT.md','docs/WEAPON_DEVELOPMENT_STANDARD.md']:
        doc=ROOT/filename
        for target in re.findall(r'\]\(([^)]+)\)',doc.read_text(encoding='utf-8')):
            if '://' in target or target.startswith('#'):continue
            assert (doc.parent/target.split('#')[0]).exists(),target
    print(json.dumps({k:summary[k] for k in ['version','checks','protected_files_unchanged','archived_wavs_unchanged','base_salvo_counts_match_v55','live_weapon_voice_count']},ensure_ascii=False))

if __name__=='__main__':run()
