"""Append the stern weapon's sampled instrument, preserving the existing 120."""
from pathlib import Path
import hashlib
import json
import subprocess
import wave
import numpy as np
from repair_recorded_audio_imports import import_sidecar

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'work/instrument-sources'
RATE = 22050
SCALE = [0, 2, 3, 5, 7, 8, 10, 12]


def main():
    path = ROOT / 'audio/instruments/MANIFEST.json'
    manifest = json.loads(path.read_text(encoding='utf-8'))
    records = [r for r in manifest['instruments'] if r['id'] != 'stern_fan']
    preserved = {s['file']: s['sha256'] for r in records for s in r['samples']}
    sounds = []
    for degree in SCALE:
        raw = SOURCE / 'stern-note.f32'
        result = subprocess.run([str(SOURCE / 'render_instrument_note.exe'),
            str(SOURCE / 'GeneralUser-GS.sf2'), '0', '45', str(60 + degree),
            '.07', '.55', str(raw)], check=True, capture_output=True, text=True)
        preset = result.stdout.strip()
        data = np.fromfile(raw, dtype='<f4').astype(np.float64)
        peak = float(abs(data).max())
        assert peak > .001
        active = np.flatnonzero(abs(data) > peak * .002)
        data = data[max(0, int(active[0]) - 22):]
        n = min(round(.014 * RATE), len(data))
        data[-n:] *= np.linspace(1, 0, n)
        data[:22] *= np.linspace(0, 1, 22)
        sounds.append(data)
    gain = min(.68 / max(abs(x).max() for x in sounds),
        .12 / max(1e-9, float(np.median([np.sqrt(np.mean(x*x)) for x in sounds]))))
    samples = []
    for index, data in enumerate(sounds):
        data *= gain
        dest = ROOT / f'audio/arsenal/notes/inst_stern_fan_{index}.wav'
        with wave.open(str(dest), 'wb') as stream:
            stream.setnchannels(1)
            stream.setsampwidth(2)
            stream.setframerate(RATE)
            stream.writeframes(np.rint(np.clip(data, -.94, .94) * 32767).astype('<i2').tobytes())
        dest.with_suffix('.wav.import').write_text(import_sidecar(dest), encoding='utf-8', newline='\n')
        samples.append({'pitch_index': index, 'root_midi': 60 + SCALE[index],
            'file': dest.relative_to(ROOT).as_posix(), 'seconds': len(data)/RATE,
            'sha256': hashlib.sha256(dest.read_bytes()).hexdigest(),
            'peak': float(abs(data).max()), 'rms': float(np.sqrt(np.mean(data*data)))})
    records.append({'id': 'stern_fan', 'instrument': '拨弦弦乐', 'voice': 'inst_stern_fan',
        'bank': 0, 'program': 45, 'preset_name': preset, 'root_midi': 60,
        'percussion': False, 'gain': gain, 'hold': .07, 'release': .55,
        'electronic_mix': 0., 'samples': samples})
    assert all(hashlib.sha256((ROOT / f).read_bytes()).hexdigest() == digest
               for f, digest in preserved.items())
    manifest['instruments'] = records
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'Added 8 stern samples; {len(preserved)} existing samples hash-verified unchanged')


if __name__ == '__main__':
    main()
