"""Original weapon instruments, eight C-minor pitches per independent weapon.

Data comes from arsenal_catalog.gd via export_arsenal_audio.gd. Audio is authored
procedurally, without reference-game samples. PCM import settings are deliberate.
"""
from pathlib import Path
import hashlib
import json
import math
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050
SCALE = [0, 2, 3, 5, 7, 8, 10, 12]


def save(name, samples):
    target = ROOT / 'audio' / 'arsenal' / 'notes' / (name + '.wav')
    target.parent.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(samples, -.95, .95) * 32767).astype('<i2')
    with wave.open(str(target), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    source = 'res://' + target.relative_to(ROOT).as_posix()
    digest = hashlib.md5(source.encode()).hexdigest()
    imported = f'res://.godot/imported/{target.name}-{digest}.sample'
    # Godot preserves these options during import; default QOA would prevent
    # the native composer from reading individual signed16-bit samples.
    target.with_suffix('.wav.import').write_text(
        '[remap]\nimporter="wav"\ntype="AudioStreamWAV"\n'
        f'path="{imported}"\n\n[deps]\nsource_file="{source}"\n'
        f'dest_files=["{imported}"]\n\n[params]\n'
        'force/8_bit=false\nforce/mono=false\nforce/max_rate=false\n'
        'force/max_rate_hz=44100\nedit/trim=false\nedit/normalize=false\n'
        'edit/loop_mode=0\nedit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n',
        encoding='utf-8')


def oscillator(phase, shape, frequency):
    if shape == 'sine':
        return np.sin(phase)
    harmonics = max(1, min(25, int(RATE / (2 * frequency)) - 1))
    result = np.zeros_like(phase)
    for harmonic in range(1, harmonics + 1):
        if shape == 'square' and harmonic % 2 == 0:
            continue
        if shape == 'triangle':
            if harmonic % 2 == 0:
                continue
            gain = (-1) ** ((harmonic - 1) // 2) / harmonic ** 2
        else:
            gain = (1 if harmonic % 2 else -1) / harmonic
        result += np.sin(phase * harmonic) * gain
    return result * (1.0 if shape == 'triangle' else .66)


def instrument(recipe, index, seed):
    params = recipe.get('timbre', {})
    decay = float(params.get('decay', .18))
    duration = min(1.75, max(.20, decay * 3.2))
    time = np.arange(round(RATE * duration)) / RATE
    frequency = 261.625565 * 2 ** ((SCALE[index] + 12 * int(params.get('octave', 0))) / 12)
    detune = 2 ** (float(params.get('detune', 0)) / 1200)
    phase = 2 * np.pi * frequency * time
    phase += float(params.get('fm', 0)) * np.sin(phase * 2) * np.exp(-time * 9)
    shape = params.get('wave', 'sine')
    if shape == 'noise':
        random = np.random.default_rng(seed + index)
        noise = random.normal(size=time.size)
        noise = np.convolve(noise, np.ones(5) / 5, mode='same')
        signal = np.sin(phase) * .76 + noise * .24
    else:
        signal = oscillator(phase, shape, frequency) * .78
        signal += np.sin(phase * detune + .1) * .22
    # Distinct body/envelope and a short musical echo give each weapon an
    # audible identity without burying the base rhythm in long reverb.
    envelope = np.minimum(time / .004, 1) * np.exp(-time / max(.035, decay))
    envelope *= np.minimum((duration - time) / .035, 1).clip(0, 1)
    signal *= envelope
    delay = int(RATE * (.045 + (seed % 7) * .008))
    signal[delay:] += signal[:-delay].copy() * .12
    peak = max(.001, float(np.max(np.abs(signal))))
    return signal / peak * .42


def main():
    recipes = json.loads((ROOT / 'audio' / 'arsenal' / 'recipes.json').read_text(encoding='utf-8'))
    synthesized = [row for row in recipes if not row.get('recorded_audio', False)]
    recorded = [row for row in recipes if row.get('recorded_audio', False)]
    assert len(recipes) == 36 and len(synthesized) == 32 and len(recorded) == 4
    assert len({row['voice'] for row in recipes}) == 36
    hashes = {}
    for number, recipe in enumerate(synthesized):
        seed = 1201 + number * 97
        for pitch in range(8):
            samples = instrument(recipe, pitch, seed)
            save(f"{recipe['voice']}_{pitch}", samples)
            if pitch == 0:
                digest = hashlib.sha256(samples.astype('<f4').tobytes()).hexdigest()
                assert digest not in hashes, 'Duplicate weapon timbre: ' + recipe['id']
                hashes[digest] = recipe['id']
    for category, decay in [('mod', .05), ('rhythm', .025), ('defense', .11), ('core', .18)]:
        for pitch in range(8):
            time = np.arange(round(RATE * .36)) / RATE
            random = np.random.default_rng(4000 + len(category) * 23 + pitch)
            frequency = {'mod': 720, 'rhythm': 3400, 'defense': 73, 'core': 250}[category]
            carrier = np.sin(2 * np.pi * frequency * time)
            if category in ['mod', 'rhythm']:
                noise = random.normal(size=time.size)
                carrier = .15 * carrier + .25 * (noise - np.roll(noise, 1))
            sound = carrier * np.minimum(time / .002, 1) * np.exp(-time / decay)
            sound *= np.minimum((time[-1] - time) / .03, 1).clip(0, 1)
            save(f'support_{category}_{pitch}', sound * .26)
    report = {'weapons': len(recipes), 'synthesized_weapons': len(synthesized),
              'recorded_audio_weapons': len(recorded), 'weapon_sample_files': 288,
              'synthesized_pitched_samples': 256, 'recorded_event_slices': 32,
              'recorded_transposition': False, 'percussion_samples': 32,
              'rate': RATE, 'format': 'mono PCM16',
              'unique_synthesized_first_pitch_hashes': len(hashes),
              'origin': '32 original procedural synthesis instruments plus 4 authorized recorded-audio event groups'}
    (ROOT / 'audio' / 'arsenal' / 'generation_report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
