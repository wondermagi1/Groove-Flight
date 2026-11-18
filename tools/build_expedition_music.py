"""Import the licensed expedition soundtrack and create its three-key charts."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import quote
from urllib.request import Request, urlopen
import hashlib
import json
import subprocess

import numpy as np
from scipy.ndimage import gaussian_filter1d
from scipy.signal import find_peaks

ROOT = Path(__file__).resolve().parents[1]
OFFICIAL = "https://incompetech.com/music/royalty-free/"
LICENSE = "https://creativecommons.org/licenses/by/4.0/"
TRACKS = [
    ("mercury", "limit_70", "Limit 70", "USUAN1900042", 102.65, "电子巡航"),
    ("venus", "vibing_over_venus", "Vibing Over Venus", "USUAN2300005", 94., "律动爵士"),
    ("earth", "space_jazz", "Space Jazz", "USUAN2100030", 89., "太空爵士"),
    ("mars", "brain_dance", "Brain Dance", "USUAN2300006", 124., "赛博合成器"),
    ("jupiter", "shiny_tech", "Shiny Tech", "USUAN1100078", 138., "电子舞曲"),
    ("saturn", "voxel_revolution", "Voxel Revolution", "USUAN2000025", 122., "芯片舞曲"),
    ("uranus", "tech_live", "Tech Live", "USUAN1700030", 124., "电子切分"),
    ("neptune", "laser_groove", "Laser Groove", "USUAN1700017", 140., "合成器陷阱节拍"),
]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def import_track(track):
    planet, key, title, isrc, bpm, mood = track
    source = ROOT / "work/expedition-music" / f"{key}.mp3"
    target = ROOT / "audio/authorized/incompetech" / f"{key}.ogg"
    url = f"{OFFICIAL}mp3-royaltyfree/{quote(title)}.mp3"
    fallback = f"{OFFICIAL}mp3-royaltyfree/{quote(title)}.mp3".replace("https://incompetech.com/", "https://www.incompetech.com/")
    if not source.exists():
        error = None
        for download in (url, fallback):
            try:
                with urlopen(Request(download, headers={"User-Agent": "GrooveFlight soundtrack importer"}), timeout=28) as response:
                    data = response.read()
                if data[:3] != b"ID3" and data[:1] != b"\xff":
                    raise ValueError(f"Expected MP3 at {download}")
                source.write_bytes(data)
                url = download
                error = None
                break
            except (OSError, ValueError) as exc:
                error = exc
        if error:
            raise error
    if not target.exists():
        subprocess.run([
            "ffmpeg", "-v", "error", "-y", "-i", str(source), "-vn", "-ac", "2", "-ar", "44100",
            "-c:a", "libvorbis", "-q:a", "4", str(target),
        ], check=True)
    duration = float(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=nw=1:nk=1", str(target),
    ]))
    row = {
        "planet": planet, "id": key, "title": title, "artist": "Kevin MacLeod", "mood": mood,
        "source_page": f"{OFFICIAL}index.html?Search=Search&isrc={isrc}", "download_url": url,
        "license": "CC BY 4.0", "license_url": LICENSE, "retrieved": "2026-11-18",
        "credit": f"{title} by Kevin MacLeod (incompetech.com), CC BY 4.0",
        "source_sha256": digest(source), "runtime": "res://" + target.relative_to(ROOT).as_posix(),
        "sha256": digest(target), "duration": duration, "published_bpm": bpm,
        "chart": f"res://audio/charts/expeditions/{planet}.json",
        "conversion": "Full source transcoded to stereo Ogg Vorbis; original playback speed and pitch.",
    }
    chart = make_chart(target, row)
    save(ROOT / row["chart"].removeprefix("res://"), chart, indent=None)
    print(planet, title, round(duration, 1), len(chart["events"]), round(chart["estimated_bpm"], 2), flush=True)
    return row


def make_chart(path, row):
    rate, hop, width = 11025, 128, 1024
    audio = np.frombuffer(subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le",
        "-ac", "1", "-ar", str(rate), "-",
    ]), dtype="<f4")
    frames = np.lib.stride_tricks.sliding_window_view(audio, width)[::hop]
    spectrum = np.empty((len(frames), 96), dtype=np.float32)
    for start in range(0, len(frames), 1024):
        batch = frames[start:start + 1024]
        spectrum[start:start + len(batch)] = np.abs(np.fft.rfft(batch * np.hanning(width), axis=1))[:, :96]
    log = np.log1p(spectrum * 12.)
    flux = gaussian_filter1d(np.maximum(np.diff(log, axis=0, prepend=log[:1]), 0.).sum(axis=1), .68)
    peaks, _ = find_peaks(flux, distance=round(.08 * rate / hop), prominence=np.percentile(flux, 55))
    times = (peaks * hop + width * .5) / rate - .024
    weights = np.minimum(flux[peaks], np.percentile(flux[peaks], 85))
    bpm = row["published_bpm"]
    offsets = np.linspace(bpm - 1.2, bpm + 1.2, 181)
    phasors = np.exp(2j * np.pi * offsets[:, None] * times[None, :] / 60.) @ weights
    best = int(np.argmax(np.abs(phasors)))
    beat_period = 60. / float(offsets[best])
    phase = float(np.angle(phasors[best]) / (2. * np.pi) % 1.) * beat_period
    events = []
    limit = float(row["duration"]) - .31
    grid = np.arange(phase, limit, beat_period)
    for beat, point in enumerate(grid):
        # The first four bars leave a clear pulse for pilots learning to steer
        # and play at the same time. Faster songs keep one breath per bar.
        if point < .28 or (beat < 16 and beat % 2 == 1):
            continue
        if beat >= 16 and beat_period < .515 and beat % 4 == (2 if row["planet"] in {"saturn", "neptune"} else 3):
            continue
        near = int(np.argmin(abs(times - point)))
        anchored = abs(float(times[near]) - point) < .055
        t = float(times[near]) if anchored else float(point)
        window = audio[max(0, round((t - .04) * rate)):round((t + .10) * rate)]
        if not len(window) or np.max(np.abs(window)) < .009:
            continue
        hold = min(.53, beat_period * .79) if beat % 8 == 1 and point + .85 < limit else 0.
        events.append({
            "t": round(t, 4), "kind": "hold" if hold else "tap", "hold": round(hold, 3),
            "beat": beat, "measure": beat // 4, "phrase": beat // 8, "accent": beat % 4 == 0,
            "origin": "nearby_audio_onset" if anchored else "fitted_beat",
        })
    assert events and all(b["t"] - a["t"] > .28 for a, b in zip(events, events[1:]))
    return {
        "schema": 3, "planet": row["planet"], "id": row["id"], "title": row["title"],
        "artist": row["artist"], "source": row["runtime"], "source_sha256": row["sha256"],
        "duration": row["duration"], "estimated_bpm": round(60. / beat_period, 3),
        "meter": "4-pulse game arrangement", "keys": ["J", "K", "L"],
        "method": "Source BPM with onset-phase fitting and sparse beat-anchored three-key arrangement.",
        "events": events,
    }


def save(path, data, indent=2):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=indent) + "\n", encoding="utf-8")


def main():
    for folder in ("work/expedition-music", "audio/authorized/incompetech", "audio/charts/expeditions"):
        (ROOT / folder).mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        rows = list(pool.map(import_track, TRACKS))
    save(ROOT / "audio/PLANET_MUSIC.json", {"schema": 1, "revision": "v65", "tracks": rows})
    credits = ["# Expedition soundtrack", "", "Music by Kevin MacLeod (incompetech.com), CC BY 4.0.", ""]
    credits += [f"- {row['title']} ([official track page]({row['source_page']}))" for row in rows]
    credits += ["", f"[CC BY 4.0 license]({LICENSE})", "", "Converted to Ogg Vorbis. Original tempo, pitch and duration."]
    (ROOT / "audio/authorized/incompetech/LICENSE.md").write_text("\n".join(credits) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
