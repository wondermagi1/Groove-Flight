"""Prepare the three CC0 contact layers used by the runtime rhythm mix."""
import argparse
from hashlib import sha256
from io import BytesIO
import json
from math import gcd
from pathlib import Path
import wave
from zipfile import ZipFile

import numpy as np
from scipy.signal import butter, resample_poly, sosfilt


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "audio/authorized/feedback"
RATE = 22050
FILES = {"tap": ("click_002.wav", 16.), "accent": ("click_001.wav", 27.), "soft": ("click_005.wav", 19.)}


def convert(raw, output, milliseconds):
    with wave.open(BytesIO(raw), "rb") as wav:
        assert wav.getsampwidth() == 2
        source_rate = wav.getframerate()
        channels = wav.getnchannels()
        samples = np.frombuffer(wav.readframes(wav.getnframes()), dtype="<i2").reshape(-1, channels)
    signal = samples.mean(axis=1) / 32768.
    factor = gcd(RATE, source_rate)
    signal = resample_poly(signal, RATE // factor, source_rate // factor)
    signal = sosfilt(butter(2, 180., btype="highpass", fs=RATE, output="sos"), signal)
    leading = int(np.flatnonzero(abs(signal) > abs(signal).max() * .045)[0])
    start = max(0, leading - round(RATE * .0007))
    signal = signal[start:start + round(milliseconds * RATE / 1000)]
    attack = round(RATE * .0003)
    release = min(round(RATE * .004), len(signal) // 3)
    signal[:attack] *= np.linspace(0, 1, attack)
    signal[-release:] *= np.linspace(1, 0, release)
    pcm = np.rint(signal / abs(signal).max() * .84 * 32767).astype("<i2")
    with wave.open(str(output), "wb") as wav:
        wav.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        wav.writeframes(pcm.tobytes())
    return len(pcm)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path, help="Kenney Interface Sounds WAV archive")
    args = parser.parse_args()
    entries = []
    with ZipFile(args.archive) as pack:
        for role, (filename, milliseconds) in FILES.items():
            source, = (name for name in pack.namelist() if name.endswith("/" + filename))
            raw = pack.read(source)
            output = OUTPUT / f"rhythm_click_{role}.wav"
            count = convert(raw, output, milliseconds)
            entries.append({
                "role": role, "source_file": filename, "source_sha256": sha256(raw).hexdigest(),
                "file": output.name, "sha256": sha256(output.read_bytes()).hexdigest(),
                "frames": count, "sample_rate": RATE,
            })
    manifest = {
        "creator": "Kenney", "collection": "Interface Sounds", "license": "CC0-1.0",
        "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
        "source_page": "https://kenney.nl/assets/interface-sounds",
        "download_url": "https://codeload.github.com/Calinou/kenney-interface-sounds/zip/refs/heads/master",
        "archive_sha256": sha256(args.archive.read_bytes()).hexdigest(),
        "conversion": "Mono 22050 Hz PCM, transient trim, 180 Hz high-pass, short fades and peak normalization.",
        "samples": entries,
    }
    (OUTPUT / "RHYTHM_CLICKS_SOURCE.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
