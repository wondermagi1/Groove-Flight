"""Original 120 BPM stems and voices; no commercial-game audio is copied."""
from pathlib import Path
import math
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
RATE = 22050
STEP = .25
rng = np.random.default_rng(72841)

def save(path, samples):
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(samples, -.98, .98) * 32767).astype('<i2')
    with wave.open(str(path), 'wb') as out:
        out.setnchannels(1); out.setsampwidth(2); out.setframerate(RATE)
        out.writeframes(pcm.tobytes())

def envelope(t, decay):
    return np.minimum(t / .003, 1) * np.exp(-t * decay) * np.minimum((t[-1] - t) / .015, 1).clip(0, 1)

def tone(kind, frequency):
    duration = dict(pulse=.24, scatter=.19, beam=.38, missile=.34, nova=.52, chain=.25)[kind]
    t = np.arange(round(RATE * duration)) / RATE
    phase = 2 * np.pi * frequency * t
    if kind == 'pulse':
        sound = np.sin(phase) + .25 * np.sin(phase * 2) + .12 * np.sin(phase * 3)
        sound *= envelope(t, 14)
    elif kind == 'scatter':
        sound = (.65 * np.sin(phase) + .18 * np.sin(phase * 4) + .14 * rng.normal(size=t.size)) * envelope(t, 20)
    elif kind == 'beam':
        sound = np.sin(phase + .7 * np.sin(phase * 2) * np.exp(-t * 8)) * envelope(t, 9)
    elif kind == 'missile':
        sound = (np.sin(phase * .5 + .35 * np.exp(-t * 30)) + .18 * np.sin(phase)) * envelope(t, 13)
    elif kind == 'nova':
        sound = sum(np.sin(phase * ratio) * gain for ratio, gain in [(1, .6), (1.5, .28), (2, .2)]) * envelope(t, 8)
    else:
        sound = np.zeros(t.size)
        for delay, ratio in [(0., 1), (.065, 1.5), (.13, 2)]:
            u = (t - delay).clip(0)
            sound += np.sin(2 * np.pi * frequency * ratio * u) * np.exp(-u * 35) * (t >= delay) * np.minimum(u / .002, 1)
        sound *= np.minimum((t[-1] - t) / .015, 1).clip(0, 1)
    return sound * .52

def main():
    scale = [0, 3, 7, 10, 12, 10, 7, 3]
    for kind in ['pulse', 'scatter', 'beam', 'missile', 'nova', 'chain']:
        for step, semitones in enumerate(scale):
            frequency = 261.625565 * 2 ** (semitones / 12)
            save(ROOT / 'audio' / 'notes' / f'{kind}_{step}.wav', tone(kind, frequency))
    base = np.zeros(round(RATE * STEP * 8))
    def add(sound, when, gain=1):
        index = (np.arange(sound.size) + round(when * RATE)) % base.size
        np.add.at(base, index, sound * gain)
    for step in range(8):
        if step % 2 == 0:
            t = np.arange(round(RATE * .27)) / RATE
            phase = 2 * np.pi * (46 * t + 70 * .025 * (1 - np.exp(-t / .025)))
            add(np.sin(phase) * envelope(t, 19), step * STEP, .34 if step % 4 == 0 else .16)
        if step in [2, 6]:
            t = np.arange(round(RATE * .15)) / RATE
            noise = rng.normal(size=t.size); noise = noise - np.roll(noise, 1)
            add((noise * .19 + np.sin(t * 2 * np.pi * 180) * .17) * envelope(t, 32), step * STEP, .32)
        t = np.arange(round(RATE * .055)) / RATE
        noise = rng.normal(size=t.size); noise = noise - np.roll(noise, 1)
        add(noise * envelope(t, 105), step * STEP, .022 if step % 2 else .014)
    # Muted C-minor bass; the weapons provide the changing melody.
    for step, note in [(0, 0), (3, 7), (4, 3), (7, 10)]:
        t = np.arange(round(RATE * .22)) / RATE
        phase = 2 * np.pi * 65.406 * 2 ** (note / 12) * t
        add((np.sin(phase) + .18 * np.sin(phase * 2)) * envelope(t, 17), step * STEP, .13)
    save(ROOT / 'audio' / 'backing.wav', base)
    for name, freq in [('pickup', 1046.5), ('dash', 196), ('hit', 82.4), ('reward', 523.25)]:
        t = np.arange(round(RATE * (.22 if name == 'reward' else .09))) / RATE
        sample = np.sin(2 * np.pi * freq * t + (3 * np.exp(-t * 45) if name == 'hit' else 0))
        if name == 'reward': sample += .4 * np.sin(2 * np.pi * freq * 1.5 * t)
        save(ROOT / 'audio' / f'{name}.wav', sample * envelope(t, 30 if name != 'reward' else 15) * .45)
    print('Generated 48 pitched voices, 120 BPM backing and 4 original SFX.')

if __name__ == '__main__':
    main()
