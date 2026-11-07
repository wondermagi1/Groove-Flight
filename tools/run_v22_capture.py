from pathlib import Path
import os
import subprocess

root = Path(__file__).resolve().parents[1]
env = os.environ.copy()
env['APPDATA'] = str(root / 'tests/profile-v22-capture')
engine = os.environ.get('GODOT_PATH', 'D:/Tool/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe')
args = [engine, '--rendering-method', 'forward_plus', '--position', '-4000,-2000',
        '--resolution', '1920x1080', '--windowed', '--path', str(root),
        '--script', 'res://tests/v22_native_barrage_review.gd', '--',
        '--grooveflight-test', '--capture-preview']
(root / 'work').mkdir(exist_ok=True)
with (root / 'work/v22-capture.log').open('w', encoding='utf-8') as log:
    result = subprocess.run(args, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=240)
print('V22 native capture exit', result.returncode, flush=True)
raise SystemExit(result.returncode)
