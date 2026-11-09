"""Build the current piano / bowed strings / harp palette from one policy.

Offline only. Historical builders remain historical; use this for V25 onward.
No external download, oscillator layer, reverb or runtime DSP is introduced.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import wave
import argparse

import numpy as np
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'work/instrument-sources'
RATE = 22050


def write_wav(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(np.rint(np.clip(data, -.98, .98) * 32767).astype('<i2').tobytes())


def sync_catalog(entries):
    path = ROOT / 'scripts/arsenal_catalog.gd'
    text = path.read_text(encoding='utf-8')
    start = text.index('## Generated from audio/instruments/CHAMBER_PALETTE.json')
    end = text.index('const LEGACY_WEAPON_ALIASES=', start)
    def literal(value):
        return json.dumps(value, ensure_ascii=False, separators=(',', ':'))
    lines = ['## Generated from audio/instruments/CHAMBER_PALETTE.json by build_chamber_instruments.py.',
        'const INSTRUMENTS=' + literal({e['id']: e['instrument'] for e in entries}),
        'const INSTRUMENT_ROOTS=' + literal({e['id']: e['root_midi'] for e in entries}),
        'const INSTRUMENT_FAMILIES=' + literal({e['id']: e['instrument_family'] for e in entries}),
        'const INSTRUMENT_PROGRAMS=' + literal({e['id']: e['program'] for e in entries}),
        'const INSTRUMENT_GROUP_OVERRIDES=' + literal({e['id']: e['instrument_group'] for e in entries if e.get('instrument_group')}),
        'const PERCUSSION_IDS=[]',
        'const NEW_INSTRUMENTS=' + literal({e['id']: e['instrument'] for e in entries
            if e['id'] in ['gilded_helix', 'weave_cross', 'crown_orbit', 'stern_fan'] or e.get('fleet_barrage', False)})]
    path.write_text(text[:start] + '\n'.join(lines) + '\n' + text[end:], encoding='utf-8', newline='\n')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ids', help='Comma-separated IDs to render, retaining existing samples for other voices.')
    parser.add_argument('--preview-dir', help='Repository-relative audition output directory; preserves historical previews.')
    args = parser.parse_args()
    policy = json.loads((ROOT / 'audio/instruments/CHAMBER_PALETTE.json').read_text(encoding='utf-8'))
    assert len(policy['weapons']) > 0 and len({e['id'] for e in policy['weapons']}) == len(policy['weapons'])
    selected = set(args.ids.split(',')) if args.ids else {e['id'] for e in policy['weapons']}
    assert selected <= {e['id'] for e in policy['weapons']}
    assert all(e['instrument_family'] in policy['allowed_families'] and e['bank'] == 0
               and e['program'] in policy.get('allowed_programs',[0, 1, 40, 41, 42, 46]) and e['electronic_mix'] == 0
               for e in policy['weapons'])
    exe = SOURCE / 'render_instrument_note.exe'
    subprocess.run(['E:/MinGW/bin/gcc.exe', '-O2', '-std=c99', '-I', str(SOURCE),
                    str(ROOT / 'tools/render_instrument_note.c'), '-o', str(exe), '-lm'], check=True, timeout=60)
    manifest_path = ROOT / 'audio/instruments/MANIFEST.json'
    old_manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    existing = {e['id']: e for e in old_manifest['instruments']}
    historical = ROOT / 'audio/instruments/archives/MANIFEST-before-v25.json'
    if not historical.exists():
        historical.parent.mkdir(parents=True, exist_ok=True)
        historical.write_bytes(manifest_path.read_bytes())
    font = SOURCE / 'GeneralUser-GS.sf2'
    assert hashlib.sha256(font.read_bytes()).hexdigest() == old_manifest['soundfont_sha256']
    records, demo, timeline = [], [], []
    for entry in policy['weapons']:
        if entry['id'] not in selected:
            records.append(existing[entry['id']])
            continue
        sounds = []
        for degree in policy['scale_semitones']:
            raw = SOURCE / 'chamber-note.f32'
            command = [str(exe), str(font), str(entry['bank']), str(entry['program']),
                str(entry['root_midi'] + degree), str(entry['hold']), str(entry['release']), str(raw),
                str(entry['velocity'])]
            if entry.get('source_attack_ms'):
                command.append(str(entry['source_attack_ms'] / 1000.))
            result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=30)
            data = np.fromfile(raw, dtype='<f4').astype(np.float64)
            peak = float(np.max(np.abs(data)))
            assert peak > .001
            active = np.flatnonzero(np.abs(data) > peak * .002)
            data = data[max(0, int(active[0]) - 22):]
            # Smooth the source, not the music transport: no added playback latency.
            data = sosfilt(butter(2, entry['lowpass_hz'], fs=RATE, output='sos'), data)
            data -= float(data.mean())
            attack = min(round(entry['attack_ms'] * RATE / 1000), len(data))
            tail = min(round(.035 * RATE), len(data))
            data[:attack] *= np.sin(np.linspace(0, np.pi / 2, attack)) ** 2
            data[-tail:] *= np.cos(np.linspace(0, np.pi / 2, tail)) ** 2
            sounds.append(data)
        window = round(.30 * RATE)
        energy = [float(np.sqrt(np.mean(x[:window] ** 2))) for x in sounds]
        gain = min(entry['peak_limit'] / max(float(np.max(np.abs(x))) for x in sounds),
                   entry['target_rms'] / max(1e-9, float(np.median(energy))))
        samples = []
        for index, data in enumerate(sounds):
            data *= gain
            path = ROOT / f'audio/arsenal/notes/inst_{entry["id"]}_{index}.wav'
            write_wav(path, data)
            # Never touch existing Godot import UIDs. New raw PCM files also
            # load directly at runtime before the editor creates import sidecars.
            samples.append({'pitch_index': index, 'root_midi': entry['root_midi'] + policy['scale_semitones'][index],
                'file': path.relative_to(ROOT).as_posix(), 'seconds': len(data) / RATE,
                'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'peak': float(np.max(np.abs(data))),
                'rms': float(np.sqrt(np.mean(data ** 2))),
                'attack_300ms_rms': float(np.sqrt(np.mean(data[:window] ** 2)))})
        records.append({**entry, 'voice': 'inst_' + entry['id'], 'preset_name': result.stdout.strip(),
                        'percussion': False, 'gain': gain, 'samples': samples})
        # Direct timbre audition at the current1.5s scan interval.
        block_seconds = 3.1
        block = np.zeros(round(RATE * block_seconds))
        for at in [0, 1.5]:
            start = round(at * RATE)
            length = min(len(sounds[0]), len(block) - start)
            block[start:start + length] += sounds[0][:length] * .8
        timeline.append({'id': entry['id'], 'instrument': entry['instrument'],
                         'start_seconds': len(demo) * block_seconds, 'end_seconds': (len(demo) + 1) * block_seconds})
        demo.append(block)
        print(entry['id'], result.stdout.strip(), 'peak', round(samples[0]['peak'], 3), flush=True)
    manifest = {k: old_manifest[k] for k in ['source', 'homepage', 'license', 'soundfont_sha256',
                                            'renderer', 'renderer_sha256', 'format', 'fixed_battle_pitch_index']}
    manifest.update(palette_revision=policy['revision'], allowed_families=policy['allowed_families'],
                    renderer_driver_sha256=hashlib.sha256((ROOT / 'tools/render_instrument_note.c').read_bytes()).hexdigest(),
                    processing='Acoustic sampled instruments with sustained note-on/body and natural note-off release,optional clear-bow attack,offline low-pass and onset/tail fades;shared gain across8pitches. No synthetic layer,time stretching or playback speed change.',
                    instruments=records)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    sync_catalog(policy['weapons'])
    preview = ROOT / args.preview_dir / 'chamber-voices.wav' if args.preview_dir else ROOT / ('docs/audio-v30/three-forward-voices.wav' if args.ids else 'docs/audio-current/chamber-voices.wav')
    write_wav(preview, np.concatenate(demo))
    preview.with_suffix('.json').write_text(json.dumps({'scope': 'Sequential offline current fixed-voice auditions; each repeats after1.5s. Direct timbre audition,not charge eligibility or live capture.',
        'seconds': len(demo) * block_seconds, 'timeline': timeline}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Built{len(selected)*8} samples; palette now{len(records)} instruments; existing unselected samples preserved')


if __name__ == '__main__':
    main()
