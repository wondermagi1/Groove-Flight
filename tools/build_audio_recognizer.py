"""Build the offline Windows audio-to-score helper in an isolated venv.

Downloads public wheel/model files from PyPI and Spotify's pinned repository;
never installs into the player's or system Python environment.
"""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import shutil
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'work' / 'audio-build'
REVISION = 'fa5997af0a8210982619003269994a1be25eddf3'

def fetch(url, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(url, timeout=90) as source:
        path.write_bytes(source.read())

def main():
    from pip._vendor.packaging.tags import sys_tags
    from pip._vendor.packaging.utils import parse_wheel_filename
    from pip._vendor.packaging.requirements import Requirement
    tags = list(sys_tags())
    wheels = BUILD / 'wheels'
    pending = ['numpy', 'miniaudio', 'onnxruntime', 'pyinstaller']
    if '--test-tools' in sys.argv:
        pending.append('lameenc')
    chosen = {}
    lock = ROOT / 'third_party' / 'audio-recognizer' / 'build-versions.json'
    locked = json.loads(lock.read_text(encoding='utf-8')) if lock.exists() else {}
    while pending:
        requirement = Requirement(pending.pop(0))
        if requirement.marker and not requirement.marker.evaluate({'extra': ''}):
            continue
        if requirement.name in chosen:
            if not requirement.specifier.contains(chosen[requirement.name]):
                raise ValueError('Conflicting build dependency: ' + str(requirement))
            continue
        pinned = '/' + locked[requirement.name] if requirement.name in locked else ''
        with urllib.request.urlopen('https://pypi.org/pypi/' + requirement.name + pinned + '/json', timeout=60) as response:
            package = json.load(response)
        version = package['info']['version']
        if not requirement.specifier.contains(version):
            raise ValueError('Pin a compatible dependency: ' + str(requirement))
        candidates = []
        for item in package['urls']:
            if not item['filename'].endswith('.whl'):
                continue
            wheel_tags = parse_wheel_filename(item['filename'])[3]
            order = next((i for i, tag in enumerate(tags) if tag in wheel_tags), None)
            if order is not None:
                candidates.append((order, item))
        if not candidates:
            raise ValueError('No compatible Windows wheel: ' + requirement.name)
        item = min(candidates, key=lambda value: value[0])[1]
        target = wheels / item['filename']
        if not target.exists():
            print('Downloading', item['filename'], flush=True)
            fetch(item['url'], target)
        if hashlib.sha256(target.read_bytes()).hexdigest() != item['digests']['sha256']:
            raise ValueError('Wheel checksum mismatch: ' + target.name)
        chosen[requirement.name] = version
        pending.extend(package['info'].get('requires_dist') or [])
    model = ROOT / 'tools' / 'models' / 'basic_pitch.onnx'
    if not model.exists():
        fetch(f'https://raw.githubusercontent.com/spotify/basic-pitch/{REVISION}/basic_pitch/saved_models/icassp_2022/nmp.onnx', model)
    license_path = ROOT / 'third_party' / 'basic-pitch' / 'LICENSE'
    if not license_path.exists():
        fetch(f'https://raw.githubusercontent.com/spotify/basic-pitch/{REVISION}/LICENSE', license_path)
    venv = BUILD / 'venv'
    python = venv / 'Scripts' / 'python.exe'
    if not python.exists():
        subprocess.run([sys.executable, '-m', 'venv', '--without-pip', str(venv)], check=True)
    env = dict(os.environ, TEMP=str(BUILD / 'tmp'), TMP=str(BUILD / 'tmp'))
    Path(env['TEMP']).mkdir(exist_ok=True)
    subprocess.run([sys.executable, '-m', 'pip', '--python', str(python), 'install', '--no-index', '--find-links', str(wheels), *[f'{k}=={v}' for k,v in chosen.items()]], check=True, env=env)
    (BUILD / 'dependency-lock.json').write_text(json.dumps(chosen, indent=2), encoding='utf-8')
    collect_licenses(venv)
    if '--dependencies-only' in sys.argv:
        return
    # Godot launches this with open_console=false; console mode also permits
    # useful diagnostics when a developer runs it directly from a terminal.
    subprocess.run([str(python), '-m', 'PyInstaller', '--noconfirm', '--onedir', '--console',
                    '--name', 'BeatDriftTranscribe', '--distpath', str(ROOT / 'tools' / 'audio_recognizer'),
                    '--workpath', str(BUILD / 'freeze'), '--specpath', str(BUILD),
                    '--add-data', str(model) + ';models', '--collect-all', 'onnxruntime',
                    '--hidden-import', '_cffi_backend',
                    '--copy-metadata', 'numpy', '--copy-metadata', 'miniaudio', '--copy-metadata', 'onnxruntime',
                    str(ROOT / 'tools' / 'transcribe_audio.py')], check=True, env=env)

def collect_licenses(venv):
    site = venv / 'Lib' / 'site-packages'
    output = ROOT / 'third_party' / 'audio-recognizer'
    output.mkdir(parents=True, exist_ok=True)
    names = ['numpy', 'onnxruntime', 'miniaudio', 'cffi', 'pycparser', 'flatbuffers', 'protobuf', 'packaging', 'pyinstaller']
    for name in names:
        for directory in site.glob(name+'-*.dist-info'):
            for source in directory.rglob('*'):
                if source.is_file() and (source.name.lower().startswith(('license','copying','notice')) or 'licenses' in source.parts):
                    target = output / name / source.relative_to(directory)
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(source, target)
    python_license = Path(sys.base_prefix) / 'LICENSE.txt'
    if python_license.exists():
        shutil.copyfile(python_license, output / 'Python-LICENSE.txt')
    shutil.copyfile(BUILD / 'dependency-lock.json', output / 'build-versions.json')

if __name__ == '__main__':
    main()
