"""Fetch seven official CC-BY downloads as synchronized game music assets.

Original MP3s stay in ignored work cache; full converted OGGs ship with credits.
Filaments is preserved byte-for-byte from the previously licensed game resource.
"""
from pathlib import Path
import concurrent.futures,hashlib,json,shutil,subprocess,urllib.request
ROOT=Path(__file__).resolve().parents[1]
ROWS=[
 ('mercury','filaments','Filaments','2019/10/sb_filaments.mp3','清晰起航'),
 ('venus','helios','Helios','2020/05/sb_helios.mp3','升腾弦乐'),
 ('earth','reverie','Reverie','2020/03/sb_reverie.mp3','钢琴与归航'),
 ('mars','legionnaire','Legionnaire (Original)','https://www.scottbuckley.com.au/wp-content/audio/sb_legionnaire.mp3','行进重拍'),
 ('jupiter','titan','Titan','2018/06/sb_titan.mp3','宏大交响'),
 ('saturn','cassini','Cassini','2014/07/sb_cassini.mp3','光环与流动'),
 ('uranus','luminance','Luminance','2020/07/sb_luminance.mp3','七拍极轴'),
 ('neptune','omega','Omega','2019/08/sb_omega.mp3','终章递进'),
]
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def one(row):
 planet,id,title,relative,mood=row
 folder=ROOT/'audio/authorized/scott_buckley/planets';folder.mkdir(exist_ok=True)
 source_url=relative if relative.startswith('https:') else 'https://www.scottbuckley.com.au/library/wp-content/uploads/'+relative
 if id=='filaments':
  ogg=ROOT/'audio/authorized/scott_buckley/filaments.ogg';source_sha=json.loads((ogg.parent/'SOURCE.json').read_text(encoding='utf-8'))['files']['sb_filaments.mp3']['sha256']
 else:
  cache=ROOT/'work/planet-music';cache.mkdir(exist_ok=True);mp3=cache/(id+'.mp3');ogg=folder/(id+'.ogg')
  if not mp3.exists():
   request=urllib.request.Request(source_url,headers={'User-Agent':'GrooveFlight-asset-import/1.0'})
   with urllib.request.urlopen(request,timeout=90) as response:mp3.write_bytes(response.read())
  source_sha=digest(mp3)
  if not ogg.exists():subprocess.run([shutil.which('ffmpeg'),'-v','error','-y','-i',str(mp3),'-vn','-ar','44100','-ac','2','-c:a','libvorbis','-q:a','5',str(ogg)],check=True)
 probe=json.loads(subprocess.check_output([shutil.which('ffprobe'),'-v','error','-show_entries','format=duration','-of','json',str(ogg)]))
 result={'planet':planet,'id':id,'title':title,'artist':'Scott Buckley','mood':mood,'source_page':f'https://www.scottbuckley.com.au/library/{id}/','download_url':source_url,'license':'CC BY 4.0','license_url':'https://creativecommons.org/licenses/by/4.0/','license_statement':'https://www.scottbuckley.com.au/library/using-this-music/','retrieved':'2026-11-11','credit':f"'{title}' by Scott Buckley - released under CC-BY 4.0. www.scottbuckley.com.au",'source_sha256':source_sha,'runtime':'res://'+ogg.relative_to(ROOT).as_posix(),'sha256':digest(ogg),'duration':float(probe['format']['duration']),'chart':f'res://audio/charts/planets/{planet}.json','conversion':'Full source converted to stereo 44100Hz Vorbis q5; no cuts, tempo/pitch/volume changes. Game-synchronized use, independent user music bus.'}
 print('READY',planet,title,round(result['duration'],2),flush=True);return result
def run():
 with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:rows=list(pool.map(one,ROWS))
 (ROOT/'audio/PLANET_MUSIC.json').write_text(json.dumps({'schema':1,'revision':'v53','tracks':rows},ensure_ascii=False,indent=2),encoding='utf-8')
 text='# Planet music attribution\n\nMusic integrated with Groove Flight gameplay. Each track by Scott Buckley, CC BY 4.0.\n\n'
 for r in rows:text+=f"- {r['planet']}: {r['credit']} [Official source]({r['source_page']})\n"
 text+='\n[License](https://creativecommons.org/licenses/by/4.0/) · [Official usage](https://www.scottbuckley.com.au/library/using-this-music/). Full-source transcoding only; no source retiming. Source hashes and conversion details: audio/PLANET_MUSIC.json.\n'
 (ROOT/'audio/authorized/scott_buckley/planets/LICENSE.md').write_text(text,encoding='utf-8')
 print('IMPORTED',len(rows),'distinct planet songs',flush=True)
if __name__=='__main__':run()
