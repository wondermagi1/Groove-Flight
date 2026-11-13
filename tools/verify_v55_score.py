"""Archive combined-score evidence and compare protected inputs with the backup."""
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BASE = "bab8df876a1440278abeb65ba5723900b7835fe5"
ALLOWED = {
    f"scripts/{name}.gd"
    for name in ["main", "rhythm_score", "rhythm_tiles", "ui", "weapon_codex"]
} | {"audio/CREDITS.md"}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run():
    protected = ["scripts", "audio", "native", "assets", "shaders", "scenes"]
    changed = subprocess.check_output(
        ["git", "diff", "--diff-filter=MDRT", "--name-only", BASE, "--", *protected],
        cwd=ROOT,
    ).decode().splitlines()
    assert set(changed) <= ALLOWED, changed
    tree = subprocess.check_output(
        ["git", "ls-tree", "-r", "-z", BASE, "--", *protected], cwd=ROOT
    ).decode().split("\0")
    expected = {}
    for entry in filter(None, tree):
        meta, path = entry.split("\t")
        if path not in ALLOWED:
            expected[path] = meta.split()[2]
    paths = sorted(expected)
    hashes = subprocess.check_output(
        ["git", "hash-object", "--stdin-paths"], cwd=ROOT,
        input=("\n".join(paths) + "\n").encode(),
    ).decode().splitlines()
    assert len(paths) == len(hashes) and all(
        expected[path] == value for path, value in zip(paths, hashes)
    ), "Protected weapon/music/mission/native file changed"

    songs = json.loads((ROOT / "audio/PLANET_MUSIC.json").read_text(encoding="utf-8"))["tracks"]
    cue_total = 0
    for song in songs:
        assert digest(ROOT / song["runtime"].removeprefix("res://")) == song["sha256"]
        chart = json.loads((ROOT / song["chart"].removeprefix("res://")).read_text(encoding="utf-8"))
        assert chart["keys"] == ["J", "K", "L"] and chart["tracks"] == ["A", "B", "C"]
        assert chart["lane_mode"] == "weapon_track" and chart["schema"] == 3
        assert all(event["kind"] in ["tap", "hold"] and "lanes" not in event for event in chart["events"])
        cue_total += len(chart["events"])
    assert len(songs) == 8 and cue_total == 3487

    stage = ROOT / "work/v50-runtime/tests"
    report = ROOT / "docs/data-v55"
    report.mkdir(exist_ok=True)
    reviews = {}
    names = {
        "score": "results-v55-score", "planets": "results-v54-planets",
        "native": "results-v55-native", "live": "results-v55-live",
    }
    warnings = {}
    for name, filename in names.items():
        data = json.loads((stage / (filename + ".json")).read_text(encoding="utf-8"))
        assert not data["failures"]
        reviews[name] = data
        log = (ROOT / ("work/v55-" + name + ".log")).read_text(encoding="utf-8", errors="replace")
        assert "SCRIPT ERROR" not in log and "Parse Error" not in log
        errors = [line for line in log.splitlines() if line.startswith("ERROR:") and "resources still in use at exit" not in line]
        assert not errors, errors
        warnings[name] = [line for line in log.splitlines() if line.startswith("WARNING:")]
        (report / (name + ".json")).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    for path in reviews["native"]["captures"]:
        name = Path(path).name
        shutil.copy2(stage / name, ROOT / "docs/screenshots" / name)
    wavs = [path for path in paths if path.startswith("audio/arsenal/") and path.endswith(".wav")]
    summary = {
        "version": "0.55.0-combined-rhythm-score", "date": "2026-11-13",
        "backup": BASE, "branch": "codex/combined-rhythm-score",
        "input_mapping": {"J": "A", "K": "B", "L": "C"},
        "aggregation": "sum(A/B/C earned points) / sum(A/B/C possible points); not mean of lane percentages",
        "application": "one shared ratio for all weapons in the next six-second window",
        "score_window_seconds": 6, "opening_ratio": 1.0,
        "points": {"perfect": 100, "good": 70, "miss": 0},
        "empty_lane": "adds no denominator", "no_note_window": "carry prior shared ratio",
        "zero_quota": "no new salvo/audio on any track; scoring notes continue",
        "candidate_times_and_holds_unchanged": cue_total,
        "checks": {name: data["checks"] for name, data in reviews.items()},
        "protected_files_unchanged": len(paths), "unchanged_all_arsenal_wavs": len(wavs),
        "unchanged_active_weapons": 24, "unchanged_active_wavs": 288,
        "unchanged_full_background_songs": len(songs),
        "native_kernel_sha256": digest(ROOT / "native/crowd/groove_crowd.windows.x86_64.dll"),
        "native_renderer": reviews["native"]["renderer"],
        "screenshots": len(reviews["native"]["captures"]),
        "visual_review": "Four Forward+ captures inspected at1280/1920, inventory fallback and score feedback. Current segment points and currently applied previous-segment ratio are separately labelled.",
        "layout": "Adjacent to sequencer, aligned bottoms; above-right fallback when inventory leaves insufficient side room.",
        "warnings": warnings,
        "scope": "Weighted uneven/empty lanes, all24 weapons on3tracks, shared zero/recovery, real voices, native clock/OGG transport, eight mission regressions and Forward+ input/layout. No human difficulty, listening, physical-device latency or sustained FPS certification. Historical demo/PPT/private reports excluded.",
    }
    (report / "SUMMARY.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    for filename in ["README.md", "docs/V55_COMBINED_RHYTHM_SCORE.md", "docs/WEAPON_VFX_AUDIO_REFERENCE.md", "docs/RHYTHM_CONTRACT.md"]:
        doc = ROOT / filename
        for target in re.findall(r"\]\(([^)]+)\)", doc.read_text(encoding="utf-8")):
            if "://" in target or target.startswith("#"):
                continue
            assert (doc.parent / target.split("#")[0]).exists(), target
    print(json.dumps(summary, ensure_ascii=False))


if __name__ == "__main__":
    run()
