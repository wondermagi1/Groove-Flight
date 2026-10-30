"""Fetch original-resolution Solar System Scope maps and record attribution.

No upscaling or AI detail fabrication. Runtime material adds lighting separately.
"""
from concurrent.futures import ThreadPoolExecutor
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin
import hashlib
import json
import urllib.request
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PAGE = 'https://www.solarsystemscope.com/textures/'
FILES = {
    'mercury': '8k_mercury.jpg',
    'venus': '4k_venus_atmosphere.jpg',
    'earth': '8k_earth_daymap.jpg',
    'earth_night': '8k_earth_nightmap.jpg',
    'earth_clouds': '8k_earth_clouds.jpg',
    'earth_normal': '8k_earth_normal_map.tif',
    'earth_specular': '8k_earth_specular_map.tif',
    'mars': '8k_mars.jpg',
    'jupiter': '8k_jupiter.jpg',
    'saturn': '8k_saturn.jpg',
    'saturn_ring': '8k_saturn_ring_alpha.png',
    'uranus': '2k_uranus.jpg',
    'neptune': '2k_neptune.jpg',
    'stars': '8k_stars_milky_way.jpg',
}

class Links(HTMLParser):
    def __init__(self):
        super().__init__(); self.values = {}
    def handle_starttag(self, tag, attrs):
        value = dict(attrs).get('href', '')
        if tag == 'a' and value:
            self.values[value.rsplit('/',1)[-1]] = urljoin(PAGE, value)

def request(url):
    return urllib.request.Request(url, headers={'User-Agent': 'BeatDrift-art-source/1.0'})

def main():
    with urllib.request.urlopen(request(PAGE),timeout=60) as response:
        page = response.read().decode('utf-8')
    links = Links(); links.feed(page)
    destination = ROOT/'assets'/'planets'
    destination.mkdir(parents=True,exist_ok=True)
    print(json.dumps({key: links.values.get(filename,'MISSING') for key,filename in FILES.items()},indent=2),flush=True)
    def download(entry):
        key, filename = entry
        if filename not in links.values:
            return {'id': key, 'missing': filename}
        source_folder=ROOT/'source_art'/'planets' if filename.endswith('.tif') else destination
        source_folder.mkdir(parents=True,exist_ok=True)
        target = source_folder/filename
        if not target.exists():
            with urllib.request.urlopen(request(links.values[filename]),timeout=90) as response:
                data = response.read(64*1024*1024+1)
                if len(data)>64*1024*1024: raise ValueError('Unexpected large image: '+filename)
            temporary = target.with_suffix(target.suffix+'.tmp')
            temporary.write_bytes(data); temporary.replace(target)
        data = target.read_bytes()
        print('Downloaded',filename,len(data),flush=True)
        with Image.open(target) as image:
            width,height=image.size
            if target.suffix=='.tif':
                runtime=destination/(target.stem+'.png')
                image.save(runtime,format='PNG')  # Format conversion only; preserve pixel values/resolution.
            else: runtime=target
        return {'id':key,'file':'res://assets/planets/'+runtime.name,'url':links.values[filename],
                'width':width,'height':height,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
    with ThreadPoolExecutor(max_workers=2) as pool:
        assets = list(pool.map(download, FILES.items()))
    manifest={'source':PAGE,'credit':'Solar System Scope / INOVE','license':'CC BY 4.0',
              'license_url':'https://creativecommons.org/licenses/by/4.0/','assets':assets}
    (destination/'sources.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')

if __name__=='__main__': main()
