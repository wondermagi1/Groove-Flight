"""Build the four authorized recorded-audio weapons from approved source clips."""

from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import wave

from audio_library import analyze_audio_file, catalog_path, write_audio_plot
from repair_recorded_audio_imports import import_sidecar


ROOT = Path(__file__).resolve().parents[1]
NOTES = ROOT / "audio" / "arsenal" / "notes"
WORKING = ROOT / "audio" / "library" / "groove_core" / "working"
ANALYSIS = ROOT / "audio" / "library" / "groove_core" / "analysis"
AUTHORIZED = ROOT / "audio" / "authorized"
CODEC = ROOT / "audio" / "weapon_codex.json"
SOURCES = {
    "rec_crude": (
        WORKING / "weapon_crude_fire" / "extracted_audio.wav",
        "weapon_crude_fire@0.00-6.00s continuous three-cycle group",
        [
            (0.05, 0.32),
            (1.05, 1.74),
            (2.05, 2.32),
            (3.05, 3.74),
            (4.05, 4.32),
            (5.04, 5.74),
            (6.04, 6.32),
            (7.05, 7.74),
        ],
        4.5,
    ),
    "rec_ballistic": (
        WORKING / "weapon_ballistic_volume_ramp" / "extracted_audio.wav",
        "weapon_ballistic_volume_ramp@0.58-16.58s complete sixteen-second weapon cycle",
        [
            (0.58, 1.06),
            (1.64, 2.06),
            (2.58, 3.06),
            (3.58, 4.06),
            (4.58, 5.06),
            (5.58, 6.06),
            (6.58, 7.06),
            (7.58, 8.06),
        ],
        12.0,
    ),
}

GROUPS = {
    "rec_crude": {
        "source": WORKING / "weapon_crude_fire" / "extracted_audio.wav",
        "catalog_id": "weapon_crude_fire",
        "start": 0.0,
        "end": 6.0,
        "file": AUTHORIZED / "weapon_crude_fire_group_6s.wav",
        "label": "crude-fire-full-0-6s",
    },
    "rec_ballistic": {
        "source": WORKING / "weapon_ballistic_volume_ramp" / "extracted_audio.wav",
        "catalog_id": "weapon_ballistic_volume_ramp",
        "start": 0.58,
        "end": 16.58,
        "file": AUTHORIZED / "weapon_ballistic_cycle_16s.wav",
        "label": "ballistic-sixteen-second-cycle",
    },
}


def run(command: list[str]) -> None:
    subprocess.run(command, check=True, timeout=120)


def build_recorded_group(ffmpeg: str, voice: str, group: dict) -> dict:
    source: Path = group["source"]
    output: Path = group["file"]
    start = float(group["start"])
    end = float(group["end"])
    output.parent.mkdir(parents=True, exist_ok=True)
    # Decode only. No fades, gain changes, normalization, resampling, sample
    # splitting or pitch processing are applied to the retained recording.
    run([
        ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
        "-ss", f"{start:.6f}", "-t", f"{end - start:.6f}", "-i", str(source),
        "-map", "0:a:0", "-vn", "-c:a", "pcm_s16le", "-map_metadata", "-1",
        str(output),
    ])
    output.with_suffix(".wav.import").write_text(
        import_sidecar(output), encoding="utf-8", newline="\n"
    )
    with wave.open(str(source), "rb") as source_audio, wave.open(str(output), "rb") as result_audio:
        source_audio.setpos(round(start * source_audio.getframerate()))
        source_frames = source_audio.readframes(result_audio.getnframes())
        result_frames = result_audio.readframes(result_audio.getnframes())
        if source_frames != result_frames:
            raise ValueError(f"runtime group is not sample-identical to its source: {output}")
    analysis = analyze_audio_file(output)
    event_starts = [
        float(interval["start_seconds"])
        for interval in analysis.get("active_intervals", [])
        if float(interval.get("duration_seconds", 0.0)) >= 0.1
    ]
    onset_offsets = [round(value - event_starts[0], 3) for value in event_starts] if event_starts else []
    onset_errors_ms = [
        round(abs(offset - float(index)) * 1000.0, 1)
        for index, offset in enumerate(onset_offsets)
    ]
    if voice == "rec_ballistic":
        if len(onset_offsets) != 16:
            raise ValueError(
                f"ballistic cycle must contain 16 audible hits, found {len(onset_offsets)}"
            )
        if max(onset_errors_ms) > 75.0:
            raise ValueError(
                "ballistic cycle exceeds 75 ms one-second grid tolerance: "
                f"{max(onset_errors_ms)} ms"
            )
    if voice == "rec_crude":
        if len(onset_offsets) != 6:
            raise ValueError(
                f"crude-fire cycle must contain 6 audible hits, found {len(onset_offsets)}"
            )
        if max(onset_errors_ms) > 75.0:
            raise ValueError(
                "crude-fire group exceeds 75 ms one-second grid tolerance: "
                f"{max(onset_errors_ms)} ms"
            )
    plot_dir = ANALYSIS / str(group["catalog_id"])
    plot_dir.mkdir(parents=True, exist_ok=True)
    plot_path = plot_dir / f"{group['label']}-waveform.png"
    write_audio_plot(analysis, plot_path)
    return {
        "voice": voice,
        "catalog_id": group["catalog_id"],
        "source_file": catalog_path(source),
        "source_start_seconds": start,
        "source_end_seconds": end,
        "runtime_file": catalog_path(output),
        "processing": "direct PCM16 slice only; no fades, gain, normalization, resampling, segmentation or pitch processing",
        "duration_seconds": analysis["duration_seconds"],
        "peak_dbfs": analysis["peak_dbfs"],
        "rms_dbfs": analysis["rms_dbfs"],
        "waveform": catalog_path(plot_path),
        "pcm_samples_identical_to_source": True,
        "detected_sound_count": len(onset_offsets),
        "onset_offsets_seconds": onset_offsets,
        "onset_grid_error_ms": onset_errors_ms,
        "max_onset_grid_error_ms": max(onset_errors_ms) if onset_errors_ms else 0.0,
    }


def main() -> None:
    ffmpeg = shutil.which("ffmpeg")
    if not ffmpeg:
        raise ValueError("ffmpeg is required")
    NOTES.mkdir(parents=True, exist_ok=True)
    temporary_path = ROOT / "work" / "recorded-audio-build"
    temporary_path.mkdir(parents=True, exist_ok=True)
    group_records = [
        build_recorded_group(ffmpeg, voice, group)
        for voice, group in GROUPS.items()
    ]
    group_report = {
        "schema": 1,
        "rule": "The runtime sound is one continuous file from the source recording. Four-beat gameplay timing does not split or transpose the recording.",
        "groups": group_records,
    }
    (ANALYSIS / "recorded-weapon-groups.json").write_text(
        json.dumps(group_report, ensure_ascii=False, indent=2),
        encoding="utf-8",
        newline="\n",
    )
    for voice, (source, recorded_source, event_ranges, gain_db) in SOURCES.items():
        if not source.is_file():
            raise FileNotFoundError(source)
        for pitch, (start, end) in enumerate(event_ranges):
            output = NOTES / f"{voice}_{pitch}.wav"
            duration = end - start
            run([
                ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
                "-ss", f"{start:.3f}", "-t", f"{duration:.3f}", "-i", str(source),
                "-af", f"asetpts=PTS-STARTPTS,afade=t=in:st=0:d=0.005,afade=t=out:st={max(0., duration - 0.005):.3f}:d=0.005,volume={gain_db:.1f}dB",
                "-ac", "1", "-ar", "22050", "-c:a", "pcm_s16le", str(output),
            ])
            output.with_suffix(".wav.import").write_text(
                import_sidecar(output), encoding="utf-8", newline="\n"
            )
        print(f"{voice}: {recorded_source}")

    codex = json.loads(CODEC.read_text(encoding="utf-8"))
    retired_recordings = {"recorded_light", "recorded_medium", "recorded_heavy"}
    base_weapons = [
        weapon for weapon in codex.get("weapons", [])
        if not str(weapon.get("id", "")).endswith(("_rare", "_legend"))
        and str(weapon.get("id", "")) not in retired_recordings
    ]
    if not any(str(weapon.get("id", "")) == "recorded_ballistic" for weapon in base_weapons):
        ballistic = {
            "id": "recorded_ballistic",
            "name": "实弹连奏炮",
            "family": "pulse",
            "voice": "rec_ballistic",
            "attr": "ballistic",
            "charge_bars": 1,
            "width": 2,
            "recorded_audio": True,
            "recorded_source": SOURCES["rec_ballistic"][1],
            "cadence": {
                "label": "匀速四连",
                "scales": [0.25, 0.25, 0.25, 0.25],
                "pitches": [0, 0, 0, 0],
            },
            "cadence_total": 1.0,
            "reference_layer": "ballistic_volume_ramp",
            "sample_count": 8,
            "samples": [
                {"pitch": pitch, "path": f"res://audio/arsenal/notes/rec_ballistic_{pitch}.wav"}
                for pitch in range(8)
            ],
        }
        base_weapons.insert(-1, ballistic)
    expanded = []
    for weapon in base_weapons:
        expanded.append(weapon)
        weapon_id = str(weapon.get("id", ""))
        voice = str(weapon.get("voice", ""))
        if not weapon.get("recorded_audio") or voice not in SOURCES:
            continue
        for quality, suffix in ((1, "_rare"), (2, "_legend")):
            tier = json.loads(json.dumps(weapon))
            tier["id"] = weapon_id + suffix
            tier["base_weapon_id"] = weapon_id
            tier["quality"] = quality
            tier["quality_name"] = ("稀有", "珍贵")[quality - 1]
            expanded.append(tier)
    codex["weapons"] = expanded
    for weapon in codex.get("weapons", []):
        voice = str(weapon.get("voice", ""))
        if voice not in SOURCES or not weapon.get("recorded_audio"):
            continue
        group = GROUPS[voice]
        weapon["recorded_source"] = SOURCES[voice][1]
        weapon["recorded_group"] = "res://" + catalog_path(group["file"])
        weapon["recorded_group_start"] = group["start"]
        weapon["recorded_group_end"] = group["end"]
        weapon["recorded_group_processing"] = "direct PCM16 source slice; no segmentation or pitch processing"
        weapon["source_event_ranges"] = [
            {"start_seconds": start, "end_seconds": end}
            for start, end in SOURCES[voice][2]
        ]
        for sample in weapon.get("samples", []):
            path = NOTES / Path(str(sample["path"])).name
            payload = path.read_bytes()
            sample["bytes"] = len(payload)
            sample["sha256"] = hashlib.sha256(payload).hexdigest()
    codex["generated_at"] = "2026-11-04"
    codex["weapon_count"] = len(codex["weapons"])
    recorded_count = sum(1 for weapon in codex["weapons"] if weapon.get("recorded_audio"))
    codex["scope"] = (
        f"All {len(codex['weapons'])} weapon quality entries use their live sample voices. "
        f"Two recorded prototypes expose {recorded_count} normal/rare/precious tiers that share "
        "two unsegmented authorized PCM16 groups; 32 placeholder-synth weapons remain archived "
        "but disabled in production."
    )
    CODEC.write_text(json.dumps(codex, ensure_ascii=False, indent="\t"), encoding="utf-8")
    print(json.dumps(group_report, ensure_ascii=False, indent=2))
    print("UPDATED audio/weapon_codex.json")


if __name__ == "__main__":
    main()
