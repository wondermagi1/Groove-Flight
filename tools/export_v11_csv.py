"""Run Godot tests/v11_export_tables.gd first, then this UTF-8 table exporter."""
from pathlib import Path
import json,csv,wave,math,struct
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'docs/data-v11'
def emit(name,rows):
    if not rows:return
    with (DEST/name).open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def text(v):return json.dumps(v,ensure_ascii=False) if isinstance(v,(dict,list)) else v
def main():
    data=json.loads((DEST/'tables.json').read_text(encoding='utf-8'))
    items=data['catalog'];lookup={x['id']:x for x in items}
    emit('equipment-240.csv',[{**{k:text(v) for k,v in x.items()},'source':'Original BeatDrift catalog; 8 trajectory rules upgraded in V11','caps':'level4; rule scaling 1+.35*(level-1); see protocol'} for x in items])
    emit('weapons-32.csv',[{**{k:text(v) for k,v in x.items()},'source':f"audio/arsenal/notes/{x['voice']}_0..7.wav",'interval_seconds':x['charge']*2,'pan_A_B_C':'-0.46 / 0 / +0.46','hit_feedback':'family body + impact sparks / local blast when explosion>0','gate_seconds':x['life'],'caps':'beam12 / chain8,links32 / others96'} for x in items if x['category']=='weapon'])
    emit('planet-waves-67.csv',[{'planet':x['planet'],'wave':x['wave'],**x['profile'],**x['combat'],'role_counts_out_of_20':text(x['role_counts_out_of_20']),'boss_motif':x['boss_motif']} for x in data['routes']])
    emit('build-layouts.csv',[{'path':b['path']['name'],'ID':id,'name':lookup[id]['name'],'track':'ABC'[at//8],'head_from_1':at%8+1,'width':lookup[id]['width'],'price':lookup[id]['cost'],'rules':text(lookup[id]['rules'])} for b in data['builds'] for id,at in b['path']['layout']])
    audio=[]
    for p in sorted((ROOT/'docs/audio-v11').glob('*.wav')):
        with wave.open(str(p),'rb') as f:ch=f.getnchannels();rate=f.getframerate();n=f.getnframes();raw=f.readframes(n)
        values=struct.unpack('<'+'h'*(len(raw)//2),raw)
        audio.append({'file':p.name,'channels':ch,'rate':rate,'seconds':n/rate,'peak':max(map(abs,values))/32768.,'rms':math.sqrt(sum(x*x for x in values)/len(values))/32768.,'scope':'PCM only; human listening pending'})
    (DEST/'audio-measurements.json').write_text(json.dumps(audio,ensure_ascii=False,indent=2),encoding='utf-8')
if __name__=='__main__':main()
