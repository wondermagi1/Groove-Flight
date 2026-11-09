"""Compare V41 against the uploaded V40 snapshot, not a rewritten manifest."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[1]
BASE='fa855416abb9f7976ee1e64a3958cc2b1d038e50'
def old_json(path):
    return json.loads(subprocess.check_output(['git','show',f'{BASE}:{path}'],cwd=ROOT))
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    failures=[]; samples={}
    for weapon in old_json('audio/weapon_codex.json')['weapons']:
        for sample in weapon['samples']: samples[sample['path'].removeprefix('res://')]=sample['sha256']
        for sample in weapon['dynamics']['layers']: samples[sample['file']]=sample['sha256']
    for path,expected in samples.items():
        if digest(ROOT/path)!=expected: failures.append('Changed preserved sample: '+path)
    old=old_json('docs/data-v40/weapon-selection.json')['weapons']
    current={w['id']:w for w in json.loads((ROOT/'docs/data-v41/weapon-selection.json').read_text(encoding='utf-8'))['weapons']}
    fields=['family','damage','count','speed','life','spread','pierce','explosion','homing','bounces','charge','width','rarity','cost','voice','instrument','sample_root','visual_class','emission','color']
    for weapon in old:
        for key in fields:
            if weapon.get(key)!=current.get(weapon['id'],{}).get(key): failures.append(f'Changed {weapon["id"]}/{key}')
    native='0046a79a8dd2eb63f7c13ea4d3e20720651b851aaa71892902701077c3c2c84e'
    if digest(ROOT/'native/crowd/groove_crowd.windows.x86_64.dll')!=native: failures.append('Changed native crowd DLL')
    report={'baseline_commit':BASE,'old_samples_verified':len(samples),'old_weapon_profiles_verified':len(old),'fields':fields,'native_crowd_sha256':native,'failures':failures,'scope':'Immutable uploaded V40 source comparison;new12WAVs and explicit equipped projectile-field effects are separately checked.'}
    (ROOT/'docs/data-v41/asset-preservation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8',newline='\n')
    print('Preserved',len(samples),'WAVs,',len(old),'weapon profiles and native crowd DLL;failures=',len(failures))
    if failures: raise SystemExit('\n'.join(failures))
if __name__=='__main__': main()
