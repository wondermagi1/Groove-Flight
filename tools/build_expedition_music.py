"""Import the licensed expedition soundtrack and create its three-key charts."""
import argparse
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
    ("mercury", "go_cart", "Go Cart", "USUAN1300006", 115., "低音推进"),
    ("venus", "vibing_over_venus", "Vibing Over Venus", "USUAN2300005", 94., "切分律动爵士"),
    ("earth", "digital_lemonade", "Digital Lemonade", "USUAN1700010", 120., "明亮模拟合成器"),
    ("mars", "brain_dance", "Brain Dance", "USUAN2300006", 124., "赛博合成器"),
    ("jupiter", "edm_detection_mode", "EDM Detection Mode", "USUAN1500026", 128., "低音重拍舞曲"),
    ("saturn", "voxel_revolution", "Voxel Revolution", "USUAN2000025", 122., "芯片舞曲"),
    ("uranus", "tech_live", "Tech Live", "USUAN1700030", 124., "电子切分"),
    ("neptune", "furious_freak", "Furious Freak", "USUAN1600021", 160., "高速合成器高潮"),
]
ARCHIVE = [("Limit 70", "USUAN1900042"), ("Space Jazz", "USUAN2100030"),
           ("Shiny Tech", "USUAN1100078"), ("Laser Groove", "USUAN1700017")]
# Opening quarter beats, later rest slots across alternating bars, lane phrase.
ARRANGEMENTS = {
    "mercury": (16, (None, None), (0, 1, 2, 1, 0, 2, 0, 1)),
    "venus": (16, (None, 3), (1, 0, 1, 2, 1, 2, 1, 0)),
    "earth": (16, (3, 2), (0, 1, 2, 0, 2, 1, 0, 2)),
    "mars": (16, (None, 3), (2, 0, 2, 1, 0, 1, 2, 1)),
    "jupiter": (16, (2, 3), (0, 2, 1, 2, 1, 0, 1, 2)),
    "saturn": (16, (2, 3), (2, 1, 0, 1, 2, 0, 2, 1)),
    "uranus": (16, (3, 2), (1, 0, 2, 1, 2, 1, 0, 2)),
    "neptune": (24, (3, 2), (0, 2, 0, 1, 2, 1, 2, 0)),
}
GESTURES = {
    # Hold slots in a sixteen-beat phrase, max hold, chord slots, roll slots.
    "venus": ({1, 5, 9, 13}, .59, {4}, {10, 11}),
    "earth": ({1, 9}, .48, {4, 12}, {5, 13}),
    "mars": ({1}, .38, {4}, {2, 5, 6, 9, 10, 13, 14}),
}


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
    offsets = np.linspace(bpm - 2., bpm + 2., 201)
    phasors = np.exp(2j * np.pi * offsets[:, None] * times[None, :] / 60.) @ weights
    best = int(np.argmax(np.abs(phasors)))
    beat_period = 60. / float(offsets[best])
    phase = float(np.angle(phasors[best]) / (2. * np.pi) % 1.) * beat_period
    events = []
    planet = row["planet"]
    opening, rests, motif = ARRANGEMENTS[planet]
    hold_slots, hold_limit, chord_slots, roll_slots = GESTURES.get(
        planet, ({1, 9}, .53, {4}, {5, 6, 9, 10, 12, 13})
    )
    limit = float(row["duration"]) - .31
    grid = np.arange(phase, limit, beat_period)
    for beat, point in enumerate(grid):
        # Leave a readable half-time pulse before introducing the full phrase.
        if point < .34 or (beat < opening and beat % 2 == 1):
            continue
        if beat >= opening and beat % 4 == rests[(beat // 4) % 2]:
            continue
        low, high = np.searchsorted(times, [point - .05, point + .05])
        anchored = low < high
        t = float(point)
        if anchored:
            # Prefer a distinct attack close to the grid over a weak nearby peak.
            candidates = weights[low:high] * (1. - .5 * abs(times[low:high] - point) / .05)
            t = float(times[low + np.argmax(candidates)])
        if events and t - events[-1]["t"] <= .285:
            if point - events[-1]["t"] <= .285:
                continue
            t, anchored = float(point), False
        window = audio[max(0, round((t - .04) * rate)):round((t + .10) * rate)]
        if not len(window) or np.max(np.abs(window)) < .009:
            continue
        hold = min(hold_limit, beat_period * (.92 if planet == "venus" else .79)) if beat % 16 in hold_slots and point + .85 < limit else 0.
        events.append({
            "t": round(t, 4), "kind": "hold" if hold else "tap", "hold": round(hold, 3),
            "beat": beat, "measure": beat // 4, "phrase": beat // 8, "accent": beat % 4 == 0 or (planet == "mars" and beat % 8 == 6),
            "origin": "nearby_audio_onset" if anchored else "fitted_beat",
        })
    minimum_roll_space = beat_period * .94 if planet in {"mercury", "mars"} else .58
    for index in range(1, len(events) - 1):
        event, prior, following = events[index], events[index - 1], events[index + 1]
        if event["kind"] != "tap" or event["beat"] < opening or event["t"] - prior["t"] - prior["hold"] < .34:
            continue
        if event["beat"] % 16 in chord_slots:
            event["technique"] = "chord"
        elif event["beat"] % 16 in roll_slots and following["t"] - event["t"] >= minimum_roll_space:
            subdivision = event["t"] + beat_period * .5
            nearest = int(np.argmin(abs(times - subdivision)))
            if abs(float(times[nearest]) - subdivision) < .038:
                subdivision = float(times[nearest])
            event["technique"] = "roll"
            event["roll"] = round(np.clip(subdivision - event["t"], .22, .38), 4)
    assert events and all(b["t"] - a["t"] > .28 for a, b in zip(events, events[1:]))
    return {
        "schema": 3, "planet": row["planet"], "id": row["id"], "title": row["title"],
        "artist": row["artist"], "source": row["runtime"], "source_sha256": row["sha256"],
        "duration": row["duration"], "estimated_bpm": round(60. / beat_period, 3),
        "meter": "4-pulse game arrangement", "keys": ["J", "K", "L"],
        "finger_pattern": motif,
        "method": "An individual lane phrase and bar rests over the fitted beat grid. Attacks are aligned to nearby strong onsets where available.",
        "events": events,
    }


def save(path, data, indent=2):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=indent) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--charts", nargs="+", choices=tuple(ARRANGEMENTS), help="Regenerate only these charts from installed audio")
    args = parser.parse_args()
    if args.charts:
        manifest = json.loads((ROOT / "audio/PLANET_MUSIC.json").read_text(encoding="utf-8"))
        for row in manifest["tracks"]:
            if row["planet"] not in args.charts:
                continue
            target = ROOT / row["runtime"].removeprefix("res://")
            if digest(target) != row["sha256"]:
                raise ValueError(f"Track checksum mismatch: {target}")
            chart = make_chart(target, row)
            save(ROOT / row["chart"].removeprefix("res://"), chart, indent=None)
            print(row["planet"], len(chart["events"]), flush=True)
        return
    for folder in ("work/expedition-music", "audio/authorized/incompetech", "audio/charts/expeditions"):
        (ROOT / folder).mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        rows = list(pool.map(import_track, TRACKS))
    save(ROOT / "audio/PLANET_MUSIC.json", {"schema": 1, "revision": "v69", "tracks": rows})
    credits = ["# Expedition soundtrack", "", "Music by Kevin MacLeod (incompetech.com), CC BY 4.0.", "", "## Active tracks", ""]
    credits += [f"- {row['title']} ([official track page]({row['source_page']}))" for row in rows]
    credits += ["", "## Archived expedition tracks", ""]
    credits += [f"- {title} ([official track page]({OFFICIAL}index.html?isrc={isrc}))" for title, isrc in ARCHIVE]
    credits += ["", f"[CC BY 4.0 license]({LICENSE})", "", "Converted to Ogg Vorbis. Original tempo, pitch and duration."]
    (ROOT / "audio/authorized/incompetech/LICENSE.md").write_text("\n".join(credits) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
